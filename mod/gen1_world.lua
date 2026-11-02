-- Gen 1-only authored entrance graph. Runtime identities and story ownership
-- are separate: moving a leader never moves another gym's completion flags.
return function(Core)
  local W={schema=1}
  W.defaults={gym_leaders="OFF",gym_entrances="OFF",dungeon_entrances="OFF",
    entrance_pool="SEPARATE",badge_pairing="INDEPENDENT",world_hints="AREA",
    trainer_checks="OFF",dex_checks="OFF"}
  W.choices={gym_leaders={"OFF","SAFE","CHAOS"},gym_entrances={"OFF","SAFE","CHAOS"},
    dungeon_entrances={"OFF","SAFE","CHAOS"},entrance_pool={"SEPARATE","MIXED"},
    badge_pairing={"INDEPENDENT","WITH_LEADER"},world_hints={"AREA","EXACT"},
    trainer_checks={"OFF","SOME","ALL"},dex_checks={"OFF","SOME","ALL"}}
  W.gyms={
    {map="PEWTER_GYM",key="OPP_BROCK#1",name="BROCK",badge="BOULDERBADGE",region="WEST",flag="EVENT_BEAT_BROCK"},
    {map="CERULEAN_GYM",key="OPP_MISTY#1",name="MISTY",badge="CASCADEBADGE",region="CERULEAN",flag="EVENT_BEAT_MISTY"},
    {map="VERMILION_GYM",key="OPP_LT_SURGE#1",name="LT.SURGE",badge="THUNDERBADGE",region="VERMILION",flag="EVENT_BEAT_LT_SURGE",gate="CUT_OR_SURF"},
    {map="CELADON_GYM",key="OPP_ERIKA#1",name="ERIKA",badge="RAINBOWBADGE",region="CELADON",flag="EVENT_BEAT_ERIKA",gate="USE_CUT"},
    {map="FUCHSIA_GYM",key="OPP_KOGA#1",name="KOGA",badge="SOULBADGE",region="FUCHSIA",flag="EVENT_BEAT_KOGA"},
    {map="SAFFRON_GYM",key="OPP_SABRINA#1",name="SABRINA",badge="MARSHBADGE",region="SAFFRON",flag="EVENT_BEAT_SABRINA",gate="SILPH_CLEARED"},
    {map="CINNABAR_GYM",key="OPP_BLAINE#1",name="BLAINE",badge="VOLCANOBADGE",region="CINNABAR",flag="EVENT_BEAT_BLAINE",gate="SECRET_KEY"},
    {map="VIRIDIAN_GYM",key="OPP_GIOVANNI#3",name="GIOVANNI",badge="EARTHBADGE",region="WEST",flag="EVENT_BEAT_GIOVANNI",gate="SEVEN_GYMS"},
  }
  W.dungeons={
    MT_MOON={prefix="MT_MOON",traverse={}},
    ROCK_TUNNEL={prefix="ROCK_TUNNEL",traverse={"USE_FLASH"}},
    DIGLETTS_CAVE={prefix="DIGLETTS_CAVE",traverse={}},
    SEAFOAM={prefix="SEAFOAM_ISLANDS",traverse={"USE_SURF","USE_STRENGTH","SEAFOAM_BOULDERS_ACCESS"}},
    VICTORY_ROAD={prefix="VICTORY_ROAD",traverse={"USE_STRENGTH","VICTORY_BOULDER_ACCESS"}},
    TOWER={prefix="POKEMON_TOWER",traverse={}},
    MANSION={prefix="POKEMON_MANSION",traverse={}},
    POWER={prefix="POWER_PLANT",traverse={}},
    SILPH={prefix="SILPH_CO",traverse={},gate="FUJI_RESCUED"},
    CERULEAN_CAVE={prefix="CERULEAN_CAVE",traverse={"USE_SURF"},gate="CHAMPION"},
  }
  local byMap,byKey,byBadge={},{},{}
  for _,g in ipairs(W.gyms) do byMap[g.map]=g;byKey[g.key]=g;byBadge[g.badge]=g end
  W.byMap,W.byKey=byMap,byKey
  local starts={CERULEAN_CITY="CERULEAN",VERMILION_CITY="VERMILION",LAVENDER_TOWN="LAVENDER",
    CELADON_CITY="CELADON",SAFFRON_CITY="SAFFRON",FUCHSIA_CITY="FUCHSIA",CINNABAR_ISLAND="CINNABAR"}
  local function meets(have,needs)
    for _,key in ipairs(needs or {}) do if not have[key] then return false end end
    return true
  end
  local function enabled(v) return v and v~="OFF" end
  function W.enabled(cfg)
    return enabled(cfg.gym_leaders) or enabled(cfg.gym_entrances) or enabled(cfg.dungeon_entrances)
      or cfg.victory_goal~=nil and cfg.victory_goal~="NATIVE"
  end
  function W.checked(cfg)
    if cfg.safety~="SAFE" or cfg.random_start=="CHAOS" then return false end
    for _,k in ipairs({"gym_leaders","gym_entrances","dungeon_entrances"}) do if cfg[k]=="CHAOS" then return false end end
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
      if not Core.tableHas(values,cfg[k]) then return false,"Unsupported Gen 1 setting: "..k end
    end
    if not W.enabled(cfg) then return true end
    if cfg.safety=="CHAOS" then
      for _,k in ipairs({"gym_leaders","gym_entrances","dungeon_entrances"}) do
        if cfg[k]=="SAFE" then return false,"All enabled Gen 1 world shuffles must use Chaos when progression safety is Chaos." end
      end
    end
    if cfg.safety=="SAFE" and not W.checked(cfg) then
      return false,"Safe progression requires Safe leader/entrance modes and a normal or Logic start. Select Chaos safety for unchecked combinations."
    end
    if enabled(cfg.gym_leaders) then
      if W.installed and not W.nativeConstructorReady then return false,"Native trainer presentation hook is unavailable on this host." end
      for _,g in ipairs(W.gyms) do
        local class,index=g.key:match("^(.-)#(%d+)$")
        local t=game.data.trainers and game.data.trainers[class]
        if not t or not t.parties or not t.parties[tonumber(index)] then return false,"Native leader roster missing: "..g.name end
      end
    end
    local ports,err=W.portals(game,Logic)
    if not ports then return false,err end
    local counts={}
    for _,p in ipairs(ports) do counts[p.content]=(counts[p.content] or 0)+1 end
    for _,g in ipairs(W.gyms) do if counts[g.map]~=1 then return false,"Missing/ambiguous native Gym entrance: "..g.map end end
    for id in pairs(W.dungeons) do
      local expected=({MT_MOON=2,ROCK_TUNNEL=2,DIGLETTS_CAVE=2,SEAFOAM=2,VICTORY_ROAD=2})[id] or 1
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
  local function dungeon(map)
    for id,d in pairs(W.dungeons) do if map==d.prefix or map:find(d.prefix.."_",1,true)==1 then return id,d end end
  end
  local outdoor={PALLET_TOWN="WEST",VIRIDIAN_CITY="WEST",PEWTER_CITY="WEST",ROUTE_1="WEST",ROUTE_3="WEST",
    CERULEAN_CITY="CERULEAN",ROUTE_24="CERULEAN",ROUTE_25="CERULEAN",ROUTE_5="CERULEAN",
    VERMILION_CITY="VERMILION",ROUTE_6="VERMILION",ROUTE_11="VERMILION",VERMILION_DOCK="VERMILION",
    LAVENDER_TOWN="LAVENDER",ROUTE_8="LAVENDER",CELADON_CITY="CELADON",ROUTE_7="CELADON",ROUTE_16="CELADON",
    SAFFRON_CITY="SAFFRON",FUCHSIA_CITY="FUCHSIA",CINNABAR_ISLAND="CINNABAR",ROUTE_20="SEAFOAM_COAST"}
  local function sourceRegion(p)
    local m=p.outsideMap
    if m=="ROUTE_2" then return "ROUTE2_EAST",{} end
    if m=="ROUTE_4" then
      -- The cave's east mouth is above the one-way ledges, not reachable by
      -- walking west out of Cerulean. The native west entrance is on 1F.
      if p.insideMap=="MT_MOON_1F" then return "WEST",{"GYM_OPP_BROCK#1"} end
      return "MOON_EAST",{}
    end
    if m=="ROUTE_10" then
      local y=p.sourceEndpoints[1].warp.y
      if p.insideMap=="POWER_PLANT" then return "ROCK_NORTH",{"USE_SURF"} end
      return (tonumber(y) or 0)<32 and "ROCK_NORTH" or "LAVENDER",{}
    end
    if m=="ROUTE_23" then
      return p.insideMap=="VICTORY_ROAD_1F" and "LEAGUE_SOUTH" or "LEAGUE_NORTH",{}
    end
    if m=="ROUTE_20" then
      -- Both coast components are reached by Surf. Do not assume free
      -- passage through Seafoam's boulders when either doorway is moved.
      local x=p.sourceEndpoints[1].warp.x
      return (tonumber(x) or 0)<50 and "SEAFOAM_WEST" or "SEAFOAM_EAST",{}
    end
    local g=byMap[p.insideMap]
    local req=g and g.gate and {g.gate} or {}
    if p.insideMap=="SILPH_CO_1F" then req={"FUJI_RESCUED"} end
    if p.insideMap:find("CERULEAN_CAVE",1,true)==1 then req={"CHAMPION","USE_SURF"} end
    return outdoor[m],req
  end
  function W.portals(game,Logic)
    local ports={}
    for _,p in ipairs(Logic.physicalPortals(game,1) or {}) do
      local g=byMap[p.insideMap]
      local id,d=dungeon(p.insideMap)
      if g or id then
        local region,needs=sourceRegion(p)
        if not region then return nil,"No authored entrance access rule for "..p.id end
        p.kind=g and "gym" or "dungeon";p.content=g and g.map or id
        p.region=region;p.needs=needs;p.gate=g and g.gate or d and d.gate
        -- Native Seafoam's boulders are reachable from its main 1F component
        -- (east exterior, landing 3), not the isolated west exit component.
        if id=="SEAFOAM" and p.landings[1].index==3 then p.puzzleOrigin="SEAFOAM_BOULDERS_ACCESS" end
        -- Conservative native Victory Road proof starts the switches at 1F.
        if id=="VICTORY_ROAD" and p.insideMap=="VICTORY_ROAD_1F" then p.puzzleOrigin="VICTORY_BOULDER_ACCESS" end
        ports[#ports+1]=p
      end
    end
    return ports
  end
  local function compact(p)
    local shape={}
    for _,group in ipairs({p.sourceEndpoints,p.landings,p.reverseEndpoints}) do
      local rows={};shape[#shape+1]=rows
      for _,e in ipairs(group) do rows[#rows+1]={map=e.map,index=e.index,x=e.warp.x,y=e.warp.y} end
    end
    return {shape=shape,id=p.id,kind=p.kind,content=p.content,region=p.region,needs=Core.copy(p.needs),gate=p.gate,
      outsideMap=p.outsideMap,insideMap=p.insideMap,puzzleOrigin=p.puzzleOrigin}
  end
  local edges={
    {"CERULEAN","VERMILION"},{"VERMILION","CERULEAN"},
    {"ROUTE2_EAST","WEST",{"USE_CUT"}},{"WEST","ROUTE2_EAST",{"USE_CUT"}},
    {"MOON_EAST","CERULEAN"},
    {"CERULEAN","ROCK_NORTH",{"USE_CUT"}},{"ROCK_NORTH","CERULEAN",{"USE_CUT"}},
    {"LAVENDER","CELADON"},{"CELADON","LAVENDER"},
    {"CELADON","SAFFRON"},{"SAFFRON","CELADON"},
    {"SAFFRON","CERULEAN"},{"SAFFRON","VERMILION"},{"SAFFRON","LAVENDER"},
    {"CERULEAN","SAFFRON",{"GUARDS_OPEN"}},{"VERMILION","SAFFRON",{"GUARDS_OPEN"}},{"LAVENDER","SAFFRON",{"GUARDS_OPEN"}},
    {"LAVENDER","FUCHSIA",{"POKE_FLUTE"}},{"FUCHSIA","LAVENDER",{"POKE_FLUTE"}},
    {"LAVENDER","FUCHSIA",{"USE_SURF"}},{"FUCHSIA","LAVENDER",{"USE_SURF"}},
    {"VERMILION","FUCHSIA",{"POKE_FLUTE"}},{"FUCHSIA","VERMILION",{"POKE_FLUTE"}},
    {"WEST","CINNABAR",{"USE_SURF"}},{"CINNABAR","WEST",{"USE_SURF"}},
    {"FUCHSIA","SEAFOAM_EAST",{"USE_SURF"}},{"SEAFOAM_EAST","FUCHSIA",{"USE_SURF"}},
    {"CINNABAR","SEAFOAM_WEST",{"USE_SURF"}},{"SEAFOAM_WEST","CINNABAR",{"USE_SURF"}},
    {"WEST","LEAGUE_SOUTH",{"EIGHT_GYMS","USE_SURF"}},
    {"LEAGUE_SOUTH","WEST",{"USE_SURF"}},
  }
  function W.worldState(plan,items)
    local have=Core.copy(items or {});local seen={[starts[plan.start] or "WEST"]=true};local entered={}
    local changed=true
    while changed do
      changed=false
      local function gain(t,k) if not t[k] then t[k]=true;changed=true end end
      if seen.CELADON or seen.SAFFRON then gain(have,"GUARDS_OPEN") end
      if have.USE_CUT or have.USE_SURF then gain(have,"CUT_OR_SURF") end
      for move,badge in pairs({CUT="CASCADEBADGE",FLASH="BOULDERBADGE",SURF="SOULBADGE",STRENGTH="RAINBOWBADGE",FLY="THUNDERBADGE"}) do
        if have["HM_"..move] and have[badge] then gain(have,"USE_"..move) end
      end
      for _,e in ipairs(edges) do if seen[e[1]] and meets(have,e[3]) then gain(seen,e[2]) end end
      if seen.CELADON then gain(seen,"ROCKET") end
      if seen.VERMILION and have.S_S_TICKET then gain(seen,"SS_ANNE") end
      if seen.FUCHSIA then gain(seen,"SAFARI") end
      if seen.TOWER and have.SILPH_SCOPE then gain(have,"FUJI_RESCUED") end
      if seen.SILPH and have.CARD_KEY and have.FUJI_RESCUED then gain(have,"SILPH_CLEARED") end
      local count=0
      for _,g in ipairs(W.gyms) do
        if seen[g.map] and (not g.gate or have[g.gate]) then
          gain(have,"GYM_"..g.key);gain(have,plan.badges[g.key] or g.badge)
        end
        if have["GYM_"..g.key] then count=count+1 end
      end
      if count>=7 then gain(have,"SEVEN_GYMS") end
      if count==8 then gain(have,"EIGHT_GYMS") end
      if seen.LEAGUE_NORTH and have.EIGHT_GYMS and have.USE_SURF and have.USE_STRENGTH then gain(have,"CHAMPION") end
      for _,source in ipairs(plan.portals) do
        local target=plan.byId[plan.destinations[source.id]]
        if target and seen[source.region] and meets(have,source.needs) and (not target.gate or have[target.gate]) then
          gain(entered,target.id);gain(seen,target.content)
          if target.puzzleOrigin then gain(have,target.puzzleOrigin) end
        end
      end
      -- Each entry can immediately use its paired return. Cross-dungeon
      -- exits require the authored internal traversal capabilities.
      for _,target in ipairs(plan.portals) do
        local d=W.dungeons[target.content]
        if d and seen[target.content] and meets(have,d.traverse) then
          for _,source in ipairs(plan.portals) do
            if plan.destinations[source.id]==target.id then gain(seen,source.region) end
          end
        end
      end
    end
    return seen,have,entered
  end
  local checks={
    BILL_TICKET={"CERULEAN"},SS_ANNE_CUT={"SS_ANNE"},OAK_AIDE_FLASH={"ROUTE2_EAST"},
    ROUTE_FAN_VOUCHER={"VERMILION"},BIKE_SHOP_BICYCLE={"CERULEAN","BIKE_VOUCHER"},
    ROUTE16_FLY={"CELADON","USE_CUT"},ROCKET_LIFT={"ROCKET"},ROCKET_SCOPE={"ROCKET","LIFT_KEY"},
    FUJI_FLUTE={"LAVENDER","FUJI_RESCUED"},SAFARI_TEETH={"SAFARI"},SAFARI_SURF={"SAFARI"},
    WARDEN_STRENGTH={"FUCHSIA","GOLD_TEETH"},SILPH_CARD={"SILPH"},MANSION_SECRET={"MANSION"},
  }
  function W.checkRule(def)
    if def.kind=="field_extra" and def.map=="POKEMON_MANSION_1F" then return {"MANSION"} end
    if def.key=="START_SURF" then return {"MANSION"} end
    return checks[def.key]
  end
  function W.replay(plan,itemPlan,withheld)
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
    return have.CHAMPION and #blocked==0 and #inaccessible==0 or false,
      {complete=not not have.CHAMPION,reached=reached,items=items,regions=seen,capabilities=have,
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
    local plan={schema=W.schema,start=start,portals={},byId={},destinations={},badges={},leaders={},checked=W.checked(cfg)}
    for _,p in ipairs(ports) do local c=compact(p);plan.portals[#plan.portals+1]=c;plan.byId[c.id]=c;plan.destinations[c.id]=c.id end
    for _,g in ipairs(W.gyms) do plan.badges[g.key]=(badges and badges[g.key]) or g.badge;plan.leaders[g.key]=g.key end
    return plan,ports
  end
  function W.build(game,cfg,seed,itemPlan,badgePlan,Logic)
    if not itemPlan then return nil,"Gen 1 world requires an item plan" end
    local plan,ports=W.identity(game,cfg,itemPlan.start,badgePlan and badgePlan.gymToBadge,Logic)
    if not plan then return nil,ports end
    plan.seed=seed
    local valid,baseProof=W.replay(plan,itemPlan)
    if plan.checked and not valid then return nil,"[seed] Native world does not pass the expanded entrance proof: "..table.concat(baseProof.blocked or {},", ") end
    local pools={}
    for _,p in ipairs(ports) do
      if enabled(cfg[p.kind.."_entrances"]) then
        local key=cfg.entrance_pool=="MIXED" and "mixed" or p.kind
        pools[key]=pools[key] or {};pools[key][#pools[key]+1]=p.id
      end
    end
    local rng=Core.rng(Core.hash("g1-entrances-v1",seed))
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
        shuffle(Core.rng(Core.hash("g1-leaders-v1",seed)),names)
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
    'The secret ninth badge is awarded for reading the damn settings.',
    'Professor Oak recommends saving before you do something stupid. Too late?',
    'A Magikarp wrote this hint. Somehow it still has a better plan than you.',
    'The strongest trainer here is the bastard who remembered to buy Potions.',
    'Use FLASH on your brain. It has been a dark cave in there all run.',
    'The Champion is weak to competence. Tough matchup for you, champ.',
  }
  function W.state(a)
    a.gen1State=a.gen1State or {schema=1,seed=a.seed,version=a.version,journal={},rumors={},rumorCount=0,claims={},rewards={}}
    return a.gen1State
  end
  function W.persist(mod,a) mod.save:set('gen1_state',Core.copy(W.state(a))) end
  function W.hint(a,mod,key,fallback)
    if not a or a.generation~=1 then return nil end
    local st=W.state(a)
    if st.rumors[key] then return st.rumors[key].text,st.rumors[key].tier end
    st.rumorCount=st.rumorCount+1
    local rng=Core.rng(Core.hash('gen1-rumor|'..key,a.seed))
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
      if a.gen1World then
        for _,p in ipairs(a.gen1World.portals) do
          local target=a.gen1World.byId[a.gen1World.destinations[p.id]]
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
  function W.party(a,class,index,original)
    local target=a.gen1World and a.gen1World.leaders[class..'#'..tostring(index or 1)]
    if not target or target==class..'#'..tostring(index or 1) then return original end
    local c,p=target:match('^(.-)#(%d+)$')
    local party=Core.copy(a.game.data.trainers[c].parties[tonumber(p)])
    -- A moved native roster uses the original gym's level band. The final
    -- progression cap and the user's Boss % are applied by the main hook.
    if a.gen1World.checked then
      local sourceMax,targetMax=1,1
      for _,m in ipairs(original) do sourceMax=math.max(sourceMax,m.level or 1) end
      for _,m in ipairs(party) do targetMax=math.max(targetMax,m.level or 1) end
      for _,m in ipairs(party) do m.level=math.max(1,sourceMax-math.min(2,targetMax-m.level)) end
    end
    return party
  end
  function W.levelCap(a,kind)
    if not a or not a.gen1World or not a.gen1World.checked then return nil end
    local n=0;local inv=a.game.save.inventory or {}
    for _,g in ipairs(W.gyms) do if inv[g.badge] and inv[g.badge]~=0 then n=n+1 end end
    return math.min(100,7+4*n+(kind=='boss' and 5 or kind=='trainer' and 2 or 0))
  end
  local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
  end
  function W.saveRun(mod,a)
    if a.generation~=1 then return end
    local w=a.gen1World
    mod.save:set('gen1_world',w and {schema=W.schema,seed=a.seed,version=a.version,
      destinations=Core.copy(w.destinations),leaders=Core.copy(w.leaders),badges=Core.copy(w.badges),
      locations=Core.copy(a.logicItemPlan.locations),portals=Core.copy(w.portals)} or nil)
    W.persist(mod,a)
  end
  function W.restoreRun(mod,a)
    if a.generation~=1 then return true end
    local saved=mod.save:get('gen1_world',nil);local w=a.gen1World
    if w then
      if not saved or saved.schema~=W.schema or saved.seed~=a.seed or saved.version~=a.version
        or not same(saved.destinations,w.destinations) or not same(saved.leaders,w.leaders)
        or not same(saved.badges,w.badges) or not same(saved.locations,a.logicItemPlan.locations) or not same(saved.portals,w.portals) then
        return false,'Saved Gen 1 world differs from its certified mapping. It has not been rerolled.'
      end
    end
    local st=mod.save:get('gen1_state',nil)
    if st and st.schema==1 and st.seed==a.seed and st.version==a.version then a.gen1State=Core.copy(st) end
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
    local rows={};local save=a.game.save;local flags=save.flags or {};local inv=save.inventory or {}
    for _,g in ipairs(W.gyms) do
      local target=a.gen1World and a.gen1World.leaders[g.key] or g.key
      local badge=a.gen1World and a.gen1World.badges[g.key] or g.badge
      rows[#rows+1]={label=human(g.map),right=flags[g.flag] and 'Cleared' or 'Not cleared',
        help='Leader: '..W.byKey[target].name..'. Reward: '..human(badge)..'. Completion comes from this gym\'s actual story flag.'}
    end
    for move,badge in pairs({CUT='CASCADEBADGE',FLASH='BOULDERBADGE',SURF='SOULBADGE',STRENGTH='RAINBOWBADGE',FLY='THUNDERBADGE'}) do
      local hm='HM_'..move;local learned=false
      for _,mon in ipairs(save.party or {}) do for _,m in ipairs(mon.moves or {}) do
        if (type(m)=='table' and (m.id or m.move) or m)==move then learned=true end
      end end
      rows[#rows+1]={label=move,right=inv[badge] and learned and 'Usable' or 'Needs setup',
        help='Requires '..human(badge)..' and a party Pokemon that knows '..move..'. HM in bag: '..(inv[hm] and 'yes' or 'no')..'. Badge owned: '..(inv[badge] and 'yes' or 'no')..'. Move learned in party: '..(learned and 'yes' or 'no')..'.'}
    end
    rows[#rows+1]={label='Completion proof',right=a.gen1World and a.gen1World.checked and 'Checked' or 'Not certified',
      help='Safe world generation checks all eight gyms, required item sources, paired dungeon exits and access to the Champion. This is a structural proof; combat, money management and your choices still matter. Chaos can contain locks.'}
    for _,r in ipairs(W.state(a).rewards) do rows[#rows+1]={label='Bonus: '..human(r.item),help=r.text} end
    return rows
  end
  function W.award(mod,a,I,kind,key)
    if not a or a.generation~=1 then return false end
    local mode=a.cfg[kind=='trainer' and 'trainer_checks' or 'dex_checks']
    if not mode or mode=='OFF' then return false end
    local st=W.state(a);key=kind..'|'..key
    if st.claims[key] then return false end
    local roll=Core.hash('bonus-check|'..key,a.seed)
    st.claims[key]=true
    if mode=='SOME' and math.floor(roll/65536)%4~=0 then W.persist(mod,a);return false end
    -- Bonus checks never contain a key/HM or replace a required location.
    local pool={}
    for _,id in ipairs({'POKE_BALL','GREAT_BALL','ULTRA_BALL','POTION','SUPER_POTION','HYPER_POTION','ANTIDOTE','PARLYZ_HEAL','AWAKENING','REPEL','ESCAPE_ROPE'}) do
      local d=a.game.data.items[id]
      if d and not d.keyItem and not d.machine then pool[#pool+1]=id end
    end
    if #pool==0 then st.claims[key]=nil;return false end
    local item=pool[1+math.floor(roll/256)%#pool]
    local Bag=require('src.inventory.Bag')
    local ok,pc=I.award(a.game,item,1,true,Bag.add,a.game.data)
    if not ok then st.claims[key]=nil;return false end
    local text=human(key)..': '..human(item)..(pc and ' sent to your PC (bag full).' or ' added to your bag.')
    st.rewards[#st.rewards+1]={item=item,text=text};W.persist(mod,a)
    return true,text
  end
  function W.decorateBattle(a,b)
      if a.cfg.gym_leaders=="OFF" then return end
      local target=a.gen1World.leaders[b.oppClass..'#'..tostring(b.partyIndex or 1)]
      if not target then return end
      local c,p=target:match('^(.-)#(%d+)$');local trainer=a.game.data.trainers[c]
      b.trainer=trainer;b.enemyAIMods=trainer.aiMods
      if b.aiUsesFor then b.aiUses=b:aiUsesFor() end
      local B=require('src.battle.BattleState')
      b.trainerPic=B.trainerSprite(a.game.data,trainer,c,tonumber(p))
      b.introText=trainer.name..' wants\nto fight!'
      -- Adaptive rows already supply curated native moves after the ordinary
      -- trainer hook. Preserve them through the leader presentation adapter.
      if a.cfg.adaptive_gyms and a.cfg.adaptive_gyms~='OFF' then return end
      -- Rebuild only enemy moves. Never touch the player's learned moves/PP.
      local Pokemon=require('src.pokemon.Pokemon')
      for _,mon in ipairs(b.enemyParty or {}) do
        mon.moves={}
        for _,id in ipairs(Pokemon.movesAtLevel(a.game.data.pokemon[mon.species],mon.level)) do
          mon.moves[#mon.moves+1]={id=id,pp=(a.game.data.moves[id] or {}).pp or 0}
        end
      end
      if a.cfg.movesets=='UNCHANGED' then
        if a.version=='yellow' then
          for _,entry in ipairs(trainer.specialMoves or {}) do if entry.party==tonumber(p) then
            for _,row in ipairs(entry.moves) do local mon=b.enemyParty[row.mon];local md=a.game.data.moves[row.move]
              if mon and md then mon.moves[math.min(row.slot,#mon.moves+1)]={id=row.move,pp=md.pp or 0} end
            end
          end end
        else
          local signatures={OPP_BROCK={2,'BIDE'},OPP_MISTY={2,'BUBBLEBEAM'},OPP_LT_SURGE={3,'THUNDERBOLT'},OPP_ERIKA={3,'MEGA_DRAIN'},OPP_KOGA={4,'TOXIC'},OPP_SABRINA={4,'PSYWAVE'},OPP_BLAINE={4,'FIRE_BLAST'},OPP_GIOVANNI={5,'FISSURE'}}
          local sig=signatures[c];local mon=sig and b.enemyParty[sig[1]];local md=sig and a.game.data.moves[sig[2]]
          if mon and md then mon.moves[math.min(3,#mon.moves+1)]={id=sig[2],pp=md.pp or 0} end
        end
      end
  end
  local originalMetadata
  function W.release(a)
    if originalMetadata then
      local gyms=require('data.scripts.gyms')
      for id,row in pairs(originalMetadata) do gyms[id].leader=row.leader;gyms[id].badge=row.badge end
      originalMetadata=nil
    end
    local world=a and a.game and (a.game.overworld or a.game.world)
    for _,npc in ipairs(world and world.npcs or {}) do
      if npc._urLeaderAppearance and npc.setAppearance then
        npc:setAppearance(npc.def.sprite,a.game.data.sprites[npc.def.sprite]);npc._urLeaderAppearance=nil
      end
    end
  end
  function W.present(a)
    W.release()
    if not a or not a.gen1World then return end
    local gyms=require('data.scripts.gyms');originalMetadata={}
    for _,g in ipairs(W.gyms) do
      local row=gyms[g.map]
      if row then
        originalMetadata[g.map]={leader=row.leader,badge=row.badge}
        row.leader=W.byKey[a.gen1World.leaders[g.key]].name;row.badge=a.gen1World.badges[g.key]
      end
    end
    local world=a.game.overworld or a.game.world
    if world and world.map then W.refreshNpc(a,world.map.id) end
  end
  function W.refreshNpc(a,mapId)
      local world=a.game.overworld or a.game.world
      local g=a.gen1World and W.byMap[tostring(mapId)]
      if g and world then
        local t=W.byKey[a.gen1World.leaders[g.key]]
        local map=a.game.data.maps[t.map];local sprite
        for _,obj in ipairs(map and map.objects or {}) do
          if obj.trainerClass and obj.trainerClass..'#'..tostring(obj.trainerParty or 1)==t.key then sprite=obj.sprite end
        end
        for _,npc in ipairs(world.npcs or {}) do
          local d=npc.def or {}
          if sprite and d.trainerClass and d.trainerClass..'#'..tostring(d.trainerParty or 1)==g.key and npc.setAppearance then
            npc:setAppearance(sprite,a.game.data.sprites[sprite]);npc._urLeaderAppearance=true
          end
        end
      end
  end
  function W.install(mod,R,I)
    local function active()
      local a=R.active();return a and a.generation==1 and a or nil
    end
    mod.hooks:wrap('warp.destination',function(nextFn,dm,x,y,ctx)
      local dest,dx,dy=nextFn(dm,x,y,ctx)
      local a=active();local entry=a and a.gen1World and ctx and a.doorPlan.byWarp[ctx.warp]
      if entry and dest==entry.map then a.pendingJournal={source=entry.source,target=entry.target,map=dest} end
      return dest,dx,dy
    end,100001)
    mod.events:on('map.entered',function(ev)
      local a=active();if not a or not ev then return end
      local pending=a.pendingJournal;a.pendingJournal=nil
      if pending and ev.mapId==pending.map then
        W.state(a).journal[pending.source]=pending.target;W.persist(mod,a)
      end
      W.refreshNpc(a,ev.mapId)
    end)
    local Data=require('src.core.Data')
    local resolve=Data.resolveText
    Data.resolveText=function(data,mapLabel,textConst,...)
      local text,asm=resolve(data,mapLabel,textConst,...)
      local a=active()
      if a and a.gen1World and a.cfg.gym_leaders~='OFF' and a.game.data==data then
        for _,g in ipairs(W.gyms) do
          local map=data.maps[g.map]
          if map and (map.label==mapLabel or g.map==mapLabel) then
            for _,obj in ipairs(map.objects or {}) do
              if obj.text==textConst and obj.trainerClass and obj.trainerClass..'#'..tostring(obj.trainerParty or 1)==g.key then
                local target=W.byKey[a.gen1World.leaders[g.key]]
                if not a.game.save.flags[g.flag] then text=target.name..': Ready for a\nGym battle?'
                elseif text then text=text:gsub(g.name:gsub('([^%w])','%%%1'),function() return target.name end) end
              end
            end
          end
        end
      end
      return text,asm
    end
    local okB,B=pcall(require,'src.battle.BattleState')
    W.installed=true;W.nativeConstructorReady=okB and type(B.newTrainer)=="function"
    if W.nativeConstructorReady then
      local base=B.newTrainer
      B.newTrainer=function(game,class,index,...)
        local battle=base(game,class,index,...)
        local a=active()
        if a and a.game==game and a.gen1World then W.decorateBattle(a,battle) end
        return battle
      end
    end
    mod.events:on('battle.ended',function(ev)
      local a=active();local b=ev and ev.battle
      if a and b and b.kind=='trainer' and ev.result=='win' then W.award(mod,a,I,'trainer',tostring(b.oppClass)..'#'..tostring(b.partyIndex or 1)) end
    end)
    mod.events:on('pokemon.caught',function(ev)
      local a=active()
      local owned=false
      if a and ev and ev.mon then
        for _,m in ipairs(a.game.save.party or {}) do if m==ev.mon then owned=true end end
        for _,box in ipairs(a.game.save.boxes or {}) do for _,m in ipairs(box) do if m==ev.mon then owned=true end end end
      end
      if a and ev and ev.species and owned then
        W.award(mod,a,I,'dex',tostring(ev.species))
      end
    end)
  end
  return W
end
