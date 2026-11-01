local modRoot=os.getenv('MOD_SOURCE') or 'mod'
local baseRoot=os.getenv('MOD_BASE') or '../randomizer'
local hostRoot=os.getenv('HOST_SOURCE') or '../host-source'
package.path=hostRoot..'/?.lua;'..package.path
unpack=table.unpack or unpack
local generation=1
package.loaded['src.core.GameVersion']={get=function() return generation==1 and 'red' or 'gold' end}
local Core=dofile(baseRoot..'/core.lua')
local Hooks=require('src.mods.Hooks')
local Events=require('src.mods.Events')
local hooks,events=Hooks.new(),Events.new()
local saveValues={}
local mod={hooks={wrap=function(_,name,fn,p) return hooks:wrap(name,fn,p,'universal_randomizer') end},
 events={on=function(_,name,fn,p) return events:on(name,fn,p,'universal_randomizer') end},
 save={get=function(_,k,d) local v=saveValues[k]; if v==nil then return d end; return v end,set=function(_,k,v) saveValues[k]=v end},
 log={error=function(_,fmt,...) error(fmt:format(...)) end}}
local R=dofile(modRoot..'/randomizer.lua')(mod,Core,{},nil)
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1 end
local function mon(index,b,gen)
 return {index=index,dex=index,types={'NORMAL'},baseStats={hp=b,attack=50,defense=50,speed=50,
 special=gen==1 and 50 or nil,specialAttack=gen==2 and 50 or nil,specialDefense=gen==2 and 50 or nil}}
end
local game={data={pokemon={},items={},maps={}},save={party={{level=20}}},world={map={id='ROUTE_1'}}}
mod.game=game; game.mods={hooks=hooks,events=events}
for i=1,151 do game.data.pokemon['MON_'..i]=mon(i,i+5,1) end
local cfg=R.defaults(); cfg.bst_match=true; cfg.allow_legendaries=true
check(cfg.bst_difference==50,'default BST tolerance is 50')
check(cfg.mart_safety==true,'new runs keep balls in marts')
check(R.normalizedConfig({}).bst_match==false,'old runs keep BST disabled')
check(R.normalizedConfig({}).gift_items=='UNCHANGED','old runs keep gifts unchanged')
check(R.normalizedConfig({}).mart_safety==false,'old missing Mart Safety stays disabled')
for _,value in ipairs({-12,0,50,500,800}) do
 check(R.normalizedConfig({bst_difference=value}).bst_difference==math.max(0,math.min(500,value)),'clamped BST range')
end
for _,limit in ipairs({0,1,50,500}) do
 cfg.bst_difference=limit
 for seed=1,80 do
  for _,mode in ipairs({'RANDOM','SIMILAR','THEMED'}) do
   local target=R.selectSpecies(game,cfg,seed,'test','MON_75',mode)
   check(R.withinBst(game,cfg,'MON_75',target),'selected species respects '..limit)
   check(target==R.selectSpecies(game,cfg,seed,'test','MON_75',mode),'selection deterministic')
  end
 end
end
cfg.bst_difference=0
check(R.selectSpecies(game,cfg,1,'empty','MON_75','RANDOM',function() return false end)=='MON_75','empty pool keeps source')
local starters=R.buildStarterMap(game,cfg,7,{starters={'MON_1','MON_2','MON_3'}})
for source,target in pairs(starters) do check(R.withinBst(game,cfg,source,target),'zero-BST starter fallback') end
local def=game.data.pokemon.MON_1; def.baseStats.specialAttack=120; def.baseStats.specialDefense=100
check(R.speciesBst(game,'MON_1')==206,'Gen1 split-special aliases are not double-counted')
generation=2; game.data.gen2Encounters={}
check(R.speciesBst(game,'MON_1')==376,'Gen2 uses split Special stats')
generation=1; game.data.gen2Encounters=nil

