local root=os.getenv('MOD_SOURCE') or 'mod'
local base=os.getenv('MOD_BASE') or 'dist/baseline'
local host=os.getenv('HOST_SOURCE') or '../host-source'
package.path=host..'/?.lua;'..package.path
unpack=table.unpack or unpack
local version,gen='red',1
package.loaded['src.core.GameVersion']={get=function() return version end,generation=function() return gen end,isYellow=function() return version=='yellow' end}
local Core=dofile(base..'/core.lua')
local I=dofile(root..'/progression_items.lua')(Core)
local L=dofile(root..'/logic_graph.lua')(Core)
local W=dofile(root..'/gen1_world.lua')(Core)
local hooks,events=require('src.mods.Hooks').new(),require('src.mods.Events').new()
local saved={}
local mod={hooks={wrap=function(_,n,f,p) return hooks:wrap(n,f,p,'universal_randomizer') end},events={on=function(_,n,f,p) return events:on(n,f,p,'universal_randomizer') end},
 save={get=function(_,k,d) if saved[k]==nil then return d end;return saved[k] end,set=function(_,k,v) saved[k]=v end},
 log={error=function(_,fmt,...) error(fmt:format(...)) end},world={removeNpc=function() end}}
local R=dofile(root..'/randomizer.lua')(mod,Core,dofile(base..'/adapters.lua'),I,L,W)
local fixture=dofile('tests/support/audit_fixture.lua')({Core=Core,I=I,L=L,R=R,mod=mod,hooks=hooks,events=events,setVersion=function(g,v) gen,version=g,v end})
local n=0
local function check(v,msg) assert(v,msg);n=n+1 end
local function gameFor(v)
 local game=fixture(1,v);local ports=dofile(v=='yellow' and 'tests/support/gen1_portals_yellow.lua' or 'tests/support/gen1_portals.lua')
 for id,def in pairs(ports) do
  game.data.maps[id]=game.data.maps[id] or {id=id,objects={}}
  for k,x in pairs(def) do game.data.maps[id][k]=x end
 end
 game.data.trainers={}
 for i,g in ipairs(W.gyms) do
  local class,index=g.key:match('^(.-)#(%d+)$')
  game.data.trainers[class]={name=g.name,parties={[tonumber(index)]={{species='MON_10',level=10+i}}}}
 end
 return game
