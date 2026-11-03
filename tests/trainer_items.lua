-- Trainer reward locations, native identities and independent progression proofs.
-- World records use the established synthetic audit fixture plus pinned portals.
local root=os.getenv('MOD_SOURCE') or 'mod'
local base=os.getenv('MOD_BASE') or 'dist/baseline/mod'
local host=os.getenv('HOST_SOURCE') or '../host-source'
package.path=host..'/?.lua;'..package.path
unpack=table.unpack or unpack
dofile('tests/support/bit54.lua')
local version,gen='red',1
package.loaded['src.core.GameVersion']={get=function() return version end,generation=function() return gen end,isYellow=function() return version=='yellow' end}
local Core=dofile(base..'/core.lua')
local I=dofile(root..'/progression_items.lua')(Core)
local L=dofile(root..'/logic_graph.lua')(Core)
local G1=dofile(root..'/gen1_world.lua')(Core)
local G2=dofile(root..'/gen2_world.lua')(Core)
local Worlds=dofile(root..'/worlds.lua')(G1,G2)
local A=dofile(root..'/adaptive_gyms.lua')(Core,Worlds)
local hooks,events=require('src.mods.Hooks').new(),require('src.mods.Events').new()
local saved={}
local mod={hooks={wrap=function(_,n,f,p) return hooks:wrap(n,f,p,'universal_randomizer') end},events={on=function(_,n,f,p) return events:on(n,f,p,'universal_randomizer') end},
 save={get=function(_,k,d) if saved[k]==nil then return d end;return saved[k] end,set=function(_,k,v) saved[k]=v end},
 log={error=function(_,fmt,...) error(fmt:format(...)) end},world={removeNpc=function() end}}
