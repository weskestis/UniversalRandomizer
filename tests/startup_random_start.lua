-- Cold title-screen startup plus recovered Random Start integration. Native
-- scripts/VM/hook dispatch come from the pinned host; map data are fixtures.
local root=os.getenv('MOD_SOURCE') or 'mod'
local base=os.getenv('MOD_BASE') or '../randomizer'
local host=os.getenv('HOST_SOURCE') or '../host-source'
package.path=host..'/?.lua;'..package.path
unpack=table.unpack or unpack
local gen,version=1,'red'
package.loaded['src.core.GameVersion']={get=function() return version end,generation=function() return gen end,isYellow=function() return version=='yellow' end}
package.loaded['src.render.TextBox']={new=function(g,text,done,opts) return {text=text,done=done,opts=opts} end,soundOpts=function() return {} end}
local Core=dofile(base..'/core.lua')
local I=dofile(root..'/progression_items.lua')(Core)
local L=dofile(root..'/logic_graph.lua')(Core)
local Hooks=require('src.mods.Hooks');local Events=require('src.mods.Events')
local hooks,events=Hooks.new(),Events.new()
local saved,removed={},{}
local mod={hooks={wrap=function(_,n,f,p) return hooks:wrap(n,f,p,'universal_randomizer') end},
 events={on=function(_,n,f,p) return events:on(n,f,p,'universal_randomizer') end},
 save={get=function(_,k,d) if saved[k]==nil then return d end;return saved[k] end,set=function(_,k,v) saved[k]=v end},
 world={spawnNpc=function() error('guard spawned') end,removeNpc=function(_,id) removed[id]=true end},
 log={error=function(_,fmt,...) error(fmt:format(...)) end}}
local R=dofile(root..'/randomizer.lua')(mod,Core,dofile(base..'/adapters.lua'),I,L)
local count=0
local function check(ok,msg) assert(ok,msg);count=count+1 end
local MS=require('src.script.MapScripts')
check(MS.baseTalk('ROUTE_1','TEXT_ROUTE1_YOUNGSTER1')==nil,'cold registry starts empty')
I.installHardcoded(mod,R)
check(MS.baseTalk('ROUTE_1','TEXT_ROUTE1_YOUNGSTER1')==nil,'mod entry does not load scripts before data is ready')
events:emit('game.ready',{})
check(type(MS.baseTalk('ROUTE_1','TEXT_ROUTE1_YOUNGSTER1'))=='function','game.ready installs Route 1 before setup')
local first=MS.baseTalk('ROUTE_1','TEXT_ROUTE1_YOUNGSTER1')
events:emit('game.ready',{})
check(MS.baseTalk('ROUTE_1','TEXT_ROUTE1_YOUNGSTER1')==first,'ready event is idempotent')
local old=R.normalizedConfig({protection_guards=true,level_mode='HYBRID'})
check(old.protection_guards==false and old.level_mode=='PERCENTAGE','obsolete saved settings cannot enable guards or party scaling')
R.installHooks()
dofile(root..'/gift_items.lua')(mod,Core,R,I)
require('src.mods.Runtime').install(events,hooks)