end
local game=gameFor('red');local cfg=R.defaults(game)
cfg.gym_leaders='SAFE';cfg.gym_entrances='SAFE';cfg.dungeon_entrances='SAFE';cfg.badges='SAFE'
local ok,why=R.preflight(game,cfg);check(ok,tostring(why))
local ports=W.portals(game,L);check(#ports==23,'23 physical portals, got '..#ports)
for _,start in ipairs({'OFF','CERULEAN_CITY','VERMILION_CITY','LAVENDER_TOWN','CELADON_CITY','SAFFRON_CITY','FUCHSIA_CITY','CINNABAR_ISLAND'}) do
 local sid=start~='OFF' and start or nil
 local mapping,err=R._checkedBadgeAssignment(1,77,sid and {id=sid},game,cfg)
 check(mapping,tostring(err)..' start '..start)
 local native=R._nativeAuditPlan(1,sid,mapping)
 local world=W.identity(game,cfg,sid,mapping,L)
 local pass,proof=W.replay(world,native)
 check(pass,start..' blocked '..table.concat(proof.blocked,',')..' entrances '..table.concat(proof.inaccessible,','))
end
for seed=1,8 do
 local c=Core.copy(cfg);c.random_start=seed==1 and 'OFF' or 'LOGIC'
 local a,err,attempts=R.generate(game,c,seed)
 check(a,tostring(err));check(attempts<=50,'bounded attempts')
 check(a.gen1World.proof.complete,'completion')
 print('seed',seed,'start',a.gen1World.start,'attempts',attempts)
end

local function stable(t)
 if type(t)~='table' then return tostring(t) end
 local out={};for _,k in ipairs(Core.sortedKeys(t)) do out[#out+1]=tostring(k)..'='..stable(t[k]) end
 return '{'..table.concat(out,',')..'}'
end
-- Native host hook dispatch; the complete ROM renderer is not mocked into a
-- pretend playthrough. Presentation/constructor tests are separate below.
I.installHardcoded(mod,R);R.installHooks();W.install(mod,R,I)
require('src.mods.Runtime').install(events,hooks)
local generated=0
if not os.getenv('UR_PRESENTATION_ONLY') then
for _,v in ipairs({'red','blue','yellow'}) do
 for pattern=1,7 do for _,mode in ipairs({'SAFE','CHAOS'}) do
  game=gameFor(v);cfg=R.defaults(game)
  cfg.safety=mode;cfg.badges=mode
  cfg.gym_leaders=pattern%2==1 and mode or 'OFF'
  cfg.gym_entrances=math.floor(pattern/2)%2==1 and mode or 'OFF'
  cfg.dungeon_entrances=math.floor(pattern/4)%2==1 and mode or 'OFF'
  cfg.entrance_pool=pattern%2==1 and 'MIXED' or 'SEPARATE'
  cfg.badge_pairing=pattern%3==0 and 'WITH_LEADER' or 'INDEPENDENT'
  cfg.random_start=mode=='SAFE' and 'LOGIC' or 'OFF'
  local a,err,tries=R.generate(game,cfg,100+pattern)
  check(a,v..' '..pattern..' '..mode..': '..tostring(err));generated=generated+1
  check(tries>=1 and tries<=50,'bounded generation')
  local world=a.gen1World
  check(world.checked==(mode=='SAFE'),'Chaos never gets Safe certification')
  local used={}
  for _,p in ipairs(world.portals) do
   local dest=world.destinations[p.id]
   check(dest and not used[dest],'one-to-one entrance');used[dest]=true
   if cfg[p.kind..'_entrances']=='OFF' then check(dest==p.id,'disabled pool fixed') end
   if cfg.entrance_pool=='SEPARATE' then check(world.byId[dest].kind==p.kind,'separate pools') end
  end
  if world.checked then
   local pass,proof=W.replay(world,a.logicItemPlan);check(pass,'complete sphere replay')
   for _,def in ipairs(a.logicItemPlan.defs) do
    local _,without=W.replay(world,a.logicItemPlan,a.logicItemPlan.locations[def.key])
    check(without.reached[def.key],'reward does not lock its own source')
   end
  end
  local leaders={}
  for _,g in ipairs(W.gyms) do
   local leader=world.leaders[g.key];check(not leaders[leader],'leader permutation');leaders[leader]=true
   if cfg.gym_leaders=='OFF' then check(leader==g.key,'leaders disabled') end
   if cfg.gym_leaders~='OFF' and cfg.badge_pairing=='WITH_LEADER' then check(W.byKey[leader].badge==world.badges[g.key],'leader/badge coupling') end
  end
  if mode=='CHAOS' then check(R.commit(a) and saved.safety=='CHAOS','unchecked world is not saved as Safe PASS') end
  if mode=='SAFE' then
   local snapshot=stable({world.destinations,world.leaders,world.badges,a.logicItemPlan.locations})
   check(R.commit(a),'commit checked world')
   R.abortSavedActivation(game)
   local resumed,why=R.activateSaved(game);check(resumed,tostring(why))
   check(stable({resumed.gen1World.destinations,resumed.gen1World.leaders,resumed.gen1World.badges,resumed.logicItemPlan.locations})==snapshot,'cold Continue never rerolls')
   check(R.runCode(resumed):find('UR170',1,true)==1,'new Gen 1 run namespace')
  end
 end end
end
-- Every supported start with both pool modes and both badge/leader policies,
-- on all three native cartridges. Force one imported fly landing at a time.
for _,v in ipairs({'red','blue','yellow'}) do
 for _,start in ipairs(L.logicStarts(1)) do
  for _,pool in ipairs({'SEPARATE','MIXED'}) do for _,pairing in ipairs({'INDEPENDENT','WITH_LEADER'}) do
   game=gameFor(v);local landing=game.data.field.flyWarps[start]
   game.data.field.flyWarps={[start]=landing}
   cfg=R.defaults(game);cfg.random_start='LOGIC';cfg.badges='SAFE'
   cfg.gym_leaders='SAFE';cfg.gym_entrances='SAFE';cfg.dungeon_entrances='SAFE'
   cfg.entrance_pool=pool;cfg.badge_pairing=pairing
   local a,why,tries=R.generate(game,cfg,379)
   check(a,v..' '..start..' '..pool..' '..pairing..': '..tostring(why));generated=generated+1
   check(tries==1,'constructive checked planner succeeds without blind rerolls')
   check(a.gen1World.start==start,'requested native start exercised')
   check(a.gen1World.proof.complete,'all-start combined proof')
   local all=W.portals(game,L);local byId={};for _,p in ipairs(all) do byId[p.id]=p end
   for _,p in ipairs(all) do
    local target=byId[a.gen1World.destinations[p.id]]
    for i,exit in ipairs(target.reverseEndpoints) do
     local back=a.doorPlan.byWarp[exit.warp];local source=p.sourceEndpoints[((i-1)%#p.sourceEndpoints)+1]
     check(back.map==source.map and back.x==source.warp.x and back.y==source.warp.y,'every exit returns to its exact paired entrance')
    end
   end
  end end
 end
end
-- Negative controls: a missing native door is rejected before generation;
-- direct and multi-item locks are rejected independently of placement order.
game=gameFor('red');cfg=R.defaults(game);cfg.gym_entrances='SAFE';cfg.dungeon_entrances='SAFE';cfg.badges='SAFE'
local a,err=R.generate(game,cfg,43);check(a,tostring(err))
local broken=Core.copy(a.logicItemPlan)
for _,d in ipairs(broken.defs) do broken.locations[d.key]=d.item end
broken.locations.ROCKET_LIFT='SILPH_SCOPE';broken.locations.ROCKET_SCOPE='LIFT_KEY'
local native=W.identity(game,a.cfg,nil,nil,L)
check(not W.replay(native,broken),'Lift Key behind its own elevator rejected')
broken.locations.ROCKET_LIFT='LIFT_KEY';broken.locations.ROCKET_SCOPE='SILPH_SCOPE'
broken.locations.SS_ANNE_CUT='S_S_TICKET';broken.locations.BILL_TICKET='HM_CUT'
check(not W.replay(native,broken),'ticket inside its ship rejected')
local badBadges={['OPP_BROCK#1']='EARTHBADGE',['OPP_MISTY#1']='MARSHBADGE',['OPP_LT_SURGE#1']='BOULDERBADGE',
 ['OPP_ERIKA#1']='CASCADEBADGE',['OPP_KOGA#1']='THUNDERBADGE',['OPP_SABRINA#1']='SOULBADGE',['OPP_BLAINE#1']='RAINBOWBADGE',['OPP_GIOVANNI#3']='VOLCANOBADGE'}
local lockedWorld=W.identity(game,a.cfg,nil,badBadges,L)
check(not W.replay(lockedWorld,R._nativeAuditPlan(1,nil,badBadges)),'badge/HM cycle rejected')
local coast=W.identity(game,a.cfg,'FUCHSIA_CITY',nil,L)
local coastSeen=W.worldState(coast,{HM_SURF=true})
check(not coastSeen.SEAFOAM_WEST,'Seafoam cannot be traversed without Strength')
-- Wrong-side entries cannot operate remote boulder switches. Isolate each
-- transit component so another outdoor route cannot disguise the mistake.
for _,id in ipairs({'SEAFOAM','VICTORY_ROAD'}) do
 local isolated={start='CINNABAR_ISLAND',portals={},byId={},destinations={},badges={}}
 local origin,exit
 for _,p in ipairs(native.portals) do if p.content==id then
  local c=Core.copy(p);c.region=p.puzzleOrigin and 'ISOLATED' or 'CINNABAR'
  isolated.portals[#isolated.portals+1]=c;isolated.byId[c.id]=c;isolated.destinations[c.id]=c.id
  if c.puzzleOrigin then origin=c else exit=c end
 end end
 local have={HM_SURF=true,SOULBADGE=true,HM_STRENGTH=true,RAINBOWBADGE=true}
 local seen=W.worldState(isolated,have)
 check(not seen.ISOLATED,id..' wrong-side puzzle entry rejected even with both HMs')
 origin.region='CINNABAR';exit.region='ISOLATED'
 seen=W.worldState(isolated,have)
 check(seen.ISOLATED,id..' forward puzzle traversal remains possible')
end
local supplies=Core.copy(cfg);supplies.mart_safety=false;supplies.marts='CHAOS'
local supplyCfg=R.normalizedConfig(supplies,game)
check(supplyCfg.mart_safety,'Safe worlds retain renewable catching/healing stock even with broad shop pool')
check(R.setLiveMartSafety(game,false) and R.active().cfg.mart_safety,'live options cannot remove Safe world essentials')
local oldWarps=game.data.maps.PEWTER_CITY.warps;game.data.maps.PEWTER_CITY.warps={}
check(not R.preflight(game,cfg),'missing actual gym entrance rejected')
game.data.maps.PEWTER_CITY.warps=oldWarps
local duplicate=Core.copy(a.gen1World);local p1,p2=duplicate.portals[1],duplicate.portals[2]
duplicate.destinations[p1.id]=duplicate.destinations[p2.id]
check(not W.bind(duplicate,W.portals(game,L)),'duplicate reverse destinations rejected')
local moon
for _,p in ipairs(native.portals) do if p.region=='MOON_EAST' then moon=p end end
check(moon~=nil,'east Mt. Moon mouth modeled separately')
local seen=W.worldState({start='CERULEAN_CITY',portals={},byId={},destinations={},badges={}}, {})
check(not seen.WEST and not seen.MOON_EAST,'Cerulean cannot walk backward over Mt Moon ledges')
-- Mechanical native warp hook and actual map-entered confirmation.
a=assert(R.generate(game,cfg,43));check(R.commit(a),'journal run committed')
local port=W.portals(game,L)[1];local e=port.sourceEndpoints[1];local target=a.doorPlan.byWarp[e.warp]
local dm,x,y=hooks:call('warp.destination',function(d,x,y) return d,x,y end,e.warp.destMap,0,0,{warp=e.warp,data=game.data})
check(dm==target.map and x==target.x and y==target.y,'native warp routed to actual landing')
check(next(W.state(a).journal)==nil,'queries alone do not reveal journal')
events:emit('map.entered',{mapId=dm});check(W.state(a).journal[target.source]==target.target,'entered destination recorded')
-- Every four NEW rumors has exactly one bogus hint; rereads are stable and
-- do not consume the sequence. Both hint detail modes and paid signs share it.
for _,detail in ipairs({'AREA','EXACT'}) do
 a.cfg.world_hints=detail
 for cycle=1,4 do
  local bogus=0
  for i=1,4 do
   local key=detail..cycle..':'..i;local text,tier=W.hint(a,mod,key)
   if tier=='bogus' then bogus=bogus+1 end
   check(W.hint(a,mod,key)==text,'hint remains stable on reread')
  end
  check(bogus==1,'guaranteed bogus hint in every four')
 end
end
-- Bonuses never become progression dependencies, are once per identity,
-- survive Continue, and have a working full-bag PC route.
a.cfg.trainer_checks='ALL';a.cfg.dex_checks='ALL'
game.data.constants={bagSize=1};game.save.inventory={FILLER_1=99};game.save.bagOrder={'FILLER_1'}
local yes,msg=W.award(mod,a,I,'trainer','OPP_BROCK#1');check(yes and msg:find('PC',1,true),'full-bag bonus sent to PC')
check(not W.award(mod,a,I,'trainer','OPP_BROCK#1'),'rematch cannot duplicate bonus')
check(#W.state(a).rewards==1,'bonus log factual')
check(R.commit(a),'persist bonus claims')
a=assert(R.activateSaved(game));check(not W.award(mod,a,I,'trainer','OPP_BROCK#1'),'claims survive load')
local mon={species='MON_10'};local before=#W.state(a).rewards
events:emit('pokemon.caught',{species='MON_10',mon=mon,destination='box'})
check(#W.state(a).rewards==before,'failed storage cannot earn capture reward')
game.save.party={mon};events:emit('pokemon.caught',{species='MON_10',mon=mon,destination='party'})
check(#W.state(a).rewards==before,'capture reward removed')
events:emit('pokemon.caught',{species='MON_10',mon=mon,destination='party'})
check(#W.state(a).rewards==before,'repeat capture gives no reward')
-- The 50th candidate is still fully certified. There is no 51st attempt and
-- persistent failure cannot leave an active/committable invalid world.
local build=W.build;local calls=0
W.build=function(...)
 calls=calls+1
 if calls<50 then return nil,'[seed] injected rejected candidate' end
 return build(...)
end
game=gameFor('red');local st=assert(R.beginGenerate(game,cfg,90));local frames=0
while not st.done and frames<701 do R.stepGenerate(st);frames=frames+1 end
check(st.active and st.attempt==50 and calls==50,'valid checked seed on attempt 50')
check(frames==700,'one bounded stage per frame')
W.build=function() return nil,'[seed] persistent rejected candidate' end
st=assert(R.beginGenerate(game,cfg,90));frames=0
while not st.done and frames<701 do R.stepGenerate(st);frames=frames+1 end
check(st.done and not st.active and st.attempt==50 and frames==700,'failure stops exactly at 50')
check(R.active()==nil,'no rejected world is active')
W.build=build
-- Freeze Gen 2 output against the released implementation. New config keys,
-- retry behavior, fingerprints and run codes must not enter that generation.
local oldR=dofile('dist/baseline/randomizer-1.6.5.lua')
if oldR then
 local baseline=oldR(mod,Core,dofile(base..'/adapters.lua'),I,L)
 for _,v in ipairs({'gold','silver','crystal'}) do
  local g=fixture(2,v);local c=baseline.defaults(g)
  check(c.gym_leaders==nil and c.world_hints==nil,'Gen 2 has no new settings')
  local b,why=baseline.generate(g,c,51);check(b,tostring(why))
  local expected=stable({b.cfg,b.starterMap,b.badgePlan,b.logicItemPlan,b.fingerprint,baseline.runCode(b)})
  baseline.clear(g);g=fixture(2,v)
  local current,why=R.generate(g,c,51);check(current,tostring(why))
  check(stable({current.cfg,current.starterMap,current.badgePlan,current.logicItemPlan,current.fingerprint,R.runCode(current)})==expected,'Gen 2 frozen behavior '..v)
  check(R.beginGenerate(g,c,51).maxAttempts==1,'Gen 2 single attempt unchanged')
 end
end
print(('Gen 1 world: %d checks passed; %d setting worlds'):format(n,generated))
end
-- Native battle construction keeps source victory identity while changing the
-- native roster/portrait/name. Only image loading is replaced for headless use.
game=gameFor('red');cfg=R.defaults(game);cfg.gym_leaders='SAFE';cfg.trainers='UNCHANGED'
a=assert(R.generate(game,cfg,88))
local Battle=require('src.battle.BattleState');local Pokemon=require('src.pokemon.Pokemon')
love=love or {};love.math={random=math.random}
for id,d in pairs(game.data.pokemon) do d.name=id;d.growthRate='MEDIUM_FAST';d.catchRate=45;d.baseExp=50 end
for _,m in pairs(game.data.moves) do m.pp=m.pp or 20;m.accuracy=m.accuracy or 100 end
for class,t in pairs(game.data.trainers) do t.id=class;t.pic='native/'..class..'.png';t.aiMods={} end
game.data.type_chart={matchups={},types={}}
game.save.pokedex.seen={}
game.save.party={Pokemon.new(game.data,'MON_10',12)}
local pic=Battle.trainerSprite
Battle.trainerSprite=function(data,trainer,class,party) return Battle.trainerPicPath(data,trainer,class,party) end
local source=W.gyms[1];local target=W.byKey[a.gen1World.leaders[source.key]]
local battle=Battle.newTrainer(game,'OPP_BROCK',1)
check(battle.oppClass=='OPP_BROCK' and battle.partyIndex==1,'native battle keeps source victory key')
check(battle.trainer.name==target.name,'native battle displays target leader')
check(battle.trainerPic=='native/'..target.key:match('^(.-)#')..'.png','native target portrait used')
check(battle.introText:find(target.name,1,true),'intro is changed before enter queues text')
local before=stable(game.save.party)
W.decorateBattle(a,battle);check(stable(game.save.party)==before,'player learned moves and PP untouched')
Battle.trainerSprite=pic
for badges=0,8 do
 game.save.inventory={}
 for i=1,badges do game.save.inventory[W.gyms[i].badge]=1 end
 local wild={species='MON_10',level=99}
 R._finalWildLevelAuthority(a,wild,'POKEMON_MANSION_B1F','audit')
 check(wild.level<=7+4*badges,'moved dungeon wild levels track earned badges')
 local team={{species='MON_10',level=99}}
 R._finalTrainerPartyAuthority(a,'OPP_BLAINE',1,team,'CINNABAR_GYM')
 check(team[1].level<=12+4*badges,'moved boss levels track earned badges')
end
game.save.inventory={};a.cfg.statics='UNCHANGED'
check(R.staticLevelScalingActive(a),'fixed battles obey Safe world caps without a Random Start')
local fixed=hooks:call('script.command',function(ctx,name,args) return args end,
 {game=game,mapId='POKEMON_TOWER_6F'},'static_battle',{'MON_10',99},{})
check(fixed[1]=='MON_10' and fixed[2]==7,'native fixed species preserved while its level is capped')
-- Refresh an already loaded gym (Continue) and restore only owned visuals.
game.data.sprites={}
for _,g in ipairs(W.gyms) do
 local class,index=g.key:match('^(.-)#(%d+)$')
 game.data.maps[g.map].objects={{index=1,trainerClass=class,trainerParty=tonumber(index),sprite=g.name,text='TEXT_LEADER'}}
 game.data.sprites[g.name]={}
end
local obj=game.data.maps.PEWTER_GYM.objects[1]
local npc={def=obj,setAppearance=function(self,id) self.appearance=id end}
game.overworld.map={id='PEWTER_GYM'};game.overworld.npcs={npc}
W.present(a)
check(npc.appearance==target.name,'Continue refreshes current gym native NPC appearance')
check(require('data.scripts.gyms').PEWTER_GYM.leader==target.name,'gym statue reports actual leader')
local Data=require('src.core.Data');setmetatable(game.data,{__index=Data})
game.data.text={GREETING='BROCK: I am BROCK.'}
game.data.text_pointers={PEWTER_GYM={TEXT_LEADER={text='GREETING',asm=true}}}
local greeting,asm=game.data:resolveText('PEWTER_GYM','TEXT_LEADER')
check(greeting:find(target.name,1,true) and asm,'native leader greeting changes while script routing stays intact')
W.release(a)
check(npc.appearance=='BROCK' and require('data.scripts.gyms').PEWTER_GYM.leader=='BROCK','owned gym presentation restored')
print('Native Gen 1 presentation/levels: '..n..' total checks')
