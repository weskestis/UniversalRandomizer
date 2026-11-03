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
local Worlds=dofile(root..'/worlds.lua')(W,dofile(root..'/gen2_world.lua')(Core))
local R=dofile(root..'/randomizer.lua')(mod,Core,dofile(base..'/adapters.lua'),I,L,Worlds)
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
local oldR=dofile('dist/baseline/randomizer-1.7.0.lua')(mod,Core,dofile(base..'/adapters.lua'),I,L,W)
local function stable(t)
 if type(t)~='table' then return tostring(t) end
 local out={};for _,k in ipairs(Core.sortedKeys(t)) do out[#out+1]=tostring(k)..'='..stable(t[k]) end
 return '{'..table.concat(out,',')..'}'
end
local function snapshot(r,a) return stable({a.cfg,a.starterMap,a.badgePlan,a.logicItemPlan,a.gen1World,a.fingerprint,r.runCode(a)}) end
for _,v in ipairs({'red','blue','yellow'}) do for mode=1,4 do
 local g=gameFor(v);local c=oldR.defaults(g)
 if mode>=2 then c.gym_leaders='SAFE';c.gym_entrances='SAFE';c.dungeon_entrances='SAFE';c.badges='SAFE' end
 if mode==3 then c.random_start='LOGIC';c.entrance_pool='MIXED' end
 if mode==4 then c.safety='CHAOS';c.gym_leaders='CHAOS';c.gym_entrances='CHAOS';c.dungeon_entrances='CHAOS';c.badges='CHAOS' end
 local before,why=oldR.generate(g,c,818+mode);check(before,tostring(why));local expected=snapshot(oldR,before)
 oldR.clear(g);g=gameFor(v)
 local after,why=R.generate(g,c,818+mode);check(after,tostring(why))
 check(snapshot(R,after)==expected,'Gen 1 released seed/config/fingerprint/world/run-code preserved: '..v..' '..mode)
 R.clear(g)
end end
print('PASS: '..n..' frozen Gen 1 release comparisons')
-- Existing 1.7.0 Gen 2 saves gain disabled world controls, not a rerolled run.
local legacyChecks=0
local function legacySnapshot(a)
 local progression=Core.copy(a.progression)
 if progression and progression.badges then progression.badges.flagMap=nil end
 return stable({a.starterMap,a.badgePlan and a.badgePlan.gymToBadge,a.logicItemPlan,progression,
  a.wildMap,a.areaPools,a.areaHighVariety,a.encounterRollState})
end
for _,v in ipairs({'gold','silver','crystal'}) do for mode=1,3 do
 local g=fixture(2,v);local c=oldR.defaults(g)
 if mode>=2 then c.field_items='LOGIC_RANDOM';c.progression_items=true;c.badges='SAFE';c.world_logic='AUDITED' end
 if mode==3 then c.random_start='LOGIC' end
 local before,why=oldR.generate(g,c,918+mode);assert(before,tostring(why));assert(oldR.commit(before))
 local expected=legacySnapshot(before);local priorCfg=Core.copy(before.cfg)
 oldR.abortSavedActivation(g)
 local after,why=R.activateSaved(g);assert(after,tostring(why))
 -- The per-edition engine flag map is deliberately corrected in 1.8.0;
 -- compare selected rewards and encounter/item/start worlds, not that adapter.
 assert(after.gen2World==nil and after.cfg.gym_leaders=='OFF' and after.cfg.gym_entrances=='OFF' and after.cfg.dungeon_entrances=='OFF','new Gen 2 shuffles stay disabled on Continue')
 for k,value in pairs(priorCfg) do assert(stable(after.cfg[k])==stable(value),'legacy setting changed: '..k) end
 assert(legacySnapshot(after)==expected,'legacy Gen 2 placements or encounters rerolled: '..v..' '..mode)
 R.clear(g);legacyChecks=legacyChecks+1
end end
print('PASS: '..legacyChecks..' Gen 2 release-to-release Continue comparisons')
