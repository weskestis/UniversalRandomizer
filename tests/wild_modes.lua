-- Exercise the public encounter projection and the eager saved-table path:
-- low route levels must not imply only first-stage Pokemon in Truly random.
local root=os.getenv('MOD_SOURCE') or 'mod'
local base=os.getenv('MOD_BASE') or '../randomizer'
local Core=dofile(base..'/core.lua')
local gen,version=1,'red'
package.loaded['src.core.GameVersion']={get=function() return version end,generation=function() return gen end}
local saved={}
local mod={save={get=function(_,k,d) return saved[k] or d end,set=function(_,k,v) saved[k]=v end}}
local R=dofile(root..'/randomizer.lua')(mod,Core,{})
local n=0
local function check(v,s) assert(v,s);n=n+1 end
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
 version=v;gen=(v=='red' or v=='blue' or v=='yellow') and 1 or 2
 local cap=gen==1 and 151 or 251
 local game={data={pokemon={},items={},moves={},maps={},field={}},save={party={},flags={}}}
 mod.game=game
 for i=1,cap do
  local b=i<=20 and 35 or 110
  game.data.pokemon['MON_'..i]={dex=i,index=i,types={'NORMAL'},baseStats={hp=b,attack=b,defense=b,speed=b,special=gen==1 and b or nil,specialAttack=gen==2 and b or nil,specialDefense=gen==2 and b or nil},evolutions={}}
 end
 game.data.pokemon.MON_1.evolutions={{level=16,species='MON_40'}}
 game.data.pokemon.MON_40.evolutions={{level=32,species='MON_80'}}
 if gen==1 then game.data.encounters={ROUTE_1={grass={slots={{species='MON_1',level=2},{species='MON_2',level=3}}}}}
 else game.data.gen2Maps={};game.data.gen2Encounters={grass={ROUTE_1={slots={{species='MON_1',level=2},{species='MON_2',level=3}}}}} end
 for _,mode in ipairs({'HIGH_VARIETY','AREA_POOL','CHAOS_POOL','FULL_SLOT_RANDOM'}) do
  local high,low=0,0
  for seed=1,80 do
   local cfg=R.defaults(game);cfg.wild_randomness='UNRESTRICTED';cfg.area_encounters=mode
   cfg.safety='SAFE';cfg.extra_species=0;cfg.bst_match=true;cfg.bst_difference=0
   local a={game=game,cfg=cfg,seed=seed,generation=gen,version=v,wildMap={},areaPools={},areaHighVariety={},encounterRollState={},preview=true}
   check(R._primeEncounterTables(a),'prime unrestricted tables')
   local seenHigh=false
   for _,id in pairs(a.wildMap) do if tonumber(id:match('%d+'))>20 then seenHigh=true end end
   for _,pool in pairs(a.areaPools) do for _,id in ipairs(pool) do if tonumber(id:match('%d+'))>20 then seenHigh=true end end end
   for _,rec in pairs(a.areaHighVariety) do for _,id in ipairs(rec.pool) do if tonumber(id:match('%d+'))>20 then seenHigh=true end end end
   if seenHigh then high=high+1 end
   local out=R.visibleEncounter(a,'MON_1',2,'ROUTE_1','grass','low-level-slot')
   check(game.data.pokemon[out.species]~=nil,'native encounter selected')
   check(out.level==2,'unrestricted species choice does not inflate levels')
   if tonumber(out.species:match('%d+'))<=20 then low=low+1 end
   check(R._evolveWildSpeciesForLevel(a,{species='MON_1',level=99}).species=='MON_1','unrestricted does not force late evolution')
   local bcfg=Core.copy(cfg);bcfg.wild_randomness='BALANCED'
   local b={game=game,cfg=bcfg,seed=seed,generation=gen,version=v,wildMap={},areaPools={},areaHighVariety={},encounterRollState={},preview=true}
   local balanced=R.visibleEncounter(b,'MON_1',2,'ROUTE_1','grass','low-level-slot')
   check(R.withinBst(game,bcfg,'MON_1',balanced.species),'balanced respects explicit BST bound')
   check(R.wildSelectionMode(a)=='RANDOM' and R.wildSelectionMode(b)=='SIMILAR','safety and strength are separate')
   bcfg.safety='CHAOS';check(R.wildSelectionMode(b)=='SIMILAR','CHAOS does not secretly change balanced wilds')
  end
  check(high>50,'fully evolved/high-BST pool is available on early routes: '..v..' '..mode)
  check(low>0,'unrestricted also retains weak species')
 end
 local cfg=R.normalizedConfig({safety='SAFE',area_encounters='HIGH_VARIETY'},game)
 check(cfg.wild_randomness=='LEGACY' and cfg.wild_evolution=='LEVEL','old active run keeps original policy')
 local a={game=game,cfg=cfg,seed=5,generation=gen,version=v}
 check(R._evolveWildSpeciesForLevel(a,{species='MON_1',level=40}).species=='MON_80','legacy evolution scaling retained')
 cfg.wild_randomness='UNRESTRICTED';cfg.wild_evolution='LEVEL'
 check(R.normalizedConfig(cfg,game).wild_evolution=='AS_ROLLED','truly random cannot silently promote species')
end
print('PASS: '..n..' wild mode checks across all six editions')
