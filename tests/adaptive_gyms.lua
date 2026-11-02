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
local chaosLarge,chaosEvolved=false,false
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
 local game=gameFor(v);local cfg=R.defaults(game)
 check(cfg.adaptive_gyms=='OFF','opt-in default')
 cfg.adaptive_gyms='SAFE';cfg.allow_legendaries=false
 local a={game=game,generation=gen,version=v,cfg=cfg,seed=17}
 check(A.preflight(game,cfg),'native trainer preflight')
 check(A.validate(a),v..' every native leader/badge tier has a usable team')
 local catalog=A.catalog(a)
 check(#catalog.ids==(gen==1 and 151 or 251),'exact native dex')
 check(A.theme(gen==1 and G1.byKey['OPP_SABRINA#1'] or G2.byKey.MARSH)=='PSYCHIC_TYPE','native psychic type ID')
 for _,mode in ipairs({'SAFE','CHAOS'}) do
  cfg.adaptive_gyms=mode
  for _,seed in ipairs({1,17,98765}) do a.seed=seed
   for count=0,(gen==1 and 8 or 16) do
    badgeCount(game,count,count%2==0)
    check(A.badges(a)==count,'counts actual earned badges in both stores')
    for _,g in ipairs((gen==1 and G1 or G2).gyms) do
     local class,index=args(g);local rows,info=A.plan(a,class,index);plans=plans+1
     check(stable(rows)==stable(A.plan(a,class,index)),v..' deterministic rematch')
     check(info.badges==count and info.leader==g.key,'earned count and original identity')
     check(#rows==(mode=='SAFE' and math.min(6,2+math.max(0,count-1)) or #rows),'safe 2-to-6 progression')
     check(#rows>=2 and #rows<=6,'native party size')
     if mode=='CHAOS' and count==0 and #rows>2 then chaosLarge=true end
     for _,row in ipairs(rows) do
      local def=game.data.pokemon[row.species];check(def and typeMatch(def,info.theme),'native theme')
      check(not ({ARTICUNO=true,ZAPDOS=true,MOLTRES=true,MEWTWO=true,MEW=true,RAIKOU=true,ENTEI=true,SUICUNE=true,LUGIA=true,HO_OH=true,CELEBI=true})[row.species],'legend exclusion')
      check(row.level>=1 and row.level<=100 and row.level<=A.tier(count).level,'bounded levels')
      check(#row.moves>=1 and #row.moves<=4,'valid moveset length')
      local legal={};for _,m in ipairs(catalog.moves[row.species]) do legal[m]=true end
      local used={};local damaging=false
      for _,m in ipairs(row.moves) do
       check(legal[m] and not used[m],'distinct native legal move');used[m]=true
       local md=game.data.moves[m];check(md.pp>0,'usable PP')
       if md.power>1 then damaging=true end
       if mode=='SAFE' then check(not banned[m],'no early-lock or unpredictable move') end
      end
      if mode=='SAFE' then
       check(damaging,'Safe always has a usable damaging move')
       if count<2 then
        check(catalog.meta[row.species].stage==0,'Safe starts with basic forms')
        check(row.item==nil,'no early held-item stall')
        for _,m in ipairs(row.moves) do check(game.data.moves[m].power<=60,'early move ceiling') end
       end
       check(catalog.meta[row.species].minLevel<=row.level,'no premature evolution in any slot before percentage modifiers')
      elseif count==0 and catalog.meta[row.species].stage>0 then chaosEvolved=true end
      if gen==1 then check(row.item==nil,'no Gen 2 held items in Gen 1') end
     end
    end
   end
  end
 end
 -- No false badge counts for false/zero values; named+numeric aliases count once.
 badgeCount(game,0);if gen==1 then game.save.inventory.BOULDERBADGE=0
 else game.save.player.badges.ZEPHYR=false;game.save.player.badges[1]=0 end
 check(A.badges(a)==0,'unearned badges do not count')
 badgeCount(game,1);if gen==2 then game.save.player.badges[1]=true end
 check(A.badges(a)==1,'aliases never double-count')
 local ordinary=gen==1 and 'OPP_YOUNGSTER' or 'YOUNGSTER'
 check(A.plan(a,ordinary,1)==nil,'ordinary trainer untouched')
 if gen==1 then check(A.plan(a,'OPP_GIOVANNI',1)==nil and A.plan(a,'OPP_GIOVANNI',2)==nil,'Rocket Giovanni is not the gym') end
 cfg.adaptive_gyms='OFF';check(A.party(a,args((gen==1 and G1 or G2).gyms[1]))==nil,'Off has no party override')
end
check(chaosLarge and chaosEvolved,'Chaos allows large evolved opening teams')
print('Native adaptive corpus:',plans,'teams;',checks,'checks')

I.installHardcoded(mod,R);R.installHooks();Worlds.install(mod,R,I)
require('src.mods.Runtime').install(events,hooks)
local Pokemon=require('src.pokemon.Pokemon')
local B1=require('src.battle.BattleState')
love=love or {};love.math={random=math.random}
B1.trainerSprite=function(data,trainer,class,party) return B1.trainerPicPath(data,trainer,class,party) end
local Mon=require('src.battle.gen2.Mon')
local B2=require('src.battle.gen2.Battle')
local Trainers=require('src.world.gen2.Trainers')
local function battle(game,g)
 if gen==1 then local c,p=args(g);return B1.newTrainer(game,c,p) end
 local rec=G2.nativeTrainer(game,g.class)
 return B2.new({data=game.data,save=game.save,party=game.save.party,trainer={class=rec.class,classId=rec.classId,memberId=rec.id,
   name=rec.name,party=Trainers.party(game.data,rec)},random=function() return 0 end})
end
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
 for _,shuffle in ipairs({false,true}) do
  local game=gameFor(v);local cfg=R.defaults(game);cfg.adaptive_gyms='SAFE';cfg.allow_legendaries=false
  if shuffle then cfg.gym_leaders='SAFE';cfg.gym_entrances='SAFE';cfg.dungeon_entrances='SAFE';cfg.badges='SAFE';cfg.random_start='LOGIC' end
  local a,err=R.generate(game,cfg,131);check(a,v..': '..tostring(err));check(R.commit(a),'persist adaptive run')
  game.save.party={(gen==1 and Pokemon or Mon).new(game.data,'PIKACHU',99)}
  game.save.party[1].moves[1].pp=1
  local player=stable(game.save.party)
  local w=gen==1 and G1 or G2
  for _,g in ipairs(w.gyms) do
   for _,count in ipairs({0,4,7}) do
    badgeCount(game,count)
    local class,index=args(g);local expected,info=A.plan(a,class,index)
    local b=battle(game,g)
    check(#b.enemyParty==#expected,'actual native battle size')
    for i,m in ipairs(b.enemyParty) do
     check(m.species==expected[i].species and m.level==expected[i].level,'actual species/level')
     check(m.hp==(gen==1 and m.stats.hp or m.maxHp) and m.hp>0,'native stats/HP rebuilt: '..v)
     local ids={};for _,move in ipairs(m.moves) do ids[#ids+1]=move.id;check(move.pp==game.data.moves[move.id].pp,'native full PP') end
     check(stable(ids)==stable(expected[i].moves),'signature/global learnset cannot overwrite adaptive moves')
     check(m.item==expected[i].item,'native held-item support only')
    end
    check(stable(game.save.party)==player,'player species/moves/PP stay intact')
    if gen==2 then check(b.trainer.classId==w.byKey[info.leader].class,'shuffled portrait identity') end
   end
  end
  badgeCount(game,0);local g=w.gyms[1];local class,index=args(g)
  local before=A.plan(a,class,index)
  for _,pct in ipairs({-50,50}) do
   a.cfg.boss_levels=pct;local scaled=A.plan(a,class,index)
   for i,row in ipairs(scaled) do
    check(row.species==before[i].species and stable(row.moves)==stable(before[i].moves),'Boss% does not reroll team')
    check(row.level==math.floor(before[i].level*(100+pct)/100+0.5),'Boss% applied exactly once')
   end
   local b=battle(game,g);check(b.enemyParty[#scaled].level==scaled[#scaled].level,'actual native Boss% once')
  end
  a.cfg.boss_levels=0
  local expected=stable({A.plan(a,class,index),R.runCode(a),a.gen1World,a.gen2World,a.logicItemPlan})
  R.commit(a);R.abortSavedActivation(game)
  local resumed,why=R.activateSaved(game);check(resumed,tostring(why))
  check(expected==stable({A.plan(resumed,class,index),R.runCode(resumed),resumed.gen1World,resumed.gen2World,resumed.logicItemPlan}),'cold Continue keeps team and world')
  check(R.runCode(resumed):sub(1,5)=='UR190','versioned opt-in run code')
  R.clear(game)
 end
end
-- Explicit precedence under randomized types/stats/evolutions/learnsets/TMs,
-- zero BST tolerance, both progression policies and both adaptive modes.
for _,v in ipairs({'red','yellow','gold','crystal'}) do
 for _,mode in ipairs({'SAFE','CHAOS'}) do for pattern=1,3 do
  local game=gameFor(v);local cfg=R.defaults(game)
  cfg.adaptive_gyms=mode;cfg.safety=pattern==2 and 'CHAOS' or 'SAFE'
  cfg.base_stats=({'UNCHANGED','SHUFFLE','RANDOM'})[pattern]
  cfg.types=({'UNCHANGED','FOLLOW_EVOS','RANDOM'})[pattern]
  cfg.movesets=({'UNCHANGED','TYPE_BIAS','RANDOM'})[pattern]
  cfg.evolutions='RANDOM';cfg.impossible_evos=true;cfg.tms='RANDOM';cfg.tm_compat='FULL'
  cfg.trainers=pattern==1 and 'UNCHANGED' or pattern==2 and 'SIMILAR' or 'TYPE_THEMED'
  cfg.bst_match=true;cfg.bst_difference=0;cfg.allow_legendaries=pattern==3
  local a,why,tries=R.generate(game,cfg,179);check(a,v..' combined '..mode..' '..pattern..': '..tostring(why))
  check(tries<=50,'bounded setting-combination generation')
  local original=native[v];local c=A.catalog(a)
  for id,m in pairs(c.meta) do
   local source=a.adaptiveSource[id]
   check(source and stable(source.evolutions.value)==stable(original.pokemon[id].evolutions),'native evolution graph survives target randomization')
  end
  local g=(gen==1 and G1 or G2).gyms[1];local class,index=args(g)
  if gen==2 then
   local rec=G2.nativeTrainer(game,g.class)
   check(stable(A.plan(a,rec.class,rec.member))==stable(A.plan(a,class,index)),'numeric native trainer identity')
  end
  game.save.party={(gen==1 and Pokemon or Mon).new(game.data,'PIKACHU',5)}
  local plan=A.plan(a,class,index);local b=battle(game,g)
  check(b.enemyParty[1].species==plan[1].species,'adaptive species override conflicting trainer/BST choice')
  local moves={};for _,m in ipairs(b.enemyParty[1].moves) do moves[#moves+1]=m.id end
  check(stable(moves)==stable(plan[1].moves),'adaptive native legal moves override global learnsets/TMs')
  R.clear(game)
 end end
end
-- Compare actual released 1.8.0 seeds, including both full world adapters.
local oldR=dofile('dist/baseline/randomizer-1.8.0.lua')(mod,Core,dofile(base..'/adapters.lua'),I,L,Worlds)
local function snapshot(r,a)
 local cfg=Core.copy(a.cfg);cfg.adaptive_gyms=nil
 return stable({cfg,a.fingerprint,r.runCode(a),a.starterMap,a.badgePlan,a.logicItemPlan,a.gen1World,a.gen2World})
end
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
 for mode=1,3 do
  local game=gameFor(v);local cfg=oldR.defaults(game)
  if mode>=2 then cfg.gym_leaders='SAFE';cfg.gym_entrances='SAFE';cfg.dungeon_entrances='SAFE';cfg.badges='SAFE' end
  if mode==3 then cfg.random_start='LOGIC' end
  local prior,why=oldR.generate(game,cfg,44);check(prior,tostring(why));local expected=snapshot(oldR,prior)
  oldR.commit(prior);oldR.abortSavedActivation(game)
  local resumed,why=R.activateSaved(game);check(resumed,tostring(why))
  check(resumed.cfg.adaptive_gyms=='OFF','1.8.0 Continue defaults Off')
  check(snapshot(R,resumed)==expected,'1.8.0 Continue preserves exact seed/fingerprint/world: '..v..' '..mode)
  R.clear(game);game=gameFor(v)
  local current,why=R.generate(game,cfg,44);check(current,tostring(why))
  check(snapshot(R,current)==expected,'same Off configuration replays 1.8.0 exactly: '..v..' '..mode)
  R.clear(game)
 end
end
-- Bad types/stats combinations fail validation instead of launching an empty team.
local game=gameFor('crystal');local cfg=R.defaults(game);cfg.adaptive_gyms='SAFE'
local a={game=game,generation=2,cfg=cfg,seed=1}
for _,def in pairs(game.data.pokemon) do def.types={'NORMAL'} end
local pass,why=A.validate(a);check(not pass and why:find('No eligible',1,true),'empty themed pools fail closed')
game=gameFor('red');game.data.trainers.OPP_BROCK=nil
check(not A.preflight(game,cfg),'missing native roster fails preflight')
cfg.adaptive_gyms='INVALID';check(not R.preflight(game,cfg),'invalid setting rejected')
print('PASS:',checks,'adaptive gym checks;',plans,'native team plans; six editions + actual Gen 1/2 battle constructors')