local function fixture(g,v)
 gen,version=g,v
 local game={data={items={},pokemon={},maps={},moves={},field={flyWarps={},hiddenItems={}}},
   save={party={},inventory={},flags={},player={name='TEST',badges={}},pokedex={owned={}}},
   stack={rows={},push=function(self,row) self.rows[#self.rows+1]=row end}}
 if g==2 then game.data.gen2Maps={};game.data.gen2Encounters={};game.data.gen2Scripts={} end
 game.mods={hooks=hooks,events=events}
 local maps=g==1 and game.data.maps or game.data.gen2Maps
 local function map(id) maps[id]=maps[id] or {id=id,objects={},bgEvents={},warps={},connections={}};return maps[id] end
 local index=0
 local function item(id)
  if game.data.items[id] then return end
  index=index+1
  local hm=id:match('^HM_(.+)');local tm=id:match('^TM_(.+)')
  game.data.items[id]={index=index,name=id,price=100,keyItem=not hm and not tm,pocket=g==2 and (hm or tm) and 'TM_HM' or nil}
  if hm or tm then
   game.data.items[id].machine={kind=hm and 'HM' or 'TM',move=hm or tm}
   game.data.items[id].teaches=hm or tm;game.data.moves[hm or tm]={power=40,type='NORMAL'}
  end
 end
 for _,p in ipairs(I.catalog(g,v)) do
  item(p.item);local m=map(p.maps[1])
  if p.kind=='field' then m.objects[#m.objects+1]=g==1 and {item=p.item} or {itemball={item=p.item}} end
 end
 for _,d in ipairs(R._LOGIC_ITEM_DEFS[g]) do
  item(d.item);local m=map(d.map)
  if d.kind=='field' or d.kind=='auto' then
   local exists=false;for _,o in ipairs(m.objects) do if o.item==d.item or (o.itemball and o.itemball.item==d.item) then exists=true end end
   if not exists then m.objects[#m.objects+1]=g==1 and {item=d.item} or {itemball={item=d.item}} end
  end
 end
 for _,id in ipairs({'POKE_BALL','POTION','FRESH_WATER','ANTIDOTE','CARBOS'}) do item(id);game.data.items[id].keyItem=false;game.data.items[id].index=nil end
 local ordinary=map('ROUTE_1')
 for i=1,20 do local id='FILLER_'..i;item(id);game.data.items[id].keyItem=false;game.data.items[id].index=nil;ordinary.objects[#ordinary.objects+1]={item=id} end
 -- Required native field TM coverage and enough ordinary authored checks.
 for i=1,50 do
  local id='TM_'..i;item(id);game.data.items[id].machine.number=i;game.data.items[id].index=nil
  ordinary.objects[#ordinary.objects+1]={item=id}
 end
 -- Cinnabar has two independently reachable Mansion pickups before Surf.
 map('POKEMON_MANSION_1F').objects={{item='CARBOS'},{item='ANTIDOTE'}}
 for _,id in ipairs(L.logicStarts(g)) do
  local m=map(id);local center=id..'_POKECENTER_1F'
  m.warps={{destMap=center,x=4,y=5}};map(center).objects={{sprite='NURSE',x=3,y=1}}
  game.data.field.flyWarps[id]={x=4,y=6}
  for _,dest in ipairs(L.policy(g,id) or {}) do map(dest);m.connections[dest]={mapId=dest} end
 end
 for i,id in ipairs({'ROUTE_20','ROUTE_21'}) do map(id);map('CINNABAR_ISLAND').connections[id]={mapId=id} end
 if g==1 then game.data.text_pointers={SAFFRON_MART={CLERK={mart={'POKE_BALL','POTION','ANTIDOTE'}}}} end
 if g==2 then for _,m in pairs(maps) do for _,o in ipairs(m.objects) do if o.item then o.itemball={item=o.item};o.item=nil end end end end
 local starters=g==1 and {'BULBASAUR','CHARMANDER','SQUIRTLE'} or {'CHIKORITA','CYNDAQUIL','TOTODILE'}
 for dex=1,(g==1 and 151 or 251) do
  game.data.pokemon[starters[dex] or ('MON_'..dex)]={index=dex,dex=dex,types={'NORMAL'},baseStats={hp=50,attack=50,defense=50,speed=50,special=50,specialAttack=50,specialDefense=50},level1Moves={'TACKLE'},tmhm={},evolutions={}}
 end
 game.data.moves.TACKLE={index=33,power=40,type='NORMAL'}
 for i=1,25 do game.data.moves['MOVE_'..i]={index=i,power=40,type='NORMAL'} end
 game.overworld={map={id=g==1 and 'OAKS_LAB' or 'ELMS_LAB'},npcs={}}
 if g==2 then game.world=game.overworld end
 mod.game=game
 return game,starters
end
local function config()
 local cfg=R.defaults();cfg.random_start='LOGIC';cfg.badges='SAFE';cfg.gift_items='RANDOM'
 cfg.starters='UNCHANGED';cfg.statics='UNCHANGED';cfg.trainers='UNCHANGED';cfg.mart_safety=false
 return cfg
end
local function generate(game,cfg,seed)
 local state,why=R.beginGenerate(game,cfg,seed);check(state~=nil,why or 'preflight')
 for step=1,14 do R.stepGenerate(state) end
 check(state.active~=nil,state.error or ('stage '..tostring(state.stage)))
 return state.active
end

-- Reproduce the screenshot's first-title-screen validation with actual callbacks.
local game=fixture(1,'red');local cfg=config();cfg.random_start='OFF';cfg.field_items='SHUFFLE';cfg.badges='VANILLA'
local a=generate(game,cfg,99)
check(a.itemPlan and a.itemPlan.byGift['ROUTE1|POTION'],'cold setup retains Route 1 reward')
check(R.installGen1HardcodedBridges(game),'native static bridges initialize after registry')

local seedsByStart={}
for _,v in ipairs({'red','crystal'}) do
 local g=v=='red' and 1 or 2
 local game,starters=fixture(g,v);local cfg=config();local seen={}
 for seed=1,80 do
  local a=generate(game,cfg,seed);local start=a.progression.start.id
  seen[start]=true;seedsByStart[start]=seed
  check(a.cfg.protection_guards==false,'no guards after normalization')
  check(a.itemPlan.graph and R._validateLogicItemPlan(game,a.cfg),'one graph owns key/HM placement')
  check(I.validate(game),'award bridge accepts graph placement')
  if start=='CIANWOOD_CITY' then
   check(a.progression.certificate.kind=='NATIVE_HM_ESCAPE','Cianwood uses native Fly reward')
   check(a.itemPlan.byGift['CIANWOODCITY|HM_FLY'].target=='HM_FLY','native Fly source pinned for escape')
  end
  if start=='CINNABAR_ISLAND' then check(a.progression.certificate.logic,'Cinnabar HM is a solver placement') end
 end
 for _,id in ipairs(L.logicStarts(g)) do check(seen[id],'seed matrix covers '..id) end
end

-- Runtime guards, portal timing, local respawn, and player-independent levels.
for _,start in ipairs({'CINNABAR_ISLAND','SAFFRON_CITY','CIANWOOD_CITY','BLACKTHORN_CITY'}) do
 saved={};local g=(start=='CINNABAR_ISLAND' or start=='SAFFRON_CITY') and 1 or 2
 local game,starters=fixture(g,g==1 and 'red' or 'crystal')
 local a=generate(game,config(),assert(seedsByStart[start]));check(R.commit(a),'commit seed')
 local function warp(dest)
  return hooks:call('warp.destination',function(dm,x,y) return dm,x,y end,dest,1,1,{game=game})
 end
 check(warp('PALLET_TOWN')=='PALLET_TOWN','portal waits for starter')
 game.save.party={{species=starters[1],level=5,moves={}}}
 if g==1 then
  check(warp('PALLET_TOWN')=='PALLET_TOWN','Gen1 waits for actual Pokedex bootstrap')
  game.save.flags.EVENT_GOT_POKEDEX=true
 else a.randomStartArmed=true end
 local flags=Core.copy(game.save.flags)
 check(warp('HOME')==start,'portal reaches selected start')
 for k,v in pairs(game.save.flags) do check(flags[k]==v,'portal does not manufacture story flag '..k) end
 check(not game.save.inventory.HM_SURF and not game.save.inventory.HM_FLY,'portal does not preload HMs')
 check(not game.save.party[1].moves[1],'portal does not preteach escape moves')
 if g==1 then check(game.save.lastHeal.map==start..'_POKECENTER_1F','Gen1 respawn stays in local Center')
 else check(game.save.blackoutMap==start,'Gen2 respawn stays in starting town') end
 game.overworld.map.id=start;R.onMapEntered(game,start,'HOME')
 a.routeGuardIds={'legacy-guard'};check(R.refreshRouteRoadblocks(game,start),'guard cleanup')
 check(removed['legacy-guard'],'legacy guard removed')
 check(not R.routeConnectionBlocked(game,start,'ROUTE_21'),'no hidden exit blocking')
 if start=='CINNABAR_ISLAND' then check(a.routeState.target~='ROUTE_21' and a.routeState.target~='ROUTE_20','no water hint before Surf') end
 local low=R._percentageRouteBaselineMax(a,start,'wild',false)
 game.save.party[1].level=80
 check(low==R._percentageRouteBaselineMax(a,start,'wild',false),'party level cannot change world baseline')
 check(warp('NEXT_MAP')=='NEXT_MAP','portal runs once')
 check(warp(start..'_POKECENTER_1F')==start..'_POKECENTER_1F','normal Center visit preserved')
 check(not a.randomStartRespawnLocked,'normal Center visit releases temporary respawn lock')
end
-- Reference snapshots were captured by running the published 1.4.1 installer
-- against these same fixtures, before applying the update. Include field slots,
-- start and badge awards so Continue cannot silently regenerate a new world.
local function stable(value)
 if type(value)~='table' then return tostring(value) end
 local keys={};for k in pairs(value) do if k~='reserved' then keys[#keys+1]=k end end
 table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
 local rows={};for _,k in ipairs(keys) do rows[#rows+1]=tostring(k)..'='..stable(value[k]) end
 return '{'..table.concat(rows,',')..'}'
end
local oldSnapshots={
 red={[1]=2264764137,[3]=1063823770,[6]=1411149662,[8]=3015212445,[10]=1695924905,[12]=4168424605},
 crystal={[1]=3457805906,[2]=3126596708,[3]=953474531,[4]=1804461195,[5]=653349136,[6]=1948575395,[7]=3142772225},
}
for v,seeds in pairs(oldSnapshots) do
 for seed,expected in pairs(seeds) do
  local g=v=='red' and 1 or 2;local game=fixture(g,v)
  local cfg=R.defaults();cfg.start_logic=nil;cfg.random_doors=nil;cfg.sphere_curve=nil
  cfg.protection_guards=true;cfg.level_mode='PROGRESSION'
  cfg.random_start='LOGIC';cfg.badges='SAFE';cfg.field_items='SHUFFLE';cfg.progression_items=false
  cfg.gift_items='RANDOM';cfg.starters='UNCHANGED';cfg.statics='UNCHANGED';cfg.trainers='UNCHANGED';cfg.mart_safety=false
  saved={seed=seed,config=cfg,version=v,random_start_used=true}
  game.save.inventory.POTION=3;game.save.flags.REAL_STORY_PROGRESS=true
  local a,why=R.activateSaved(game);check(a~=nil,why)
  check(a.cfg.start_logic=='LEGACY' and a.cfg.field_items=='SHUFFLE','Continue retains legacy placement mode')
  local signature=stable({start=a.progression.start.id,badges=a.badgePlan,items=a.itemPlan,fields=game.data.gen2Maps or game.data.maps})
  check(Core.hash(signature)==expected,'1.4.1 placements retained: '..v..' '..seed)
  check(game.save.inventory.POTION==3 and game.save.flags.REAL_STORY_PROGRESS,'Continue preserves player inventory/story state')
  check(a.randomStartUsed and not a.cfg.protection_guards,'Continue cannot re-run portal or enable guards')
 end
end
for _,v in ipairs({'red','crystal'}) do
 local game=fixture(v=='red' and 1 or 2,v);local cfg=config();cfg.safety='CHAOS'
 local a=generate(game,cfg,10)
 check(a.cfg.field_items=='CHAOS' and a.progression.certificate.checked==false,'CHAOS bypasses start proof')
 check(#a.logicItemPlan.sequence==0,'CHAOS does not use restrictive progression fill')
 cfg.safety='SAFE';cfg.field_items='CHAOS'
 check(R.normalizedConfig(cfg).field_items=='LOGIC_RANDOM','SAFE cannot inherit unchecked item placement')
end
-- The solved placement must be the item the native award code actually gives.
local function drain(game)
 for i=1,40 do
  local box=table.remove(game.stack.rows)
  if not box then return end
  if box.opts and box.opts.choice then box.opts.choice(true) elseif box.done then box.done() end
 end
 error('native dialogue did not finish')
end
do
 local game=fixture(1,'red');local a=generate(game,config(),seedsByStart.SAFFRON_CITY)
 game.data.text={}
 local stock=game.data.text_pointers.SAFFRON_MART.CLERK.mart;local water=false
 for _,id in ipairs(stock) do if id=='FRESH_WATER' then water=true end end
 check(water and not game.save.flags.EVENT_GAVE_GUARDS_DRINK,'Saffron supplies a drink without granting the story flag')
 game.save.inventory.FRESH_WATER=1
 MS.baseTalk('ROUTE_6_GATE','TEXT_ROUTE6GATE_GUARD')(game,{},nil,function() end);drain(game)
 check(game.save.flags.EVENT_GAVE_GUARDS_DRINK and not game.save.inventory.FRESH_WATER,'native Saffron guard consumes drink and opens gates')
 local gift=a.itemPlan.byGift['ROUTE16FLYHOUSE|HM_FLY'];check(gift~=nil,'graph binds native Fly gift')
 game.data.constants={bagSize=1};game.data.items.BLOCKER={name='BLOCKER'};game.save.inventory={BLOCKER=1}
 MS.baseTalk('ROUTE_16_FLY_HOUSE','TEXT_ROUTE16FLYHOUSE_BRUNETTE_GIRL')(game,{},nil,function() end);drain(game)
 check(game.save.pcItems and game.save.pcItems[gift.target]==1,'native graph award survives a full bag with its exact solved target')
 MS.baseTalk('ROUTE_16_FLY_HOUSE','TEXT_ROUTE16FLYHOUSE_BRUNETTE_GIRL')(game,{},nil,function() end);drain(game)
 check(game.save.pcItems[gift.target]==1,'native graph gift remains one-time')
 local sample=R.itemGiftForRun(a,'POTION','ROUTE_1|native|route1-gift','ROUTE_1')
 check(sample~='POTION','fixture exercises a changed ordinary native gift')
 local before=(game.save.pcItems or {})[sample] or 0
 MS.baseTalk('ROUTE_1','TEXT_ROUTE1_YOUNGSTER1')(game,{},nil,function() end);drain(game)
 check(game.save.pcItems[sample]==before+1 and game.save.flags.EVENT_GOT_POTION_SAMPLE,'graph run randomizes the actual native Route 1 sample')
end
if jit then
 local game=fixture(2,'crystal');local a=generate(game,config(),seedsByStart.CIANWOOD_CITY)
 local gift=a.itemPlan.byGift['CIANWOODCITY|HM_FLY']
 local Vm=require('src.script.gen2.Vm');local Flags=require('src.world.gen2.Events');local flags=Flags.new()
 local awards={}
 local vm=Vm.new({GIFT={{op='giveitem',item=game.data.items.HM_FLY.index,quantity=1},{op='setevent',event=99},{op='end'}}},{},flags,{
  mapId=function() return 'CIANWOOD_CITY' end,
  giveItem=function(id,qty) awards[#awards+1]={id,qty};return false end,
  showText=function(_,done) done() end,
 })
 vm:start('GIFT')
 check(not vm:running() and flags:get(99),'native graph VM completes after PC recovery')
 check(#awards==1 and awards[1][1]==game.data.items[gift.target].index,'native graph VM awards the planned HM once')
 check(game.save.pcItems and game.save.pcItems.HM_FLY==1,'Cianwood native Fly gift survives bag refusal')
end
print(('PASS: %d startup and Random Start checks'):format(count))
