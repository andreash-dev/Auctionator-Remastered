-- Test in fresh WoW-like global environments so conflict cases cannot leak state.
local assertions=0
local function check(value,message) assertions=assertions+1;assert(value,message) end
local function scenario(addons, options)
 options=options or {}
 local env=setmetatable({},{__index=_G});env._G=env
 local events,loads,disabled,enabled,labels={},{},{},{},{}
 local frames={}
 env.SlashCmdList={}
 options.messages={}
 env.DEFAULT_CHAT_FRAME={AddMessage=function(_,text) options.messages[#options.messages+1]=text end}
 env.IsLoggedIn=function() return options.late or false end
 local function widget()
  local w={shown=true,scripts={},children={},level=0}
  function w:RegisterEvent(event) events[event]=self end
  function w:SetScript(event,fn) self.scripts[event]=fn end
  function w:CreateFontString() local label=widget();labels[#labels+1]=label;return label end
  function w:SetText(text) self.text=text end
  function w:SetBackdrop(value) self.backdrop=value end
  function w:SetTemplate(value) self.elvTemplate=value end
  function w:GetStringHeight() return 32 end
  function w:GetChildren() return unpack(self.children) end
  function w:GetFrameLevel() return self.level end
  function w:SetFrameLevel(level) self.level=level end
  function w:SetToplevel(value) self.toplevel=value end
  function w:Raise() self.level=self.level+20 end
  function w:Show() self.shown=true end
  function w:Hide() self.shown=false end
  function w:IsShown() return self.shown end
  function w:Enable() self.enabled=true end
  function w:Disable() self.enabled=false end
  return setmetatable(w,{__index=function(_,name) if name:match('^Set') or name=='EnableMouse' then return function() end end end})
 end
 env.CreateFrame=function(kind,name,parent,template)
  if template=='UIPanelScrollFrameTemplate' then
   -- Wrath UIPanelScrollFrame_OnLoad concatenates self:GetName().
   assert(type(name)=='string' and name~='', 'WoW 3.3.5 requires a named UIPanelScrollFrameTemplate')
   options.namedScrolls=(options.namedScrolls or 0)+1
  end
  if template=='UIPanelButtonTemplate' then assert(type(name)=='string' and name~='', 'Startup template buttons require stable names') end
  local w=widget();frames[#frames+1]=w
  w.parent=parent
  if parent then w.level=parent.level+1;parent.children[#parent.children+1]=w end
  if name then env[name]=w end
  if template=='UIPanelScrollFrameTemplate' then
   local bar=widget();bar.parent=w;bar.level=w.level+1;w.children[#w.children+1]=bar;env[name..'ScrollBar']=bar
  end
  return w
 end
 env.UIParent=widget();env.UISpecialFrames={}
 if options.elvUI then
  local skin={HandleButton=function(_,button)
    options.skinnedButtons=(options.skinnedButtons or 0)+1
    local background=widget();background.parent=button;background.level=button.level-1
    button.backdrop=background;button.children[#button.children+1]=background
   end,
      HandleScrollBar=function() options.skinnedScrolls=(options.skinnedScrolls or 0)+1 end}
  env.ElvUI={{GetModule=function() return skin end}}
 end
 env.GetNumAddOns=function() return #addons end
 env.GetAddOnInfo=function(i) local a=addons[i];return a.name,a.title or a.name,'',a.enabled end
 env.GetAddOnMetadata=function(name) for _,a in ipairs(addons) do if a.name==name then return a.component end end end
 env.IsAddOnLoaded=function(name) for _,a in ipairs(addons) do if a.name==name then return a.loaded end end end
 env.InCombatLockdown=function() return options.combat end
 env.DisableAddOn=function(name) disabled[#disabled+1]=name end
 env.EnableAddOn=function(name) enabled[#enabled+1]=name end
 env.ReloadUI=function() options.reload=(options.reload or 0)+1 end
 env.LoadAddOn=function(name)
  loads[#loads+1]=name
  check(not options.login,'Engine must load before PLAYER_LOGIN, preserving original initialization ordering')
  return not options.fail,options.fail
 end
 if options.unknown then env.Atr_core={} end
 local function load(path,...)
  local fn=assert(loadfile('AuctionatorRemastered_Startup/'..path));setfenv(fn,env);fn(...)
 end
 load('ConflictPolicy.lua');load('Startup.lua', 'AuctionatorRemastered_Startup')
 options.command=function() env.SlashCmdList.ATRREMASTEREDSTARTUP() end
 local function event(kind,name)
  local f=events[kind];check(f~=nil,'Registered event '..kind);f.scripts.OnEvent(f,kind,name)
 end
 event('ADDON_LOADED','AuctionatorRemastered_Startup')
 check(not env.AuctionatorRemasteredStartup.dialog,'Do not show startup dialogs before login')
 options.login=true;event('PLAYER_LOGIN')
 check(not env.AuctionatorRemasteredStartup.dialog,'Wait until startup UI events have completed')
 options.tick=function(elapsed)
  for _,frame in ipairs(frames) do if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame,elapsed) end end
 end
 options.tick(.5)
 check(not env.AuctionatorRemasteredStartup.dialog,'Do not show under the loading screen')
 options.tick(.6)
 return env.AuctionatorRemasteredStartup,event,loads,disabled,enabled,labels,options
end
local function addon(name,enabled,title) return {name=name,enabled=enabled,title=title} end
local s,event,loads,disabled,enabled=scenario({addon('Auctionator',true)})
check(s.blocked and #loads==0 and s.dialog.shown,'Enabled original blocks ALL engine loading')
check(s.conflicts[1].name=='Auctionator')
s.Resolve(true)
check(disabled[1]=='Auctionator' and #disabled==1)
check(enabled[1]=='AuctionatorRemastered_Startup' and enabled[2]=='AuctionatorRemastered')
event('ADDON_LOADED','AuctionatorRemastered_Startup');check(#loads==0,'Cannot start in a previously blocked session')
s,event,loads,disabled,enabled=scenario({addon('Auctionator',true),addon('AuctionatorMiniFeatures',true),addon('Unrelated',true)})
check(s.blocked and #s.conflicts==2 and #loads==0,'Original and MiniFeatures are both listed before any engine loads')
check(s.dialog.list.text:find('AuctionatorMiniFeatures',1,true) and s.dialog.list.text:find('Folder: Auctionator',1,true),'Dialog names both installed conflicts')
s.Resolve(true)
check(#disabled==2 and disabled[1]=='Auctionator' and disabled[2]=='AuctionatorMiniFeatures','One action disables all conflicts and leaves unrelated addons enabled')
check(#enabled==2 and enabled[1]=='AuctionatorRemastered_Startup' and enabled[2]=='AuctionatorRemastered','Enable both Remastered modules for next reload')
s,event,loads=scenario({addon('Auctionator',false),addon('AuctionatorMiniFeatures',0),addon('Auctioneer',true),addon('AuctionatorDiagnostics',true),addon('AuctionatorBulkProbe',true),addon('AuctionatorRemastered',true),addon('AuctionatorRemastered_Startup',true)})
check(not s.blocked and #loads==1 and loads[1]=='AuctionatorRemastered','Ignore disabled copies, own modules, diagnostics and unrelated Auctioneer')
event('ADDON_LOADED','AuctionatorRemastered_Startup');check(#loads==1,'Engine loads only once')
s,event,loads=scenario({addon('OddFolder',1,'|cff00ff00Auctionator Fixed|r'),addon('Auctionator_Fixed',1),addon('AuctionatorMiniFeatures',true),addon('Unrelated',1),addon('NoName',false,'Auctionator')})
check(s.blocked and #s.conflicts==3 and #loads==0,'Recognize forks through folder OR colored title')
check(s.conflicts[1].name=='Auctionator_Fixed','Stable case-insensitive ordering')
s,event,loads=scenario({{name='OtherCopy',enabled=true,title='Completely renamed',component='Engine'}})
check(s.blocked and #loads==0,'Detect duplicated Remastered main modules via metadata')
s,event,loads=scenario({{name='Auctionator',enabled=false,loaded=true}})
check(s.blocked and #loads==0,'Loaded-but-now-disabled code still requires reload')
s,event,loads,disabled,enabled=scenario({}, {unknown=true})
check(s.blocked and s.unidentified and #loads==0 and not s.dialog.useRemastered.enabled,'Unknown existing shared globals require manual identification')
s,event,loads,disabled,enabled,_,options=scenario({addon('Auctionator',true)},{combat=true})
check(not s.dialog.useRemastered.enabled and not s.dialog.useOther.enabled)
s.Resolve(true);check(#disabled==0 and not options.reload,'No addon changes or reload in combat')
options.combat=false;event('PLAYER_REGEN_ENABLED');check(s.dialog.useRemastered.enabled)
s.Resolve(false)
check(disabled[1]=='AuctionatorRemastered_Startup' and disabled[2]=='AuctionatorRemastered' and #enabled==0)
check(options.reload==1)
s,event,loads=scenario({}, {fail='MISSING'})
check(s.blocked and s.failure=='MISSING' and s.dialog.shown,'Explain missing main module without retry loops')
s,event,loads,disabled,enabled,labels=scenario({addon('OddFolder',true,'Auctionator |Tbad:200|t\nTitle')})
check(s.dialog.list.text:find('||Tbad',1,true),'Treat addon titles as plain text, not injected textures')
s.dialog:Hide();check(not s.dialog.shown and #loads==0,'Later leaves the conflicting session alone')
s,event,loads,disabled,enabled,labels,options=scenario({addon('Auctionator',true)},{elvUI=true})
check(s.dialog.elvTemplate=='Transparent' and options.skinnedButtons==3 and options.skinnedScrolls==1,'ElvUI styles the dialog, all actions and native scrollbar without loading the engine')
for _,control in ipairs({s.dialog.useRemastered,s.dialog.useOther,s.dialog.later,s.dialog.content}) do
 check(control:GetFrameLevel()>s.dialog:GetFrameLevel(),'Child controls remain above the root background')
end
for _,control in ipairs({s.dialog.useRemastered,s.dialog.useOther,s.dialog.later}) do
 check(control.backdrop:GetFrameLevel()<control:GetFrameLevel(),'ElvUI button backgrounds remain below their text and click frame')
end
check(s.dialog.toplevel==false and s.dialog.later.enabled,'Root cannot auto-raise over its controls; Later stays enabled')
check(#options.messages==1 and options.messages[1]:find('/atrstartup',1,true),'Blocked startup leaves a visible chat entry with recovery command')
s.dialog:Hide();s.ShowWarning()
check(s.dialog.shown and options.skinnedButtons==3,'Reopening is available and styling does not stack')
s.dialog.later.scripts.OnClick()
event('PLAYER_ENTERING_WORLD');options.tick(2)
check(not s.dialog.shown and #loads==0,'Later stays dismissed during subsequent world events')
options.command()
check(s.dialog.shown and #loads==0,'Slash command reopens a dismissed chooser without loading the conflicting engine')
s,event,loads,disabled,enabled,labels,options=scenario({addon('Auctionator',true)},{late=true})
check(s.blocked and s.dialog.shown and #loads==0,'Late startup after PLAYER_LOGIN still opens its conflict warning')
s,event,loads,disabled,enabled,labels,options=scenario({}, {late=true})
check(s.needsReload and #loads==0 and s.dialog.shown,'Late startup requires reload instead of loading the engine after initialization events')
s,event,loads=scenario({addon('Auctionator',true)})
check(s.dialog.backdrop.bgFile:find('UI-DialogBox-Background',1,true),'Standard UI uses its native dialog background')
print('PASS: '..assertions..' startup conflict, renamed fork, disabled/loaded copy, duplicate module, UI choice, combat, failure and event-order checks')
