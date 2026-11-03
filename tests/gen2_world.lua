local root=os.getenv('MOD_SOURCE') or 'mod'
local base=os.getenv('MOD_BASE') or 'dist/baseline'
local host=os.getenv('HOST_SOURCE') or '../host-source'
package.path=host..'/?.lua;'..package.path
unpack=table.unpack or unpack
dofile('tests/support/bit54.lua')
local version,gen='gold',2
package.loaded['src.core.GameVersion']={get=function() return version end,generation=function() return gen end,isYellow=function() return version=='yellow' end}
local Core=dofile(base..'/core.lua')
local I=dofile(root..'/progression_items.lua')(Core)
local L=dofile(root..'/logic_graph.lua')(Core)
local G1=dofile(root..'/gen1_world.lua')(Core)
local W=dofile(root..'/gen2_world.lua')(Core)
local Worlds=dofile(root..'/worlds.lua')(G1,W)
local hooks,events=require('src.mods.Hooks').new(),require('src.mods.Events').new()
local saved={}
local mod={hooks={wrap=function(_,n,f,p) return hooks:wrap(n,f,p,'universal_randomizer') end},events={on=function(_,n,f,p) return events:on(n,f,p,'universal_randomizer') end},
 save={get=function(_,k,d) if saved[k]==nil then return d end;return saved[k] end,set=function(_,k,v) saved[k]=v end},
 log={error=function(_,fmt,...) error(fmt:format(...)) end},world={removeNpc=function() end}}