local R=dofile(root..'/randomizer.lua')(mod,Core,dofile(base..'/adapters.lua'),I,L,Worlds,A)
local fixture=dofile('tests/support/audit_fixture.lua')({Core=Core,I=I,L=L,R=R,mod=mod,hooks=hooks,events=events,setVersion=function(g,v) gen,version=g,v end})
local native=dofile('tests/support/adaptive_native.lua')
local checks,plans=0,0
local function check(v,msg) assert(v,msg);checks=checks+1 end
local function stable(t)
 if type(t)~='table' then return tostring(t) end
 local out={};for _,k in ipairs(Core.sortedKeys(t)) do out[#out+1]=tostring(k)..'='..stable(t[k]) end
 return '{'..table.concat(out,',')..'}'
end
local function gameFor(v)
 local generation=(v=='red' or v=='blue' or v=='yellow') and 1 or 2
 local game=fixture(generation,v)
 local data=native[v=='blue' and 'red' or v=='silver' and 'gold' or v]
 -- Convert the synthetic world encounter/trade references to native species.
 local dex={};for id,d in pairs(data.pokemon) do dex[d.dex]=id end
 local function rewrite(t)
  for k,x in pairs(t) do
   if type(x)=='table' then rewrite(x)
   elseif type(x)=='string' and x:match('^MON_%d+$') then t[k]=assert(dex[tonumber(x:match('%d+'))]) end
  end
 end
 rewrite(game.data)
 for k,d in pairs(data) do game.data[k]=Core.copy(d) end
 game.data.items.BERRY={index=173,name='BERRY'};game.data.items.LEFTOVERS={index=146,name='LEFTOVERS'}
 game.data.type_chart={matchups={},types={}}
 game.save.pokedex.seen={}
 local ports=generation==1 and dofile(v=='yellow' and 'tests/support/gen1_portals_yellow.lua' or 'tests/support/gen1_portals.lua')
   or dofile('tests/support/gen2_portals.lua')[v=='crystal' and 'crystal' or 'gold']
 local maps=generation==1 and game.data.maps or game.data.gen2Maps
 for id,def in pairs(ports) do
  maps[id]=maps[id] or {id=id,objects={}}
  for k,x in pairs(def) do maps[id][k]=Core.copy(x) end
 end
 game.data.sprites={}
 for _,g in ipairs((generation==1 and G1 or G2).gyms) do
  game.data.sprites[g.sprite or g.name]={}
 end
 for class,t in pairs(game.data.trainers or {}) do t.pic='native/'..class..'.png' end
 return game
end

I.installHardcoded(mod,R);R.installHooks();Worlds.install(mod,R,I)
require('src.mods.Runtime').install(events,hooks)
local totals={slots=0,keys=0}
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
 local game=gameFor(v);local W=gen==1 and G1 or G2
 local maps=gen==1 and game.data.maps or game.data.gen2Maps
 -- These authored encounter maps do not all have entrance records in the
 -- fixture. Native rosters are extracted from the pinned cartridge sources.
 if gen==1 then
  for _,id in ipairs({'VIRIDIAN_FOREST','ROUTE_3','ROUTE_24','ROUTE_25'}) do maps[id]=maps[id] or {objects={}} end
  maps.VIRIDIAN_FOREST.objects={{trainerClass='OPP_BUG_CATCHER',trainerParty=1}}
 else
  maps.ROUTE_30=maps.ROUTE_30 or {objects={}}
  maps.RADIO_TOWER_5F=maps.RADIO_TOWER_5F or {objects={}}
  maps.SPROUT_TOWER_3F=maps.SPROUT_TOWER_3F or {objects={}}
 end
 local candidates=I.trainerCandidates(game,gen,W)
 check(#candidates>8,v..' has native modeled trainer sources')
 local indexed={};for _,d in ipairs(candidates) do indexed[d.trainer]=d end
 local traps=gen==1 and {{'OPP_BLAINE#1','MANSION_SECRET'},{'OPP_GIOVANNI#1','ROCKET_LIFT'}}
   or {{'JASMINE#1','CIANWOOD_SECRET'},{'YOUNGSTER#1','MYSTERY_EGG'},{'EXECUTIVEM#1','WAREHOUSE_CARD'}}
 for _,trap in ipairs(traps) do
  local d=Core.copy((assert(indexed[trap[1]],'native trap source missing')))
  local nativePlan=R._nativeAuditPlan(gen,nil);local reward=nativePlan.locations[trap[2]]
  nativePlan.locations[trap[2]]='POTION';nativePlan.locations[d.key]=reward;nativePlan.defs[#nativePlan.defs+1]=d
  local world=W.identity(game,R.defaults(game),nil,nil,L)
  check(not R._auditItemSpheres(nativePlan,gen),'native graph rejects trainer holding own access item: '..trap[1])
  check(not W.replay(world,nativePlan),'entrance graph independently rejects trainer self-lock: '..trap[1])
 end
 if gen==2 then
  local d=Core.copy(assert(indexed['CLAIR#1']));local p=R._nativeAuditPlan(2,nil)
  p.locations.ROCKET_WHIRL='POTION';p.locations[d.key]='HM_WHIRLPOOL';p.defs[#p.defs+1]=d
  check(R._auditItemSpheres(p,2),'Clair fight precedes Whirlpool badge quest')
  check(W.replay(W.identity(game,R.defaults(game),nil,nil,L),p),'expanded graph allows Whirlpool after Clair fight')
 end
 for _,d in ipairs(candidates) do
  local class,member=d.trainer:match('^(.-)#(%d+)$')
  check(I.trainerKey(game,gen,class,tonumber(member))==d.trainer,'canonical native source')
  if gen==2 then
   local entry=game.data.gen2Trainers.classes[class]
   check(I.trainerKey(game,2,entry.index,entry.trainers[tonumber(member)].id)==d.trainer,'numeric class and symbolic member resolve identically')
   check(I.trainerKey(game,2,tostring(entry.index),tonumber(member))==d.trainer,'serialized numeric class resolves to the same source')
  end
 end
 local safePool=R.trainerItemPool(game,false);local chaosPool=R.trainerItemPool(game,true)
 check(#safePool>40,'broad native item/TM pool')
 check(not Core.tableHas(safePool,'HM_SURF') and Core.tableHas(chaosPool,'HM_SURF'),'HM pool respects mode')
 local off=R.defaults(game);check(off.trainer_checks=='OFF','default Off')
 check(R.preflight(game,off),'Off accepted')
 local bad=Core.copy(off);bad.trainer_checks='SAFE';bad.safety='CHAOS'
 check(not R.preflight(game,bad),'mixed safety rejected')
 for _,mode in ipairs({'SAFE','CHAOS'}) do
  for seed=1,3 do
   local cfg=R.defaults(game);cfg.trainer_checks=mode;cfg.safety=mode
   if seed==2 then
    cfg.random_start=mode=='SAFE' and 'LOGIC' or 'OFF';cfg.badges=mode
    cfg.gym_leaders=mode;cfg.gym_entrances=mode;cfg.dungeon_entrances=mode
    cfg.entrance_pool='MIXED'
   end
   local a,why,attempts=R.generate(game,cfg,seed)
   check(a,v..' '..mode..' '..seed..': '..tostring(why));check(attempts<=50,'bounded validation')
   check((a.gen1World or a.gen2World).checked==(mode=='SAFE'),'honest certification')
   local plan=a.logicItemPlan;local selected={}
   for _,d in ipairs(plan.defs) do if d.kind=='trainer' then
    selected[#selected+1]=d;totals.slots=totals.slots+1
    check(I.trainerDrop(a.seed,d.trainer),'seeded chance selects sources before fill')
    if plan.locations[d.key]:find('KEY',1,true) or plan.locations[d.key]:find('HM_',1,true) then totals.keys=totals.keys+1 end
    if mode=='SAFE' then
     local _,proof=W.replay(a.gen1World or a.gen2World,plan,plan.locations[d.key])
     check(proof.reached[d.key],'reward not required to reach its own trainer')
    end
   end end
   check(R._validateLogicItemPlan(game,a.cfg),'applied plan passes validator')
   if #selected>0 then
    local d=selected[1];local installed=game.data._urLogicItemPlan;local old=d.trainerRule
    for _,entry in ipairs(installed.defs) do if entry.key==d.key then entry.trainerRule={'EARLY'} end end
    check(not R._validateLogicItemPlan(game,a.cfg),'tampered trainer prerequisites rejected')
    game.data._urLogicItemPlan=Core.copy(plan)
    game.data._urLogicItemPlan.locations[d.key]=nil
    check(not R._validateLogicItemPlan(game,a.cfg),'missing trainer award rejected')
    game.data._urLogicItemPlan=Core.copy(plan)
    game.data.constants={bagSize=1};game.save.inventory={FILLER_1=99};game.save.bagOrder={'FILLER_1'}
    if gen==2 then game.save.inventory[plan.locations[d.key]]=99 end
    local class,member=d.trainer:match('^(.-)#(%d+)$')
    local battle=gen==1 and {kind='trainer',oppClass=class,partyIndex=tonumber(member)} or {trainer={classId=class,member=tonumber(member)}}
    local before=#W.state(a).rewards
    events:emit('battle.ended',{battle=battle,result='lose'})
    events:emit('battle.ended',{battle=battle,result='win',skipped=true})
    check(#W.state(a).rewards==before,'loss and skipped battle never reward')
    local drop=I.trainerDrop;I.trainerDrop=function() return false end
    events:emit('battle.ended',{battle=battle,result='win'})
    I.trainerDrop=drop
    check(#W.state(a).rewards==before+1,'native victory event awards seeded item')
    check((game.save.pcItems or {})[plan.locations[d.key]],'full bag sends actual assigned item to PC')
    events:emit('battle.ended',{battle=battle,result='win'})
    check(#W.state(a).rewards==before+1,'repeated battle event cannot farm items')
    a.cfg.dex_checks='ALL';local mon={species='PIKACHU'};game.save.party={mon}
    events:emit('pokemon.caught',{species='PIKACHU',mon=mon,destination='party'})
    check(#W.state(a).rewards==before+1,'capture reward removed even in legacy saves')
    game.save.party={};a.cfg.dex_checks='OFF'
    check(R.commit(a),'persist trainer assignment and claim')
    R.abortSavedActivation(game)
    local resumed,err=R.activateSaved(game);check(resumed,tostring(err))
    check(stable(resumed.logicItemPlan.locations)==stable(plan.locations),'cold Continue preserves all assigned items')
    check(not W.award(mod,resumed,I,'trainer',d.trainer),'cold Continue preserves claims')
   end
  end
 end
 print('trainer items',v,'passed')
end
check(totals.keys>0,'keys/HMs actually move to trainer wins')
local yes,no=0,0
for seed=1,2000 do if I.trainerDrop(seed,'OPP_BROCK#1') then yes=yes+1 else no=no+1 end end
check(yes>400 and yes<600 and no>1400,'approximately one quarter chance')
print(('Trainer items: %d checks; %d trainer locations; %d key/HM rewards'):format(checks,totals.slots,totals.keys))
