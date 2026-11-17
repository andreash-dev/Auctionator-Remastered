"""Merge verified metadata into a compact ID/suffix catalog; never execute Lua.

Only allowlisted static metadata and observed item names are exported. Prices,
accounts, characters, trading logs, instance seeds and guessed name families are
not exported. Later sources enrich/replace verified fields of the same identity.
"""
import argparse
import collections
import json
import math
import re
from pathlib import Path

CLASSES = {'Weapon','Armor','Container','Consumable','Glyph','Trade Goods','Projectile','Quiver','Recipe','Gem','Miscellaneous','Quest'}
FIELDS = ('class', 'subclass', 'texture', 'quality', 'equipLoc')
SLOTS = {'INVTYPE_HEAD','INVTYPE_NECK','INVTYPE_SHOULDER','INVTYPE_CLOAK','INVTYPE_CHEST','INVTYPE_ROBE','INVTYPE_BODY','INVTYPE_TABARD','INVTYPE_WRIST','INVTYPE_HAND','INVTYPE_WAIST','INVTYPE_LEGS','INVTYPE_FEET','INVTYPE_FINGER','INVTYPE_TRINKET','INVTYPE_WEAPON','INVTYPE_2HWEAPON','INVTYPE_WEAPONMAINHAND','INVTYPE_WEAPONOFFHAND','INVTYPE_SHIELD','INVTYPE_HOLDABLE','INVTYPE_RANGED','INVTYPE_RANGEDRIGHT','INVTYPE_THROWN','INVTYPE_RELIC','INVTYPE_BAG','INVTYPE_QUIVER','INVTYPE_AMMO'}


def lua(value):
    if isinstance(value, str):
        return '"' + value.replace('\\','\\\\').replace('"','\\"').replace('\n','\\n').replace('\r','\\r').replace('\t','\\t') + '"'
    if isinstance(value, bool): return 'true' if value else 'false'
    if isinstance(value, int): return str(value)
    if isinstance(value, float) and math.isfinite(value): return repr(value)
    if isinstance(value, list): return '{'+','.join(lua(v) for v in value)+'}'
    if isinstance(value, dict): return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in sorted(value.items()))+'}'
    raise TypeError(type(value))


def identity(value):
    if not isinstance(value,str): return None
    compact=re.fullmatch(r'item:(\d+):(-?\d+)',value)
    if compact:
        item_id,suffix=map(int,compact.groups())
    else:
        match=re.search(r'\|Hitem:([\d:\-]+)\|h',value) or re.fullmatch(r'item:([\d:\-]+)',value)
        if not match: return None
        parts=match.group(1).split(':')
        if len(parts)<7 or not all(re.fullmatch(r'-?\d+',p) for p in parts): return None
        item_id,suffix=int(parts[0]),int(parts[6])
    if not 0<item_id<=2147483647 or not -2147483647<=suffix<=2147483647: return None
    return f'item:{item_id}:{suffix}',item_id,suffix


def names_list(value):
    if isinstance(value,list): return value
    if isinstance(value,dict): return [v for k,v in sorted((k,v) for k,v in value.items() if type(k) is int)]
    return []


def observations(source):
    if not isinstance(source,dict): raise ValueError('Expected literal table assignments')
    base=source.get('AuctionatorItemBase',{})
    if not isinstance(base,dict): base={}
    if base.get('version')==2:
        for key,variant in base.get('variants',{}).items():
            parsed=identity(key)
            if not parsed or not isinstance(variant,dict): continue
            raw=dict(base.get('baseItems',{}).get(parsed[1],{}));raw.update(variant)
            labels=[variant.get('name')]+names_list(variant.get('aliases',[]))
            labels=[name for name in labels if name is not None]
            if labels:
                for name in labels: yield name,raw,key,True
            else: yield None,raw,key,False
    elif base:
        for name,raw in base.get('items',{}).items():
            yield name,raw,raw.get('itemString') if isinstance(raw,dict) else None,False
    for name,raw in source.get('AUCTIONATOR_BROWSER_ITEMS',{}).items():
        yield name,raw,raw.get('link') if isinstance(raw,dict) else None,'link'
    root=source.get('AUCTIONATOR_REMASTERED_DATABASE',{})
    catalog=root.get('catalog',{}) if isinstance(root,dict) else {}
    seen=set()
    for key,raw in catalog.get('items',{}).items():
        if not isinstance(raw,dict): continue
        link=raw.get('link')
        label=re.search(r'\|h\[(.*?)\]\|h',link) if isinstance(link,str) else None
        if label and identity(link) and identity(link)[0]==key:
            name=label.group(1);seen.add((name,key));yield name,raw,link,'link'
        else: yield None,raw,key,False
    for locale,aliases in catalog.get('names',{}).items():
        for name,key in aliases.items():
            if isinstance(key,str) and key in catalog.get('items',{}) and (name,key) not in seen:
                seen.add((name,key));yield name,catalog['items'][key],key,True


