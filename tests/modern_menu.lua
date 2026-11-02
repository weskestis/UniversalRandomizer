-- Drive the actual setup screens with controller input and a bounded drawing
-- facade. The separate LOVE preview renders these same menu methods.
local root=os.getenv('MOD_SOURCE') or 'mod'
local base=os.getenv('MOD_BASE') or '../randomizer'
local Core=dofile(base..'/core.lua')
local version,generation='red',1
package.loaded['src.core.GameVersion']={get=function() return version end,generation=function() return generation end}
local clock=0;local draws={}
local G={}
function G.newFont(size) return {getWidth=function(_,s) return #s*size*.52 end} end
for _,name in ipairs({'setColor','setFont','push','pop','translate','scale'}) do G[name]=function() end end
function G.print(s,x,y) draws[#draws+1]={text=s,x=x,y=y} end
function G.rectangle() end
love={graphics=G,timer={getTime=function() return clock end}}
local n=0
local function check(v,s) assert(v,s);n=n+1 end
local saved,screens,hooks={},{},{}
local stack={states={}}
function stack:push(s) self.states[#self.states+1]=s end
function stack:top() return self.states[#self.states] end
function stack:pop() return table.remove(self.states) end
local input={pressed={},held={}}
function input:wasPressed(k) return self.pressed[k] end
function input:isDown(k) return self.held[k] end
local game={data={},save={flags={}},stack=stack,input=input}
local mod={game=game,path=root,save={get=function(_,k,d) if saved[k]==nil then return d end;return saved[k] end,set=function(_,k,v) saved[k]=v end},
 content={screens={register=function(_,id,s) screens[id]=s end}},hooks={wrap=function(_,name,fn) hooks[name]=fn end},
 log={error=function(_,fmt,...) error(fmt:format(...)) end},read=function(_,path) local f=assert(io.open(root..'/'..path));local s=f:read('*a');f:close();return s end,ui={}}
function mod.ui.push(g,id,opts) local m=screens[id].new(g,opts);stack:push(m);return m end
local W=dofile(root..'/gen1_world.lua')(Core)
local G2=dofile(root..'/gen2_world.lua')(Core)
local Worlds=dofile(root..'/worlds.lua')(W,G2)
local A=dofile(root..'/adaptive_gyms.lua')(Core,Worlds)
local R=dofile(root..'/randomizer.lua')(mod,Core,{},nil,nil,Worlds,A)
local cleared,committed,ended=0,0,0
R.clear=function() cleared=cleared+1 end
R.preflight=function(g,cfg) return true,nil,R.normalizedConfig(cfg,g) end
R.beginGenerate=function(g,cfg) return {stage=0,cfg=cfg} end
R.stepGenerate=function(h)
 h.stage=h.stage+1;h.label='Stage '..h.stage
 if h.stage==14 then h.done=true;h.active={fingerprint='test',cfg=h.cfg} end
 return h
end
R.commit=function() committed=committed+1;return true end
mod.events={on=function() end}
R.AdaptiveBosses=dofile(root..'/adaptive_bosses.lua')(Core,Worlds,A,R)
R.RunTools=dofile(root..'/run_tools.lua')(mod,Core,R,Worlds,A)
local UI=dofile(root..'/ui.lua')(mod,Core,R)
local function frame(key,dt)
 input.pressed={};if key then input.pressed[key]=true end
 clock=clock+(dt or 1/60)
 local m=stack:top();if m then m:update(dt or 1/60) end
 input.pressed={};m=stack:top();if m then m:draw() end
end
local function selectRow(value)
 local m=stack:top()
 for i,row in ipairs(m.items) do if row.value==value then m.index=i;m:sync();return row end end
 error('missing row '..value)
end
local setup=mod.ui.push(game,UI.SETUP,{onDone=function() ended=ended+1 end})
check(select(1,setup:uiSize())==640 and select(2,setup:uiSize())==360,'Gen1 full modern canvas')
check(setup:drawsWidescreen(),'Gen2 uses explicit compositor path')
selectRow('wilds');frame('a')
local wilds=stack:top();selectRow('wild_randomness');frame('right')
check(wilds.items[1].right=='Truly random','right selects visible unrestricted mode')
for _,row in ipairs(wilds.items) do check(row.value~='wild_evolution' and row.value~='bst_match','unrestricted wilds do not offer conflicting limits') end
frame('select');check(wilds.helpFocus,'SELECT focuses explanation')
local before=wilds.items[1].right;frame('down');frame('right')
check(wilds.helpScroll==wilds.helpMax and wilds.helpMax>0,'manual help can reach the end')
check(wilds.items[1].right==before,'reading does not change settings')
frame('b');check(stack:top()==wilds and not wilds.helpFocus,'B leaves guide before leaving settings')
frame('b');frame()
check(stack:top()==setup and setup.items[2].right()=='Truly random','choice persists and setup summary refreshes')
selectRow('world');frame('a');local world=stack:top();selectRow('random_start');frame('right')
check(world.items[1].right=='Logic','Random Start is first and clearly enabled')
local body=world:helpContent()
check(body:find("Parcel",1,true) and body:find('first lab exit',1,true),'Gen1 portal prerequisite is explained')
frame('b');frame();check(setup.items[4].right()=='Start: Logic','setup shows actual start setting')
selectRow('battle');frame('a');local battle=stack:top();selectRow('trainers');frame('right')
check(battle.items[battle.index].right=='Similar strength','right advances trainer option')
frame('left');check(battle.items[battle.index].right=='Random','left reverses trainer option')
frame('b');selectRow('pokemon');frame('a');local pokemon=stack:top()
selectRow('movesets');frame('right')
check(pokemon.items[pokemon.index].right=='Type bias','Type Bias is selectable')
local guide=pokemon:helpContent()
check(guide:find('65%',1,true) and guide:find('STAB',1,true) and guide:find('Dragon Rage',1,true),'learnset guide explains odds, guarantee and native exception')
frame('select');frame('right')
check(pokemon.helpMax>0 and pokemon.helpScroll==pokemon.helpMax,'full Type Bias guide is reachable')
frame('b')
-- Held navigation uses elapsed real time, not the number of sped-up frames.
pokemon.index=1;input.held.down=true;frame('down');local after=pokemon.index
for i=1,100 do frame(nil,0) end
check(pokemon.index==after,'game speed cannot accelerate held input')
frame(nil,.2);frame(nil,.2);frame(nil,.02)
check(pokemon.index==after+1,'real-time hold repeat advances at controlled cadence')
input.held={};frame('b')
-- Every selectable option includes concrete help, not a clipped footer.
for _,id in ipairs({UI.POKEMON,UI.BATTLE,UI.WORLD,UI.RUN,UI.WILDS,UI.GYMS}) do
 local cfg=R.defaults(game);cfg.seed_mode='MANUAL';cfg.bst_match=true
 local menu=screens[id].new(game,{cfg=cfg})
 for _,row in ipairs(menu.items) do check(row.help and #row.help>30,'setting has substantial help: '..row.label) end
end
-- Independent combat safety must remain reachable through repeated cycles,
-- without changing entrance/progression policy or the displayed actual choice.
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
 version=v;generation=(v=='red' or v=='blue' or v=='yellow') and 1 or 2
 game.data.gen2Encounters=generation==2 and {} or nil
 for _,safety in ipairs({'SAFE','CHAOS'}) do for _,key in ipairs({'left','right','a'}) do
  local cfg=R.defaults(game);cfg.safety=safety;cfg.gym_leaders=safety;cfg.gym_entrances=safety
  local m=mod.ui.push(game,UI.GYMS,{cfg=cfg});selectRow('adaptive_gyms')
  local pos=1;local options={'OFF','SAFE','CHAOS'}
  for step=1,9 do
   pos=((pos-1+(key=='left' and -1 or 1))%3)+1;frame(key)
   check(cfg.adaptive_gyms==options[pos],'adaptive mode never disappears on wrap')
   check(R.normalizedConfig(cfg,game).adaptive_gyms==options[pos],'actual adaptive mode matches menu')
   check(cfg.safety==safety and cfg.gym_leaders==safety and cfg.gym_entrances==safety,'combat choice does not switch world safety')
  end
  frame('select');frame('right')
  check(m.helpMax>0 and m.helpScroll==m.helpMax,'complete adaptive explanation scrolls')
  check(m:helpContent():find('Boss level',1,true) and m:helpContent():find('16 badges',1,true),'scaling and Gen 2 scope explained')
  frame('b');frame('b')
 end end
end
-- Scrolling keeps every word, including long error paths; both directions
-- and automatic scrolling eventually expose the final line.
version='red';generation=1;game.data.gen2Encounters=nil
local Menu=dofile(root..'/menu.lua')
local token=string.rep('long_error_path_',30)..'END_OF_ERROR'
local m=Menu.new(game,'Failure details',{{label='Retry',help=token}})
stack:push(m);frame();check(m.helpMax>0,'long errors overflow into scrollable guide')
local joined=table.concat(m.helpLines,'')
check(joined==token,'wrapping preserves the complete long error')
for _,line in ipairs(m.helpLines) do check(G.newFont(14):getWidth(line)<=220,'each guide line stays inside panel') end
for i=1,31 do frame(nil,.2) end
check(m.helpScroll>0,'idle explanations automatically scroll')
frame('select');frame('right');check(m.helpLines[#m.helpLines]:find('END_OF_ERROR',1,true),'end of error remains readable')
frame('b');frame('b')
local utf=Menu.new(game,'Unicode error',{{label='Read',help=string.rep('Pokémon_',60)}})
utf:helpLayout()
check(table.concat(utf.helpLines,'')==string.rep('Pokémon_',60),'Unicode text is preserved')
for _,line in ipairs(utf.helpLines) do
 local b=line:byte(1);check(not b or b<128 or b>=192,'wrapped lines start on a whole glyph')
end
-- Back must not silently play vanilla or consume the intro callback.
frame('b');local confirmation=stack:top()
check(confirmation~=setup and cleared==0 and ended==0,'Back opens explicit vanilla confirmation')
frame('b');check(stack:top()==setup and cleared==0,'canceling confirmation keeps setup')
-- Validation is locked against Back/re-entry until its one handle finishes.
selectRow('begin');frame('a');frame('b');frame('a')
check(stack:top()==setup and setup:isLocked() and ended==0,'validation cannot be dismissed or restarted')
for i=1,14 do hooks['input.step'](function() end,game,1/60) end
check(committed==1 and ended==1 and stack:top()==nil,'validation commits and releases intro exactly once')
-- The explicit vanilla choice still works.
mod.ui.push(game,UI.SETUP,{onDone=function() ended=ended+1 end});frame('b');selectRow('vanilla');frame('a')
check(cleared==1 and ended==2 and stack:top()==nil,'confirmed vanilla closes both menus exactly once')
-- Failed validation belongs to its row; it must not replace the World/items
-- guide while the player is trying to understand or correct the settings.
saved.last_config={badge_logic='LEGACY'}
local failure='SAFE key/HM logic requires Badges: Vanilla or Safe. '..string.rep('Details remain readable. ',20)
R.preflight=function(g,cfg)
 check(cfg.badge_logic=='CHECKED','new setup upgrades old preferences without changing Continue')
 return false,failure
end
local failed=mod.ui.push(game,UI.SETUP,{})
selectRow('begin');frame('a')
check(failed:helpContent()==failure and not failed:isLocked(),'preflight failure is readable and leaves controls active')
selectRow('world');frame()
check(failed:helpContent():find('Random Start, items',1,true) and not failed:helpContent():find(failure,1,true),'World/items guide is not replaced by a stale validation error')
selectRow('begin');frame('select');frame('right')
check(failed.helpMax>0 and failed.helpScroll==failed.helpMax,'failed validation retains full scrollable details')
frame('b')
R.preflight=function(g,cfg) return true,nil,R.normalizedConfig(cfg,g) end
R.stepGenerate=function(h) h.done=true;h.error=failure;return h end
frame('a');hooks['input.step'](function() end,game,1/60);frame()
check(failed:helpContent():find(failure,1,true),'staged generation errors remain visible on retry')
selectRow('run');frame()
check(failed:helpContent():find('SAFE checks supported progression',1,true),'Safety/seed guide remains available after staged failure')
-- Reproduce the reported second-lap loss of Logical random. Exercise actual
-- controller inputs in both directions, with both initial safety policies.
local modes={'UNCHANGED','SHUFFLE','RANDOM','LOGIC_RANDOM','CHAOS'}
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
 version=v;generation=(v=='red' or v=='blue' or v=='yellow') and 1 or 2
 game.data.gen2Encounters=generation==2 and {} or nil
 for _,initial in ipairs({'SAFE','CHAOS'}) do
  for _,key in ipairs({'right','a','left'}) do
   local cfg=R.defaults(game);cfg.safety=initial;cfg.random_start='OFF';cfg.field_items='UNCHANGED'
   local world=mod.ui.push(game,UI.WORLD,{cfg=cfg});selectRow('field_items')
   local pos=1
   for lap=1,3 do
    for step=1,#modes do
     pos=((pos-1+(key=='left' and -1 or 1))%#modes)+1
     frame(key)
     check(cfg.field_items==modes[pos],'every field item mode remains reachable on every lap: '..v..' '..initial..' '..key..' '..lap)
     check(R.normalizedConfig(cfg,game).field_items==cfg.field_items,'visible field mode survives validation normalization')
     if cfg.field_items=='LOGIC_RANDOM' then
      check(cfg.safety=='SAFE' and cfg.progression_items,'Logical random selects checked key/HM placement')
      check(world.items[world.index].right=='Logical random','Logical random label matches the actual choice')
     elseif cfg.field_items=='CHAOS' then check(cfg.safety=='CHAOS','Chaos selects unchecked progression') end
    end
   end
   frame('b')
   world=mod.ui.push(game,UI.WORLD,{cfg=cfg});selectRow('field_items')
   for step=1,3 do frame('right') end
   check(cfg.field_items=='LOGIC_RANDOM','Logical random is available after closing and reopening settings')
   frame('b')
  end
 end
 -- Logic Random Start requires a graph item mode. Both legal choices must
 -- remain selectable in either direction, without a permanent Chaos trap.
 for _,key in ipairs({'right','a','left'}) do
  local cfg=R.defaults(game);cfg.safety='CHAOS';cfg.field_items='CHAOS'
  local world=mod.ui.push(game,UI.WORLD,{cfg=cfg});selectRow('random_start');frame('right')
  check(cfg.random_start=='LOGIC' and cfg.safety=='SAFE' and cfg.field_items=='LOGIC_RANDOM','explicit Logic start selects checked progression')
  selectRow('field_items')
  for step=1,8 do
   frame(key)
   local expected=step%2==1 and 'CHAOS' or 'LOGIC_RANDOM'
   check(cfg.field_items==expected,'Logic start cycles both supported item modes: '..key)
   check(R.normalizedConfig(cfg,game).field_items==expected,'Logic start displays the mode validation will use')
  end
  frame('b');mod.ui.push(game,UI.RUN,{cfg=cfg});selectRow('safety');frame('right')
  check(cfg.safety=='CHAOS' and cfg.field_items=='CHAOS','explicit safety switch updates graph mode')
  frame('left');check(cfg.safety=='SAFE' and cfg.field_items=='LOGIC_RANDOM','switching safety back restores logical placement')
  frame('b');world=mod.ui.push(game,UI.WORLD,{cfg=cfg});selectRow('random_start');frame('left')
  check(cfg.random_start=='OFF','Logic start can be disabled')
  selectRow('field_items');frame('left')
  check(cfg.field_items=='RANDOM','turning Logic start off restores the ordinary item choices')
  frame('b')
 end
end
-- The Keys + HMs row exposes its effective mode instead of a permanently
-- locked On toggle. Exercise every lap and direction, including the original
-- screenshot combination (normal start + Chaos field items).
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
 version=v;generation=(v=='red' or v=='blue' or v=='yellow') and 1 or 2
 game.data.gen2Encounters=generation==2 and {} or nil
 for _,start in ipairs({'OFF','LOGIC'}) do for _,key in ipairs({'a','left','right'}) do
  local cfg=R.defaults(game);cfg.random_start=start;cfg.field_items='CHAOS';cfg.safety='CHAOS';cfg.progression_items=true
  if start=='LOGIC' then cfg.badges='SAFE' end
  local menu=mod.ui.push(game,UI.WORLD,{cfg=cfg});selectRow('progression_items')
  local modes=start=='LOGIC' and {'SAFE','CHAOS'} or {'OFF','SAFE','CHAOS'}
  local pos=#modes
  for step=1,#modes*3 do
   pos=((pos-1+(key=='left' and -1 or 1))%#modes)+1;frame(key)
   local mode=modes[pos]
   check(cfg.progression_items==(mode~='OFF'),'Keys/HMs inclusion matches visible mode')
   check(menu.items[menu.index].right==({OFF='Off',SAFE='Safe',CHAOS='Chaos'})[mode],'Keys/HMs has selectable Off/Safe/Chaos labels')
   if mode~='OFF' then
    check(cfg.safety==mode and cfg.field_items==(mode=='SAFE' and 'LOGIC_RANDOM' or 'CHAOS'),'Keys/HMs reconciles field placement and safety')
   else check(cfg.field_items=='RANDOM','Off leaves ordinary items randomized') end
   check(R.normalizedConfig(cfg,game).progression_items==cfg.progression_items,'Key/HM selection survives validation')
  end
  frame('b')
 end end
 -- Sweep every other visible row through several laps. Compare the actual
 -- menu config to normalization after each controller press, not only once.
 local lengths={safety=2,field_items=5,gift_items=2,random_start=3,badges=3}
 for _,d in ipairs(dofile('tests/support/settings_domains.lua')) do lengths[d[1]]=#d[2] end
 for _,id in ipairs({UI.POKEMON,UI.BATTLE,UI.WORLD,UI.RUN,UI.WILDS}) do
  local initial=R.defaults(game);initial.bst_match=true;initial.seed_mode='MANUAL'
  local probe=screens[id].new(game,{cfg=initial});local keys={}
  for _,row in ipairs(probe.items) do if lengths[row.value] and row.value~='manual_seed' and row.value~='bst_difference' then keys[#keys+1]=row.value end end
  for _,setting in ipairs(keys) do for _,button in ipairs({'right','left','a'}) do
   local cfg=R.defaults(game);cfg.bst_match=true;cfg.seed_mode='MANUAL'
   mod.ui.push(game,id,{cfg=cfg});selectRow(setting)
   for step=1,lengths[setting]*3 do
    frame(button);local norm=R.normalizedConfig(cfg,game)
    check(norm[setting]==cfg[setting],'visible setting remains the actual setting: '..setting)
    check(not (cfg.safety=='SAFE' and cfg.badges=='CHAOS'),'menu never leaves Safe with Chaos badges')
    check(cfg.random_start~='LOGIC' or (cfg.badges=='SAFE' and cfg.progression_items),'Logic start dependencies remain enabled')
   end
   frame('b')
  end end
 end
end
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
 version=v;generation=(v=='red' or v=='blue' or v=='yellow') and 1 or 2
 game.data.gen2Encounters=generation==2 and {} or nil
 saved.last_config=nil
 local setup=screens[UI.SETUP].new(game,{})
 local found=false;for _,row in ipairs(setup.items) do if row.value=='gyms' then found=true end end
 check(found,'world extension appears in all six native games')
 if found then
  for key,values in pairs(W.choices) do for _,button in ipairs({'a','right','left'}) do
   local cfg=R.defaults(game);mod.ui.push(game,UI.GYMS,{cfg=cfg});selectRow(key)
   for i=1,#values*3 do
    frame(button);local norm=R.normalizedConfig(cfg,game)
    check(cfg[key]==norm[key],'new setting survives normalization: '..key)
    check(stack:top().items[stack:top().index].help:len()>30,'new setting has complete scrolling guide')
    if W.enabled(cfg) then
     check(cfg.progression_items and (cfg.field_items=='LOGIC_RANDOM' or cfg.field_items=='CHAOS'),'world settings require joint item plan')
     for _,k in ipairs({'gym_leaders','gym_entrances','dungeon_entrances'}) do
      check(cfg[k]=='OFF' or cfg[k]==cfg.safety,'all active shuffles share safety')
     end
    end
   end
   frame('b')
  end end
  local cfg=R.defaults(game);cfg.gym_entrances='SAFE'
  mod.ui.push(game,UI.WORLD,{cfg=cfg});selectRow('progression_items')
  for i=1,8 do frame('right');check(cfg.progression_items,'keys cannot be disabled while world shuffled') end
  cfg.safety='SAFE';cfg.gym_entrances='SAFE';cfg.mart_safety=true;selectRow('mart_safety');frame('right')
  check(cfg.mart_safety,'Safe world cannot disable shop essentials')
  frame('b');mod.ui.push(game,UI.RUN,{cfg=cfg});selectRow('safety');frame('left')
  check(cfg.gym_entrances==cfg.safety,'global safety updates entrance label');frame('b')
 end
end
print('PASS: '..n..' modern menu navigation, help, scrolling and validation checks')

version='red';generation=1;game.data.gen2Encounters=nil;saved.last_config=nil;stack.states={}
local requestedSeed,exactSeed
R.beginGenerate=function(g,cfg,seed,options) requestedSeed=seed;exactSeed=options and options.exactSeed;return {stage=0,cfg=cfg} end
local cfg=R.defaults(game);cfg.adaptive_bosses='SAFE'
local clipboard=R.RunTools.exportCode({game=game,version='red',seed=98765,cfg=cfg})
love.system={getClipboardText=function() return clipboard end,setClipboardText=function(v) clipboard=v end}
local s=mod.ui.push(game,UI.SETUP,{})
selectRow('tools');frame('a');selectRow('import');frame('a')
check(stack:top().title=='Import run','clipboard import opens review')
selectRow('apply');frame('a');frame('b');selectRow('begin');frame('a')
check(requestedSeed==98765 and exactSeed,'import uses exact accepted seed even when original seed mode was Auto')
for i=1,14 do hooks['input.step'](function() end,game,1/60) end
stack.states={};s=mod.ui.push(game,UI.SETUP,{})
selectRow('tools');frame('a');selectRow('presets');frame('a')
local list=stack:top();list.index=2;frame('a');check(stack:top().title=='Everything shuffled safely','preset opens change preview')
selectRow('back');frame('a');check(stack:top()==list,'cancel preview leaves settings unchanged')
frame('b');frame('b');selectRow('battle');frame('a');selectRow('adaptive_bosses')
for i=1,6 do frame('right');check(stack:top().items[stack:top().index].help:find('rival',1,true),'story setting has explanatory guide') end
print('PASS: '..n..' modern menu checks including presets and exact-seed import')