local a={game=game,cfg=Core.copy(cfg),seed=41,generation=1,version='red',fingerprint='test',
 wildMap={},areaPools={},areaUsed={},areaCounters={},areaBaseSpecies={},areaExtraSpecies={},routeState={visited={}}}
a.cfg.area_encounters='FULL_SLOT_RANDOM'; a.cfg.extra_species=0; a.cfg.bst_difference=50
a.cfg.random_start='OFF'; a.cfg.level_mode='PERCENTAGE'; a.cfg.wild_levels=50
R.active=function() return a end
local C=dofile(modRoot..'/untamed_compat.lua')(mod,Core,R)
local original={ROUTE_1={grass={rate=255,buckets={128,256},slots={{species='MON_20',level=10},{species='MON_80',level=20}}},water={rate=255,slots={{species='MON_50',level=12}}}}}
game.data.encounters=original
game.data.field={fishing={OLD_ROD={always={species='MON_20',level=10}},GOOD_ROD={pool={{species='MON_80',level=20}}},SUPER_ROD={perMap='superRod'}},superRod={ROUTE_1={{species='MON_70',level=16}}}}
local view=C.buildView(a,'ROUTE_1')
check(view.encounters~=original,'adapter uses a separate encounter root')
check(original.ROUTE_1.grass.slots[1].level==10,'native level unchanged')
check(view.encounters.ROUTE_1.grass.slots[1].level==15,'visible level scaling once')
check(R.withinBst(game,a.cfg,'MON_20',view.encounters.ROUTE_1.grass.slots[1].species),'visible BST bound')
check(view.field.fishing.OLD_ROD.always.level==15,'Gen1 old rod projection')
check(view.field.fishing.GOOD_ROD.pool[1].level==30,'Gen1 good rod projection')
check(view.field.superRod.ROUTE_1[1].level==24,'Gen1 super rod projection')
check(next(a.wildMap)==nil and next(a.areaCounters)==nil,'preview does not consume actual run mappings/counters')
local inside,before,after,vanilla,other
hooks:wrap('probe',function(nextFn)
 before=game.data.encounters
 local x,y=nextFn()
 after=game.data.encounters
 return x,y
end,10,'overworldmons')
hooks:wrap('probe',function(nextFn) other=game.data.encounters; return nextFn() end,0,'other_mod')
events:on('visible',function() inside=game.data.encounters end,0,'overworldmons')
C.attach(game); C.attach(game)
events:emit('visible')
check(inside~=original and game.data.encounters==original,'event view is scoped and restored')
local x,y=hooks:call('probe',function() vanilla=game.data.encounters; return nil,42 end)
check(x==nil and y==42,'wrapper preserves multiple returns including nil')
check(before~=original and after~=original,'Untamed sees projection before/after next')
check(other==original and vanilla==original,'other hooks and native next see original tables')
check(game.data.encounters==original,'hook restores native tables')
hooks:wrap('failure',function() error('intentional callback failure') end,0,'overworldmons'); C.attach(game)
hooks:call('failure',function() return true end)
check(game.data.encounters==original,'throwing callback restores tables')
local old=a; a=nil; events:emit('visible'); check(inside==original,'disabled randomizer is transparent'); a=old

generation=2; a.generation=2; a.version='gold'; a.cfg.ruleset='GEN2'
local enc2={grass={ROUTE_1={rates={MORN=255,DAY=255,NITE=255},slots={MORN={{species='MON_20',level=10}},DAY={{species='MON_30',level=12}},NITE={{species='MON_40',level=14}}}}},
 water={ROUTE_1={rate=255,slots={{species='MON_50',level=10}}}},
 swarmGrass={ROUTE_1={rate=255,slots={day={{species='MON_60',level=20}}}}},
 fishGroups={ONE={old={{chance=256,species='MON_70',level=10}},super={{chance=256,timeGroup=1}}}},
 timeFishGroups={{day={species='MON_80',level=20},nite={species='MON_90',level=30}}}}
