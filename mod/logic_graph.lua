return function(Core)
  local L={}

  L.STARTS={
    [1]={"CERULEAN_CITY","VERMILION_CITY","LAVENDER_TOWN","CELADON_CITY","SAFFRON_CITY","FUCHSIA_CITY","CINNABAR_ISLAND"},
    [2]={"CHERRYGROVE_CITY","AZALEA_TOWN","GOLDENROD_CITY","ECRUTEAK_CITY","OLIVINE_CITY","CIANWOOD_CITY","MAHOGANY_TOWN","BLACKTHORN_CITY"},
  }

  -- Ordered local objectives for starts that are not equivalent to walking out
  -- of a normal early-game town.  Earlier entries are always preferred over a
  -- merely low-level adjacent map.  This is intentionally conservative: if a
  -- safe proof is not known, the route scorer does not invent one.
  L.START_POLICIES={
    [1]={
      CERULEAN_CITY={"ROUTE_5","ROUTE_24","ROUTE_4"},
      VERMILION_CITY={"ROUTE_6","ROUTE_11","DIGLETTS_CAVE"},
      LAVENDER_TOWN={"ROUTE_8","ROUTE_10"},
      -- Celadon must obtain a guard drink before Route 7 is a real escape.
      -- Protect the Department Store exterior door when this is the start.
      CELADON_CITY={"CELADON_MART_1F","ROUTE_7","ROUTE_16"},
      SAFFRON_CITY={"SAFFRON_MART","ROUTE_8","ROUTE_7","ROUTE_6","ROUTE_5"},
      -- Fuchsia has a completely land-based east escape through Routes
      -- 15->14->13->12->11.  Surf is useful but is not a Random Start gate.
      FUCHSIA_CITY={"ROUTE_15","ROUTE_14","ROUTE_13","ROUTE_12","ROUTE_11"},
      CINNABAR_ISLAND={"POKEMON_MANSION_1F","CINNABAR_GYM","ROUTE_21","ROUTE_20"},
    },
    [2]={
      CHERRYGROVE_CITY={"ROUTE_30","ROUTE_29"},
      AZALEA_TOWN={"KURTS_HOUSE","SLOWPOKE_WELL_B1F","AZALEA_GYM","ILEX_FOREST","ROUTE_33"},
      GOLDENROD_CITY={"GOLDENROD_GYM","GOLDENROD_FLOWER_SHOP","ROUTE_35","ROUTE_36","ROUTE_34"},
      -- Burned Tower is the story gate that makes Morty available; Surf comes
      -- from the Dance Theater after that local sequence.
      ECRUTEAK_CITY={"BURNED_TOWER_1F","ECRUTEAK_GYM","DANCE_THEATER","ROUTE_38","ROUTE_42","ROUTE_37"},
      OLIVINE_CITY={"ROUTE_39","ROUTE_38","ECRUTEAK_CITY","BURNED_TOWER_1F","ECRUTEAK_GYM"},
      CIANWOOD_CITY={"CIANWOOD_GYM","CIANWOOD_PHARMACY","ROUTE_41"},
      MAHOGANY_TOWN={"ROUTE_42","MOUNT_MORTAR_1F_OUTSIDE","ECRUTEAK_CITY","BURNED_TOWER_1F","ECRUTEAK_GYM"},
      BLACKTHORN_CITY={"ROUTE_45","ROUTE_46","ROUTE_29","NEW_BARK_TOWN"},
    },
  }

  -- Complete LOGIC Random Start escape certificates.  These are authored
  -- progression proofs, not level heuristics: each proof describes how a fresh
  -- post-starter run reaches a normal early-game component without teleport
  -- recovery or forced story flags.  SAFE badge randomization is constrained
  -- separately so any badge named here remains obtainable at the stated gym.
  L.START_PROOFS={
    [1]={
      CERULEAN_CITY={kind="CUT_RETURN",requiredMoves={"CUT"},badgeLocks={{gym="CERULEAN_CITY",badge="CASCADEBADGE"}},
        steps={"Route 5 -> Underground Path -> Route 6/Vermilion","Visit Bill on Route 25 for S.S. Ticket","Defeat Misty for Cascade Badge","Board S.S. Anne and receive HM Cut","Teach Cut","Use Diglett's Cave -> Route 2 Cut tree to return to west Kanto"}},
      VERMILION_CITY={kind="CUT_RETURN",requiredMoves={"CUT"},badgeLocks={{gym="CERULEAN_CITY",badge="CASCADEBADGE"}},
        steps={"Route 6 -> Underground Path -> Route 5/Cerulean","Visit Bill on Route 25 for S.S. Ticket","Defeat Misty for Cascade Badge","Return to S.S. Anne and receive HM Cut","Teach Cut","Use Diglett's Cave -> Route 2 Cut tree to return to west Kanto"}},
      LAVENDER_TOWN={kind="DRINK_RETURN",steps={"Route 8 -> Underground Path -> Route 7/Celadon","Buy Fresh Water/Soda/Lemonade in Celadon","Give the drink to a Saffron guard","Use the opened Saffron routes to continue Kanto progression"}},
      CELADON_CITY={kind="DRINK_RETURN",steps={"Enter Celadon Department Store","Buy Fresh Water/Soda/Lemonade","Give the drink to a Saffron guard","Use the opened Saffron routes to continue Kanto progression"}},
      SAFFRON_CITY={kind="DRINK_RETURN",steps={"Buy guaranteed Fresh Water at the local Mart","Give it to any Saffron guard from the city side","Leave through Route 5/6/7/8","Continue normal Kanto progression"}},
      FUCHSIA_CITY={kind="LAND_RETURN",steps={"Route 15","Route 14","Route 13","Route 12 south","Route 11","Vermilion City; no HM is required for this escape"}},
      CINNABAR_ISLAND={kind="LOCAL_HM",badgeLocks={{gym="CINNABAR_ISLAND",badge="SOULBADGE"}},steps={"Explore Pokemon Mansion","Obtain Secret Key and the LOGIC RANDOM local Surf placement","Open and defeat Cinnabar Gym","Receive Soul Badge","Teach Surf to a compatible Pokemon","Surf to Pallet/Seafoam and continue Kanto"}},
    },
    [2]={
      CHERRYGROVE_CITY={kind="STORY_RETURN",steps={"Route 30","Visit Mr. Pokemon and receive the Mystery Egg/Pokedex progression","Return through Cherrygrove -> Route 29 -> New Bark","Continue normal Johto story"}},
      AZALEA_TOWN={kind="CUT_ESCAPE",requiredMoves={"CUT"},badgeLocks={{gym="AZALEA_TOWN",badge="HIVE"}},
        steps={"Speak with Kurt","Clear Slowpoke Well","Defeat Bugsy for Hive Badge","Resolve the Ilex Forest Farfetch'd event","Receive HM Cut","Teach Cut and exit Ilex Forest to Route 34/Goldenrod"}},
      GOLDENROD_CITY={kind="SQUIRTBOTTLE_ESCAPE",badgeLocks={{gym="GOLDENROD_CITY",badge="PLAIN"}},steps={"Defeat Whitney","Obtain Squirtbottle from the Flower Shop","Travel Route 35/National Park -> Route 36","Clear Sudowoodo","Reach Route 37/Ecruteak and continue Johto"}},
      ECRUTEAK_CITY={kind="SURF_FLY_RETURN",requiredMoves={"SURF","FLY"},badgeLocks={{gym="ECRUTEAK_CITY",badge="FOG"},{gym="CIANWOOD_CITY",badge="STORM"}},
        steps={"Enter Burned Tower and complete Morty's local story gate","Defeat Morty for Fog Badge","Defeat the Kimono Girls and receive HM Surf","Teach Surf","Travel through Olivine/Route 40/41 to Cianwood","Use the solved start-safe Cianwood Gym lane and defeat Chuck","Receive Storm Badge and native HM Fly","Teach Fly and return to New Bark"}},
      OLIVINE_CITY={kind="SURF_FLY_RETURN",requiredMoves={"SURF","FLY"},badgeLocks={{gym="ECRUTEAK_CITY",badge="FOG"},{gym="CIANWOOD_CITY",badge="STORM"}},
        steps={"Walk Route 39 -> Route 38 -> Ecruteak","Complete Burned Tower","Defeat Morty for Fog Badge and obtain HM Surf from Dance Theater","Surf Route 40/41 to Cianwood","Defeat Chuck for Storm Badge and receive native HM Fly","Teach Fly and return to New Bark"}},
      CIANWOOD_CITY={kind="NATIVE_FLY_RETURN",requiredMoves={"FLY"},badgeLocks={{gym="CIANWOOD_CITY",badge="STORM"}},
        steps={"Use the start-only solved boulder lane to reach Chuck","Defeat Chuck","Receive Storm Badge","Receive native HM Fly from Chuck's wife","Teach Fly to the guaranteed compatible Mania gift/starter option","Fly to New Bark"}},
      MAHOGANY_TOWN={kind="SURF_FLY_RETURN",requiredMoves={"SURF","FLY"},badgeLocks={{gym="ECRUTEAK_CITY",badge="FOG"},{gym="CIANWOOD_CITY",badge="STORM"}},
        steps={"Travel west on Route 42 through the land-accessible Mount Mortar passage","Reach Ecruteak","Complete Burned Tower","Defeat Morty for Fog Badge and obtain HM Surf","Surf from Olivine to Cianwood","Defeat Chuck for Storm Badge and receive HM Fly","Fly to New Bark"}},
      BLACKTHORN_CITY={kind="LEDGE_RETURN",steps={"Leave south on Route 45","Follow the one-way ledge descent through Route 46","Reach Route 29/New Bark without any HM","Continue the normal Johto story"}},
    },
  }

  function L.proof(gen,start)
    return Core.copy(L.START_PROOFS[gen] and L.START_PROOFS[gen][tostring(start or "")] or nil)
  end

  -- Traversal requirements that are invisible to a naive map-adjacency graph.
  -- These are the high-risk Random Start edges; ordinary story checks remain
  -- owned by the cartridge scripts.  A required field move means the HM item,
  -- badge permission and an actually taught move must all be true at runtime.
  L.EDGE_REQUIREMENTS={
    [1]={
      ["CINNABAR_ISLAND>ROUTE_21"]={move="SURF"},
      ["CINNABAR_ISLAND>ROUTE_20"]={move="SURF"},
      ["ROUTE_21>CINNABAR_ISLAND"]={move="SURF"},
      ["ROUTE_20>CINNABAR_ISLAND"]={move="SURF"},
      ["FUCHSIA_CITY>ROUTE_19"]={move="SURF"},
      ["ROUTE_19>FUCHSIA_CITY"]={move="SURF"},
      ["ROUTE_12>ROUTE_13"]={move="SURF",alternate=true},
    },
    [2]={
      ["CIANWOOD_CITY>ROUTE_41"]={move="SURF",escapeMove="FLY"},
      ["ROUTE_41>CIANWOOD_CITY"]={move="SURF"},
      ["OLIVINE_CITY>ROUTE_40"]={move="SURF",alternate=true},
      ["ROUTE_40>OLIVINE_CITY"]={move="SURF",alternate=true},
      ["MAHOGANY_TOWN>ROUTE_42"]={move="SURF",alternate=true},
      ["ROUTE_42>MAHOGANY_TOWN"]={move="SURF",alternate=true},
      ["BLACKTHORN_CITY>DRAGONS_DEN_1F"]={move="SURF"},
      ["DRAGONS_DEN_1F>BLACKTHORN_CITY"]={move="SURF"},
    },
  }

  local BADGE_FOR_MOVE={
    [1]={CUT="CASCADEBADGE",FLY="THUNDERBADGE",SURF="SOULBADGE",STRENGTH="RAINBOWBADGE",FLASH="BOULDERBADGE"},
    [2]={CUT="HIVE",FLY="STORM",SURF="FOG",STRENGTH="PLAIN",FLASH="ZEPHYR",WHIRLPOOL="GLACIER",WATERFALL="RISING"},
  }

  function L.logicStarts(gen)
    return Core.copy(L.STARTS[gen] or {})
  end

  function L.policy(gen,start)
    return Core.copy(L.START_POLICIES[gen] and L.START_POLICIES[gen][tostring(start or "")] or nil)
  end

  function L.preferredRank(gen,start,current,dest)
    local p=L.START_POLICIES[gen] and L.START_POLICIES[gen][tostring(start or "")]
    if not p then return nil end
    dest=tostring(dest or "")
    for i,id in ipairs(p) do
      if dest==id or dest:find(id,1,true)==1 then return i end
    end
    return nil
  end

  function L.edgeRequirement(gen,from,to)
    return L.EDGE_REQUIREMENTS[gen] and L.EDGE_REQUIREMENTS[gen][tostring(from or "")..">"..tostring(to or "")] or nil
  end

  function L.badgeForMove(gen,move)
    return BADGE_FOR_MOVE[gen] and BADGE_FOR_MOVE[gen][tostring(move or ""):upper()] or nil
  end

  function L.forbiddenBeforeMove(gen,start,to,hasMove)
    local req=L.edgeRequirement(gen,start,to)
    return req and req.move and not hasMove or false
  end

  -- ---------------------------------------------------------------------
  -- 2.0 progression-item world graph
  -- ---------------------------------------------------------------------
  -- This is deliberately an abstract *progression* graph rather than a raw
  -- warp graph. Cartridge scripts still own story/badge gates; these nodes
  -- model the item-bearing components and the item prerequisites that join
  -- them. The item placer asks this graph what is reachable after every
  -- placement, exactly like a restrictive-fill multiworld solver.
  local ITEM_WORLD={
    [1]={
      default="EARLY", completion="VICTORY",
      starts={
        CERULEAN_CITY="EARLY", VERMILION_CITY="VERMILION",
        LAVENDER_TOWN="LAVENDER", CELADON_CITY="CELADON",
        SAFFRON_CITY="SAFFRON", FUCHSIA_CITY="FUCHSIA",
        CINNABAR_ISLAND="CINNABAR",
      },
      edges={
        {"EARLY","VERMILION"},{"VERMILION","EARLY"},
        {"VERMILION","ROUTE2_EAST"},{"ROUTE2_EAST","VERMILION"},
        {"ROUTE2_EAST","EARLY",{"HM_CUT"}},
        {"EARLY","LAVENDER",{"HM_CUT"}},
        {"LAVENDER","CELADON"},{"CELADON","LAVENDER"},
        {"CELADON","SAFFRON"},{"SAFFRON","CELADON"},
        {"LAVENDER","SAFFRON"},{"SAFFRON","LAVENDER"},
        -- The guard drink is a guaranteed non-randomized world resource. Once
        -- Saffron is reached from either side, its Route 5/6 exits reconnect
        -- the Cerulean/Vermilion early component.
        {"SAFFRON","EARLY"},{"EARLY","SAFFRON",{"HM_CUT"}},
        {"SAFFRON","VERMILION"},{"VERMILION","SAFFRON",{"HM_CUT"}},
        {"CELADON","ROCKET"},{"ROCKET","CELADON"},
        {"LAVENDER","TOWER"},{"TOWER","LAVENDER"},
        {"VERMILION","SS_ANNE",{"S_S_TICKET"}},{"SS_ANNE","VERMILION"},
        {"VERMILION","FUCHSIA",{"POKE_FLUTE"}},{"FUCHSIA","VERMILION"},
        {"EARLY","CINNABAR",{"HM_SURF"}},{"FUCHSIA","CINNABAR",{"HM_SURF"}},
        {"CINNABAR","EARLY",{"HM_SURF"}},
        {"LAVENDER","POWER",{"HM_SURF"}},{"POWER","LAVENDER",{"HM_SURF"}},
        -- Completion is deliberately gated by the full authored Kanto item
        -- spine. A shallow Surf+Strength shortcut made the restrictive-fill
        -- scorer value Victory Road before Cut/Rocket/Tower/Silph progression,
        -- which could strand the remaining key items. Badge/story order stays
        -- cartridge-owned, but every randomized item prerequisite must exist.
        {"EARLY","VICTORY",{"S_S_TICKET","HM_CUT","LIFT_KEY","SILPH_SCOPE","POKE_FLUTE","GOLD_TEETH","HM_SURF","HM_STRENGTH","CARD_KEY","SECRET_KEY"}},
      },
    },
    [2]={
      default="EARLY", completion="MT_SILVER",
      starts={
        CHERRYGROVE_CITY="EARLY", AZALEA_TOWN="AZALEA",
        GOLDENROD_CITY="GOLDENROD", ECRUTEAK_CITY="ECRUTEAK",
        OLIVINE_CITY="OLIVINE", CIANWOOD_CITY="CIANWOOD",
        MAHOGANY_TOWN="MAHOGANY", BLACKTHORN_CITY="BLACKTHORN",
      },
      edges={
        {"EARLY","VIOLET"},{"VIOLET","EARLY"},
        {"VIOLET","AZALEA",{"MYSTERY_EGG"}},
        {"AZALEA","VIOLET",{"HM_CUT"}},
        {"AZALEA","GOLDENROD",{"HM_CUT"}},{"GOLDENROD","AZALEA",{"HM_CUT"}},
        -- Route 36's TM08 ROCK SMASH is required for the Burned Tower/Morty
        -- progression seam. Keep the restrictive-fill graph conservative: an
        -- Ecruteak progression sphere is not considered solved until both the
        -- Sudowoodo gate and ROCK SMASH are available.
        {"GOLDENROD","ECRUTEAK",{"SQUIRTBOTTLE","TM_ROCK_SMASH"}},{"ECRUTEAK","GOLDENROD",{"SQUIRTBOTTLE"}},
        {"ECRUTEAK","OLIVINE"},{"OLIVINE","ECRUTEAK"},
        {"ECRUTEAK","MAHOGANY"},{"MAHOGANY","ECRUTEAK"},
        {"OLIVINE","CIANWOOD",{"HM_SURF"}},{"CIANWOOD","OLIVINE",{"HM_SURF"}},
        {"CIANWOOD","EARLY",{"HM_FLY"}},
        {"MAHOGANY","RADIO"},{"RADIO","MAHOGANY"},
        {"RADIO","BLACKTHORN",{"BASEMENT_KEY","CARD_KEY"}},
        {"BLACKTHORN","EARLY"},
        -- Reaching the League is a whole-Johto story proof, not merely a map
        -- traversal proof. A random start in Blackthorn must not bypass
        -- mandatory earlier story/HM gates just because it begins beyond them.
        -- Require the complete normal-progression item spine before the solver
        -- can call Johto completable. Fly/Flash remain useful rather than
        -- mandatory; Lost Item/Pass are post-League optional travel.
        {"BLACKTHORN","LEAGUE",{"MYSTERY_EGG","HM_CUT","SQUIRTBOTTLE","HM_SURF","HM_STRENGTH","SECRETPOTION","HM_WHIRLPOOL","BASEMENT_KEY","CARD_KEY","HM_WATERFALL"}},
        {"LEAGUE","POST_LEAGUE"},{"POST_LEAGUE","EARLY"},
        {"POST_LEAGUE","KANTO_EAST",{"S_S_TICKET"}},
        {"KANTO_EAST","KANTO_WEST",{"MACHINE_PART"}},{"KANTO_WEST","KANTO_EAST"},
        {"KANTO_WEST","MT_SILVER"},
      },
    },
  }

  local function reqsMet(reqs,state)
    for _,id in ipairs(reqs or {}) do if not state[id] then return false end end
    return true
  end

  function L.itemStartRegion(gen,startId)
    local w=ITEM_WORLD[gen]
    if not w then return nil end
    return (w.starts and w.starts[tostring(startId or "")]) or w.default
  end

  local function itemEdgeReq(gen,startId,e)
    if gen==1 and tostring(startId or "")=="CINNABAR_ISLAND"
        and e[1]=="CINNABAR" and e[2]=="EARLY" then
      return {"HM_SURF","SECRET_KEY"}
    end
    return e[3]
  end

  -- Item ownership alone is not permission to cross an HM gate. Solve gym
  -- access, shuffled badge rewards and field moves together to reject cycles
  -- such as a Surf badge behind a Card Key that was placed beyond Surf.
  local GYMS={
    [1]={
      {"OPP_BROCK#1","BOULDERBADGE","EARLY"},
      {"OPP_MISTY#1","CASCADEBADGE","EARLY"},
      {"OPP_LT_SURGE#1","THUNDERBADGE","VERMILION",{"USE_CUT"}},
      {"OPP_ERIKA#1","RAINBOWBADGE","CELADON",{"USE_CUT"}},
      {"OPP_KOGA#1","SOULBADGE","FUCHSIA"},
      {"OPP_SABRINA#1","MARSHBADGE","SAFFRON",{"CARD_KEY"}},
      {"OPP_BLAINE#1","VOLCANOBADGE","CINNABAR",{"SECRET_KEY"}},
    },
    [2]={
      {"ZEPHYR","ZEPHYR","VIOLET"}, {"HIVE","HIVE","AZALEA"},
      {"PLAIN","PLAIN","GOLDENROD"},
      {"FOG","FOG","ECRUTEAK",{"TM_ROCK_SMASH"}},
      {"MINERAL","MINERAL","OLIVINE",{"SECRETPOTION"}},
      {"STORM","STORM","CIANWOOD",{"USE_STRENGTH"}},
      {"GLACIER","GLACIER","MAHOGANY",{"USE_SURF"}},
      {"RISING","RISING","BLACKTHORN",{"USE_SURF","USE_WHIRLPOOL"}},
    },
  }

  function L.itemWorldState(gen,startId,state)
    local w=ITEM_WORLD[gen]
    if not w then return {},{} end
    local have=Core.copy(state or {})
    local seen={[L.itemStartRegion(gen,startId)]=true}
    local proof=L.proof(gen,startId)
    local solvedChuck=false
    for _,lock in ipairs((proof and proof.badgeLocks) or {}) do
      if lock.gym=="CIANWOOD_CITY" then solvedChuck=true end
    end
    local function accessible(reqs)
      for _,id in ipairs(reqs or {}) do
        local move=id:match('^HM_(.+)')
        if not have[move and ('USE_'..move) or id] then return false end
      end
      return true
    end
    local changed=true
    while changed do
      changed=false
      local function gain(id) if not have[id] then have[id]=true;changed=true end end
      local gymCount=0
      for _,gym in ipairs(GYMS[gen] or {}) do
        local needs=gym[4]
        if gen==2 and gym[1]=='STORM' and solvedChuck then needs={} end
        if seen[gym[3]] and reqsMet(needs,have) then
          gain('GYM_'..gym[1]);gain('BADGE_'..((have._badges or {})[gym[1]] or gym[2]))
        end
        if have['GYM_'..gym[1]] then gymCount=gymCount+1 end
      end
      if gen==2 and gymCount>=7 then gain('RADIO_OPEN') end
      if gen==2 and gymCount==8 then gain('JOHTO_GYMS') end
      if gen==1 and gymCount>=7 then
        gain('ALL_GYMS')
        gain('BADGE_'..((have._badges or {})['OPP_GIOVANNI#3'] or 'EARTHBADGE'))
      end
      for move,badge in pairs(BADGE_FOR_MOVE[gen] or {}) do
        if have['HM_'..move] and have['BADGE_'..badge] then gain('USE_'..move) end
      end
      for _,e in ipairs(w.edges or {}) do
        local permitted=true
        if gen==2 and e[2]=='RADIO' then permitted=have.RADIO_OPEN end
        if gen==2 and e[2]=='LEAGUE' then permitted=have.JOHTO_GYMS end
        if gen==2 and e[1]=='RADIO' and e[2]=='BLACKTHORN' then permitted=have.USE_STRENGTH end
        if gen==1 and e[2]=='VICTORY' then permitted=have.ALL_GYMS end
        if permitted and seen[e[1]] and not seen[e[2]] and accessible(itemEdgeReq(gen,startId,e)) then
          seen[e[2]]=true;changed=true
        end
      end
    end
    return seen,have
  end

  function L.itemReachableRegions(gen,startId,state)
    return (L.itemWorldState(gen,startId,state))
  end

  function L.itemFrontierNeeds(gen,startId,state)
    local w=ITEM_WORLD[gen]; if not w then return {} end
    local seen=L.itemReachableRegions(gen,startId,state or {}); local need={}
    for _,e in ipairs(w.edges or {}) do
      if seen[e[1]] and not seen[e[2]] then
        for _,id in ipairs(itemEdgeReq(gen,startId,e) or {}) do
          if not (state or {})[id] then need[id]=true end
        end
      end
    end
    return need
  end

  function L.itemRegionReachable(gen,startId,region,state)
    if not region then return false end
    return not not L.itemReachableRegions(gen,startId,state)[region]
  end

  function L.itemCompletionReachable(gen,startId,state)
    local w=ITEM_WORLD[gen]
    return w and L.itemRegionReachable(gen,startId,w.completion,state) or false
  end

  local function mapMatch(id,p)
    return id==p or id:sub(1,#p+1)==p.."_"
  end
  local function anyMap(id,list)
    for _,p in ipairs(list) do if mapMatch(id,p) then return true end end
    return false
  end

  -- Conservative map -> progression-component mapping. Unknown/ambiguous maps
  -- are intentionally omitted from progression placement; their ordinary
  -- items are still randomized by the normal filler pass.
  function L.itemRegion(gen,mapId)
    local u=tostring(mapId or ""):upper()
    if gen==1 then
      if anyMap(u,{"VICTORY_ROAD","INDIGO_PLATEAU","ROUTE_23"}) then return "VICTORY" end
      if anyMap(u,{"POWER_PLANT"}) then return "POWER" end
      if anyMap(u,{"CINNABAR_ISLAND","CINNABAR_GYM","POKEMON_MANSION","SEAFOAM_ISLANDS","ROUTE_19","ROUTE_20","ROUTE_21"}) then return "CINNABAR" end
      if anyMap(u,{"FUCHSIA_CITY","SAFARI_ZONE","WARDENS_HOUSE","ROUTE_12","ROUTE_13","ROUTE_14","ROUTE_15"}) then return "FUCHSIA" end
      if anyMap(u,{"SAFFRON_CITY","SAFFRON_GYM","SAFFRON_MART","SILPH_CO","FIGHTING_DOJO"}) then return "SAFFRON" end
      if anyMap(u,{"ROCKET_HIDEOUT"}) then return "ROCKET" end
      if anyMap(u,{"POKEMON_TOWER","MR_FUJIS_HOUSE"}) then return "TOWER" end
      if anyMap(u,{"CELADON_CITY","CELADON_MART","GAME_CORNER","ROUTE_7","ROUTE_16_FLY_HOUSE"}) then return "CELADON" end
      if anyMap(u,{"LAVENDER_TOWN","ROUTE_8","ROUTE_10","ROCK_TUNNEL"}) then return "LAVENDER" end
      if anyMap(u,{"SS_ANNE"}) then return "SS_ANNE" end
      if u=="ROUTE_2_GATE" then return "ROUTE2_EAST" end
      if anyMap(u,{"VERMILION_CITY","POKEMON_FAN_CLUB","DIGLETTS_CAVE","ROUTE_5","ROUTE_6","ROUTE_11"}) then return "VERMILION" end
      if anyMap(u,{"PALLET_TOWN","VIRIDIAN_CITY","VIRIDIAN_FOREST","PEWTER_CITY","CERULEAN_CITY","BILLS_HOUSE","BIKE_SHOP","MT_MOON","ROUTE_1","ROUTE_3","ROUTE_4","ROUTE_24","ROUTE_25"}) then return "EARLY" end
      return nil
    end

    if anyMap(u,{"MT_SILVER","SILVER_CAVE"}) then return "MT_SILVER" end
    if anyMap(u,{"PEWTER_CITY","VIRIDIAN_CITY","PALLET_TOWN","CINNABAR_ISLAND"}) then return "KANTO_WEST" end
    if anyMap(u,{"VERMILION_CITY","POKEMON_FAN_CLUB","COPYCATS_HOUSE","SAFFRON_CITY","CERULEAN_CITY","CERULEAN_GYM","CELADON_CITY","LAVENDER_TOWN","FUCHSIA_CITY","POWER_PLANT"}) then return "KANTO_EAST" end
    if anyMap(u,{"INDIGO_PLATEAU","VICTORY_ROAD","ROUTE_26","ROUTE_27","TOHJO_FALLS"}) then return "LEAGUE" end
    if anyMap(u,{"BLACKTHORN_CITY","DRAGONS_DEN","ICE_PATH","ROUTE_44","ROUTE_45","ROUTE_46"}) then return "BLACKTHORN" end
    if anyMap(u,{"RADIO_TOWER","GOLDENROD_UNDERGROUND_WAREHOUSE"}) then return "RADIO" end
    if anyMap(u,{"MAHOGANY_TOWN","TEAM_ROCKET_BASE","LAKE_OF_RAGE","MOUNT_MORTAR","ROUTE_42","ROUTE_43"}) then return "MAHOGANY" end
    if anyMap(u,{"CIANWOOD_CITY","CIANWOOD_GYM","CIANWOOD_PHARMACY","ROUTE_40","ROUTE_41","WHIRL_ISLAND"}) then return "CIANWOOD" end
    if anyMap(u,{"OLIVINE_CITY","OLIVINE_CAFE","OLIVINE_LIGHTHOUSE","LIGHTHOUSE","ROUTE_38","ROUTE_39"}) then return "OLIVINE" end
    if anyMap(u,{"ECRUTEAK_CITY","ECRUTEAK_GYM","BURNED_TOWER","DANCE_THEATER","ROUTE_37"}) then return "ECRUTEAK" end
    if anyMap(u,{"GOLDENROD_CITY","GOLDENROD_GYM","GOLDENROD_FLOWER_SHOP","NATIONAL_PARK","ROUTE_34","ROUTE_35","ROUTE_36"}) then return "GOLDENROD" end
    if anyMap(u,{"AZALEA_TOWN","AZALEA_GYM","SLOWPOKE_WELL","ILEX_FOREST","UNION_CAVE","ROUTE_32","ROUTE_33"}) then return "AZALEA" end
    if anyMap(u,{"VIOLET_CITY","VIOLET_GYM","SPROUT_TOWER","ROUTE_31"}) then return "VIOLET" end
    if anyMap(u,{"NEW_BARK_TOWN","CHERRYGROVE_CITY","MR_POKEMONS_HOUSE","ELMS_LAB","ROUTE_29","ROUTE_30"}) then return "EARLY" end
    return nil
  end

  local function bound(n,lo,hi)
    if n<lo then return lo elseif n>hi then return hi else return n end
  end

  -- Archipelago-style monotonic sphere curves.  These are deliberately pure:
  -- they never inspect party level, which keeps Percentage mode isolated.
  function L.sphereLevel(curve,sphere,kind,generation,minLevel,maxLevel,totalSpheres)
    sphere=math.max(0,tonumber(sphere) or 0)
    minLevel=tonumber(minLevel) or 5
    maxLevel=tonumber(maxLevel) or ((generation==2) and 73 or 65)
    totalSpheres=math.max(1,tonumber(totalSpheres) or 16)
    local t=bound(sphere/totalSpheres,0,1)
    curve=tostring(curve or "VANILLA"):upper()
    local shaped=t
    if curve=="SQRT" then shaped=math.sqrt(t)
    elseif curve=="QUADRATIC" then shaped=t*t
    elseif curve=="S_CURVE" then shaped=t*t*(3-2*t)
    elseif curve=="LINEAR" then shaped=t
    else
      -- Vanilla-shaped curve: approximate the cartridge's gradual early rise,
      -- faster middle and compressed late game while remaining deterministic.
      shaped=(t<0.5) and (0.72*t) or (0.36+1.28*(t-0.5))
    end
    local base=math.floor(minLevel+(maxLevel-minLevel)*bound(shaped,0,1)+0.5)
    kind=tostring(kind or "wild")
    if kind=="trainer" then base=base+2 elseif kind=="boss" then base=base+5 end
    return bound(base,1,100)
  end

  local function mapTable(game)
    return game and game.data and (game.data.gen2Maps or game.data.maps) or {}
  end

  local function isOutside(def,gen)
    if not def then return false end
    if def.outdoor~=nil then return not not def.outdoor end
    if gen==2 then return def.environment=="TOWN" or def.environment=="ROUTE" end
    return def.tileset=="OVERWORLD" or def.tileset=="PLATEAU"
  end

  local SPECIAL_PATTERNS={
    "ELEVATOR","LIFT","HOLE","FALL","SPINNER","TELEPORT","S_S_ANNE","SS_ANNE","FAST_SHIP","S_S_AQUA","MAGNET_TRAIN",
    "HALL_OF_FAME","INDIGO_PLATEAU","SILVER_CAVE_ROOM_3","ELMS_LAB","OAKS_LAB",
  }
  local DUNGEON_PATTERNS={
    "CAVE","TUNNEL","FOREST","TOWER","MANSION","HIDEOUT","SILPH","VICTORY_ROAD","SEAFOAM","POWER_PLANT",
    "MT_MOON","ROCK_TUNNEL","ROCKET_BASE","ICE_PATH","WHIRL_ISLAND","DRAGONS_DEN","SLOWPOKE_WELL","RUINS_OF_ALPH","MOUNT_MORTAR",
  }

  local function hasPattern(id,list)
    id=tostring(id or ""):upper()
    for _,p in ipairs(list) do if id:find(p,1,true) then return true end end
    return false
  end

  function L.classifyDoor(maps,gen,mapId,warpIndex)
    local m=maps and maps[mapId]
    local w=m and m.warps and m.warps[warpIndex]
    if not m or not w then return nil end
    local dm=tostring(w.destMap or w.mapId or w.map or "")
    local d=maps[dm]
    if dm=="" or not d then return nil end
    if hasPattern(mapId,SPECIAL_PATTERNS) or hasPattern(dm,SPECIAL_PATTERNS) then return "special" end
    local outA,outB=isOutside(m,gen),isOutside(d,gen)
    if outA~=outB then
      if hasPattern(mapId,DUNGEON_PATTERNS) or hasPattern(dm,DUNGEON_PATTERNS) then return "dungeon" end
      return "building"
    end
    if hasPattern(mapId,DUNGEON_PATTERNS) and hasPattern(dm,DUNGEON_PATTERNS) then return "dungeon_internal" end
    return "internal"
  end

  local function endpointKey(e) return tostring(e.map).."#"..tostring(e.index) end

  local SAFE_CRITICAL_PATTERNS={
    "GYM","OAKS_LAB","ELMS_LAB","SILPH_CO","ROCKET_HIDEOUT","TEAM_ROCKET_BASE",
    "SLOWPOKE_WELL","ILEX_FOREST","BURNED_TOWER","OLIVINE_LIGHTHOUSE","ICE_PATH",
    "DRAGONS_DEN","VICTORY_ROAD","POKEMON_MANSION","POWER_PLANT","RADIO_TOWER",
    "POKECENTER","HALL_OF_FAME","ELITE_FOUR",
    "BILL","SEA_COTTAGE","WARDEN","MR_POKEMON","KURT","DANCE_THEATER",
    "PHARMACY","FLOWER_SHOP","OLIVINE_CAFE","GOLDENROD_UNDERGROUND_WAREHOUSE",
    "SAFARI_ZONE","DAYCARE","DAY_CARE",
    -- Global progression doors that can create item/entrance cycles if moved
    -- without a complete item-placement solver.  Keep SAFE modes conservative;
    -- CHAOS still allows the broad shuffle where mechanically unambiguous.
    "POKEMON_TOWER","CELADON_MART","CELADON_DEPT_STORE","DEPT_STORE",
  }

  -- Check-level progression eligibility for ordinary field pickups. Region
  -- reachability alone is not sufficient: most field checks can sit behind
  -- local Cut/Surf/Card Key/Whirlpool/Strength gates. Keep this whitelist
  -- intentionally tiny and only add checks whose exact physical pickup has
  -- been audited. Cinnabar needs two local checks (Surf + Secret Key); the
  -- Mansion 1F Carbos ball is the second audited pre-gate check.
  function L.itemExtraProgressionSafe(gen,mapId,itemId)
    gen=tonumber(gen) or 0
    mapId=tostring(mapId or ""):upper(); itemId=tostring(itemId or ""):upper()
    return gen==1 and mapId=="POKEMON_MANSION_1F" and itemId=="CARBOS"
  end

  function L.itemLocationDoorStable(game,gen,mapId,mode,startId)
    mode=tostring(mode or "OFF")
    if mode=="OFF" or mode=="CHAOS" then return true end
    local maps=mapTable(game); local m=maps[tostring(mapId or "")]
    if not m then return false end
    if isOutside(m,gen) then return true end
    if hasPattern(mapId,SAFE_CRITICAL_PATTERNS) then return true end
    local p=L.START_POLICIES[gen] and L.START_POLICIES[gen][tostring(startId or "")]
    for _,id in ipairs(p or {}) do
      if tostring(mapId)==id or tostring(mapId):find(id,1,true)==1 then return true end
    end
    return false
  end

  local function startCritical(gen,startId,a,b)
    if not startId or startId=="" then return false end
    local policy=L.START_POLICIES[gen] and L.START_POLICIES[gen][tostring(startId)] or nil
    if not policy then return false end
    local function matches(id)
      id=tostring(id or "")
      -- Every authored proof objective is progression-critical for this start,
      -- not only the first one.  A later door (Diglett's Cave, Dance Theater,
      -- etc.) can be just as necessary to escape the starting component.
      for i=1,#policy do local p=policy[i]; if id==p or id:find(p,1,true)==1 then return true end end
      return false
    end
    return (tostring(a)==tostring(startId) and matches(b)) or (tostring(b)==tostring(startId) and matches(a))
  end

  local function acceptPortal(mode,category)
    if mode=="CHAOS" then return category=="building" or category=="dungeon" end
    if mode=="BUILDINGS" then return category=="building" end
    if mode=="FULL_LOGIC" then return category=="building" or category=="dungeon" end
    return false
  end

  -- A door is a *portal*, not an individual warp tile.  Gen 1 usually has
  -- one exterior warp and two LAST_MAP exit tiles; Gen 2 commonly has two
  -- exterior tiles and two reciprocal interior tiles.  Treating each tile as
  -- an independent entrance can split a double door in half, so collect the
  -- whole outside<->inside portal and shuffle those records instead.
  local function indoorComponents(maps,gen)
    local compOf,components={},{}
    local nextId=0
    for mapId,m in pairs(maps or {}) do
      if not isOutside(m,gen) and not compOf[mapId] then
        nextId=nextId+1
        local q={mapId}; compOf[mapId]=nextId; local qi=1
        while qi<=#q do
          local cur=q[qi]; qi=qi+1
          local cm=maps[cur]
          for _,w in ipairs((cm and cm.warps) or {}) do
            local dm=tostring(w.destMap or w.mapId or w.map or "")
            local d=maps[dm]
            if d and not isOutside(d,gen) and not compOf[dm] then
              compOf[dm]=nextId; q[#q+1]=dm
            end
          end
        end
        components[nextId]=q
      end
    end
    return compOf,components
  end

  local function adjacentWarpCells(a,b)
    local ax,ay=tonumber(a and a.x),tonumber(a and a.y)
    local bx,by=tonumber(b and b.x),tonumber(b and b.y)
    if not ax or not ay or not bx or not by then return false end
    return math.max(math.abs(ax-bx),math.abs(ay-by))<=1
  end

  -- Build physical doorway portals before applying any mode/safety filter.
  -- A map pair is not a portal identity: several maps (Cerulean Badge House,
  -- Celadon Dept. Store, route gatehouses, etc.) have two *different* doors
  -- between the same outside and inside maps.  Conversely a double door may
  -- use two adjacent exterior tiles and one or two adjacent interior mats.
  -- Group only geometrically adjacent source/landing atoms.
  local function physicalPortals(maps,gen)
    local buckets={}
    for mapId,m in pairs(maps or {}) do
      if isOutside(m,gen) then
        for idx,w in ipairs((m and m.warps) or {}) do
          local dm=tostring(w.destMap or w.mapId or w.map or "")
          local d=maps[dm]
          if d and not isOutside(d,gen) then
            local category=L.classifyDoor(maps,gen,mapId,idx)
            if category=="building" or category=="dungeon" then
              local di=tonumber(w.destWarp or w.warp or w.destWarpIndex)
              local landing=d.warps and di and d.warps[di]
              if landing then
                local key=tostring(mapId)..">"..dm
                buckets[key]=buckets[key] or {}
                buckets[key][#buckets[key]+1]={
                  outsideMap=mapId,insideMap=dm,category=category,
                  source={map=mapId,index=idx,warp=w},
                  landing={map=dm,index=di,warp=landing},
                }
              end
            end
          end
        end
      end
    end

    local portals={}
    for _,atoms in pairs(buckets) do
      local parent={}; for i=1,#atoms do parent[i]=i end
      local function find(i)
        while parent[i]~=i do parent[i]=parent[parent[i]]; i=parent[i] end
        return i
      end
      local function union(a,b)
        a,b=find(a),find(b); if a~=b then parent[b]=a end
      end
      for i=1,#atoms do
        for j=i+1,#atoms do
          local ai,aj=atoms[i],atoms[j]
          local sameLanding=ai.landing.index==aj.landing.index
          if adjacentWarpCells(ai.source.warp,aj.source.warp)
              and (sameLanding or adjacentWarpCells(ai.landing.warp,aj.landing.warp)) then
            union(i,j)
          end
        end
      end
      local comps={}
      for i,a in ipairs(atoms) do
        local r=find(i); comps[r]=comps[r] or {}; comps[r][#comps[r]+1]=a
      end
      for _,group in pairs(comps) do
        table.sort(group,function(a,b) return a.source.index<b.source.index end)
        local first=group[1]
        local r={
          outsideMap=first.outsideMap,insideMap=first.insideMap,category=first.category,
          sourceEndpoints={},landings={},sourceIndexSet={},reverseEndpoints={}
        }
        local ids={}
        for _,a in ipairs(group) do
          r.sourceEndpoints[#r.sourceEndpoints+1]=a.source
          r.landings[#r.landings+1]=a.landing
          r.sourceIndexSet[a.source.index]=true
          ids[#ids+1]=tostring(a.source.index)
        end
        r.id=tostring(r.outsideMap)..">"..tostring(r.insideMap).."#"..table.concat(ids,"+")
        portals[#portals+1]=r
      end
    end
    table.sort(portals,function(a,b) return a.id<b.id end)
    return portals
  end

  local function componentExteriorCounts(portals,compOf)
    local counts={}
    for _,r in ipairs(portals or {}) do
      local cid=compOf[r.insideMap]
      if cid then counts[cid]=(counts[cid] or 0)+1 end
    end
    return counts
  end

  local function collectPortals(maps,gen,mode,startId)
    local protected=0
    local compOf=indoorComponents(maps,gen)
    local allPortals=physicalPortals(maps,gen)
    local exteriorCounts=componentExteriorCounts(allPortals,compOf)
    local candidates={}

    for _,r in ipairs(allPortals) do
      if acceptPortal(mode,r.category) then
        local safe=(mode~="CHAOS")
        local cid=compOf[r.insideMap]
        local transit=(cid and (tonumber(exteriorCounts[cid]) or 0)>1) or false
        local blocked=safe and (transit
          or hasPattern(r.outsideMap,SAFE_CRITICAL_PATTERNS)
          or hasPattern(r.insideMap,SAFE_CRITICAL_PATTERNS)
          or startCritical(gen,startId,r.outsideMap,r.insideMap))
        if blocked then
          protected=protected+1
        else
          local inside=maps[r.insideMap]
          r.reverseEndpoints={}
          for idx,w in ipairs((inside and inside.warps) or {}) do
            local back=tostring(w.destMap or w.mapId or w.map or "")
            local bi=tonumber(w.destWarp or w.warp or w.destWarpIndex)
            local matches=false
            if gen==1 then
              matches=((back=="LAST_MAP" and bi and r.sourceIndexSet[bi])
                or (back==tostring(r.outsideMap) and (not bi or r.sourceIndexSet[bi])))
            else
              matches=(back==tostring(r.outsideMap) and (not bi or r.sourceIndexSet[bi]))
            end
            if matches then r.reverseEndpoints[#r.reverseEndpoints+1]={map=r.insideMap,index=idx,warp=w} end
          end

          -- Safe/coupled shuffle requires a real return path for every landing.
          local reverseSet={}
          for _,e in ipairs(r.reverseEndpoints) do reverseSet[e.warp]=true end
          local reversible=#r.sourceEndpoints>0 and #r.reverseEndpoints>0
          for _,e in ipairs(r.landings) do if not reverseSet[e.warp] then reversible=false; break end end
          if reversible then
            table.sort(r.sourceEndpoints,function(a,b) return a.index<b.index end)
            table.sort(r.landings,function(a,b) return a.index<b.index end)
            table.sort(r.reverseEndpoints,function(a,b) return a.index<b.index end)
            candidates[#candidates+1]=r
          else
            protected=protected+1
          end
        end
      end
    end

    -- A few gatehouses/transit rooms expose one interior exit warp through
    -- more than one exterior portal.  Such a warp cannot simultaneously be
    -- the reciprocal half of two shuffled entrances.  Never create an
    -- ambiguous runtime mapping: protect these portals even in CHAOS.  CHAOS
    -- may be logically unbeatable, but it must still be mechanically sound.
    local owner,ambiguous={},{}
    local function claim(r,e)
      local prev=owner[e.warp]
      if prev and prev~=r then ambiguous[prev]=true; ambiguous[r]=true else owner[e.warp]=r end
    end
    for _,r in ipairs(candidates) do
      local seen={}
      for _,e in ipairs(r.landings) do if not seen[e.warp] then claim(r,e); seen[e.warp]=true end end
      for _,e in ipairs(r.reverseEndpoints) do if not seen[e.warp] then claim(r,e); seen[e.warp]=true end end
    end
    local portals={}
    for _,r in ipairs(candidates) do
      if ambiguous[r] then protected=protected+1 else portals[#portals+1]=r end
    end
    table.sort(portals,function(a,b) return a.id<b.id end)
    return portals,protected
  end

  local function sattolo(Core,rng,list)
    -- One-cycle derangement: no shuffled portal maps back to itself when the
    -- pool has at least two entries.
    for i=#list,2,-1 do
      local j=rng:int(1,i-1)
      list[i],list[j]=list[j],list[i]
    end
  end

  function L.buildDoorPlan(game,cfg,seed,gen,startId)
    local mode=tostring(cfg and cfg.random_doors or "OFF")
    if mode=="OFF" then return {mode=mode,byWarp={},pairs={},eligible=0,protected=0} end
    local maps=mapTable(game)
    local portals,protected=collectPortals(maps,gen,mode,startId)
    local groups={}
    for _,portal in ipairs(portals) do
      local g=(mode=="CHAOS") and "all" or portal.category
      groups[g]=groups[g] or {}
      groups[g][#groups[g]+1]=portal
    end
    local plan={mode=mode,byWarp={},byEndpoint={},pairs={},eligible=#portals,protected=protected,portals={},mappingCollisions={}}
    for _,g in ipairs(Core.sortedKeys(groups)) do
      local srcs=groups[g]
      table.sort(srcs,function(a,b) return a.id<b.id end)
      if #srcs>1 then
        local targets={}
        for i,p in ipairs(srcs) do targets[i]=p end
        local rng=Core.rng(Core.hash("door-rando|"..tostring(g),seed))
        sattolo(Core,rng,targets)
        for i,src in ipairs(srcs) do
          local dst=targets[i]
          local record={from=src.id,to=dst.id,category=src.category,pairs={},reversePairs={}}
          -- Exterior/source tiles enter the destination portal's interior.
          for j,se in ipairs(src.sourceEndpoints) do
            local de=dst.landings[((j-1)%#dst.landings)+1]
            local sk,dk=endpointKey(se),endpointKey(de)
            local mapping={map=de.map,x=de.warp.x,y=de.warp.y,
              source=sk,target=dk,category=src.category}
            if plan.byEndpoint[sk] and plan.byEndpoint[sk].target~=dk then
              plan.mappingCollisions[#plan.mappingCollisions+1]=sk
            end
            plan.byWarp[se.warp]=mapping
            plan.byEndpoint[sk]=mapping
            plan.pairs[#plan.pairs+1]={from=sk,to=dk,
              reverseFrom=dk,reverseTo=sk,category=src.category}
            record.pairs[#record.pairs+1]={from=sk,to=dk}
          end
          -- Every exit tile in the destination portal returns to this source
          -- doorway.  This is essential for Gen 1's paired LAST_MAP mats.
          for j,re in ipairs(dst.reverseEndpoints) do
            local se=src.sourceEndpoints[((j-1)%#src.sourceEndpoints)+1]
            local rk,sk=endpointKey(re),endpointKey(se)
            local mapping={map=se.map,x=se.warp.x,y=se.warp.y,
              source=rk,target=sk,category=src.category}
            if plan.byEndpoint[rk] and plan.byEndpoint[rk].target~=sk then
              plan.mappingCollisions[#plan.mappingCollisions+1]=rk
            end
            plan.byWarp[re.warp]=mapping
            plan.byEndpoint[rk]=mapping
            record.reversePairs[#record.reversePairs+1]={from=rk,to=sk}
          end
          plan.portals[#plan.portals+1]=record
        end
      end
    end
    return plan
  end

  function L.auditDoorPlan(plan)
    if not plan then return false,{"missing door plan"} end
    local errs={}
    if #(plan.mappingCollisions or {})>0 then
      errs[#errs+1]="door endpoint collision: "..tostring(plan.mappingCollisions[1])
    end
    local seenFrom={}
    for _,p in ipairs(plan.pairs or {}) do
      if not p.from or not p.to then
        errs[#errs+1]="incomplete forward pair"
      else
        local f=plan.byEndpoint and plan.byEndpoint[p.from]
        if not f or f.target~=p.to then errs[#errs+1]="missing forward mapping "..tostring(p.from) end
        if seenFrom[p.from] and seenFrom[p.from]~=p.to then errs[#errs+1]="ambiguous source "..tostring(p.from) end
        seenFrom[p.from]=p.to
      end
    end
    for _,rec in ipairs(plan.portals or {}) do
      if not rec.from or not rec.to or rec.from==rec.to then errs[#errs+1]="invalid portal assignment" end
      if #(rec.pairs or {})==0 or #(rec.reversePairs or {})==0 then
        errs[#errs+1]="uncoupled portal "..tostring(rec.from)
      else
        -- Coupling is a portal invariant, not a tile invariant.  Gen 1 often
        -- has two outside mat tiles feeding one interior LAST_MAP exit, so the
        -- unique interior exit may return to either tile of the same doorway.
        local sourceSet,destSet={},{}
        for _,fp in ipairs(rec.pairs or {}) do sourceSet[fp.from]=true; destSet[fp.to]=true end
        for dk in pairs(destSet) do
          local r=plan.byEndpoint and plan.byEndpoint[dk]
          if not r or not sourceSet[r.target] then errs[#errs+1]="destination leaves wrong portal "..tostring(dk) end
        end
        for _,rp in ipairs(rec.reversePairs or {}) do
          local r=plan.byEndpoint and plan.byEndpoint[rp.from]
          if not r or r.target~=rp.to or not sourceSet[rp.to] then
            errs[#errs+1]="bad portal return "..tostring(rp.from)
          end
        end
      end
    end
    return #errs==0,errs
  end

  function L.auditStatic()
    local errs={}
    for gen,starts in pairs(L.STARTS) do
      local seen={}
      for _,s in ipairs(starts) do
        if seen[s] then errs[#errs+1]="duplicate start "..s end
        seen[s]=true
        if not L.START_POLICIES[gen][s] then errs[#errs+1]="missing start policy "..s end
        if not L.START_PROOFS[gen][s] then errs[#errs+1]="missing start proof "..s end
      end
    end
    if L.preferredRank(1,"CINNABAR_ISLAND","CINNABAR_ISLAND","POKEMON_MANSION_1F")~=1 then errs[#errs+1]="Cinnabar policy" end
    if not L.edgeRequirement(1,"CINNABAR_ISLAND","ROUTE_21") then errs[#errs+1]="Cinnabar Surf edge" end
    if not L.edgeRequirement(2,"CIANWOOD_CITY","ROUTE_41") then errs[#errs+1]="Cianwood Surf edge" end
    return #errs==0,errs
  end

  return L
end
