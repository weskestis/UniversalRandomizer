-- Native species/moves/rosters, actual host party hooks and battle constructors.
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
R.AdaptiveBosses=dofile(root..'/adaptive_bosses.lua')(Core,Worlds,A,R)
R.RunTools=dofile(root..'/run_tools.lua')(mod,Core,R,Worlds,A)
local B,T=R.AdaptiveBosses,R.RunTools
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
local function badgeCount(game,n,numeric)
 game.save.inventory={};game.save.player.badges={};game.save.player.kantoBadges={}
 for i,g in ipairs((gen==1 and G1 or G2).gyms) do
  if i<=n then
   if gen==1 then game.save.inventory[g.badge]=1
   else game.save.player[g.store][numeric and g.index or g.badge]=true end
  end
 end
end
local function args(g)
 if gen==1 then local c,p=g.key:match('^(.-)#(%d+)$');return c,tonumber(p) end
 return g.class,1
end
local function typeMatch(def,theme)
 if theme=='MIXED' then return true end
 for _,t in ipairs(def.types) do if t==theme then return true end end
 return false
end
local banned={FISSURE=true,HORN_DRILL=true,GUILLOTINE=true,SONICBOOM=true,DRAGON_RAGE=true,EXPLOSION=true,SELFDESTRUCT=true,SEISMIC_TOSS=true,NIGHT_SHADE=true,METRONOME=true}