game.data.encounters=enc2; game.data.gen2Encounters=enc2
local v2=C.buildView(a,'ROUTE_1')
check(v2.encounters==v2.gen2Encounters,'Gen2 aliases share projection')
check(v2.encounters.grass.ROUTE_1.slots.NITE[1].level==21,'night slots scaled once')
check(v2.encounters.timeFishGroups[1].nite.level==45,'time-group fishing scaled')
check(v2.encounters.fishGroups.ONE.super[1].timeGroup==1,'fishing indirection preserved')
check(v2.encounters.swarmGrass.ROUTE_1.slots.day[1].level==30,'swarm slots projected')
check(enc2.timeFishGroups[1].nite.level==30,'original time groups unchanged')
a.cfg.area_encounters='VANILLA'
check(C.buildView(a,'ROUTE_1').encounters.grass.ROUTE_1.slots.DAY[1].species=='MON_30','vanilla encounter mode preserved')

local mapped={POTION='ANTIDOTE',[1]=2,[2]=3,[3]=4}
local awards={itemGift=function(_,source) return mapped[source] or source end}
local G=dofile(modRoot..'/gift_items.lua')(mod,Core,awards)
local args={'POTION',5,'You received a POTION!','Bag full',false}
local out=G.rewrite({mapId='SHOP'},'give_item',args,nil,game)
check(out[1]=='ANTIDOTE' and out[2]==5 and out[3]==nil and out[4]=='Bag full','Gen1 gift preserves amount/full path, uses actual receipt')
check(args[1]=='POTION','gift source arguments immutable')
local cmd={op='verbosegiveitemvar',item=1,var=17,args={1,17}}
local _,rewrite=G.rewrite({mapId='TOWN'},cmd.op,{},cmd,game)
check(rewrite.item==2 and rewrite.var==17 and rewrite.args[2]==17,'Gen2 variable quantity preserved')
check(cmd.item==1,'Gen2 gift command immutable')
local vm={scriptVar=1,cmdList={{op='giveitem',item=255}}}
local _,mem=G.rewrite({vm=vm,mapId='TOWN'},'giveitem',{}, {item=255,quantity=3},game)
check(mem.item==2 and mem.quantity==3,'ITEM_FROM_MEM resolved without changing scriptVar')
check(vm.scriptVar==1,'script variable remains available for original VM')
local _,name=G.rewrite({vm=vm,mapId='TOWN'},'getitemname',{}, {item=1},game)
check(name.item==2,'gift name and award agree')
local _,otherName=G.rewrite({vm={cmdList={}},mapId='TOWN'},'getitemname',{}, {item=1},game)
check(otherName.item==1,'unrelated name query unchanged')
local H=require('src.world.gen2.HiddenItems')
local pickup=H.pickupScript(1,20)
local _,skip=G.rewrite({scriptKey=pickup,vm={cmdList=pickup}},'giveitem',{},pickup[4],game)
check(skip.item==1,'field pickup is not gift-randomized again')
print(('PASS: %d feature checks'):format(checks))

-- Actual award pools: progression items and HM bytes never enter the pool.
game.data.items={
 POKE_BALL={index=5,price=200}, POTION={index=18,price=300},ANTIDOTE={index=9,price=100},
 POKE_FLUTE={index=20,keyItem=true},HM01={index=243,machine={kind='HM',number=1}},
 TM01={index=191,machine={kind='TM',number=1}},TM02={index=192,machine={kind='TM',number=2}}}
