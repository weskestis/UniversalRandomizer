-- Gen 2-only authored entrance graph. Runtime identities and story ownership
-- are separate: moving a leader never moves another gym's completion flags.
return function(Core)
  local W={schema=1}
  W.defaults={gym_leaders="OFF",gym_entrances="OFF",dungeon_entrances="OFF",
    entrance_pool="SEPARATE",badge_pairing="INDEPENDENT",world_hints="AREA",
    trainer_checks="OFF",dex_checks="OFF"}
  W.choices={gym_leaders={"OFF","SAFE","CHAOS"},gym_entrances={"OFF","SAFE","CHAOS"},
    dungeon_entrances={"OFF","SAFE","CHAOS"},entrance_pool={"SEPARATE","MIXED"},
    badge_pairing={"INDEPENDENT","WITH_LEADER"},world_hints={"AREA","EXACT"},
    trainer_checks={"OFF","SAFE","CHAOS"},dex_checks={"OFF","SOME","ALL"}}
  W.gyms={
    {map='VIOLET_GYM',key='ZEPHYR',class='FALKNER',region='VIOLET'},
    {map='AZALEA_GYM',key='HIVE',class='BUGSY',region='AZALEA',gate='WELL_CLEARED'},
    {map='GOLDENROD_GYM',key='PLAIN',class='WHITNEY',region='GOLDENROD'},
    {map='ECRUTEAK_GYM',key='FOG',class='MORTY',region='ECRUTEAK',gate='BEASTS_RELEASED'},
    {map='OLIVINE_GYM',key='MINERAL',class='JASMINE',region='OLIVINE',gate='AMPHY_HEALED'},
    {map='CIANWOOD_GYM',key='STORM',class='CHUCK',region='CIANWOOD',gate='CHUCK_LANE'},
    {map='MAHOGANY_GYM',key='GLACIER',class='PRYCE',region='MAHOGANY',gate='ROCKET_BASE_CLEARED'},
    {map='BLACKTHORN_GYM_1F',key='RISING',class='CLAIR',region='BLACKTHORN',gate='CLAIR_BADGE'},
    {map='PEWTER_GYM',key='BOULDER',class='BROCK',region='WEST'},
    {map='CERULEAN_GYM',key='CASCADE',class='MISTY',region='KANTO',gate='MISTY_RETURNED'},
    {map='VERMILION_GYM',key='THUNDER',class='LT_SURGE',region='KANTO',gate='USE_CUT'},
    {map='CELADON_GYM',key='RAINBOW',class='ERIKA',region='KANTO',gate='USE_CUT'},
    {map='FUCHSIA_GYM',key='SOUL',class='JANINE',region='KANTO'},
    {map='SAFFRON_GYM',key='MARSH',class='SABRINA',region='KANTO'},
    {map='SEAFOAM_GYM',key='VOLCANO',class='BLAINE',region='CINNABAR'},
    {map='VIRIDIAN_GYM',key='EARTH',class='BLUE',region='WEST',gate='BLUE_RETURNED'},
  }
  W.dungeons={
    SPROUT={map='SPROUT_TOWER_1F',count=1,traverse={}},
    UNION={map='UNION_CAVE_1F',count=2,traverse={}},
    WELL={map='SLOWPOKE_WELL_B1F',count=1,traverse={}},
    BURNED={map='BURNED_TOWER_1F',count=1,traverse={}},
    LIGHTHOUSE={map='OLIVINE_LIGHTHOUSE_1F',count=1,traverse={}},
    ICE={map='ICE_PATH_1F',count=2,traverse={'USE_STRENGTH','ICE_BOULDERS_ACCESS'}},
    DEN={map='DRAGONS_DEN_1F',count=1,traverse={}},
    TOHJO={map='TOHJO_FALLS',count=2,traverse={'USE_SURF','USE_WATERFALL'}},
    ROCK={map='ROCK_TUNNEL_1F',count=2,traverse={'USE_FLASH'}},
    DIGLETT={map='DIGLETTS_CAVE',count=2,traverse={}},
    MOON={map='MOUNT_MOON',count=2,traverse={}},
    SILVER={map='SILVER_CAVE_ROOM_1',count=1,traverse={}},
  }
  W.hmBadges={CUT='HIVE',FLASH='ZEPHYR',SURF='FOG',STRENGTH='PLAIN',FLY='STORM',WHIRLPOOL='GLACIER',WATERFALL='RISING'}
  local byMap,byKey,byBadge,byClass={},{},{},{}
  for i,g in ipairs(W.gyms) do
    g.badge=g.key;g.name=g.class=='LT_SURGE' and 'LT.SURGE' or g.class:gsub('_',' ');g.flag='EVENT_BEAT_'..g.class:gsub('LT_SURGE','LTSURGE');g.sprite=g.class=='LT_SURGE' and 'SURGE' or g.class
    g.store=i<=8 and 'badges' or 'kantoBadges';g.index=(i-1)%8+1
    byMap[g.map]=g;byKey[g.key]=g;byBadge[g.badge]=g;byClass[g.class]=g
  end
  W.byMap,W.byKey=byMap,byKey
  local starts={CHERRYGROVE_CITY='EARLY',AZALEA_TOWN='AZALEA',GOLDENROD_CITY='GOLDENROD',
    ECRUTEAK_CITY='ECRUTEAK',OLIVINE_CITY='OLIVINE',CIANWOOD_CITY='CIANWOOD',MAHOGANY_TOWN='MAHOGANY',BLACKTHORN_CITY='BLACKTHORN'}
  local function meets(have,needs)
    for _,key in ipairs(needs or {}) do if not have[key] then return false end end
    return true
  end
  local function enabled(v) return v and v~="OFF" end
  function W.enabled(cfg)
    return enabled(cfg.gym_leaders) or enabled(cfg.gym_entrances) or enabled(cfg.dungeon_entrances)
      or cfg.trainer_checks=="SAFE" or cfg.trainer_checks=="CHAOS"
      or cfg.victory_goal~=nil and cfg.victory_goal~="NATIVE"
  end
  function W.checked(cfg)
    if cfg.safety~="SAFE" or cfg.random_start=="CHAOS" then return false end
    for _,k in ipairs({"gym_leaders","gym_entrances","dungeon_entrances","trainer_checks"}) do if cfg[k]=="CHAOS" then return false end end
    return true
  end
  function W.normalize(cfg,input)
    if input then
      for k,v in pairs(W.defaults) do if input[k]==nil then cfg[k]=v end end
    end
    if W.enabled(cfg) then
      cfg.random_doors="OFF";cfg.world_logic="AUDITED";cfg.progression_items=true
      if W.checked(cfg) then cfg.mart_safety=true end
      cfg.field_items=cfg.safety=="CHAOS" and "CHAOS" or "LOGIC_RANDOM"
      if enabled(cfg.gym_leaders) and cfg.badge_pairing=="WITH_LEADER" then cfg.badges=cfg.safety=="CHAOS" and "CHAOS" or "SAFE" end
      if cfg.random_start=="LOGIC" then cfg.badges="SAFE" end
    end
    return cfg
  end
  function W.preflight(game,cfg,Logic)
    for k,values in pairs(W.choices) do
      if not Core.tableHas(values,cfg[k]) and not (k=="trainer_checks" and (cfg[k]=="SOME" or cfg[k]=="ALL")) then return false,"Unsupported Gen 2 setting: "..k end
    end
    if not W.enabled(cfg) then return true end
    if cfg.safety=="CHAOS" then
      for _,k in ipairs({"gym_leaders","gym_entrances","dungeon_entrances","trainer_checks"}) do
        if cfg[k]=="SAFE" then return false,"All enabled Gen 2 world shuffles must use Chaos when progression safety is Chaos." end
      end
    end
    if cfg.safety=="SAFE" and not W.checked(cfg) then
      return false,"Safe progression requires Safe leader/entrance/trainer item modes and a normal or Logic start. Select Chaos safety for unchecked combinations."
    end
    if enabled(cfg.gym_leaders) then
      if W.installed and not W.nativeConstructorReady then return false,"Native trainer presentation hook is unavailable on this host." end
      for _,g in ipairs(W.gyms) do
        if not W.nativeTrainer(game,g.class) then return false,"Native leader roster missing: "..g.name end
      end
    end
    local ports,err=W.portals(game,Logic)
    if not ports then return false,err end
    local counts={}
    for _,p in ipairs(ports) do counts[p.content]=(counts[p.content] or 0)+1 end
    for _,g in ipairs(W.gyms) do if counts[g.map]~=1 then return false,"Missing/ambiguous native Gym entrance: "..g.map end end
    for id in pairs(W.dungeons) do
      local expected=W.dungeons[id].count
      if counts[id]~=expected then return false,"Missing/ambiguous audited dungeon entrances: "..id end
    end
    for _,kind in ipairs({"gym","dungeon"}) do
      if enabled(cfg[kind.."_entrances"]) then
        local count=0;for _,p in ipairs(ports) do if p.kind==kind then count=count+1 end end
        if count<2 then return false,"Not enough audited "..kind.." entrances in this imported game." end
      end
    end
    return true
  end
  local function compact(p)
    local shape={}
    for _,group in ipairs({p.sourceEndpoints,p.landings,p.reverseEndpoints}) do
      local rows={};shape[#shape+1]=rows
      for _,e in ipairs(group) do rows[#rows+1]={map=e.map,index=e.index,x=e.warp.x,y=e.warp.y} end
    end
    return {shape=shape,id=p.id,kind=p.kind,content=p.content,region=p.region,needs=Core.copy(p.needs),gate=p.gate,
      outsideMap=p.outsideMap,insideMap=p.insideMap,puzzleOrigin=p.puzzleOrigin,zone=p.zone}
  end
  local exterior={VIOLET_CITY='VIOLET',AZALEA_TOWN='AZALEA',GOLDENROD_CITY='GOLDENROD',ECRUTEAK_CITY='ECRUTEAK',
    OLIVINE_CITY='OLIVINE',CIANWOOD_CITY='CIANWOOD',MAHOGANY_TOWN='MAHOGANY',BLACKTHORN_CITY='BLACKTHORN',
    ROUTE_32='UNION_NORTH',ROUTE_33='AZALEA',ROUTE_44='ICE_WEST',PEWTER_CITY='WEST',VIRIDIAN_CITY='WEST',
    CERULEAN_CITY='KANTO',VERMILION_CITY='KANTO',CELADON_CITY='KANTO',FUCHSIA_CITY='KANTO',SAFFRON_CITY='KANTO',
    ROUTE_20='CINNABAR',ROUTE_9='KANTO',ROUTE_10='KANTO',ROUTE_10_NORTH='KANTO',ROUTE_10_SOUTH='KANTO',ROUTE_2='ROUTE2_EAST',ROUTE_11='KANTO',
    ROUTE_3='WEST',ROUTE_4='MOON_EAST',SILVER_CAVE_OUTSIDE='SILVER_OUTSIDE'}
  function W.portals(game,Logic)
    local ports={}
    for _,p in ipairs(Logic.physicalPortals(game,2) or {}) do
      local g=byMap[p.insideMap];local id,d
      for key,row in pairs(W.dungeons) do if p.insideMap==row.map then id,d=key,row end end
      -- Mt Moon Square's stairs are internal passages, not region entrances.
      if (g or id) and p.outsideMap~='MOUNT_MOON_SQUARE' then
        p.kind=g and 'gym' or 'dungeon';p.content=g and g.map or id
        p.region=exterior[p.outsideMap];p.needs={};p.gate=nil
        if p.outsideMap=='ROUTE_27' then p.region=p.landings[1].index==1 and 'TOHJO_WEST' or 'TOHJO_EAST' end
        if not p.region then return nil,'No authored Gen 2 doorway rule: '..p.id end
        p.zone=({KANTO=true,WEST=true,CINNABAR=true,ROUTE2_EAST=true,MOON_EAST=true,SILVER_OUTSIDE=true})[p.region] and 'KANTO' or 'JOHTO'
        if p.insideMap=='AZALEA_GYM' then p.needs={'WELL_CLEARED'} end
        if p.insideMap=='MAHOGANY_GYM' then p.needs={'ROCKET_BASE_CLEARED'} end
        if p.insideMap=='VERMILION_GYM' or p.insideMap=='CELADON_GYM' then p.needs={'USE_CUT'} end
        if p.insideMap=='DRAGONS_DEN_1F' then p.needs={'USE_SURF','CLAIR_DEFEATED'} end
        if p.insideMap=='DIGLETTS_CAVE' and p.outsideMap=='VERMILION_CITY' then p.needs={'SNORLAX_AWAKE'} end
        if p.insideMap=='DIGLETTS_CAVE' and p.outsideMap=='ROUTE_11' then p.needs={'SNORLAX_AWAKE'} end
        if p.outsideMap=='ROUTE_20' then p.needs={'USE_SURF'} end
        if id=='ICE' and p.landings[1].index==1 then p.puzzleOrigin='ICE_BOULDERS_ACCESS' end
        ports[#ports+1]=p
      end
    end
    return ports
  end
  local edges={
    {'EARLY','VIOLET',{'EGG_RETURNED'}},{'VIOLET','EARLY',{'EGG_RETURNED'}},
    {'VIOLET','UNION_NORTH',{'EGG_RETURNED','BADGE_ZEPHYR'}},{'UNION_NORTH','VIOLET'},
    {'AZALEA','GOLDENROD',{'USE_CUT','WELL_CLEARED'}},{'GOLDENROD','AZALEA',{'USE_CUT','WELL_CLEARED'}},
    {'GOLDENROD','ECRUTEAK',{'SQUIRTBOTTLE'}},{'ECRUTEAK','GOLDENROD',{'SQUIRTBOTTLE'}},
    {'ECRUTEAK','OLIVINE'},{'OLIVINE','ECRUTEAK'},
    -- The fixed Mount Mortar ground-floor passage bypasses Route 42 water.
    {'ECRUTEAK','MAHOGANY'},{'MAHOGANY','ECRUTEAK'},
    {'OLIVINE','CIANWOOD',{'USE_SURF'}},{'CIANWOOD','OLIVINE',{'USE_SURF'}},
    {'CIANWOOD','EARLY',{'USE_FLY'}},
    {'MAHOGANY','ICE_WEST',{'RADIO_CLEARED'}},{'ICE_WEST','MAHOGANY'},
    {'BLACKTHORN','EARLY'}, -- Route 45/46 ledges only work downhill.
    {'EARLY','TOHJO_WEST',{'USE_SURF'}},{'TOHJO_WEST','EARLY',{'USE_SURF'}},
    {'TOHJO_EAST','LEAGUE',{'USE_SURF','JOHTO_BADGES'}},{'LEAGUE','TOHJO_EAST',{'USE_SURF'}},
    {'KANTO','ROUTE2_EAST',{'SNORLAX_AWAKE'}}, -- actual crossing is added by DIGLETT below, not this edge
    {'WEST','ROUTE2_EAST',{'USE_CUT'}},{'ROUTE2_EAST','WEST',{'USE_CUT'}},
    {'MOON_EAST','KANTO'}, -- Route 4 ledges cannot be climbed from Cerulean.
    {'WEST','CINNABAR',{'USE_SURF'}},{'CINNABAR','WEST',{'USE_SURF'}},
  }
  -- Diglett's Cave must supply the crossing, even when its doors move.
  for i=#edges,1,-1 do if edges[i][1]=='KANTO' and edges[i][2]=='ROUTE2_EAST' then table.remove(edges,i) end end
  function W.worldState(plan,items)
    local have=Core.copy(items or {});local seen={[starts[plan.start] or 'EARLY']=true};local entered={}
    local solvedChuck=plan.start=='CIANWOOD_CITY' or plan.start=='ECRUTEAK_CITY' or plan.start=='OLIVINE_CITY' or plan.start=='MAHOGANY_TOWN'
    local changed=true
    while changed do
      changed=false
      local function gain(t,k) if not t[k] then t[k]=true;changed=true end end
      for move,badge in pairs(W.hmBadges) do if have['HM_'..move] and have['BADGE_'..badge] then gain(have,'USE_'..move) end end
      if seen.EARLY and have.MYSTERY_EGG then gain(have,'EGG_RETURNED') end
      if seen.AZALEA and seen.WELL then gain(have,'WELL_CLEARED') end
      if seen.ECRUTEAK and seen.BURNED then gain(have,'BEASTS_RELEASED') end
      if seen.LIGHTHOUSE and have.SECRETPOTION then gain(have,'AMPHY_HEALED') end
      if have.USE_STRENGTH or solvedChuck then gain(have,'CHUCK_LANE') end
      if seen.MAHOGANY and have.USE_SURF then gain(have,'ROCKET_BASE_CLEARED') end
      if seen.BLACKTHORN_GYM_1F and have.USE_STRENGTH then gain(have,'CLAIR_DEFEATED') end
      if seen.DEN and have.CLAIR_DEFEATED and have.USE_SURF and have.USE_WHIRLPOOL then gain(have,'CLAIR_BADGE') end
      if seen.KANTO and have.USE_CUT and have.USE_SURF then gain(have,'POWER_VISITED');gain(have,'MISTY_RETURNED') end
      if have.POWER_VISITED and have.MACHINE_PART then gain(have,'POWER_RESTORED') end
      if seen.CINNABAR then gain(have,'BLUE_RETURNED') end
      local johto,kanto=0,0
      for i,g in ipairs(W.gyms) do
        if seen[g.map] and (not g.gate or have[g.gate]) then gain(have,'GYM_'..g.key);gain(have,'BADGE_'..(plan.badges[g.key] or g.badge)) end
        if have['BADGE_'..g.badge] then if i<=8 then johto=johto+1 else kanto=kanto+1 end end
      end
      if johto>=7 then gain(have,'RADIO_OPEN') end
      if johto==8 then gain(have,'JOHTO_BADGES') end
      if kanto==8 then gain(have,'KANTO_BADGES') end
      if seen.GOLDENROD and (not have.RADIO_OPEN or have.RADIO_CLEARED) then gain(have,'RADIO_CARD') end
      if seen.GOLDENROD and have.RADIO_OPEN and have.ROCKET_BASE_CLEARED then gain(seen,'RADIO') end
      if seen.RADIO and have.BASEMENT_KEY and have.CARD_KEY then gain(have,'RADIO_CLEARED');gain(have,'RADIO_CARD') end
      if seen.LEAGUE and have.JOHTO_BADGES and have.EGG_RETURNED then gain(have,'CHAMPION');gain(seen,'EARLY') end
      if seen.OLIVINE and have.CHAMPION and have.S_S_TICKET then gain(seen,'KANTO') end
      if seen.KANTO and have.RADIO_CARD and have.POWER_RESTORED then gain(have,'SNORLAX_AWAKE') end
      if seen.WEST and have.JOHTO_BADGES and have.KANTO_BADGES then gain(seen,'SILVER_OUTSIDE') end
      if seen.SILVER and have.JOHTO_BADGES and have.KANTO_BADGES and have.USE_FLASH and have.USE_SURF then gain(have,'RED') end
      for _,e in ipairs(edges) do if seen[e[1]] and meets(have,e[3]) then gain(seen,e[2]) end end
      for _,source in ipairs(plan.portals) do
        local target=plan.byId[plan.destinations[source.id]]
        if target and seen[source.region] and meets(have,source.needs) then
          gain(entered,target.id);gain(seen,target.content)
          if target.puzzleOrigin then gain(have,target.puzzleOrigin) end
        end
      end
      for _,target in ipairs(plan.portals) do
        local d=W.dungeons[target.content]
        if d and seen[target.content] and meets(have,d.traverse) then
          for _,source in ipairs(plan.portals) do if plan.destinations[source.id]==target.id then gain(seen,source.region) end end
        end
      end
    end
    return seen,have,entered
  end
  local checks={
    MYSTERY_EGG={'EARLY'},SPROUT_FLASH={'SPROUT'},ILEX_CUT={'AZALEA','WELL_CLEARED'},
    FLOWER_SQUIRT={'GOLDENROD','BADGE_PLAIN'},ROUTE36_ROCK_SMASH={'GOLDENROD','SQUIRTBOTTLE'},
    DANCE_SURF={'ECRUTEAK'},OLIVINE_STRENGTH={'OLIVINE'},CIANWOOD_SECRET={'CIANWOOD'},
    CIANWOOD_FLY={'CIANWOOD','GYM_STORM','BADGE_STORM'},ROCKET_WHIRL={'MAHOGANY','ROCKET_BASE_CLEARED'},
    RADIO_BASEMENT={'RADIO'},WAREHOUSE_CARD={'RADIO','BASEMENT_KEY'},
    ICE_WATERFALL={'ICE','ICE_BOULDERS_ACCESS'},ELM_TICKET={'EARLY','CHAMPION'},
    CERULEAN_MACHINE={'CERULEAN_GYM','POWER_VISITED'},FAN_LOST_ITEM={'KANTO','POWER_RESTORED'},
    COPYCAT_PASS={'KANTO','POWER_RESTORED','LOST_ITEM'},
  }
  function W.checkRule(def) return def.kind=="trainer" and def.trainerRule or checks[def.key] end
  function W.replay(plan,itemPlan,withheld)
    if plan.checked then
      for _,source in ipairs(plan.portals) do
        local target=plan.byId[plan.destinations[source.id]]
        if not target or source.zone~=target.zone then
          return false,{error='Safe entrances cannot award Kanto badges before Johto badge-count events.',blocked={},inaccessible={source.id}}
        end
      end
    end
    local items,reached,spheres={},{},{}
    for step=1,#itemPlan.defs+2 do
      local seen,have=W.worldState(plan,items);local nextSphere={}
      for _,def in ipairs(itemPlan.defs) do
        local rule=W.checkRule(def)
        if not rule then return false,{error="Unmodeled item check: "..def.key} end
        local yes=seen[rule[1]]
        for i=2,#rule do if not have[rule[i]] then yes=false end end
        if yes and not reached[def.key] then nextSphere[#nextSphere+1]=def.key end
      end
      if #nextSphere==0 then break end
      for _,key in ipairs(nextSphere) do
        reached[key]=true;local item=itemPlan.locations[key]
        if item~=withheld then items[item]=true end
      end
      spheres[#spheres+1]=nextSphere
    end
    local seen,have,entered=W.worldState(plan,items);local blocked={}
    for _,def in ipairs(itemPlan.defs) do if not reached[def.key] then blocked[#blocked+1]=def.key end end
    local inaccessible={}
    for _,p in ipairs(plan.portals) do if not entered[p.id] then inaccessible[#inaccessible+1]=p.id end end
    return have.RED and #blocked==0 and #inaccessible==0 or false,
      {complete=not not have.RED,reached=reached,items=items,regions=seen,capabilities=have,
       spheres=spheres,blocked=blocked,inaccessible=inaccessible}
  end
  function W.bind(plan,ports)
    local byId={};for _,p in ipairs(ports) do byId[p.id]=p end
    local door={byWarp={},byEndpoint={},pairs={},portals={},mappingCollisions={}}
    local claimed={}
    local function add(from,to,kind)
      local key=from.map.."#"..from.index;local tk=to.map.."#"..to.index
      if claimed[key] and claimed[key]~=tk then return false,"Conflicting paired exit: "..key end
      claimed[key]=tk
      local m={map=to.map,x=to.warp.x,y=to.warp.y,source=key,target=tk,category=kind}
      door.byWarp[from.warp]=m;door.byEndpoint[key]=m
      return true
    end
    local targets={}
    for _,p in ipairs(ports) do
      local d=byId[plan.destinations[p.id]]
      if not d or targets[d.id] then return nil,"Entrance mapping is not a bijection" end
      targets[d.id]=true
      for i,e in ipairs(p.sourceEndpoints) do
        local to=d.landings[((i-1)%#d.landings)+1]
        local ok,err=add(e,to,p.kind);if not ok then return nil,err end
        door.pairs[#door.pairs+1]={from=e.map.."#"..e.index,to=to.map.."#"..to.index,category=p.kind}
      end
      for i,e in ipairs(d.reverseEndpoints) do
        local ok,err=add(e,p.sourceEndpoints[((i-1)%#p.sourceEndpoints)+1],p.kind)
        if not ok then return nil,err end
      end
    end
    return door
  end
  local function shuffle(rng,rows)
    for i=#rows,2,-1 do local j=(math.floor(rng:next32()/65536)%i)+1;rows[i],rows[j]=rows[j],rows[i] end
  end
  function W.identity(game,cfg,start,badges,Logic)
    local ports,err=W.portals(game,Logic);if not ports then return nil,err end
    local plan={generation=2,schema=W.schema,start=start,portals={},byId={},destinations={},badges={},leaders={},checked=W.checked(cfg)}
    for _,p in ipairs(ports) do local c=compact(p);plan.portals[#plan.portals+1]=c;plan.byId[c.id]=c;plan.destinations[c.id]=c.id end
    for _,g in ipairs(W.gyms) do plan.badges[g.key]=(badges and badges[g.key]) or g.badge;plan.leaders[g.key]=g.key end
    return plan,ports
  end
  function W.build(game,cfg,seed,itemPlan,badgePlan,Logic)
    if not itemPlan then return nil,"Gen 2 world requires an item plan" end
    local plan,ports=W.identity(game,cfg,itemPlan.start,badgePlan and badgePlan.gymToBadge,Logic)
    if not plan then return nil,ports end
    plan.seed=seed
    if cfg.badges~="VANILLA" then
      local names={};for i=9,16 do names[#names+1]=W.gyms[i].badge end
      shuffle(Core.rng(Core.hash("g2-kanto-badges-v1",seed)),names)
      for i=9,16 do plan.badges[W.gyms[i].key]=names[i-8] end
    end
    local valid,baseProof=W.replay(plan,itemPlan)
    if plan.checked and not valid then return nil,"[seed] Native world does not pass the expanded entrance proof: "..table.concat(baseProof.blocked or {},", ") end
    local pools={}
    for _,p in ipairs(ports) do
      if enabled(cfg[p.kind.."_entrances"]) then
        local key=(cfg.entrance_pool=="MIXED" and "mixed" or p.kind)..(plan.checked and ("|"..p.zone) or "")
        pools[key]=pools[key] or {};pools[key][#pools[key]+1]=p.id
      end
    end
    local rng=Core.rng(Core.hash("g2-entrances-v1",seed))
    for _,key in ipairs(Core.sortedKeys(pools)) do
      local pool=pools[key]
      -- Constructive search never destroys the current certified layout.
      -- The fallback uses the same checks, with exhaustive pair proposals.
      local proposals={}
      for i=1,#pool do for j=i+1,#pool do proposals[#proposals+1]={pool[i],pool[j]} end end
      shuffle(rng,proposals)
      for _,pair in ipairs(proposals) do
        local x,y=pair[1],pair[2]
        plan.destinations[x],plan.destinations[y]=plan.destinations[y],plan.destinations[x]
        if plan.checked and not W.replay(plan,itemPlan) then
          plan.destinations[x],plan.destinations[y]=plan.destinations[y],plan.destinations[x]
        end
      end
    end
    if enabled(cfg.gym_leaders) then
      if cfg.badge_pairing=="WITH_LEADER" then
        for _,g in ipairs(W.gyms) do
          local target=byBadge[plan.badges[g.key]]
          if not target then return nil,"Unsupported leader badge" end
          plan.leaders[g.key]=target.key
        end
      else
        local names={};for _,g in ipairs(W.gyms) do names[#names+1]=g.key end
        shuffle(Core.rng(Core.hash("g2-leaders-v1",seed)),names)
        for i,g in ipairs(W.gyms) do plan.leaders[g.key]=names[i] end
      end
    end
    local final,proof=W.replay(plan,itemPlan)
    if plan.checked and not final then return nil,"[seed] Final entrance sphere replay failed" end
    if plan.checked then
      for _,def in ipairs(itemPlan.defs) do
        local _,without=W.replay(plan,itemPlan,itemPlan.locations[def.key])
        if not without.reached or not without.reached[def.key] then return nil,"[seed] Reward locks its own source: "..def.key end
      end
    end
    plan.proof=proof
    local door,why=W.bind(plan,ports);if not door then return nil,why end
    return plan,door
  end
  local function human(s) return tostring(s or '?'):gsub('_',' ') end
  W.roasts={
    'Try using CUT on your terrible decisions, dumbass.',
    'Mew is under the truck. So is your common sense, apparently.',
    'The secret seventeenth badge is awarded for reading the damn settings.',
    'Professor Elm recommends saving before you do something stupid. Too late?',
    'A Magikarp wrote this hint. Somehow it still has a better plan than you.',
    'The strongest trainer here is the bastard who remembered to buy Potions.',
    'Use FLASH on your brain. It has been a dark cave in there all run.',
    'The Champion is weak to competence. Tough matchup for you, champ.',
  }
  function W.state(a)
    a.gen2State=a.gen2State or {schema=1,seed=a.seed,version=a.version,journal={},rumors={},rumorCount=0,claims={},rewards={}}
    return a.gen2State
  end
  function W.persist(mod,a) mod.save:set('gen2_state',Core.copy(W.state(a))) end
  function W.hint(a,mod,key,fallback)
    if not a or a.generation~=2 then return nil end
    local st=W.state(a)
    if st.rumors[key] then return st.rumors[key].text,st.rumors[key].tier end
    st.rumorCount=st.rumorCount+1
    local rng=Core.rng(Core.hash('gen2-rumor|'..key,a.seed))
    local text,tier
    if (st.rumorCount-1)%4==0 then text=rng:pick(W.roasts);tier='bogus'
    else
      local rows={}
      local items=a.logicItemPlan
      for _,d in ipairs(items and items.defs or {}) do
        local item=items.locations[d.key]
        local place=a.cfg.world_hints=='EXACT' and (human(d.map)..' / '..human(d.key)) or human(d.map)
        rows[#rows+1]=human(item)..' is at '..place..'.'
      end
      if a.gen2World then
        for _,p in ipairs(a.gen2World.portals) do
          local target=a.gen2World.byId[a.gen2World.destinations[p.id]]
          local place=a.cfg.world_hints=='EXACT' and human(p.id) or human(p.outsideMap)
          rows[#rows+1]='An entrance in '..place..' leads to '..human(target.insideMap)..'.'
        end
      end
      if #rows>0 then text=rng:pick(rows);tier='world'
      elseif fallback then text,tier=fallback()
      else text='The shop essentials option keeps Poke Balls and Potions available when enabled.';tier='tip' end
    end
    st.rumors[key]={text=text,tier=tier};W.persist(mod,a)
    return text,tier
  end
  function W.nativeTrainer(game,class)
    local data=game.data.gen2Trainers or game.data.trainers
    local entry=data and data.classes and data.classes[class]
    if not entry or not entry.trainers or not entry.trainers[1] then return nil end
    return require('src.world.gen2.Trainers').lookup(data,entry.index,1)
  end
  function W.source(game,class,index)
    local data=game.data.gen2Trainers or game.data.trainers
    local c=type(class)=='string' and class or nil
    if not c then local rec=require('src.world.gen2.Trainers').lookup(data,class,tonumber(index) or 1);c=rec and rec.classId end
    local g=c and byClass[c]
    if not g then return nil end
    local rec=W.nativeTrainer(game,c)
    if index~=nil and index~=1 and index~=(rec and rec.id) then return nil end
    return g
  end
  function W.party(a,class,index,original)
    local source=a.gen2World and W.source(a.game,class,index)
    local target=source and byKey[a.gen2World.leaders[source.key]]
    if not target or target==source then return original end
    local party=require('src.world.gen2.Trainers').party(a.game.data,W.nativeTrainer(a.game,target.class))
    if a.gen2World.checked then
      local sourceMax,targetMax=1,1
      for _,m in ipairs(original) do sourceMax=math.max(sourceMax,m.level or 1) end
      for _,m in ipairs(party) do targetMax=math.max(targetMax,m.level or 1) end
      for _,m in ipairs(party) do m.level=math.max(1,sourceMax-math.min(2,targetMax-m.level)) end
    end
    return party
  end
  function W.badgeOwned(a,g)
    local player=a.game.save.player or {};local rows=player[g.store] or {}
    local v=rows[g.badge]
    return v==true or (type(v)=='number' and v>0) or rows[g.index]==true
  end
  function W.levelCap(a,kind)
    if not a or not a.gen2World or not a.gen2World.checked then return nil end
    local n=0;for _,g in ipairs(W.gyms) do if W.badgeOwned(a,g) then n=n+1 end end
    return math.min(100,7+4*math.min(n,8)+5*math.max(0,n-8)+(kind=='boss' and 5 or kind=='trainer' and 2 or 0))
  end
  function W.badgeFlags(a)
    local constants=a.game.data.gen2Constants or {}
    local world=a.game.world or a.game.overworld
    local order=constants.engineFlagOrder or (world and world.constants and world.constants.engineFlagOrder)
    local ids={}
    for index,name in pairs(order or {}) do if type(index)=='number' then ids[name]=index-1 end end
    local offset=a.version=='crystal' and 27 or 26
    for i,g in ipairs(W.gyms) do
      local name='ENGINE_'..g.badge..'BADGE'
      ids[name]=ids[name] or offset+i-1
    end
    local out={};local mapping=a.gen2World and a.gen2World.badges or a.badgePlan and a.badgePlan.gymToBadge or {}
    for source,target in pairs(mapping) do out[ids['ENGINE_'..source..'BADGE']]=ids['ENGINE_'..target..'BADGE'] end
    return out
  end
  function W.prepare(a)
    if not a or a.generation~=2 then return end
    if a.gen2World then
      a.badgePlan=a.badgePlan or {mode='VANILLA',gen=2}
      a.badgePlan.gymToBadge=Core.copy(a.gen2World.badges)
    end
    if a.badgePlan then a.badgePlan.flagMap=W.badgeFlags(a) end
  end

  local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
  end
  function W.saveRun(mod,a)
    if a.generation~=2 then return end
    local w=a.gen2World
    mod.save:set('gen2_world',w and {schema=W.schema,seed=a.seed,version=a.version,
      destinations=Core.copy(w.destinations),leaders=Core.copy(w.leaders),badges=Core.copy(w.badges),
      locations=Core.copy(a.logicItemPlan.locations),portals=Core.copy(w.portals)} or nil)
    W.persist(mod,a)
  end
  function W.restoreRun(mod,a)
    if a.generation~=2 then return true end
    local saved=mod.save:get('gen2_world',nil);local w=a.gen2World
    if w then
      if not saved or saved.schema~=W.schema or saved.seed~=a.seed or saved.version~=a.version
        or not same(saved.destinations,w.destinations) or not same(saved.leaders,w.leaders)
        or not same(saved.badges,w.badges) or not same(saved.locations,a.logicItemPlan.locations) or not same(saved.portals,w.portals) then
        return false,'Saved Gen 2 world differs from its certified mapping. It has not been rerolled.'
      end
    end
    local st=mod.save:get('gen2_state',nil)
    if st and st.schema==1 and st.seed==a.seed and st.version==a.version then a.gen2State=Core.copy(st) end
    return true
  end
  function W.journal(a)
    local rows={};local discovered=W.state(a).journal
    for _,key in ipairs(Core.sortedKeys(discovered)) do
      rows[#rows+1]={label=human(key),help='Discovered passage: '..human(discovered[key])..'. Its exit returns to this entrance.'}
    end
    if #rows==0 then rows[1]={label='No entrances discovered',help='Use a shuffled entrance to record its destination. Undiscovered entrances are not revealed here.'} end
    return rows
  end
  function W.tracker(a)
    local rows={};local world=a.game.world or a.game.overworld
    -- Gym event indices are shared by the native Gold/Silver/Crystal tables.
    local ids=world and world.events and require('src.core.gen2.FlagNames').events or {}
    for _,g in ipairs(W.gyms) do
      local target=a.gen2World and a.gen2World.leaders[g.key] or g.key
      local badge=a.gen2World and a.gen2World.badges[g.key] or (a.badgePlan and a.badgePlan.gymToBadge[g.key]) or g.badge
      local id=ids[g.flag];local beaten=world and world.events and id and world.events:get(id)
      rows[#rows+1]={label=human(g.map),right=beaten and 'Cleared' or 'Not cleared',
        help='Leader: '..byKey[target].name..'. Reward: '..human(badge)..' Badge. '..(g.key=='RISING' and 'After beating this leader, finish Dragon\'s Den to receive the badge.' or 'Defeat the leader here to clear this gym.')}
    end
    for _,move in ipairs(Core.sortedKeys(W.hmBadges)) do
      local badge=W.hmBadges[move];local inv=a.game.save.inventory or {};local learned=false
      for _,m in ipairs(a.game.save.party or {}) do for _,entry in ipairs(m.moves or {}) do
        if (type(entry)=='table' and (entry.id or entry.move) or entry)==move then learned=true end
      end end
      local owned=W.badgeOwned(a,byBadge[badge])
      rows[#rows+1]={label=move,right=owned and learned and 'Usable' or 'Needs setup',
        help='Requires '..badge..' Badge and a party Pokemon that knows '..move..'. HM in bag: '..(inv['HM_'..move] and 'yes' or 'no')..'. Badge owned: '..(owned and 'yes' or 'no')..'. Move learned: '..(learned and 'yes' or 'no')..'.'}
    end
    rows[#rows+1]={label='Completion proof',right=a.gen2World and a.gen2World.checked and 'Checked' or 'Not certified',
      help='Safe checks all 16 badges, Johto story gates, required items, the League, Kanto power/radio progression, paired dungeon exits and access to Red. Combat and money are assumed manageable. Chaos may contain locks.'}
    for _,r in ipairs(W.state(a).rewards) do rows[#rows+1]={label='Trainer item: '..human(r.item),help=r.text} end
    return rows
  end

  function W.award(mod,a,I,kind,key)
    if not a or a.generation~=2 or kind~='trainer' or not W.randomizer then return false end
    local class,member=tostring(key):match('^(.-)#(.+)$')
    key=class and I.trainerKey(a.game,2,class,member)
    return I.trainerReward(mod,a,W,W.randomizer,key)
  end
  function W.decorateBattle(a,b)
    local t=b and b.trainer
    local g=t and W.source(a.game,t.classId or t.class,t.memberId or t.index)
    if not g or a.cfg.gym_leaders=='OFF' then return end
    local target=byKey[a.gen2World.leaders[g.key]];local rec=target and W.nativeTrainer(a.game,target.class)
    if not rec then return end
    b._urSourceTrainer=g.class..'#1'
    -- Script records are never changed: victory callbacks still own the original event/TM.
    t.classId=rec.classId;t.class=rec.class;t.memberId=rec.id;t.className=rec.className
    t.name=rec.name;t.trainerName=rec.name;t.attributes=Core.copy(rec.attributes);t.items=Core.copy(rec.items)
    t.baseMoney=rec.baseMoney
  end
  local function appearance(a,npc,id)
    local world=a.game.world or a.game.overworld
    local def=(world.sprites or {})[id] or (a.game.data.sprites or {})[id]
    if def and npc.setSpriteDef then
      if npc:setSpriteDef(def) and world.applySpritePalette then world:applySpritePalette(npc) end
      npc.appearance=id;return true
    end
  end
  function W.release(a)
    local world=a and a.game and (a.game.world or a.game.overworld)
    for _,npc in ipairs(world and world.npcs or {}) do if npc._urGen2LeaderAppearance then
      appearance(a,npc,npc._urGen2LeaderAppearance);npc._urGen2LeaderAppearance=nil
    end end
  end
  function W.refreshNpc(a,mapId)
    local world=a.game.world or a.game.overworld;local source=byMap[mapId]
    if not a.gen2World or not source or not world then return end
    local target=byKey[a.gen2World.leaders[source.key]]
    local targetMap=a.game.data.gen2Maps[target.map];local sprite
    for _,obj in ipairs(targetMap and targetMap.objects or {}) do
      if tostring(obj.sprite):upper()=='SPRITE_'..target.sprite or tostring(obj.sprite):upper()==target.sprite then sprite=obj.sprite end
    end
    for _,npc in ipairs(world.npcs or {}) do local obj=npc.def or {}
      if sprite and (tostring(obj.sprite):upper()=='SPRITE_'..source.sprite or tostring(obj.sprite):upper()==source.sprite) then
        if appearance(a,npc,sprite) then npc._urGen2LeaderAppearance=obj.sprite end
      end
    end
  end
  function W.present(a)
    if not a or not a.gen2World then return end
    local world=a.game.world or a.game.overworld
    if world and world.map then W.refreshNpc(a,world.map.id) end
  end
  function W.install(mod,R,I)
    W.randomizer=R
    local ownerHooks,ownerEpoch
    local function active()
      local rt=require('src.mods.Runtime');local hooks=rt.hooks
      if not hooks or not hooks.ownerEpoch then return nil end
      local epoch=hooks:ownerEpoch(mod.id or 'universal_randomizer')
      if not ownerHooks then ownerHooks,ownerEpoch=hooks,epoch end
      if hooks~=ownerHooks or epoch~=ownerEpoch then return nil end
      local a=R.active();return a and a.generation==2 and a or nil
    end
    mod.hooks:wrap('warp.destination',function(nextFn,dm,x,y,ctx)
      local dest,dx,dy=nextFn(dm,x,y,ctx)
      local a=active();local entry=a and a.gen2World and ctx and a.doorPlan.byWarp[ctx.warp]
      if entry and dest==entry.map then a.pendingJournal={source=entry.source,target=entry.target,map=dest} end
      return dest,dx,dy
    end,100001)
    mod.events:on('map.entered',function(ev)
      local a=active();if not a or not ev then return end
      local pending=a.pendingJournal;a.pendingJournal=nil
      if pending and ev.mapId==pending.map then W.state(a).journal[pending.source]=pending.target;W.persist(mod,a) end
      W.refreshNpc(a,ev.mapId)
    end)
    local loaded,B=pcall(require,'src.battle.gen2.Battle');local base=loaded and B.new
    W.installed=true;W.nativeConstructorReady=type(base)=='function'
    if W.nativeConstructorReady then B.new=function(opts)
      local b=base(opts);local a=active()
      if a and a.gen2World and opts and opts.data==a.game.data then W.decorateBattle(a,b) end
      return b
    end end
    mod.hooks:wrap('script.command',function(nextFn,ctx,name,args,cmd)
      local a=active();local world=a and a.gen2World
      local mapId=ctx and (ctx.mapId or ctx.map)
      local g=byMap[tostring(mapId)]
      if not g and (mapId=='DRAGONS_DEN_B1F' or mapId=='DRAGON_SHRINE') then g=byKey.RISING end
      if world and g and name=='writetext' and cmd and ctx.vm and ctx.vm.text then
        local body=ctx.vm.text[cmd.text]
        if type(body)=='string' then
          local changed=body;local target=byKey[world.leaders[g.key]]
          if a.cfg.gym_leaders~='OFF' then
            if g.class=='LT_SURGE' then
              changed=changed:gsub('LT%.SURGE','SURGE'):gsub('LT SURGE','SURGE'):gsub('%f[%a]SURGE%f[%A]',function() return target.name end)
            else changed=changed:gsub(g.name:gsub('([^%w])','%%%1'),function() return target.name end) end
          end
          local badge=world.badges[g.key]
          if badge~=g.badge then changed=changed:gsub(g.badge..'BADGE',badge..'BADGE'):gsub(g.badge..' BADGE',badge..' BADGE'):gsub(g.badge..'%-%s*BADGE',badge..'BADGE') end
          if changed~=body then
            local c=Core.copy(cmd);c.text='__ur_g2_world_'..tostring(cmd.text)..'_'..target.key..'_'..badge
            ctx.vm.text[c.text]=changed;return nextFn(ctx,name,args,c)
          end
        end
      end
      return nextFn(ctx,name,args,cmd)
    end,100001)
    mod.events:on('battle.ended',function(ev)
      local a=active();local b=ev and ev.battle
      if a and b and b.trainer and not b.wild and ev.result=='win' and not ev.skipped and not b.link and not b.linkBattle and not b.isLink and not b.inBattleTowerBattle then
        W.award(mod,a,I,'trainer',b._urSourceTrainer or I.trainerKey(a.game,2,b.trainer.classId or b.trainer.class,b.trainer.member or b.trainer.memberId or b.trainer.index or b.trainer.id))
      end
    end)

  end

  return W
end