local R=dofile(root..'/randomizer.lua')(mod,Core,dofile(base..'/adapters.lua'),I,L,Worlds)
local fixture=dofile('tests/support/audit_fixture.lua')({Core=Core,I=I,L=L,R=R,mod=mod,hooks=hooks,events=events,setVersion=function(g,v) gen,version=g,v end})
local n=0
local function check(v,msg) assert(v,msg);n=n+1 end
local function gameFor(v)
 local game=fixture(2,v);local ports=dofile('tests/support/gen2_portals.lua')[v=='crystal' and 'crystal' or 'gold']
 for id,def in pairs(ports) do
  game.data.gen2Maps[id]=game.data.gen2Maps[id] or {id=id,objects={}}
  for k,x in pairs(def) do game.data.gen2Maps[id][k]=Core.copy(x) end
 end
 game.data.gen2Trainers={classes={}}
 game.data.sprites={}
 for i,g in ipairs(W.gyms) do
  game.data.gen2Trainers.classes[g.class]={id=g.class,index=i,name=g.name,baseMoney=100,
   trainers={{id=g.class..'1',name=g.name,party={{species='MON_'..(10+i),level=10+i,moves={'TACKLE'},item='ANTIDOTE'},{species='MON_'..(30+i),level=12+i,moves={'TACKLE'}}}}}}
  game.data.sprites[g.sprite]={}
  game.data.gen2Maps[g.map].objects[#game.data.gen2Maps[g.map].objects+1]={sprite=g.sprite,index=1}
 end
 return game
end
local game=gameFor('gold');local cfg=R.defaults(game)
cfg.gym_leaders='SAFE';cfg.gym_entrances='SAFE';cfg.dungeon_entrances='SAFE';cfg.badges='SAFE'
local ok,why=R.preflight(game,cfg);check(ok,tostring(why))
local ports=W.portals(game,L);check(#ports==34,'34 physical portals, got '..#ports)
for _,start in ipairs({'OFF','CHERRYGROVE_CITY','AZALEA_TOWN','GOLDENROD_CITY','ECRUTEAK_CITY','OLIVINE_CITY','CIANWOOD_CITY','MAHOGANY_TOWN','BLACKTHORN_CITY'}) do
 local sid=start~='OFF' and start or nil
 local mapping,err=R._checkedBadgeAssignment(2,77,sid and {id=sid},game,cfg)
 check(mapping,tostring(err)..' start '..start)
 local native=R._nativeAuditPlan(2,sid,mapping)
 local world=W.identity(game,cfg,sid,mapping,L)
 local pass,proof=W.replay(world,native)
 check(pass,start..' blocked '..table.concat(proof.blocked,',')..' entrances '..table.concat(proof.inaccessible,','))
end
for seed=1,8 do
 local c=Core.copy(cfg);c.random_start=seed==1 and 'OFF' or 'LOGIC'
 local a,err,attempts=R.generate(game,c,seed)
 check(a,tostring(err));check(attempts<=50,'bounded attempts')
 check(a.gen2World.proof.complete,'completion')
 print('seed',seed,'start',a.gen2World.start,'attempts',attempts)
end

local function stable(t)
 if type(t)~='table' then return tostring(t) end
 local out={};for _,k in ipairs(Core.sortedKeys(t)) do out[#out+1]=tostring(k)..'='..stable(t[k]) end
 return '{'..table.concat(out,',')..'}'
end
-- Native host hook dispatch; the complete ROM renderer is not mocked into a
-- pretend playthrough. Presentation/constructor tests are separate below.
I.installHardcoded(mod,R);R.installHooks();Worlds.install(mod,R,I)
require('src.mods.Runtime').install(events,hooks)
local generated=0
if not os.getenv('UR_PRESENTATION_ONLY') then
for _,v in ipairs({'gold','silver','crystal'}) do
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
  local world=a.gen2World
  check(world.checked==(mode=='SAFE'),'Chaos never gets Safe certification')
  local used={}
  for _,p in ipairs(world.portals) do
   local dest=world.destinations[p.id]
   check(dest and not used[dest],'one-to-one entrance');used[dest]=true
   if cfg[p.kind..'_entrances']=='OFF' then check(dest==p.id,'disabled pool fixed') end
   if world.checked then check(world.byId[dest].zone==p.zone,'Safe preserves native regional badge-count triggers') end
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
   check(stable({resumed.gen2World.destinations,resumed.gen2World.leaders,resumed.gen2World.badges,resumed.logicItemPlan.locations})==snapshot,'cold Continue never rerolls')
   check(R.runCode(resumed):find('UR180',1,true)==1,'new Gen 2 run namespace')
  end
 end end
end
-- Every supported start with both pool modes and both badge/leader policies,
-- on all three native cartridges. Force one imported fly landing at a time.
for _,v in ipairs({'gold','silver','crystal'}) do
 for _,start in ipairs(L.logicStarts(2)) do
  for _,pool in ipairs({'SEPARATE','MIXED'}) do for _,pairing in ipairs({'INDEPENDENT','WITH_LEADER'}) do
   game=gameFor(v);local landing=game.data.field.flyWarps[start]
   game.data.field.flyWarps={[start]=landing}
   cfg=R.defaults(game);cfg.random_start='LOGIC';cfg.badges='SAFE'
   cfg.gym_leaders='SAFE';cfg.gym_entrances='SAFE';cfg.dungeon_entrances='SAFE'
   cfg.entrance_pool=pool;cfg.badge_pairing=pairing
   local a,why,tries=R.generate(game,cfg,379)
   check(a,v..' '..start..' '..pool..' '..pairing..': '..tostring(why));generated=generated+1
   check(tries==1,'constructive checked planner succeeds without blind rerolls')
   check(a.gen2World.start==start,'requested native start exercised')
   check(a.gen2World.proof.complete,'all-start combined proof')
   local all=W.portals(game,L);local byId={};for _,p in ipairs(all) do byId[p.id]=p end
   for _,p in ipairs(all) do
    local target=byId[a.gen2World.destinations[p.id]]
    for i,exit in ipairs(target.reverseEndpoints) do
     local back=a.doorPlan.byWarp[exit.warp];local source=p.sourceEndpoints[((i-1)%#p.sourceEndpoints)+1]
     check(back.map==source.map and back.x==source.warp.x and back.y==source.warp.y,'every exit returns to its exact paired entrance')
    end
   end
  end end
 end
end
game=gameFor('gold');cfg=R.defaults(game);cfg.gym_entrances='SAFE';cfg.dungeon_entrances='SAFE';cfg.badges='SAFE'
local a,err=R.generate(game,cfg,43);check(a,tostring(err))
local native=W.identity(game,a.cfg,nil,nil,L)
local cross=Core.copy(native);local johto,kanto
for _,p in ipairs(cross.portals) do if p.zone=='JOHTO' then johto=p else kanto=p end end
cross.destinations[johto.id],cross.destinations[kanto.id]=kanto.id,johto.id
check(not W.replay(cross,R._nativeAuditPlan(2,nil,nil)),'early Kanto badge-count event skip rejected')
local broken=R._nativeAuditPlan(2,nil,nil)
broken.locations.RADIO_BASEMENT='CARD_KEY';broken.locations.WAREHOUSE_CARD='BASEMENT_KEY'
check(not W.replay(native,broken),'Basement Key behind its own door rejected')
broken=R._nativeAuditPlan(2,nil,nil);broken.locations.ELM_TICKET='HM_WATERFALL';broken.locations.ICE_WATERFALL='S_S_TICKET'
check(not W.replay(native,broken),'Waterfall after the League rejected')
local badges={ZEPHYR='HIVE',HIVE='ZEPHYR'}
check(not W.replay(W.identity(game,a.cfg,nil,badges,L),R._nativeAuditPlan(2,nil,badges)),'Zephyr badge behind Union route guard rejected')
local isolated={generation=2,start='BLACKTHORN_CITY',portals={},byId={},destinations={},badges={}}
for _,p in ipairs(native.portals) do if p.content=='ICE' then
 local c=Core.copy(p);c.region=p.puzzleOrigin and 'ISOLATED' or 'BLACKTHORN'
 isolated.portals[#isolated.portals+1]=c;isolated.byId[c.id]=c;isolated.destinations[c.id]=c.id
end end
local seen=W.worldState(isolated,{HM_STRENGTH=true,BADGE_PLAIN=true})
check(not seen.ISOLATED,'wrong-side Ice Path cannot operate west boulders')
check(not W.checkRule({key='UNKNOWN_KEY'}),'unknown progression source rejected')
local supplies=Core.copy(cfg);supplies.mart_safety=false;supplies.marts='CHAOS'
local supplyCfg=R.normalizedConfig(supplies,game)
check(supplyCfg.mart_safety,'Safe worlds retain renewable catching/healing stock even with broad shop pool')
check(R.setLiveMartSafety(game,false) and R.active().cfg.mart_safety,'live options cannot remove Safe world essentials')
local oldWarps=game.data.gen2Maps.PEWTER_CITY.warps;game.data.gen2Maps.PEWTER_CITY.warps={}
check(not R.preflight(game,cfg),'missing actual gym entrance rejected')
game.data.gen2Maps.PEWTER_CITY.warps=oldWarps
local duplicate=Core.copy(a.gen2World);local p1,p2=duplicate.portals[1],duplicate.portals[2]
duplicate.destinations[p1.id]=duplicate.destinations[p2.id]
check(not W.bind(duplicate,W.portals(game,L)),'duplicate reverse destinations rejected')
local moon
for _,p in ipairs(native.portals) do if p.region=='MOON_EAST' then moon=p end end
check(moon~=nil,'east Mt. Moon mouth modeled separately')
local seen=W.worldState({start='GOLDENROD_CITY',portals={},byId={},destinations={},badges={}}, {})
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
local yes,msg=W.award(mod,a,I,'trainer','FALKNER#1');check(yes and msg:find('PC',1,true),'full-bag bonus sent to PC')
check(not W.award(mod,a,I,'trainer','FALKNER#1'),'rematch cannot duplicate bonus')
check(#W.state(a).rewards==1,'bonus log factual')
check(R.commit(a),'persist bonus claims')
a=assert(R.activateSaved(game));check(not W.award(mod,a,I,'trainer','FALKNER#1'),'claims survive load')
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
game=gameFor('gold');local st=assert(R.beginGenerate(game,cfg,90));local frames=0
while not st.done and frames<701 do R.stepGenerate(st);frames=frames+1 end
check(st.active and st.attempt==50 and calls==50,'valid checked seed on attempt 50')
check(frames==700,'one bounded stage per frame')
W.build=function() return nil,'[seed] persistent rejected candidate' end
st=assert(R.beginGenerate(game,cfg,90));frames=0
while not st.done and frames<701 do R.stepGenerate(st);frames=frames+1 end
check(st.done and not st.active and st.attempt==50 and frames==700,'failure stops exactly at 50')
check(R.active()==nil,'no rejected world is active')
W.build=build
print(('Gen 2 world: %d checks passed; %d setting worlds'):format(n,generated))
end
-- Actual Gen 2 constructor, party factory, badge engine flags and script hook.
local Battle=require('src.battle.gen2.Battle')
local Trainers=require('src.world.gen2.Trainers')
local Mon=require('src.battle.gen2.Mon')
local NativeWorld=require('src.world.gen2.World')
local FieldMoves=require('src.world.gen2.FieldMoves')
for _,v in ipairs({'gold','silver','crystal'}) do
 game=gameFor(v);cfg=R.defaults(game);cfg.gym_leaders='SAFE';cfg.badges='SAFE';cfg.trainers='UNCHANGED';cfg.movesets='UNCHANGED';cfg.statics='UNCHANGED'
 local a=assert(R.generate(game,cfg,88));check(R.commit(a),'native run commit')
 for id,d in pairs(game.data.pokemon) do d.name=id;d.growthRate='MEDIUM_FAST';d.catchRate=45;d.baseExp=50 end
 for _,m in pairs(game.data.moves) do m.pp=m.pp or 20;m.accuracy=m.accuracy or 100 end
 game.save.party={Mon.new(game.data,'MON_10',12)}
 local playerMoves=stable(game.save.party[1].moves)
 local source=W.gyms[1];local target=W.byKey[a.gen2World.leaders[source.key]]
 local record=W.nativeTrainer(game,source.class)
 local opts={data=game.data,save=game.save,party=game.save.party,trainer={class=record.class,classId=record.classId,memberId=record.id,
   name=record.name,party=Trainers.party(game.data,record),baseMoney=100},random=function(n) return 0 end}
 local battle=Battle.new(opts)
 check(battle.trainer.classId==target.class and battle.trainer.name==target.name,'native target identity supplies portrait/palette lookup')
 check(battle.enemyParty[1].species==W.nativeTrainer(game,target.class).roster[1].species,'actual target native-shaped roster selected')
 check(battle.enemyParty[1].item=='ANTIDOTE','held item survives native party construction')
 check(record.classId==source.class and record.id==source.class..'1','original script record retains event/reward owner')
 check(battle._urSourceTrainer==source.class..'#1','bonus claim retains source trainer identity')
 check(stable(game.save.party[1].moves)==playerMoves,'player moves and PP stay intact')
 for _,m in ipairs(battle.enemyParty) do check(m.level<=12,'early boss cap');check(m.hp and m.maxHp and m.hp==m.maxHp,'native stats rebuilt at final level') end
 for count=0,16 do
  game.save.player.badges={};game.save.player.kantoBadges={}
  for i=1,count do local g=W.gyms[i];game.save.player[g.store][g.badge]=true end
  local limit=7+4*math.min(count,8)+5*math.max(0,count-8)
  check(W.levelCap(a,'wild')==limit,'16-badge wild ceiling')
  check(W.levelCap(a,'boss')==limit+5,'16-badge boss ceiling')
 end
 check(R.staticLevelScalingActive(a),'fixed encounters obey Safe world cap')
 game.save.player.badges={};game.save.player.kantoBadges={}
 local fixed=hooks:call('script.command',function(ctx,name,args,cmd) return cmd end,
  {game=game,mapId='LAKE_OF_RAGE'},'loadwildmon',{}, {species=10,level=99})
 check(fixed.species==10 and fixed.level==7,'native fixed battle retains species and gets Safe level ceiling')
 local offset=v=='crystal' and 27 or 26
 game.data.gen2Constants={engineFlagOrder={}}
 for i,g in ipairs(W.gyms) do game.data.gen2Constants.engineFlagOrder[offset+i]='ENGINE_'..g.badge..'BADGE' end
 FieldMoves.bindEngineFlags(game.data.gen2Constants.engineFlagOrder)
 W.prepare(a)
 for i,g in ipairs(W.gyms) do
  game.save.player.badges={};game.save.player.kantoBadges={}
  local before=stable(game.save.events or {})
  hooks:call('script.command',function(ctx,name,args,cmd)
    NativeWorld.setEngineFlag({game=game},cmd.flag,true)
  end,{game=game,mapId=g.map},'setflag',{offset+i-1},{flag=offset+i-1,args={offset+i-1}})
  local expected=W.byKey[a.gen2World.badges[g.key]]
  check(W.badgeOwned(a,expected),'correct native badge flag: '..v..' '..g.key)
  check(stable(game.save.events or {})==before,'badge remap cannot change gym event flags')
 end
 -- Native sprite setter contract; refresh immediately on Continue then restore.
 game.world.sprites=game.data.sprites;game.world.map={id=source.map};game.world.game=game
 local obj={sprite=source.sprite};local npc={def=obj,setSpriteDef=function(self,def) self.rendered=def;return true end}
 game.world.npcs={npc};game.world.applySpritePalette=function() end
 W.present(a);check(npc.appearance==target.sprite,'native NPC appearance uses target sprite')
 W.release(a);check(npc.appearance==source.sprite,'owned NPC appearance restored')
 game.world.events=require('src.world.gen2.Events').new()
 game.world.events:set(require('src.core.gen2.FlagNames').events[source.flag],true)
 check(W.tracker(a)[1].right=='Cleared','tracker reads actual event bitfield')
 local worldPlan=a.gen2World;a.gen2World=nil
 check(W.tracker(a)[1].help:find(a.badgePlan.gymToBadge[source.key]..' Badge',1,true),'tracker reports standalone randomized badge rewards')
 a.gen2World=worldPlan
 local vm={text={INTRO=source.name..' gives a '..source.badge..'BADGE.'}}
 local text=hooks:call('script.command',function(ctx,name,args,cmd) return ctx.vm.text[cmd.text] end,
  {game=game,mapId=source.map,vm=vm},'writetext',{}, {text='INTRO'})
 check(text:find(target.name,1,true)~=nil,'native dialogue names moved leader')
 local surge=W.byKey.THUNDER;local moved=W.byKey[a.gen2World.leaders.THUNDER]
 vm.text.SURGE='SURGE: THUNDER-\nBADGE. Defeat LT.SURGE!'
 local surgeText=hooks:call('script.command',function(ctx,name,args,cmd) return ctx.vm.text[cmd.text] end,
  {game=game,mapId=surge.map,vm=vm},'writetext',{}, {text='SURGE'})
 check(surgeText:find(moved.name..':',1,true) and surgeText:find('Defeat '..moved.name..'!',1,true),'native LT.SURGE and SURGE aliases use moved identity')
 local badge=a.gen2World.badges.THUNDER
 check(badge=='THUNDER' or surgeText:find(badge..'BADGE',1,true),'native hyphenated badge dialogue uses selected reward')
end
local retained=R.active();local lastGame=retained.game
hooks:removeOwner('universal_randomizer')
local original=W.nativeTrainer(lastGame,'FALKNER')
local b=Battle.new({data=lastGame.data,save=lastGame.save,party=lastGame.save.party,trainer={class=original.class,classId=original.classId,memberId=original.id,name=original.name,party=Trainers.party(lastGame.data,original)}})
check(b.trainer.classId=='FALKNER' and b._urSourceTrainer==nil,'disabled mod cannot keep decorating native battles')
R.clear(lastGame)
check(saved.gen2_state==nil and saved.gen2_world==nil,'clear removes Gen 2 world, rumors and bonus claims')
print('PASS: '..n..' Gen 2 world and native runtime checks')