local total=0
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
 local game=gameFor(v);mod.game=game
 local cfg=R.defaults(game);cfg.adaptive_bosses='SAFE';cfg.rival_starter=false
 local a={game=game,generation=gen,version=v,cfg=cfg,seed=17}
 check(T.preflight(game,cfg),'new defaults accepted')
 local ok,why=B.validate(a);check(ok,v..': '..tostring(why))
 local encounters=B.encounters(a);check(#encounters>10,'native story encounters included')
 for _,e in ipairs(encounters) do
  for _,n in ipairs({0,2,6,gen==1 and 8 or 16}) do
   local profile=B.profile(e.source,n)
   check(profile.level==math.min(e.source.peak,A.tier(n).level),'story phase follows the full earned-badge curve')
   local rows,meta=B.plan(a,e.class,e.index,n);check(rows and #rows>0,meta)
   check(#rows<=#e.source.roster,'safe does not expand early encounter roster')
   for _,row in ipairs(rows) do
    check(game.data.pokemon[row.species]~=nil,'native species')
    check(#row.moves>=1 and #row.moves<=4,'usable move count')
    if e.source.peak<=9 then check(row.level<=9 and #rows==1,'opening rival protection') end
    for _,move in ipairs(row.moves) do check(game.data.moves[move]~=nil,'native move') end
   end
   total=total+1
  end
 end
 cfg.rival_starter=true
 check(B.validate(a),'native rival starter families remain eligible')
 for _,e in ipairs(encounters) do if e.source.rival then
   local rows=B.plan(a,e.class,e.index,0);local catalog=A.catalog(a)
   check(catalog.meta[rows[#rows].species].root==catalog.meta[e.source.roster[#e.source.roster].species].root,'rival family retained')
 end end
 local off=Core.copy(cfg);off.adaptive_bosses='OFF'
 local legacy=Core.copy(off);for k in pairs(T.defaults) do legacy[k]=nil end
 check(R.configFingerprint(17,off,v)==R.configFingerprint(17,legacy,v),'new default keys preserve legacy fingerprint')
 local code=T.exportCode(a);local imported,err=T.importCode(game,code)
 check(imported~=nil,'share import: '..tostring(err));check(stable(imported.cfg)==stable(cfg),'every setting round trips')
 check(imported.seed==17,'actual accepted seed round trips')
 check(T.importCode(game,code..'X')==nil,'corrupt code rejected')
 check(T.importCode(game,string.rep('x',16001))==nil,'size bounded')
 local prefix=code:match('^(UR110:%d+:)');local wrong=code:gsub(prefix,prefix,1)
 local originalVersion=version;version=v=='red' and 'yellow' or 'red'
 check(T.importCode(game,wrong)==nil,'wrong cartridge rejected');version=originalVersion
 local rows=T.objectives(a);check(rows[1].id=='CHAMPION','native completion')
 cfg.victory_goal='CHECKLIST';a.objectives=T.objectives(a);check(#a.objectives==5,'five deterministic native goals')
 check(stable(a.objectives)==stable(T.objectives(a)),'goal determinism')
 local pass=T.prepare(a);check(not pass,'custom SAFE goal without proof rejected')
 local w={checked=true,proof={complete=true}};if gen==1 then a.gen1World=w else a.gen2World=w end
 check(T.prepare(a),'complete native proof accepted')
 T.start(a);T.state(a).seconds=12;T.persist(a)
 local clone=Core.copy(a);clone.game=game;clone.runRecord=nil;T.restore(clone);check(T.state(clone).seconds==12,'run clock resumes')
 clone.seed=99;clone.runRecord=nil;T.restore(clone);check(T.state(clone).seconds==0,'other seed cannot inherit record')
 for _,o in ipairs(a.objectives) do T.win(a,o.id,o.label) end
 check(T.state(a).completed,'checklist actually completes');check(T.recap(a):find('GOAL COMPLETE',1,true),'recap completion')
 check(T.state(a).finishedAt==12,'finish time frozen')
 local splitCount=#T.state(a).splits;T.win(a,'EXTRA','Post-goal win');check(#T.state(a).splits==splitCount,'post-goal play cannot rewrite finish splits')
 cfg.race_mode=true;check(not T.locked(a),'completed race unlocks')
 a.runRecord.completed=false;check(T.locked(a),'ongoing race locked')
 check(T.diagnostic(a):find('Seed: 17',1,true),'diagnostic contains reproducible seed')
end
print('PASS: '..checks..' story boss / goal / share / save checks across '..total..' native story plans')
-- Exercise the real native constructors after the final trainer hook.
I.installHardcoded(mod,R);R.installHooks();Worlds.install(mod,R,I);T.install()
require('src.mods.Runtime').install(events,hooks)
local Pokemon=require('src.pokemon.Pokemon')
local Battle1=require('src.battle.BattleState')
local Mon=require('src.battle.gen2.Mon')
local Battle2=require('src.battle.gen2.Battle')
local Trainers=require('src.world.gen2.Trainers')
love={math={random=math.random},timer={getTime=function() return 0 end}}
Battle1.trainerSprite=function(data,trainer,class,party) return Battle1.trainerPicPath(data,trainer,class,party) end
local function construct(game,e)
 if gen==1 then return Battle1.newTrainer(game,e.class,e.index) end
 local data=game.data.gen2Trainers or game.data.trainers
 local rec=Trainers.lookup(data,data.classes[e.class].index,e.index)
 return Battle2.new({data=game.data,save=game.save,party=game.save.party,trainer={class=rec.class,classId=rec.classId,member=rec.member,memberId=rec.id,
   name=rec.name,party=Trainers.party(game.data,rec)},random=function() return 0 end})
end
for _,v in ipairs({'red','yellow','gold','crystal'}) do
 local game=gameFor(v);mod.game=game
 local cfg=R.defaults(game);cfg.adaptive_bosses='SAFE';cfg.race_mode=true;cfg.victory_goal='CHECKLIST'
 cfg.gym_leaders='SAFE';cfg.gym_entrances='SAFE';cfg.dungeon_entrances='SAFE';cfg.random_start='LOGIC'
 local a,why=R.generate(game,cfg,131);check(a,v..' integrated seed: '..tostring(why));check(R.commit(a),'commit run')
 game.save.party={(gen==1 and Pokemon or Mon).new(game.data,'PIKACHU',5)}
 for _,e in ipairs(B.encounters(a)) do
  local expected=B.plan(a,e.class,e.index)
  local b=construct(game,e)
  check(#b.enemyParty==#expected,'native story party size')
  for i,m in ipairs(b.enemyParty) do
   check(m.species==expected[i].species and m.level==expected[i].level,'native story species / level '..v..' '..e.source.key..' '..i..' got '..m.species..'/'..m.level..' expected '..expected[i].species..'/'..expected[i].level)
   local moves={};for _,row in ipairs(m.moves) do moves[#moves+1]=row.id;check(row.pp==game.data.moves[row.id].pp,'native PP') end
   check(stable(moves)==stable(expected[i].moves),'signature moves cannot override curated story moves')
  end
 end
 check(R.spoilerData(game)==nil,'race spoiler export blocked')
 check(R.hintForSign('MAP',1,1):find('Race mode',1,true),'race sign blocked')
 local money=game.save.money;check(R.buyHint(game)==nil and money==game.save.money,'race paid hint cannot charge')
 -- A source gym, not its shuffled leader, earns the completion credit.
 local g=(gen==1 and G1 or G2).gyms[1]
 if gen==2 then
  local source=G2.nativeTrainer(game,g.class)
  local actual=Battle2.new({data=game.data,save=game.save,party=game.save.party,trainer={class=source.class,classId=source.classId,member=source.member,memberId=source.id,
    name=source.name,party=Trainers.party(game.data,source)},random=function() return 0 end})
  check(actual._urSourceTrainer~=nil,'shuffled native battle carries source identity')
  T.battleEnd({battle=actual,result='win'})
  check(T.state(a).wins['GYM:'..g.key],'shuffled Gen 2 gym credits source, not presented leader')
  T.state(a).wins['GYM:'..g.key]=nil;T.state(a).splits={}
 end
 local c,p=args(g)
 local b=gen==1 and {kind='trainer',oppClass=c,partyIndex=p} or {trainer={classId=c,member=1}}
 T.battleEnd({battle=b,result='lose'});check(not T.state(a).wins['GYM:'..g.key],'losing never completes a goal')
 T.battleEnd({battle=b,result='win'});check(T.state(a).wins['GYM:'..g.key],'native gym source wins recorded')
 local count=#T.state(a).splits;T.battleEnd({battle=b,result='win'});check(#T.state(a).splits==count,'rematches do not duplicate split')
 T.state(a).seconds=57;T.persist(a);R.abortSavedActivation(game)
 local resumed,err=R.activateSaved(game);check(resumed,tostring(err));check(T.state(resumed).seconds==57,'Continue resumes exact record')
 check(stable(a.objectives)==stable(resumed.objectives),'Continue retains objective list')
 R.clear(game)
end
print('PASS: '..checks..' combined native-constructor, race and Continue checks')

for _,v in ipairs({'red','crystal'}) do
 local game=gameFor(v);mod.game=game
 for _,goal in ipairs({'CHAMPION','BADGES','CHECKLIST',gen==2 and 'RED' or 'CHAMPION'}) do
  local cfg=R.defaults(game);cfg.victory_goal=goal
  local a,why=R.generate(game,cfg,131);check(a,'unshuffled custom goal '..v..' '..goal..': '..tostring(why))
  check((a.gen1World or a.gen2World).proof.complete,'goal-only run has complete world proof')
  R.clear(game)
 end
end
print('PASS: '..checks..' total new-run checks including unshuffled custom goals')

-- Real presets use the full generator and bounded automatic retry path.
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
 for _,preset in ipairs(T.presets) do
  local game=gameFor(v);mod.game=game;local cfg=T.preset(game,preset)
  local ok,why=R.preflight(game,cfg);check(ok,'preset preflight '..v..' '..preset.id..': '..tostring(why))
  local a,err,tries=R.generate(game,cfg)
  check(a,'preset generation '..v..' '..preset.id..': '..tostring(err))
  check(tries<=50,'preset retry bound');check(a.cfg.pokedex=='NATIVE','preset retains native content')
  R.clear(game)
 end
end
print('PASS: '..checks..' total run tools checks including all six editions and presets')

-- The released 1.9.0 generator remains the oracle for default-Off migration.
local oldR=dofile('dist/baseline/randomizer-1.9.0.lua')(mod,Core,dofile(base..'/adapters.lua'),I,L,Worlds,A)
local function baselineSnapshot(r,a)
 local cfg=Core.copy(a.cfg);for k in pairs(T.defaults) do cfg[k]=nil end
 return stable({cfg,a.fingerprint,r.runCode(a),a.starterMap,a.logicItemPlan,a.badgePlan,a.gen1World,a.gen2World})
end
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
 local oldGame=gameFor(v);mod.game=oldGame;local cfg=oldR.defaults(oldGame)
 cfg.adaptive_gyms='SAFE'
 local prior,why=oldR.generate(oldGame,cfg,44);check(prior,tostring(why));local expected=baselineSnapshot(oldR,prior)
 oldR.clear(oldGame)
 local game=gameFor(v);mod.game=game;local current,err=R.generate(game,cfg,44);check(current,tostring(err))
 check(baselineSnapshot(R,current)==expected,'1.9.0 seed/team/world/fingerprint preserved: '..v)
 R.clear(game)
end
print('PASS: '..checks..' run tools checks, including released 1.9.0 generator comparison')

-- Import is deliberately stricter than ordinary 50-candidate generation.
do
 local game=gameFor('red');mod.game=game;local cfg=R.defaults(game)
 cfg.adaptive_bosses='SAFE'
 local validate=B.validate;B.validate=function() return false,'[seed] simulated changed-data incompatibility' end
 local handle=assert(R.beginGenerate(game,cfg,98765,{exactSeed=true}))
 while not handle.done do R.stepGenerate(handle) end
 check(handle.active==nil and handle.attempt==1 and handle.seed==98765,'invalid imported seed is rejected without rerolling')
 B.validate=validate;R.clear(game)
end
for _,v in ipairs({'red','crystal'}) do
 for _,mode in ipairs({'SAFE','CHAOS'}) do
  local game=gameFor(v);mod.game=game;local cfg=R.defaults(game)
  cfg.adaptive_bosses=mode;cfg.starters='RANDOM';cfg.evolutions='RANDOM';cfg.types='RANDOM';cfg.base_stats='SHUFFLE';cfg.movesets='TYPE_BIAS';cfg.trainers='TYPE_THEMED';cfg.tms='RANDOM';cfg.tm_compat='FULL';cfg.bst_match=true;cfg.bst_difference=0
  local a,why,tries=R.generate(game,cfg,179);check(a,'combined story settings '..v..' '..mode..': '..tostring(why))
  check(tries<=50,'combined settings retain attempt bound')
  for _,e in ipairs(B.encounters(a)) do
   local rows=B.plan(a,e.class,e.index);check(rows and #rows>0,'combined native story plan')
   for _,row in ipairs(rows) do for _,move in ipairs(row.moves) do check(Core.tableHas(A.catalog(a).moves[row.species],move),'story moves remain in the native catalog after global randomization') end end
  end
  R.clear(game)
 end
end
print('PASS: '..checks..' final story/run checks including coupled settings and exact import rejection')