a.cfg.gift_items='RANDOM'
for _,id in ipairs({'POKE_FLUTE','HM01'}) do check(R.itemGiftForRun(a,id,'test')==id,'progression item protected: '..id) end
for seed=1,50 do
 a.seed=seed
 local item=R.itemGiftForRun(a,'POTION','TOWN|NPC')
 check(item=='POKE_BALL' or item=='POTION' or item=='ANTIDOTE','ordinary gifts stay in regular pool')
 check(R.itemGiftForRun(a,'POTION','TOWN|NPC')==item,'gift retry deterministic')
 local tm=R.itemGiftForRun(a,'TM01','TOWN|NPC')
 check(tm=='TM01' or tm=='TM02','gift TM stays a TM')
end
local _,varName=G.rewrite({vm=vm,mapId='TOWN'},'getitemname',{}, {item=0},game)
check(varName.item==2,'USE_SCRIPT_VAR name lookup matches gift')
local stocks={{'ANTIDOTE'},{9},{'POKE_BALL','POTION'}}
game.data.gen2Marts={lists=stocks};local added={}
R._applyMartSafety(game,added)
for _,stock in ipairs(stocks) do
 local found={};for _,id in ipairs(stock) do found[Core.resolveIndexedId(game.data.items,id) or id]=true end
 check(found.POKE_BALL and found.POTION,'every mart has balls and potions')
