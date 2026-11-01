-- Exercise the pinned engines' actual movesAtLevel builders. Synthetic native
-- records cover sparse move pools, duplicate rows and both learnset layouts;
-- no ROM or later-generation content is needed.
local root=os.getenv('MOD_SOURCE') or 'mod'
local base=os.getenv('MOD_BASE') or '../randomizer'
local host=os.getenv('HOST_SOURCE') or '../host-source'
package.path=host..'/?.lua;'..package.path
unpack=table.unpack or unpack
local gen,version=1,'red'
package.loaded['src.core.GameVersion']={get=function() return version end,generation=function() return gen end,isYellow=function() return version=='yellow' end}
local Core=dofile(base..'/core.lua')
local Adapters=dofile(base..'/adapters.lua')
local Pokemon=require('src.pokemon.Pokemon')
local Mon=require('src.battle.gen2.Mon')
local saved={}
local mod={save={get=function(_,k,d) if saved[k]==nil then return d end;return saved[k] end,set=function(_,k,v) saved[k]=v end},log={error=function(_,fmt,...) error(fmt:format(...)) end}}
local R=dofile(root..'/randomizer.lua')(mod,Core,Adapters)
local n,exceptions=0,0
local function check(ok,why) assert(ok,why);n=n+1 end
local function typeKey(t) return gen==1 and t=='PSYCHIC' and 'PSYCHIC_TYPE' or t end
-- Positive oracle: only these known, ordinary native attacks qualify. The
-- decoys below have positive power or a matching type but cannot promise STAB.
local attacks={
 {'TACKLE',33,'NORMAL',35},{'EMBER',52,'FIRE',40},{'FLAMETHROWER',53,'FIRE',95},
 {'WATER_GUN',55,'WATER',40},{'SURF',57,'WATER',95},{'VINE_WHIP',22,'GRASS',35},
 {'RAZOR_LEAF',75,'GRASS',55},{'THUNDERSHOCK',84,'ELECTRIC',40},{'THUNDERBOLT',85,'ELECTRIC',95},
 {'CONFUSION',93,'PSYCHIC',50},{'PSYCHIC_M',94,'PSYCHIC',90},{'LICK',122,'GHOST',20},
 {'LOW_KICK',67,'FIGHTING',50},{'KARATE_CHOP',2,'FIGHTING',50},{'EARTHQUAKE',89,'GROUND',100},{'ICE_BEAM',58,'ICE',95},
 {'TWINEEDLE',41,'BUG',25},{'POISON_STING',40,'POISON',15},{'ROCK_THROW',88,'ROCK',50},
 {'WING_ATTACK',17,'FLYING',35},{'DRAGONBREATH',225,'DRAGON',60},
 {'CRUNCH',242,'DARK',80},{'STEEL_WING',211,'STEEL',70},
}
local decoys={
 {'GROWL',45,'NORMAL',0},{'SPLASH',150,'NORMAL',0},{'CONFUSE_RAY',109,'GHOST',0},
 {'NIGHT_SHADE',101,'GHOST',1},{'DRAGON_RAGE',82,'DRAGON',40},
 {'SONICBOOM',49,'NORMAL',20},{'SEISMIC_TOSS',69,'FIGHTING',1},
 {'PSYWAVE',149,'PSYCHIC',1},{'COUNTER',68,'FIGHTING',1},
 {'BIDE',117,'NORMAL',1},{'SUPER_FANG',162,'NORMAL',1},
 {'FISSURE',90,'GROUND',1},{'HORN_DRILL',32,'NORMAL',1},{'GUILLOTINE',12,'NORMAL',1},
 {'DREAM_EATER',138,'PSYCHIC',100},{'SELFDESTRUCT',120,'NORMAL',130},
 {'EXPLOSION',153,'NORMAL',170},{'SNORE',173,'NORMAL',40},
 {'MIRROR_COAT',243,'PSYCHIC',1},{'HIDDEN_POWER',237,'NORMAL',1},
 {'FUTURE_SIGHT',248,'PSYCHIC',80},{'BEAT_UP',251,'DARK',10},
}
local levels={1,2,3,4,5,6,8,10,12,16,20,25,30,40,50,60,80,99,100}
local good
local function fixture(v)
 version=v;gen=(v=='red' or v=='blue' or v=='yellow') and 1 or 2
 local game={data={pokemon={},moves={},maps={},items={},field={}},save={party={},boxes={},daycare={},inventory={},flags={}}}
 if gen==2 then game.data.gen2Maps={};game.data.gen2Encounters={} end
 good={}
 for _,list in ipairs({attacks,decoys}) do
  for _,m in ipairs(list) do
   if m[2]<=(gen==1 and 165 or 251) then
    local t=typeKey(m[3])
    if gen==1 and m[1]=='KARATE_CHOP' then t='NORMAL' end
    game.data.moves[m[1]]={index=m[2],type=t,power=m[4],pp=20}
    if list==attacks then good[m[1]]=t end
   end
  end
 end
 -- A matching attack from outside the cartridge must never satisfy coverage.
 game.data.moves.MODERN_DRAGON={index=300,type='DRAGON',power=80,pp=10}
 game.data.moves.UNINDEXED_DRAGON={type='DRAGON',power=80,pp=10}
 -- Invalid STAB candidates carried by otherwise native-shaped mod records.
 game.data.moves.FIXED_ALIAS={index=160,type='DRAGON',power=40,pp=20,fixedDamage=40}
 game.data.moves.EFFECT_ALIAS={index=159,type='DRAGON',power=40,pp=20,effect=gen==1 and 'SPECIAL_DAMAGE_EFFECT' or 'EFFECT_STATIC_DAMAGE'}
 game.data.moves.EMPTY_PP={index=158,type='DRAGON',power=40,pp=0}
 local types={'NORMAL','FIRE','WATER','GRASS','ELECTRIC',typeKey('PSYCHIC'),'GHOST','DRAGON','FIGHTING','GROUND','ICE','BUG','POISON','ROCK','FLYING'}
 if gen==2 then types[#types+1]='DARK';types[#types+1]='STEEL' end
 local starters=Adapters[v].starters
 for i=1,(gen==1 and 151 or 251) do
  local id=starters[i] or ('MON_'..i)
  local def={index=i,dex=i,name=id,types={types[(i-1)%#types+1]},baseStats={hp=50,attack=50,defense=50,speed=50,special=50,specialAttack=50,specialDefense=50},evolutions={},tmhm={}}
  if i>30 then def.types[2]=types[i%#types+1] end
  local rows={}
  for _,level in ipairs(levels) do
   rows[#rows+1]={level=level,move='GROWL'}
   if level==1 or level==5 or level==20 then
    for j=1,5 do rows[#rows+1]={level=level,move='TACKLE'} end
   end
  end
  if gen==1 then def.level1Moves=i%4==0 and {} or {'GROWL','TACKLE'};def.learnset=rows
  else def.levelMoves=rows end
  -- Include no initial slot / a learnset that starts later than level 1.
  if i%10==0 then
   local later={};for _,r in ipairs(rows) do if r.level>=6 then later[#later+1]=r end end
   if gen==1 then def.level1Moves={};def.learnset=later else def.levelMoves=later end
  end
  game.data.pokemon[id]=def
 end
 mod.game=game
 return game
end
local function config(game,safety,types,mode)
 local cfg=R.defaults(game)
 cfg.safety=safety;cfg.movesets=mode or 'TYPE_BIAS';cfg.types=types or 'UNCHANGED'
 cfg.starters='RANDOM';cfg.trainers='UNCHANGED';cfg.statics='UNCHANGED';cfg.mart_safety=false;cfg.progression_items=false
 return cfg
end
local function knowsStab(def,ids)
 for _,m in ipairs(ids) do
  local t=good[type(m)=='table' and m.id or m]
  for _,s in ipairs(def.types) do if t and t==s then return true end end
 end
 return false
end
local function signature(game)
 local ids={};for id in pairs(game.data.pokemon) do ids[#ids+1]=id end;table.sort(ids)
 local s={}
 for _,id in ipairs(ids) do
  local d=game.data.pokemon[id];s[#s+1]=id..':'..table.concat(d.types,',')..':'..table.concat(d.level1Moves or {},',')
  for _,r in ipairs(d.learnset or d.levelMoves or {}) do s[#s+1]=r.level..'='..r.move end
 end
 return table.concat(s,'|')
end
local function audit(game,label)
 for id,def in pairs(game.data.pokemon) do
  local available={};for mid in pairs(good) do available[#available+1]=mid end
  local eligible=knowsStab(def,available)
  if not eligible then exceptions=exceptions+1 end
  for _,level in ipairs(levels) do
   local moves=gen==1 and Pokemon.movesAtLevel(def,level) or Mon.movesAtLevel(def,level,game.data.moves)
   check(#moves<=4 and (not eligible or #moves>0),'native moveset size: '..label..' '..id)
   if eligible then check(knowsStab(def,moves),'missing damaging STAB: '..label..' '..id..' level '..level) end
   for _,m in ipairs(moves) do
    local md=game.data.moves[type(m)=='table' and m.id or m]
    check(md and md.index and md.index<=(gen==1 and 165 or 251),'native move boundary')
   end
  end
 end
end

for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
 for _,safety in ipairs({'SAFE','CHAOS'}) do
  for _,types in ipairs({'UNCHANGED','RANDOM'}) do
   local game=fixture(v);local cfg=config(game,safety,types)
   for seed=1,8 do
    local a,why=R.generate(game,cfg,seed);check(a~=nil,why)
    audit(game,v..' '..safety..' '..types..' seed '..seed)
    if seed==1 then
     local before=signature(game)
     local st,err=R.beginGenerate(game,cfg,seed);check(st~=nil,err)
     for step=1,14 do R.stepGenerate(st) end
     check(st.done and st.active and not st.error,st.error or 'staged generation')
     check(signature(game)==before,'staged and synchronous learnsets must agree')
     saved={seed=seed,config=Core.copy(a.cfg),version=v}
     local owned={species=next(game.data.pokemon),level=20,moves={{id='GROWL',pp=7},{id='TACKLE',pp=12,ppUps=2}}}
     game.save.party={owned};game.save.boxes={{Core.copy(owned)}};game.save.daycare={mon=Core.copy(owned)}
     local resumed,reason=R.activateSaved(game);check(resumed~=nil,reason)
     check(signature(game)==before,'Continue restores the corrected learnset deterministically')
     for _,mon in ipairs({owned,game.save.boxes[1][1],game.save.daycare.mon}) do
      check(#mon.moves==2 and mon.moves[1].id=='GROWL' and mon.moves[1].pp==7 and mon.moves[2].id=='TACKLE' and mon.moves[2].ppUps==2,'Continue preserves owned/taught moves and PP')
     end
     local cold=fixture(v);cold.save=Core.copy(game.save)
     local coldR=dofile(root..'/randomizer.lua')(mod,Core,Adapters)
     local loaded,whyCold=coldR.activateSaved(cold);check(loaded~=nil,whyCold)
     check(signature(cold)==before,'cold Continue uses the same fixed learnsets without a new seed')
     check(cold.save.party[1].moves[1].id=='GROWL' and cold.save.party[1].moves[2].ppUps==2,'cold Continue preserves taught moves')
     mod.game=game
    end
   end
  end
 end
 -- SAFE continues supplying four distinct attacks, with STAB reserved first.
 local game=fixture(v)
 local sparseCfg=config(game,'CHAOS','UNCHANGED')
 assert(R.generate(game,sparseCfg,991))
 local ghost=game.data.pokemon.MON_7
 local function arrival(level)
  local ids=gen==1 and Pokemon.movesAtLevel(ghost,level) or Mon.movesAtLevel(ghost,level,game.data.moves)
  local out={};for _,m in ipairs(ids) do out[#out+1]=type(m)=='table' and m.id or m end
  return table.concat(out,',')
 end
 check(arrival(40)~=arrival(100),'a sole eligible STAB attack must not freeze all later coverage')
 for id,def in pairs(game.data.pokemon) do
  local moves=R._safeStarterCoverage(game,id,37,{movesets='TYPE_BIAS'})
  check(#moves==4,'SAFE keeps four attacks')
  local seen={};for _,m in ipairs(moves) do check(not seen[m],'SAFE has no duplicate attacks');seen[m]=true end
  local available={};for mid in pairs(good) do available[#available+1]=mid end
  if knowsStab(def,available) then check(knowsStab(def,moves),'SAFE starter override must retain STAB') end
  for _,mode in ipairs({'UNCHANGED','RANDOM'}) do
   check(table.concat(R._safeStarterCoverage(game,id,37,{movesets=mode}),',')==table.concat(R._safeStarterCoverage(game,id,37),','),'other starter modes keep their original seed results')
  end
 end
 -- Optional release comparison checks the entire non-Type-Bias output against
 -- the published 1.6.0 module, without shipping that older module in the mod.
 if os.getenv('TYPE_BIAS_BASELINE') then
  local old=dofile(os.getenv('TYPE_BIAS_BASELINE'))(mod,Core,Adapters)
  for _,mode in ipairs({'UNCHANGED','RANDOM'}) do
   for _,safety in ipairs({'SAFE','CHAOS'}) do
    local current=fixture(v);local cfg=config(current,safety,'RANDOM',mode)
    assert(R.generate(current,cfg,371));local expected=signature(current)
    local previous=fixture(v);assert(old.generate(previous,cfg,371))
    check(signature(previous)==expected,'non-Type-Bias learnsets match published 1.6.0')
   end
  end
 end
end
check(exceptions>0,'exercise native types with no STAB-capable attack (Gen 1 Dragon)')
print('PASS: '..n..' Type Bias checks with native move builders across six games; '..exceptions..' no-STAB-pool cases handled')
