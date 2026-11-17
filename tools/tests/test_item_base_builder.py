"""Verify the literal-only metadata export, merge rules and public field allowlist."""
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from build_item_base import build,lua,identity
from wow_saved_variables import Parser


def entry(item_id=100,suffix=-5,name='Sword',**extra):
    row={'link':f'|Hitem:{item_id}:0:0:0:0:0:{suffix}:12345:80|h[{name}]|h','id':str(item_id),'class':'Weapon','subclass':'Sword','texture':'Interface\\Icons\\INV_Sword_01','quality':2}
    row.update(extra)
    return row


class BuilderTests(unittest.TestCase):
    def test_merge_and_no_price_or_personal_fields(self):
        old={'AUCTIONATOR_BROWSER_ITEMS':{'Sword':entry(mr=100,character='PRIVATE',seller='PRIVATE')}}
        new={'AUCTIONATOR_BROWSER_ITEMS':{'Sword':entry(equipLoc='INVTYPE_WEAPON')},'AUCTIONATOR_PURCHASES':{'PRIVATE':'PRIVATE'}}
        result,stats=build([old,new])
        self.assertEqual(stats['variants'],1)
        self.assertEqual(stats['duplicate_observations'],1)
        self.assertEqual(result['baseItems'][100]['equipLoc'],'INVTYPE_WEAPON')
        export=lua(result)
        self.assertNotIn('PRIVATE',export)
        self.assertNotIn('12345',export)
        self.assertNotIn('itemString',export)
        self.assertNotIn('families',export)
        self.assertNotIn('["mr"]',export)

    def test_same_name_two_suffixes_preserved_without_name_guessing(self):
        result,stats=build([{'AUCTIONATOR_BROWSER_ITEMS':{'Shared':entry(suffix=-5,name='Shared')}},
                            {'AUCTIONATOR_BROWSER_ITEMS':{'Shared':entry(suffix=5,name='Shared')}}])
        self.assertEqual(set(result['variants']),{'item:100:-5','item:100:5'})
        self.assertEqual(stats['ambiguous_names'],1)

    def test_consensus_and_missing_values(self):
        a=entry(name='A',equipLoc='INVTYPE_WEAPON')
        b=entry(name='B',suffix=5)
        result,_=build({'AUCTIONATOR_BROWSER_ITEMS':{'A':a,'B':b}})
        self.assertEqual(result['baseItems'][100]['equipLoc'],'INVTYPE_WEAPON')
        b['equipLoc']='INVTYPE_2HWEAPON'
        result,_=build({'AUCTIONATOR_BROWSER_ITEMS':{'A':a,'B':b}})
        self.assertNotIn('equipLoc',result['baseItems'][100])
        self.assertEqual(result['variants']['item:100:-5']['equipLoc'],'INVTYPE_WEAPON')

    def test_wrong_links_and_wrong_claimed_ids_rejected(self):
        bad={'Wrong':entry(name='Different'),'Sword':entry(id='999')}
        result,stats=build({'AUCTIONATOR_BROWSER_ITEMS':bad})
        self.assertFalse(result['variants'])
        self.assertEqual(stats['rejected'],2)
        self.assertIsNone(identity('item:100:0:0'))

    def test_invalid_fields_do_not_crash_or_export(self):
        value=entry(**{'class':{},'quality':True,'equipLoc':{},'subclass':'bad\x00value','texture':'Interface\\Icons\\INV_Misc_QuestionMark'})
        result,stats=build({'AUCTIONATOR_BROWSER_ITEMS':{'Sword':value,'Broken':{'link':42}}})
        self.assertFalse(result['variants'])
        self.assertEqual(stats['rejected'],2)

    def test_v1_to_v2_and_v2_roundtrip(self):
        value=entry()
        old={'AuctionatorItemBase':{'version':1,'items':{'Sword':{'id':100,'itemString':'item:100:0:0:0:0:0:-5:999:0',
             'class':'Weapon','texture':value['texture'],'quality':2}},'families':{'FAKE':{'id':999}}}}
        result,_=build(old)
        text='AuctionatorItemBase = '+lua(result)
        loaded=Parser(text).document()
        rebuilt,_=build(loaded)
        self.assertEqual(result,rebuilt)
        self.assertNotIn('FAKE',lua(result))

    def test_legacy_names_are_not_trusted_without_observed_label(self):
        old={'AuctionatorItemBase':{'version':1,'items':{'Unproven':{'id':100,'itemString':'item:100:0:0:0:0:0:-5:0',
             'class':'Weapon','texture':'Interface\\Icons\\INV_Sword_01'}}}}
        result,stats=build(old)
        self.assertNotIn('name',result['variants']['item:100:-5'])
        self.assertEqual(stats['unlabelled_variants'],1)

    def test_new_schema_ambiguous_names_preserve_each_exact_item(self):
        source={'AUCTIONATOR_REMASTERED_DATABASE':{'catalog':{'items':{'item:100:-5':entry(name='Shared'),
            'item:100:5':entry(suffix=5,name='Shared')},'names':{'enUS':{'Shared':False}}}}}
        result,stats=build(source)
        self.assertEqual(stats['variants'],2)
        self.assertEqual(stats['ambiguous_names'],1)

    def test_literal_parser_identifier_fields_and_rejects_code(self):
        parsed=Parser('X = {version=2, items={["id"]={quality=0}}, flags={true,false}}').document()
        self.assertEqual(parsed['X']['version'],2)
        self.assertEqual(parsed['X']['items']['id']['quality'],0)
        for value in ('X = os.execute("bad")','X = {field=function() end}','X = {field=unknown}','X = setmetatable({}, {})'):
            with self.assertRaises((ValueError,AssertionError)):
                Parser(value).document()


if __name__=='__main__': unittest.main()
