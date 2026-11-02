-- Pairwise public settings, exhaustive core world dependencies, and actual
-- runtime hooks. Synthetic cartridge-shaped data; not a ROM playthrough.
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
local hooks,events=require('src.mods.Hooks').new(),require('src.mods.Events').new()
local saved={}
local mod={hooks={wrap=function(_,n,f,p) return hooks:wrap(n,f,p,'universal_randomizer') end},
 events={on=function(_,n,f,p) return events:on(n,f,p,'universal_randomizer') end},
 save={get=function(_,k,d) if saved[k]==nil then return d end;return saved[k] end,set=function(_,k,v) saved[k]=v end},
 world={spawnNpc=function() error('unexpected synthetic guard') end,removeNpc=function() end},
 log={error=function(_,fmt,...) error(fmt:format(...)) end}}
local R=dofile(root..'/randomizer.lua')(mod,Core,dofile(base..'/adapters.lua'),I,L)
I.installHardcoded(mod,R);R.installHooks();dofile(root..'/gift_items.lua')(mod,Core,R,I)
local C=dofile(root..'/untamed_compat.lua')(mod,Core,R)
local visibleView
events:on('audit.visible',function() visibleView=mod.game.data.gen2Encounters or mod.game.data.encounters end,0,'overworldmons')
require('src.mods.Runtime').install(events,hooks)
local fixture=dofile('tests/support/audit_fixture.lua')({Core=Core,I=I,L=L,R=R,mod=mod,hooks=hooks,events=events,setVersion=function(g,v) gen,version=g,v end})
local n,generated,rejected=0,0,0
local function check(ok,why) assert(ok,why);n=n+1 end
local function stable(t)
 if type(t)~='table' then return tostring(t) end
 local keys={};for k in pairs(t) do keys[#keys+1]=k end;table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
 local rows={};for _,k in ipairs(keys) do rows[#rows+1]=tostring(k)..'='..stable(t[k]) end
 return '{'..table.concat(rows,',')..'}'
end
local function generate(game,cfg,seed,label)
 local h,why=R.beginGenerate(game,cfg,seed)
 check(h~=nil,(label or '')..': '..tostring(why))
 for step=1,14 do R.stepGenerate(h) end
 check(h.done and h.active~=nil,(label or '')..': '..tostring(h.error))
 generated=generated+1;return h.active
end
local domains=dofile('tests/support/settings_domains.lua')
-- Greedy deterministic covering array. Each uncovered value pair is seeded
-- into a row; the other columns maximize remaining coverage. Verify the
-- completed array independently before running it through the generator.
local uncovered,total={},0
for i=1,#domains do for j=i+1,#domains do for a=1,#domains[i][2] do for b=1,#domains[j][2] do
 local key=table.concat({i,j,a,b},':');uncovered[key]={i,j,a,b};total=total+1
end end end end
local rows={}
while next(uncovered) do
 local first
 for _,p in pairs(uncovered) do if not first or table.concat(p,':')<table.concat(first,':') then first=p end end
 local row={[first[1]]=first[3],[first[2]]=first[4]}
 for i=1,#domains do if not row[i] then
  local best,score=1,-1
  for val=1,#domains[i][2] do
   local s=0
   for j,other in pairs(row) do
    local key=i<j and table.concat({i,j,val,other},':') or table.concat({j,i,other,val},':')
    if uncovered[key] then s=s+1 end
   end
   if s>score then best,score=val,s end
  end
  row[i]=best
 end end
 for i=1,#domains do for j=i+1,#domains do uncovered[table.concat({i,j,row[i],row[j]},':')]=nil end end
 rows[#rows+1]=row
end
local covered={}
for _,row in ipairs(rows) do for i=1,#domains do for j=i+1,#domains do covered[table.concat({i,j,row[i],row[j]},':')]=true end end end
local pairsSeen=0;for _ in pairs(covered) do pairsSeen=pairsSeen+1 end
check(pairsSeen==total,'covering array contains every independent setting-value pair')
print(('Settings array: %d rows covering %d value pairs'):format(#rows,total))
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
 local g=(v=='red' or v=='blue' or v=='yellow') and 1 or 2
 for index,row in ipairs(rows) do
  saved={};local game=fixture(g,v);local cfg=R.defaults(game)
  for i,choice in ipairs(row) do cfg[domains[i][1]]=domains[i][2][choice] end
  local a=generate(game,cfg,100+index,v..' settings row '..index)
  check(a.cfg.pokedex=='NATIVE' and a.cfg.ruleset==(g==1 and 'GEN1' or 'GEN2'),'settings retain native roster/rules')
  check(a.cfg.level_mode=='PERCENTAGE' and not a.cfg.protection_guards,'retired controls cannot reappear')
  local visited={}
  local function learner(id)
   if visited[id] then return end;visited[id]=true
   local def=game.data.pokemon[id];check(def~=nil,'starter evolution exists')
   for item,record in pairs(game.data.items) do
    if record.machine and record.machine.kind=='HM' then check(Core.tableHas(def.tmhm,record.machine.move),'SAFE starter family remains a legal HM carrier: '..id..' '..item) end
   end
   if g==2 then check(Core.tableHas(def.tmhm,'ROCK_SMASH') and Core.tableHas(def.tmhm,'HEADBUTT'),'SAFE starter family retains field TM learning') end
   for _,e in ipairs(def.evolutions or {}) do learner(e.species or e.into) end
  end
  for _,id in pairs(R._starterTargets(game,a.starterMap)) do learner(id) end
  if g==2 and cfg.tms=='RANDOM' then check(game.data.items.TM_ROCK_SMASH.machine.move=='ROCK_SMASH' and game.data.items.TM_2.machine.move=='HEADBUTT','randomized TMs preserve native field actions across importer names') end
 end
 -- Every combination of the six progression switches. Deduplicate identical
 -- normalized configurations, and explicitly test the rejected combinations.
 local seen={}
 for _,start in ipairs({'OFF','LOGIC','CHAOS'}) do for _,safety in ipairs({'SAFE','CHAOS'}) do
 for _,badge in ipairs({'VANILLA','SAFE','CHAOS'}) do for _,field in ipairs({'UNCHANGED','SHUFFLE','RANDOM','LOGIC_RANDOM','CHAOS'}) do
 for _,gift in ipairs({'UNCHANGED','RANDOM'}) do for _,keys in ipairs({false,true}) do
  local game=fixture(g,v);local cfg=R.defaults(game)
  cfg.random_start=start;cfg.safety=safety;cfg.badges=badge;cfg.field_items=field;cfg.gift_items=gift;cfg.progression_items=keys
  local pass,why,norm=R.preflight(game,cfg);local sig=stable(norm)
  if not pass then
   check((start=='LOGIC' and badge~='SAFE') or (safety=='SAFE' and badge=='CHAOS'),
    v..' unexpected preflight rejection: '..tostring(why))
   check(type(why)=='string' and #why>20,'incompatible configuration explains the correction');rejected=rejected+1
  elseif not seen[sig] then
   seen[sig]=true;saved={}
   local a=generate(game,norm,17,v..' world '..start..' '..safety..' '..badge..' '..field..' '..gift..' '..tostring(keys))
   if norm.field_items=='LOGIC_RANDOM' then
    local ok,cert=R._auditItemSpheres(a.logicItemPlan,g);check(ok and cert.complete,'independent full-placement sphere replay')
    check(a.logicItemPlan.world_logic=='AUDITED','new worlds use audited rules')
   end
  end
 end end end end end end
 print(v..': pairwise and world combination sweeps passed')
end
-- Source-backed negative controls: never infer access from a shared map name
-- or an inventory item without its native badge permission.
do
 local state={_world='AUDITED'}
 local regions,have=L.itemWorldState(1,'CERULEAN_CITY',state)
 check(not regions.EARLY and not have['GYM_OPP_BROCK#1'],'Mt Moon ledges do not grant west-Kanto access')
 regions=L.itemWorldState(1,'FUCHSIA_CITY',state)
 check(not regions.VERMILION and not regions.LAVENDER,'Fuchsia cannot walk through sleeping Snorlax')
 local surf={_world='AUDITED',HM_SURF=true}
 regions=L.itemWorldState(1,'FUCHSIA_CITY',surf)
 check(regions.LAVENDER,'Fuchsia can Surf north around Snorlax after Koga')
 local silph=R._auditedLogicDef({key='SILPH_CARD',region='SAFFRON'},1)
 check(not R._logicItemReqMet(silph,state,'SAFFRON_CITY',1),'Silph Co entrance is blocked before Fuji rescue')
 check(R._logicItemReqMet(silph,{_world='AUDITED',SILPH_SCOPE=true},'SAFFRON_CITY',1),'Fuji rescue opens Silph after Scope')
 local blocked={_world='AUDITED',MYSTERY_EGG=true,_badges={ZEPHYR='RISING'}}
 regions=L.itemWorldState(2,'CHERRYGROVE_CITY',{_world='AUDITED'})
 check(not regions.VIOLET,'Route 30 intro barrier cannot be crossed before the Mystery Egg handoff')
 regions,have=L.itemWorldState(2,'AZALEA_TOWN',{_world='AUDITED',MYSTERY_EGG=true,HM_CUT=true})
 check(not regions.EARLY and not have.EGG_RETURNED,'owning the Egg north of Route 30 cannot substitute for reaching Elm')
 regions=L.itemWorldState(2,'CHERRYGROVE_CITY',blocked)
 check(not regions.AZALEA,'Route 32 checks the actual Zephyr badge')
 regions,have=L.itemWorldState(2,'ECRUTEAK_CITY',state)
 check(have.GYM_FOG and not have.TM_ROCK_SMASH,'native Morty does not require optional Rock Smash')
 local machine=R._auditedLogicDef({key='CERULEAN_MACHINE',region='KANTO_EAST'},2)
 check(not R._logicItemReqMet(machine,{S_S_TICKET=true},nil,2,{regions={KANTO_EAST=true},have={S_S_TICKET=true}}),'Machine Part quest needs the Power Plant approach')
 local waterfall=R._auditedLogicDef({key='ICE_WATERFALL',region='BLACKTHORN'},2)
 check(not R._logicItemReqMet(waterfall,{_world='AUDITED',BASEMENT_KEY=true,CARD_KEY=true,HM_STRENGTH=true},'BLACKTHORN_CITY',2),'Blackthorn starts cannot take Waterfall from the wrong side of Ice Path')
 -- Tampering leaves the proposal order untouched. Replay must detect locks
 -- from actual awards, including a two-item cycle.
 local p=R._nativeAuditPlan(1,nil)
 p.locations.BILL_TICKET,p.locations.SS_ANNE_CUT=p.locations.SS_ANNE_CUT,p.locations.BILL_TICKET
 check(not R._auditItemSpheres(p,1),'ticket behind its own S.S. Anne gate is rejected')
 p=R._nativeAuditPlan(1,nil)
 p.locations.BILL_TICKET,p.locations.ROCKET_SCOPE=p.locations.ROCKET_SCOPE,p.locations.BILL_TICKET
 check(not R._auditItemSpheres(p,1),'ticket/Cut/east-Kanto cycle is rejected')
 p=R._nativeAuditPlan(2,nil)
 p.locations.ILEX_CUT,p.locations.CERULEAN_MACHINE=p.locations.CERULEAN_MACHINE,p.locations.ILEX_CUT
 check(not R._auditItemSpheres(p,2),'Cut cannot be hidden behind the Power Plant approach')
end
local johto={'ZEPHYR','HIVE','PLAIN','FOG','MINERAL','STORM','GLACIER','RISING'}
local kanto={'BOULDER','CASCADE','THUNDER','RAINBOW','SOUL','MARSH','VOLCANO','EARTH'}
local function badges(game,g,count)
 game.save.inventory={};game.save.player.badges={};game.save.player.kantoBadges={}
 for i=1,count do
  if g==1 then game.save.inventory[kanto[i]..'BADGE']=1
  elseif i<=8 then game.save.player.badges[johto[i]]=true
  else game.save.player.kantoBadges[kanto[i-8]]=true end
 end
end
local startCount,withheldCount=0,0
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
 local g=(v=='red' or v=='blue' or v=='yellow') and 1 or 2
 local game,starters=fixture(g,v);local cfg=R.defaults(game)
 cfg.random_start='LOGIC';cfg.badges='SAFE';cfg.field_items='LOGIC_RANDOM';cfg.starters='UNCHANGED';cfg.statics='UNCHANGED';cfg.trainers='UNCHANGED'
 cfg.area_encounters='VANILLA';cfg.extra_species=0
 local seeds={}
 for seed=1,100 do local id=R._logicItemStartId(game,cfg,seed);if not seeds[id] then seeds[id]=seed end end
 for _,start in ipairs(L.logicStarts(g)) do
  check(seeds[start]~=nil,'deterministic seed search reaches '..v..' '..start)
  saved={};game,starters=fixture(g,v)
  local a=generate(game,cfg,seeds[start],v..' '..start);startCount=startCount+1
  check(a.progression.start.id==start,'generated start matches selected seed')
  local p=a.logicItemPlan
  for _,d in ipairs(p.defs) do
   local _,proof=R._auditItemSpheres(p,g,p.locations[d.key]);withheldCount=withheldCount+1
   check(proof.reached[d.key],'withholding a reward leaves its source reachable: '..start..' '..d.key)
  end
  -- Independent seed corpus checks badge constraints for every authored start.
  for seed=1,20 do
   local mapping,why=R._checkedBadgeAssignment(g,seed,{id=start});check(mapping~=nil,why)
   check(R._auditItemSpheres(R._nativeAuditPlan(g,start,mapping),g),'each checked badge layout retains native progression')
  end
  check(R.commit(a),'commit audit run')
  if g==2 and start=='CHERRYGROVE_CITY' then
   dofile('tests/support/elm_handoff.lua')(game,a,R,hooks,check)
  end
  game.save.party={{species=starters[1],level=5,moves={{id='TACKLE',pp=17}}}}
  if g==1 then game.save.flags.EVENT_GOT_POKEDEX=true end
  local exterior=g==1 and 'PALLET_TOWN' or 'NEW_BARK_TOWN'
  local dest=hooks:call('warp.destination',function(dm,x,y) return dm,x,y end,exterior,1,1,{data=game.data})
  check(dest==start and a.randomStartUsed,'native intro hook activates level protection: '..v..' '..start)
  game.overworld.map.id=start;C.attach(game);badges(game,g,0)
  events:emit('audit.visible');local firstView=visibleView
  local function visiblePeak(view)
   local rows=g==1 and view[start].grass.slots or view.grass[start].slots
   local peak=0;for _,slot in ipairs(rows) do peak=math.max(peak,slot.level) end;return peak
  end
  check(visiblePeak(firstView)<=7,'Untamed uses the zero-badge starting level band')
  game.save.party[1].level=80;events:emit('audit.visible')
  check(visibleView==firstView,'Untamed cache is independent of party level')
  badges(game,g,1);events:emit('audit.visible')
  check(visibleView~=firstView and visiblePeak(visibleView)>visiblePeak(firstView) and visiblePeak(visibleView)<=11,'earning a badge refreshes Untamed levels without changing maps')
  local maps={start,start..'_POKECENTER_1F','UNLISTED_SIDE_PATH','DUNGEON_INTERIOR'}
  for _,map in ipairs(L.policy(g,start)) do maps[#maps+1]=map end
  for count=0,(g==1 and 8 or 16) do
   badges(game,g,count);check(R.startBadgeCount(a)==count,'actual badge storage advances milestone '..count)
  end
  for _,count in ipairs(g==1 and {0,1,7,8} or {0,1,7,8,9,16}) do
   badges(game,g,count)
   for _,map in ipairs(maps) do
    game.overworld.map.id=map;a.routeRuntimeMapId=map
    for _,pct in ipairs({-50,0,50}) do
     a.cfg.wild_levels=pct;a.cfg.trainer_levels=pct;a.cfg.boss_levels=pct
     local previous
     for _,partyLevel in ipairs({5,80}) do
      game.save.party[1].level=partyLevel
      a.routeState.routeLegsCompleted=999;a.routeState.guidedMap='SOME_OTHER_MAP';a.routeState.offRoute=true
      local limit=math.max(1,math.floor(L.startLevel(count,'wild',g)*(100+pct)/100+.5))
      local encounter=hooks:call('encounter.species',function(enc) return enc end,{species='MON_10',level=50,mapId=map},{data=game.data,mapId=map,terrain='grass'})
      check(encounter.level<=limit and encounter.level>=1,'wild level cap survives side paths/interiors/modifiers')
      if previous then check(encounter.level==previous,'party level and map loops do not inflate encounters') end;previous=encounter.level
      local fish=hooks:call('encounter.fishing',function() return {species='MON_10',level=50,mapId=map} end,'SUPER_ROD',map,{}, {data=game.data})
      check(fish.level<=limit,'fishing uses the same milestone protection')
      local static
      if g==1 then
       static=hooks:call('script.command',function(_,_,args) return args[2] end,{game=game,mapId=map},'static_battle',{'MON_10',50})
      else
       static=hooks:call('script.command',function(_,_,_,cmd) return cmd.level end,{game=game,mapId=map},'loadwildmon',{}, {species=game.data.pokemon.MON_10.index,level=50})
      end
      check(static<=limit,'native-species fixed battles retain Logic-start level protection')
      for _,boss in ipairs({false,true}) do
       local cls=boss and (g==1 and 'OPP_BROCK' or 'RED') or (g==1 and 'OPP_YOUNGSTER' or 'YOUNGSTER')
       local team=hooks:call('trainer.party',function(_,_,party) return party end,cls,1,{{species='MON_10',level=40},{species='MON_12',level=50}})
       local ceiling=math.max(1,math.floor(L.startLevel(count,boss and 'boss' or 'trainer',g)*(100+pct)/100+.5))
       check(team[1].level<=ceiling and team[2].level<=ceiling,'trainer/boss hook uses milestone plus its own modifier')
       check(team[1].level<=team[2].level,'native relative team order is preserved')
      end
     end
    end
   end
  end
  badges(game,g,0);game.save.party[1].level=5;a.cfg.wild_levels=0;a.cfg.trainer_levels=0;a.cfg.boss_levels=0
  local low=hooks:call('trainer.party',function(_,_,party) return party end,'YOUNGSTER',1,{{species='MON_10',level=2},{species='MON_12',level=4}})
  check(low[1].level==2 and low[2].level==4,'low native trainers are never raised to the cap')
  local before=stable({saved,game.save,p});local report=R.logicCheck(game)
  check(report.ok and #report.warnings==0,'audited diagnostic passes without false Rock Smash warning')
  check(stable({saved,game.save,p})==before,'diagnostics do not mutate the world, owned moves, PP or save')
  local code=R.runCode(a);check(code:find('UR165.',1,true)==1,'new solver revision has a distinct run-code namespace')
  local resumed,why=R.activateSaved(game);check(resumed~=nil,why)
  check(resumed.randomStartUsed and R._percentageRouteBaselineMax(resumed,'SIDE_PATH','wild',false)==7,'cold Continue keeps zero-badge protection')
  check(stable(resumed.logicItemPlan.locations)==stable(p.locations),'Continue retains exact key/HM placements')
  check(game.save.party[1].moves[1].pp==17,'Continue preserves owned move PP')
 end
end
print(('Start corpus: %d edition/start pairs; %d withheld-reward checks'):format(startCount,withheldCount))
print(('PASS: %d settings/progression audit checks; %d generated worlds; %d rejected unsafe inputs'):format(n,generated,rejected))