end
R._applyMartSafety(game,{})
check(#stocks[1]==3 and #stocks[2]==3 and #stocks[3]==2,'Mart Safety is idempotent')
R._removeMartSafety(added)
check(#stocks[1]==1 and #stocks[2]==1 and #stocks[3]==2,'Mart Safety restores original stock')

-- Test the real Untamed 1.2.1 spawn-to-queue path. Test-only accessors expose
-- its local functions; production code and algorithms are left intact.
local untamedPath=os.getenv('UNTAMED_SOURCE') or '../untamed/main.lua'
local file=assert(io.open(untamedPath));local source=file:read('*a');file:close()
local entry=assert(source:find('\nreturn function(mod)\n',1,true))
source=source:sub(1,entry-1)
local count
source,count=source:gsub('  return tickWildStep, wildDiag\n',[[
  wildDiag.probe={spawn=spawnOne,dist=eligibleDist,fish=fishSlots,live=live,
    queue=function(w) pending=w; tickWildStep(mod.game,0) end}
  return tickWildStep,wildDiag
]])
check(count==1,'pinned Untamed setup seam found')
source=source..[[
return function(mod,gen)
 RUNTIME.gen1=gen==1
 Encounter=require('src.battle.gen2.Encounter')
 return setupWild(mod,nil,nil,gen)
end
]]
local setup=assert((loadstring or load)(source,'@untamed-spawn-probe'))()
for gen=1,2 do
 generation=gen;a.generation=gen;a.version=gen==1 and 'red' or 'gold'
 a.seed=41;a.cfg.area_encounters='FULL_SLOT_RANDOM';a.cfg.bst_difference=50
 game.data.encounters=gen==1 and original or enc2
 game.data.gen2Encounters=gen==2 and enc2 or nil
 game.save.inventory={OLD_ROD=1,GOOD_ROD=1,SUPER_ROD=1}
 game.world.maps={ROUTE_1={fishGroup='ONE'}}
 local queued,npcs={},{}
 local untamed={game=game,path='fixture',log={info=function() end,warn=function() end,error=function(_,msg) error(msg) end},
  save=mod.save,content={sprites={patch=function() end},screens={register=function() end},
   pokemon={get=function(_,id) return game.data.pokemon[id] end}},
  hooks={wrap=function(_,name,fn,p) hooks:wrap(name,fn,p,'overworldmons') end},
  events={on=function(_,name,fn,p) events:on(name,fn,p,'overworldmons') end}}
 untamed.world={
  effectiveEncounters=function(_,mapId,terrain)
   local enc=game.data.encounters
   local slotdef=gen==1 and enc[mapId][terrain] or enc[terrain][mapId]
   local slots=slotdef.slots.DAY or slotdef.slots; local dist={}
   for _,row in ipairs(slots) do dist[row.species]=(dist[row.species] or 0)+1 end
   return {chance=1,dist=dist}
  end,
  spawnNpc=function(_,mapId,opts) local i=#npcs+1;npcs[i]={cellX=opts.x,cellY=opts.y};return 'wild_obj_'..i end,
  npc=function(_,mapId,index) return {npc=npcs[index]} end,
  queueScript=function(_,rows) queued[#queued+1]=rows[1] end,
 }
 untamed.world.game=game
 if jit then
  local facade=require(gen==1 and 'src.world.WorldAPI' or 'src.world.gen2.WorldAPI')
  untamed.world.effectiveEncounters=facade.effectiveEncounters
 end
 local tick,diag=setup(untamed,gen);check(tick~=nil,'real Untamed setup loaded Gen'..gen)
 events:on('untamed.probe'..gen,function()
  local dist=diag.probe.dist('ROUTE_1','grass')
  diag.probe.spawn('ROUTE_1',{1,1},'grass',dist,function() return 0.25 end)
  local live=diag.probe.live[1]
  check(live~=nil,'real Untamed spawned Gen'..gen)
  check(diag.dex==game.data.pokemon[live.species].dex,'visible sprite dex matches stored species')
  diag.probe.queue(live)
  local battle=queued[#queued]
  check(battle[3]==live.species and battle[4]==live.level,'actual Untamed queued matching species and level')
  local fish,levels=diag.probe.fish('ROUTE_1')
  check(fish and next(fish) and next(levels),'real Untamed reads randomized fishing Gen'..gen)
 end,0,'overworldmons')
 C.attach(game);events:emit('untamed.probe'..gen)
 check(#queued==1,'spawn-to-battle callback completed without errors')
 check(game.data.encounters==(gen==1 and original or enc2),'real Untamed leaves native tables intact')
end
print(('PASS: %d total checks including real Untamed spawn/battle path'):format(checks))
if jit then
 local Runtime=require('src.mods.Runtime')
 local Vm=require('src.script.gen2.Vm')
 local Flags=require('src.world.gen2.Events')
 Runtime.install(events,hooks)
 for _,accept in ipairs({true,false}) do
  local received,names={},{}
  local flags=Flags.new()
  local vm2=Vm.new({NPC={
   {op='getitemname',item=1},{op='giveitem',item=1,quantity=3},
   {op='iffalse',script='full'},{op='setevent',event=99},{op='itemnotify'},{op='end'}},
   full={{op='end'}}},{},flags,{
    mapId=function() return 'TOWN' end,
    giveItem=function(id,qty) received[#received+1]={id,qty};return accept end,
    getItemName=function(id) names[#names+1]=id;return 'ITEM_'..id end,
    showText=function(_,done) done() end,
  })
  vm2:start('NPC')
  check(not vm2:running(),'native gift VM completes')
  check(#received==1 and received[1][1]==2 and received[1][2]==3,'native VM awards rewritten item exactly once')
  check(flags:get(99)==accept,'bag-full branch does not consume gift event')
  check(vm2.curItem==2 and names[1]==2,'native receipt and item notification use randomized item')
 end
 awards.fieldTreeItem=function(_,item) return item+1 end
 local originalTree=function() return 1 end
 local fruit={}
 local treeVm=Vm.new({TREE={{op='fruittree',tree=1}}},{},Flags.new(),{
  mapId=function() return 'ROUTE_1' end,fruitTreeItem=originalTree,
  giveItem=function(id) fruit[#fruit+1]=id;return true end,
  getItemName=function(id) return 'ITEM_'..id end,
  showText=function(_,done) done() end,
 })
 treeVm:start('TREE')
 check(#fruit==1 and fruit[1]==2,'native fruit-tree award passes through field-item adapter')
 check(treeVm.fruitTreeItemFn==originalTree,'fruit-tree handler restored after yielding dialogue')
 print(('PASS: %d checks with native LuaJIT VM and world facades'):format(checks))
end