def clean_fields(raw):
    result={}
    category='Miscellaneous' if raw.get('class') in ('Key','Keys') else raw.get('class')
    if isinstance(category,str) and category in CLASSES: result['class']=category
    subclass=raw.get('subclass')
    if isinstance(subclass,str) and subclass and subclass not in ('Unknown','Unclassified') and len(subclass)<=128 and not any(ord(c)<32 for c in subclass):
        result['subclass']=subclass
    texture=raw.get('texture')
    if isinstance(texture,str):
        texture=re.sub(r'\\+',r'\\',texture.replace('/','\\'))
        if re.fullmatch(r'Interface\\Icons\\[A-Za-z0-9_\-.]+',texture,re.I) and 'inv_misc_questionmark' not in texture.lower():
            result['texture']=texture
    quality=raw.get('quality')
    if type(quality) is int and 0<=quality<=7: result['quality']=quality
    if isinstance(raw.get('equipLoc'),str) and raw['equipLoc'] in SLOTS: result['equipLoc']=raw['equipLoc']
    return result


def build(sources):
    if isinstance(sources,dict): sources=[sources]
    merged={};stats=collections.Counter()
    for source in sources:
        for name,raw,proof,verified_name in observations(source):
            valid_name=isinstance(name,str) and bool(name) and len(name)<=512 and not any(ord(c)<32 for c in name)
            if (not valid_name and (name is not None or verified_name)) or not isinstance(raw,dict):
                stats['rejected']+=1;continue
            parsed=identity(proof)
            label=re.search(r'\|h\[(.*?)\]\|h',proof) if isinstance(proof,str) else None
            if not parsed or (label and label.group(1)!=name): stats['rejected']+=1;continue
            if verified_name=='link' and not label: verified_name=False
            key,item_id,suffix=parsed
            claimed=raw.get('id')
            if claimed is not None and str(claimed).split(':')[0]!=str(item_id): stats['rejected']+=1;continue
            fields=clean_fields(raw)
            if not fields: stats['rejected']+=1;continue
            if key not in merged: merged[key]={'names':set(),'fields':{},'seen':0}
            entry=merged[key]
            if entry['seen']: stats['duplicate_observations']+=1
            entry['seen']+=1
            if verified_name:
                entry['names'].add(name);entry['name']=name
            for field,value in fields.items():
                previous=entry['fields'].get(field)
                if previous is not None and previous!=value: stats['updated_fields']+=1
                if previous is None: stats['enriched_fields']+=1
                entry['fields'][field]=value
            stats['accepted_observations']+=1
    grouped=collections.defaultdict(list)
    for key,entry in merged.items(): grouped[identity(key)[1]].append(entry['fields'])
    bases={}
    for item_id,entries in grouped.items():
        common={}
        for field in FIELDS:
            # Only observed field values count: missing data is not a new
            # value. Any disagreement prevents that field's base-ID fallback.
            values={row[field] for row in entries if field in row}
            if len(values)==1: common[field]=next(iter(values))
        bases[item_id]=common
    variants={};name_ids=collections.defaultdict(set)
    for key,entry in sorted(merged.items()):
        common=bases[identity(key)[1]]
        row={'name':entry['name']} if entry['names'] else {}
        aliases=sorted(entry['names']-{entry.get('name')})
        if aliases: row['aliases']=aliases
        row.update({field:value for field,value in entry['fields'].items() if common.get(field)!=value})
        variants[key]=row
        for name in entry['names']: name_ids[name].add(key)
    stats.update(unlabelled_variants=sum(not entry['names'] for entry in merged.values()),variants=len(variants),base_ids=len(bases),names=len(name_ids),ambiguous_names=sum(len(ids)>1 for ids in name_ids.values()),
                 variants_with_slots=sum('equipLoc' in e['fields'] for e in merged.values()))
    return {'version':2,'baseItems':bases,'variants':variants},dict(stats)


def read(path):
    if path.suffix.lower()=='.json': return json.loads(path.read_text())
    from wow_saved_variables import Parser
    before=path.stat()
    value=Parser(path.read_text(encoding='utf-8-sig')).document()
    after=path.stat()
    if (before.st_size,before.st_mtime_ns)!=(after.st_size,after.st_mtime_ns): raise ValueError('Source changed while reading; reload/save again before exporting')
    return value


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path)
    parser.add_argument('output',type=Path)
    parser.add_argument('--merge',action='append',type=Path,default=[],help='Additional sources, newest last')
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    catalog,stats=build([read(path) for path in [args.source]+args.merge])
    lines=['-- Verified metadata reserve only. No prices, accounts, characters, logs or instance seeds.',
           '-- ID/suffix keys; base fields require agreement across observed variants. No name-family inference.',
           'AuctionatorItemBase = {version=2,baseItems={']
    lines.extend('['+lua(key)+']='+lua(row)+',' for key,row in sorted(catalog['baseItems'].items()))
    lines.append('},variants={')
    lines.extend('['+lua(key)+']='+lua(row)+',' for key,row in sorted(catalog['variants'].items()))
    lines.append('}}')
    args.output.write_text('\n'.join(lines)+'\n')
    stats['output_bytes']=args.output.stat().st_size
    if args.report: args.report.write_text(json.dumps(stats,indent=2)+'\n')
    print(json.dumps(stats,sort_keys=True))


if __name__=='__main__': main()
