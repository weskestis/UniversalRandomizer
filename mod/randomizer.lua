return function(mod, Core, Adapters, ItemLogic, Logic)
  local R = {}
  local Runtime = {
    snapshots = setmetatable({}, { __mode = "k" }),
    active = nil,
    bridgeGames = setmetatable({}, { __mode = "k" }),
    gen1BridgesInstalled = false,
    gen2BridgesInstalled = false,
    allSpeciesCache = setmetatable({}, { __mode = "k" }),
    selectedSpeciesCache = setmetatable({}, { __mode = "k" }),
    eligibleSpeciesCache = setmetatable({}, { __mode = "k" }),
  }

  local LEGENDARIES = {
    ARTICUNO=true, ZAPDOS=true, MOLTRES=true, MEWTWO=true, MEW=true,
    RAIKOU=true, ENTEI=true, SUICUNE=true, LUGIA=true, HO_OH=true, CELEBI=true,
    ["HO-OH"]=true,
  }
  local KEY_ITEMS = {
    OAKS_PARCEL=true, POKE_FLUTE=true, SECRET_KEY=true, BIKE_VOUCHER=true,
    BICYCLE=true, CARD_KEY=true, LIFT_KEY=true, SILPH_SCOPE=true,
    GOLD_TEETH=true, COIN_CASE=true, ITEMFINDER=true, EXP_ALL=true,
    S_S_TICKET=true, TOWN_MAP=true,
    MYSTERY_EGG=true, RED_SCALE=true, SQUIRTBOTTLE=true, SECRETPOTION=true, BASEMENT_KEY=true,
    MACHINE_PART=true, LOST_ITEM=true, PASS=true, CLEAR_BELL=true,
    RAINBOW_WING=true, SILVER_WING=true, S_S_AQUA_TICKET=true,
  }
  local BAD_STARTER_MOVES = { SELFDESTRUCT=true, EXPLOSION=true, SPLASH=true, TELEPORT=true, DREAM_EATER=true, SNORE=true }

  -- UPR-ZX required field-TM guarantees.  RANDOM field-item mode must keep
  -- these TM numbers obtainable in the overworld so a seed cannot erase a
  -- progression-sensitive machine merely because all field TMs were rerolled.
  local REQUIRED_FIELD_TMS = {
    [1] = { 3,4,8,10,12,14,16,19,20,22,25,26,30,40,43,44,45,47 },
    [2] = { 4,20,22,26,28,34,35,39,40,43,44,46 },
  }

  -- Gen 1 Game Corner prize windows. The engine's hand-ported counter builds
  -- its labels from these native source species in a Lua closure, so there is
  -- no ordinary script.command row to rewrite. A small Gen1-only bridge below
  -- keeps those labels/confirmation names synchronized with the same gift pick.
  local G1_PRIZE_WINDOWS = {
    red = {
      { {"ABRA",9},{"CLEFAIRY",8},{"NIDORINA",17} },
      { {"DRATINI",18},{"SCYTHER",25},{"PORYGON",26} },
    },
    blue = {
      { {"ABRA",6},{"CLEFAIRY",12},{"NIDORINO",17} },
      { {"PINSIR",20},{"DRATINI",24},{"PORYGON",18} },
    },
    yellow = {
      { {"ABRA",15},{"VULPIX",18},{"WIGGLYTUFF",22} },
      { {"SCYTHER",30},{"PINSIR",30},{"PORYGON",26} },
    },
  }

  -- Gen 2 Game Corner prize Pokemon are ordinary givepoke script commands, but
  -- their menus and confirmation text carry the source species separately.
  -- Keep all three representations on one deterministic pick so the player
  -- never selects "ABRA" and receives something else.  Silver differs only
  -- in Goldenrod's middle prize (Sandshrew instead of Ekans).
  local G2_PRIZE_LEVELS = {
    GOLDENROD_GAME_CORNER = { ABRA=10, EKANS=10, SANDSHREW=10, DRATINI=10 },
    CELADON_GAME_CORNER_PRIZE_ROOM = { MR__MIME=15, EEVEE=15, PORYGON=20 },
  }

  -- Yellow's Cerulean Bulbasaur has a separate pet cry byte in the original
  -- ROM. UPR-ZX patches it together with the gift species; keep the runtime
  -- pet cry on that exact same deterministic gift mapping.
  local G1_GIFT_CRY_LEVELS = {
    CERULEAN_MELANIES_HOUSE = { BULBASAUR=10 },
  }

  local RANDOM_START_LOGIC, RANDOM_START_CHAOS
  local applyBadgeRewards, restoreGen1BadgeRewards
  local applyRandomStartRespawn

  local function versionId(game)
    local ok, GV = pcall(require, "src.core.GameVersion")
    if ok and GV and GV.get then return GV.get() end
    if game and game.data and game.data.gen2Encounters then return "gold" end
    return "red"
  end

  local function generation(game)
    local id = versionId(game)
    local a = Adapters[id]
    if a then return a.generation end
    local ok, GV = pcall(require, "src.core.GameVersion")
    if ok and GV and GV.generation then return GV.generation(id) end
    return (game and game.data and game.data.gen2Encounters) and 2 or 1
  end

  local DEFAULTS = {
    safety = "SAFE",
    ruleset = "GEN1",
    pokedex = "NATIVE",
    bst_match = false,
    bst_difference = 50,
    base_stats = "UNCHANGED",
    types = "UNCHANGED",
    evolutions = "UNCHANGED",
    impossible_evos = false,
    starters = "RANDOM",
    rival_starter = true,
    movesets = "UNCHANGED",
    trainers = "RANDOM",
    -- Legacy wild field remains for save migration only; new runs use area_encounters.
    wild = "RANDOM",
    area_encounters = "HIGH_VARIETY",
    wild_randomness = "BALANCED",
    wild_evolution = "AS_ROLLED",
    extra_species = 3,
    statics = "RANDOM",
    tms = "UNCHANGED",
    tm_compat = "UNCHANGED",
    field_items = "UNCHANGED",
    gift_items = "UNCHANGED",
    progression_items = true,
    pc_item = false,
    marts = "VANILLA",
    mart_safety = true,
    protection_guards = false,
    random_doors = "OFF",
    sphere_curve = "VANILLA",
    random_start = "OFF",
    start_logic = "RESTORED",
    badges = "VANILLA",
    trades = "UNCHANGED",
    level_mode = "PERCENTAGE",
    trainer_levels = 0,
    boss_levels = 0,
    wild_levels = 0,
    trainer_ai = "NORMAL",
    boss_ai = "NORMAL",
    allow_legendaries = false,
    seed_mode = "AUTO",
    manual_seed = 1,
  }

  local ALLOWED = {
    safety = { SAFE=true, CHAOS=true },
    base_stats = { UNCHANGED=true, SHUFFLE=true, RANDOM=true },
    types = { UNCHANGED=true, FOLLOW_EVOS=true, RANDOM=true },
    evolutions = { UNCHANGED=true, RANDOM=true },
    starters = { UNCHANGED=true, RANDOM=true, TWO_EVOS=true },
    movesets = { UNCHANGED=true, TYPE_BIAS=true, RANDOM=true },
    trainers = { UNCHANGED=true, RANDOM=true, SIMILAR=true, TYPE_THEMED=true },
    wild = { UNCHANGED=true, RANDOM=true, SIMILAR=true },
    wild_randomness = { BALANCED=true, UNRESTRICTED=true, LEGACY=true },
    wild_evolution = { AS_ROLLED=true, LEVEL=true },
    area_encounters = { VANILLA=true, HIGH_VARIETY=true, AREA_POOL=true, CHAOS_POOL=true, FULL_SLOT_RANDOM=true },
    statics = { UNCHANGED=true, RANDOM=true, SIMILAR=true },
    tms = { UNCHANGED=true, RANDOM=true },
    tm_compat = { UNCHANGED=true, TYPE_BIAS=true, RANDOM=true, FULL=true },
    field_items = { UNCHANGED=true, SHUFFLE=true, RANDOM=true, LOGIC_RANDOM=true, CHAOS=true },
    gift_items = { UNCHANGED=true, RANDOM=true },
    marts = { VANILLA=true, SAFE=true, CHAOS=true },
    random_start = { OFF=true, LOGIC=true, CHAOS=true },
    start_logic = { RESTORED=true, LEGACY=true },
    random_doors = { OFF=true, BUILDINGS=true, FULL_LOGIC=true, CHAOS=true },
    sphere_curve = { VANILLA=true, LINEAR=true, SQRT=true, QUADRATIC=true, S_CURVE=true },
    badges = { VANILLA=true, SAFE=true, CHAOS=true },
    trainer_ai = { NORMAL=true, STRONG=true },
    boss_ai = { NORMAL=true, STRONG=true },
    trades = { UNCHANGED=true, GIVEN=true, BOTH=true },
    level_mode = { PROGRESSION=true, PERCENTAGE=true, HYBRID=true },
    seed_mode = { AUTO=true, MANUAL=true },
  }

  function R.defaults(game)
    return R.normalizedConfig(nil,game)
  end

  function R.normalizedConfig(input,game)
    local out=Core.copy(DEFAULTS)
    if type(input)=="table" then
      for k,v in pairs(input) do if out[k]~=nil then out[k]=Core.copy(v) end end
      -- 1.3.0 and earlier exposed WILDS instead of the richer area model.
      -- Preserve the old intent on migrated saves while new runs default to
      -- HIGH VARIETY +3.
      if input.area_encounters==nil and input.wild~=nil then
        if input.wild=="UNCHANGED" then out.area_encounters="VANILLA"
        elseif input.wild=="SIMILAR" then out.area_encounters="HIGH_VARIETY"
        else out.area_encounters="FULL_SLOT_RANDOM" end
        out.extra_species=0
      end
    end
    -- New controls must not silently alter an existing run.
    if type(input)=="table" and input.progression_items==nil then out.progression_items=false end
    if type(input)=="table" and input.mart_safety==nil then out.mart_safety=false end
    out.ruleset=generation(game or mod.game)==2 and "GEN2" or "GEN1"
    out.pokedex="NATIVE"
    -- Saved encounter tables retain the policy that created them. New setup
    -- screens promote LEGACY to an explicit player-facing choice.
    if type(input)=="table" and input.wild_randomness==nil then out.wild_randomness="LEGACY" end
    if type(input)=="table" and input.wild_evolution==nil then out.wild_evolution="LEVEL" end
    if out.wild_randomness=="UNRESTRICTED" then out.wild_evolution="AS_ROLLED" end
    out.bst_difference=math.max(0,math.min(500,math.floor(tonumber(out.bst_difference) or 50)))
    if out.field_items=="VANILLA" then out.field_items="UNCHANGED" end
    out.extra_species=math.max(0,math.min(5,math.floor(tonumber(out.extra_species) or 0)))
    -- 2.0.0: one deterministic level policy.  The logic graph/native tables
    -- establish the baseline and the three category modifiers are applied
    -- afterward.  Party level never participates.  Keep the legacy fields in
    -- saved config only as fixed migration sentinels so older saves/loaders do
    -- not break when upgrading into 2.0.0.
    out.level_mode="PERCENTAGE"
    out.sphere_curve="VANILLA"
    out.protection_guards=false
    if out.random_start=="LOGIC" and out.start_logic~="LEGACY" then
      out.field_items="LOGIC_RANDOM"; out.progression_items=true
    end
    if out.field_items=="LOGIC_RANDOM" or out.field_items=="CHAOS" then
      out.field_items=out.safety=="CHAOS" and "CHAOS" or "LOGIC_RANDOM"
      out.progression_items=true
    end
    out.trainer_levels=math.max(-50,math.min(50,math.floor(tonumber(out.trainer_levels) or 0)))
    -- 1.3.8: bosses have their own level percentage. Old saves did not carry
    -- boss_levels, so inherit their trainer modifier to preserve 1.3.7 behavior.
    if type(input)=="table" and input.boss_levels==nil then out.boss_levels=out.trainer_levels end
    out.boss_levels=math.max(-50,math.min(50,math.floor(tonumber(out.boss_levels) or 0)))
    out.wild_levels=math.max(-50,math.min(50,math.floor(tonumber(out.wild_levels) or 0)))
    return out
  end

  local function isSpeciesDef(def)
    return type(def) == "table" and type(def.baseStats) == "table"
  end

  local function nativeDexCap(game) return generation(game)==2 and 251 or 151 end
  local function pokedexCap(game) return nativeDexCap(game) end
  function R.pokedexCap(game) return nativeDexCap(game) end
  function R.availablePokedexModes() return {"NATIVE"} end

  local function allSpecies(game)
    local data=game and game.data
    if not data then return {} end
    local cached=Runtime.allSpeciesCache[data]
    if cached then return cached end
    local rows={}
    for id,def in pairs(data.pokemon or {}) do
      if isSpeciesDef(def) and not tostring(id):match("^MISSINGNO") and not tostring(id):match("^UNUSED")
         and not tostring(id):match("FOSSIL") and id~="MON_GHOST" then rows[#rows+1]=id end
    end
    table.sort(rows,function(a,b)
      local da=tonumber(data.pokemon[a].dex) or 9999; local db=tonumber(data.pokemon[b].dex) or 9999
      if da~=db then return da<db end; return a<b
    end)
    Runtime.allSpeciesCache[data]=rows
    return rows
  end

  local function selectedSpecies(game,cfg)
    local data=game and game.data
    if not data then return {} end
    local cap=pokedexCap(game,cfg)
    local byCap=Runtime.selectedSpeciesCache[data]
    if not byCap then byCap={}; Runtime.selectedSpeciesCache[data]=byCap end
    if byCap[cap] then return byCap[cap] end
    local rows={}
    for _,id in ipairs(allSpecies(game)) do
      local d=data.pokemon[id]
      local dex=d and tonumber(d.dex)
      if dex and dex>=1 and dex<=cap then rows[#rows+1]=id end
    end
    byCap[cap]=rows
    return rows
  end

  local function eligibleSpecies(game, cfg)
    local data=game and game.data
    if not data then return {} end
    local cap=pokedexCap(game,cfg)
    local key=tostring(cap).."|"..tostring(not not cfg.allow_legendaries)
    local cache=Runtime.eligibleSpeciesCache[data]
    if not cache then cache={}; Runtime.eligibleSpeciesCache[data]=cache end
    if cache[key] then return cache[key] end
    local rows = {}
    for _,id in ipairs(selectedSpecies(game,cfg)) do
      if cfg.allow_legendaries or not LEGENDARIES[id] then rows[#rows+1]=id end
    end
    cache[key]=rows
    return rows
  end

  function R.poolSize(game,cfg) return #eligibleSpecies(game,R.normalizedConfig(cfg,game)) end

  local function movePool(game, damagingOnly)
    local out = {}
    for id, def in pairs((game.data and game.data.moves) or {}) do
      local index=type(def)=="table" and tonumber(def.index)
      if type(def) == "table" and id ~= "STRUGGLE"
          and index and index>=1 and index<=(generation(game)==2 and 251 or 165) then
        local power = tonumber(def.power) or 0
        if not damagingOnly or (power > 0 and not BAD_STARTER_MOVES[id]) then
          out[#out + 1] = id
        end
      end
    end
    table.sort(out)
    return out
  end

  local function typePool(game)
    local seen, out = {}, {}
    for _, def in pairs((game.data and game.data.pokemon) or {}) do
      for _, t in ipairs(type(def) == "table" and def.types or {}) do
        local nativeType=({NORMAL=true,FIGHTING=true,FLYING=true,POISON=true,GROUND=true,ROCK=true,BUG=true,GHOST=true,FIRE=true,WATER=true,GRASS=true,ELECTRIC=true,PSYCHIC=true,PSYCHIC_TYPE=true,ICE=true,DRAGON=true})[t]
          or (generation(game)==2 and (t=="STEEL" or t=="DARK"))
        if nativeType and not seen[t] then
          seen[t] = true; out[#out + 1] = t
        end
      end
    end
    table.sort(out)
    return out
  end

  local function captureMapMutationFields(data)
    local out={}
    local function captureMaps(maps)
      for _,map in pairs(maps or {}) do
        if type(map)=="table" then
          for _,obj in ipairs(map.objects or {}) do
            if obj.item~=nil then out[#out+1]={parent=obj,field="item",value=Core.copy(obj.item)} end
            if obj.pokemon~=nil then out[#out+1]={parent=obj,field="pokemon",value=Core.copy(obj.pokemon)} end
            if type(obj.itemball)=="table" and obj.itemball.item~=nil then
              out[#out+1]={parent=obj.itemball,field="item",value=Core.copy(obj.itemball.item)}
            end
          end
          for _,ev in ipairs(map.bgEvents or {}) do
            if type(ev.hiddenItem)=="table" and ev.hiddenItem.item~=nil then
              out[#out+1]={parent=ev.hiddenItem,field="item",value=Core.copy(ev.hiddenItem.item)}
            end
          end
        end
      end
    end
    captureMaps(data and data.maps)
    captureMaps(data and data.gen2Maps)
    return out
  end

  local function restoreMapMutationFields(rows)
    for _,row in ipairs(rows or {}) do row.parent[row.field]=Core.copy(row.value) end
  end

  -- Seed validation used to deep-copy the entire expanded Pokemon registry on
  -- every retry. With 493 species that creates a large burst of short-lived
  -- tables on mobile and can push Android over its memory limit while the
  -- setup screen is validating. Snapshot only fields the randomizer can
  -- mutate; sprite/icon/dex metadata and other immutable content stays in
  -- place.
  local POKEMON_MUTATION_FIELDS = {
    "baseStats", "types", "evolutions", "level1Moves", "learnset",
    "levelMoves", "tmhm",
  }

  local function capturePokemonMutationFields(rows)
    local out={}
    for id,def in pairs(rows or {}) do
      if type(def)=="table" then
        local rec={}
        for _,field in ipairs(POKEMON_MUTATION_FIELDS) do
          rec[field]={present=def[field]~=nil,value=Core.copy(def[field])}
        end
        out[id]=rec
      end
    end
    return out
  end

  local function restorePokemonMutationFields(rows,snapshot)
    for id,rec in pairs(snapshot or {}) do
      local def=rows and rows[id]
      if type(def)=="table" then
        for _,field in ipairs(POKEMON_MUTATION_FIELDS) do
          local saved=rec[field]
          if saved and saved.present then def[field]=Core.copy(saved.value) else def[field]=nil end
        end
      end
    end
  end

  -- Snapshot the rest of the mutable registries by reference + field value as
  -- well.  Earlier WIP builds still deep-copied all items/field/text/mart data
  -- on every candidate seed.  On Gold that includes large imported script and
  -- map-adjacent tables, which is unnecessary and was the remaining validation
  -- memory spike after the Pokemon-registry fix.
  local function captureItemMachineFields(rows)
    local out={}
    for id,def in pairs(rows or {}) do
      if type(def)=="table" then
        out[id]={
          teachesPresent=def.teaches~=nil, teaches=Core.copy(def.teaches),
          machine=type(def.machine)=="table" and def.machine or nil,
          machineMovePresent=type(def.machine)=="table" and def.machine.move~=nil or false,
          machineMove=type(def.machine)=="table" and Core.copy(def.machine.move) or nil,
        }
      end
    end
    return out
  end

  local function restoreItemMachineFields(rows,snapshot)
    for id,rec in pairs(snapshot or {}) do
      local def=rows and rows[id]
      if type(def)=="table" then
        if rec.teachesPresent then def.teaches=Core.copy(rec.teaches) else def.teaches=nil end
        if rec.machine and type(def.machine)=="table" then
          if rec.machineMovePresent then def.machine.move=Core.copy(rec.machineMove) else def.machine.move=nil end
        end
      end
    end
  end

  local function captureMartMutationFields(data)
    local out={}
    for _,perMap in pairs((data and data.text_pointers) or {}) do
      if type(perMap)=="table" then
        for _,entry in pairs(perMap) do
          if type(entry)=="table" and type(entry.mart)=="table" then
            out[#out+1]={parent=entry,field="mart",value=Core.copy(entry.mart)}
          end
        end
      end
    end
    for _,stock in ipairs((data and data.gen2Marts and data.gen2Marts.lists) or {}) do
      if type(stock)=="table" then out[#out+1]={parent=stock,value=Core.copy(stock),array=true} end
    end
    return out
  end

  local function restoreMartMutationFields(rows)
    for _,row in ipairs(rows or {}) do
      if row.array then Core.deepcopyInto(row.parent,row.value)
      else row.parent[row.field]=Core.copy(row.value) end
    end
  end

  local function captureFieldMutationFields(data)
    local out={}
    local field=data and data.field
    if field and type(field.trades)=="table" then out.trades=Core.copy(field.trades) end
    -- Gen 1 hidden-item rows are mutated in place; only their item cell changes.
    out.hidden={}
    for _,rows in pairs((field and field.hiddenItems) or {}) do
      for _,row in ipairs(rows or {}) do
        if type(row)=="table" and row.item~=nil then
          out.hidden[#out.hidden+1]={parent=row,field="item",value=Core.copy(row.item)}
        end
      end
    end
    return out
  end

  local function restoreFieldMutationFields(data,snapshot)
    if not snapshot then return end
    if snapshot.trades and data and data.field and data.field.trades then
      Core.deepcopyInto(data.field.trades,snapshot.trades)
    end
    restoreMapMutationFields(snapshot.hidden)
  end

  local function snapshotFor(game)
    local data = game and game.data
    if not data then return nil end
    local s = Runtime.snapshots[data]
    if not s then
      s = {
        pokemonFields = capturePokemonMutationFields(data.pokemon),
        itemMachineFields = captureItemMachineFields(data.items),
        fieldMutationFields = captureFieldMutationFields(data),
        martMutationFields = captureMartMutationFields(data),
        mapMutationFields = captureMapMutationFields(data),
        gen2Trades = Core.copy((data.gen2EventTables and data.gen2EventTables.trades) or {}),
      }
      Runtime.snapshots[data] = s
    end
    return s
  end

  local function restore(game)
    local s = snapshotFor(game)
    if not s then return end
    restorePokemonMutationFields(game.data.pokemon,s.pokemonFields)
    restoreItemMachineFields(game.data.items,s.itemMachineFields)
    restoreFieldMutationFields(game.data,s.fieldMutationFields)
    restoreMartMutationFields(s.martMutationFields)
    restoreMapMutationFields(s.mapMutationFields)
    if game.data.gen2EventTables and game.data.gen2EventTables.trades then
      Core.deepcopyInto(game.data.gen2EventTables.trades, s.gen2Trades)
    end
    game.data._urProgressionHmSlots=nil
    game.data._urProgressionPlan=nil
    game.data._urItemPlan=nil
    game.data._urLogicItemPlan=nil
    game.data._urLogicItemLockedRefs=nil
    game.data._urLogicItemRefsByKey=nil
  end

  local function evoRows(def)
    return (def and def.evolutions) or {}
  end

  local function evoTarget(row)
    return row and (row.species or row.into)
  end

  local function evoStages(game,cfg)
    local pokemon = game.data.pokemon or {}
    local incoming = {}
    for _, id in ipairs(selectedSpecies(game,cfg)) do incoming[id] = 0 end
    for id in pairs(incoming) do
      local def = pokemon[id]
      for _, e in ipairs(evoRows(def)) do
        local t = evoTarget(e)
        if incoming[t] ~= nil then incoming[t] = incoming[t] + 1 end
      end
    end
    local stage = {}
    local q = {}
    for id, n in pairs(incoming) do
      if n == 0 then stage[id] = 0; q[#q + 1] = id end
    end
    table.sort(q)
    local pos = 1
    while q[pos] do
      local id = q[pos]; pos = pos + 1
      local s = stage[id] or 0
      for _, e in ipairs(evoRows(pokemon[id])) do
        local t = evoTarget(e)
        if pokemon[t] then
          local ns = math.min(2, s + 1)
          if stage[t] == nil or ns > stage[t] then stage[t] = ns end
          incoming[t] = (incoming[t] or 1) - 1
          if incoming[t] <= 0 then q[#q + 1] = t end
        end
      end
    end
    for id in pairs(incoming) do if stage[id] == nil then stage[id] = 0 end end
    return stage
  end

  local function evoDepth(game, start, cfg)
    local seen = {}
    local function rec(id)
      if seen[id] then return 0 end
      seen[id] = true
      local best = 0
      for _, e in ipairs(evoRows(game.data.pokemon[id])) do
        local t = evoTarget(e)
        if game.data.pokemon[t] and (tonumber(game.data.pokemon[t].dex) or 9999)<=pokedexCap(game,cfg) then best = math.max(best, 1 + rec(t)) end
      end
      seen[id] = nil
      return best
    end
    return rec(start)
  end

  local function chooseSimilar(game, pool, source, rng, predicate)
    local src = game.data.pokemon[source]
    if not src then return rng:pick(pool) end
    local bst = Core.bst(src)
    local scored = {}
    for _, id in ipairs(pool) do
      if (not predicate or predicate(id)) and id ~= source then
        scored[#scored + 1] = { id = id, d = math.abs(Core.bst(game.data.pokemon[id]) - bst) }
      end
    end
    table.sort(scored, function(a,b) if a.d ~= b.d then return a.d < b.d end return a.id < b.id end)
    if #scored == 0 then return rng:pick(pool) end
    local band = math.min(#scored, math.max(6, math.floor(#scored * 0.12)))
    return scored[rng:int(1, band)].id
  end

  local function sharesType(game, a, b)
    local ad, bd = game.data.pokemon[a], game.data.pokemon[b]
    if not ad or not bd then return false end
    local seen = {}
    for _, t in ipairs(ad.types or {}) do seen[t] = true end
    for _, t in ipairs(bd.types or {}) do if seen[t] then return true end end
    return false
  end

  local function hasType(game, id, wanted)
    local def=game.data.pokemon[id]
    if not def then return false end
    for _,t in ipairs(def.types or {}) do if t==wanted then return true end end
    return false
  end

  -- Compare the stats used by this cartridge. Expanded Gen-1 records can
  -- carry split-special aliases; those must not count as two extra stats.
  function R.speciesBst(game,id)
    local b=(game.data.pokemon[id] or {}).baseStats or {}
    local total=(b.hp or 0)+(b.attack or 0)+(b.defense or 0)+(b.speed or 0)
    if generation(game)==1 then return total+(b.special or b.specialAttack or 0) end
    return total+(b.specialAttack or b.special or 0)+(b.specialDefense or b.special or 0)
  end

  function R.withinBst(game,cfg,source,target)
    if not cfg.bst_match then return true end
    if not game.data.pokemon[source] or not game.data.pokemon[target] then return false end
    return math.abs(R.speciesBst(game,target)-R.speciesBst(game,source))<=cfg.bst_difference
  end

  local function selector(game, cfg, seed, namespace, source, mode, extraPred)
    local pool = eligibleSpecies(game, cfg)
    local rng = Core.rng(Core.hash(namespace .. "|" .. tostring(source), seed))
    local function ok(id)
      return (not extraPred or extraPred(id)) and (cfg.allow_legendaries or not LEGENDARIES[id])
    end
    if cfg.bst_match then
      local bounded,themed={},{}
      for _,id in ipairs(pool) do
        if ok(id) and R.withinBst(game,cfg,source,id) then
          bounded[#bounded+1]=id
          if sharesType(game,source,id) then themed[#themed+1]=id end
        end
      end
      if mode=="THEMED" and #themed>0 then bounded=themed end
      -- A hard limit must never widen just because the eligible pool is small.
      return rng:pick(bounded) or source
    end
    if mode == "SIMILAR" then return chooseSimilar(game, pool, source, rng, ok) end
    if mode == "THEMED" then
      local themed = {}
      for _, id in ipairs(pool) do if ok(id) and sharesType(game, source, id) then themed[#themed+1]=id end end
      if #themed > 0 then return chooseSimilar(game, themed, source, rng) end
    end
    local filtered = {}
    for _, id in ipairs(pool) do if ok(id) then filtered[#filtered+1]=id end end
    return rng:pick(#filtered > 0 and filtered or pool)
  end

  local function buildStarterMap(game, cfg, seed, adapter)
    local out, used = {}, {}
    if cfg.starters == "UNCHANGED" then return out end
    local pool = eligibleSpecies(game, cfg)
    local vanillaStarters = {}
    for _, id in ipairs((adapter and adapter.starters) or {}) do vanillaStarters[id] = true end

    local function collect(src, allowVanilla)
      local candidates = {}
      for _, id in ipairs(pool) do
        local good = not used[id] and (allowVanilla or not vanillaStarters[id])
          and R.withinBst(game,cfg,src,id)
        -- Even the emergency fallback must not hand a pedestal its own
        -- vanilla species unless the selected pool literally has no other
        -- eligible choice.
        if allowVanilla and id == src then good = false end
        if cfg.starters == "TWO_EVOS" then good = good and evoDepth(game, id, cfg) >= 2 end
        if good then candidates[#candidates+1] = id end
      end
      return candidates
    end

    for i, src in ipairs((adapter and adapter.starters) or {}) do
      local rng = Core.rng(Core.hash("starter|" .. i, seed))
      -- RANDOM means visibly randomized: prefer a unique species outside the
      -- entire vanilla starter set, not merely a different pedestal. This
      -- prevents seeds such as Bulbasaur / Charmander / <random> from looking
      -- only partially randomized.
      local candidates = collect(src, false)
      if #candidates == 0 then candidates = collect(src, true) end
      if #candidates == 0 and cfg.starters ~= "TWO_EVOS" then candidates = cfg.bst_match and {src} or pool end
      local pick = rng:pick(candidates)
      if pick then out[src] = pick; used[pick] = true end
    end
    return out
  end

  -- UPR-ZX's "rival carries starter throughout" is a separate rule from
  -- general trainer randomization.  Capture the ORIGINAL starter families
  -- before evolution tables are mutated so rival slots can still be
  -- recognized later, then evolve the randomized replacement on UPR-style
  -- level thresholds (16/36 for two-stage lines, 30 for one-stage lines).
  local function buildStarterFamilies(game, adapter)
    local sourceToBase={}
    local function walk(base,id,depth,seen)
      if not id or seen[id] or depth>3 then return end
      seen[id]=true; sourceToBase[id]=base
      local def=game.data.pokemon[id]
      for _,e in ipairs(evoRows(def)) do
        local to=evoTarget(e)
        if type(to)=="string" and game.data.pokemon[to] then walk(base,to,depth+1,seen) end
      end
    end
    for _,base in ipairs((adapter and adapter.starters) or {}) do
      if game.data.pokemon[base] then walk(base,base,0,{}) end
    end
    return sourceToBase
  end

  local function evoChoices(game,id)
    local out={}
    local def=game.data.pokemon[id]
    for _,e in ipairs(evoRows(def)) do
      local to=evoTarget(e)
      if type(to)=="string" and game.data.pokemon[to] then out[#out+1]=to end
    end
    table.sort(out)
    return out
  end

  local function targetEvolutionPath(a,base)
    a.rivalEvolutionPaths=a.rivalEvolutionPaths or {}
    if a.rivalEvolutionPaths[base] then return a.rivalEvolutionPaths[base] end
    local path={base}
    local first=evoChoices(a.game,base)
    if #first>0 then
      local twoStage={}
      for _,id in ipairs(first) do if #evoChoices(a.game,id)>0 then twoStage[#twoStage+1]=id end end
      local pool=#twoStage>0 and twoStage or first
      local f=Core.rng(Core.hash("rival-evo1|"..base,a.seed)):pick(pool)
      if f then
        path[2]=f
        local second=evoChoices(a.game,f)
        if #second>0 then path[3]=Core.rng(Core.hash("rival-evo2|"..base,a.seed)):pick(second) end
      end
    end
    a.rivalEvolutionPaths[base]=path
    return path
  end

  local function rivalStarterPick(a,classId,partyId,source,level)
    if not a.cfg.rival_starter or not a.starterFamilyBase then return nil end
    local c,p=tostring(classId or ""),tostring(partyId or "")
    local rival=(c=="OPP_RIVAL1" or c=="OPP_RIVAL2" or c=="OPP_RIVAL3"
      or c=="RIVAL1" or c=="RIVAL2" or p:match("^RIVAL[12]_"))
    if not rival then return nil end
    local originalBase=a.starterFamilyBase[source]
    if not originalBase then return nil end
    local targetBase=a.starterMap[originalBase]
    if not targetBase then return nil end
    local path=targetEvolutionPath(a,targetBase)
    local lv=tonumber(level) or 1
    if path[3] then
      if lv>=36 then return path[3] end
      if lv>=16 then return path[2] end
      return path[1]
    elseif path[2] then
      return lv>=30 and path[2] or path[1]
    end
    return path[1]
  end


  local function mutateStats(game, cfg, seed)
    if cfg.base_stats == "UNCHANGED" then return end
    local selected=selectedSpecies(game,cfg)
    for _, id in ipairs(selected) do
      local def = game.data.pokemon[id]
      local rng = Core.rng(Core.hash("stats|" .. id, seed))
      local target=def
      if cfg.base_stats == "SHUFFLE" then
        local keys = Core.statKeys(target)
        local vals = {}; for i,k in ipairs(keys) do vals[i] = target.baseStats[k] end
        rng:shuffle(vals)
        for i,k in ipairs(keys) do target.baseStats[k] = vals[i] end
      else
        local vals = Core.redistributeStats(target, rng)
        for k,v in pairs(vals) do target.baseStats[k] = v end
      end

    end
  end

  local function familyRoots(game,cfg,selected)
    selected=selected or selectedSpecies(game,cfg)
    local parent = {}
    for _, id in ipairs(selected) do parent[id]=id end
    local function find(x)
      while parent[x] and parent[x] ~= x do parent[x] = parent[parent[x]]; x = parent[x] end
      return x
    end
    local function union(a,b)
      if not parent[a] or not parent[b] then return end
      a,b=find(a),find(b); if a~=b then if a<b then parent[b]=a else parent[a]=b end end
    end
    for id in pairs(parent) do
      local def = game.data.pokemon[id]
      for _,e in ipairs(evoRows(def)) do union(id,evoTarget(e)) end
    end
    local roots={}; for id in pairs(parent) do roots[id]=find(id) end
    return roots
  end

  local function mutateTypes(game, cfg, seed)
    if cfg.types == "UNCHANGED" then return end
    local selected=selectedSpecies(game,cfg)
    local types = typePool(game)
    local roots = cfg.types == "FOLLOW_EVOS" and familyRoots(game,cfg,selected) or nil
    local assigned = {}
    for _, id in ipairs(selected) do
      local key = roots and roots[id] or id
      if not assigned[key] then
        local rng = Core.rng(Core.hash("types|" .. key, seed))
        local t1 = rng:pick(types)
        local t2 = rng:chance(45) and rng:pick(types) or nil
        if t2 == t1 then t2 = nil end
        assigned[key] = t2 and {t1,t2} or {t1}
      end
      game.data.pokemon[id].types = Core.copy(assigned[key])
    end
  end

  local SAFE_G2_UTILITY_FAMILY = {
    PARAS=true, PARASECT=true,
    SLOWPOKE=true, SLOWBRO=true, SLOWKING=true,
    POLIWAG=true, POLIWHIRL=true, POLIWRATH=true, POLITOED=true,
  }

  local function mutateEvolutions(game, cfg, seed)
    if cfg.evolutions == "UNCHANGED" then return end
    local preserveUtilityFamilies = generation(game)==2 and cfg.safety=="SAFE" and cfg.tm_compat=="UNCHANGED"
    -- Preserve the original stage shape.  A base->middle edge stays an edge
    -- into a middle-stage Pokemon that still has enough downstream depth,
    -- instead of occasionally collapsing a requested TWO_EVOS starter into a
    -- one-step line.  This also bounds every randomized chain to Gen 1/2's
    -- normal three-stage shape.
    local selected=selectedSpecies(game,cfg)
    local stages = evoStages(game,cfg)
    local depths = {}
    for _, sid in ipairs(selected) do depths[sid] = evoDepth(game, sid, cfg) end
    local pool = eligibleSpecies(game, cfg)
    for _, id in ipairs(selected) do
      local def = game.data.pokemon[id]
      -- SAFE + vanilla HM compatibility keeps the three required utility
      -- families intact so a caught learner cannot evolve into a non-learner
      -- before the corresponding HM is obtained.
      if not (preserveUtilityFamilies and SAFE_G2_UTILITY_FAMILY[id]) then
      for ei, e in ipairs(evoRows(def)) do
        local originalTarget = evoTarget(e)
        local targetStage = stages[originalTarget]
        local targetDepth = depths[originalTarget] or 0
        local candidates = {}
        for _, target in ipairs(pool) do
          if target ~= id and (stages[target] or 0) == targetStage
             and (depths[target] or 0) >= targetDepth then
            candidates[#candidates+1]=target
          end
        end
        -- If a highly unusual modded evolution graph has no exact structural
        -- peer, degrade to any later stage rather than emitting a bad id.
        if #candidates == 0 then
          local srcStage = stages[id] or 0
          for _, target in ipairs(pool) do
            if target ~= id and (stages[target] or 0) > srcStage then candidates[#candidates+1]=target end
          end
        end
        if #candidates > 0 then
          local rng = Core.rng(Core.hash("evo|"..id.."|"..ei, seed))
          local target = rng:pick(candidates)
          if e.species ~= nil then e.species = target else e.into = target end
        end
      end
      end
    end
  end

  -- Mirror UPR-ZX's Gen 1/2 "Change Impossible Evolutions" rules.
  local function changeImpossibleEvolutions(game, cfg)
    if not cfg.impossible_evos then return end
    local gen = generation(game)
    local selected=selectedSpecies(game,cfg)
    for _, id in ipairs(selected) do
      for _, e in ipairs(evoRows(game.data.pokemon[id])) do
        if gen == 1 and e.method == "TRADE" then
          e.method, e.level = "LEVEL", 37
        elseif gen == 2 and e.method == "EVOLVE_TRADE" then
          if id == "SLOWPOKE" then
            e.method, e.item, e.level = "EVOLVE_ITEM", "WATER_STONE", nil
          elseif id == "SEADRA" then
            e.method, e.level, e.item = "EVOLVE_LEVEL", 40, nil
          elseif id == "POLIWHIRL" or e.item == nil then
            e.method, e.level, e.item = "EVOLVE_LEVEL", 37, nil
          else
            e.method, e.level, e.item = "EVOLVE_LEVEL", 30, nil
          end
        end
      end
    end
  end

  local Stab = {}
  do
    -- These moves either bypass STAB, depend on a different effective type,
    -- need sleep/other party members, or sacrifice the user. Positive power
    -- alone does not make an attack suitable for guaranteed opening STAB.
    local excluded = {
      SONICBOOM=true, DRAGON_RAGE=true, SEISMIC_TOSS=true, NIGHT_SHADE=true,
      PSYWAVE=true, COUNTER=true, MIRROR_COAT=true, BIDE=true, SUPER_FANG=true,
      FISSURE=true, HORN_DRILL=true, GUILLOTINE=true, HIDDEN_POWER=true,
      FUTURE_SIGHT=true, BEAT_UP=true, PRESENT=true,
    }
    local excludedEffects = {
      SPECIAL_DAMAGE_EFFECT=true, SUPER_FANG_EFFECT=true, OHKO_EFFECT=true,
      BIDE_EFFECT=true, COUNTER_EFFECT=true, DREAM_EATER_EFFECT=true,
      EXPLODE_EFFECT=true,
      EFFECT_STATIC_DAMAGE=true, EFFECT_LEVEL_DAMAGE=true, EFFECT_PSYWAVE=true,
      EFFECT_COUNTER=true, EFFECT_MIRROR_COAT=true, EFFECT_BIDE=true,
      EFFECT_SUPER_FANG=true, EFFECT_OHKO=true, EFFECT_HIDDEN_POWER=true,
      EFFECT_FUTURE_SIGHT=true, EFFECT_BEAT_UP=true, EFFECT_PRESENT=true,
      EFFECT_DREAM_EATER=true, EFFECT_SNORE=true, EFFECT_SELFDESTRUCT=true,
    }
    function Stab.pool(game,def,pool)
      local types,out={},{}
      -- Match the engine's literal type IDs (including PSYCHIC_TYPE where
      -- supplied by the cartridge); aliases cannot earn STAB in native damage.
      for _,t in ipairs((def and def.types) or {}) do types[t]=true end
      for _,mid in ipairs(pool) do
        local md=game.data.moves[mid]
        if types[md.type] and (tonumber(md.power) or 0)>0
            and (tonumber(md.pp) or 0)>0 and not md.fixedDamage
            and not BAD_STARTER_MOVES[mid] and not excluded[mid]
            and not excludedEffects[md.effect] then out[#out+1]=mid end
      end
      return out
    end

    function Stab.ensure(game,def,id,seed,pool)
      local candidates=Stab.pool(game,def,pool)
      -- For example, Gen 1's only Dragon attack is fixed-damage Dragon Rage.
      -- Keep the native pool; do not invent an attack or reject a valid seed.
      if #candidates==0 then return end
      local eligible={};for _,mid in ipairs(candidates) do eligible[mid]=true end
      local rng=Core.rng(Core.hash("moveset-stab|"..id,seed))
      local function hasStab(known)
        for _,mid in ipairs(known) do if eligible[mid] then return true end end
        return false
      end
      local function choose(known)
        local seen={};for _,mid in ipairs(known) do seen[mid]=true end
        local first=rng:int(1,#candidates)
        for offset=0,#candidates-1 do
          local mid=candidates[((first+offset-1)%#candidates)+1]
          if not seen[mid] then return mid end
        end
        return candidates[first]
      end
      -- Mirror native arrival moves: later unique moves push the oldest out;
      -- an already-known move is skipped. Repeating the sole eligible attack
      -- (e.g. Lick) keeps it known instead of evicting it at higher levels.
      local function learn(known,mid)
        local out={};local duplicate=false
        for i,m in ipairs(known) do out[i]=m;if m==mid then duplicate=true end end
        if not duplicate then
          if #out==4 then table.remove(out,1) end
          out[#out+1]=mid
        end
        return out
      end
      local known,rows={},nil
      if def.level1Moves then
        for i=1,math.min(4,#def.level1Moves) do known[i]=def.level1Moves[i] end
        if not hasStab(known) then
          local slot=#known>0 and rng:int(1,#known) or 1
          known[slot]=choose(known);def.level1Moves[slot]=known[slot]
        end
        rows=def.learnset or {}
      else
        def.levelMoves=def.levelMoves or {}
        rows=def.levelMoves
        if not rows[1] or rows[1].level>1 then
          table.insert(rows,1,{level=1,move=choose(known)})
        end
      end
      for _,row in ipairs(rows) do
        local nextKnown=learn(known,row.move)
        if not hasStab(nextKnown) then
          row.move=choose(known)
          nextKnown=learn(known,row.move)
        end
        known=nextKnown
      end
    end
  end

  local function mutateMovesets(game, cfg, seed)
    if cfg.movesets == "UNCHANGED" then return end
    local prefer = cfg.movesets == "TYPE_BIAS"
    -- Validation must stay responsive on mobile with 493 species. The old
    -- implementation allocated a fresh candidates array by scanning every
    -- registered move for every single learnset slot. With later-generation
    -- learnsets that turns one Validate press into millions of table writes.
    -- Build the global/type pools once and choose unused moves by bounded
    -- rejection sampling instead.
    local pool = movePool(game,false)
    local byType={}
    if prefer then
      for _,mid in ipairs(pool) do
        local md=game.data.moves[mid]
        local t=md and md.type
        if t then byType[t]=byType[t] or {}; byType[t][#byType[t]+1]=mid end
      end
    end
    local selected=selectedSpecies(game,cfg)
    local function pickUnused(rng,source,used)
      if not source or #source==0 then return nil end
      -- Most species learn far fewer moves than the 400-600 move pool, so a
      -- few rejection attempts are effectively constant-time.
      for _=1,16 do
        local m=source[rng:int(1,#source)]
        if m and not used[m] then return m end
      end
      -- Deterministic bounded fallback for the rare heavily-used pool.
      local first=rng:int(1,#source)
      for off=0,#source-1 do
        local m=source[((first+off-1)%#source)+1]
        if m and not used[m] then return m end
      end
      return source[first]
    end
    local function typedSource(def)
      if not prefer then return nil end
      local a,b=(def.types or {})[1],(def.types or {})[2]
      if a and b and a~=b then
        local merged={}
        for _,m in ipairs(byType[a] or {}) do merged[#merged+1]=m end
        for _,m in ipairs(byType[b] or {}) do merged[#merged+1]=m end
        return merged
      end
      return byType[a]
    end
    for _, id in ipairs(selected) do
      local def = game.data.pokemon[id]
      local rng = Core.rng(Core.hash("moveset|" .. id, seed))
      local used = {}
      local typed=typedSource(def)
      local function nextMove()
        local source=(prefer and typed and #typed>0 and rng:chance(65)) and typed or pool
        local move=pickUnused(rng,source,used)
        if not move and source~=pool then move=pickUnused(rng,pool,used) end
        if move then used[move]=true end
        return move
      end
      local function fill(rows)
        for i,row in ipairs(rows or {}) do
          local move=nextMove()
          if move then
            if type(row)=="table" then row.move=move else rows[i]=move end
          end
        end
      end
      if def.level1Moves then
        for i=1,#def.level1Moves do local move=nextMove(); if move then def.level1Moves[i]=move end end
        fill(def.learnset)
      else
        fill(def.levelMoves)
      end
      if prefer then Stab.ensure(game,def,id,seed,pool) end
    end
  end

  -- SAFE starter protection. A randomized starter is the only guaranteed tool
  -- the player owns for the opening rival / first-route trainers, so one weak
  -- or immune attack can turn an otherwise valid seed into a literal unwinnable
  -- matchup. Give each randomized SAFE starter four deterministic damaging
  -- attacks with distinct types where the active move registry permits it.
  function R._safeStarterCoverage(game,id,seed,cfg)
    local pool=movePool(game,true)
    local rng=Core.rng(Core.hash("startercoverage|"..tostring(id),seed))
    local shuffled=Core.copy(pool); rng:shuffle(shuffled)
    local out,used,usedType={}, {}, {}
    local function add(m)
      if not m or used[m] then return false end
      local md=game.data.moves[m]
      if not md or (tonumber(md.power) or 0)<=0 or BAD_STARTER_MOVES[m] then return false end
      out[#out+1]=m; used[m]=true; usedType[tostring(md.type or "")]=true
      return true
    end
    -- Reserve a real STAB attack before filling coverage. Keep the original
    -- shuffle and results for UNCHANGED/RANDOM and for no-eligible-pool cases.
    if cfg and cfg.movesets=="TYPE_BIAS" then
      local typed=Stab.pool(game,game.data.pokemon[id],shuffled)
      if typed[1] then add(typed[1]) end
    end
    -- Then maximize type diversity so Ghost/Ground/Flying and heavy resistance
    -- matchups cannot wall the starter's entire opening moveset.
    for _,m in ipairs(shuffled) do
      if #out>=4 then break end
      local md=game.data.moves[m]; local t=tostring(md and md.type or "")
      if md and not usedType[t] then add(m) end
    end
    for _,m in ipairs(shuffled) do if #out>=4 then break end; add(m) end
    return out
  end

  function R._ensureStarterCoverage(game, starterMap, seed, cfg)
    for _,id in pairs(starterMap or {}) do
      local def=game.data.pokemon[id]
      local coverage=def and R._safeStarterCoverage(game,id,seed,cfg) or {}
      if def and #coverage>0 then
        if def.level1Moves then
          -- Gen 1: remove <=Lv5 learnset rows so they cannot immediately push
          -- one of the four guaranteed opening moves out of the party moveset.
          def.level1Moves={}
          for i=1,math.min(4,#coverage) do def.level1Moves[i]=coverage[i] end
          local later={}
          for _,row in ipairs(def.learnset or {}) do if (tonumber(row.level) or 99)>5 then later[#later+1]=row end end
          def.learnset=later
        elseif def.levelMoves then
          -- Gen 2 MakeTrainerPartyMon / givepoke use the last four levelMoves at
          -- or below the current level. Put the guaranteed set at Lv1 and keep
          -- later progression rows, then recheck Type Bias coverage below.
          local later={}
          for _,row in ipairs(def.levelMoves or {}) do if (tonumber(row.level) or 99)>5 then later[#later+1]=row end end
          def.levelMoves={}
          for i=1,math.min(4,#coverage) do def.levelMoves[#def.levelMoves+1]={level=1,move=coverage[i]} end
          for _,row in ipairs(later) do def.levelMoves[#def.levelMoves+1]=row end
        end
        if cfg and cfg.movesets=="TYPE_BIAS" then Stab.ensure(game,def,id,seed,movePool(game,false)) end
      end
    end
  end

  local function machineKind(def, id)
    if type(def) ~= "table" then return nil end
    if type(def.machine) == "table" then return def.machine.kind end
    local label = tostring(def.tmLabel or def.name or id or "")
    if label:match("^HM") or tostring(id or ""):match("^HM") then return "HM" end
    if label:match("^TM") or tostring(id or ""):match("^TM") then return "TM" end
    return nil
  end

  local function machineMove(def)
    if type(def) ~= "table" then return nil end
    if type(def.machine) == "table" then return def.machine.move end
    return def.teaches
  end

  local function setMachineMove(def, move)
    if type(def) ~= "table" then return end
    if type(def.machine) == "table" then def.machine.move = move else def.teaches = move end
  end

  local function isKeyItem(id, def)
    return KEY_ITEMS[id] or (type(def) == "table" and (def.keyItem == true or def.pocket == "KEY_ITEM"))
  end

  local function tmItems(game)
    local out = {}
    for id, def in pairs(game.data.items or {}) do
      if type(def) == "table" and machineKind(def, id) == "TM" then out[#out+1] = id end
    end
    table.sort(out)
    return out
  end

  local function allMachineMoves(game)
    local out={}
    for id,def in pairs(game.data.items or {}) do
      if type(def) == "table" and machineKind(def, id) then
        local move = machineMove(def)
        if move then out[#out+1] = move end
      end
    end
    return Core.unique(out)
  end

  local function hmMoves(game)
    local out={}
    for id,def in pairs(game.data.items or {}) do
      if type(def)=="table" and machineKind(def,id)=="HM" then
        local move=machineMove(def)
        if move then out[#out+1]=move end
      end
    end
    return Core.unique(out)
  end

  local function mutateTms(game, cfg, seed)
    if cfg.tms ~= "RANDOM" then return end
    local pool = movePool(game, false)
    local used = {}
    for _, itemId in ipairs(tmItems(game)) do
      local rng = Core.rng(Core.hash("tm|"..itemId, seed))
      local candidates={}
      for _,m in ipairs(pool) do if not used[m] then candidates[#candidates+1]=m end end
      if #candidates==0 then candidates=pool end
      local pick=rng:pick(candidates)
      if pick then setMachineMove(game.data.items[itemId], pick); used[pick]=true end
    end
  end

  local function mutateTmCompat(game,cfg,seed)
    if cfg.tm_compat == "UNCHANGED" then return end
    local machines = allMachineMoves(game)
    local safeHms=(cfg.safety=="SAFE") and hmMoves(game) or {}
    local selected=selectedSpecies(game,cfg)
    for _, id in ipairs(selected) do
      local def=game.data.pokemon[id]
      local out={}
      if cfg.tm_compat == "FULL" then
        out=Core.copy(machines)
      else
        local types={}; for _,t in ipairs(def.types or {}) do types[t]=true end
        local rng=Core.rng(Core.hash("tmcompat|"..id,seed))
        for _,m in ipairs(machines) do
          local md=game.data.moves[m]
          local chance=(cfg.tm_compat=="TYPE_BIAS" and md and types[md.type]) and 90
            or (cfg.tm_compat=="TYPE_BIAS" and 25 or 50)
          if rng:chance(chance) then out[#out+1]=m end
        end
      end
      -- SAFE mode guarantees field-move usability when compatibility is
      -- randomized. HMs remain their vanilla moves; only their compatibility
      -- is made universal. CHAOS keeps the selected random policy unchanged.
      if cfg.safety=="SAFE" then
        local seen={}
        for _,m in ipairs(out) do seen[m]=true end
        for _,m in ipairs(safeHms) do
          if not seen[m] then out[#out+1]=m; seen[m]=true end
        end
      end
      def.tmhm=out
    end
  end

  local function tradeIsProtected(row)
    return type(row)=="table" and (row.randomizerProtected==true or row.protected==true
      or row.noRandomize==true or row.randomize==false)
  end

  local function nativeTradeCount(spec)
    if type(spec)~="table" then return nil end
    return tonumber(spec.nativeCount or spec.count)
  end

  local function tradeCountOk(spec,count)
    local native=nativeTradeCount(spec)
    if not native then return true end
    if count<native then return false,native end
    if spec.allowExtra==false and count~=native then return false,native end
    return true,native
  end

  local function mutateTradeRows(game,cfg,seed,rows,prefix,isGen2)
    if type(rows) ~= "table" then return end
    local pool=eligibleSpecies(game,cfg)
    local usedGet,usedGive={},{}
    local original={}

    local function resolved(value)
      return Core.resolveIndexedId(game.data.pokemon,value) or value
    end

    local function choose(key,used,forbid,source)
      local candidates={}
      for _,id in ipairs(pool) do
        if not used[id] and id ~= forbid and R.withinBst(game,cfg,source,id) then candidates[#candidates+1]=id end
      end
      if #candidates==0 then
        for _,id in ipairs(pool) do if id ~= forbid and R.withinBst(game,cfg,source,id) then candidates[#candidates+1]=id end end
      end
      local rng=Core.rng(Core.hash("trade|"..prefix.."|"..key,seed))
      return rng:pick(#candidates>0 and candidates or (cfg.bst_match and {source} or pool))
    end

    -- Capture the native relationship first. Yellow has more than one
    -- same-species trade, and a one-pass algorithm can accidentally spend a
    -- future same-species row's requested species on an earlier row.
    for i,row in ipairs(rows) do
      original[i]={get=resolved(row.get),give=resolved(row.give),protected=tradeIsProtected(row)}
    end

    -- Pass 1: received species are globally unique across rows this randomizer
    -- owns.  Expansion mods may explicitly protect authored trade rows; those
    -- rows remain byte-for-byte untouched and are excluded from uniqueness.
    for i,row in ipairs(rows) do
      local oldGet=original[i].get
      if not original[i].protected then
        if type(oldGet)=="string" and game.data.pokemon[oldGet] then
          local newGet=choose("get|"..i,usedGet,nil,oldGet)
          if newGet then
            row.get=newGet
            usedGet[newGet]=true
            -- UPR-ZX updates a default species-name nickname when the received
            -- species changes. Authored nicknames such as MUSCLE/ROCKY remain.
            local oldDef,newDef=game.data.pokemon[oldGet],game.data.pokemon[newGet]
            if row.nickname and oldDef and newDef
               and tostring(row.nickname):upper()==tostring(oldDef.name or oldGet):upper() then
              row.nickname=newDef.name or newGet
            end
          end
        end
        if isGen2 then row.gender="TRADE_GENDER_EITHER" end
      end
    end

    if cfg.trades~="BOTH" then return end

    -- Reserve the requested species of every original same-species trade
    -- before randomizing the other requests. This makes the uniqueness
    -- guarantee constructive instead of rejecting otherwise-valid manual
    -- seeds after the fact (notably Yellow seed 3 in the retail dataset).
    for i,row in ipairs(rows) do
      local o=original[i]
      if not o.protected and o.give==o.get and row.get then
        row.give=row.get
        usedGive[row.give]=true
      end
    end

    -- Pass 2: randomize the remaining requested species without colliding
    -- with the reserved same-species rows or the received species in-row.
    for i,row in ipairs(rows) do
      local o=original[i]
      if not o.protected and o.give~=o.get and type(o.give)=="string" and game.data.pokemon[o.give] then
        local newGive=choose("give|"..i,usedGive,row.get,o.give)
        if newGive then row.give=newGive; usedGive[newGive]=true end
      end
    end
  end

  local function mutateTrades(game,cfg,seed)
    if cfg.trades == "UNCHANGED" then return end
    if game.data.field and game.data.field.trades then
      mutateTradeRows(game,cfg,seed,game.data.field.trades,"g1",false)
    end
    local ev=game.data.gen2EventTables
    if ev and ev.trades then mutateTradeRows(game,cfg,seed,ev.trades,"g2",true) end
  end

  local function itemId(game, value)
    if type(value)=="string" then
      if game.data.items and game.data.items[value] then return value end
      return nil
    end
    return Core.resolveIndexedId(game.data.items,value)
  end

  local function itemValue(game, id, template)
    if type(template)=="number" then
      local d=game.data.items and game.data.items[id]
      if d and d.index~=nil then return d.index end
      -- Gen 1 exposes virtual named TM records (for example TM10) that do
      -- not have a cartridge item-table index.  The overworld/hidden-item
      -- pickup paths feed their payload directly to Bag.add(), which accepts
      -- canonical string item ids, so preserving the target id here is the
      -- correct representation.  Falling back to `template` silently kept
      -- the old item and could make a required TM disappear from the seed.
      if generation(game)==1 and d then return id end
      return template
    end
    return id
  end

  local function placeholderItem(id)
    local u=tostring(id or ""):upper()
    return u=="" or u=="0" or u=="ITEM_NONE" or u=="NO_ITEM"
      or u:match("^UNUSED")~=nil or u:match("^TERU_SAMA")~=nil
      or u:match("^MISSING")~=nil
  end

  local function isRandomizableItem(game,id,def)
    if type(id)~="string" or type(def)~="table" then return false end
    if placeholderItem(id) or isKeyItem(id,def) then return false end
    if machineKind(def,id)=="HM" then return false end
    local index=tonumber(def.index)
    local gen=generation(game)
    -- Match UPR-ZX's generation-specific allowed-item masks for the numeric
    -- cartridge item table.  Named TM records can be virtual in Gen 1, so the
    -- machine metadata above remains authoritative when no numeric index exists.
    if index then
      if gen==1 then
        local singles={ [5]=true,[6]=true,[7]=true,[8]=true,[9]=true,[31]=true,
          [48]=true,[50]=true,[59]=true,[63]=true,[64]=true }
        if singles[index] or (index>=21 and index<=28) or (index>=41 and index<=45)
           or (index>=69 and index<=78) or (index>=84 and index<=195) then return false end
      elseif gen==2 then
        local banned={ [6]=true,[25]=true,[45]=true,[50]=true,[56]=true,[90]=true,
          [100]=true,[120]=true,[135]=true,[136]=true,[137]=true,[141]=true,[142]=true,
          [145]=true,[147]=true,[148]=true,[149]=true,[153]=true,[154]=true,[155]=true,
          [162]=true,[171]=true,[176]=true,[179]=true,[190]=true,[195]=true,[220]=true }
        if banned[index] then return false end
      end
    end
    return true
  end

  local function safeItemPool(game, wantTm)
    local out={}
    for id,def in pairs(game.data.items or {}) do
      if isRandomizableItem(game,id,def) then
        local isTm=machineKind(def,id)=="TM"
        if (wantTm==true and isTm) or (wantTm==false and not isTm) or wantTm==nil then
          out[#out+1]=id
        end
      end
    end
    table.sort(out,function(a,b)
      local da,db=game.data.items[a],game.data.items[b]
      local ia,ib=tonumber(da and da.index) or 99999,tonumber(db and db.index) or 99999
      if ia~=ib then return ia<ib end
      return a<b
    end)
    return out
  end

  -- Gen 2 NPC-gift item discovery. Field-item randomization historically
  -- only scanned item balls/hidden items, so literal giveitem/verbosegiveitem
  -- rewards such as Itemfinder, Old Rod and NPC-gifted TMs stayed vanilla on
  -- every seed. Discover one-time-style TM/key-item rewards from map-owned
  -- script roots and give each command a stable map/script/index identity.
  --
  -- We deliberately exclude HMs and every item already owned by the authored
  -- restrictive logic table: those rewards are progression checks and remain
  -- under _buildLogicItemPlan. Shared engine/std scripts are not traversed.
  function R._gen2ScriptKeyBank(key)
    local b=tostring(key or ""):match("^([0-9a-fA-F]+):")
    return b and tonumber(b,16) or nil
  end

  function R._gen2MapScriptRoots(map)
    local out,seen={},{}
    local function add(v)
      if type(v)=="string" and v:find(":",1,true) and not seen[v] then
        seen[v]=true; out[#out+1]=v
      end
    end
    for _,obj in ipairs((map and map.objects) or {}) do add(obj.scriptKey) end
    for _,ev in ipairs((map and map.bgEvents) or {}) do add(ev.scriptKey) end
    for _,ev in ipairs((map and map.coordEvents) or {}) do add(ev.scriptKey) end
    for _,row in pairs((map and map.sceneScripts) or {}) do
      if type(row)=="table" then add(row.scriptKey or row.key)
      elseif type(row)=="string" then add(row) end
    end
    for _,row in ipairs((map and map.callbacks) or {}) do
      if type(row)=="table" then add(row.scriptKey or row.key)
      elseif type(row)=="string" then add(row) end
    end
    table.sort(out)
    return out
  end

  function R._discoverGen2NpcGiftSlots(game)
    if generation(game)~=2 then return {} end
    local scripts=(game.data and game.data.gen2Scripts) or {}
    local maps=(game.data and game.data.gen2Maps) or {}
    if next(scripts)==nil or next(maps)==nil then return {} end

    local authored={}
    for _,d in ipairs(R._LOGIC_ITEM_DEFS and R._LOGIC_ITEM_DEFS[2] or {}) do
      authored[tostring(d.item or "")]=true
    end

    local foundByCmd=setmetatable({}, {__mode="k"})
    for _,mapId in ipairs(Core.sortedKeys(maps)) do
      local map=maps[mapId]
      if type(map)=="table" then
        local visited={}
        local function walk(key,depth)
          if depth>24 or visited[key] then return end
          visited[key]=true
          local rows=scripts[key]
          if type(rows)~="table" then return end
          for i,cmd in ipairs(rows) do
            if type(cmd)=="table" and (cmd.op=="giveitem" or cmd.op=="verbosegiveitem") and cmd.item~=nil then
              local src=itemId(game,cmd.item)
              local def=src and game.data.items and game.data.items[src]
              local kind=machineKind(def,src)
              local wanted=(kind=="TM") or (isKeyItem(src,def) and kind~="HM")
              if wanted and not authored[tostring(src)] then
                local rec=foundByCmd[cmd]
                if not rec then
                  foundByCmd[cmd]={
                    key=("NPCGIFT|%s|%s|%d"):format(tostring(mapId),tostring(key),i),
                    map=tostring(mapId),scriptKey=tostring(key),commandIndex=i,
                    item=src,category=(kind=="TM") and "TM" or "KEY",cmd=cmd,shared=false,
                  }
                elseif rec.map~=tostring(mapId) then
                  rec.shared=true
                end
              end
            end
            local target=type(cmd)=="table" and cmd.script or nil
            -- Standard/shared scripts are intentionally not item checks.
            if type(target)=="string" and not cmd.std then walk(target,depth+1) end
          end
        end
        for _,root in ipairs(R._gen2MapScriptRoots(map)) do walk(root,0) end
      end
    end

    local out={}
    for _,rec in pairs(foundByCmd) do
      if not rec.shared then out[#out+1]=rec end
    end
    table.sort(out,function(a,b) return a.key<b.key end)
    return out
  end

  function R._shuffledGiftTargets(seed,category,slots)
    local values={}
    for i,row in ipairs(slots) do values[i]=row.item end
    local rng=Core.rng(Core.hash("npc-gift-items|"..tostring(category),seed))
    rng:shuffle(values)
    -- If the whole category happened to draw the identity permutation, rotate
    -- once so a multi-check category is visibly randomized while preserving a
    -- perfect one-for-one permutation.
    if #values>1 then
      local identity=true
      for i,row in ipairs(slots) do if values[i]~=row.item then identity=false; break end end
      if identity then
        local first=table.remove(values,1); values[#values+1]=first
      end
    end
    return values
  end

  function R._buildNpcGiftItemPlan(game,cfg,seed)
    local plan={schema=1,seed=seed,version=versionId(game),mode=cfg and cfg.field_items or "UNCHANGED",slots={}}
    if generation(game)~=2 or not cfg or cfg.gift_items~="RANDOM" or cfg.field_items~="LOGIC_RANDOM" then return plan end
    local slots=R._discoverGen2NpcGiftSlots(game)
    local groups={TM={},KEY={}}
    for _,row in ipairs(slots) do groups[row.category][#groups[row.category]+1]=row end
    for _,category in ipairs({"TM","KEY"}) do
      local rows=groups[category]
      local values=R._shuffledGiftTargets(seed,category,rows)
      for i,row in ipairs(rows) do
        plan.slots[#plan.slots+1]={
          key=row.key,map=row.map,scriptKey=row.scriptKey,commandIndex=row.commandIndex,
          source=row.item,target=values[i],category=category,
        }
      end
    end
    table.sort(plan.slots,function(a,b) return a.key<b.key end)
    return plan
  end

  function R._validateNpcGiftItemPlan(game,cfg,plan)
    if generation(game)~=2 or not cfg or cfg.gift_items~="RANDOM" or cfg.field_items~="LOGIC_RANDOM" then return true end
    if type(plan)~="table" or tonumber(plan.schema)~=1 or type(plan.slots)~="table" then
      return false,"NPC gift item plan missing"
    end
    local discovered=R._discoverGen2NpcGiftSlots(game)
    local byKey={}; for _,row in ipairs(discovered) do byKey[row.key]=row end
    if #plan.slots~=#discovered then
      return false,("NPC gift item check count changed (%d saved/generated vs %d host)"):format(#plan.slots,#discovered)
    end
    local srcBag={TM={},KEY={}}; local dstBag={TM={},KEY={}}
    for _,row in ipairs(discovered) do
      local t=srcBag[row.category]; t[row.item]=(t[row.item] or 0)+1
    end
    local seen={}
    for _,row in ipairs(plan.slots) do
      if seen[row.key] then return false,"duplicate NPC gift check "..tostring(row.key) end
      seen[row.key]=true
      local live=byKey[row.key]
      if not live then return false,"NPC gift check disappeared: "..tostring(row.key) end
      if tostring(live.item)~=tostring(row.source) or tostring(live.category)~=tostring(row.category) then
        return false,"NPC gift source changed at "..tostring(row.key)
      end
      local td=game.data.items and game.data.items[row.target]
      if not td then return false,"NPC gift target item missing: "..tostring(row.target) end
      local targetCategory=(machineKind(td,row.target)=="TM") and "TM"
        or (isKeyItem(row.target,td) and machineKind(td,row.target)~="HM" and "KEY" or nil)
      if targetCategory~=row.category then
        return false,"NPC gift category changed at "..tostring(row.key)
      end
      local t=dstBag[row.category]; t[row.target]=(t[row.target] or 0)+1
    end
    for _,category in ipairs({"TM","KEY"}) do
      for id,n in pairs(srcBag[category]) do
        if dstBag[category][id]~=n then return false,"NPC gift permutation lost "..tostring(id) end
      end
      for id,n in pairs(dstBag[category]) do
        if srcBag[category][id]~=n then return false,"NPC gift permutation invented "..tostring(id) end
      end
    end
    return true
  end

  function R._bindNpcGiftItemTargets(game,plan)
    local out=setmetatable({}, {__mode="k"})
    if not plan or type(plan.slots)~="table" then return out end
    local byKey={}
    for _,row in ipairs(R._discoverGen2NpcGiftSlots(game)) do byKey[row.key]=row end
    for _,row in ipairs(plan.slots) do
      local live=byKey[row.key]
      if live and live.cmd then out[live.cmd]=row.target end
    end
    return out
  end


  -- Standard Poke Mart inventory randomization. Gen 1 stores each clerk's
  -- shelf directly on text_pointers[*][*].mart; Gen 2 stores the 34 normal
  -- mart shelves in data.gen2Marts.lists. Bargain/Game Corner/prize vendors
  -- use separate systems and are deliberately not treated as Poke Marts.
  local function martItemCategory(id)
    local u=tostring(id or ""):upper()
    if u:find("BALL",1,true) then return "BALL" end
    if u:find("_STONE",1,true) or u=="MOON_STONE" then return "STONE" end
    if u=="POTION" or u=="SUPER_POTION" or u=="HYPER_POTION"
       or u=="MAX_POTION" or u=="FULL_RESTORE" or u=="FRESH_WATER"
       or u=="SODA_POP" or u=="LEMONADE" or u=="MOOMOO_MILK"
       or u=="BERRY" or u=="GOLD_BERRY" then return "HEAL" end
    if u=="ANTIDOTE" or u=="BURN_HEAL" or u=="ICE_HEAL"
       or u=="AWAKENING" or u=="PARLYZ_HEAL" or u=="FULL_HEAL"
       or u=="PSNCUREBERRY" or u=="PRZCUREBERRY" or u=="BURNT_BERRY"
       or u=="ICE_BERRY" or u=="MINT_BERRY" then return "STATUS" end
    if u=="REPEL" or u=="SUPER_REPEL" or u=="MAX_REPEL"
       or u=="ESCAPE_ROPE" then return "UTILITY" end
    return "OTHER"
  end

  local function martItemPool(game, priceCap, category)
    local out={}
    for id,def in pairs(game.data.items or {}) do
      local price=type(def)=="table" and tonumber(def.price) or nil
      if isRandomizableItem(game,id,def) and price and price>0
         and (not priceCap or price<=priceCap)
         and (not category or martItemCategory(id)==category) then
        out[#out+1]=id
      end
    end
    table.sort(out,function(a,b)
      local da,db=game.data.items[a],game.data.items[b]
      local pa,pb=tonumber(da and da.price) or 0,tonumber(db and db.price) or 0
      if pa~=pb then return pa<pb end
      local ia,ib=tonumber(da and da.index) or 99999,tonumber(db and db.index) or 99999
      if ia~=ib then return ia<ib end
      return a<b
    end)
    return out
  end

  function R._originalMartStock(snap,stock)
    for _,rec in ipairs((snap and snap.martMutationFields) or {}) do
      if rec.array and rec.parent==stock then return rec.value end
      if not rec.array and rec.parent and rec.parent[rec.field]==stock then return rec.value end
    end
    return nil
  end

  local function martRows(game)
    local rows,seen={},{}
    local snap=Runtime.snapshots[game.data]
    if generation(game)==1 then
      local current=game.data.text_pointers or {}
      for _,mapId in ipairs(Core.sortedKeys(current)) do
        local perMap=current[mapId]
        if type(perMap)=="table" then
          for _,textId in ipairs(Core.sortedKeys(perMap)) do
            local entry=perMap[textId]
            if type(entry)=="table" and type(entry.mart)=="table" and #entry.mart>0
               and not seen[entry.mart] then
              seen[entry.mart]=true
              local src=R._originalMartStock(snap,entry.mart) or entry.mart
              rows[#rows+1]={key="g1|"..tostring(mapId).."|"..tostring(textId),stock=entry.mart,source=Core.copy(src)}
            end
          end
        end
      end
    else
      local current=(game.data.gen2Marts and game.data.gen2Marts.lists) or {}
      for i,stock in ipairs(current) do
        if type(stock)=="table" and #stock>0 then
          rows[#rows+1]={key="g2|"..tostring(i-1),stock=stock,source=Core.copy(R._originalMartStock(snap,stock) or stock)}
        end
      end
    end
    table.sort(rows,function(a,b) return a.key<b.key end)
    return rows
  end

  local function martSourceMaxPrice(game,source)
    local maxPrice=0
    for _,id in ipairs(source or {}) do
      local def=game.data.items and game.data.items[id]
      maxPrice=math.max(maxPrice,tonumber(def and def.price) or 0)
    end
    return maxPrice
  end

  local function chooseUnused(rng,pool,used)
    local choices={}
    for _,id in ipairs(pool or {}) do if not used[id] then choices[#choices+1]=id end end
    local pick=rng:pick(choices)
    if pick then used[pick]=true end
    return pick
  end

  R._MART_SAFETY_ITEMS={"POKE_BALL","POTION"}

  function R._applyMartSafety(game,tracker)
    tracker=tracker or {}
    for _,row in ipairs(martRows(game)) do
      local stock=row.stock
      local present={}
      for _,id in ipairs(stock or {}) do present[itemId(game,id) or tostring(id)]=true end
      for _,wanted in ipairs(R._MART_SAFETY_ITEMS) do
        if game.data.items and game.data.items[wanted] and not present[wanted] then
          local template=(stock and stock[1]) or wanted
          local value=itemValue(game,wanted,template)
          stock[#stock+1]=value
          tracker[#tracker+1]={stock=stock,value=value,id=wanted}
          present[wanted]=true
        end
      end
    end
    return tracker
  end

  function R._removeMartSafety(tracker)
    for i=#(tracker or {}),1,-1 do
      local rec=tracker[i]; local stock=rec and rec.stock
      if type(stock)=="table" then
        for j=#stock,1,-1 do
          if stock[j]==rec.value then table.remove(stock,j); break end
        end
      end
    end
  end

  local function mutateMarts(game,cfg,seed)
    if cfg.marts=="VANILLA" then return end
    for _,row in ipairs(martRows(game)) do
      local rng=Core.rng(Core.hash("mart|"..row.key,seed))
      local count=#row.source
      local cap=nil
      if cfg.marts=="SAFE" then
        -- Keep early-game shops economically sane: randomized stock cannot
        -- cost more than twice the original shelf's highest price, with a
        -- ¥500 floor so tiny starter marts still have a useful legal pool.
        cap=math.max(500,martSourceMaxPrice(game,row.source)*2)
      end
      local general=martItemPool(game,cap,nil)
      if #general==0 then general=martItemPool(game,nil,nil) end
      local out,used={},{}
      if cfg.marts=="SAFE" then
        -- Preserve one representative of every progression/useful class that
        -- the vanilla shelf provided. Thus a ball mart stays a ball mart, a
        -- healing/status/repel mart keeps that role, and stone counters keep
        -- an evolution-stone option while the exact stock still changes.
        local present={}
        for _,id in ipairs(row.source) do
          local cat=martItemCategory(id)
          if cat~="OTHER" then present[cat]=true end
        end
        for _,cat in ipairs({"BALL","HEAL","STATUS","UTILITY","STONE"}) do
          if present[cat] and #out<count then
            local pool=martItemPool(game,cap,cat)
            local pick=chooseUnused(rng,pool,used)
            if not pick then
              for _,id in ipairs(row.source) do
                if martItemCategory(id)==cat and not used[id] then pick=id; used[id]=true; break end
              end
            end
            if pick then out[#out+1]=pick end
          end
        end
      end
      while #out<count do
        local pick=chooseUnused(rng,general,used)
        if not pick then pick=rng:pick(general) end
        if not pick then break end
        out[#out+1]=pick
      end
      if #out==count then
        rng:shuffle(out)
        for i=#row.stock,1,-1 do row.stock[i]=nil end
        for i,id in ipairs(out) do row.stock[i]=id end
      end
    end
  end

  function R._ensureLogicStartMartAccess(game,cfg,progression)
    if generation(game)~=1 or cfg.random_start~="LOGIC" then return true end
    local startId=progression and progression.start and tostring(progression.start.id or "") or ""
    if startId~="SAFFRON_CITY" then return true end
    local wanted="FRESH_WATER"
    if not (game.data.items and game.data.items[wanted]) then return false,"Fresh Water missing for Saffron LOGIC start" end
    local found=false
    for _,row in ipairs(martRows(game)) do
      if tostring(row.key):find("SAFFRON",1,true) then
        found=true
        local present=false
        for _,raw in ipairs(row.stock or {}) do if tostring(itemId(game,raw) or raw)==wanted then present=true; break end end
        if not present then
          if not row.stock or #row.stock==0 then return false,"Saffron mart has no replaceable stock slot" end
          -- Preserve the native mart slot count: replace one ordinary slot
          -- rather than appending a seventh product and invalidating the host
          -- mart table contract.
          row.stock[#row.stock]=itemValue(game,wanted,row.stock[#row.stock])
        end
      end
    end
    if not found then return false,"Saffron mart unavailable for legitimate guard-drink progression" end
    return true
  end

  local function validateMarts(game,cfg)
    if cfg.marts=="VANILLA" then return true end
    local rows=martRows(game)
    if #rows==0 then return false,"Poke Mart inventory tables unavailable" end
    for _,row in ipairs(rows) do
      if #row.stock~=#row.source then
        return false,"mart slot count changed at "..tostring(row.key)
      end
      local present={}
      local maxAllowed=nil
      if cfg.marts=="SAFE" then
        maxAllowed=math.max(500,martSourceMaxPrice(game,row.source)*2)
      end
      for _,id in ipairs(row.stock) do
        local def=game.data.items and game.data.items[id]
        local price=tonumber(def and def.price) or 0
        if not isRandomizableItem(game,id,def) or price<=0 then
          return false,"invalid mart item at "..tostring(row.key)..": "..tostring(id)
        end
        if maxAllowed and price>maxAllowed then
          return false,"SAFE mart price curve exceeded at "..tostring(row.key)..": "..tostring(id)
        end
        present[martItemCategory(id)]=true
      end
      if cfg.marts=="SAFE" then
        local required={}
        for _,id in ipairs(row.source) do
          local cat=martItemCategory(id)
          if cat~="OTHER" then required[cat]=true end
        end
        for cat in pairs(required) do
          if not present[cat] then
            return false,"SAFE mart lost "..cat.." access at "..tostring(row.key)
          end
        end
      end
    end
    return true
  end

  -- UPR-ZX's Gen 1 RANDOMIZE PC POTION tweak: replace the single Potion in
  -- the player's bedroom item PC with another useful non-TM item.  Gen 2
  -- starts with an empty item PC, so this setting is intentionally Gen 1 only.
  local function startingPcItem(game,cfg,seed)
    if not cfg.pc_item or generation(game)~=1 then return nil end
    local pool={}
    for _,id in ipairs(safeItemPool(game,false)) do
      if id~="POTION" then pool[#pool+1]=id end
    end
    if #pool==0 then return nil end
    return Core.rng(Core.hash("pc-potion",seed)):pick(pool)
  end

  local function applyStartingPcItem(active)
    if not active or not active.pcStartItem or active.generation~=1 then return true end
    local save=active.game and active.game.save
    if type(save)~="table" then return false,"save unavailable for starting PC item" end
    save.pcItems=save.pcItems or {}
    -- Setup runs during New Game, before the player can access the bedroom PC.
    -- Replace exactly the vanilla starter Potion rather than rewriting an
    -- already-used PC on later save activation.
    if save.pcItems.POTION~=1 then
      return false,"starting bedroom PC Potion is not in the expected New Game state"
    end
    local stacks=0
    for _ in pairs(save.pcItems) do stacks=stacks+1 end
    if stacks~=1 then
      return false,"starting bedroom PC contains unexpected extra item stacks"
    end
    save.pcItems.POTION=nil
    save.pcItems[active.pcStartItem]=1
    return true
  end

  local function mapTable(game)
    if generation(game)==2 then return (game.data and game.data.gen2Maps) or {} end
    return (game.data and game.data.maps) or {}
  end

  local function fieldSlots(game)
    local groups, order = {}, {}
    local function add(key, parent, field, value, mapId)
      if ItemLogic and ItemLogic.reserved(game,parent,field) then return end
      if game.data._urLogicItemLockedRefs and game.data._urLogicItemLockedRefs[parent] then return end
      local id=itemId(game,value)
      local def=id and game.data.items and game.data.items[id]
      if not id then return end
      local kind=(machineKind(def,id)=="TM") and "TM" or "ITEM"
      key=tostring(kind).."|"..tostring(key)
      local forced=(game.data._urProgressionHmSlots or {})[key]
      -- A SAFE Random Start can intentionally replace one ordinary field item
      -- with the local escape HM. HMs are normally excluded from random item
      -- pools, but that forced slot must remain visible to later validation and
      -- shared-event consistency checks after the replacement has occurred.
      if not isRandomizableItem(game,id,def)
          and not (forced and tostring(forced)==tostring(id) and machineKind(def,id)=="HM") then return end
      local g=groups[key]
      if not g then
        g={ key=key, kind=kind, source=id, refs={}, maps={} }
        groups[key]=g; order[#order+1]=g
      elseif g.source~=id then
        -- A shared event flag should describe one pickup.  If a future cache
        -- exposes conflicting values under one flag, keep them independent so
        -- randomization never merges unrelated objects silently.
        key=key.."|"..id
        g=groups[key]
        if not g then g={key=key,kind=kind,source=id,refs={},maps={}}; groups[key]=g; order[#order+1]=g end
      end
      g.refs[#g.refs+1]={ parent=parent, field=field, template=value }
      if mapId then g.maps[tostring(mapId)]=true end
    end

    local gen=generation(game)
    local maps=mapTable(game)
    for _,mapId in ipairs(Core.sortedKeys(maps)) do
      local map=maps[mapId]
      if type(map)=="table" then
        for i,obj in ipairs(map.objects or {}) do
          if gen==1 and obj.item~=nil then
            add("visible|"..mapId.."|"..i,obj,"item",obj.item,mapId)
          elseif gen==2 and type(obj.itemball)=="table" and obj.itemball.item~=nil then
            local event=obj.eventFlag
            local key=event~=nil and ("itemball-event|"..tostring(event))
              or ("itemball|"..mapId.."|"..i)
            add(key,obj.itemball,"item",obj.itemball.item,mapId)
          end
        end
        if gen==2 then
          for i,ev in ipairs(map.bgEvents or {}) do
            if type(ev.hiddenItem)=="table" and ev.hiddenItem.item~=nil then
              local event=ev.hiddenItem.event
              local key=event~=nil and ("hidden-event|"..tostring(event))
                or ("hidden|"..mapId.."|"..i)
              add(key,ev.hiddenItem,"item",ev.hiddenItem.item,mapId)
            end
          end
        end
      end
    end
    if gen==1 then
      for _,mapId in ipairs(Core.sortedKeys((game.data.field and game.data.field.hiddenItems) or {})) do
        local rows=game.data.field.hiddenItems[mapId]
        for i,row in ipairs(rows or {}) do
          if row.item~=nil then add("hidden|"..mapId.."|"..i,row,"item",row.item,mapId) end
        end
      end
    end
    table.sort(order,function(a,b) return a.key<b.key end)
    return order
  end

  local function setFieldSlot(game,slot,id)
    for _,ref in ipairs(slot.refs or {}) do
      ref.parent[ref.field]=itemValue(game,id,ref.template)
    end
  end

  local function tmByNumber(game,number)
    for id,def in pairs(game.data.items or {}) do
      local n=type(def)=="table" and ((def.machine and def.machine.number) or def.tmNumber) or nil
      if machineKind(def,id)=="TM" and tonumber(n)==tonumber(number) then return id end
    end
    return nil
  end

  local function mutateFieldItems(game,cfg,seed)
    if cfg.field_items=="UNCHANGED" then return end

    if cfg.field_items=="LOGIC_RANDOM" or cfg.field_items=="CHAOS" then
      local plan,why=R._buildLogicItemPlan(game,cfg,seed)
      if not plan then error(why or "logic progression-item fill failed") end
      local ok,err=R._applyLogicItemPlan(game,plan)
      if not ok then error(err or "logic progression-item application failed") end
    end

    local slots=fieldSlots(game)
    local regular,tms={},{}
    for _,slot in ipairs(slots) do
      if slot.kind=="TM" then tms[#tms+1]=slot else regular[#regular+1]=slot end
    end
    local rng=Core.rng(Core.hash("field-items",seed))
    if cfg.field_items=="SHUFFLE" then
      local items={}; for i,slot in ipairs(regular) do items[i]=slot.source end
      local machines={}; for i,slot in ipairs(tms) do machines[i]=slot.source end
      rng:shuffle(items); rng:shuffle(machines)
      for i,slot in ipairs(regular) do setFieldSlot(game,slot,items[i]) end
      for i,slot in ipairs(tms) do setFieldSlot(game,slot,machines[i]) end
      return
    end

    -- LOGIC RANDOM and CHAOS both randomize ordinary field rewards after the
    -- progression pool has been placed. The difference is that LOGIC RANDOM
    -- uses restrictive progression fill above; CHAOS freely permutes it.
    local itemPool=safeItemPool(game,false)
    local tmPool=safeItemPool(game,true)
    for _,slot in ipairs(regular) do
      local pick=rng:pick(itemPool)
      if pick then setFieldSlot(game,slot,pick) end
    end

    -- Keep required field TMs represented in LOGIC RANDOM. CHAOS deliberately
    -- drops this progression guarantee and fills the TM slots freely.
    local wanted,seen={},{}
    if cfg.field_items=="LOGIC_RANDOM" or cfg.field_items=="RANDOM" then
      for _,number in ipairs(REQUIRED_FIELD_TMS[generation(game)] or {}) do
        local id=tmByNumber(game,number)
        if id and not seen[id] then wanted[#wanted+1]=id; seen[id]=true end
      end
    end
    local rest={}
    for _,id in ipairs(tmPool) do if not seen[id] then rest[#rest+1]=id end end
    rng:shuffle(rest)
    local pos=1
    while #wanted<#tms and pos<=#rest do wanted[#wanted+1]=rest[pos]; seen[rest[pos]]=true; pos=pos+1 end
    while #wanted<#tms and #tmPool>0 do wanted[#wanted+1]=rng:pick(tmPool) end
    rng:shuffle(wanted)
    for i,slot in ipairs(tms) do if wanted[i] then setFieldSlot(game,slot,wanted[i]) end end
  end

  local G1_BADGES={"BOULDERBADGE","CASCADEBADGE","THUNDERBADGE","RAINBOWBADGE","SOULBADGE","MARSHBADGE","VOLCANOBADGE","EARTHBADGE"}
  local G1_GYMS={
    PEWTER_CITY="OPP_BROCK#1", CERULEAN_CITY="OPP_MISTY#1", VERMILION_CITY="OPP_LT_SURGE#1",
    CELADON_CITY="OPP_ERIKA#1", FUCHSIA_CITY="OPP_KOGA#1", SAFFRON_CITY="OPP_SABRINA#1",
    CINNABAR_ISLAND="OPP_BLAINE#1", VIRIDIAN_CITY="OPP_GIOVANNI#3",
  }
  local G1_GYM_ORDER={"OPP_BROCK#1","OPP_MISTY#1","OPP_LT_SURGE#1","OPP_ERIKA#1","OPP_KOGA#1","OPP_SABRINA#1","OPP_BLAINE#1","OPP_GIOVANNI#3"}
  local G2_BADGES={"ZEPHYR","HIVE","PLAIN","FOG","MINERAL","STORM","GLACIER","RISING"}
  local G2_BADGE_FLAGS={ZEPHYR=26,HIVE=27,PLAIN=28,FOG=29,MINERAL=30,STORM=31,GLACIER=32,RISING=33}
  local G2_GYM_SOURCE={
    VIOLET_CITY="ZEPHYR", AZALEA_TOWN="HIVE", GOLDENROD_CITY="PLAIN", ECRUTEAK_CITY="FOG",
    OLIVINE_CITY="MINERAL", CIANWOOD_CITY="STORM", MAHOGANY_TOWN="GLACIER", BLACKTHORN_CITY="RISING",
  }
  local G2_GYM_MAP_SOURCE={
    VIOLET_GYM="ZEPHYR", AZALEA_GYM="HIVE", GOLDENROD_GYM="PLAIN", ECRUTEAK_GYM="FOG",
    OLIVINE_GYM="MINERAL", CIANWOOD_GYM="STORM", MAHOGANY_GYM="GLACIER", BLACKTHORN_GYM="RISING",
  }
  local function badgeDisplay(id)
    local t=tostring(id or ""):gsub("BADGE$",""):gsub("_"," "):lower()
    t=t:gsub("(%a)([%w']*)",function(a,b) return a:upper()..b end)
    return t.." Badge"
  end

  -- LOGIC random starts can place a brand-new Gen 1 player in hubs whose
  -- vanilla surrounding content assumes several badges.  Keep those hubs in
  -- the pool, but only compress the specific escape corridor/gym needed by the
  -- seeded start.  Ordinary progression and every other start remain vanilla.
  local function gen1LogicStartActive(a,startId)
    return a and a.generation==1 and a.cfg and a.cfg.random_start=="LOGIC"
      and a.progression and a.progression.start
      and tostring(a.progression.start.id)==tostring(startId)
  end

  local function gen1KantoBadgeCount(game)
    -- Gen 1 badges are inventory keys; Gen 2 alone uses player.badges.
    local owned=game and game.save and game.save.inventory or {}
    local n=0
    for _,name in ipairs(G1_BADGES) do if owned[name] then n=n+1 end end
    return n
  end

  local function partyPeakLevel(game,limit)
    local party=game and game.save and game.save.party or {}
    local n=limit or #party
    local peak=1
    for i=1,math.min(#party,n) do
      peak=math.max(peak,tonumber(party[i] and party[i].level) or 1)
    end
    return peak
  end

  -- 1.3.30: seed-guided world progression for LOGIC Random Start.
  -- Keep the implementation behind one table so the already-large module
  -- stays under Lua 5.1/LuaJIT's 200-local limit.
  local Route={
    exclude={
      "POKECENTER","_MART","MART_","_HOUSE","HOUSE_","_HOME","HOME_","_LAB","LAB_",
      "BEDROOM","_ROOM","ROOM_","GAME_CORNER","DEPT_STORE","NAME_RATER","BIKE_SHOP",
      "DAY_CARE","SCHOOL","FAN_CLUB","TRADE_HOUSE","PLAYERS_HOUSE","RIVALS_HOUSE",
    },
    relevant={
      "ROUTE_","CITY","TOWN","GYM","CAVE","FOREST","TUNNEL","TOWER","ROAD","ISLAND",
      "MANSION","PATH","WELL","LAKE","DEN","LIGHTHOUSE","PLATEAU","RUINS","PARK",
      "MT_","VICTORY_ROAD","SEAFOAM","SILVER_CAVE","ILEX","WHIRL","TOHJO","ROCK_TUNNEL",
    },
    transit={"_GATE","GATE_","ENTRANCE","PASSAGE"},
  }

  function Route.human(v)
    local text=tostring(v or "?"):gsub("^TEXT_",""):gsub("_"," "):lower()
    return (text:gsub("(%a)([%w']*)",function(a,b) return a:upper()..b end))
  end

  function Route.systemActive(a)
    -- 2.0.0: LOGIC Random Start always owns one deterministic authored route.
    -- Level safety comes from the route/sphere baseline itself, never from
    -- party-relative rubber-banding or synthetic roadblocks.
    return a and a.cfg and a.cfg.random_start=="LOGIC"
      and a.progression and a.progression.start
  end

  function Route.levelAverage(root)
    if type(root)~="table" then return nil,0 end
    local sum,n=0,0
    local seen={}
    local function scan(row,depth)
      if depth>7 or type(row)~="table" or seen[row] then return end
      seen[row]=true
      local lv=tonumber(row.level)
      if lv and lv>0 and lv<=100 then sum=sum+lv; n=n+1 end
      for _,value in pairs(row) do if type(value)=="table" then scan(value,depth+1) end end
    end
    scan(root,0)
    return n>0 and (sum/n) or nil,n
  end

  function Route.gen2Party(a,classId,memberId)
    local trainers=a and a.game and a.game.data and (a.game.data.gen2Trainers or a.game.data.trainers)
    local classes=trainers and trainers.classes or {}
    a.routeGen2ClassByIndex=a.routeGen2ClassByIndex or {}
    local key=tonumber(classId)
    local cls=key and a.routeGen2ClassByIndex[key] or nil
    if not cls and key then
      for _,row in pairs(classes) do if tonumber(row and row.index)==key then cls=row; break end end
      a.routeGen2ClassByIndex[key]=cls or false
    elseif cls==false then cls=nil end
    local trainer=cls and cls.trainers and cls.trainers[tonumber(memberId) or 1]
    return trainer and trainer.party or nil
  end

  function Route.dangerStats(a,mapId)
    if not a or not a.game then return nil end
    mapId=tostring(mapId or "")
    a.routeDangerCache=a.routeDangerCache or {}
    if a.routeDangerCache[mapId] then return a.routeDangerCache[mapId] end
    local data=a.game.data or {}
    local maps=mapTable(a.game)
    local def=maps and maps[mapId]
    if not def then
      a.routeDangerCache[mapId]={danger=nil,wild=nil,trainer=nil,wildCount=0,trainerCount=0}
      return a.routeDangerCache[mapId]
    end
    local wildSum,wildN=0,0
    local function addWild(root)
      local avg,n=Route.levelAverage(root)
      if avg and n>0 then wildSum=wildSum+avg*n; wildN=wildN+n end
    end
    if a.generation==1 then
      local enc=data.encounters and data.encounters[mapId]
      if enc then addWild(enc.grass); addWild(enc.water) end
    else
      local enc=data.gen2Encounters or data.encounters or {}
      addWild(enc.grass and enc.grass[mapId])
      addWild(enc.water and enc.water[mapId])
    end
    local trainerSum,trainerN=0,0
    local trainers=data.trainers or {}
    for _,obj in ipairs(def.objects or {}) do
      local party=nil
      if a.generation==1 and obj.trainerClass then
        local cls=trainers[obj.trainerClass]
        party=cls and cls.parties and cls.parties[tonumber(obj.trainerParty) or 1]
      elseif a.generation==2 and type(obj.trainer)=="table" then
        party=Route.gen2Party(a,obj.trainer.class,obj.trainer.member)
      end
      if party then
        local avg,n=Route.levelAverage(party)
        if avg and n>0 then trainerSum=trainerSum+avg*n; trainerN=trainerN+n end
      end
    end
    local wild=wildN>0 and wildSum/wildN or nil
    local trainer=trainerN>0 and trainerSum/trainerN or nil
    local danger=(wild and trainer) and ((wild+trainer)/2) or wild or trainer
    a.routeDangerCache[mapId]={danger=danger,wild=wild,trainer=trainer,wildCount=wildN,trainerCount=trainerN}
    return a.routeDangerCache[mapId]
  end

  function Route.contains(id,patterns)
    id=tostring(id or ""):upper()
    for _,pat in ipairs(patterns) do if id:find(pat,1,true) then return true end end
    return false
  end

  function Route.relevantMap(a,mapId)
    local id=tostring(mapId or ""):upper()
    if id=="" then return false end
    -- Authored start-proof objectives are relevant even when they are normally
    -- quiet interiors (Kurt's house, Saffron Mart, Dance Theater, etc.).
    -- Without this exception the danger scanner discarded the very story
    -- objective that makes several fresh Random Starts escapable.
    local startId=a and a.progression and a.progression.start and a.progression.start.id
    if Logic and Logic.preferredRank and Logic.preferredRank(a and a.generation,startId,nil,id) then return true end
    local stats=Route.dangerStats(a,id)
    if stats and stats.danger then return true end
    if Route.contains(id,Route.exclude) then return false end
    return Route.contains(id,Route.relevant)
  end

  function Route.transitMap(a,mapId)
    local id=tostring(mapId or ""):upper()
    if id=="" or Route.relevantMap(a,id) then return false end
    return Route.contains(id,Route.transit)
  end

  function Route.dest(row)
    return type(row)=="table" and (row.mapId or row.destMap or row.map) or nil
  end

  function Route.directSteps(a,mapId)
    local def=mapTable(a.game)[mapId]
    local out={}
    if not def then return out end
    for dir,row in pairs(def.connections or {}) do
      local dest=Route.dest(row)
      if dest then out[#out+1]={kind="connection",dir=tostring(dir),dest=tostring(dest),conn=row} end
    end
    for i,w in ipairs(def.warps or {}) do
      local dest=Route.dest(w)
      if dest then out[#out+1]={kind="warp",warpIndex=i,dest=tostring(dest),warp=w} end
    end
    return out
  end

  function Route.neighbors(a,mapId)
    local out,seen={},{}
    local function add(dest,first,via)
      dest=tostring(dest or "")
      if dest=="" or dest==tostring(mapId) or seen[dest] or not Route.relevantMap(a,dest) then return end
      seen[dest]=true; out[#out+1]={id=dest,first=first,via=via}
    end
    for _,step in ipairs(Route.directSteps(a,mapId)) do
      if Route.relevantMap(a,step.dest) then
        add(step.dest,step,nil)
      elseif Route.transitMap(a,step.dest) then
        for _,second in ipairs(Route.directSteps(a,step.dest)) do
          if second.dest~=mapId and Route.relevantMap(a,second.dest) then add(second.dest,step,step.dest) end
        end
      end
    end
    return out
  end

  function Route.dangerForGate(a,mapId)
    local stats=Route.dangerStats(a,mapId)
    if not stats or not stats.danger then return nil,stats end
    local wild,trainer=stats.wild,stats.trainer
    if R.percentageScalingEnabled and R.percentageScalingEnabled(a) then
      if wild then wild=wild*(100+(tonumber(a.cfg.wild_levels) or 0))/100 end
      if trainer then trainer=trainer*(100+(tonumber(a.cfg.trainer_levels) or 0))/100 end
    end
    local danger=(wild and trainer) and ((wild+trainer)/2) or wild or trainer
    return danger,{danger=danger,wild=wild,trainer=trainer}
  end

  function Route.state(a)
    if not a.routeState then a.routeState={visited={},current=nil,target=nil,guidedMap=nil,offRoute=false} end
    a.routeState.visited=a.routeState.visited or {}
    return a.routeState
  end

  function Route.persist(a)
    if not a or not a.routeState or not mod.save:get("seed",nil) then return end
    local copy=Core.copy(a.routeState); copy.guidedMap=nil; copy.offRouteMap=nil
    mod.save:set("route_state",copy)
  end

  function Route.recordForTarget(a,mapId,target)
    if not target then return nil end
    for _,row in ipairs(Route.neighbors(a,mapId)) do if row.id==target then return row end end
    return nil
  end

  function Route.chooseTarget(a,mapId,fromMapId)
    local st=Route.state(a)
    local rows=Route.neighbors(a,mapId)
    if #rows==0 then return nil end
    -- 2.0.0: adjacency is not reachability.  Filter known HM/water gates
    -- before scoring so a low-level map on the far side of Surf can never be
    -- selected as the first "safe" objective (the 1.3.42 Cinnabar bug).
    if Logic and a and a.progression and a.progression.start then
      local start=tostring(a.progression.start.id or "")
      local filtered={}
      for _,row in ipairs(rows) do
        local req=Logic.edgeRequirement(a.generation,tostring(mapId),tostring(row.id))
        local blocked=req and req.move and not (R.fieldMoveUsable and R.fieldMoveUsable(a,req.move))
        -- Alternate edges may be physically bypassed by an ordinary land route;
        -- keep them as candidates but never prefer them over a proven local leg.
        if not blocked or (req and req.alternate) then filtered[#filtered+1]=row end
      end
      rows=filtered
      if #rows==0 then return nil end
    end
    local function pool(pred)
      local p={}; for _,row in ipairs(rows) do if pred(row) then p[#p+1]=row end end; return p
    end
    local candidates=pool(function(r) return not st.visited[r.id] and r.id~=fromMapId end)
    if #candidates==0 then candidates=pool(function(r) return not st.visited[r.id] end) end
    if #candidates==0 then candidates=pool(function(r) return r.id~=fromMapId end) end
    if #candidates==0 then candidates=rows end
    -- First-leg guidance is world-state based, never party-level based.
    -- This keeps the complete LOGIC route deterministic for the same
    -- seed/settings even if a save is inspected with a differently leveled party.
    local firstLeg=a and a.progression and a.progression.start
      and tostring(a.progression.start.id or "")==tostring(mapId)
      and (tonumber(st.routeLegsCompleted) or 0)==0
    local function score(row)
      local startId=a and a.progression and a.progression.start and a.progression.start.id
      local policyRank=Logic and Logic.preferredRank(a.generation,startId,mapId,row.id) or nil
      local danger=select(1,Route.dangerForGate(a,row.id)) or 90
      local stats=Route.dangerStats(a,row.id)
      -- Fresh Random Starts need a catchable grinding lane first. Without this
      -- preference Celadon could seed GAME CORNER -> ROCKET HIDEOUT as its
      -- "safe" path: trainer levels were protected, but the player had no low-
      -- level wild pool to build a team. Prefer a neighboring map with actual
      -- wild encounters for the first leg whenever one exists.
      local catchPenalty=(firstLeg and (not stats or not stats.wild)) and 50 or 0
      local gymPenalty=tostring(row.id):find("GYM",1,true) and 5 or 0
      local h=math.abs(tonumber(Core.hash("guided-route|"..tostring(mapId).."|"..row.id,a.seed)) or 0)
      -- An authored progression proof outranks danger scoring.  The rank is
      -- intentionally a large negative term so Cinnabar Mansion / Cianwood Gym
      -- cannot lose to an inaccessible water route on any seed.
      -- Authored proof order is lexicographically dominant.  Route danger,
      -- catch-lane preference and seeded tie-breaking may rank candidates only
      -- *within* the same proof priority; they must never promote proof step 2
      -- ahead of proof step 1 (for example Saffron Route 8 over the local Mart).
      local proofBonus=policyRank and (-100000+(policyRank*1000)) or 0
      return proofBonus+danger+catchPenalty+gymPenalty+(h%2501)/1000
    end
    table.sort(candidates,function(x,y)
      local sx,sy=score(x),score(y)
      if sx==sy then return x.id<y.id end
      return sx<sy
    end)
    return candidates[1]
  end

  -- Protection Guards were removed from the 2.0.0 runtime.  Keep only tiny
  -- compatibility no-ops for older companion mods/saves that may still call
  -- the exported API; no NPCs or level-gated seams can be created.
  function Route.clearGuards(a)
    if not a then return end
    if mod.world and mod.world.removeNpc then
      for _,id in ipairs(a.routeGuardIds or {}) do pcall(mod.world.removeNpc,mod.world,id) end
    end
    a.routeGuardIds={}
  end

  function Route.currentMapId(a)
    local world=a and a.game and (a.game.world or a.game.overworld)
    return tostring(world and world.map and world.map.id or "")
  end

  function Route.activeFor(game)
    local a=Runtime.active
    if a and (not game or a.game==game) then return a end
    if game and R.activateSaved then
      local ok,recovered=pcall(R.activateSaved,game); if ok and recovered then return recovered end
    end
    return Runtime.active
  end

  function R.refreshRouteRoadblocks(game,mapId)
    local a=Route.activeFor(game)
    if a then Route.clearGuards(a) end
    return true,0
  end

  function R.routeConnectionBlocked(game,mapId,destMapId)
    return false
  end

  function R.onMapEntered(game,mapId,fromMapId)
    local a=Route.activeFor(game)
    if not a then return false end
    mapId=tostring(mapId or Route.currentMapId(a)); fromMapId=tostring(fromMapId or "")
    if mapId~="" then a.routeRuntimeMapId=mapId end
    Route.clearGuards(a)
    if not Route.systemActive(a) or not a.randomStartUsed then return false end
    if mapId=="" then return false end
    local st=Route.state(a)
    if not st.current then
      st.current=mapId; st.guidedMap=mapId; st.offRoute=false; st.visited[mapId]=true
      local pick=Route.chooseTarget(a,mapId,fromMapId); st.target=pick and pick.id or nil
    elseif mapId==st.target then
      local done=tonumber(st.routeLegsCompleted)
      if done==nil then
        local visited=0
        for _,seen in pairs(st.visited or {}) do if seen then visited=visited+1 end end
        done=math.max(0,visited-1)
      end
      st.routeLegsCompleted=math.max(0,done)+1
      st.current=mapId; st.guidedMap=mapId; st.offRoute=false; st.offRouteMap=nil; st.visited[mapId]=true
      local pick=Route.chooseTarget(a,mapId,fromMapId); st.target=pick and pick.id or nil
    elseif mapId==st.current then
      st.guidedMap=mapId; st.offRoute=false; st.offRouteMap=nil
    else
      local rec=Route.recordForTarget(a,st.current,st.target)
      if rec and rec.via and tostring(rec.first and rec.first.dest or "")==mapId then
        st.guidedMap=nil; st.offRoute=false; st.offRouteMap=nil
      else
        st.guidedMap=nil; st.offRoute=true; st.offRouteMap=mapId
      end
    end
    Route.persist(a)
    return true,Core.copy(st)
  end

  function R.routeProgressionState(game)
    local a=Route.activeFor(game)
    if not a or not Route.systemActive(a) then return nil end
    return Core.copy(Route.state(a))
  end

  -- Internal deterministic test seam used by the 2.0.0 progression audit.
  -- It exposes only the selected map id, not mutable Route internals.
  function R._auditRouteTarget(a,mapId,fromMapId)
    local row=Route.chooseTarget(a,tostring(mapId or ""),fromMapId)
    return row and row.id or nil
  end

  function R._auditRouteFirstStep(a,mapId,target)
    local row=Route.recordForTarget(a,tostring(mapId or ""),target)
    local first=row and row.first or nil
    if not first then return nil end
    return {kind=first.kind,dest=first.dest,warpIndex=first.warpIndex,warp=first.warp}
  end

  function R._routeProgressionMax(a,mapId,kind,isBoss)
    if not (R.randomStartLevelCapsEnabled and R.randomStartLevelCapsEnabled(a)) then return nil end
    if not Route.systemActive(a) or not a.randomStartUsed then return nil end
    local st=Route.state(a)
    mapId=tostring(mapId or Route.currentMapId(a))
    if mapId=="" or tostring(st.guidedMap or "")~=mapId then return nil end
    local peak=partyPeakLevel(a.game)
    local completed=math.max(0,tonumber(st.routeLegsCompleted) or 0)
    local sphereBase=Logic and Logic.sphereLevel and Logic.sphereLevel(a.cfg.sphere_curve or "VANILLA",math.max(0,completed-1),isBoss and "boss" or kind,a.generation,7,49,14) or nil
    if isBoss or kind=="boss" then
      local relative=math.max(5,math.min(100,peak+3))
      return sphereBase and math.max(relative,sphereBase) or relative
    end
    if kind=="trainer" then
      local relative=math.max(3,math.min(100,peak+1))
      return sphereBase and math.max(relative,sphereBase) or relative
    end
    local relative=math.max(2,math.min(100,peak+1))
    return sphereBase and math.max(relative,sphereBase) or relative
  end

  function R.routeHint()
    local a=Runtime.active
    if not a or not Route.systemActive(a) or not a.randomStartUsed then return nil end
    local st=Route.state(a)
    if not st.current or not st.target then return nil end
    if st.offRoute then
      return ("Progression hint: return to %s. Your seeded route continues toward %s."):format(Route.human(st.current),Route.human(st.target))
    end
    local danger=select(1,Route.dangerForGate(a,st.target))
    local suffix=danger and (" Native danger there averages about Lv%d."):format(math.floor(danger+0.5)) or ""
    local policy=" Levels use the deterministic logic/native baseline plus your Wild/Trainer/Boss modifiers."
    return ("Progression hint: head toward %s.%s%s"):format(Route.human(st.target),suffix,policy)
  end

  function R.routeGuardText(target) return nil end

  function R.clearRouteGuards(game)
    local a=(Runtime.active and (not game or Runtime.active.game==game)) and Runtime.active or nil
    if a then Route.clearGuards(a) end
  end

  local G1_START_TRAINER_MAPS={
    LAVENDER_TOWN={ROUTE_8=true},
    FUCHSIA_CITY={FUCHSIA_GYM=true},
    CINNABAR_ISLAND={CINNABAR_GYM=true},
  }

  local function gen1StartTrainerProgressionMax(a,isBoss,mapIdOverride)
    if not (R.randomStartLevelCapsEnabled and R.randomStartLevelCapsEnabled(a)) then return nil end
    if not a or a.generation~=1 or not a.progression or not a.progression.start then return nil end
    local start=tostring(a.progression.start.id or "")
    if not gen1LogicStartActive(a,start) then return nil end
    local world=a.game and (a.game.world or a.game.overworld)
    local mapId=tostring(mapIdOverride or (world and world.map and world.map.id) or "")
    local allowed=G1_START_TRAINER_MAPS[start]
    if not allowed or not allowed[mapId] then return nil end
    -- Route 8 is an escape corridor, never a boss arena.
    if mapId=="ROUTE_8" and isBoss then return nil end
    local badges=gen1KantoBadgeCount(a.game)
    local peak=partyPeakLevel(a.game)
    local floor=(isBoss and 9 or 6)+(badges*4)
    local relative=peak+(isBoss and 3 or 1)
    return math.max(1,math.min(50,math.max(floor,relative)))
  end

  local function gen1StartWildProgressionMax(a,mapId)
    if not (R.randomStartLevelCapsEnabled and R.randomStartLevelCapsEnabled(a)) then return nil end
    if not a or a.generation~=1 or not a.progression or not a.progression.start then return nil end
    local start=tostring(a.progression.start.id or "")
    if not gen1LogicStartActive(a,start) then return nil end
    mapId=tostring(mapId or "")
    local localWild=false
    if start=="CINNABAR_ISLAND" and (mapId=="CINNABAR_ISLAND" or mapId:find("POKEMON_MANSION",1,true)) then
      localWild=true
    elseif start=="FUCHSIA_CITY" and (mapId=="ROUTE_15" or mapId=="ROUTE_14") then
      localWild=true
    elseif start=="LAVENDER_TOWN" and mapId=="ROUTE_8" then
      localWild=true
    end
    if not localWild then return nil end
    local badges=gen1KantoBadgeCount(a.game)
    local peak=partyPeakLevel(a.game)
    return math.max(2,math.min(50,math.max(5+(badges*4),peak+1)))
  end

  -- Cianwood is intentionally kept in the Gen-2 LOGIC random-start pool.
  -- Unlike a normal playthrough, a player can arrive there with only the Elm
  -- starter and zero badges, so vanilla Chuck/gym levels are not a meaningful
  -- progression gate.  The helpers below make that one isolated-start case
  -- self-contained without globally level-scaling Silver's gyms.
  local function cianwoodLogicStartActive(a)
    if not (a and a.generation==2 and a.cfg and a.cfg.random_start=="LOGIC"
        and a.progression and a.progression.start) then return false end
    local proof=Logic and Logic.proof and Logic.proof(2,tostring(a.progression.start.id or "")) or nil
    if not proof then return false end
    for _,lock in ipairs(proof.badgeLocks or {}) do
      if tostring(lock.gym)=="CIANWOOD_CITY" and tostring(lock.badge)=="STORM" then return true end
    end
    return false
  end

  local function gen2JohtoBadgeCount(game)
    local owned=game and game.save and game.save.player and game.save.player.badges or {}
    local n=0
    for i,name in ipairs(G2_BADGES) do
      if owned[name]==true or owned[i]==true then n=n+1 end
    end
    return n
  end

  -- 1.3.29: a LOGIC Random Start can place a fresh Elm starter beside
  -- mid/late-game Crystal/Gold/Silver encounter tables. Progression mode used
  -- to keep native content as an unconditional floor, so a Blackthorn/Mahogany
  -- start could still have only Lv20-30 wilds at 0 PCT. Treat the landing hub,
  -- its directly connected outdoor maps, and encounter-bearing direct warps as
  -- a temporary local progression zone. This is a safety ceiling only; it does
  -- not alter normal non-Random-Start progression or CHAOS starts.
  function R._gen2LogicStartActive(a)
    return a and a.generation==2 and a.cfg and a.cfg.random_start=="LOGIC"
      and a.progression and a.progression.start and a.progression.start.id
  end

  function R._gen2StartLocalMapSet(a,forTrainers)
    if not R._gen2LogicStartActive(a) then return nil end
    local start=tostring(a.progression.start.id or "")
    local cacheKey=forTrainers and "_urG2StartTrainerMaps" or "_urG2StartWildMaps"
    local cached=a[cacheKey]
    if cached and cached.start==start then return cached.maps end
    local out={[start]=true}
    local maps=a.game and a.game.data and (a.game.data.gen2Maps or a.game.data.maps) or {}
    local def=maps and maps[start]
    for _,row in pairs((def and def.connections) or {}) do
      if type(row)=="table" then
        local dm=tostring(row.mapId or row.destMap or row.map or "")
        if dm~="" then out[dm]=true end
      end
    end
    if forTrainers then
      local sourceBadge=G2_GYM_SOURCE[start]
      if sourceBadge then
        for gymMap,badge in pairs(G2_GYM_MAP_SOURCE) do
          if badge==sourceBadge then out[gymMap]=true end
        end
      end
    else
      -- Direct cave/tower/den entrances can be the first catchable area at
      -- some starts (notably Blackthorn/Ecruteak). Harmless building warps are
      -- included too, but have no encounter hook to transform.
      for _,row in ipairs((def and def.warps) or {}) do
        if type(row)=="table" then
          local dm=tostring(row.destMap or row.mapId or row.map or "")
          if dm~="" then out[dm]=true end
        end
      end
    end
    a[cacheKey]={start=start,maps=out}
    return out
  end

  function R._gen2StartWildProgressionMax(a,mapId)
    if not (R.randomStartLevelCapsEnabled and R.randomStartLevelCapsEnabled(a)) then return nil end
    local localMaps=R._gen2StartLocalMapSet(a,false)
    mapId=tostring(mapId or "")
    if not localMaps or not localMaps[mapId] then return nil end
    local badges=gen2JohtoBadgeCount(a.game)
    local peak=partyPeakLevel(a.game)
    return math.max(2,math.min(50,math.max(5+(badges*4),peak+1)))
  end

  function R._gen2StartTrainerProgressionMax(a,isBoss,mapIdOverride)
    if not (R.randomStartLevelCapsEnabled and R.randomStartLevelCapsEnabled(a)) then return nil end
    local localMaps=R._gen2StartLocalMapSet(a,true)
    if not localMaps then return nil end
    local world=a.game and (a.game.world or a.game.overworld)
    local mapId=tostring(mapIdOverride or (world and world.map and world.map.id) or "")
    if not localMaps[mapId] then return nil end
    local badges=gen2JohtoBadgeCount(a.game)
    local peak=partyPeakLevel(a.game)
    local floor=(isBoss and 9 or 6)+(badges*4)
    local relative=peak+(isBoss and 3 or 1)
    return math.max(1,math.min(50,math.max(floor,relative)))
  end

  local function cianwoodGymProgressionMax(a,isBoss)
    if not (R.randomStartLevelCapsEnabled and R.randomStartLevelCapsEnabled(a)) then return nil end
    if not cianwoodLogicStartActive(a) then return nil end
    local world=a.game and (a.game.world or a.game.overworld)
    local map=world and world.map
    if tostring(map and map.id or "")~="CIANWOOD_GYM" then return nil end
    local badges=gen2JohtoBadgeCount(a.game)
    local peak=partyPeakLevel(a.game)
    -- Zero-badge starter runs land around Lv6-8 trainers and a Lv9-10 Chuck.
    -- Four-badge/natural Cianwood progression converges on the vanilla band.
    local floor=(isBoss and 9 or 6)+(badges*4)
    local relative=peak+(isBoss and 3 or 1)
    return math.max(1,math.min(45,math.max(floor,relative)))
  end

  local function cianwoodFlyGiftPick(a)
    if not cianwoodLogicStartActive(a) then return nil end
    return selector(a.game,a.cfg,a.seed,"cianwood-fly-gift","SHUCKLE","RANDOM",
      function(id)
        local def=a.game and a.game.data and a.game.data.pokemon and a.game.data.pokemon[id]
        if not def then return false end
        for _,m in ipairs(def.tmhm or {}) do if tostring(m):upper()=="FLY" then return true end end
        return false
      end)
  end

  local function cianwoodFlyGiftLevel(a,partyCountBefore)
    -- 2.0.0 never derives levels from the player's party. Mania's utility gift
    -- keeps its authored Lv15 while only species/compatibility is adapted.
    return 15
  end

  -- Audit seams used by the exact-ROM 2.0.0 certification harness.  These are
  -- read-only helpers; runtime behavior still goes through the normal hooks.
  R._cianwoodFlyGiftPick=cianwoodFlyGiftPick
  R._cianwoodFlyGiftLevel=cianwoodFlyGiftLevel
  R._cianwoodFlyProofActive=cianwoodLogicStartActive

  -- 2.0.0: one level model for every randomized run. Native/randomized
  -- encounter tables plus the LOGIC Random Start sphere establish a fully
  -- deterministic baseline. Wild/Trainer/Boss percentages are always applied
  -- afterward. These compatibility helpers deliberately report the old
  -- PERCENTAGE semantics so older companion code keeps working without
  -- reintroducing party-relative scaling.
  function R.levelMode(a) return "PERCENTAGE" end
  function R.progressionScalingEnabled(a) return false end
  function R.percentageScalingEnabled(a) return true end
  function R.pureProgressionEnabled(a) return false end
  function R.hybridScalingEnabled(a) return false end
  function R.randomStartLevelCapsEnabled(a) return false end

  -- 2.0.0 LOGIC sphere baseline. The helper keeps its historical export name
  -- for compatibility, but it is now the sole Random Start level baseline.
  -- It is route-position based and therefore identical for Lv5 and Lv80 parties.
  function R._percentageRouteBaselineMax(a,mapId,kind,isBoss)
    if not Route.systemActive(a) or not a.randomStartUsed then return nil end
    local st=Route.state(a)
    mapId=tostring(mapId or Route.currentMapId(a))
    if mapId=="" or tostring(st.guidedMap or "")~=mapId then return nil end
    local completed=tonumber(st.routeLegsCompleted)
    if completed==nil then
      local visited=0
      for _,seen in pairs(st.visited or {}) do if seen then visited=visited+1 end end
      completed=math.max(0,visited-1)
    end
    completed=math.max(0,completed)
    local sphere=math.max(0,completed-1)
    if Logic and Logic.sphereLevel then
      return Logic.sphereLevel(a.cfg.sphere_curve or "VANILLA",sphere,isBoss and "boss" or kind,a.generation,7,49,14)
    end
    local step=math.min(14,sphere)*3
    if isBoss or kind=="boss" then return math.min(54,12+step) end
    if kind=="trainer" then return math.min(51,9+step) end
    return math.min(49,7+step)
  end

  -- raises content that the player has out-grown. Category percentages are
  -- applied afterward only in PERCENTAGE/HYBRID mode.
  local function progressionAnchor(a,kind)
    local peak=partyPeakLevel(a and a.game)
    if kind=="boss" then return math.max(1,peak+3) end
    if kind=="trainer" then return math.max(1,peak+1) end
    return math.max(1,peak-1) -- wild/static/gift
  end

  function R.staticLevelScalingActive(a)
    if not a or not a.cfg then return false end
    if R.progressionScalingEnabled(a) then return true end
    return a.cfg.statics~="UNCHANGED" or ((tonumber(a.cfg.wild_levels) or 0)~=0 and R.percentageScalingEnabled(a))
  end

  local function scaleStaticEnemyLevel(a,level,mapId,key)
    level=tonumber(level)
    if not a or not level or not R.staticLevelScalingActive(a) then return level end
    local anchor=level
    if R.pureProgressionEnabled(a) then
      anchor=progressionAnchor(a,"wild")
    elseif R.progressionScalingEnabled(a) then
      anchor=math.max(anchor,progressionAnchor(a,"wild"))
    end
    local routeCap=R._routeProgressionMax(a,mapId,"wild",false)
    local percentageRouteCap=R._percentageRouteBaselineMax(a,mapId,"wild",false)
    if percentageRouteCap then routeCap=routeCap and math.min(routeCap,percentageRouteCap) or percentageRouteCap end
    if routeCap then anchor=math.min(anchor,routeCap) end
    local startCap=nil
    if not R.pureProgressionEnabled(a) then
      startCap=gen1StartWildProgressionMax(a,mapId) or R._gen2StartWildProgressionMax(a,mapId)
    end
    if startCap then anchor=math.min(anchor,startCap) end
    local pct=R.percentageScalingEnabled(a) and (tonumber(a.cfg and a.cfg.wild_levels) or 0) or 0
    if pct~=0 then anchor=math.floor(anchor*(100+pct)/100+0.5) end
    return math.max(1,math.min(100,anchor))
  end

  local function scaleGiftLevel(a,level)
    level=tonumber(level)
    if not a or not level or not a.cfg then return level end
    -- Pure PROGRESSION owns levels independently from species-randomization
    -- toggles, so even a vanilla-species gift follows the player's current
    -- progression. HYBRID retains the older raise-only behavior. Percentage
    -- mode never changes a gift's authored level through Wild %.
    if not R.progressionScalingEnabled(a) then return level end
    local target=progressionAnchor(a,"gift")
    if R.pureProgressionEnabled(a) then
      return math.max(1,math.min(100,target))
    end
    if a.cfg.statics=="UNCHANGED" then return level end
    return math.max(1,math.min(100,math.max(level,target)))
  end


  local function solveCianwoodStartBoulders(a)
    if not cianwoodLogicStartActive(a) then return false end
    local world=a.game and (a.game.world or a.game.overworld)
    if not world or not world.map or tostring(world.map.id)~="CIANWOOD_GYM" then return false end
    local rocks={}
    for _,npc in ipairs(world.npcs or {}) do
      local def=npc and npc.def or {}
      -- SPRITEMOVEDATA_STRENGTH_BOULDER is $19 in Gen 2.  Use both the
      -- movement byte and the cart-authored row coordinates so no unrelated
      -- object can be moved by this isolated-start exception.
      if tonumber(def.movement)==0x19 and tonumber(npc.cellY)==7
          and (tonumber(npc.cellX)==3 or tonumber(npc.cellX)==4 or tonumber(npc.cellX)==5) then
        rocks[tonumber(npc.cellX)]=npc
      end
    end
    if not (rocks[3] and rocks[4] and rocks[5]) then return false end
    local function place(npc,x,y)
      npc.cellX,npc.cellY=x,y
      npc.px,npc.py=x*16,y*16
      npc.targetX,npc.targetY=nil,nil
      npc.moving=false
    end
    -- Same solved arrangement used by the host's field driver: outer rocks
    -- north, center rock west, leaving the x=4 lane to Chuck open.
    place(rocks[3],3,6)
    place(rocks[5],5,6)
    place(rocks[4],3,7)
    return true
  end
  R._solveCianwoodStartBoulders=solveCianwoodStartBoulders
  local HM_BADGE_G1={SURF="SOULBADGE",FLY="THUNDERBADGE",CUT="CASCADEBADGE",STRENGTH="RAINBOWBADGE",FLASH="BOULDERBADGE"}
  local HM_BADGE_G2={SURF="FOG",FLY="STORM",CUT="HIVE",STRENGTH="PLAIN",FLASH="ZEPHYR",WHIRLPOOL="GLACIER",WATERFALL="RISING"}
  local START_REQUIREMENTS={
    [1]={
      CINNABAR_ISLAND={oneOf={"SURF","FLY"},areas={"CINNABAR","POKEMON_MANSION"},gym="CINNABAR_ISLAND"},
    },
    [2]={ CIANWOOD_CITY={oneOf={"FLY"},areas={"CIANWOOD"},gym="CIANWOOD_CITY"} },
  }

  Runtime.LEGACY_START_REQUIREMENTS={
    [1]={
      FUCHSIA_CITY={oneOf={"SURF"},areas={"FUCHSIA","SAFARI_ZONE"},gym="FUCHSIA_CITY"},
      CINNABAR_ISLAND={oneOf={"SURF","FLY"},areas={"CINNABAR","POKEMON_MANSION"},gym="CINNABAR_ISLAND"},
    },
    [2]={ CIANWOOD_CITY={oneOf={"FLY"},areas={"CIANWOOD"},gym="CIANWOOD_CITY"} },
  }

  local function hmItemForMove(game,move)
    for id,def in pairs(game.data.items or {}) do
      if machineKind(def,id)=="HM" and tostring(machineMove(def))==tostring(move) then return id end
    end
    return nil
  end


  -- -----------------------------------------------------------------------
  -- 2.0 graph-driven progression item fill
  -- -----------------------------------------------------------------------
  -- These are the progression rewards whose *location semantics* are proven
  -- in the 0.2.24 host.  We deliberately do not guess at direct/special
  -- rewards that bypass the generic item command.  LOGIC RANDOM permutes this
  -- pool with restrictive forward fill; ordinary field items/TMs are filled
  -- afterward by the normal safe pools.
  R._LOGIC_ITEM_DEFS={
    [1]={
      {key="BILL_TICKET",item="S_S_TICKET",map="BILLS_HOUSE",kind="script",class="PROGRESSION",region="EARLY"},
      {key="SS_ANNE_CUT",item="HM_CUT",map="SS_ANNE_CAPTAINS_ROOM",kind="script",class="PROGRESSION",region="SS_ANNE",requires={"S_S_TICKET"}},
      {key="OAK_AIDE_FLASH",item="HM_FLASH",map="ROUTE_2_GATE",kind="direct",class="USEFUL",region="ROUTE2_EAST"},
      {key="ROUTE_FAN_VOUCHER",item="BIKE_VOUCHER",map="POKEMON_FAN_CLUB",kind="script",class="USEFUL",region="VERMILION"},
      {key="BIKE_SHOP_BICYCLE",item="BICYCLE",map="BIKE_SHOP",kind="direct",class="USEFUL",region="EARLY",requires={"BIKE_VOUCHER"}},
      {key="ROUTE16_FLY",item="HM_FLY",map="ROUTE_16_FLY_HOUSE",kind="direct",class="USEFUL",region="CELADON",requires={"HM_CUT"}},
      {key="ROCKET_LIFT",item="LIFT_KEY",map="ROCKET_HIDEOUT_B4F",kind="field",class="PROGRESSION",region="ROCKET"},
      {key="ROCKET_SCOPE",item="SILPH_SCOPE",map="ROCKET_HIDEOUT_B4F",kind="field",class="PROGRESSION",region="ROCKET",requires={"LIFT_KEY"}},
      {key="FUJI_FLUTE",item="POKE_FLUTE",map="MR_FUJIS_HOUSE",kind="script",class="PROGRESSION",region="TOWER",requires={"SILPH_SCOPE"}},
      {key="SAFARI_TEETH",item="GOLD_TEETH",map="SAFARI_ZONE_WEST",kind="field",class="PROGRESSION",region="FUCHSIA",requires={"POKE_FLUTE"},startBypass={FUCHSIA_CITY=true},startBypassItems={"POKE_FLUTE"}},
      {key="SAFARI_SURF",item="HM_SURF",map="SAFARI_ZONE_SECRET_HOUSE",kind="script",class="PROGRESSION",region="FUCHSIA",requires={"POKE_FLUTE"},startBypass={FUCHSIA_CITY=true},startBypassItems={"POKE_FLUTE"}},
      {key="WARDEN_STRENGTH",item="HM_STRENGTH",map="WARDENS_HOUSE",kind="script",class="PROGRESSION",region="FUCHSIA",requires={"POKE_FLUTE","GOLD_TEETH"},startBypass={FUCHSIA_CITY=true},startBypassItems={"POKE_FLUTE"}},
      {key="SILPH_CARD",item="CARD_KEY",map="SILPH_CO_5F",kind="field",class="PROGRESSION",region="SAFFRON"},
      {key="MANSION_SECRET",item="SECRET_KEY",map="POKEMON_MANSION_B1F",kind="field",class="PROGRESSION",region="CINNABAR",requires={"HM_SURF"},startBypass={CINNABAR_ISLAND=true},startBypassItems={"HM_SURF"}},
    },
    [2]={
      {key="MYSTERY_EGG",item="MYSTERY_EGG",map="MR_POKEMONS_HOUSE",kind="script",class="PROGRESSION",region="EARLY"},
      {key="SPROUT_FLASH",item="HM_FLASH",map="SPROUT_TOWER_3F",kind="script",class="USEFUL",region="VIOLET"},
      {key="ILEX_CUT",item="HM_CUT",map="ILEX_FOREST",kind="script",class="PROGRESSION",region="AZALEA"},
      {key="FLOWER_SQUIRT",item="SQUIRTBOTTLE",map="GOLDENROD_FLOWER_SHOP",kind="script",class="PROGRESSION",region="GOLDENROD",requires={"BADGE_PLAIN"}},
      -- TM08 ROCK SMASH is a real Crystal/GS progression dependency: the
      -- Route 36 reward is needed for the Burned Tower route before Morty.
      -- Treat it as a restrictive-fill progression item instead of hoping an
      -- ordinary randomized TM slot happens to make it available in time.
      {key="ROUTE36_ROCK_SMASH",item="TM_ROCK_SMASH",map="ROUTE_36",kind="script",class="PROGRESSION",region="GOLDENROD",requires={"SQUIRTBOTTLE"}},
      {key="DANCE_SURF",item="HM_SURF",map="DANCE_THEATER",kind="script",class="PROGRESSION",region="ECRUTEAK"},
      {key="OLIVINE_STRENGTH",item="HM_STRENGTH",map="OLIVINE_CAFE",kind="script",class="PROGRESSION",region="OLIVINE"},
      {key="CIANWOOD_SECRET",item="SECRETPOTION",map="CIANWOOD_PHARMACY",kind="script",class="PROGRESSION",region="CIANWOOD"},
      {key="CIANWOOD_FLY",item="HM_FLY",map="CIANWOOD_CITY",kind="script",class="USEFUL",region="CIANWOOD",requires={"GYM_STORM","BADGE_STORM"}},
      {key="ROCKET_WHIRL",item="HM_WHIRLPOOL",map="TEAM_ROCKET_BASE_B2F",kind="script",class="PROGRESSION",region="MAHOGANY",requires={"HM_SURF"}},
      {key="RADIO_BASEMENT",item="BASEMENT_KEY",map="RADIO_TOWER_5F",kind="script",class="PROGRESSION",region="RADIO"},
      {key="WAREHOUSE_CARD",item="CARD_KEY",map="GOLDENROD_UNDERGROUND_WAREHOUSE",kind="script",class="PROGRESSION",region="RADIO",requires={"BASEMENT_KEY"}},
      {key="ICE_WATERFALL",item="HM_WATERFALL",map="ICE_PATH_1F",kind="field",class="PROGRESSION",region="BLACKTHORN",requires={"BASEMENT_KEY","CARD_KEY"}},
      -- Elm hands the ticket only after the League. Its physical map is early,
      -- but its logical check belongs to POST_LEAGUE.
      {key="ELM_TICKET",item="S_S_TICKET",map="ELMS_LAB",kind="script",class="PROGRESSION",region="POST_LEAGUE",requires={"HM_WATERFALL"}},
      {key="CERULEAN_MACHINE",item="MACHINE_PART",map="CERULEAN_GYM",kind="auto",class="PROGRESSION",region="KANTO_EAST",requires={"S_S_TICKET"}},
      {key="FAN_LOST_ITEM",item="LOST_ITEM",map="POKEMON_FAN_CLUB",kind="script",class="USEFUL",region="KANTO_EAST",requires={"MACHINE_PART"}},
      {key="COPYCAT_PASS",item="PASS",map="COPYCATS_HOUSE_2F",kind="script",class="USEFUL",region="KANTO_EAST",requires={"LOST_ITEM"}},
    },
  }

  function R._logicFieldRefs(game,row)
    local maps=mapTable(game); local m=maps[row.map]; if type(m)~="table" then return nil end
    local refs={}
    for _,obj in ipairs(m.objects or {}) do
      if obj.item~=nil and itemId(game,obj.item)==row.item then refs[#refs+1]={parent=obj,field="item",template=obj.item} end
      if type(obj.itemball)=="table" and obj.itemball.item~=nil and itemId(game,obj.itemball.item)==row.item then refs[#refs+1]={parent=obj.itemball,field="item",template=obj.itemball.item} end
    end
    for _,ev in ipairs(m.bgEvents or {}) do
      if type(ev.hiddenItem)=="table" and ev.hiddenItem.item~=nil and itemId(game,ev.hiddenItem.item)==row.item then refs[#refs+1]={parent=ev.hiddenItem,field="item",template=ev.hiddenItem.item} end
    end
    if generation(game)==1 then
      for _,h in ipairs((game.data.field and game.data.field.hiddenItems and game.data.field.hiddenItems[row.map]) or {}) do
        if h.item~=nil and itemId(game,h.item)==row.item then refs[#refs+1]={parent=h,field="item",template=h.item} end
      end
    end
    return (#refs>0) and refs or nil
  end

  function R._logicItemDefs(game)
    local gen=generation(game); local maps=mapTable(game); local out={}
    for _,row in ipairs(R._LOGIC_ITEM_DEFS[gen] or {}) do
      if game.data.items and game.data.items[row.item] and maps[row.map] then
        local d=Core.copy(row)
        if d.kind=="auto" then d.kind=R._logicFieldRefs(game,d) and "field" or "script" end
        out[#out+1]=d
      end
    end
    return out
  end

  function R._logicItemReqMet(row,state,startId,gen)
    gen=gen or (row and row.generation)
    if Logic and Logic.itemWorldState then
      local _,capabilities=Logic.itemWorldState(gen,startId,state)
      state=capabilities
    end
    local bypass=row.startBypass and row.startBypass[tostring(startId or "")]
    local bypassItems={}
    if bypass then for _,id in ipairs(row.startBypassItems or {}) do bypassItems[id]=true end end
    for _,id in ipairs(row.requires or {}) do
      local move=id:match('^HM_(.+)')
      if not bypassItems[id] and not state[move and ('USE_'..move) or id] then return false end
    end
    if row.anyOf and #row.anyOf>0 then
      local any=false
      for _,set in ipairs(row.anyOf) do
        local ok=true
        for _,id in ipairs(set) do if not bypassItems[id] and not state[id] then ok=false; break end end
        if ok then any=true; break end
      end
      if not any then return false end
    end
    if Logic and Logic.itemRegionReachable then
      local region=row.region or (Logic.itemRegion and Logic.itemRegion(gen,row.map))
      if not region or not Logic.itemRegionReachable(gen,startId,region,state) then return false end
    end
    return true
  end

  function R._logicItemStartId(game,cfg,seed)
    if not cfg or cfg.random_start~="LOGIC" or not Logic or not Logic.logicStarts then return nil end
    local gen=generation(game); local source=Logic.logicStarts(gen); local choices={}
    local fly=game.data.field and game.data.field.flyWarps or {}
    for _,id in ipairs(source or {}) do
      local w=fly[id]
      if type(w)=="table" and w.x~=nil and w.y~=nil then choices[#choices+1]=id end
    end
    if #choices==0 and gen==2 then
      local maps=mapTable(game)
      for _,id in ipairs(source or {}) do
        local m=maps[id]
        for _,w in ipairs((m and m.warps) or {}) do
          local dm=tostring(w.destMap or w.map or "")
          if dm:find("POKECENTER",1,true) and w.x~=nil and w.y~=nil then choices[#choices+1]=id; break end
        end
      end
    end
    if #choices==0 then return nil end
    return Core.rng(Core.hash("random-start",seed)):pick(choices)
  end

  function R._logicItemLocations(game,cfg,startId)
    local gen=generation(game); local defs=R._logicItemDefs(game); local locs={}
    for _,d in ipairs(defs) do
      d.generation=gen
      d.region=d.region or (Logic and Logic.itemRegion and Logic.itemRegion(gen,d.map))
      if d.progressionEligible==nil then d.progressionEligible=(d.class=="PROGRESSION") end
      locs[#locs+1]=d
    end
    -- Ordinary non-TM field checks participate only in the filler layer.
    -- Region reachability is not enough to prove an exact pickup: a field item
    -- can sit behind an internal Card Key door, Surf tile, Cut tree, Whirlpool,
    -- Strength boulder, or other local gate even when its map is reachable.
    -- Until a check-level prerequisite is explicitly authored above, never put
    -- a PROGRESSION item there. This is intentionally conservative and prevents
    -- paper-only item-behind-itself proofs.
    for _,slot in ipairs(fieldSlots(game)) do
      if slot.kind=="ITEM" then
        local mapIds={}; for mapId in pairs(slot.maps or {}) do mapIds[#mapIds+1]=mapId end; table.sort(mapIds)
        if #mapIds==1 then
          local region=Logic and Logic.itemRegion and Logic.itemRegion(gen,mapIds[1]) or nil
          if region then
            local stable=true
            if Logic and Logic.itemLocationDoorStable then stable=Logic.itemLocationDoorStable(game,gen,mapIds[1],cfg and cfg.random_doors,startId) end
            local exactSafe=Logic and Logic.itemExtraProgressionSafe and Logic.itemExtraProgressionSafe(gen,mapIds[1],slot.source) or false
            locs[#locs+1]={key="EXTRA|"..slot.key,item=slot.source,map=mapIds[1],kind="field_extra",class="FILLER",
              slotKey=slot.key,region=region,generation=gen,doorStable=stable,progressionEligible=(not not exactSafe) and stable}
          end
        end
      end
    end
    table.sort(locs,function(a,b) return a.key<b.key end)
    return locs
  end

  local function itemListSet(list)
    local s={}; for _,id in ipairs(list or {}) do s[id]=true end; return s
  end

  function R._buildLogicItemPlan(game,cfg,seed)
    if cfg.field_items~="LOGIC_RANDOM" and cfg.field_items~="CHAOS" then return nil end
    local gen=generation(game); local defs=R._logicItemDefs(game)
    if #defs<8 then return nil,"logic progression-item location pool is incomplete" end
    local startId=R._logicItemStartId(game,cfg,seed)
    local locs=R._logicItemLocations(game,cfg,startId)
    local badgeMap
    if cfg.badges=='SAFE' then
      local why
      badgeMap,why=R._safeBadgeAssignment(gen,seed,startId and {id=startId})
      if not badgeMap then return nil,why end
    end

    local proof=cfg.field_items=="LOGIC_RANDOM" and startId and Logic and Logic.proof and Logic.proof(gen,startId) or nil
    local promoted={}
    -- Fly can be the only legitimate return to the early Johto component
    -- when shuffled Cut/Surf permissions are earned on opposite sides of it.
    if gen==2 and startId then promoted.HM_FLY=true end
    for _,move in ipairs((proof and proof.requiredMoves) or {}) do
      local hm=hmItemForMove(game,move); if hm then promoted[hm]=true end
    end
    for _,d in ipairs(locs) do if promoted[d.item] then d.progressionEligible=true end end

    local progressionItems,usefulItems,authoredSet,byItem={},{},{},{}
    for _,d in ipairs(defs) do
      authoredSet[d.item]=true; byItem[d.item]=d
      if d.class=="PROGRESSION" or promoted[d.item] then progressionItems[#progressionItems+1]=d.item
      else usefulItems[#usefulItems+1]=d.item end
    end
    table.sort(progressionItems); table.sort(usefulItems)

    -- Drop extra modeled checks that cannot be reached even with every authored
    -- item. Authored checks themselves must all remain provably reachable.
    local allState={_badges=badgeMap}; for id in pairs(authoredSet) do allState[id]=true end
    local filtered={}
    for _,d in ipairs(locs) do
      if R._logicItemReqMet(d,allState,startId,gen) then filtered[#filtered+1]=d
      elseif d.kind~="field_extra" then return nil,"authored item check is outside solved world graph: "..d.key end
    end
    locs=filtered

    local plan={mode=cfg.field_items,seed=seed,start=startId,badgeMap=badgeMap,locations={},scriptTargets={},directTargets={},
      sequence={},usefulSequence={},defs=locs,progressionItems=Core.copy(progressionItems),usefulItems=Core.copy(usefulItems)}
    plan.progressionCount=#progressionItems

    local fillerItems={}
    for _,d in ipairs(locs) do if d.kind=="field_extra" then fillerItems[#fillerItems+1]=d.item end end
    local assigned,unfilled,state,collected={},{},{_badges=badgeMap},{}
    for _,d in ipairs(locs) do unfilled[#unfilled+1]=d end

    -- Authored Random Start proof HMs stay on their certified native checks.
    -- This preserves exact proof-order semantics (Cut on S.S. Anne, Surf in the
    -- Dance Theater, Fly after Chuck) while every other progression item may
    -- move through restrictive fill.
    if cfg.field_items=="LOGIC_RANDOM" and proof then
      for _,move in ipairs(proof.requiredMoves or {}) do
        local hm=hmItemForMove(game,move); local d=hm and byItem[hm]
        if d then assigned[d.key]=hm end
      end
    end

    -- This native gift disappears after Sudowoodo is cleared. Keeping its
    -- own prerequisite here prevents a skipped one-time reward from being lost.
    if cfg.field_items=="LOGIC_RANDOM" and gen==2 and byItem.SQUIRTBOTTLE then
      assigned[byItem.SQUIRTBOTTLE.key]="SQUIRTBOTTLE"
    end

    local function removeValue(list,value)
      for i=#list,1,-1 do if list[i]==value then table.remove(list,i); return true end end
    end
    local function removeLoc(key)
      for i=#unfilled,1,-1 do if unfilled[i].key==key then table.remove(unfilled,i); return true end end
    end
    for key,item in pairs(assigned) do
      removeValue(progressionItems,item); removeValue(usefulItems,item); removeLoc(key)
    end

    local rng=Core.rng(Core.hash(cfg.field_items=="CHAOS" and "logic-items-chaos" or "logic-items",seed))
    if cfg.field_items=="CHAOS" then
      local allItems={}
      for _,d in ipairs(defs) do allItems[#allItems+1]=d.item end
      for _,it in ipairs(fillerItems) do allItems[#allItems+1]=it end
      if #allItems~=#locs then return nil,"chaos item/location count mismatch" end
      rng:shuffle(allItems); local shuffledLocs=Core.copy(locs); rng:shuffle(shuffledLocs)
      for i,d in ipairs(shuffledLocs) do plan.locations[d.key]=allItems[i] end
    else
      local function pumpPinned()
        local changed=true
        while changed do
          changed=false
          for _,d in ipairs(locs) do
            local item=assigned[d.key]
            if item and not collected[d.key] and R._logicItemReqMet(d,state,startId,gen) then
              plan.locations[d.key]=item; collected[d.key]=true; state[item]=true
              plan.sequence[#plan.sequence+1]={key=d.key,item=item,map=d.map,pinned=true}
              assigned[d.key]=nil; changed=true
            end
          end
        end
      end
      local function reachScore(testState)
        local n=0
        if Logic and Logic.itemReachableRegions then for _ in pairs(Logic.itemReachableRegions(gen,startId,testState)) do n=n+8 end end
        if Logic and Logic.itemWorldState then
          local _,caps=Logic.itemWorldState(gen,startId,testState)
          for token in pairs(caps) do
            if type(token)=='string' and (token:match('^BADGE_') or token:match('^USE_') or token:match('^GYM_')) then n=n+4 end
          end
        end
        for _,d in ipairs(unfilled) do if d.progressionEligible~=false and R._logicItemReqMet(d,testState,startId,gen) then n=n+1 end end
        for _,d in ipairs(locs) do if assigned[d.key] and not collected[d.key] and R._logicItemReqMet(d,testState,startId,gen) then n=n+2 end end
        if Logic and Logic.itemCompletionReachable and Logic.itemCompletionReachable(gen,startId,testState) then n=n+10000 end
        return n
      end
      local function chooseItem(items)
        local frontier=(Logic and Logic.itemFrontierNeeds and Logic.itemFrontierNeeds(gen,startId,state)) or {}
        local pool={}
        for _,it in ipairs(items) do if frontier[it] then pool[#pool+1]=it end end
        if #pool==0 then for _,it in ipairs(items) do pool[#pool+1]=it end end
        local base=reachScore(state); local best,bestGain={},-math.huge
        for _,it in ipairs(pool) do
          local t=Core.copy(state); t[it]=true
          local gain=reachScore(t)-base
          if gain>bestGain then bestGain=gain; best={it} elseif gain==bestGain then best[#best+1]=it end
        end
        table.sort(best); return best[rng:int(1,#best)]
      end
      local function placeClass(items,seq,isProgression)
        local guard=0
        while #items>0 do
          guard=guard+1; if guard>1024 then return false,"logic item fill exceeded iteration guard" end
          pumpPinned()
          local reachable={}
          for _,d in ipairs(unfilled) do
            if (not isProgression or d.progressionEligible~=false) and R._logicItemReqMet(d,state,startId,gen) then reachable[#reachable+1]=d end
          end
          if #reachable==0 then
            local have=Core.sortedKeys(state); local left=Core.copy(items); table.sort(left)
            return false,(isProgression and "no reachable progression-item location remains" or "no reachable useful-item location remains")
              .." start="..tostring(startId).." have="..table.concat(have,",").." left="..table.concat(left,",")
          end
          table.sort(reachable,function(a,b) return a.key<b.key end)
          local item=chooseItem(items)
          -- Location choice remains seeded, but prefer locations that do not
          -- consume the only check newly opened by the same frontier item.
          local loc=reachable[rng:int(1,#reachable)]
          plan.locations[loc.key]=item; state[item]=true; collected[loc.key]=true
          seq[#seq+1]={key=loc.key,item=item,map=loc.map}
          removeValue(items,item); removeLoc(loc.key)
        end
        pumpPinned()
        return true
      end

      local ok,why=placeClass(progressionItems,plan.sequence,true); if not ok then return nil,why end
      if next(assigned) then return nil,"pinned progression item is unreachable" end
      if Logic and Logic.itemCompletionReachable and not Logic.itemCompletionReachable(gen,startId,state) then
        return nil,"progression items do not prove New Game -> completion"
      end
      local ok2,why2=placeClass(usefulItems,plan.usefulSequence,false); if not ok2 then return nil,why2 end

      for _,d in ipairs(unfilled) do
        if not R._logicItemReqMet(d,state,startId,gen) then return nil,"modeled filler location remains unreachable: "..d.key end
      end
      rng:shuffle(fillerItems); rng:shuffle(unfilled)
      if #fillerItems~=#unfilled then return nil,"logic item filler/location count mismatch" end
      for i,d in ipairs(unfilled) do plan.locations[d.key]=fillerItems[i] end
    end

    local progressionSeen={}; local progSet=itemListSet(plan.progressionItems)
    for _,d in ipairs(locs) do
      local target=plan.locations[d.key]; if not target then return nil,"logic item location left unfilled: "..d.key end
      if progSet[target] then
        if progressionSeen[target] then return nil,"duplicate progression item in logic fill: "..target end
        progressionSeen[target]=true
      end
    end
    for id in pairs(progSet) do if not progressionSeen[id] then return nil,"progression item lost from logic fill: "..id end end
    for _,d in ipairs(defs) do
      local target=plan.locations[d.key]
      if d.kind=="script" then plan.scriptTargets[d.item]=target
      elseif d.kind=="direct" then plan.directTargets[d.item]=target end
    end
    return plan
  end

  function R._applyLogicItemPlan(game,plan)
    if not plan then return true end
    local ordinaryByKey={}; for _,slot in ipairs(fieldSlots(game)) do ordinaryByKey[slot.key]=slot.refs end
    local refsByKey={}
    for _,d in ipairs(plan.defs or {}) do
      if d.kind=="field" then
        local refs=R._logicFieldRefs(game,d); if not refs then return false,"progression field source missing: "..d.key end; refsByKey[d.key]=refs
      elseif d.kind=="field_extra" then
        local refs=ordinaryByKey[d.slotKey]; if not refs then return false,"modeled ordinary field source missing: "..d.key end; refsByKey[d.key]=refs
      end
    end
    game.data._urLogicItemLockedRefs={}
    game.data._urLogicItemRefsByKey=refsByKey
    for _,d in ipairs(plan.defs or {}) do
      local target=plan.locations[d.key]
      for _,ref in ipairs(refsByKey[d.key] or {}) do
        ref.parent[ref.field]=itemValue(game,target,ref.template)
        game.data._urLogicItemLockedRefs[ref.parent]=true
      end
    end
    game.data._urLogicItemPlan=Core.copy(plan)
    return true
  end

  function R._validateLogicItemPlan(game,cfg)
    if cfg.field_items~="LOGIC_RANDOM" and cfg.field_items~="CHAOS" then return true end
    local plan=game.data._urLogicItemPlan
    if not plan or type(plan.locations)~="table" then return false,"logic progression-item plan missing" end
    local gen=generation(game); local progSet=itemListSet(plan.progressionItems); local progSeen={}; local byKey={}
    for _,d in ipairs(plan.defs or {}) do byKey[d.key]=d end
    for _,d in ipairs(plan.defs or {}) do
      local target=plan.locations[d.key]
      if not target or not (game.data.items and game.data.items[target]) then return false,"invalid logic item at "..d.key end
      if progSet[target] then if progSeen[target] then return false,"duplicate logic progression item "..target end; progSeen[target]=true end
      if d.kind=="field" or d.kind=="field_extra" then
        local refs=game.data._urLogicItemRefsByKey and game.data._urLogicItemRefsByKey[d.key]
        if not refs or #refs==0 then return false,"logic pickup binding missing: "..d.key end
        for _,ref in ipairs(refs) do
          if itemId(game,ref.parent[ref.field])~=target then return false,"logic pickup changed: "..d.key end
        end
        local found=false; local m=mapTable(game)[d.map]
        local function scan(raw) if itemId(game,raw)==target then found=true end end
        if type(m)=="table" then
          for _,obj in ipairs(m.objects or {}) do scan(obj.item); if type(obj.itemball)=="table" then scan(obj.itemball.item) end end
          for _,ev in ipairs(m.bgEvents or {}) do if type(ev.hiddenItem)=="table" then scan(ev.hiddenItem.item) end end
        end
        if gen==1 then for _,h in ipairs((game.data.field and game.data.field.hiddenItems and game.data.field.hiddenItems[d.map]) or {}) do scan(h.item) end end
        if not found then return false,"applied logic field item missing at "..d.key end
      end
    end
    for id in pairs(progSet) do if not progSeen[id] then return false,"logic progression item missing: "..id end end
    if cfg.field_items=="LOGIC_RANDOM" then
      local state={_badges=plan.badgeMap}
      for _,step in ipairs(plan.sequence or {}) do
        local d=byKey[step.key]; if not d then return false,"unknown logic item sequence location" end
        if plan.locations[step.key]~=step.item then return false,"logic sequence does not match award: "..step.key end
        if not R._logicItemReqMet(d,state,plan.start,gen) then return false,"logic item placed behind unmet requirement at "..d.key end
        if not progSet[step.item] then return false,"non-progression item appeared in restrictive sequence" end
        state[step.item]=true
      end
      for id in pairs(progSet) do if not state[id] then return false,"logic item not collectable in restrictive sequence: "..id end end
      if Logic and Logic.itemCompletionReachable and not Logic.itemCompletionReachable(gen,plan.start,state) then
        return false,"logic item solver does not prove New Game -> completion"
      end
      for _,step in ipairs(plan.usefulSequence or {}) do
        local d=byKey[step.key]; if not d or not R._logicItemReqMet(d,state,plan.start,gen) then return false,"useful item placed behind itself/cycle" end
        if plan.locations[step.key]~=step.item then return false,"useful sequence does not match award: "..step.key end
        state[step.item]=true
      end
      for _,d in ipairs(plan.defs or {}) do if not R._logicItemReqMet(d,state,plan.start,gen) then return false,"modeled location never becomes reachable: "..d.key end end
    end
    return true
  end

  function R.fieldMoveUsable(a,move)
    if not a or not a.game or not a.game.save then return false end
    move=tostring(move or ""):upper()
    local game=a.game
    local hm=hmItemForMove(game,move)
    local inv=game.save.inventory or {}
    if not hm or not inv[hm] then return false end
    local badge=Logic and Logic.badgeForMove(a.generation,move) or ((a.generation==1) and HM_BADGE_G1[move] or HM_BADGE_G2[move])
    if badge then
      local has=false
      if a.generation==1 then
        has=not not inv[badge]
      else
        local badges=game.save.player and game.save.player.badges or {}
        has=not not badges[badge]
        if not has then
          for i,name in ipairs(G2_BADGES) do if name==badge and badges[i] then has=true; break end end
        end
      end
      if not has then return false end
    end
    for _,mon in ipairs(game.save.party or {}) do
      for _,m in ipairs(mon.moves or {}) do
        local id=type(m)=="table" and (m.id or m.move) or m
        if tostring(id or ""):upper()==move then return true end
      end
    end
    return false
  end

  local function startLanding(game,cfg,seed)
    if not cfg or cfg.random_start=="OFF" then return nil end
    local gen=generation(game)
    local source=(cfg.random_start=="LOGIC") and RANDOM_START_LOGIC and RANDOM_START_LOGIC[gen]
      or RANDOM_START_CHAOS and RANDOM_START_CHAOS[gen]
    if not source then return nil end
    local choices={}
    local fly=game.data.field and game.data.field.flyWarps or {}
    for _,id in ipairs(source) do
      local w=fly[id]
      if type(w)=="table" and w.x~=nil and w.y~=nil then choices[#choices+1]={id=id,x=w.x,y=w.y} end
    end
    if #choices==0 and gen==2 then
      local maps=game.data.gen2Maps or game.data.maps or {}
      for _,id in ipairs(source) do
        local m=maps[id]
        for _,w in ipairs((m and m.warps) or {}) do
          local dm=tostring(w.destMap or w.map or "")
          if dm:find("POKECENTER",1,true) and w.x~=nil and w.y~=nil then choices[#choices+1]={id=id,x=w.x,y=w.y+1}; break end
        end
      end
    end
    if #choices==0 then return nil end
    return Core.rng(Core.hash("random-start",seed)):pick(choices)
  end

  -- SAFE badge randomization is a progression assignment, not a cosmetic
  -- permutation. The HM item alone is not enough: its authorizing badge must
  -- be obtainable before the first mandatory use of that field move.
  function R._safeBadgeAssignment(gen,seed,start)
    local badges=(gen==1) and G1_BADGES or G2_BADGES
    local sources=(gen==1) and G1_GYM_ORDER or G2_BADGES
    local deadlines=(gen==1)
      and {CASCADEBADGE=2,SOULBADGE=6}
      or {HIVE=2,FOG=4,PLAIN=3,GLACIER=7}
    local pins={}
    local proof=start and Logic and Logic.proof and Logic.proof(gen,start.id) or nil
    for _,lock in ipairs((proof and proof.badgeLocks) or {}) do
      local src=(gen==1) and G1_GYMS[lock.gym] or G2_GYM_SOURCE[lock.gym]
      if src and lock.badge then pins[src]=lock.badge end
    end

    -- A certified isolated start can deliberately earn a field badge later
    -- than the normal-game deadline (Cinnabar -> Soul at Blaine). That is safe
    -- only because the authored start proof obtains it before crossing the gate.
    local deadlineExempt={}
    local sourceIndex={}
    for i,src in ipairs(sources) do sourceIndex[src]=i end
    for src,badge in pairs(pins) do
      local d=deadlines[badge]
      if d and (sourceIndex[src] or 99)>d then deadlineExempt[badge]=true end
    end

    local rng=Core.rng(Core.hash("badges",seed))
    for _=1,8192 do
      local pool=Core.copy(badges); rng:shuffle(pool)
      local ok=true
      local seen={}
      for i,src in ipairs(sources) do
        local badge=pool[i]
        if seen[badge] then ok=false; break end
        seen[badge]=true
        if pins[src] and pins[src]~=badge then ok=false; break end
        local d=deadlines[badge]
        if d and not deadlineExempt[badge] and i>d then ok=false; break end
      end
      if ok then
        local out={}
        for i,src in ipairs(sources) do out[src]=pool[i] end
        local all={_badges=out}
        for _,d in ipairs(R._LOGIC_ITEM_DEFS[gen]) do all[d.item]=true end
        if not Logic or not Logic.itemCompletionReachable or Logic.itemCompletionReachable(gen,start and start.id,all) then
          return out
        end
      end
    end
    return nil,"SAFE badge assignment has no progression-valid permutation"
  end

  function R._validateSafeBadgeAssignment(gen,plan,start)
    if not plan or plan.mode~="SAFE" then return true end
    local sources=(gen==1) and G1_GYM_ORDER or G2_BADGES
    local deadlines=(gen==1)
      and {CASCADEBADGE=2,SOULBADGE=6}
      or {HIVE=2,FOG=4,PLAIN=3,GLACIER=7}
    local proof=start and Logic and Logic.proof and Logic.proof(gen,start.id) or nil
    local exempt={}
    for _,lock in ipairs((proof and proof.badgeLocks) or {}) do
      local src=(gen==1) and G1_GYMS[lock.gym] or G2_GYM_SOURCE[lock.gym]
      for i,s in ipairs(sources) do
        if s==src and deadlines[lock.badge] and i>deadlines[lock.badge] then exempt[lock.badge]=true end
      end
    end
    local seen={}
    for i,src in ipairs(sources) do
      local badge=plan.gymToBadge and plan.gymToBadge[src]
      if not badge or seen[badge] then return false,"SAFE badge assignment is incomplete/duplicated" end
      seen[badge]=true
      local d=deadlines[badge]
      if d and not exempt[badge] and i>d then
        return false,tostring(badge).." is awarded after its required field-move deadline"
      end
    end
    for _,lock in ipairs((proof and proof.badgeLocks) or {}) do
      local src=(gen==1) and G1_GYMS[lock.gym] or G2_GYM_SOURCE[lock.gym]
      if src and tostring(plan.gymToBadge[src] or "")~=tostring(lock.badge or "") then
        return false,"Random Start proof badge mismatch at "..tostring(lock.gym)
      end
    end
    return true
  end

  function R._legacyBadgePlan(game,cfg,seed,start)
    if cfg.badges=="VANILLA" then return nil end
    local gen=generation(game); local rng=Core.rng(Core.hash("badges",seed))
    local plan={mode=cfg.badges,gen=gen,gymToBadge={},flagMap={}}
    if gen==1 then
      local pool=Core.copy(G1_BADGES); rng:shuffle(pool)
      for i,key in ipairs(G1_GYM_ORDER) do plan.gymToBadge[key]=pool[i] end
      local req=start and Runtime.LEGACY_START_REQUIREMENTS[1][start.id]
      if cfg.badges=="SAFE" and req and req.gym then
        local gymKey=G1_GYMS[req.gym]
        local allowed={}; for _,m in ipairs(req.oneOf) do allowed[#allowed+1]=HM_BADGE_G1[m] end
        -- Use high hash bits for SAFE escape-path selection. Core.rng:int uses the
        -- LCG low bits; when startLanding() also selects from an even-sized pool,
        -- those low bits can correlate with the chosen location (Cinnabar was
        -- effectively Fly-only). Decouple the local HM/badge route from the
        -- landing RNG so Surf/Fly opportunities stay healthy across seeds.
        local mix=Core.hash('safe-escape|'..tostring(start.id),seed)
        local want=(#allowed>0) and allowed[(math.floor(mix/65536)%#allowed)+1] or nil
        if want and gymKey and plan.gymToBadge[gymKey]~=want then
          local other
          for k,b in pairs(plan.gymToBadge) do if b==want then other=k break end end
          if other then plan.gymToBadge[other]=plan.gymToBadge[gymKey] end
          plan.gymToBadge[gymKey]=want
        end
      end
    else
      local pool=Core.copy(G2_BADGES); rng:shuffle(pool)
      for i,sourceBadge in ipairs(G2_BADGES) do
        local target=pool[i]; plan.flagMap[G2_BADGE_FLAGS[sourceBadge]]=G2_BADGE_FLAGS[target]
        plan.gymToBadge[sourceBadge]=target
      end
      local req=start and Runtime.LEGACY_START_REQUIREMENTS[2][start.id]
      if cfg.badges=="SAFE" and req and req.gym then
        local sourceBadge=G2_GYM_SOURCE[req.gym]
        local allowed={}; for _,m in ipairs(req.oneOf) do allowed[#allowed+1]=HM_BADGE_G2[m] end
        local mix=Core.hash('safe-escape|'..tostring(start.id),seed)
        local want=(#allowed>0) and allowed[(math.floor(mix/65536)%#allowed)+1] or nil
        if sourceBadge and want and plan.gymToBadge[sourceBadge]~=want then
          local other
          for s,b in pairs(plan.gymToBadge) do if b==want then other=s break end end
          if other then plan.gymToBadge[other]=plan.gymToBadge[sourceBadge] end
          plan.gymToBadge[sourceBadge]=want
          for s,b in pairs(plan.gymToBadge) do plan.flagMap[G2_BADGE_FLAGS[s]]=G2_BADGE_FLAGS[b] end
        end
      end
    end
    return plan
  end


  local function buildBadgePlan(game,cfg,seed,start)
    if cfg.random_start~="LOGIC" or cfg.start_logic=="LEGACY" then return R._legacyBadgePlan(game,cfg,seed,start) end
    if cfg.badges=="VANILLA" then return nil end
    local gen=generation(game)
    local plan={mode=cfg.badges,gen=gen,gymToBadge={},flagMap={}}
    if cfg.badges=="SAFE" then
      local mapping,why=R._safeBadgeAssignment(gen,seed,start)
      if not mapping then error(why or "SAFE badge assignment failed") end
      plan.gymToBadge=mapping
    else
      local rng=Core.rng(Core.hash("badges",seed))
      local pool=Core.copy((gen==1) and G1_BADGES or G2_BADGES); rng:shuffle(pool)
      if gen==1 then
        for i,key in ipairs(G1_GYM_ORDER) do plan.gymToBadge[key]=pool[i] end
      else
        for i,sourceBadge in ipairs(G2_BADGES) do plan.gymToBadge[sourceBadge]=pool[i] end
      end
    end
    if gen==2 then
      for sourceBadge,target in pairs(plan.gymToBadge) do
        plan.flagMap[G2_BADGE_FLAGS[sourceBadge]]=G2_BADGE_FLAGS[target]
      end
    end
    return plan
  end

  -- Existing 1.4.1 saves keep their seed-owned item locations. This path is
  -- only selected during Continue, never by the New Game setup.
  function R._restoreLegacyEscapePlacement(game,cfg,seed,start,badgePlan)
    if not start or cfg.random_start~="LOGIC" then return nil end
    local gen=generation(game); local req=Runtime.LEGACY_START_REQUIREMENTS[gen][start.id]
    if not req then return {start=start.id,kind="OPEN",steps={"Start at "..start.id,"No immediate HM escape gate"}} end
    local badgeMap=(gen==1) and HM_BADGE_G1 or HM_BADGE_G2
    local gymSource=(gen==1) and G1_GYMS[req.gym] or G2_GYM_SOURCE[req.gym]
    local awarded=badgePlan and badgePlan.gymToBadge[gymSource]
    local candidates={}
    for _,move in ipairs(req.oneOf) do if badgeMap[move]==awarded then candidates[#candidates+1]=move end end
    if #candidates==0 then return nil,"start badge does not unlock an escape HM" end
    local move=Core.rng(Core.hash("start-hm",seed)):pick(candidates); local hm=hmItemForMove(game,move)
    if not hm then return nil,"required HM item missing for "..tostring(move) end
    local slots=fieldSlots(game); local eligibleVisible,eligibleHidden,eligibleTm={},{},{}
    for _,slot in ipairs(slots) do
      local localSlot=false
      for mapId in pairs(slot.maps or {}) do
        local u=tostring(mapId):upper()
        for _,prefix in ipairs(req.areas or {}) do
          if u:find(prefix,1,true) then localSlot=true; break end
        end
        if localSlot then break end
      end
      if localSlot then
        -- A SAFE escape item should be discoverable without knowing an invisible
        -- cart pickup coordinate. Prefer visible ordinary balls first, then a
        -- hidden ordinary pickup only if the isolated region has no visible one.
        -- TM slots remain last because replacing one can erase a guaranteed TM.
        if slot.kind=="TM" then
          eligibleTm[#eligibleTm+1]=slot
        elseif tostring(slot.key):find("hidden|",1,true) then
          eligibleHidden[#eligibleHidden+1]=slot
        else
          eligibleVisible[#eligibleVisible+1]=slot
        end
      end
    end
    local eligible=(#eligibleVisible>0) and eligibleVisible
      or ((#eligibleHidden>0) and eligibleHidden or eligibleTm)
    if #eligible==0 then return nil,"no reachable field-item slot in start region for "..tostring(move) end
    local slot=Core.rng(Core.hash("start-hm-slot",seed)):pick(eligible)
    setFieldSlot(game,slot,hm)
    game.data._urProgressionHmSlots=game.data._urProgressionHmSlots or {}
    -- Replacing a TM-designated pickup with an HM changes fieldSlots()'s
    -- ITEM/TM prefix on its next scan. Preserve the post-replacement identity
    -- too so SAFE validation can find the exact forced slot instead of losing
    -- isolated starts such as Cinnabar/Cianwood.
    local certKey=slot.key
    game.data._urProgressionHmSlots[slot.key]=hm
    if tostring(slot.key):match("^TM|") then
      certKey=tostring(slot.key):gsub("^TM|","ITEM|",1)
      game.data._urProgressionHmSlots[certKey]=hm
    end
    return {start=start.id,kind="HM_ESCAPE",gym=req.gym,badge=awarded,hm=hm,move=move,slot=certKey,
      steps={"Start at "..start.id,"Explore local area","Defeat local Gym: "..req.gym,"Receive "..tostring(awarded),"Find "..tostring(hm).." locally","Use "..move.." to leave"}}
  end

  local function forceProgressionHm(game,cfg,seed,start,badgePlan)
    if cfg.start_logic=="LEGACY" then return R._restoreLegacyEscapePlacement(game,cfg,seed,start,badgePlan) end
    if not start or cfg.random_start~="LOGIC" then return nil end
    local gen=generation(game); local req=START_REQUIREMENTS[gen][start.id]
    if not req then
      local proof=Logic and Logic.proof and Logic.proof(gen,start.id) or nil
      return {start=start.id,kind=(proof and proof.kind or "OPEN"),steps=(proof and proof.steps or {"Start at "..start.id,"No immediate HM escape gate"}),badgeLocks=proof and proof.badgeLocks or nil}
    end
    -- 2.0.0: Cianwood uses the cartridge's real post-Chuck HM02 reward.  The
    -- old emergency path injected Fly into Mania's Shuckle before HM02 was
    -- legitimately obtained, violating the LOGIC progression contract.
    if gen==2 and tostring(start.id)=="CIANWOOD_CITY" then
      local sourceBadge=G2_GYM_SOURCE.CIANWOOD_CITY
      local awarded=badgePlan and badgePlan.gymToBadge[sourceBadge] or "STORM"
      if tostring(awarded)~="STORM" then return nil,"Cianwood start must award Storm Badge for native Fly escape" end
      local hm=hmItemForMove(game,"FLY")
      if not hm then return nil,"HM02 Fly missing from host data" end
      local proof=Logic and Logic.proof and Logic.proof(gen,start.id) or nil
      return {start=start.id,kind="NATIVE_HM_ESCAPE",gym="CIANWOOD_CITY",badge="STORM",hm=hm,move="FLY",source="CIANWOOD_POST_CHUCK",
        steps=(proof and proof.steps) or {"Start at CIANWOOD_CITY","Reach Chuck through the start-only solved boulder lane","Defeat Chuck","Receive Storm Badge","Receive native HM02 Fly","Teach Fly to a compatible Pokemon","Fly to a visited Johto town"},badgeLocks=proof and proof.badgeLocks or nil}
    end
    local badgeMap=(gen==1) and HM_BADGE_G1 or HM_BADGE_G2
    local gymSource=(gen==1) and G1_GYMS[req.gym] or G2_GYM_SOURCE[req.gym]
    local awarded=badgePlan and badgePlan.gymToBadge[gymSource]
    local candidates={}
    for _,move in ipairs(req.oneOf) do if badgeMap[move]==awarded then candidates[#candidates+1]=move end end
    if #candidates==0 then return nil,"start badge does not unlock an escape HM" end
    local move=Core.rng(Core.hash("start-hm",seed)):pick(candidates); local hm=hmItemForMove(game,move)
    if not hm then return nil,"required HM item missing for "..tostring(move) end
    -- Under LOGIC RANDOM, the item solver is the only authority allowed to
    -- satisfy an isolated-start HM. Never inject a duplicate/emergency HM.
    -- Certify the placed item directly from the restrictive-fill sequence.
    if cfg.field_items=="LOGIC_RANDOM" then
      local ip=game.data._urLogicItemPlan
      local root=Logic and Logic.itemStartRegion and Logic.itemStartRegion(gen,start.id) or nil
      if ip and type(ip.locations)=="table" then
        for _,d in ipairs(ip.defs or {}) do
          if tostring(ip.locations[d.key] or "")==tostring(hm)
              and (not root or tostring(d.region or "")==tostring(root)) then
            local proof=Logic and Logic.proof and Logic.proof(gen,start.id) or nil
            return {start=start.id,kind="HM_ESCAPE",logic=true,gym=req.gym,badge=awarded,hm=hm,move=move,slot=d.key,
              steps=(proof and proof.steps) or {"Start at "..start.id,"Explore the local item sphere","Defeat local Gym: "..req.gym,"Receive "..tostring(awarded),"Find "..tostring(hm).." through LOGIC RANDOM","Use "..move.." to leave"},badgeLocks=proof and proof.badgeLocks or nil}
          end
        end
      end
      return nil,"LOGIC RANDOM did not place the certified escape HM in the starting sphere"
    end

    return nil,"This isolated LOGIC start requires ITEMS: LOGIC RANDOM"
  end

  local function buildProgressionPlan(game,cfg,seed)
    if cfg.random_start~="LOGIC" then return nil end
    local cache=game.data._urProgressionPlan
    local sig=table.concat({tostring(seed),tostring(cfg.badges),tostring(cfg.random_start),tostring(cfg.field_items),tostring(cfg.pokedex),tostring(cfg.start_logic)},"|")
    if cache and cache.sig==sig and cache.plan then return Core.copy(cache.plan) end
    local start=startLanding(game,cfg,seed); if not start then return nil,"no logical random-start landing" end
    local badges=buildBadgePlan(game,cfg,seed,start)
    if cfg.safety=="CHAOS" and cfg.start_logic~="LEGACY" then
      local plan={start=start,badges=badges,certificate={kind="CHAOS",checked=false}}
      game.data._urProgressionPlan={sig=sig,plan=Core.copy(plan)}
      return plan
    end
    local cert,err=forceProgressionHm(game,cfg,seed,start,badges); if not cert then return nil,err end
    local plan={start=start,badges=badges,certificate=cert}
    game.data._urProgressionPlan={sig=sig,plan=Core.copy(plan)}
    return Core.copy(plan)
  end

  -- SAFE LOGIC Random Start must never depend on finding a lucky HM-compatible
  -- catch.  When compatibility is otherwise vanilla, grant only the field moves
  -- named by the authored start proof to the randomized starter target species.
  -- This changes compatibility, not progression: the HM itself and its badge must
  -- still be obtained through the cartridge-authored proof chain.
  local function ensureProgressionStarterHmCompat(game,cfg,starterMap,progression)
    if cfg.safety~="SAFE" or cfg.random_start~="LOGIC" or cfg.tm_compat~="UNCHANGED" then return end
    local gen=generation(game)
    local start=progression and progression.start and progression.start.id
    local proof=Logic and Logic.proof and Logic.proof(gen,start) or nil
    local moves={}
    for _,m in ipairs((proof and proof.requiredMoves) or {}) do moves[tostring(m)]=true end
    local cert=progression and progression.certificate
    if cert and cert.move then moves[tostring(cert.move)]=true end
    if next(moves)==nil then return end
    for _,id in pairs(starterMap or {}) do
      local def=game.data.pokemon and game.data.pokemon[id]
      if def then
        def.tmhm=def.tmhm or {}
        local have={}
        for _,m in ipairs(def.tmhm) do have[tostring(m)]=true end
        for move in pairs(moves) do
          if not have[move] then def.tmhm[#def.tmhm+1]=move; have[move]=true end
        end
      end
    end
  end

  local function validateProgressionPlan(game,cfg,seed)
    if cfg.random_start~="LOGIC" then return true end
    local plan,err=buildProgressionPlan(game,cfg,seed)
    if not plan then return false,err or "logical random-start progression unavailable" end
    local start=plan.start; local cert=plan.certificate
    if not start or not start.id then return false,"logical random-start landing missing" end
    if start.id=="PALLET_TOWN" or start.id=="VIRIDIAN_CITY" then return false,"forbidden random-start landing: "..start.id end
    local gen=generation(game); local allowed={}
    for _,id in ipairs(RANDOM_START_LOGIC[gen] or {}) do allowed[id]=true end
    if not allowed[start.id] then return false,"logical random-start landing outside SAFE pool: "..tostring(start.id) end
    local proof=Logic and Logic.proof and Logic.proof(gen,start.id) or nil
    if not proof then return false,"logical random-start proof missing: "..tostring(start.id) end
    -- Verify every badge used by the authored proof is actually awarded by the
    -- named reachable gym after SAFE badge shuffling.  This catches circular
    -- Cut/Surf/Fly permissions before the game begins.
    for _,lock in ipairs(proof.badgeLocks or {}) do
      local source=(gen==1) and G1_GYMS[lock.gym] or G2_GYM_SOURCE[lock.gym]
      local got=plan.badges and plan.badges.gymToBadge and source and plan.badges.gymToBadge[source] or nil
      if tostring(got or "")~=tostring(lock.badge or "") then
        return false,"proof badge lock mismatch at "..tostring(lock.gym)..": expected "..tostring(lock.badge).." got "..tostring(got)
      end
    end
    local req=(START_REQUIREMENTS[gen] or {})[start.id]
    if not req then
      if not cert or not cert.kind or type(cert.steps)~="table" or #cert.steps==0 then
        return false,"logical random-start certificate incomplete: "..tostring(start.id)
      end
      return true
    end
    if cert and cert.kind=="NATIVE_HM_ESCAPE" then
      if tostring(start.id)~="CIANWOOD_CITY" or tostring(cert.move)~="FLY" or tostring(cert.badge)~="STORM" then
        return false,"invalid native HM escape certificate"
      end
      return hmItemForMove(game,"FLY")~=nil or false,"native HM02 Fly unavailable"
    end
    if not cert or cert.kind~="HM_ESCAPE" then return false,"HM-gated start lacks escape certificate" end
    local badgeMap=(gen==1) and HM_BADGE_G1 or HM_BADGE_G2
    if badgeMap[cert.move]~=cert.badge then return false,"escape HM/badge permission mismatch" end
    local hm=hmItemForMove(game,cert.move)
    if not hm or tostring(hm)~=tostring(cert.hm) then return false,"escape HM item mismatch" end
    -- Validate the exact field slot recorded by the progression certificate.
    -- Some host field pickups (especially hidden/event-backed items) live in
    -- data.field rather than being embedded recursively in the map object, so
    -- scanning map tables alone can falsely report that a forced local HM is
    -- missing even though the real field-item hook will award it.
    if cert.logic then
      local ip=game.data._urLogicItemPlan
      local d
      for _,row in ipairs((ip and ip.defs) or {}) do if tostring(row.key)==tostring(cert.slot) then d=row; break end end
      if not d or tostring(ip.locations[d.key] or "")~=tostring(hm) then return false,"logic escape HM certificate does not match item plan" end
      local root=Logic and Logic.itemStartRegion and Logic.itemStartRegion(gen,start.id) or nil
      if root and tostring(d.region or "")~=tostring(root) then return false,"logic escape HM is outside starting sphere" end
      return true
    end
    local seen=false
    for _,slot in ipairs(fieldSlots(game)) do
      if tostring(slot.key)==tostring(cert.slot) then
        local inArea=false
        for mapId in pairs(slot.maps or {}) do
          local u=tostring(mapId):upper()
          for _,prefix in ipairs(req.areas or {}) do
            if u:find(prefix,1,true) then inArea=true; break end
          end
          if inArea then break end
        end
        if inArea then
          local cur=itemId(game,slot.refs[1] and slot.refs[1].parent[slot.refs[1].field])
          seen=(tostring(cur)==tostring(hm))
        end
        break
      end
    end
    if not seen then return false,"required escape HM is not reachable in starting region" end
    return true
  end

  local function validateFieldItems(game,cfg)
    if cfg.field_items=="UNCHANGED" then return true end
    local slots=fieldSlots(game)
    if #slots==0 then return false,"field item tables unavailable" end
    local tmCount=0
    for _,slot in ipairs(slots) do
      local id=itemId(game,slot.refs[1] and slot.refs[1].parent[slot.refs[1].field])
      local def=id and game.data.items and game.data.items[id]
      local forced=(game.data._urProgressionHmSlots or {})[slot.key]
      if not id or (not isRandomizableItem(game,id,def) and not (forced and id==forced and machineKind(def,id)=="HM")) then
        return false,"invalid randomized field item at "..tostring(slot.key)
      end
      if machineKind(def,id)=="TM" then tmCount=tmCount+1 end
      for _,ref in ipairs(slot.refs) do
        local other=itemId(game,ref.parent[ref.field])
        if other~=id then return false,"shared field-item event diverged at "..tostring(slot.key) end
      end
    end
    if cfg.field_items=="LOGIC_RANDOM" or cfg.field_items=="CHAOS" then
      local lok,lwhy=R._validateLogicItemPlan(game,cfg); if not lok then return false,lwhy end
      local itemPool=safeItemPool(game,false)
      local tmPool=safeItemPool(game,true)
      if #itemPool<10 then return false,"safe regular-item pool too small" end
      if tmCount>#tmPool then return false,"field TM slots exceed distinct TM pool" end
      local required=(cfg.field_items=="LOGIC_RANDOM") and (REQUIRED_FIELD_TMS[generation(game)] or {}) or {}
      if tmCount<#required then return false,"not enough field TM slots for required-TM safety set" end
      local found={}
      for _,slot in ipairs(slots) do
        if slot.kind=="TM" then
          local id=itemId(game,slot.refs[1].parent[slot.refs[1].field])
          local d=id and game.data.items[id]
          local n=d and ((d.machine and d.machine.number) or d.tmNumber)
          if n then found[tonumber(n)]=true end
        end
      end
      for _,n in ipairs(required) do
        if tmByNumber(game,n) and not found[n] then
          local have={}; for k in pairs(found) do have[#have+1]=k end; table.sort(have); return false,"required field TM missing after randomization: TM"..tostring(n).." (found "..table.concat(have,",")..")"
        end
      end
    end
    return true
  end

  local function mutateMapStatics(game,cfg,seed)
    if cfg.statics=="UNCHANGED" or generation(game)~=1 then return end
    local maps=mapTable(game)
    for _,mapId in ipairs(Core.sortedKeys(maps)) do
      local map=maps[mapId]
      for i,obj in ipairs((map and map.objects) or {}) do
        local src=Core.resolveIndexedId(game.data.pokemon,obj.pokemon) or obj.pokemon
        if type(src)=="string" and game.data.pokemon[src] then
          local mode=cfg.statics=="SIMILAR" and "SIMILAR" or "RANDOM"
          local objectId=obj.index or i
          local key=table.concat({"g1static",tostring(mapId),"object="..tostring(objectId),tostring(src),tostring(obj.level or "?")},"|")
          local pick=selector(game,cfg,seed,key,src,mode)
          if pick then
            if type(obj.pokemon)=="number" then
              local d=game.data.pokemon[pick]; obj.pokemon=(d and d.index) or obj.pokemon
            else obj.pokemon=pick end
          end
        end
      end
    end
  end

  local function validateMapStatics(game,cfg)
    if cfg.statics=="UNCHANGED" then return true end
    if generation(game)~=1 then return true end
    local count=0
    for _,map in pairs(mapTable(game)) do
      for _,obj in ipairs((map and map.objects) or {}) do
        if obj.pokemon~=nil then
          count=count+1
          local id=Core.resolveIndexedId(game.data.pokemon,obj.pokemon) or obj.pokemon
          if type(id)~="string" or not game.data.pokemon[id] then
            return false,"invalid map static Pokemon reference: "..tostring(id)
          end
        end
      end
    end
    if count==0 then return false,"map static Pokemon table unavailable" end
    return true
  end

  local function validateEvos(game,cfg)
    local pokemon=game.data.pokemon or {}
    local visiting,done={},{ }
    local function dfs(id,depth)
      if depth>3 then return false,"evolution chain exceeds three stages at "..id end
      if visiting[id] then return false,"evolution cycle at "..id end
      if done[id] then return true end
      if not isSpeciesDef(pokemon[id]) then return false,"missing evolution target "..tostring(id) end
      visiting[id]=true
      for _,e in ipairs(evoRows(pokemon[id])) do
        local t=evoTarget(e)
        if not isSpeciesDef(pokemon[t]) then return false,"missing evolution target "..tostring(t) end
        local ok,why=dfs(t,depth+1); if not ok then return false,why end
      end
      visiting[id]=nil; done[id]=true; return true
    end
    for _,id in ipairs(selectedSpecies(game,cfg)) do local ok,why=dfs(id,1); if not ok then return false,why end end
    return true
  end


  local function validateTrades(game,cfg,postRandomized)
    if cfg.trades=="UNCHANGED" then return true end
    if cfg.random_start=="LOGIC" and cfg.badges~="SAFE" then
      return false,"Logic Random Start requires Random Badges: SAFE"
    end
    local id=versionId(game)
    local adapter=Adapters[id] or {}
    local isGen2=(adapter.generation==2)
    local events=isGen2 and game.data.gen2EventTables or nil
    local rows=isGen2
      and events and events.trades
      or game.data.field and game.data.field.trades
    if type(rows)~="table" or #rows==0 then return false,"in-game trade table unavailable" end
    local spec=adapter.trade
    local countOk,nativeCount=tradeCountOk(spec,#rows)
    if not countOk then
      if #rows<(nativeCount or 0) then
        return false,("%s trade table incomplete: host exposes %d, adapter requires at least %d native rows")
          :format(tostring(id),#rows,nativeCount or 0)
      end
      return false,("%s trade table mismatch: host exposes %d, adapter requires exactly %d rows")
        :format(tostring(id),#rows,nativeCount or 0)
    end
    local randomizableRows=0
    for _,row in ipairs(rows) do if not tradeIsProtected(row) then randomizableRows=randomizableRows+1 end end
    local available=#eligibleSpecies(game,cfg)
    if randomizableRows>available then
      return false,("trade randomization needs %d unique species but the active pool has %d")
        :format(randomizableRows,available)
    end

    -- Gen 2's five dialog outcomes are an indexed pointer matrix.  Checking
    -- every expected personality before a seed exists catches an incomplete
    -- host cache (especially Crystal's fourth GIRL set) before randomization
    -- can commit a run that later prints the wrong/fallback conversation.
    if isGen2 and spec and spec.dialogSets then
      local dialogRows={"TRADE_DIALOG_INTRO","TRADE_DIALOG_CANCEL","TRADE_DIALOG_WRONG",
        "TRADE_DIALOG_COMPLETE","TRADE_DIALOG_AFTER"}
      local texts=events and events.tradeTexts
      local buffers=events and events.tradeBuffers
      if type(texts)~="table" or type(buffers)~="table" then
        return false,"Gen 2 trade dialog tables unavailable"
      end
      for _,dialog in ipairs(dialogRows) do
        if type(texts[dialog])~="table" or type(buffers[dialog])~="table" then
          return false,"Gen 2 trade dialog row unavailable: "..dialog
        end
        for setName in pairs(spec.dialogSets) do
          if texts[dialog][setName]==nil or buffers[dialog][setName]==nil then
            return false,("Gen 2 trade dialog set unavailable: %s/%s"):format(dialog,setName)
          end
        end
      end
    end

    local genders={TRADE_GENDER_EITHER=true,TRADE_GENDER_MALE=true,TRADE_GENDER_FEMALE=true}
    local seenGive,seenGet={},{}
    for i,row in ipairs(rows) do
      -- The script operand is the zero-based NPC_TRADE_* index.  If an
      -- extractor ever reorders rows while retaining their ids, the wrong NPC
      -- would request/award the wrong pair and the completion flag would point
      -- at a different trade.  Treat that as structural corruption.
      if isGen2 then
        -- Native extractor rows carry their zero-based id.  Appended expansion
        -- rows may omit it because Gen1Recomp dispatches by array index; if an
        -- id is supplied it still has to agree with that index.
        if row.id~=nil and tonumber(row.id)~=(i-1) then
          return false,("trade %d row id mismatch: got %s"):format(i-1,tostring(row.id))
        end
        if i<=(nativeCount or 0) and row.id==nil then
          return false,("native trade %d is missing its row id"):format(i-1)
        end
      end
      local give=Core.resolveIndexedId(game.data.pokemon,row.give) or row.give
      local get=Core.resolveIndexedId(game.data.pokemon,row.get) or row.get
      if type(give)~="string" or not game.data.pokemon[give] then
        return false,("trade %d requested species missing: %s"):format(i-1,tostring(give))
      end
      if type(get)~="string" or not game.data.pokemon[get] then
        return false,("trade %d received species missing: %s"):format(i-1,tostring(get))
      end
      if postRandomized and not cfg.bst_match and not tradeIsProtected(row) then
        if seenGet[get] then return false,("trade %d duplicates received species: %s"):format(i-1,get) end
        seenGet[get]=true
        if cfg.trades=="BOTH" then
          if seenGive[give] then return false,("trade %d duplicates requested species: %s"):format(i-1,give) end
          seenGive[give]=true
        end
      end
      if isGen2 then
        local dialog=row.dialog
        if type(dialog)~="string" or dialog=="" then
          return false,("trade %d has invalid dialog set: %s"):format(i-1,tostring(dialog))
        end
        -- Expansion rows may introduce a new dialog personality. Accept it
        -- only when the host exposes a complete five-outcome text+buffer
        -- matrix for that exact set; otherwise fail before seed generation.
        local dialogRows={"TRADE_DIALOG_INTRO","TRADE_DIALOG_CANCEL","TRADE_DIALOG_WRONG",
          "TRADE_DIALOG_COMPLETE","TRADE_DIALOG_AFTER"}
        for _,dialogRow in ipairs(dialogRows) do
          local textRow=events and events.tradeTexts and events.tradeTexts[dialogRow]
          local bufferRow=events and events.tradeBuffers and events.tradeBuffers[dialogRow]
          if type(textRow)~="table" or type(bufferRow)~="table"
             or textRow[dialog]==nil or bufferRow[dialog]==nil then
            return false,("trade %d dialog set is incomplete: %s/%s")
              :format(i-1,dialogRow,dialog)
          end
        end
        if not genders[row.gender] then
          return false,("trade %d has invalid gender rule: %s"):format(i-1,tostring(row.gender))
        end
        if postRandomized and not tradeIsProtected(row) and spec and spec.clearGenderOnRandomize
           and row.gender~="TRADE_GENDER_EITHER" then
          return false,("trade %d retained a gender restriction after randomization"):format(i-1)
        end
        local dvs=row.dvs
        if type(dvs)~="table" or type(dvs[1])~="number" or type(dvs[2])~="number"
           or dvs[1]<0 or dvs[1]>255 or dvs[2]<0 or dvs[2]>255 then
          return false,("trade %d has invalid DV bytes"):format(i-1)
        end
        if row.item~=nil then
          local item=Core.resolveIndexedId(game.data.items,row.item) or row.item
          if type(item)~="string" or not game.data.items[item] then
            return false,("trade %d held item missing: %s"):format(i-1,tostring(item))
          end
        end
        local ot=tonumber(row.otId)
        if not ot or ot<0 or ot>65535 or ot~=math.floor(ot) then
          return false,("trade %d has invalid OT id"):format(i-1)
        end
        if type(row.nickname)~="string" or row.nickname=="" then
          return false,("trade %d has invalid nickname"):format(i-1)
        end
        if type(row.otName)~="string" or row.otName=="" then
          return false,("trade %d has invalid OT name"):format(i-1)
        end
        if spec and spec.nicknameLength and #row.nickname>spec.nicknameLength then
          return false,("trade %d nickname exceeds %d-byte field"):format(i-1,spec.nicknameLength)
        end
        if spec and spec.otNameLength and #row.otName>spec.otNameLength then
          return false,("trade %d OT name exceeds %d-byte field"):format(i-1,spec.otNameLength)
        end
      end
    end
    return true
  end

  local function validatePlan(game,cfg,seed,starterMap)
    local pool=eligibleSpecies(game,cfg)
    local selected=selectedSpecies(game,cfg)
    if #pool < 30 then return false,"species pool too small" end
    if #movePool(game,false) < 20 then return false,"move pool too small" end
    if cfg.field_items ~= "UNCHANGED" then
      local ok,why=validateFieldItems(game,cfg); if not ok then return false,why end
    end
    if cfg.marts ~= "VANILLA" then
      local ok,why=validateMarts(game,cfg); if not ok then return false,why end
    end
    if cfg.evolutions ~= "UNCHANGED" then
      local ok,why=validateEvos(game,cfg); if not ok then return false,why end
    end
    if cfg.trades ~= "UNCHANGED" then
      local ok,why=validateTrades(game,cfg,true); if not ok then return false,why end
    end
    if cfg.statics ~= "UNCHANGED" then
      local ok,why=validateMapStatics(game,cfg); if not ok then return false,why end
    end
    if cfg.starters~="UNCHANGED" then
      local adapter=Adapters[versionId(game)]
      for _,src in ipairs((adapter and adapter.starters) or {}) do
        local id=starterMap and starterMap[src]
        if not id then return false,"starter target missing for source: "..tostring(src) end
        if cfg.starters=="TWO_EVOS" and evoDepth(game,id,cfg)<2 then
          return false,"2 EVOS starter lost its two-evolution chain: "..tostring(id)
        end
      end
    end
    for _,id in pairs(starterMap or {}) do
      if not game.data.pokemon[id] then return false,"starter target missing: "..tostring(id) end
      local def=game.data.pokemon[id]
      local damagingCount=0
      local seenMoves={}
      local function checkMove(m)
        local md=game.data.moves[m]
        if md and (tonumber(md.power) or 0)>0 and not BAD_STARTER_MOVES[m] and not seenMoves[m] then
          seenMoves[m]=true; damagingCount=damagingCount+1
        end
      end
      if def.level1Moves then for _,m in ipairs(def.level1Moves) do checkMove(m) end
      elseif def.levelMoves then for _,row in ipairs(def.levelMoves) do if (row.level or 99)<=5 then checkMove(row.move) end end end
      if cfg.safety=="SAFE" and damagingCount<math.min(4,#movePool(game,true)) then return false,"starter lacks four-move SAFE coverage: "..id end

    end
    local safeHms=(cfg.safety=="SAFE" and cfg.tm_compat~="UNCHANGED") and hmMoves(game) or {}
    for _,id in ipairs(selected) do
      local def=game.data.pokemon[id]
      local compat={}
      for _,m in ipairs(def.tmhm or {}) do
        if not game.data.moves[m] then return false,"invalid TM/HM move ref: "..tostring(m) end
        compat[m]=true
      end
      for _,hm in ipairs(safeHms) do
        if not compat[hm] then return false,"SAFE HM compatibility missing for "..id..": "..tostring(hm) end
      end
    end
    if ItemLogic then local pass,why=ItemLogic.validate(game); if not pass then return false,why end end
    if cfg.badges=="SAFE" and cfg.random_start=="LOGIC" then
      local start=(cfg.random_start=="LOGIC") and startLanding(game,cfg,seed) or nil
      local badgePlan=buildBadgePlan(game,cfg,seed,start)
      local bok,bwhy=R._validateSafeBadgeAssignment(generation(game),badgePlan,start)
      if not bok then return false,bwhy end
    end
    local pok,pwhy=validateProgressionPlan(game,cfg,seed)
    if not pok then return false,pwhy end
    return true
  end

  local function configCheck(game,cfg)
    if type(game)~="table" or type(game.data)~="table" then return false,"game data unavailable" end
    if type(cfg)~="table" then return false,"randomizer configuration unavailable" end
    for key,values in pairs(ALLOWED) do
      if not values[cfg[key]] then
        return false,("invalid %s setting: %s"):format(key,tostring(cfg[key]))
      end
    end
    if type(cfg.impossible_evos)~="boolean" then return false,"invalid impossible-evolution setting" end
    if type(cfg.rival_starter)~="boolean" then return false,"invalid rival-starter setting" end
    if type(cfg.allow_legendaries)~="boolean" then return false,"invalid legendary setting" end
    if type(cfg.pc_item)~="boolean" then return false,"invalid bedroom-PC-item setting" end
    if type(cfg.progression_items)~="boolean" then return false,"invalid key/HM shuffle setting" end
    if type(cfg.bst_match)~="boolean" then return false,"invalid BST matching setting" end
    if type(cfg.mart_safety)~="boolean" then return false,"invalid mart-safety setting" end
    if type(cfg.protection_guards)~="boolean" then return false,"invalid protection-guards setting" end
    if cfg.random_start=="LOGIC" and cfg.badges~="SAFE" then
      return false,"Logic Random Start requires Random Badges: SAFE"
    end
    local extra=tonumber(cfg.extra_species)
    if not extra or extra~=math.floor(extra) or extra<0 or extra>5 then
      return false,"extra species per area must be an integer from 0 to 5"
    end
    local level=tonumber(cfg.trainer_levels)
    if not level or level~=math.floor(level) or level < -50 or level > 50 then
      return false,"trainer level modifier must be an integer from -50% to +50%"
    end
    local bossLevel=tonumber(cfg.boss_levels)
    if not bossLevel or bossLevel~=math.floor(bossLevel) or bossLevel < -50 or bossLevel > 50 then
      return false,"boss level modifier must be an integer from -50% to +50%"
    end
    local wildLevel=tonumber(cfg.wild_levels)
    if not wildLevel or wildLevel~=math.floor(wildLevel) or wildLevel < -50 or wildLevel > 50 then
      return false,"wild level modifier must be an integer from -50% to +50%"
    end
    local manual=tonumber(cfg.manual_seed)
    if not manual or manual~=math.floor(manual) or manual<1 or manual>2147483646 then
      return false,"manual seed must be an integer from 1 to 2147483646"
    end
    local id=versionId(game)
    local adapter=Adapters[id]
    if not adapter then return false,"no game adapter for "..tostring(id) end
    if adapter.runtime=="pending_gen1recomp" then
      return false,id.." adapter is prepared but Gen1Recomp runtime support is not available yet"
    end
    local cap=pokedexCap(game,cfg)
    local dexSeen={}
    for _,def in pairs(game.data.pokemon or {}) do local d=tonumber(def.dex); if d and d<=cap then dexSeen[d]=(dexSeen[d] or 0)+1 end end
    for d=1,cap do
      if not dexSeen[d] then return false,("Pokedex tier incomplete: missing National Dex #%d"):format(d) end

    end

    -- Seed-independent preflight. AUTO seed entropy is not touched until all
    -- of these checks pass.
    if #allSpecies(game)<30 then return false,"species pool too small" end
    if (cfg.movesets~="UNCHANGED" or cfg.tms~="UNCHANGED" or cfg.tm_compat~="UNCHANGED")
       and #movePool(game,false)<20 then return false,"move pool too small" end
    if (cfg.types~="UNCHANGED" or cfg.trainers=="TYPE_THEMED" or cfg.trainers=="THEMED")
       and #typePool(game)<2 then return false,"type pool unavailable" end
    if cfg.field_items~="UNCHANGED" then
      local slots=fieldSlots(game)
      if #slots==0 then return false,"field item tables unavailable" end
      if #safeItemPool(game,false)<10 then return false,"safe regular-item pool too small" end
      local tmSlots=0; for _,slot in ipairs(slots) do if slot.kind=="TM" then tmSlots=tmSlots+1 end end
      if tmSlots>0 and #safeItemPool(game,true)==0 then return false,"field TM pool unavailable" end
      if cfg.field_items=="LOGIC_RANDOM" then
        local required=REQUIRED_FIELD_TMS[adapter.generation] or {}
        if tmSlots<#required then return false,"not enough field TM slots for required-TM safety set" end
        for _,n in ipairs(required) do
          if not tmByNumber(game,n) then return false,"required TM unavailable in host data: TM"..tostring(n) end
        end
      end
    end
    if cfg.marts~="VANILLA" then
      local rows=martRows(game)
      if #rows==0 then return false,"Poke Mart inventory tables unavailable" end
      if #martItemPool(game,nil,nil)<10 then return false,"purchasable mart item pool too small" end
    end
    if cfg.mart_safety then
      if not (game.data.items and game.data.items.POKE_BALL and game.data.items.POTION) then
        return false,"Mart Safety requires POKE BALL and POTION item definitions"
      end
      if #martRows(game)==0 then return false,"Mart Safety requires Poke Mart inventory tables" end
    end
    if cfg.pc_item and adapter.generation==1 then
      local useful=0
      for _,item in ipairs(safeItemPool(game,false)) do if item~="POTION" then useful=useful+1 end end
      if useful==0 then return false,"no useful non-TM item pool available for bedroom PC randomization" end
    end
    if cfg.evolutions~="UNCHANGED" then
      local ok,why=validateEvos(game,cfg); if not ok then return false,why end
    end

    if cfg.starters~="UNCHANGED" then
      if #(adapter.starters or {})==0 then return false,"starter table unavailable" end
      for _,sid in ipairs(adapter.starters or {}) do
        if not game.data.pokemon[sid] then return false,"starter source missing: "..tostring(sid) end
      end
      if cfg.starters=="TWO_EVOS" then
        local vanilla={}; for _,sid in ipairs(adapter.starters or {}) do vanilla[sid]=true end
        local count=0
        for _,id in ipairs(eligibleSpecies(game,cfg)) do
          if not vanilla[id] and evoDepth(game,id,cfg)>=2 then count=count+1 end
        end
        if count<#(adapter.starters or {}) then
          return false,("2 EVOS requires %d distinct two-evolution starter candidates; only %d are available")
            :format(#(adapter.starters or {}),count)
        end
      end
    end
    if cfg.statics~="UNCHANGED" then
      if adapter.generation==1 then
        local ok,why=validateMapStatics(game,cfg); if not ok then return false,why end
      elseif type(game.data.gen2Maps)~="table" or next(game.data.gen2Maps)==nil then
        return false,"Gen 2 map/script data unavailable for static Pokemon"
      end
    end
    if cfg.tms~="UNCHANGED" and #tmItems(game)==0 then return false,"TM data unavailable" end
    if cfg.tm_compat~="UNCHANGED" and #allMachineMoves(game)==0 then return false,"TM/HM compatibility data unavailable" end
    if cfg.impossible_evos and adapter.generation==2 and not game.data.items.WATER_STONE then
      return false,"Water Stone data unavailable for Gen 2 trade-evolution conversion"
    end
    if cfg.trades~="UNCHANGED" then
      local rows=(adapter.generation==2)
        and game.data.gen2EventTables and game.data.gen2EventTables.trades
        or game.data.field and game.data.field.trades
      if type(rows)~="table" or #rows==0 then return false,"in-game trade table unavailable" end
      local countOk,nativeCount=tradeCountOk(adapter.trade,#rows)
      if not countOk then
        if #rows<(nativeCount or 0) then
          return false,("%s trade table incomplete: host exposes %d, adapter requires at least %d native rows")
            :format(id,#rows,nativeCount or 0)
        end
        return false,("%s trade table mismatch: host exposes %d, adapter requires exactly %d rows")
          :format(id,#rows,nativeCount or 0)
      end
      local ok,why=validateTrades(game,cfg,false)
      if not ok then return false,why end
    end

    -- Random Start is validated before seed generation. If the imported host
    -- data exposes no safe landing for the chosen generation, fail immediately
    -- instead of entering the expensive candidate loop and appearing to freeze.
    if cfg.random_start and cfg.random_start~="OFF" then
      local gen=adapter.generation
      local source=(cfg.random_start=="LOGIC") and RANDOM_START_LOGIC and RANDOM_START_LOGIC[gen]
        or RANDOM_START_CHAOS and RANDOM_START_CHAOS[gen]
      -- The tables are declared later in the module on older checkpoints, so
      -- duplicate the compact candidate IDs here when they are not yet in scope.
      if not source then
        source=(gen==1) and ((cfg.random_start=="LOGIC") and {"CERULEAN_CITY","VERMILION_CITY","LAVENDER_TOWN","CELADON_CITY","SAFFRON_CITY","FUCHSIA_CITY","CINNABAR_ISLAND"}
          or {"CERULEAN_CITY","VERMILION_CITY","LAVENDER_TOWN","CELADON_CITY","SAFFRON_CITY","FUCHSIA_CITY","CINNABAR_ISLAND","INDIGO_PLATEAU"})
          or ((cfg.random_start=="LOGIC") and {"CHERRYGROVE_CITY","AZALEA_TOWN"}
          or {"CHERRYGROVE_CITY","AZALEA_TOWN","GOLDENROD_CITY","ECRUTEAK_CITY","OLIVINE_CITY","CIANWOOD_CITY","MAHOGANY_TOWN","BLACKTHORN_CITY"})
      end
      local found=false
      local fly=game.data.field and game.data.field.flyWarps or {}
      for _,mid in ipairs(source or {}) do
        local w=fly[mid]
        if type(w)=="table" and w.x~=nil and w.y~=nil then found=true; break end
      end
      if not found and gen==2 then
        local maps=game.data.gen2Maps or game.data.maps or {}
        for _,mid in ipairs(source or {}) do
          local m=maps[mid]
          for _,w in ipairs((m and m.warps) or {}) do
            local dm=tostring(w.destMap or w.map or "")
            if dm:find("POKECENTER",1,true) and w.x~=nil and w.y~=nil then found=true; break end
          end
          if found then break end
        end
      end
      if not found then return false,"Random Start has no valid imported landing points for this game" end
    end
    return true
  end

  local function enforcePokedexCap(game,cfg)
    local cap=pokedexCap(game,cfg)
    for _,id in ipairs(allSpecies(game)) do
      local def=game.data.pokemon[id]
      if def and type(def.evolutions)=="table" then
        local kept={}
        for _,e in ipairs(def.evolutions) do
          local target=e.species or e.into; local td=target and game.data.pokemon[target]
          if td and (tonumber(td.dex) or 9999)<=cap then kept[#kept+1]=e end
        end
        def.evolutions=kept
      end
    end
  end

  local function applyMutations(game,cfg,seed,starterMap,skipRestore)
    if not skipRestore then restore(game) end
    enforcePokedexCap(game,cfg)
    mutateStats(game,cfg,seed)
    mutateTypes(game,cfg,seed)
    mutateEvolutions(game,cfg,seed)
    changeImpossibleEvolutions(game,cfg)
    mutateMovesets(game,cfg,seed)
    mutateTms(game,cfg,seed)
    mutateTmCompat(game,cfg,seed)
    mutateTrades(game,cfg,seed)
    if ItemLogic then ItemLogic.prepare(game,cfg,generation(game),versionId(game)) end
    mutateFieldItems(game,cfg,seed)
    local progression,perr=buildProgressionPlan(game,cfg,seed); if cfg.random_start=="LOGIC" and not progression then error(perr or "progression plan failed") end
    ensureProgressionStarterHmCompat(game,cfg,starterMap,progression)
    mutateMarts(game,cfg,seed)
    if ItemLogic then ItemLogic.finish(game,cfg,seed,progression and progression.badges or buildBadgePlan(game,cfg,seed,nil),progression) end
    local mok,mwhy=R._ensureLogicStartMartAccess(game,cfg,progression); if not mok then error(mwhy) end
    mutateMapStatics(game,cfg,seed)
    if cfg.safety=="SAFE" then R._ensureStarterCoverage(game,starterMap,seed,cfg); R.ensureProgressionLearners(game,cfg,starterMap) end
  end

  local function makeActive(game,cfg,seed,starterMap,prepared,starterFamilies)
    local id=versionId(game)
    local adapter=Adapters[id]
    if not starterMap then
      restore(game)
      starterFamilies=starterFamilies or buildStarterFamilies(game,adapter)
      starterMap=buildStarterMap(game,cfg,seed,adapter)
    end
    starterFamilies=starterFamilies or buildStarterFamilies(game,adapter)
    if not prepared then applyMutations(game,cfg,seed,starterMap,true) end
    local martSafetyAdded={}
    if cfg.mart_safety then R._applyMartSafety(game,martSafetyAdded) end
    local progression=nil
    if cfg.random_start=="LOGIC" then progression=buildProgressionPlan(game,cfg,seed) end
    local giftItemPlan=R._buildNpcGiftItemPlan(game,cfg,seed)
    local gok,gwhy=R._validateNpcGiftItemPlan(game,cfg,giftItemPlan)
    if not gok then error(gwhy or "NPC gift item plan failed") end
    local active={
      game=game,cfg=Core.copy(cfg),seed=seed,version=id,generation=generation(game),progression=progression,
      badgePlan=progression and progression.badges or buildBadgePlan(game,cfg,seed,nil),
      starterMap=starterMap,starterFamilyBase=starterFamilies,rivalEvolutionPaths={},
      wildMap={},areaPools={},areaHighVariety={},encounterRollState={},randomStartUsed=false,
      trainerMap={},trainerThemes={},giftMap={},staticMap={},roamerMap={},martSafetyAdded=martSafetyAdded,
      routeState={visited={},current=nil,target=nil,guidedMap=nil,offRoute=false},routeGuardIds={},
      fingerprint=Core.fingerprint(seed,cfg,id),
      pcStartItem=startingPcItem(game,cfg,seed),
      itemPlan=game.data._urItemPlan,
      logicItemPlan=Core.copy(game.data._urLogicItemPlan),
      giftItemPlan=Core.copy(giftItemPlan),
      giftItemTargetsByCmd=R._bindNpcGiftItemTargets(game,giftItemPlan),
    }
    if Logic and Logic.buildDoorPlan then
      local startId=progression and progression.start and progression.start.id or nil
      active.doorPlan=Logic.buildDoorPlan(game,cfg,seed,active.generation,startId)
    end
    return active
  end

  function R._validateDoorPlan(game,cfg,seed,progression)
    if not cfg or cfg.random_doors=="OFF" then return true end
    if not Logic or not Logic.buildDoorPlan then return false,"door-logic module unavailable" end
    local startId=progression and progression.start and progression.start.id or nil
    local plan=Logic.buildDoorPlan(game,cfg,seed,generation(game),startId)
    local ok,errs=Logic.auditDoorPlan(plan)
    if not ok then return false,"Random Doors invalid: "..table.concat(errs or {},"; ") end
    if cfg.random_doors~="CHAOS" and ((tonumber(plan.eligible) or 0)==0 or #(plan.pairs or {})==0) then
      return false,"Random Doors has no compatible safe door pairs in this game/configuration"
    end
    return true,nil,plan
  end

  function R.preflight(game,cfg)
    local normalized=R.normalizedConfig(cfg,game)
    local ok,why=configCheck(game,normalized)
    if not ok then return false,why,normalized end
    return true,nil,normalized
  end

  local function generateUnsafe(game,cfg,requestedSeed)
    local ok,why,normalized=R.preflight(game,cfg); if not ok then return nil,why end
    cfg=normalized
    local manual=requestedSeed~=nil
    if manual then
      requestedSeed=tonumber(requestedSeed)
      if not requestedSeed or requestedSeed~=math.floor(requestedSeed) or requestedSeed<1 or requestedSeed>2147483646 then
        return nil,"manual seed must be an integer from 1 to 2147483646"
      end
    end

    -- WIP4: validation is intentionally single-pass. Earlier builds searched up
    -- to 96 candidate seeds by repeatedly restoring and mutating the complete
    -- expanded game registry from inside the setup-menu callback. On Android,
    -- Random Start + a 493-species pool could keep the main thread occupied long
    -- enough for the OS to report a startup freeze. The mutators already enforce
    -- the SAFE invariants (starter damage, HM access, required field TMs, etc.),
    -- so retrying whole-world mutations is unnecessary. Preflight rejects
    -- structurally impossible configs, then exactly one selected seed is built,
    -- validated and either committed or rejected.
    snapshotFor(game)
    restore(game)

    local seed
    if manual then
      seed=math.floor(requestedSeed)
    else
      seed=(love and love.math and love.math.random and love.math.random(1,2147483646))
        or math.random(1,2147483646)
    end

    local adapter=Adapters[versionId(game)]
    local starterFamilies=buildStarterFamilies(game,adapter)
    local starterMap=buildStarterMap(game,cfg,seed,adapter)
    applyMutations(game,cfg,seed,starterMap,true)

    if cfg.safety=="SAFE" then
      local pass,reason=validatePlan(game,cfg,seed,starterMap)
      if not pass then
        restore(game)
        return nil,reason,1
      end
    end
    local progression=(cfg.random_start=="LOGIC") and buildProgressionPlan(game,cfg,seed) or nil
    local dpass,dreason=R._validateDoorPlan(game,cfg,seed,progression)
    if not dpass then restore(game); return nil,dreason,1 end

    local active=makeActive(game,cfg,seed,starterMap,true,starterFamilies)
    Runtime.active=active
    return active,nil,1
  end

  -- WIP8: frame-staged generation for expanded pools.  The previous setup
  -- callback still performed every expensive mutation/validation step inside
  -- one input callback.  Even after algorithmic optimizations that can trip
  -- Android's ANR watchdog.  These helpers let the UI execute one bounded
  -- stage per frame instead.
  function R.beginGenerate(game,cfg,requestedSeed)
    local ok,why,normalized=R.preflight(game,cfg)
    if not ok then return nil,why end
    cfg=normalized
    local manual=requestedSeed~=nil
    local seed
    if manual then
      seed=tonumber(requestedSeed)
      if not seed or seed~=math.floor(seed) or seed<1 or seed>2147483646 then
        return nil,"manual seed must be an integer from 1 to 2147483646"
      end
      seed=math.floor(seed)
    else
      seed=(love and love.math and love.math.random and love.math.random(1,2147483646))
        or math.random(1,2147483646)
    end
    return {game=game,cfg=cfg,seed=seed,manual=manual,stage=0,done=false,label="READY"}
  end

  function R.stepGenerate(st)
    if not st or st.done then return st end
    local function fail(err)
      pcall(restore,st.game)
      st.done=true; st.error=tostring(err); st.label="FAILED"
      return st
    end
    local function run(label,fn)
      st.label=label
      local ok,a,b=pcall(fn)
      if not ok then return fail(a) end
      if a==false then return fail(b or label.." failed") end
      return st
    end
    st.stage=st.stage+1
    local game,cfg,seed=st.game,st.cfg,st.seed
    if st.stage==1 then
      return run("SNAPSHOT",function() snapshotFor(game); restore(game) end)
    elseif st.stage==2 then
      return run("STARTERS",function()
        local adapter=Adapters[versionId(game)]
        st.starterFamilies=buildStarterFamilies(game,adapter)
        st.starterMap=buildStarterMap(game,cfg,seed,adapter)
      end)
    elseif st.stage==3 then return run("DEX + EVOS",function() enforcePokedexCap(game,cfg) end)
    elseif st.stage==4 then return run("BASE STATS",function() mutateStats(game,cfg,seed) end)
    elseif st.stage==5 then return run("TYPES",function() mutateTypes(game,cfg,seed) end)
    elseif st.stage==6 then return run("EVOLUTIONS",function() mutateEvolutions(game,cfg,seed); changeImpossibleEvolutions(game,cfg) end)
    elseif st.stage==7 then return run("MOVESETS",function() mutateMovesets(game,cfg,seed) end)
    elseif st.stage==8 then return run("TM MOVES",function() mutateTms(game,cfg,seed) end)
    elseif st.stage==9 then return run("TM/HM",function() mutateTmCompat(game,cfg,seed) end)
    elseif st.stage==10 then return run("TRADES",function() mutateTrades(game,cfg,seed) end)
    elseif st.stage==11 then return run("ITEMS + PROGRESSION",function()
      if ItemLogic then ItemLogic.prepare(game,cfg,generation(game),versionId(game)) end
      mutateFieldItems(game,cfg,seed)
      st.progression=buildProgressionPlan(game,cfg,seed)
      if cfg.random_start=="LOGIC" and not st.progression then return false,"progression plan failed" end
      ensureProgressionStarterHmCompat(game,cfg,st.starterMap,st.progression)
      mutateMarts(game,cfg,seed)
      local mok,mwhy=R._ensureLogicStartMartAccess(game,cfg,st.progression); if not mok then return false,mwhy end
      if ItemLogic then ItemLogic.finish(game,cfg,seed,st.progression and st.progression.badges or buildBadgePlan(game,cfg,seed,nil),st.progression) end
    end)
    elseif st.stage==12 then return run("GIFTS + STATICS",function() mutateMapStatics(game,cfg,seed); if cfg.safety=="SAFE" then R._ensureStarterCoverage(game,st.starterMap,seed,cfg); R.ensureProgressionLearners(game,cfg,st.starterMap) end end)
    elseif st.stage==13 then
      return run("SAFE CHECK",function()
        if cfg.safety=="SAFE" then
          local pass,reason=validatePlan(game,cfg,seed,st.starterMap)
          if not pass then return false,reason end
        end
        local dpass,dreason=R._validateDoorPlan(game,cfg,seed,st.progression)
        if not dpass then return false,dreason end
        return true
      end)
    elseif st.stage==14 then
      return run("COMMIT READY",function()
        st.active=makeActive(game,cfg,seed,st.starterMap,true,st.starterFamilies)
        Runtime.active=st.active
        st.done=true; st.label="PASS"
      end)
    end
    st.done=true; st.error="invalid validation stage"; return st
  end

  function R.generate(game,cfg,requestedSeed)
    local function onError(err)
      local trace=(debug and debug.traceback) and debug.traceback(tostring(err),2) or tostring(err)
      return trace
    end
    local packed={xpcall(generateUnsafe,onError,game,cfg,requestedSeed)}
    if packed[1] then return packed[2],packed[3],packed[4] end
    -- A bad seed/config must never take down the whole game. Restore the last
    -- known-good content state and surface the diagnostic in the setup footer.
    pcall(restore,game)
    if collectgarbage then pcall(collectgarbage,"collect") end
    return nil,"seed validation error: "..tostring(packed[2])
  end

  function R._relinquishRuntime(game)
    local old=Runtime.active
    local target=(old and old.game) or game
    if old then pcall(Route.clearGuards,old) end
    if target then pcall(restore,target) end
    pcall(restoreGen1BadgeRewards)
    Runtime.active=nil
  end

  function R.abortSavedActivation(game)
    R._relinquishRuntime(game)
    return true
  end

  function R.nativeEncounterState(game,state)
    if type(state)~="table" then return false end
    local function valid(id)
      local d=game.data.pokemon and game.data.pokemon[id]
      local dex=d and tonumber(d.dex)
      return dex and dex>=1 and dex<=nativeDexCap(game)
    end
    local function values(rows)
      if rows~=nil and type(rows)~="table" then return false end
      for _,id in pairs(rows or {}) do if not valid(id) then return false end end
      return true
    end
    if state.areaPools~=nil and type(state.areaPools)~="table" then return false end
    if state.areaHighVariety~=nil and type(state.areaHighVariety)~="table" then return false end
    if not values(state.wildMap) then return false end
    for _,pool in pairs(state.areaPools or {}) do if not values(pool) then return false end end
    for _,rec in pairs(state.areaHighVariety or {}) do
      if type(rec)~="table" or not values(rec.map) or not values(rec.pool) or not values(rec.sources) then return false end
    end
    return true
  end

  function R.activateSaved(game)
    -- Loading another save (including a vanilla/no-seed save) is an explicit
    -- ownership transition. Restore anything the previous process-local run
    -- changed before interpreting the newly loaded save.
    R._relinquishRuntime(game)
    local seed=mod.save:get("seed",nil)
    local cfg=mod.save:get("config",nil)
    if not seed or type(cfg)~="table" then return nil end
    cfg=Core.copy(cfg)
    if cfg.start_logic==nil then cfg.start_logic="LEGACY" end
    local savedVersion=mod.save:get("version",nil)
    local current=versionId(game)
    if savedVersion and savedVersion~=current then
      return nil,("saved randomizer version %s does not match active game %s"):format(tostring(savedVersion),tostring(current))
    end
    local ok,why,normalized=R.preflight(game,cfg)
    if not ok then return nil,"saved randomizer config rejected: "..tostring(why) end
    seed=tonumber(seed)
    if not seed or seed~=math.floor(seed) or seed<1 or seed>2147483646 then
      return nil,"saved randomizer seed is invalid"
    end
    local active=makeActive(game,normalized,seed)
    local savedGiftPlan=mod.save:get("gift_item_plan",nil)
    if type(savedGiftPlan)=="table" and tonumber(savedGiftPlan.schema)==1
        and tonumber(savedGiftPlan.seed)==seed
        and tostring(savedGiftPlan.version or current)==tostring(current) then
      local gok,gwhy=R._validateNpcGiftItemPlan(game,normalized,savedGiftPlan)
      if not gok then
        R._relinquishRuntime(game)
        return nil,"saved NPC gift item world could not be restored: "..tostring(gwhy)
      end
      active.giftItemPlan=Core.copy(savedGiftPlan)
      active.giftItemTargetsByCmd=R._bindNpcGiftItemTargets(game,savedGiftPlan)
    end
    active.randomStartUsed=not not mod.save:get("random_start_used",false)
    active.randomStartArmed=not not mod.save:get("random_start_armed",false)
    active.randomStartRespawnTarget=mod.save:get("random_start_respawn_target",nil)
    active.randomStartRespawnLocked=not not mod.save:get("random_start_respawn_locked",false)
    local savedRoute=mod.save:get("route_state",nil)
    if type(savedRoute)=="table" then
      active.routeState=Core.copy(savedRoute)
      active.routeState.visited=active.routeState.visited or {}
      active.routeState.guidedMap=nil
      active.routeState.offRoute=false
    end

    -- 2.0.0 encounter persistence: area tables and the randomizer-owned
    -- per-area encounter stream are save data, not process-local caches.
    -- A previous implementation rebuilt these tables lazily after boot. That
    -- meant a changed mod stack (or simply a different hook result on startup)
    -- could make a route appear to reroll despite the same committed seed.
    -- Restore only state owned by this exact seed/game; old saves simply start
    -- with empty caches and deterministically populate them as they are used.
    local savedEncounters=mod.save:get("encounter_state",nil)
    -- A cache from an expanded run cannot reintroduce removed species.
    if savedEncounters and not R.nativeEncounterState(game,savedEncounters) then
      mod.save:set("encounter_state",nil);mod.save:set("encounter_roll_state",nil)
      savedEncounters=nil
    end
    local savedEncounterSchema=type(savedEncounters)=="table" and tonumber(savedEncounters.schema) or nil
    if type(savedEncounters)=="table"
       and (savedEncounterSchema==1 or savedEncounterSchema==2 or savedEncounterSchema==3)
       and tonumber(savedEncounters.seed)==seed
       and tostring(savedEncounters.version or current)==tostring(current) then
      if type(savedEncounters.wildMap)=="table" then active.wildMap=Core.copy(savedEncounters.wildMap) end
      if type(savedEncounters.areaPools)=="table" then active.areaPools=Core.copy(savedEncounters.areaPools) end
      if type(savedEncounters.areaHighVariety)=="table" then active.areaHighVariety=Core.copy(savedEncounters.areaHighVariety) end
      active.encounterStateSchema=savedEncounterSchema
    end
    local savedRolls=mod.save:get("encounter_roll_state",nil)
    if type(savedRolls)=="table"
       and tonumber(savedRolls.schema)==1
       and tonumber(savedRolls.seed)==seed
       and tostring(savedRolls.version or current)==tostring(current)
       and type(savedRolls.areas)=="table" then
      active.encounterRollState=Core.copy(savedRolls.areas)
    end
    -- Schema 3 extends the eager freeze beyond grass/water to every public
    -- specialty encounter table (rods/swarm rods, headbutt common/rare, Rock
    -- Smash and Bug Contest). Older test saves are upgraded in place.
    if active.encounterStateSchema~=3 and R._primeEncounterTables then
      local okPrime,whyPrime=R._primeEncounterTables(active)
      if not okPrime then
        R._relinquishRuntime(game)
        return nil,"saved encounter table could not be restored: "..tostring(whyPrime)
      end
      active.encounterStateSchema=3
    end
    -- `map.entered` can precede `save.loaded` on Continue. route_state is
    -- intentionally serialized without guidedMap, so reconstruct the current
    -- guided identity after the second activation instead of clearing the level
    -- authority until another map transition occurs.
    local currentMap=Route.currentMapId(active)
    if active.randomStartUsed and currentMap~="" then
      active.routeRuntimeMapId=currentMap
      local st=Route.state(active)
      if tostring(st.current or "")==currentMap then
        st.guidedMap=currentMap; st.offRoute=false; st.offRouteMap=nil
      end
    end
    Runtime.active=active
    applyRandomStartRespawn(active)
    applyBadgeRewards(active)
    -- Runtime and saved ownership must agree after migration. Otherwise menus,
    -- companion readers and the fingerprint can observe the pre-normalized 1.x
    -- config while hooks are executing the normalized 2.0 policy.
    mod.save:set("config",Core.copy(active.cfg))
    mod.save:set("fingerprint",active.fingerprint)
    mod.save:set("version",active.version)
    return active
  end

  function R.commit(active)
    if not active then return false,"no active randomizer plan" end
    -- Freeze the complete encounter world before any gameplay begins. This is
    -- intentionally eager: unseen slots are part of the seed/save too, so a
    -- save boot or a changed mod stack cannot reroll the rest of a route.
    if R._primeEncounterTables then
      local okPrime,whyPrime=R._primeEncounterTables(active)
      if not okPrime then return false,"encounter table freeze failed: "..tostring(whyPrime) end
      active.encounterStateSchema=3
    end
    applyBadgeRewards(active)
    if active.cfg.pc_item and active.generation==1 then
      local ok,why=applyStartingPcItem(active)
      if not ok then return false,why end
    end
    mod.save:set("seed",active.seed)
    mod.save:set("config",Core.copy(active.cfg))
    mod.save:set("fingerprint",active.fingerprint)
    mod.save:set("version",active.version)
    mod.save:set("pc_start_item",active.pcStartItem)
    mod.save:set("random_start_used",false)
    mod.save:set("random_start_armed",false)
    mod.save:set("random_start_explained",false)
    mod.save:set("random_start_respawn_target",nil)
    mod.save:set("random_start_respawn_locked",false)
    mod.save:set("paid_hint_count",0)
    mod.save:set("route_state",{visited={},current=nil,target=nil})
    mod.save:set("gift_item_plan",Core.copy(active.giftItemPlan))
    mod.save:set("encounter_state",{
      schema=3,seed=active.seed,version=active.version,
      wildMap=Core.copy(active.wildMap or {}),
      areaPools=Core.copy(active.areaPools or {}),
      areaHighVariety=Core.copy(active.areaHighVariety or {}),
    })
    mod.save:set("encounter_roll_state",{
      schema=1,seed=active.seed,version=active.version,areas=Core.copy(active.encounterRollState or {}),
    })
    mod.save:set("safety","PASS")
    return true
  end

  function R.clear(game)
    local target=game or (Runtime.active and Runtime.active.game)
    if target then restore(target) end
    restoreGen1BadgeRewards()
    if Runtime.active then R.clearRouteGuards(target) end
    mod.save:set("seed",nil); mod.save:set("config",nil); mod.save:set("fingerprint",nil); mod.save:set("safety",nil); mod.save:set("version",nil); mod.save:set("pc_start_item",nil); mod.save:set("random_start_used",nil); mod.save:set("random_start_armed",nil); mod.save:set("random_start_respawn_target",nil); mod.save:set("random_start_respawn_locked",nil); mod.save:set("route_state",nil); mod.save:set("gift_item_plan",nil); mod.save:set("encounter_state",nil); mod.save:set("encounter_roll_state",nil); mod.save:set("paid_hint_count",nil)
    Runtime.active=nil
  end

  function R.active() return Runtime.active end

  local function activeFor(game)
    local a=Runtime.active
    if a and a.game==game then return a end
    if not game then return nil end
    local ok,active,err=pcall(R.activateSaved,game)
    if not ok then
      R._relinquishRuntime(game)
      mod.log:error("failed to recover saved randomizer runtime: %s",tostring(active))
      return nil
    end
    if not active and err then
      mod.log:error("failed to recover saved randomizer runtime: %s",tostring(err))
    end
    return active
  end

  -- 2.0.0 removed selectable level modes, sphere curves, and Protection
  -- Guards. Keep compatibility exports as explicit fixed-policy no-ops so an
  -- older companion mod cannot silently reactivate legacy behavior.
  function R.setLiveLevelMode(game,value)
    return tostring(value or "")=="PERCENTAGE", "2.0.0 uses one fixed party-independent level policy"
  end

  function R.setLiveSphereCurve(game,value)
    return tostring(value or "")=="VANILLA", "2.0.0 uses the fixed vanilla-shaped logic curve"
  end

  function R.setLiveProtectionGuards(game,value)
    local a=activeFor(game)
    if a then
      a.cfg.protection_guards=false
      mod.save:set("config",Core.copy(a.cfg))
      Route.clearGuards(a)
    end
    return value==false, "Protection Guards were removed in 2.0.0"
  end

  function R.setLiveLevelModifier(game,key,value)
    local allowed={wild_levels=true,trainer_levels=true,boss_levels=true}
    if not allowed[key] then return false,"unsupported live level setting" end
    value=tonumber(value)
    if not value or value~=math.floor(value) or value < -50 or value > 50 then
      return false,"level modifier must be an integer from -50% to +50%"
    end
    local a=activeFor(game)
    if not a then return false,"no active randomizer seed" end
    a.cfg[key]=value
    -- The active config is the source of truth for all encounter/trainer hooks.
    -- Persist it immediately so blackout, save/load and app restart retain the
    -- player's mid-run adjustment. Existing combatants are intentionally not
    -- rebuilt; the new value applies when the next encounter/party is created.
    a.fingerprint=Core.fingerprint(a.seed,a.cfg,a.version)
    mod.save:set("config",Core.copy(a.cfg))
    mod.save:set("fingerprint",a.fingerprint)
    return true
  end

  function R.setLiveMartSafety(game,value)
    value=not not value
    local a=activeFor(game)
    if not a then return false,"no active randomizer seed" end
    if value==not not a.cfg.mart_safety then return true end
    if value then
      a.martSafetyAdded=R._applyMartSafety(a.game,{})
    else
      R._removeMartSafety(a.martSafetyAdded)
      a.martSafetyAdded={}
    end
    a.cfg.mart_safety=value
    a.fingerprint=Core.fingerprint(a.seed,a.cfg,a.version)
    mod.save:set("config",Core.copy(a.cfg))
    mod.save:set("fingerprint",a.fingerprint)
    return true
  end

  local function forceSavedRuntime(game,context)
    if not game then return nil end
    local ok,active,err=pcall(R.activateSaved,game)
    if not ok then
      R._relinquishRuntime(game)
      mod.log:error("failed to %s saved randomizer runtime: %s",tostring(context or "restore"),tostring(active))
      return nil
    end
    if not active and err then
      R._relinquishRuntime(game)
      mod.log:error("failed to %s saved randomizer runtime: %s",tostring(context or "restore"),tostring(err))
      return nil
    end
    return active
  end

  local function randomSpecies(a,namespace,source,mode,pred)
    return selector(a.game,a.cfg,a.seed,namespace,source,mode,pred) or source
  end

  local function encounterAreaKey(mapId,kind,daytime)
    local key=tostring(mapId or "?").."|"..tostring(kind or "grass")
    -- Gen 2 grass tables are physically different in MORN/DAY/NITE.  Treat
    -- them as separate encounter tables instead of pooling all three dayparts
    -- together; otherwise Route 30 DAY, for example, can emit species that
    -- exist only in its night table.
    if daytime~=nil and tostring(daytime)~="" then key=key.."|"..tostring(daytime) end
    return key
  end

  function R._rodKey(rod)
    local r=tostring(rod or "old"):upper()
    if r=="OLD_ROD" or r=="OLD" then return "old" end
    if r=="GOOD_ROD" or r=="GOOD" then return "good" end
    if r=="SUPER_ROD" or r=="SUPER" then return "super" end
    return tostring(rod or "old"):lower()
  end

  function R._fishDaypart(daytime)
    local d=tostring(daytime or "DAY"):upper()
    return (d=="NITE" or d=="DARK") and "NITE" or "DAY"
  end

  function R._fishingAreaKey(a,rod,mapId,ctx)
    local rk=R._rodKey(rod)
    if a and a.generation==1 then
      -- Old/Good Rod tables are global in Gen 1; Super Rod is map-specific.
      if rk=="old" or rk=="good" then return "GEN1|fishing|"..rk end
      return tostring(mapId or "?").."|fishing|"..rk
    end
    local maps=a and a.game and a.game.data and (a.game.data.gen2Maps or a.game.data.maps) or {}
    local map=maps and maps[mapId]
    local group=(ctx and ctx.fishGroup) or (map and map.fishGroup) or "FISHGROUP_POND"
    local day=R._fishDaypart(ctx and (ctx.daytime or ctx.tod))
    return table.concat({tostring(mapId or "?"),"fishing",rk,tostring(group),day},"|")
  end

  function R._headbuttAreaKey(mapId,setName,isRare)
    return table.concat({tostring(mapId or "?"),"headbutt",tostring(setName or "?"),isRare and "rare" or "common"},"|")
  end

  function R._rockAreaKey(mapId,setName)
    return table.concat({tostring(mapId or "?"),"rock",tostring(setName or "?")},"|")
  end

  function R._contestAreaKey() return "BUG_CONTEST|contest" end

  -- Randomized wild species are selected before their final encounter level is
  -- known. Once scaling / Random Start route authority has settled that level,
  -- promote the active evolution chain so route encounters do not remain in an
  -- implausibly low stage. Ordinary level evolutions keep their real thresholds.
  -- Every other evolution method gets a wild-only ceiling of Lv45: by Lv45 a
  -- randomized wild is promoted through any remaining stone/trade/friendship/
  -- item/gender/time/location/move/party/etc. stages. This does NOT change the
  -- Pokemon's actual evolution method after capture; it only selects the wild
  -- form appropriate for the final encounter level.
  --
  function R._wildEvolutionLevelRequirement(row)
    local level=row and tonumber(row.level)
    return level and level>0 and level or nil
  end

  function R._pickWildEvolutionBranch(a,enc,current,rows,step)
    if #rows==0 then return nil end
    if #rows==1 then return rows[1] end
    local key=table.concat({
      "wild-evolution-branch", tostring(current),
      tostring(enc.mapId or enc.map or "?"), tostring(enc.slot or "?"),
      tostring(step or 1)
    },"|")
    return Core.rng(Core.hash(key,a.seed or 0)):pick(rows)
  end

  function R._evolveWildSpeciesForLevel(a,enc)
    if not a or not enc or not enc.species or type(enc.level)~="number" then return enc end
    -- BST matching takes precedence over automatic wild evolution: promoting
    -- the selected species could exceed the user's explicitly chosen limit.
    if a.cfg.wild_evolution=="AS_ROLLED" or a.cfg.wild_randomness=="UNRESTRICTED"
        or a.cfg.bst_match or a.cfg.area_encounters=="VANILLA" then return enc end
    local pokemon=a.game and a.game.data and a.game.data.pokemon or {}
    local original=Core.resolveIndexedId(pokemon,enc.species) or enc.species
    if type(original)~="string" or not pokemon[original] then return enc end
    local current=original
    local seen={}
    for step=1,6 do
      if seen[current] then break end
      seen[current]=true
      local levelRows,specialRows={},{}
      for _,row in ipairs(evoRows(pokemon[current])) do
        local target=evoTarget(row)
        if type(target)=="string" and pokemon[target] and target~=current then
          local need=R._wildEvolutionLevelRequirement(row)
          if need then
            if enc.level>=need then levelRows[#levelRows+1]=row end
          elseif enc.level>=45 then
            specialRows[#specialRows+1]=row
          end
        end
      end
      -- Real level-gated branches take priority over a compatibility-forced
      -- special branch. This keeps mixed families (for example a normal level
      -- branch plus an optional stone/trade branch) behaving naturally.
      local candidates=(#levelRows>0) and levelRows or specialRows
      local chosen=R._pickWildEvolutionBranch(a,enc,current,candidates,step)
      local nextSpecies=evoTarget(chosen)
      if not nextSpecies or nextSpecies==current then break end
      current=nextSpecies
    end
    if current==original or not pokemon[current] then return enc end
    if type(enc.species)=="number" then
      enc.species=(pokemon[current] and pokemon[current].index) or enc.species
    else
      enc.species=current
    end
    return enc
  end

  -- Wild balance is independent of item/progression safety. Truly random
  -- samples every permitted native stage, ignoring the optional global BST
  -- cap for wilds only. Trainers, gifts and starters still honor that cap.
  function R.wildConfig(a)
    if a.cfg.wild_randomness=="UNRESTRICTED" then
      return setmetatable({bst_match=false},{__index=a.cfg})
    end
    return a.cfg
  end
  function R.wildSelectionMode(a,unrestrictedLegacy)
    if a.cfg.wild_randomness=="UNRESTRICTED" then return "RANDOM" end
    if a.cfg.wild_randomness=="BALANCED" then return "SIMILAR" end
    return (unrestrictedLegacy or a.cfg.safety~="SAFE") and "RANDOM" or "SIMILAR"
  end
  local function randomWildSpecies(a,namespace,source,mode,pred)
    return selector(a.game,R.wildConfig(a),a.seed,namespace,source,mode,pred)
  end

  local function uniquePick(a,namespace,source,mode,used)
    local pick=randomWildSpecies(a,namespace,source,mode,function(id) return not used[id] end)
    if pick and not used[pick] then return pick end
    for _,id in ipairs(eligibleSpecies(a.game,a.cfg)) do
      if not used[id] and (a.cfg.allow_legendaries or not LEGENDARIES[id])
          and R.withinBst(a.game,R.wildConfig(a),source,id) then return id end
    end
    return source
  end

  function R._speciesSort(a,list)
    table.sort(list,function(x,y)
      local px=a.game.data.pokemon[x] or {}; local py=a.game.data.pokemon[y] or {}
      local dx=tonumber(px.dex) or 9999; local dy=tonumber(py.dex) or 9999
      if dx~=dy then return dx<dy end
      return tostring(x)<tostring(y)
    end)
    return list
  end

  -- Physical cartridge slots for one logical encounter table. Gen 2 exposes
  -- the selected slot number to encounter.species; Gen 1 does not, so Gen 1
  -- also gets a stable species+level signature below. Building these rows
  -- from the complete table lets a committed seed persist *unseen* slots too,
  -- rather than learning the table one encounter at a time.
  function R._nativeAreaSlots(a,areaKey)
    local parts={}
    for part in tostring(areaKey or ""):gmatch("[^|]+") do parts[#parts+1]=part end
    local mapId=tostring(parts[1] or "?")
    local kind=tostring(parts[2] or "grass"):lower()
    local daypart=parts[3]
    local out={}
    local function add(raw,level,slot)
      local id=Core.resolveIndexedId(a.game.data.pokemon,raw) or raw
      if type(id)=="string" and a.game.data.pokemon[id] then
        out[#out+1]={slot=slot,species=id,level=tonumber(level)}
      end
    end
    local function rows(list,physical)
      for i,r in ipairs(list or {}) do
        if type(r)=="table" then add(r.species or r.pokemon or r[1],r.level or r[2],physical and i or nil) end
      end
    end

    if kind=="contest" then
      local enc=a.game.data.gen2Encounters or a.game.data.encounters or {}
      for _,r in ipairs(enc.bugContest or {}) do
        local lo=tonumber(r.min or r.level) or 1
        local hi=tonumber(r.max or lo) or lo
        for lv=lo,hi do add(r.species,lv,nil) end
      end
      return out
    end

    if kind=="fishing" then
      local rk=tostring(parts[3] or "old"):lower()
      if a.generation==1 then
        local field=a.game.data.field or {}
        local fishing=field.fishing or {}
        if mapId=="GEN1" and rk=="old" then
          local def=fishing.OLD_ROD or {}; local r=def.always or {species="MAGIKARP",level=5}
          add(r.species,r.level,nil)
        elseif mapId=="GEN1" and rk=="good" then
          local def=fishing.GOOD_ROD or {}
          rows(def.pool or {{species="GOLDEEN",level=10},{species="POLIWAG",level=10}},false)
        else
          rows((field.superRod or {})[mapId],false)
        end
      else
        local enc=a.game.data.gen2Encounters or a.game.data.encounters or {}
        local group=tostring(parts[4] or "FISHGROUP_POND")
        local tod=R._fishDaypart(parts[5] or "DAY")
        local todKey=(tod=="NITE") and "nite" or "day"
        local g=enc.fishGroups and enc.fishGroups[group]
        for _,r in ipairs((g and g[rk]) or {}) do
          local slot=r[todKey]
          if not slot and r.timeGroup and enc.timeFishGroups then
            local tg=enc.timeFishGroups[r.timeGroup] or enc.timeFishGroups[tonumber(r.timeGroup)]
            slot=tg and tg[todKey]
          end
          slot=slot or r
          if slot and slot.species and slot.species~=0 and slot.species~="NO_ITEM" then
            add(slot.species,slot.level,nil)
          end
        end
      end
      return out
    end

    if a.generation==2 and (kind=="headbutt" or kind=="rock") then
      local enc=a.game.data.gen2Encounters or a.game.data.encounters or {}
      local setName=tostring(parts[3] or "?")
      local set=enc.treeSets and enc.treeSets[setName]
      local which=(kind=="headbutt" and tostring(parts[4] or "common"):lower()=="rare") and "rare" or "common"
      rows(set and set[which],false)
      return out
    end

    if a.generation==2 then
      local enc=a.game.data.gen2Encounters or a.game.data.encounters or {}
      local group=(kind=="water" or kind=="surf") and enc.water or enc.grass
      local entry=group and group[mapId]
      local slots=entry and entry.slots
      if type(slots)=="table" then
        if #slots>0 then
          rows(slots,true)
        elseif daypart and type(slots[daypart])=="table" then
          rows(slots[daypart],true)
        end
      end
    else
      local all=a.game.data.encounters or {}
      local entry=all[mapId]
      local sub=entry and (entry[kind] or ((kind=="surf") and entry.water))
      if type(sub)=="table" then rows(sub.slots or sub,false) end
    end
    return out
  end

  -- Return the unique native species that define one logical grass/water area.
  -- The result is derived from the whole cartridge table, not from whichever
  -- slot happened to be encountered first. This keeps HIGH VARIETY / AREA POOL
  -- stable across save/load, app restart, and time-of-day entry order.
  function R._nativeAreaSpecies(a,areaKey,fallback)
    local seen,out={},{}
    local function add(v)
      local id=Core.resolveIndexedId(a.game.data.pokemon,v) or v
      if type(id)=="string" and a.game.data.pokemon[id] and not seen[id] then
        seen[id]=true; out[#out+1]=id
      end
    end
    for _,row in ipairs(R._nativeAreaSlots(a,areaKey)) do add(row.species) end
    if #out==0 and fallback then add(fallback) end
    return R._speciesSort(a,out)
  end

  function R._encounterPhysicalSlotKey(a,areaKey,slot)
    local kind=tostring(areaKey or ""):match("^[^|]+|([^|]+)")
    if a and a.generation==2 and slot~=nil
       and (kind=="grass" or kind=="water" or kind=="surf") then
      return tostring(areaKey).."|slot="..tostring(slot)
    end
    return nil
  end

  -- Gen 1's public encounter.species seam does not expose the physical slot.
  -- Its vanilla roll does expose species+level, so use that cartridge signature
  -- as the persistent identity. Duplicate identical rows intentionally share
  -- one target; that is preferable to a reboot-dependent pseudo-slot.
  function R._encounterSignatureKey(areaKey,source,level)
    return tostring(areaKey).."|sig="..tostring(source).."@"..tostring(level or "?")
  end

  function R._areaAnchorSource(a,areaKey,fallback)
    local src=R._nativeAreaSpecies(a,areaKey,fallback)
    return src[1] or fallback
  end

  local function persistEncounterTables(a)
    if not a or not a.seed or a._primingEncounters or a.preview then return end
    mod.save:set("encounter_state",{
      schema=3,seed=a.seed,version=a.version,
      wildMap=Core.copy(a.wildMap or {}),
      areaPools=Core.copy(a.areaPools or {}),
      areaHighVariety=Core.copy(a.areaHighVariety or {}),
    })
  end

  local function persistEncounterRolls(a)
    if not a or not a.seed or a.preview then return end
    mod.save:set("encounter_roll_state",{
      schema=1,seed=a.seed,version=a.version,areas=Core.copy(a.encounterRollState or {}),
    })
  end

  function R._ensureAreaPool(a,areaKey,source,baseSize,chaos)
    local pool=a.areaPools[areaKey]
    if pool then return pool end
    pool={}; a.areaPools[areaKey]=pool
    local used={}
    local anchor=R._areaAnchorSource(a,areaKey,source)
    local target=math.min(#eligibleSpecies(a.game,a.cfg),math.max(1,baseSize + (tonumber(a.cfg.extra_species) or 0)))
    for i=1,target do
      local mode=R.wildSelectionMode(a,chaos)
      local pick=uniquePick(a,"area-pool|"..areaKey.."|"..i,anchor,mode,used)
      if pick and not used[pick] then pool[#pool+1]=pick; used[pick]=true end
    end
    persistEncounterTables(a)
    return pool
  end

  -- HIGH VARIETY used to allocate unique targets in the order native slots
  -- happened to be seen.  That made a route's apparent table depend on play
  -- order and rebuilt differently after an app restart.  Build the complete
  -- native-source mapping in stable dex order instead.  One native species is
  -- one base randomized species; EXTRA/AREA then contributes exactly N more
  -- unique species to this fixed logical-area pool.
  function R._ensureHighVarietyArea(a,areaKey,source)
    local rec=a.areaHighVariety[areaKey]
    if rec then return rec end
    local sources=R._nativeAreaSpecies(a,areaKey,source)
    if #sources==0 and source then sources={source} end
    local used,map,pool={},{},{}
    local mode=R.wildSelectionMode(a)
    for _,src in ipairs(sources) do
      local pick=uniquePick(a,"high-variety|"..areaKey.."|"..src,src,mode,used)
      if pick and not used[pick] then
        map[src]=pick; used[pick]=true; pool[#pool+1]=pick
      end
    end
    local n=tonumber(a.cfg.extra_species) or 0
    for i=1,n do
      local anchor=sources[((i-1)%math.max(1,#sources))+1] or source
      local pick=uniquePick(a,"area-extra|"..areaKey.."|"..i,anchor,mode,used)
      if pick and not used[pick] then used[pick]=true; pool[#pool+1]=pick end
    end
    rec={map=map,pool=pool,sources=sources}; a.areaHighVariety[areaKey]=rec
    persistEncounterTables(a)
    return rec
  end

  -- Pool-based modes use a randomizer-owned per-area stream whose cursor is
  -- serialized in mod.save. The seed defines the table and stream; the saved
  -- cursor prevents a cold boot from replaying the beginning of that stream.
  -- Native slot selection remains owned by the game before this hook runs.
  function R._chooseFromAreaPool(a,areaKey,pool,namespace,randomFn,source)
    if R.wildConfig(a).bst_match then
      local bounded={}
      for _,id in ipairs(pool or {}) do
        if R.withinBst(a.game,R.wildConfig(a),source,id) then bounded[#bounded+1]=id end
      end
      pool=bounded
    end
    if not pool or #pool==0 then return nil end

    -- The selected area table belongs to the save, so its draw cursor must as
    -- well. Relying on love.math / a process-local RNG allowed the visible
    -- sequence to jump back after a cold boot on some hosts. Keep a tiny
    -- deterministic stream per area+mode and serialize its cursor with the
    -- cartridge save. This also avoids ugly immediate streaks when the pool
    -- has more than one species without changing the table itself.
    a.encounterRollState=a.encounterRollState or {}
    local stateKey=tostring(namespace or "area-roll").."|"..tostring(areaKey)
    local st=a.encounterRollState[stateKey]
    if type(st)~="table" then st={counter=0,last=nil}; a.encounterRollState[stateKey]=st end
    st.counter=(tonumber(st.counter) or 0)+1
    local rng=Core.rng(Core.hash("encounter-stream|"..stateKey.."|"..tostring(st.counter),a.seed))
    local idx=rng:int(1,#pool)
    if #pool>1 and st.last~=nil and pool[idx]==st.last then
      local step=rng:int(1,#pool-1)
      idx=((idx-1+step)%#pool)+1
    end
    local pick=pool[idx]
    st.last=pick
    persistEncounterRolls(a)
    return pick
  end

  function R._addAreaExtras(a,areaKey,source,baseSpecies,randomFn)
    local n=tonumber(a.cfg.extra_species) or 0
    if n<=0 then return baseSpecies end
    local rec=R._ensureHighVarietyArea(a,areaKey,source)
    -- For modes whose base mapping is slot-specific, include that base in the
    -- fixed area extras rather than growing a pool every time a new slot is
    -- visited.  HIGH VARIETY passes its already-complete area pool directly.
    local pool=Core.copy(rec.pool or {})
    local found=false
    for _,id in ipairs(pool) do if id==baseSpecies then found=true; break end end
    if not found and baseSpecies then pool[#pool+1]=baseSpecies end
    return R._chooseFromAreaPool(a,areaKey,pool,"area-extra-roll",randomFn,source) or baseSpecies
  end

  RANDOM_START_LOGIC = {
    [1] = { "CERULEAN_CITY", "VERMILION_CITY", "LAVENDER_TOWN", "CELADON_CITY", "SAFFRON_CITY", "FUCHSIA_CITY", "CINNABAR_ISLAND" },
    [2] = { "CHERRYGROVE_CITY", "AZALEA_TOWN", "GOLDENROD_CITY", "ECRUTEAK_CITY", "OLIVINE_CITY", "CIANWOOD_CITY", "MAHOGANY_TOWN", "BLACKTHORN_CITY" },
  }
  RANDOM_START_CHAOS = {
    [1] = { "CERULEAN_CITY", "VERMILION_CITY", "LAVENDER_TOWN", "CELADON_CITY", "SAFFRON_CITY", "FUCHSIA_CITY", "CINNABAR_ISLAND", "INDIGO_PLATEAU" },
    [2] = { "CHERRYGROVE_CITY", "AZALEA_TOWN", "GOLDENROD_CITY", "ECRUTEAK_CITY", "OLIVINE_CITY", "CIANWOOD_CITY", "MAHOGANY_TOWN", "BLACKTHORN_CITY" },
  }

  local function randomStartDestination(a)
    if a.progression and a.progression.start then return Core.copy(a.progression.start) end
    local field=a.game and a.game.data and a.game.data.field or {}
    local fly=field.flyWarps or {}
    local source=(a.cfg.random_start=="LOGIC") and RANDOM_START_LOGIC[a.generation] or RANDOM_START_CHAOS[a.generation]
    local choices={}
    for _,id in ipairs(source or {}) do
      local w=fly[id]
      if type(w)=="table" and w.x~=nil and w.y~=nil then choices[#choices+1]={id=id,x=w.x,y=w.y} end
    end
    -- Gen2 importers may not expose a Gen1-style flyWarps table. Derive an
    -- outdoor landing from the city's Pokemon Center door and stand one tile
    -- below it. That is cart-authored geometry, not a guessed map coordinate.
    if #choices==0 and a.game and a.game.data then
      local maps=a.game.data.gen2Maps or a.game.data.maps or {}
      for _,id in ipairs(source or {}) do
        local m=maps[id]
        for _,w in ipairs((m and m.warps) or {}) do
          local dm=tostring(w.destMap or w.map or "")
          if dm:find("POKECENTER",1,true) and w.x~=nil and w.y~=nil then
            choices[#choices+1]={id=id,x=w.x,y=w.y+1}; break
          end
        end
      end
    end
    if #choices==0 then return nil end
    return Core.rng(Core.hash("random-start",a.seed)):pick(choices)
  end

  local function randomStartCenterMap(a,target)
    if not a or not target or not target.id or not a.game or not a.game.data then return nil end
    local maps=a.game.data.gen2Maps or a.game.data.maps or {}
    local town=maps[target.id]
    if not town then return nil end
    local function hasNurse(def)
      for _,o in ipairs((def and def.objects) or {}) do
        if tostring(o.name or o.sprite or ''):upper():find('NURSE',1,true) then return true,o end
      end
      return false,nil
    end
    for _,w in ipairs(town.warps or {}) do
      local id=tostring(w.destMap or w.map or '')
      local def=maps[id]
      local nurse,npc=hasNurse(def)
      if id:upper():find('POKECENTER',1,true) or nurse then
        return {id=id,doorX=w.x,doorY=w.y,nurse=npc}
      end
    end
    return nil
  end

  applyRandomStartRespawn=function(a)
    if not a or not a.randomStartRespawnLocked or not a.randomStartRespawnTarget then return end
    local save=a.game and a.game.save
    local target=a.randomStartRespawnTarget
    if not save or not target.id then return end
    if a.generation==1 then
      local center=randomStartCenterMap(a,target)
      if center and center.id then
        local nx=center.nurse and tonumber(center.nurse.x) or 3
        local ny=center.nurse and tonumber(center.nurse.y) or 1
        save.lastHeal={
          map=center.id, x=nx, y=ny+2,
          outdoor={id=target.id,x=target.x,y=target.y},
        }
      else
        save.lastHeal={map=target.id,x=target.x,y=target.y}
      end
    else
      -- Gen 2's whiteout system resolves the stored outdoor town through the
      -- imported SpawnPoints table, landing at that town's Pokemon Center.
      save.blackoutMap=target.id
    end
  end

  local function lockRandomStartRespawn(a,target)
    if not a or not target then return end
    a.randomStartRespawnTarget={id=target.id,x=target.x,y=target.y}
    a.randomStartRespawnLocked=true
    mod.save:set('random_start_respawn_target',Core.copy(a.randomStartRespawnTarget))
    mod.save:set('random_start_respawn_locked',true)
    applyRandomStartRespawn(a)
  end

  local function unlockRandomStartRespawn(a)
    if not a or not a.randomStartRespawnLocked then return end
    a.randomStartRespawnLocked=false
    mod.save:set('random_start_respawn_locked',false)
  end

  local function isPokemonCenterDestination(a,mapId)
    local id=tostring(mapId or '')
    if id:upper():find('POKECENTER',1,true) then return true end
    local maps=a and a.game and a.game.data and (a.game.data.gen2Maps or a.game.data.maps) or {}
    local def=maps[id]
    if not def then return false end
    for _,o in ipairs(def.objects or {}) do
      if tostring(o.name or o.sprite or ''):upper():find('NURSE',1,true) then return true end
    end
    return false
  end

  R._randomStartCenterMap=randomStartCenterMap
  R._applyRandomStartRespawn=applyRandomStartRespawn
  R._isPokemonCenterDestination=isPokemonCenterDestination

  local function shouldRandomStart(a,ctx)
    if not a or a.randomStartUsed or a.cfg.random_start=="OFF" then return false end
    local party=a.game and a.game.save and a.game.save.party or {}
    if #party<1 then return false end
    local ow=a.game and (a.game.world or a.game.overworld)
    local current=tostring(ow and ow.map and ow.map.id or ""):gsub("_","")
    if a.generation==1 then
      -- 2.0.0: wait for the cartridge's real Parcel/Pokedex bootstrap instead
      -- of setting story flags at the portal. The Random Start fires when the
      -- player leaves Oak's Lab after legitimately receiving the Pokedex.
      local save=a.game and a.game.save or {}
      local flags=save.flags or {}
      local hasDex=flags.EVENT_GOT_POKEDEX or save.pokedexReceived
      return current=="OAKSLAB" and not not hasDex
    end
    -- A native starter still counts when STARTERS is unchanged. The lab's
    -- real exterior exit and a nonempty party are the handoff; no randomized
    -- givepoke command or process-local arming flag is required. This also
    -- recovers a saved run that previously missed the arming hook.
    local dest=tostring(ctx and (ctx.destMap or ctx.toMap or ctx.mapId) or ""):gsub("_","")
    return current=="ELMSLAB" and dest=="NEWBARKTOWN"
  end

  function R.randomStartStatus(game,cfg)
    local a=Runtime.active
    if a and a.game~=game then a=nil end
    cfg=cfg or (a and a.cfg) or R.defaults(game)
    if cfg.random_start=="OFF" then return "Off: the game uses its normal starting town." end
    if a and a.randomStartUsed then
      local target=a.randomStartRespawnTarget or (a.progression and a.progression.start)
      return "Complete: arrived at "..tostring(target and target.id or "the selected town"):gsub("_"," ")..". The portal only runs once."
    end
    if generation(game)==1 then
      local save=game and game.save or {};local flags=save.flags or {}
      if flags.EVENT_GOT_POKEDEX or save.pokedexReceived then
        return "Ready: leave Oak's Lab to travel to your starting town."
      end
      return "Waiting for Oak's Pokedex: choose a starter, finish the rival battle, collect Oak's Parcel at Viridian Mart, return it to Oak, then leave the lab. The first lab exit does not trigger the portal."
    end
    return "Ready after receiving your starter: leave Elm's Lab for New Bark Town. Original and randomized starters both work."
  end

  -- SAFE Gen-2 HM utility spine.  When TM/HM compatibility is left vanilla,
  -- encounter randomization must not erase every native learner needed by the
  -- required story route.  Preserve only the minimum cart-authored utility
  -- encounters; all other slots in these areas remain randomized normally.
  -- This is deliberately SAFE-only: CHAOS remains unrestricted.
  local SAFE_G2_UTILITY = {
    ILEX_FOREST = { PARAS=true },                         -- CUT
    SLOWPOKE_WELL_B1F = { SLOWPOKE=true },              -- SURF + STRENGTH
    SLOWPOKE_WELL_B2F = { SLOWPOKE=true },
    ECRUTEAK_CITY = { POLIWAG=true, POLIWHIRL=true },   -- WHIRLPOOL + WATERFALL
  }

  local function safeG2UtilitySource(a,areaKey,source)
    if not a or a.generation~=2 or a.cfg.safety~="SAFE" or a.cfg.tm_compat~="UNCHANGED" then
      return false
    end
    local map=tostring(areaKey or ""):match("^([^|]+)")
    local set=map and SAFE_G2_UTILITY[map]
    return set and set[source] == true or false
  end

  local function encounterPick(a,source,slotKey,areaKey,randomFn)
    local mode=a.cfg.area_encounters or "HIGH_VARIETY"
    if mode=="VANILLA" then return source end
    local preserveUtility=safeG2UtilitySource(a,areaKey,source)
    -- Guarantee the actual native utility slot survives every SAFE encounter
    -- model, including AREA/CHAOS pools and EXTRA species rolls.
    if preserveUtility then return source end
    if mode=="AREA_POOL" then
      local pool=R._ensureAreaPool(a,areaKey,source,8,false)
      return R._chooseFromAreaPool(a,areaKey,pool,"area-roll",randomFn,source) or source
    elseif mode=="CHAOS_POOL" then
      local pool=R._ensureAreaPool(a,areaKey,source,8,true)
      return R._chooseFromAreaPool(a,areaKey,pool,"chaos-area-roll",randomFn,source) or source
    elseif mode=="HIGH_VARIETY" then
      local rec=R._ensureHighVarietyArea(a,areaKey,source)
      -- A slot that has already been seen is authoritative for this save even
      -- if another mod later changes the species passed down the hook chain.
      -- This is what makes a saved encounter table survive mod-stack changes.
      local mapped=a.wildMap[slotKey]
      if not mapped then
        mapped=rec.map[source]
        if not mapped then
          mapped=randomWildSpecies(a,"high-variety-fallback|"..areaKey.."|"..source,source,R.wildSelectionMode(a))
        end
        a.wildMap[slotKey]=mapped
        persistEncounterTables(a)
      end
      if (tonumber(a.cfg.extra_species) or 0)>0 then
        return R._chooseFromAreaPool(a,areaKey,rec.pool,"high-variety-roll",randomFn,source) or mapped
      end
      return mapped or source
    end

    local mapped=a.wildMap[slotKey]
    if not mapped then
      if mode=="VANILLA" then
        mapped=randomWildSpecies(a,"wild-slot|"..slotKey,source,R.wildSelectionMode(a))
      else -- FULL_SLOT_RANDOM
        mapped=randomWildSpecies(a,"full-slot|"..slotKey,source,R.wildSelectionMode(a,true))
      end
      a.wildMap[slotKey]=mapped
      persistEncounterTables(a)
    end
    if (tonumber(a.cfg.extra_species) or 0)>0 then
      return R._addAreaExtras(a,areaKey,source,mapped,randomFn) or mapped
    end
    return mapped
  end

  -- Freeze every normal grass/water encounter table for the committed seed.
  -- Pool modes freeze their complete pool; slot modes freeze every physical
  -- Gen 2 slot and every resolvable Gen 1 species+level signature.  The latter
  -- is the strongest identity the Gen 1 public hook exposes.
  function R._primeEncounterTables(a)
    if not a or not a.game or not a.game.data then return false,"missing game data" end
    local mode=a.cfg.area_encounters or "HIGH_VARIETY"
    local areas={}
    local function addArea(key) if key and not areas[key] then areas[key]=true end end

    if a.generation==2 then
      local enc=a.game.data.gen2Encounters or a.game.data.encounters or {}
      for mapId,entry in pairs(enc.grass or {}) do
        local slots=type(entry)=="table" and entry.slots or nil
        if type(slots)=="table" then
          if #slots>0 then addArea(encounterAreaKey(mapId,"grass",nil))
          else
            for _,day in ipairs({"MORN","DAY","NITE"}) do
              if type(slots[day])=="table" and #slots[day]>0 then addArea(encounterAreaKey(mapId,"grass",day)) end
            end
          end
        end
      end
      for mapId,entry in pairs(enc.water or {}) do
        if type(entry)=="table" and type(entry.slots)=="table" and #entry.slots>0 then
          addArea(encounterAreaKey(mapId,"water",nil))
        end
      end
      -- Fishing tables are rod + resolved fish-group + DAY/NITE identities.
      -- Prime both ordinary and possible swarm group on each map so a swarm
      -- that starts after the save cannot mutate an unseen encounter world.
      local maps=a.game.data.gen2Maps or a.game.data.maps or {}
      for mapId,map in pairs(maps) do
        local base=type(map)=="table" and map.fishGroup or nil
        if base and base~=0 and base~="FISHGROUP_NONE" then
          local groups={base}
          if base=="FISHGROUP_QWILFISH" and enc.fishGroups and enc.fishGroups.FISHGROUP_QWILFISH_SWARM then
            groups[#groups+1]="FISHGROUP_QWILFISH_SWARM"
          elseif base=="FISHGROUP_REMORAID" and enc.fishGroups and enc.fishGroups.FISHGROUP_REMORAID_SWARM then
            groups[#groups+1]="FISHGROUP_REMORAID_SWARM"
          end
          for _,group in ipairs(groups) do
            for _,rod in ipairs({"old","good","super"}) do
              for _,day in ipairs({"DAY","NITE"}) do
                local key=table.concat({tostring(mapId),"fishing",rod,tostring(group),day},"|")
                if #R._nativeAreaSlots(a,key)>0 then addArea(key) end
              end
            end
          end
        end
      end
      for mapId,setName in pairs(enc.trees or {}) do
        for _,rare in ipairs({false,true}) do
          local key=R._headbuttAreaKey(mapId,setName,rare)
          if #R._nativeAreaSlots(a,key)>0 then addArea(key) end
        end
      end
      for mapId,setName in pairs(enc.rocks or {}) do
        local key=R._rockAreaKey(mapId,setName)
        if #R._nativeAreaSlots(a,key)>0 then addArea(key) end
      end
      if type(enc.bugContest)=="table" and #enc.bugContest>0 then addArea(R._contestAreaKey()) end
    else
      for mapId,entry in pairs(a.game.data.encounters or {}) do
        if type(entry)=="table" then
          for _,kind in ipairs({"grass","water"}) do
            local sub=entry[kind]
            if type(sub)=="table" and type(sub.slots or sub)=="table" and #(sub.slots or sub)>0 then
              addArea(encounterAreaKey(mapId,kind,nil))
            end
          end
        end
      end
      -- Gen 1 Old/Good Rod tables are global. Super Rod is per map.
      addArea("GEN1|fishing|old"); addArea("GEN1|fishing|good")
      for mapId,list in pairs((a.game.data.field and a.game.data.field.superRod) or {}) do
        if type(list)=="table" and #list>0 then addArea(tostring(mapId).."|fishing|super") end
      end
    end

    a._primingEncounters=true
    local ok,err=pcall(function()
      for areaKey in pairs(areas) do
        local rows=R._nativeAreaSlots(a,areaKey)
        local source=rows[1] and rows[1].species
        if source then
          if mode=="AREA_POOL" then
            R._ensureAreaPool(a,areaKey,source,8,false)
          elseif mode=="CHAOS_POOL" then
            R._ensureAreaPool(a,areaKey,source,8,true)
          elseif mode=="HIGH_VARIETY" then
            local rec=R._ensureHighVarietyArea(a,areaKey,source)
            for _,row in ipairs(rows) do
              local key=R._encounterPhysicalSlotKey(a,areaKey,row.slot) or R._encounterSignatureKey(areaKey,row.species,row.level)
              if not a.wildMap[key] then
                local mapped=safeG2UtilitySource(a,areaKey,row.species) and row.species or rec.map[row.species]
                if not mapped then
                  mapped=randomWildSpecies(a,"high-variety-fallback|"..areaKey.."|"..row.species,row.species,R.wildSelectionMode(a))
                end
                a.wildMap[key]=mapped
              end
            end
          else
            if (tonumber(a.cfg.extra_species) or 0)>0 then R._ensureHighVarietyArea(a,areaKey,source) end
            for _,row in ipairs(rows) do
              local key=R._encounterPhysicalSlotKey(a,areaKey,row.slot) or R._encounterSignatureKey(areaKey,row.species,row.level)
              if not a.wildMap[key] then
                if mode=="VANILLA" then
                  a.wildMap[key]=randomWildSpecies(a,"wild-slot|"..key,row.species,R.wildSelectionMode(a))
                else
                  a.wildMap[key]=randomWildSpecies(a,"full-slot|"..key,row.species,R.wildSelectionMode(a,true))
                end
              end
            end
          end
        end
      end
    end)
    a._primingEncounters=nil
    if not ok then return false,err end
    persistEncounterTables(a)
    return true
  end

  local function g2PrizePick(a,mapId,src)
    local byMap=G2_PRIZE_LEVELS[mapId]
    local level=byMap and byMap[src]
    if not level or a.cfg.statics=="UNCHANGED" then return nil end
    local key="g2gift|"..mapId.."|"..src.."|"..tostring(level)
    local pick=a.giftMap[key]
    if not pick then
      pick=randomSpecies(a,key,src,a.cfg.statics=="SIMILAR" and "SIMILAR" or "RANDOM")
      a.giftMap[key]=pick
    end
    return pick
  end

  local function speciesByDisplayName(game,label)
    local want=tostring(label or ""):upper():gsub("%s+$",""):gsub("^%s+","")
    for id,def in pairs((game.data and game.data.pokemon) or {}) do
      if type(def)=="table" then
        local name=tostring(def.name or id):upper():gsub("%s+$",""):gsub("^%s+","")
        if name==want then return id end
      end
    end
    return nil
  end

  local function rewritePrizeMenu(a,mapId,cmd)
    if a.cfg.statics=="UNCHANGED" or not G2_PRIZE_LEVELS[mapId]
       or type(cmd)~="table" or type(cmd.menu)~="table" or type(cmd.menu.items)~="table" then
      return nil
    end
    local copy,changed=Core.copy(cmd),false
    for i,text in ipairs(copy.menu.items) do
      if type(text)=="string" and text~="CANCEL" then
        local priceStart=text:find("%d+%s*$")
        if priceStart then
          local label=text:sub(1,priceStart-1):gsub("%s+$","")
          local src=speciesByDisplayName(a.game,label)
          if src and G2_PRIZE_LEVELS[mapId][src] then
            local pick=g2PrizePick(a,mapId,src)
            local def=pick and a.game.data.pokemon[pick]
            if def then
              local name=tostring(def.name or pick)
              local spaces=math.max(1,priceStart-1-#name)
              copy.menu.items[i]=name..string.rep(" ",spaces)..text:sub(priceStart)
              changed=true
            end
          end
        end
      end
    end
    return changed and copy or nil
  end

  local function giftPick(a,mapId,src,level)
    local pick=a.starterMap[src]
    if not pick and a.cfg.statics~="UNCHANGED" then
      local key="gift|"..tostring(mapId).."|"..tostring(src).."|"..tostring(level)
      pick=a.giftMap[key] or randomSpecies(a,key,src,a.cfg.statics=="SIMILAR" and "SIMILAR" or "RANDOM")
      a.giftMap[key]=pick
    end
    return pick
  end

  local G1_STARTER_ASK_SOURCE = {
    _OaksLabYouWantCharmanderText="CHARMANDER",
    _OaksLabYouWantSquirtleText="SQUIRTLE",
    _OaksLabYouWantBulbasaurText="BULBASAUR",
  }
  local G2_STARTER_PROMPT = {
    CYNDAQUIL="ELM: You'll take\n",
    TOTODILE="ELM: Do you want\n",
    CHIKORITA="ELM: So, you like\n",
  }

  local function pokemonIndex(game,id)
    local d=game and game.data and game.data.pokemon and game.data.pokemon[id]
    return d and d.index or nil
  end

  local function starterTarget(a,source)
    source=Core.resolveIndexedId(a.game.data.pokemon,source) or source
    return source,a.starterMap[source]
  end

  local function starterDisplayName(a,source)
    local src,pick=starterTarget(a,source)
    if not pick then return nil,src end
    local d=a.game.data.pokemon[pick]
    return tostring((d and d.name) or pick),src,pick
  end

  -- Native starter commands use the selected species' cartridge index.
  local function withGen2StarterIndex(a,source,pick,fn)
    return fn(pokemonIndex(a.game,pick))
  end

  local function g2StaticIdentity(ctx,mapId,src)
    local scriptKey=ctx and ctx.scriptKey
    if type(scriptKey)=="string" then
      return table.concat({"g2static",tostring(mapId),scriptKey,tostring(src)},"|")
    end
    return table.concat({"g2static",tostring(mapId),"object="..tostring(ctx and ctx.object or "?"),tostring(src)},"|")
  end

  local function g2ScriptHasStatic(a,vm,scriptKey,src)
    if not (vm and type(scriptKey)=="string" and type(vm.scripts)=="table") then return false end
    local list=vm.scripts[scriptKey]
    if type(list)~="table" then return false end
    for _,row in ipairs(list) do
      if type(row)=="table" and row.op=="loadwildmon" then
        local raw=row.species or (row.args and row.args[1])
        local id=Core.resolveIndexedId(a.game.data.pokemon,raw) or raw
        if id==src then return true end
      end
    end
    return false
  end

  local function g2StaticPick(a,ctx,mapId,src)
    local key=g2StaticIdentity(ctx,mapId,src)
    local pick=a.staticMap[key]
    if not pick then
      pick=randomSpecies(a,key,src,a.cfg.statics=="SIMILAR" and "SIMILAR" or "RANDOM")
      a.staticMap[key]=pick
    end
    return pick
  end

  local function g1StaticKey(ctx,mapId,src,level)
    local npc=ctx and ctx.npc
    local objectId=npc and (npc.index or npc.id or npc.name)
    return table.concat({"g1static",tostring(mapId),"object="..tostring(objectId or "?"),tostring(src),tostring(level or "?")},"|")
  end

  local function g1StaticPick(a,ctx,mapId,src,level)
    local key=g1StaticKey(ctx,mapId,src,level)
    local pick=a.staticMap[key]
    if not pick then
      pick=randomSpecies(a,key,src,a.cfg.statics=="SIMILAR" and "SIMILAR" or "RANDOM")
      a.staticMap[key]=pick
    end
    return pick
  end

  local function g1ScriptStaticLevel(a,ctx,src)
    local list=ctx and ctx.runner and ctx.runner.script
    if type(list)~="table" then return nil end
    for _,row in ipairs(list) do
      if type(row)=="table" and row[1]=="static_battle" then
        local id=Core.resolveIndexedId(a.game.data.pokemon,row[2]) or row[2]
        if id==src then return row[3] end
      end
    end
    return nil
  end

  local function g2StarterSourceForScript(a,ctx)
    if not (ctx and ctx.vm and type(ctx.scriptKey)=="string" and type(ctx.vm.scripts)=="table") then return nil end
    local list=ctx.vm.scripts[ctx.scriptKey]
    if type(list)~="table" then return nil end
    for _,row in ipairs(list) do
      if type(row)=="table" and row.op=="givepoke" then
        local raw=row.species or (row.args and row.args[1])
        local src=Core.resolveIndexedId(a.game.data.pokemon,raw) or raw
        if a.starterMap[src] then return src end
      end
    end
    return nil
  end

  -- Two Gen 1 statics live in hard-coded hand-ported Lua callbacks rather
  -- than the normal data/script seams: Celadon prize-menu labels and the
  -- Pokemon Tower RESTLESS SOUL.  Gen1Recomp currently exposes no public
  -- hook inside those closures, so this bridge uses the explicitly-declared
  -- engine_internals permission, only on Gen 1, and leaves Gold untouched.
  -- It preserves the original handlers everywhere except the exact hardcoded
  -- seams UPR-ZX itself patches in the ROM.
  function R.installGen1HardcodedBridges(game)
    if not game or Runtime.bridgeGames[game] or generation(game)~=1 then return true end
    if Runtime.gen1BridgesInstalled then Runtime.bridgeGames[game]=true; return true end
    local scriptsOK,scriptsErr=pcall(require,"data.scripts.init")
    if not scriptsOK then return false,"native script registry unavailable: "..tostring(scriptsErr) end
    local okMS,MapScripts=pcall(require,"src.script.MapScripts")
    local okBS,BattleState=pcall(require,"src.battle.BattleState")
    if not okMS or not MapScripts or not okBS or not BattleState then
      return false,"Gen 1 hardcoded-static bridge unavailable"
    end
    local newWild=BattleState["new".."Wild"]
    if type(newWild)~="function" then return false,"Gen 1 wild-battle constructor unavailable" end

    -- Celadon Game Corner: temporarily substitute only the six source display
    -- names while the vanilla prize conversation is alive. The actual award
    -- still flows through pokemon.before_give, so storage/full-party behavior
    -- remains 100% vanilla and this bridge is presentation-only.
    local prizeMap="GAME_CORNER_PRIZE_ROOM"
    local talk={}
    local windows=G1_PRIZE_WINDOWS[versionId(game)]
    if windows then
      for wi=1,2 do
        local textId="TEXT_GAMECORNERPRIZEROOM_PRIZE_VENDOR_"..wi
        local base=MapScripts.baseTalk(prizeMap,textId)
        if type(base)=="function" then
          talk[textId]=function(g,ow,npc,done)
            local a=Runtime.active
            if not a or a.game~=g or a.cfg.statics=="UNCHANGED" then return base(g,ow,npc,done) end
            local replacements,saved={},{}
            local liveWindows=G1_PRIZE_WINDOWS[versionId(g)] or windows
            for _,row in ipairs(liveWindows[wi] or {}) do
              local src,level=row[1],row[2]
              local pick=giftPick(a,prizeMap,src,level)
              local target=pick and g.data.pokemon[pick]
              local source=g.data.pokemon[src]
              if source and target then replacements[src]=tostring(target.name or pick) end
            end
            for src,name in pairs(replacements) do
              local def=g.data.pokemon[src]
              saved[src]=def.name; def.name=name
            end
            local restored=false
            local function restoreNames()
              if restored then return end; restored=true
              for src,name in pairs(saved) do if g.data.pokemon[src] then g.data.pokemon[src].name=name end end
            end
            local function finished(...) restoreNames(); return done(...) end
            local ok,err=pcall(base,g,ow,npc,finished)
            if not ok then restoreNames(); error(err,0) end
          end
        end
      end
      if next(talk) then MapScripts.attachBase(prizeMap,{talk=talk}) end
    end

    -- Yellow parity: UPR-ZX removes Melanie's Pikachu-happiness gate when
    -- the player's randomized starter is no longer Pikachu. Gen1Recomp keeps
    -- this quest as a hand-ported talk callback rather than bytecode, so wrap
    -- only its entry-time happiness read. The real saved happiness value is
    -- restored immediately; this changes eligibility, not Pikachu state.
    local melMap="CERULEAN_MELANIES_HOUSE"
    local melText="TEXT_CERULEANMELANIESHOUSE_MELANIE"
    local baseMel=MapScripts.baseTalk(melMap,melText)
    if type(baseMel)=="function" then
      MapScripts.attachBase(melMap,{talk={[melText]=function(g,ow,npc,done)
        local a=Runtime.active
        local changed=a and a.game==g and a.starterMap
          and a.starterMap.PIKACHU and a.starterMap.PIKACHU~="PIKACHU"
        if not changed or g.save.flags.EVENT_GOT_BULBASAUR_IN_CERULEAN then
          return baseMel(g,ow,npc,done)
        end
        local old=g.save.pikachuHappiness
        if (old or 90)<147 then g.save.pikachuHappiness=147 end
        local ok,err=pcall(baseMel,g,ow,npc,done)
        g.save.pikachuHappiness=old
        if not ok then error(err,0) end
      end}})
    end

    -- Pokemon Tower 6F: UPR-ZX patches all hardcoded Marowak species bytes.
    -- Mirror that runtime behavior while preserving Gen1Recomp's exact ghost,
    -- Poke Doll, no-catch, defeat-flag and blackout behavior.
    local tower="POKEMON_TOWER_6F"
    local baseView=MapScripts.get(tower)
    local baseStep=baseView and baseView.onStep
    if type(baseStep)=="function" then
      MapScripts.attachBase(tower,{onStep=function(g,ow,x,y)
        local a=Runtime.active
        local scaleActive=a and a.game==g and R.staticLevelScalingActive(a)
        if not scaleActive or x~=10 or y~=16 or g.save.flags.EVENT_BEAT_GHOST_MAROWAK then
          return baseStep(g,ow,x,y)
        end
        local src="MAROWAK"
        local key="ghost-static|"..tower.."|"..src.."|30"
        local pick=src
        if a.cfg.statics~="UNCHANGED" then
          pick=a.staticMap[key] or randomSpecies(a,key,src,a.cfg.statics=="SIMILAR" and "SIMILAR" or "RANDOM")
          a.staticMap[key]=pick
        end
        local t=g.data.text
        g.stack:push(mod.ui.TextBox.new(g,t._PokemonTower6FBeGoneText or "Be gone...\nIntruders...",function()
          local battle=newWild(g,pick,scaleStaticEnemyLevel(a,30,tower,key))
          battle.noCatch=true
          if g.save.inventory.SILPH_SCOPE then battle:makeUnveiledGhost() else battle:makeGhost() end
          battle.onFinish=function(result)
            if result=="win" or battle.pokeDollEscape then
              g.save.flags.EVENT_BEAT_GHOST_MAROWAK=true
              local rows={
                {"show_text",t._PokemonTower6FGhostWasCubonesMotherText or "The GHOST was the\nrestless soul of\vCUBONE's mother!"},
                {"play_cry",pick,true},
                {"wait",30},
                {"show_text",t._PokemonTower6FSoulWasCalmedText or "The mother's soul\nwas calmed.\012It departed to\nthe afterlife!"},
              }
              if ow.runner then ow.runner:run(rows) elseif ow.queueScript then ow:queueScript(rows) end
            elseif result~="lose" then
              ow:scriptMove(ow.player,"right",1)
            end
            ow:afterBattle(result,battle)
          end
          g.stack:push(battle)
        end))
        return true
      end})
    end
    Runtime.gen1BridgesInstalled=true
    Runtime.bridgeGames[game]=true
    return true
  end

  local scaleWildLevel

  local function maxEncounterLevel(rows)
    if type(rows)~="table" then return nil end
    local best=nil
    for _,row in pairs(rows) do
      if type(row)=="table" then
        local lv=tonumber(row.level)
        if lv and lv>0 and (not best or lv>best) then best=lv end
      end
    end
    return best
  end

  local function useUpperWildBaseline(a)
    if not a or not a.cfg then return false end
    -- Progression-aware modes always own wild levels, even with VANILLA
    -- composition. Percentage-only mode preserves exact vanilla slots only at
    -- VANILLA + 0%; randomized composition or an explicit percentage uses the
    -- normalized upper native baseline.
    if R.progressionScalingEnabled(a) then return true end
    return (a.cfg.area_encounters or "HIGH_VARIETY")~="VANILLA"
      or (R.percentageScalingEnabled(a) and (tonumber(a.cfg.wild_levels) or 0)~=0)
  end

  local function raiseWildBaseline(a,enc,ceiling)
    if not useUpperWildBaseline(a) or not enc or type(enc.level)~="number" then return enc end

    -- 1.3.17: removing low native slot rolls was not enough once the player
    -- out-levelled an early/mid-game area.  Build every randomized/scaled wild
    -- from a tight three-level band whose ceiling is the stronger of:
    --   (a) the encounter table's highest native level, or
    --   (b) one level below the player's current strongest party Pokemon.
    -- This keeps backtracking encounters relevant without flattening every wild
    -- to exactly one level.  The live Wild Level % is still applied later by
    -- scaleWildLevel, and Random Start safety caps still win after this step.
    local nativeAnchor=math.max(tonumber(ceiling) or 0,tonumber(enc.level) or 1)
    local progressionFloor=R.progressionScalingEnabled(a) and math.max(1,partyPeakLevel(a.game)-1) or 1
    -- Pure PROGRESSION is true global rubber-banding: native route level is
    -- not a floor. HYBRID keeps the older max(native, party-relative) model.
    local anchor=R.pureProgressionEnabled(a) and progressionFloor
      or math.max(nativeAnchor,progressionFloor)
    local mapId=tostring(enc.mapId or enc.area or enc.map or "?")
    -- A 1.3.30 guided route is the cross-generation counterpart to the old
    -- local Random Start bubble: lower a high native anchor before choosing the
    -- three-level band, but only on the one seeded progression map.
    local routeCap=R._routeProgressionMax(a,mapId,"wild",false)
    if routeCap then anchor=math.min(anchor,routeCap) end
    -- Gen 2 LOGIC starts retain their earlier isolated-start cap as a fallback
    -- until the guided route state is initialized by map.entered.
    local gen2StartCap=(not R.pureProgressionEnabled(a)) and R._gen2StartWildProgressionMax(a,mapId) or nil
    if gen2StartCap then anchor=math.min(anchor,gen2StartCap) end
    local species=tostring(enc.species or "?")
    local slot=tostring(enc.slot or "?")
    local h=tonumber(Core.hash(table.concat({"wild-level-band",mapId,species,slot,tostring(enc.level)},"|"),a.seed)) or 0
    local delta=math.abs(h)%3
    enc.level=math.max(1,math.min(100,math.floor(anchor-delta+0.5)))
    return enc
  end

  local function fieldWildCeiling(a,enc,ctx)
    if not a or not a.game then return nil end
    local mapId=tostring((ctx and ctx.mapId) or (enc and enc.mapId) or "")
    local terrain=tostring((ctx and ctx.terrain) or "grass")
    if generation(a.game)==1 then
      local all=a.game.data and a.game.data.encounters
      local def=all and all[mapId]
      local group=def and ((terrain=="water") and def.water or def.grass)
      return maxEncounterLevel(group and group.slots)
    end
    local world=a.game.world or a.game.overworld
    local tables=(ctx and ctx.tables) or (world and world.encounters)
    if type(tables)~="table" then return nil end
    if terrain=="water" then
      local entry=tables.water and tables.water[mapId]
      return maxEncounterLevel(entry and entry.slots)
    end
    local entry=tables.grass and tables.grass[mapId]
    local tod=(ctx and ctx.daytime) or (world and world.tod) or "DAY"
    if tod=="DARK" then tod="NITE" end
    local slots=entry and entry.slots and (entry.slots[tod] or entry.slots.DAY)
    return maxEncounterLevel(slots)
  end

  local function fishingWildCeiling(a,rod,candidates,ctx,selectedLevel)
    if not a then return nil end
    if generation(a.game)==1 then
      return maxEncounterLevel(candidates) or tonumber(selectedLevel)
    end
    if type(candidates)~="table" then return tonumber(selectedLevel) end
    local key=rod
    if rod=="OLD_ROD" then key="old" elseif rod=="GOOD_ROD" then key="good" elseif rod=="SUPER_ROD" then key="super" end
    key=key or "old"
    local rows=candidates[key]
    if type(rows)~="table" then return tonumber(selectedLevel) end
    local tod=(ctx and (ctx.daytime or ctx.tod)) or "DAY"
    local todKey=(tod=="NITE" or tod=="DARK") and "nite" or "day"
    local best=nil
    for _,row in ipairs(rows) do
      if type(row)=="table" then
        local slot=row[todKey]
        if not slot and row.timeGroup and ctx and ctx.encounters and ctx.encounters.timeFishGroups then
          local tg=ctx.encounters.timeFishGroups[row.timeGroup]
          slot=tg and tg[todKey]
        end
        slot=slot or row
        local lv=tonumber(slot and slot.level)
        if lv and lv>0 and (not best or lv>best) then best=lv end
      end
    end
    return best or tonumber(selectedLevel)
  end

  local function kaizoLiveLevelPercent(a,key)
    local game=a and a.game
    local rows=game and game.mods and game.mods.modOptions
      and game.mods.modOptions.gen1_kaizo
    local value=rows and tonumber(rows[key]) or 0
    if not value then value=0 end
    return math.max(-50,math.min(50,math.floor(value)))
  end

  local function scaleGen2SpecialWildLevel(a,enc)
    if not enc or type(enc.level)~="number" then return enc end
    -- Kaizo Ultimate's documented policy is that a non-zero matching live
    -- percentage owns the category. Headbutt/Rock Smash bypass Kaizo's shared
    -- encounter hook too, so mirror that policy here when both mods are active.
    local kpct=kaizoLiveLevelPercent(a,"wild_levels")
    if kpct~=0 then
      local mapId=tostring(enc.mapId or enc.area or enc.map or "")
      local routeCap=R._routeProgressionMax(a,mapId,"wild",false)
      if routeCap and enc.level>routeCap then
        local h=tonumber(Core.hash("guided-special|"..mapId.."|"..tostring(enc.species or "?").."|"..tostring(enc.level),a.seed)) or 0
        enc.level=math.max(2,routeCap-(math.abs(h)%3))
      end
      local startCap=R._gen2StartWildProgressionMax(a,mapId)
      if startCap and enc.level>startCap then
        local h=tonumber(Core.hash("g2-start-special|"..mapId.."|"..tostring(enc.species or "?").."|"..tostring(enc.level),a.seed)) or 0
        enc.level=math.max(2,startCap-(math.abs(h)%3))
      end
      enc.level=math.max(1,math.min(100,math.floor(enc.level*(100+kpct)/100+0.5)))
      return enc
    end
    return scaleWildLevel(a,enc)
  end

  -- Gen 2 has three encounter paths that intentionally do not raise the
  -- shared encounter.species hook in Gen1Recomp 0.1.98: headbutt trees, Rock
  -- Smash and roamers. Roamers are already randomized as authored statics at
  -- InitRoamMons, so only the first two need a narrow runtime bridge. This is
  -- kept behind engine_internals and does not alter the vanilla chance/slot
  -- roll; it transforms only the species after the cart-faithful roll wins.
  function R.installGen2EncounterBridges(game)
    if not game or generation(game)~=2 then return true end
    if Runtime.gen2BridgesInstalled then return true end
    local okE,Encounter=pcall(require,"src.battle.gen2.Encounter")
    local okW,World=pcall(require,"src.world.gen2.World")
    if not okE or not Encounter or not okW or not World then
      return false,"Gen 2 headbutt/rock encounter bridge unavailable"
    end

    local baseTreeSlot=Encounter.treeSlot
    local baseRock=World.rockMonEncounter
    if type(baseTreeSlot)~="function" or type(baseRock)~="function" then
      return false,"Gen 2 headbutt/rock encounter functions unavailable"
    end

    Encounter.treeSlot=function(encounters,mapId,cx,cy,random)
      local enc=baseTreeSlot(encounters,mapId,cx,cy,random)
      local a=Runtime.active
      if not a or generation(a.game)~=2 or not enc or not enc.species then return enc end
      local src=Core.resolveIndexedId(a.game.data.pokemon,enc.species) or enc.species
      if type(src)~="string" or not a.game.data.pokemon[src] then return enc end
      local setName=Encounter.treeSet(encounters,mapId)
      local rare=Encounter.treeIsRare(cx,cy)
      local areaKey=R._headbuttAreaKey(mapId,setName,rare)
      local key=R._encounterSignatureKey(areaKey,src,enc.level)
      local pick=encounterPick(a,src,key,areaKey,random)
      if type(enc.species)=="number" then
        local d=a.game.data.pokemon[pick]
        enc.species=(d and d.index) or enc.species
      else
        enc.species=pick
      end
      -- Headbutt bypasses the shared encounter.species hook in Gen 2.
      -- Apply the same live Wild Level % used by grass/cave/surf/fishing.
      local set=setName and encounters and encounters.treeSets and encounters.treeSets[setName]
      local list=set and (rare and set.rare or set.common)
      local scaled={level=enc.level,mapId=mapId}
      raiseWildBaseline(a,scaled,maxEncounterLevel(list))
      scaleGen2SpecialWildLevel(a,scaled)
      R._finalWildLevelAuthority(a,scaled,mapId,"headbutt")
      enc.level=scaled.level
      R._evolveWildSpeciesForLevel(a,enc)
      return enc
    end

    World.rockMonEncounter=function(self,...)
      local result=baseRock(self,...)
      local a=Runtime.active
      if not a or generation(a.game)~=2 or not result or result==0 then
        return result
      end
      local temp=self and self.tempWildMon
      local src=temp and (Core.resolveIndexedId(a.game.data.pokemon,temp.species) or temp.species)
      if type(src)~="string" or not a.game.data.pokemon[src] then return result end
      local mapId=self.map and self.map.id or "?"
      local level=temp.level
      local setName=self.encounters and self.encounters.rocks and self.encounters.rocks[mapId]
      local areaKey=R._rockAreaKey(mapId,setName)
      local key=R._encounterSignatureKey(areaKey,src,level)
      local pick=encounterPick(a,src,key,areaKey,(self and self.random) or nil)
      local d=a.game.data.pokemon[pick]
      if d and d.index then
        temp.species=d.index
        -- Rock Smash also bypasses encounter.species. Keep its selected slot
        -- level, then apply the active Randomizer Wild Level % exactly once.
        local set=setName and self.encounters and self.encounters.treeSets and self.encounters.treeSets[setName]
        local scaled={level=temp.level,mapId=mapId}
        raiseWildBaseline(a,scaled,maxEncounterLevel(set and set.common))
        scaleGen2SpecialWildLevel(a,scaled)
        R._finalWildLevelAuthority(a,scaled,mapId,"rock")
        temp.level=scaled.level
        R._evolveWildSpeciesForLevel(a,temp)
        return temp.species or d.index
      end
      return result
    end

    Runtime.gen2BridgesInstalled=true
    return true
  end

  -- -----------------------------------------------------------------------
  -- Seed-generated hint system
  -- -----------------------------------------------------------------------
  -- Hints are derived only from the committed seed + already-finalized game
  -- data.  They never roll or mutate gameplay state.  This keeps a sign or
  -- purchased answer reproducible for races and prevents the hint layer from
  -- changing the world it describes.
  local function hintMoney(game)
    local save=game and game.save or {}
    if save.player and save.player.money~=nil then return tonumber(save.player.money) or 0 end
    return tonumber(save.money) or 0
  end

  local function setHintMoney(game,value)
    local save=game and game.save or {}
    value=math.max(0,math.floor(tonumber(value) or 0))
    if save.player and save.player.money~=nil then save.player.money=value else save.money=value end
  end

  local function humanId(v)
    local s=tostring(v or "?"):gsub("^TEXT_",""):gsub("_"," "):lower()
    s=s:gsub("(%a)([%w']*)",function(a,b) return a:upper()..b end)
    return s
  end

  local function itemName(game,id)
    local d=game and game.data and game.data.items and game.data.items[id]
    return (d and d.name) or humanId(id)
  end

  local function pokemonName(game,id)
    local d=game and game.data and game.data.pokemon and game.data.pokemon[id]
    return (d and d.name) or humanId(id)
  end

  local function mapItemFacts(game)
    local facts={}
    local maps=(game and game.data and game.data.maps) or {}
    local maps2=(game and game.data and game.data.gen2Maps) or {}
    local function scanMaps(source)
    for mapId,def in pairs(source) do
      if type(def)=="table" then
        local seen={}
        local function add(raw)
          local id=itemId(game,raw)
          if id and not seen[id] and game.data.items and game.data.items[id] then
            seen[id]=true
            local idef=game.data.items[id]
            local mk=machineKind(idef,id)
            local mnum=tonumber(tostring(id):match("%d+")) or tonumber(tostring((idef and (idef.tmLabel or idef.name)) or ""):match("%d+"))
            facts[#facts+1]={map=mapId,item=id,name=itemName(game,id),machineKind=mk,machine=mnum,move=machineMove(idef)}
          end
        end
        for _,obj in ipairs(def.objects or {}) do
          if type(obj)=="table" then
            add(obj.item)
            if type(obj.itemball)=="table" then add(obj.itemball.item) end
          end
        end
        for _,ev in ipairs(def.events or {}) do
          if type(ev)=="table" and type(ev.hiddenItem)=="table" then add(ev.hiddenItem.item) end
        end
        for _,bg in ipairs(def.bgEvents or def.backgroundEvents or {}) do
          if type(bg)=="table" then
            add(bg.item)
            if type(bg.hiddenItem)=="table" then add(bg.hiddenItem.item) end
          end
        end
      end
    end
    end
    scanMaps(maps)
    if maps2~=maps then scanMaps(maps2) end
    return facts
  end

  local function randomStartFact(a)
    if not a or not a.cfg or a.cfg.random_start=="OFF" then return nil end
    local cert=a.progression and a.progression.certificate
    if cert and cert.kind=="HM_ESCAPE" then
      return {tier="strong",text=("Your path begins at %s. Defeat the local Gym for %s and find %s nearby; it lets %s open the way out."):format(humanId(cert.start),humanId(cert.badge),humanId(cert.hm),humanId(cert.move))}
    end
    local dest=randomStartDestination and randomStartDestination(a)
    if not dest then return nil end
    return {tier="strong", text="A useful path begins near "..humanId(dest.id or dest.map or dest.mapId or "your random start").."."}
  end

  local function buildHintPools(a)
    local pools={trash={},medium={},strong={}}
    if not a or not a.game then return pools end
    local facts=mapItemFacts(a.game)
    for _,f in ipairs(facts) do
      local map=humanId(f.map)
      if f.machineKind=="TM" then
        local label=f.machine and ("TM"..string.format("%02d",f.machine)) or f.name
        local move=f.move and (" ("..humanId(f.move)..")") or ""
        pools.strong[#pools.strong+1]=label..move.." is at "..map.."."
      elseif f.machineKind=="HM" then
        local move=f.move and (" ("..humanId(f.move)..")") or ""
        pools.strong[#pools.strong+1]=f.name..move.." is at "..map.."."
      else
        pools.medium[#pools.medium+1]=f.name.." can be found around "..map.."."
        pools.trash[#pools.trash+1]="Something was dropped somewhere around "..map.."."
      end
    end
    local rs=randomStartFact(a)
    if rs then pools.strong[#pools.strong+1]=rs.text end
    local route=R.routeHint and R.routeHint()
    if route then
      pools.strong[#pools.strong+1]=route
      pools.medium[#pools.medium+1]=route
    end
    local check=R.logicCheck and R.logicCheck(a.game)
    if check and check.next and check.next.text then
      pools.strong[#pools.strong+1]="NEXT LOGIC: "..check.next.text
    end
    if check and check.blocker and check.blocker.text then
      pools.strong[#pools.strong+1]="BLOCKER: "..check.blocker.text
    end

    -- Always provide truthful seed-specific filler, even on a sparse fixture.
    -- The species is chosen from the exact enabled pool, so the statement is
    -- true without claiming a location the engine has not generated yet.
    local species=eligibleSpecies(a.game,a.cfg)
    if #species>0 then
      for i=1,math.min(24,#species) do
        local pick=Core.rng(Core.hash("hint-filler|"..i,a.seed)):pick(species)
        pools.trash[#pools.trash+1]=pokemonName(a.game,pick).." is eligible to appear in this seed."
      end
    end
    if #pools.medium==0 then pools.medium[1]="This seed still has useful items hidden across the world." end
    if #pools.strong==0 then pools.strong[1]="Keep checking major routes; this seed has no resolved strong location hint yet." end
    return pools
  end

  local function chooseHint(a,tier,key)
    a.hintPools=a.hintPools or buildHintPools(a)
    local pool=a.hintPools[tier] or a.hintPools.medium
    if #pool==0 then return "No useful rumor was found." end
    return Core.rng(Core.hash("hint|"..tostring(tier).."|"..tostring(key),a.seed)):pick(pool)
  end

  function R.hintForSign(mapId,x,y)
    local a=Runtime.active
    if not a then return nil end
    local key=tostring(mapId).."|"..tostring(x).."|"..tostring(y)
    -- Guided LOGIC runs deliberately surface route direction on several signs
    -- instead of hiding the one correct path behind a rare paid hint.  The
    -- choice is deterministic per seed/sign, so races see identical guidance.
    local route=R.routeHint and R.routeHint()
    if route then
      local rr=Core.rng(Core.hash("route-sign|"..key,a.seed)):int(1,100)
      if rr<=45 then return route,"strong" end
    end
    local roll=Core.rng(Core.hash("sign-tier|"..key,a.seed)):int(1,100)
    local tier=(roll<=35 and "trash") or (roll<=75 and "medium") or "strong"
    return chooseHint(a,tier,"sign|"..key),tier
  end

  function R.buyHint(game)
    local a=Runtime.active
    if not a then return nil,"No randomized seed is active." end
    if hintMoney(game)<5000 then return nil,"You need 5000 Poke Dollars." end
    local n=(tonumber(mod.save:get("paid_hint_count",0)) or 0)+1
    local roll=Core.rng(Core.hash("paid-hint-tier|"..n,a.seed)):int(1,100)
    local tier=(roll<=15 and "trash") or (roll<=60 and "medium") or "strong"
    local text=chooseHint(a,tier,"paid|"..n)
    if not text then return nil,"No answer is available." end
    setHintMoney(game,hintMoney(game)-5000)
    mod.save:set("paid_hint_count",n)
    return text,nil,tier
  end

  local BattleHelpers={
    vanillaVictories=nil,
    G1_BOSS_CLASSES={
      OPP_LORELEI=true, OPP_BRUNO=true, OPP_AGATHA=true, OPP_LANCE=true, OPP_RIVAL3=true,
    },
  }
  restoreGen1BadgeRewards=function()
    if not BattleHelpers.vanillaVictories then return end
    local ok,v=pcall(require,"data.scripts.victories"); if not ok or type(v)~="table" then return end
    for key,rec in pairs(BattleHelpers.vanillaVictories) do
      local dst=v[key]
      if type(dst)=="table" and type(rec)=="table" then
        for k in pairs(dst) do dst[k]=nil end
        for k,val in pairs(rec) do dst[k]=Core.copy(val) end
      end
    end
  end
  applyBadgeRewards=function(active)
    restoreGen1BadgeRewards()
    if not active or not active.badgePlan or active.badgePlan.mode=="VANILLA" then return end
    if active.generation==1 then
      local ok,v=pcall(require,"data.scripts.victories"); if not ok or type(v)~="table" then return end
      if not BattleHelpers.vanillaVictories then
        BattleHelpers.vanillaVictories={}
        -- Current hosts also export helper functions from victories. Only
        -- gym reward records belong to the randomizer's restoration snapshot.
        for _,key in ipairs(G1_GYM_ORDER) do
          if type(v[key])=="table" then BattleHelpers.vanillaVictories[key]=Core.copy(v[key]) end
        end
      end
      for gym,badge in pairs(active.badgePlan.gymToBadge or {}) do
        local r=v[gym]
        if r and badge then
          r.badge=badge
          -- Original leader dialogue names its vanilla badge. Use the host's
          -- generic reward line so displayed text always matches the shuffled reward.
          r.dialogue=nil; r.tmPre=nil; r.tmDialogue=nil
        end
      end
    end
  end

  scaleWildLevel=function(a,enc)
    if not a or not enc or type(enc.level)~="number" then return enc end
    local mapId=tostring(enc.mapId or enc.area or enc.map or "")
    local world=a.game and (a.game.world or a.game.overworld)
    if mapId=="" then mapId=tostring(world and world.map and world.map.id or "") end
    local routeCap=R._routeProgressionMax(a,mapId,"wild",false)
    local percentageRouteCap=R._percentageRouteBaselineMax(a,mapId,"wild",false)
    if percentageRouteCap then routeCap=routeCap and math.min(routeCap,percentageRouteCap) or percentageRouteCap end
    if routeCap and enc.level>routeCap then
      local h=tonumber(Core.hash("guided-wild|"..mapId.."|"..tostring(enc.species or "?").."|"..tostring(enc.slot or "?").."|"..tostring(enc.level),a.seed)) or 0
      enc.level=math.max(1,routeCap-(math.abs(h)%3))
    end
    local gen1StartCap=(not R.pureProgressionEnabled(a)) and gen1StartWildProgressionMax(a,mapId) or nil
    local gen2StartCap=(not R.pureProgressionEnabled(a)) and R._gen2StartWildProgressionMax(a,mapId) or nil
    local startCap=gen1StartCap or gen2StartCap
    if startCap and enc.level>startCap then
      if gen2StartCap then
        local h=tonumber(Core.hash("g2-start-wild|"..mapId.."|"..tostring(enc.species or "?").."|"..tostring(enc.slot or "?").."|"..tostring(enc.level),a.seed)) or 0
        enc.level=math.max(2,startCap-(math.abs(h)%3))
      else
        enc.level=startCap
      end
    end
    local pct=R.percentageScalingEnabled(a) and (tonumber(a.cfg.wild_levels) or 0) or 0
    if pct~=0 then
      enc.level=math.max(1,math.min(100,math.floor(enc.level*(100+pct)/100+0.5)))
    end
    return enc
  end

  -- 1.3.31 final level authority. Hook chains are intentionally composable,
  -- so a lower-priority/inner mod may adjust an encounter after the ordinary
  -- Randomizer level pass. The outer guard below reasserts only the invariant
  -- that PROGRESSION owns the global party-relative band and that a guided
  -- LOGIC Random Start path cannot exceed its protected ceiling. It never
  -- raises Percentage/Hybrid content that another mod made easier.
  function R._finalWildLevelAuthority(a,enc,mapId,tag)
    if not a or not enc or type(enc.level)~="number" then return enc end
    local world=a.game and (a.game.world or a.game.overworld)
    mapId=tostring(mapId or enc.mapId or enc.area or enc.map or a.routeRuntimeMapId
      or (world and world.map and world.map.id) or "")
    local species=tostring(enc.species or "?")
    local slot=tostring(enc.slot or "?")
    local h=tonumber(Core.hash(table.concat({"final-wild",tostring(tag or "field"),mapId,species,slot},"|"),a.seed)) or 0
    local delta=math.abs(h)%3
    if R.pureProgressionEnabled(a) then
      local ceiling=math.max(1,partyPeakLevel(a.game)-1)
      enc.level=math.max(1,math.min(100,ceiling-delta))
      return enc
    end
    local cap=R._routeProgressionMax(a,mapId,"wild",false)
    local fixed=R._percentageRouteBaselineMax(a,mapId,"wild",false)
    if fixed then cap=cap and math.min(cap,fixed) or fixed end
    local c1=gen1StartWildProgressionMax(a,mapId)
    local c2=R._gen2StartWildProgressionMax(a,mapId)
    if c1 then cap=cap and math.min(cap,c1) or c1 end
    if c2 then cap=cap and math.min(cap,c2) or c2 end
    if cap then
      local pct=R.percentageScalingEnabled(a) and (tonumber(a.cfg and a.cfg.wild_levels) or 0) or 0
      if pct~=0 then cap=math.floor(cap*(100+pct)/100+0.5) end
      local hard=math.max(1,math.min(100,cap-delta))
      if enc.level>hard then enc.level=hard end
    end
    enc.level=math.max(1,math.min(100,enc.level))
    return enc
  end

  function BattleHelpers.trainerPartyIsBoss(game,classId,partyId)
    local id=tostring(classId or ""):upper()
    -- Gen 2 exposes one authoritative predicate covering Johto/Kanto leaders,
    -- Elite Four, Champion and Red.
    local okB,B=pcall(require,"src.battle.gen2.Battle")
    if okB and B and B.isGymLeader and B.isGymLeader(classId) then return true end
    -- Gen 1 gym status is roster-specific (Giovanni's early Rocket parties are
    -- ordinary trainer battles), so use the same victory table as BattleState.
    local okV,victories=pcall(require,"data.scripts.victories")
    if okV and type(victories)=="table" then
      local reward=victories[tostring(classId).."#"..tostring(partyId or 1)]
      if reward and reward.badge~=nil then return true end
    end
    return BattleHelpers.G1_BOSS_CLASSES[id]==true
      or id:find("LEADER",1,true)~=nil or id:find("ELITE",1,true)~=nil
      or id:find("CHAMPION",1,true)~=nil or id:find("LANCE",1,true)~=nil
      or id=="RED" or id=="OPP_RED"
  end

  function BattleHelpers.trainerIsBoss(battle)
    if not battle or battle.kind~="trainer" then return false end
    if battle.isGymLeader then return true end
    local t=battle.trainer or {}
    if BattleHelpers.trainerPartyIsBoss(battle.game or (Runtime.active and Runtime.active.game),
        battle.oppClass or t.classId or t.class or t.id,
        battle.partyIndex or t.memberId or t.index or 1) then return true end
    local id=tostring(t.id or t.class or ""):upper()
    return id:find("LEADER",1,true)~=nil or id:find("ELITE",1,true)~=nil
      or id:find("CHAMPION",1,true)~=nil or id:find("LANCE",1,true)~=nil
      or id:find("RED",1,true)~=nil
  end

  function BattleHelpers.currentTypes(battle,battler)
    if not battler then return {} end
    if type(battler.curTypes)=="table" then return battler.curTypes end
    if type(battler.types)=="table" then return battler.types end
    local def=battler.def
    if not def and battle and battle.speciesDef then
      local ok,d=pcall(battle.speciesDef,battle,battler); if ok then def=d end
    end
    return (def and def.types) or {}
  end

  function BattleHelpers.typeEffect(data,moveType,defTypes)
    local mult=10
    local chart=data and data.type_chart and data.type_chart.matchups or {}
    for _,row in ipairs(chart) do
      if row.attacker==moveType then
        for _,dt in ipairs(defTypes or {}) do
          if row.defender==dt then mult=math.floor(mult*(tonumber(row.multiplier) or 10)/10); break end
        end
      end
    end
    return mult
  end

  function BattleHelpers.smartEnemyMove(battle,vanilla,aggression)
    if not battle or battle.kind~="trainer" or not battle.enemy or not battle.player then return vanilla end
    -- Keep vanilla item/switch/special actions. This layer only improves move choice.
    if type(vanilla)=="table" and (vanilla.special or vanilla.kind=="switch" or vanilla.kind=="item") then return vanilla end
    local moves={}
    if battle.usableMoves then
      local ok,list=pcall(battle.usableMoves,battle,battle.enemy)
      if ok and type(list)=="table" then moves=list end
    end
    if #moves==0 then
      local list=battle.enemy.curMoves or battle.enemy.moves or (battle.enemy.mon and battle.enemy.mon.moves) or {}
      for _,m in ipairs(list) do
        local id=type(m)=="table" and (m.id or m.move) or m
        local pp=type(m)=="table" and m.pp or 1
        if id and (pp==nil or pp>0) then moves[#moves+1]=m end
      end
    end
    if #moves<2 then return vanilla end
    local data=battle.data or (Runtime.active and Runtime.active.game and Runtime.active.game.data) or {}
    local atkTypes=BattleHelpers.currentTypes(battle,battle.enemy)
    local defTypes=BattleHelpers.currentTypes(battle,battle.player)
    local hp=battle.player.hp or (battle.player.mon and battle.player.mon.hp) or 9999
    local scored={}
    for _,m in ipairs(moves) do
      local id=type(m)=="table" and (m.id or m.move) or m
      local def
      if Runtime.active and Runtime.active.generation==2 and battle.moveDef then
        local ok,d=pcall(battle.moveDef,battle,id); if ok then def=d end
      end
      def=def or (data.moves and data.moves[id])
      if id and def then
        local power=tonumber(def.power) or 0
        local acc=tonumber(def.accuracy) or 100
        if acc>255 then acc=100 end
        local eff=BattleHelpers.typeEffect(data,def.type,defTypes)
        local stab=1.0; for _,t in ipairs(atkTypes) do if t==def.type then stab=1.5 break end end
        local score=power*stab*(eff/10)*math.max(0.45,math.min(1,acc/100))
        if eff==0 then score=-1000 end
        if power==0 then
          score=8
          local targetStatus=battle.player.status or (battle.player.mon and battle.player.mon.status)
          local e=tostring(def.effect or "")
          if targetStatus and (e:find("POISON") or e:find("PARAL") or e:find("SLEEP") or e:find("BURN")) then score=-25 end
          if e:find("HEAL") then
            local ehp=battle.enemy.hp or (battle.enemy.mon and battle.enemy.mon.hp) or 1
            local emax=battle.enemy.maxHp or (battle.enemy.stats and battle.enemy.stats.hp) or (battle.enemy.mon and battle.enemy.mon.stats and battle.enemy.mon.stats.hp) or ehp
            score=(ehp*2<emax) and 55 or -5
          elseif e:find("ATTACK_UP") or e:find("SPECIAL_UP") or e:find("SPEED_UP") then score=18 end
        elseif score>=hp then score=score+120 end
        local pri=tonumber(def.priority) or 0; if pri>0 and hp<math.max(1,power*2) then score=score+35 end
        scored[#scored+1]={id=id,score=score,move=m}
      end
    end
    if #scored==0 then return vanilla end
    table.sort(scored,function(a,b) return a.score>b.score end)
    local rng=(Runtime.active and Core.rng(Core.hash("strong-ai|"..tostring(battle.turnCount or battle.turn or 0).."|"..tostring(scored[1].id),Runtime.active.seed))) or nil
    -- Strong is intentionally not omniscient/perfect: regular trainers use the
    -- best heuristic move ~75% of the time, bosses ~90%; otherwise vanilla.
    if rng and rng:int(1,100)>aggression then return vanilla end
    local best=scored[1]
    local pick=best.id
    if Runtime.active and Runtime.active.generation==1 and type(best.move)=="table" then
      return best.move
    end
    if type(vanilla)=="table" then
      local out={}; for k,v in pairs(vanilla) do out[k]=v end
      out.id=pick; if out.move~=nil then out.move=pick end
      return out
    end
    return pick
  end

  function R._finalTrainerPartyAuthority(a,classId,partyId,party,mapIdOverride)
    if not a or type(party)~="table" then return party end
    local boss=BattleHelpers.trainerPartyIsBoss(a.game,classId,partyId)
    local world=a.game and (a.game.world or a.game.overworld)
    local mapId=tostring(mapIdOverride or a.routeRuntimeMapId or (world and world.map and world.map.id) or "")
    local cap=nil
    if R.pureProgressionEnabled(a) then
      cap=progressionAnchor(a,boss and "boss" or "trainer")
    else
      cap=R._routeProgressionMax(a,mapId,boss and "boss" or "trainer",boss)
      local fixed=R._percentageRouteBaselineMax(a,mapId,boss and "boss" or "trainer",boss)
      if fixed then cap=cap and math.min(cap,fixed) or fixed end
      local c1=gen1StartTrainerProgressionMax(a,boss,mapId)
      local c2=R._gen2StartTrainerProgressionMax(a,boss,mapId)
      local c3=cianwoodGymProgressionMax(a,boss)
      if c1 then cap=cap and math.min(cap,c1) or c1 end
      if c2 then cap=cap and math.min(cap,c2) or c2 end
      if c3 then cap=cap and math.min(cap,c3) or c3 end
      if cap then
        local raw=boss and (tonumber(a.cfg and a.cfg.boss_levels) or 0) or (tonumber(a.cfg and a.cfg.trainer_levels) or 0)
        if R.percentageScalingEnabled(a) and raw~=0 then cap=math.floor(cap*(100+raw)/100+0.5) end
      end
    end
    if not cap then return party end
    local count=#party
    for i,row in ipairs(party) do
      if type(row)=="table" and type(row.level)=="number" then
        local h=tonumber(Core.hash(table.concat({"final-trainer",tostring(classId),tostring(partyId),tostring(i)},"|"),a.seed)) or 0
        local delta=(count>1) and (math.abs(h)%3) or 0
        local hard=math.max(1,math.min(100,cap-delta))
        if R.pureProgressionEnabled(a) or row.level>hard then row.level=hard end
        -- Any downstream species/level rewrite may have left constructed Gen 2
        -- HP/stats stale. Let the host's post-hook refresh rebuild them.
        if row.hp~=nil or row.maxHp~=nil or row.stats~=nil then
          row.hp=nil; row.maxHp=nil; row.stats=nil
        end
      end
    end
    return party
  end

  function R.ensureProgressionLearners(game,cfg,starters)
    if not cfg.progression_items or not game.data._urItemPlan then return end
    local seen={}
    local function ensure(id)
      if seen[id] then return end
      seen[id]=true
      local def=game.data.pokemon[id]
      if not def then return end
      def.tmhm=def.tmhm or {}
      for _,move in ipairs(hmMoves(game)) do
        if not Core.tableHas(def.tmhm,move) then def.tmhm[#def.tmhm+1]=move end
      end
      for _,e in ipairs(def.evolutions or {}) do
        local nextId=e.species or e.into
        if nextId then ensure(nextId) end
      end
    end
    for _,source in ipairs((Adapters[versionId(game)] or {}).starters or {}) do
      local id=(starters or {})[source] or source
      ensure(id)
    end
  end

  function R.itemGiftForRun(a,source,key,mapId)
    if not a then return source end
    local game=a.game
    local id=itemId(game,source)
    local def=id and game.data.items[id]
    if ItemLogic and a.itemPlan then
      local map=mapId or tostring(key or ""):match("^([^|]+)")
      local target,handled=ItemLogic.gift(a.itemPlan,map,id)
      if handled then return itemValue(game,target,source) end
    end
    if a.cfg.gift_items~="RANDOM" or not isRandomizableItem(game,id,def) then return source end
    local pool=safeItemPool(game,machineKind(def,id)=="TM")
    local pick=Core.rng(Core.hash("item-gift|"..tostring(key).."|"..id,a.seed)):pick(pool)
    return pick and itemValue(game,pick,source) or source
  end

  function R.itemGift(game,source,key,mapId)
    return R.itemGiftForRun(activeFor(game),source,key,mapId)
  end

  function R.fieldTreeItem(game,source,tree)
    local a=activeFor(game)
    if not a or a.cfg.field_items=="UNCHANGED" then return source end
    local id=itemId(game,source)
    if not isRandomizableItem(game,id,id and game.data.items[id]) then return source end
    local pool=safeItemPool(game,false)
    if a.cfg.field_items=="SHUFFLE" then
      local ok,Apricorns=pcall(require,"src.core.gen2.Apricorns")
      if not ok or not Apricorns.treeFruit then return source end
      pool={}
      for i=1,(Apricorns.NUM_FRUIT_TREES or 30) do pool[i]=Apricorns.treeFruit(i) end
      Core.rng(Core.hash("fruit-trees",a.seed)):shuffle(pool)
      local pick=pool[tonumber(tree)]
      return pick and itemValue(game,pick,source) or source
    end
    local pick=Core.rng(Core.hash("fruit-tree|"..tostring(tree),a.seed)):pick(pool)
    return pick and itemValue(game,pick,source) or source
  end

  function R.visibleEncounter(a,source,level,mapId,terrain,key)
    if not a then return {species=source,level=level} end
    local id=Core.resolveIndexedId(a.game.data.pokemon,source) or source
    if type(id)~="string" or not a.game.data.pokemon[id] then return {species=source,level=level} end
    -- The visible table is deterministic and never consumes the native
    -- encounter RNG or the active run's rotating area-pool counters.
    local pick=encounterPick(a,id,"visible|"..key,encounterAreaKey(mapId,terrain))
    local out={species=pick,level=level or 5,mapId=mapId,slot=key}
    scaleWildLevel(a,out)
    R._finalWildLevelAuthority(a,out,mapId,"visible")
    R._evolveWildSpeciesForLevel(a,out)
    if type(source)=="number" then out.species=(a.game.data.pokemon[out.species] or {}).index or source end
    return out
  end

  R.selectSpecies=selector
  R.buildStarterMap=buildStarterMap

  function R.installHooks()
    -- Outer post-processors are deliberately much higher than ordinary mod
    -- priorities (Kaizo uses 1000). They do not randomize content; they only
    -- enforce the final level invariant after every downstream wrapper has run.
    mod.hooks:wrap("encounter.species",function(nextFn,enc,ctx)
      local out=nextFn(enc,ctx)
      local game=(Runtime.active and Runtime.active.game) or mod.game
      local a=activeFor(game)
      if not a or not out then return out end
      R._finalWildLevelAuthority(a,out,ctx and ctx.mapId,"field")
      return R._evolveWildSpeciesForLevel(a,out)
    end,100000)

    mod.hooks:wrap("encounter.fishing",function(nextFn,rod,mapId,candidates,ctx)
      local out=nextFn(rod,mapId,candidates,ctx)
      local game=(Runtime.active and Runtime.active.game) or mod.game
      local a=activeFor(game)
      if not a or not out then return out end
      R._finalWildLevelAuthority(a,out,mapId,"fishing")
      return R._evolveWildSpeciesForLevel(a,out)
    end,100000)

    mod.hooks:wrap("trainer.party",function(nextFn,classId,partyId,party)
      local out=nextFn(classId,partyId,party)
      local game=(Runtime.active and Runtime.active.game) or mod.game
      local a=activeFor(game)
      if not a or not out then return out end
      return R._finalTrainerPartyAuthority(a,classId,partyId,out,a.routeRuntimeMapId)
    end,100000)

    -- One-time post-starter portal. LOGIC only uses walk-back-safe early hubs;
    -- CHAOS may use the broader canonical fly set. The destination itself is
    -- always sourced from imported map/fly data, never guessed floor tiles.
    mod.hooks:wrap("warp.destination",function(nextFn,destMap,x,y,ctx)
      local dm,dx,dy=nextFn(destMap,x,y,ctx)
      local game=(ctx and ctx.game) or (Runtime.active and Runtime.active.game) or mod.game
      local a=activeFor(game)
      if a and a.doorPlan and ctx and ctx.warp then
        local reroute=a.doorPlan.byWarp and a.doorPlan.byWarp[ctx.warp]
        if reroute and reroute.map and reroute.x~=nil and reroute.y~=nil then
          dm,dx,dy=reroute.map,reroute.x,reroute.y
        end
      end
      if a and a.randomStartRespawnLocked and isPokemonCenterDestination(a,dm) then
        unlockRandomStartRespawn(a)
      end
      local rsctx=Core.copy(ctx or {}); rsctx.destMap=dm
      if not shouldRandomStart(a,rsctx) then return dm,dx,dy end
      local target=randomStartDestination(a)
      if not target then return dm,dx,dy end
      a.randomStartUsed=true
      a.randomStartArmed=false
      mod.save:set("random_start_used",true)
      mod.save:set("random_start_armed",false)
      -- 1.3.31: make the destination authoritative immediately. Gen 2 can
      -- request encounter/trainer hooks before the next map.entered listener has
      -- reconciled process-local route state. Without this, the first battle on
      -- a LOGIC Random Start could briefly inherit the old map's level policy.
      a.routeRuntimeMapId=tostring(target.id)
      if Route.systemActive(a) then
        local st=Route.state(a)
        st.current=tostring(target.id); st.guidedMap=tostring(target.id)
        st.offRoute=false; st.offRouteMap=nil; st.visited[tostring(target.id)]=true
        st.routeLegsCompleted=0
        local pick=Route.chooseTarget(a,tostring(target.id),Route.currentMapId(a))
        st.target=pick and pick.id or nil
        Route.persist(a)
      end
      lockRandomStartRespawn(a,target)
      -- Gen 1 no longer writes Pokedex/Parcel/guard/object progression flags
      -- here. LOGIC starts are certified using ordinary item/badge/script state.
      return target.id,target.x,target.y
    end)

    -- Until the player reaches a Pokemon Center after Random Start, every
    -- blackout reasserts the seeded local respawn. This covers trainer losses
    -- and poison whiteouts and prevents cart story writers from silently
    -- sending the player back to the bedroom/home spawn.
    mod.events:on("world.blacked_out", function(ev)
      -- The native blackout rebuilds the current map/world state without a
      -- save.loaded event.  Random Start's heal target lives in the save, so
      -- it can survive even if the Randomizer's process-local active plan is
      -- lost or stale.  Rehydrate the committed seed/config here so trainer,
      -- boss and wild level modifiers (plus every other runtime hook) remain
      -- active after the warp instead of silently falling back to vanilla.
      local game=(Runtime.active and Runtime.active.game) or mod.game
      local a=forceSavedRuntime(game,"restore after blackout")
      if a and a.randomStartRespawnLocked then applyRandomStartRespawn(a) end
    end)

    -- A Cianwood LOGIC start happens before the player owns Plain Badge /
    -- Strength, but Chuck is physically behind a Strength-boulder puzzle.
    -- Open only that seeded-start copy of the gym by placing the three row-7
    -- boulders in the cart-valid solved arrangement as soon as the map builds.
    mod.events:on("map.entered", function(ev)
      if not ev or tostring(ev.mapId or "")~="CIANWOOD_GYM" then return end
      local game=(Runtime.active and Runtime.active.game) or mod.game
      local a=activeFor(game)
      if a then solveCianwoodStartBoulders(a) end
    end)

    -- Gen 1 gifts have an official event seam that also covers direct engine
    -- callbacks such as the Celadon Game Corner prize counters.  Using the
    -- event (rather than only script.command) is important: several vanilla
    -- gifts never pass through ScriptRunner at all.
    mod.events:on("pokemon.before_give", function(gift)
      local game=(gift and gift.ctx and gift.ctx.game) or (Runtime.active and Runtime.active.game) or mod.game
      local a=activeFor(game)
      if not a or type(gift)~="table" or not gift.species then return end
      local ctx=gift.ctx or {}
      local mapId=(ctx.overworld and ctx.overworld.map and ctx.overworld.map.id)
        or ctx.mapId
        or (ctx.game and ctx.game.overworld and ctx.game.overworld.map and ctx.game.overworld.map.id)
        or "?"
      local src=Core.resolveIndexedId(a.game.data.pokemon,gift.species) or gift.species
      local pick=giftPick(a,mapId,src,gift.level)
      if pick then
        local d=a.game.data.pokemon[pick]
        gift.species=(type(gift.species)=="number" and d and d.index) or pick
      end
      if not a.starterMap[src] and type(gift.level)=="number"
          and (pick or R.pureProgressionEnabled(a)) then
        gift.level=scaleGiftLevel(a,gift.level)
      end
    end)

    mod.hooks:wrap("encounter.species", function(nextFn, enc, ctx)
      enc=nextFn(enc,ctx)
      if not enc or not enc.species then return enc end
      local game=(ctx and ctx.data and Runtime.active and Runtime.active.game) or (Runtime.active and Runtime.active.game) or mod.game
      local a=game and activeFor(game) or Runtime.active
      if not a then return enc end
      local src=Core.resolveIndexedId(a.game.data.pokemon,enc.species) or enc.species
      if type(src)~="string" or not a.game.data.pokemon[src] then return enc end
      local mapId=tostring(ctx and ctx.mapId or "?")
      local eventKind=tostring(ctx and ctx.kind or "")
      local kind=tostring(ctx and ctx.terrain or "grass")
      local areaKey
      if eventKind=="contest" then
        areaKey=R._contestAreaKey()
      else
        local tod=(kind=="grass") and (ctx and ctx.daytime) or nil
        areaKey=encounterAreaKey(mapId,kind,tod)
      end
      local key=R._encounterPhysicalSlotKey(a,areaKey,enc.slot)
        or R._encounterSignatureKey(areaKey,src,enc.level)
      local pick=encounterPick(a,src,key,areaKey,ctx and ctx.rng)
      if type(enc.species)=="number" then local d=a.game.data.pokemon[pick]; enc.species=(d and d.index) or enc.species else enc.species=pick end
      raiseWildBaseline(a,enc,fieldWildCeiling(a,enc,ctx))
      return scaleWildLevel(a,enc)
    end)

    -- Fishing is a separate hook on both generations and does not pass
    -- through encounter.species. Keep the rod/map/slot roll vanilla, then
    -- transform only the selected species under the same WILD setting.
    mod.hooks:wrap("encounter.fishing", function(nextFn, rod, mapId, candidates, ctx)
      local enc=nextFn(rod,mapId,candidates,ctx)
      local game=(Runtime.active and Runtime.active.game) or mod.game
      local a=activeFor(game)
      if not a or not enc or not enc.species then return enc end
      local src=Core.resolveIndexedId(a.game.data.pokemon,enc.species) or enc.species
      if type(src)~="string" or not a.game.data.pokemon[src] then return enc end
      local fishArea=R._fishingAreaKey(a,rod,mapId,ctx)
      -- Neither Gen 1 nor the 0.2.29 Gen 2 fishing seam exposes the physical
      -- fishing-row index. Species+level is the strongest stable identity.
      local key=R._encounterSignatureKey(fishArea,src,enc.level)
      local pick=encounterPick(a,src,key,fishArea,ctx and ctx.rng)
      if type(enc.species)=="number" then
        local d=a.game.data.pokemon[pick]
        enc.species=(d and d.index) or enc.species
      else
        enc.species=pick
      end
      raiseWildBaseline(a,enc,fishingWildCeiling(a,rod,candidates,ctx,enc.level))
      return scaleWildLevel(a,enc)
    end)

    mod.hooks:wrap("battle.enemy_action", function(nextFn,battle)
      local vanilla=nextFn(battle)
      local game=(battle and battle.game) or (Runtime.active and Runtime.active.game) or mod.game
      local a=activeFor(game)
      if not a or not battle or battle.kind~="trainer" then return vanilla end
      local boss=BattleHelpers.trainerIsBoss(battle)
      local mode=boss and a.cfg.boss_ai or a.cfg.trainer_ai
      if mode~="STRONG" then return vanilla end
      return BattleHelpers.smartEnemyMove(battle,vanilla,boss and 90 or 75)
    end)

    mod.hooks:wrap("trainer.party", function(nextFn, classId, partyId, party)
      party=nextFn(classId,partyId,party)
      local game=(Runtime.active and Runtime.active.game) or mod.game
      local a=activeFor(game)
      if not a or type(party)~="table" then return party end
      local partyIsBoss=BattleHelpers.trainerPartyIsBoss(a.game,classId,partyId)
      local gen=generation(a.game)
      local out={}
      local world=a.game and (a.game.world or a.game.overworld)
      local trainerMapId=tostring(a.routeRuntimeMapId or (world and world.map and world.map.id) or "")
      local routeProgressionMax=R._routeProgressionMax(a,trainerMapId,partyIsBoss and "boss" or "trainer",partyIsBoss)
      local percentageRouteMax=R._percentageRouteBaselineMax(a,trainerMapId,partyIsBoss and "boss" or "trainer",partyIsBoss)
      if percentageRouteMax then routeProgressionMax=routeProgressionMax and math.min(routeProgressionMax,percentageRouteMax) or percentageRouteMax end
      local useLocalCaps=not R.pureProgressionEnabled(a)
      local gen1ProgressionMax=useLocalCaps and gen1StartTrainerProgressionMax(a,partyIsBoss,trainerMapId) or nil
      local gen2ProgressionMax=useLocalCaps and R._gen2StartTrainerProgressionMax(a,partyIsBoss,trainerMapId) or nil
      local cianwoodProgressionMax=useLocalCaps and cianwoodGymProgressionMax(a,partyIsBoss) or nil
      local progressionMax=routeProgressionMax or gen1ProgressionMax or gen2ProgressionMax or cianwoodProgressionMax
      -- 1.3.16: randomized/scaled trainer parties no longer inherit huge
      -- per-slot vanilla gaps.  The party's highest native level becomes the
      -- top of a tight three-level band (base-2 .. base), with deterministic
      -- slot variation so teams are not flattened to one identical level.
      -- Example: a native Lv8/Lv23 pair becomes roughly Lv22/Lv23 at 0%, not
      -- Lv8/Lv23 and not Lv23/Lv23.  Random Start safety caps can lower the
      -- band ceiling, then the user's live Trainer/Boss percentage applies.
      -- TRAINERS=UNCHANGED at 0% preserves the original per-slot spread.
      local trainerBaseMax=0
      for _,row in ipairs(party) do
        trainerBaseMax=math.max(trainerBaseMax,tonumber(row and row.level) or 0)
      end
      local configuredPct=partyIsBoss and (tonumber(a.cfg.boss_levels) or 0)
        or (tonumber(a.cfg.trainer_levels) or 0)
      local partyLevelPct=R.percentageScalingEnabled(a) and configuredPct or 0
      local useTrainerBand=R.progressionScalingEnabled(a) or (a.cfg.trainers~="UNCHANGED") or partyLevelPct~=0
      local partyCount=#party
      local trainerBandPatterns={
        [1]={0},
        [2]={1,0},
        [3]={2,1,0},
        [4]={2,1,0,1},
        [5]={2,1,0,2,1},
        [6]={2,1,0,2,1,0},
      }
      local trainerBandShift=0
      if partyCount>1 then
        local h=tonumber(Core.hash("trainer-level-band|"..tostring(classId).."|"..tostring(partyId),a.seed)) or 0
        trainerBandShift=math.abs(h)%partyCount
      end
      local function trainerBandDelta(slotIndex)
        local pat=trainerBandPatterns[math.max(1,math.min(6,partyCount))] or trainerBandPatterns[1]
        return pat[((slotIndex-1+trainerBandShift)%#pat)+1] or 0
      end
      local progressionBaseMax=trainerBaseMax
      local globalProgressionCeiling=R.progressionScalingEnabled(a)
        and progressionAnchor(a,partyIsBoss and "boss" or "trainer") or trainerBaseMax
      if progressionMax then
        -- RBY start safety only compresses early-inappropriate vanilla content.
        -- Once the player catches up, the corridor/gym returns to its original
        -- level band; only the user's explicit live Level % may push it higher.
        if gen1ProgressionMax and not routeProgressionMax and progressionBaseMax>0 then
          progressionMax=math.min(progressionMax,progressionBaseMax)
        end
      end
      for i,slot in ipairs(party) do
        local s=Core.copy(slot)
        local src=Core.resolveIndexedId(a.game.data.pokemon,s.species) or s.species
        if type(src)=="string" and a.game.data.pokemon[src] then
          local trainerKey=tostring(classId).."|"..tostring(partyId)
          local key=trainerKey.."|"..i.."|"..src
          local pick=rivalStarterPick(a,classId,partyId,src,s.level)
          if not pick and a.cfg.trainers~="UNCHANGED" then pick=a.trainerMap[key] end
          if not pick and a.cfg.trainers~="UNCHANGED" then
            local mode=a.cfg.trainers=="SIMILAR" and "SIMILAR" or "RANDOM"
            if a.cfg.trainers=="TYPE_THEMED" or a.cfg.trainers=="THEMED" then
              local theme=a.trainerThemes[trainerKey]
              if not theme then
                local types=typePool(a.game)
                theme=Core.rng(Core.hash("trainer-theme|"..trainerKey,a.seed)):pick(types)
                a.trainerThemes[trainerKey]=theme
              end
              pick=selector(a.game,a.cfg,a.seed,"trainer|"..key,src,"RANDOM",
                function(id) return hasType(a.game,id,theme) end)
            else
              pick=randomSpecies(a,"trainer|"..key,src,mode)
            end
            a.trainerMap[key]=pick
          end
          if pick and not R.withinBst(a.game,a.cfg,src,pick) then
            pick=randomSpecies(a,"trainer-bst|"..key,src,"RANDOM")
            a.trainerMap[key]=pick
          end
          if pick then
            if type(s.species)=="number" then
              local d=a.game.data.pokemon[pick]; s.species=(d and d.index) or s.species
            else
              s.species=pick
            end
          end
          if type(s.level)=="number" then
            -- Normalize randomized or explicitly scaled teams into a tight
            -- band instead of preserving low filler slots or flattening every
            -- slot to one level.  The band ceiling is the trainer's highest
            -- native level, or a lower LOGIC-start progression cap when one is
            -- required for safety.  Slot deltas are deterministic (0..2).
            if useTrainerBand and trainerBaseMax>0 then
              local bandCeiling
              if R.pureProgressionEnabled(a) then
                bandCeiling=globalProgressionCeiling
              else
                bandCeiling=math.max(trainerBaseMax,globalProgressionCeiling)
              end
              if progressionMax then bandCeiling=math.min(bandCeiling,progressionMax) end
              s.level=math.max(1,math.min(100,math.floor(bandCeiling-trainerBandDelta(i)+0.5)))
            elseif progressionMax and progressionBaseMax>0 then
              s.level=math.max(1,math.min(100,
                math.floor((s.level*progressionMax/progressionBaseMax)+0.5)))
            end
            if partyLevelPct~=0 then
              s.level=math.max(1,math.min(100,math.floor(s.level*(100+partyLevelPct)/100+0.5)))
            end
          end
          -- 1.3.11 trainer HP normalization. A constructed Gen 2 trainer mon may
          -- reach this hook with current HP/max HP/stats for the PRE-randomized species
          -- or level. Clear those derived fields and deliberately leave HP unresolved
          -- until the host's authoritative post-hook Mon.refreshStats pass.
          --
          -- This is important when Kaizo Ultimate is stacked with the Randomizer:
          -- Kaizo's priority-1000 trainer.party wrapper runs OUTSIDE this wrapper and may
          -- apply its own final trainer/boss level after nextFn returns. Filling HP here
          -- (as 1.3.10 did) meant Kaizo could raise the level afterward, causing the host
          -- to increase max HP while preserving the now-lower current HP. Leaving hp=nil
          -- lets the host build BOTH values from the final species/level after every mod
          -- in the wrapper chain has finished. Raw Gen 1 trainer rows have none of these
          -- derived fields and continue through the normal Gen 1 Pokemon.new path.
          local constructedTrainerMon = s.hp~=nil or s.maxHp~=nil or s.stats~=nil or s.dvs~=nil
          if constructedTrainerMon then
            s.hp=nil
            s.maxHp=nil
            s.stats=nil
          end

          -- Keep DVs/items but rebuild the species identity and learned moves from the
          -- randomized target. The engine refreshes derived stats after this hook.
          if pick and s.dvs and type(s.species)=="string" then
            s.name=(a.game.data.pokemon[pick] and a.game.data.pokemon[pick].name) or pick
            s.nickname=nil
            local def=a.game.data.pokemon[pick]
            local rows=def and (def.levelMoves or def.learnset) or {}
            local learned={}
            if def and def.level1Moves then for _,m in ipairs(def.level1Moves) do learned[#learned+1]=m end end
            for _,row in ipairs(rows) do if (row.level or 1)<=s.level then learned[#learned+1]=row.move end end
            while #learned>4 do table.remove(learned,1) end
            s.moves={}
            for _,m in ipairs(learned) do local md=a.game.data.moves[m]; s.moves[#s.moves+1]={id=m,pp=md and md.pp or 0,maxPp=md and md.pp or 0} end
          end
        end
        out[#out+1]=s
      end
      return out
    end)

    mod.hooks:wrap("script.command", function(nextFn, ctx, name, args, cmd)
      local game=(ctx and ctx.game) or (Runtime.active and Runtime.active.game) or mod.game
      local a=activeFor(game)
      if not a then return nextFn(ctx,name,args,cmd) end
      local mapId=(ctx and ctx.overworld and ctx.overworld.map and ctx.overworld.map.id) or (ctx and ctx.mapId) or "?"
      local gen=generation(a.game)

      -- Gen 2 randomized badge rewards live in the ENGINE_* badge flag namespace.
      -- Rewrite only badge setflag commands; event flags that mark a Gym beaten
      -- remain vanilla so story/NPC state cannot desync from the shuffled reward.
      if gen==2 and name=="setflag" and cmd and a.badgePlan and a.badgePlan.mode~="VANILLA" then
        local flag=cmd.flag or (type(cmd.args)=="table" and cmd.args[1]) or (args and args[1])
        local target=a.badgePlan.flagMap and a.badgePlan.flagMap[tonumber(flag)]
        if target then
          local c=Core.copy(cmd); c.flag=target
          if type(c.args)=="table" and #c.args>0 then c.args=Core.copy(c.args); c.args[1]=target end
          a.lastBadgeAward={source=tonumber(flag),target=target}
          return nextFn(ctx,name,args,c)
        end
      end
      if gen==2 and name=="writetext" and cmd and a.badgePlan and a.badgePlan.mode~="VANILLA" then
        local source=G2_GYM_MAP_SOURCE[tostring(mapId)]
        local target=source and a.badgePlan.gymToBadge and a.badgePlan.gymToBadge[source]
        local body=ctx and ctx.vm and ctx.vm.text and ctx.vm.text[cmd.text]
        if source and target and source~=target and type(body)=="string" then
          local srcName=badgeDisplay(source); local dstName=badgeDisplay(target)
          local changed=body
          changed=changed:gsub(srcName,dstName)
          changed=changed:gsub(srcName:upper(),dstName:upper())
          changed=changed:gsub(source.."BADGE",target.."BADGE")
          changed=changed:gsub(source.." BADGE",target.." BADGE")
          if changed~=body then
            local key="__universal_randomizer_badge_"..tostring(mapId).."_"..tostring(cmd.text).."_"..target
            ctx.vm.text[key]=changed
            local c=Core.copy(cmd); c.text=key
            return nextFn(ctx,name,args,c)
          end
        end
      end


      -- Ordinary Gen 2 NPC-gift TMs and key items are randomized as a stable
      -- one-for-one permutation of map-owned literal gift commands. The
      -- restrictive progression rewards are excluded from this layer and are
      -- handled by logicItemPlan below.
      if gen==2 and cmd and a.giftItemTargetsByCmd then
        local target=a.giftItemTargetsByCmd[cmd]
        if target then
          local td=a.game.data.items and a.game.data.items[target]
          if td and td.index then
            local c=Core.copy(cmd); c.item=td.index
            if type(c.args)=="table" and #c.args>0 then
              c.args=Core.copy(c.args); c.args[1]=td.index
            end
            return nextFn(ctx,name,args,c)
          end
        end
      end

      -- Starter presentation must describe the SAME Pokemon that will be
      -- awarded. UPR-ZX patches multiple ROM references for each starter; at
      -- runtime we synchronize those semantic seams instead of only replacing
      -- the final give command.
      if gen==1 and mapId=="OAKS_LAB" and name=="push_screen" and args
          and args[1]=="DexEntryMenu" and type(args[2])=="table" then
        local src,pick=starterTarget(a,args[2].species)
        if pick then
          local na=Core.copy(args); na[2]=Core.copy(args[2]); na[2].species=pick
          return nextFn(ctx,name,na)
        end
      elseif gen==1 and mapId=="OAKS_LAB" and name=="ask" and args then
        local src=G1_STARTER_ASK_SOURCE[args[1]]
        local targetName=src and starterDisplayName(a,src)
        if targetName then
          local na=Core.copy(args); na[1]="So! You want\n"..targetName.."?"
          return nextFn(ctx,name,na)
        end
      elseif gen==1 and mapId=="OAKS_LAB" and name=="show_text" and args
          and type(args[2])=="table" and args[2].RAM~=nil then
        local _,pick=starterTarget(a,args[2].RAM)
        if pick then
          local na=Core.copy(args); na[2]=Core.copy(args[2]); na[2].RAM=pick
          return nextFn(ctx,name,na)
        end
      elseif gen==2 and cmd then
        local rawSpecies=cmd.species or cmd.id or (type(cmd.args)=="table" and cmd.args[1]) or (args and args[1])
        local direct=Core.resolveIndexedId(a.game.data.pokemon,rawSpecies) or rawSpecies
        local scriptStarter=(type(direct)=="string" and a.starterMap[direct] and direct) or g2StarterSourceForScript(a,ctx)
        if scriptStarter then
          local pick=a.starterMap[scriptStarter]
          if pick then
            -- Text is data-only and must not be gated on a native cart index.
            -- That old gate is exactly why a Gen 3/4 target left CHIKORITA /
            -- TOTODILE / CYNDAQUIL visible even though starterMap was random.
            if name=="writetext" then
              local prefix=G2_STARTER_PROMPT[scriptStarter]
              local targetName=tostring((a.game.data.pokemon[pick] and a.game.data.pokemon[pick].name) or pick)
              local body=ctx.vm and ctx.vm.text and ctx.vm.text[cmd.text]
              if prefix and type(body)=="string" then
                local sourceName=tostring((a.game.data.pokemon[scriptStarter] and a.game.data.pokemon[scriptStarter].name) or scriptStarter)
                if body:upper():find(sourceName:upper(),1,true) then
                  local key="__universal_randomizer_starter_"..scriptStarter
                  ctx.vm.text[key]=prefix..targetName.."?"
                  local c=Core.copy(cmd); c.text=key
                  return nextFn(ctx,name,args,c)
                end
              end
            elseif name=="pokepic" or name=="cry" or name=="getmonname" or name=="givepoke" then
              return withGen2StarterIndex(a,scriptStarter,pick,function(idx)
                if not idx then return nextFn(ctx,name,args,cmd) end
                if name=="pokepic" then
                  local c=Core.copy(cmd); c.species=idx
                  if type(c.args)=="table" and #c.args>0 then c.args=Core.copy(c.args); c.args[1]=idx end

                  return nextFn(ctx,name,args,c)
                elseif name=="cry" then
                  local c=Core.copy(cmd); c.id=idx
                  return nextFn(ctx,name,args,c)
                elseif name=="getmonname" then
                  local c=Core.copy(cmd); c.species=idx
                  return nextFn(ctx,name,args,c)
                elseif name=="givepoke" then
                  local c=Core.copy(cmd); c.species=idx
                  if a.cfg.random_start~="OFF" then
                    a.randomStartArmed=true
                    mod.save:set("random_start_armed",true)
                  end
                  return nextFn(ctx,name,args,c)
                end
              end)
            end
          end
        end
      end

      if gen==1 and name=="play_cry" and args and args[1] and a.cfg.statics~="UNCHANGED" then
        local src=Core.resolveIndexedId(a.game.data.pokemon,args[1]) or args[1]
        local byMap=G1_GIFT_CRY_LEVELS[mapId]
        local giftLevel=type(src)=="string" and byMap and byMap[src]
        if giftLevel then
          local pick=giftPick(a,mapId,src,giftLevel)
          local na=Core.copy(args); na[1]=pick
          return nextFn(ctx,name,na)
        end
      end

      -- Gen 1 legendary/static scripts likewise carry a separate play_cry
      -- row before static_battle. Keep that cry on the same per-object mapping
      -- as the map object's species and the battle itself.
      if gen==1 and name=="play_cry" and args and args[1] and a.cfg.statics~="UNCHANGED" then
        local src=Core.resolveIndexedId(a.game.data.pokemon,args[1]) or args[1]
        local level=type(src)=="string" and g1ScriptStaticLevel(a,ctx,src) or nil
        if level then
          local pick=g1StaticPick(a,ctx,mapId,src,level)
          local na=Core.copy(args); na[1]=pick
          return nextFn(ctx,name,na)
        end
      end

      -- Gen 2 static encounters commonly play the source species' cry before
      -- loadwildmon. UPR-ZX patches both bytes. Detect a paired loadwildmon in
      -- this exact cart script and use one per-script deterministic mapping,
      -- so the three Radio Tower Electrode-style instances can randomize
      -- independently while their cries still match their battles.
      if gen==2 and name=="cry" and cmd and a.cfg.statics~="UNCHANGED" then
        local src=Core.resolveIndexedId(a.game.data.pokemon,cmd.id) or cmd.id
        if type(src)=="string" and a.game.data.pokemon[src]
            and g2ScriptHasStatic(a,ctx and ctx.vm,ctx and ctx.scriptKey,src) then
          local pick=g2StaticPick(a,ctx,mapId,src)
          local idx=pokemonIndex(a.game,pick)
          if idx then local c=Core.copy(cmd); c.id=idx; return nextFn(ctx,name,args,c) end
        end
      end

      if name=="loadmenu" and cmd then
        local c=rewritePrizeMenu(a,mapId,cmd)
        if c then return nextFn(ctx,name,args,c) end
      elseif name=="getmonname" and cmd and G2_PRIZE_LEVELS[mapId] then
        local src=Core.resolveIndexedId(a.game.data.pokemon,cmd.species or (args and args[1]))
        if src and G2_PRIZE_LEVELS[mapId][src] then
          local pick=g2PrizePick(a,mapId,src)
          if pick then
            local c=Core.copy(cmd); local d=a.game.data.pokemon[pick]; c.species=(d and d.index) or c.species
            return nextFn(ctx,name,args,c)
          end
        end
      elseif name=="static_battle" and args and args[1]
          and R.staticLevelScalingActive(a) then
        local src=Core.resolveIndexedId(a.game.data.pokemon,args[1]) or args[1]
        local pick=src
        if a.cfg.statics~="UNCHANGED" then pick=g1StaticPick(a,ctx,mapId,src,args[2]) end
        local na=Core.copy(args)
        na[1]=pick
        if type(na[2])=="number" then na[2]=scaleStaticEnemyLevel(a,na[2],mapId,g1StaticKey(ctx,mapId,src,na[2])) end
        return nextFn(ctx,name,na,cmd)
      elseif name=="givepoke" and cmd then
        local src=Core.resolveIndexedId(a.game.data.pokemon,cmd.species or (args and args[1]))
        if src then
          local pick=a.starterMap[src]
          if not pick and a.cfg.statics~="UNCHANGED" then
            local key="g2gift|"..mapId.."|"..src.."|"..tostring(cmd.level)
            pick=a.giftMap[key] or randomSpecies(a,key,src,a.cfg.statics=="SIMILAR" and "SIMILAR" or "RANDOM")
            a.giftMap[key]=pick
          end
          if pick or (R.pureProgressionEnabled(a) and not a.starterMap[src]) then
            local c=Core.copy(cmd)
            if pick then local d=a.game.data.pokemon[pick]; c.species=(d and d.index) or c.species end
            if not a.starterMap[src] and type(c.level)=="number" then c.level=scaleGiftLevel(a,c.level) end
            return nextFn(ctx,name,args,c)
          end
        end
      elseif name=="giveegg" and cmd and a.cfg.statics~="UNCHANGED" then
        local src=Core.resolveIndexedId(a.game.data.pokemon,cmd.species or (args and args[1]))
        if src then
          local key="g2egg|"..mapId.."|"..src.."|"..tostring(cmd.level)
          local pick=a.giftMap[key] or randomSpecies(a,key,src,a.cfg.statics=="SIMILAR" and "SIMILAR" or "RANDOM")
          a.giftMap[key]=pick
          local c=Core.copy(cmd); local d=a.game.data.pokemon[pick]; c.species=(d and d.index) or c.species
          return nextFn(ctx,name,args,c)
        end
      elseif name=="loadwildmon" and cmd
          and R.staticLevelScalingActive(a) then
        local src=Core.resolveIndexedId(a.game.data.pokemon,cmd.species or (args and args[1]))
        if src then
          local pick=src
          if a.cfg.statics~="UNCHANGED" then pick=g2StaticPick(a,ctx,mapId,src) end
          local c=Core.copy(cmd); local d=a.game.data.pokemon[pick]; c.species=(d and d.index) or c.species
          if type(c.level)=="number" then c.level=scaleStaticEnemyLevel(a,c.level,mapId,g2StaticIdentity(ctx,mapId,src)) end
          return nextFn(ctx,name,args,c)
        end
      elseif name=="special" and cmd and ctx and ctx.vm then
        local vm=ctx.vm
        local specialName=(type(vm.specialName)=="function") and vm:specialName(cmd.id) or nil
        if specialName=="GiveShuckle" and cianwoodLogicStartActive(a) then
          local save=a.game and a.game.save
          local before=save and save.party and #save.party or 0
          local result=nextFn(ctx,name,args,cmd)
          local party=save and save.party
          if type(party)=="table" and #party>before then
            local old=party[#party]
            local pick=cianwoodFlyGiftPick(a)
            local okMon,Mon=pcall(require,"src.battle.gen2.Mon")
            if pick and okMon and Mon and type(Mon.new)=="function" then
              local level=cianwoodFlyGiftLevel(a,before)
              local fresh=Mon.new(a.game.data,pick,level,{
                dvs=old and old.dvs or nil,
                item=old and old.item or "BERRY",
                happiness=old and old.happiness or 70,
              })
              if fresh then
                fresh.ot=old and old.ot or fresh.ot
                fresh.otName=old and old.otName or fresh.otName
                fresh.otId=old and old.otId or fresh.otId
                fresh.nickname=nil
                -- Do NOT teach Fly here.  HM02 is the native post-Chuck reward
                -- and must be obtained/used through ordinary field-move rules.
                party[#party]=fresh
              end
            end
          end
          return result
        elseif a.cfg.statics~="UNCHANGED" and specialName=="InitRoamMons" then
          local result=nextFn(ctx,name,args,cmd)
          local hooks=vm.specials
          local save=hooks and hooks.save and hooks.save() or nil
          if save and type(save.roamers)=="table" then
            for i,row in ipairs(save.roamers) do
              local src=Core.resolveIndexedId(a.game.data.pokemon,row.species) or row.species
              if type(src)=="string" and a.game.data.pokemon[src] then
                local key="g2roamer|"..i.."|"..src
                local pick=a.roamerMap[key] or randomSpecies(a,key,src,a.cfg.statics=="SIMILAR" and "SIMILAR" or "RANDOM")
                a.roamerMap[key]=pick
                if pick then row.species=pick end
                if type(row.level)=="number" then row.level=scaleStaticEnemyLevel(a,row.level,"ROAMER",key) end
              end
            end
          end
          return result
        end
      end
      return nextFn(ctx,name,args,cmd)
    end)
  end

  Runtime.runCodeKeys={"ruleset","pokedex","safety","starters","movesets","trainers","area_encounters","wild_randomness","wild_evolution","extra_species","random_start","badges","field_items","marts","mart_safety","protection_guards","tms","tm_compat","evolutions","types","base_stats","statics","trades","level_mode","trainer_levels","boss_levels","wild_levels","trainer_ai","boss_ai","bst_match","bst_difference","gift_items","progression_items"}
  function R.runCode(active)
    active=active or Runtime.active
    if not active then return nil end
    local parts={"UR14",tostring(active.seed)}
    for _,k in ipairs(Runtime.runCodeKeys) do parts[#parts+1]=tostring(active.cfg[k]) end
    return table.concat(parts,".")
  end

  function R._prettyWorldName(id)
    local t=tostring(id or "?"):gsub("#%d+$",""):gsub("_"," "):lower()
    t=t:gsub("(%a)([%w']*)",function(a,b) return a:upper()..b end)
    t=t:gsub("S S ","S.S. "):gsub("Tm ","TM "):gsub("Hm ","HM ")
    return t
  end

  function R._inventoryHas(game,id)
    local inv=game and game.save and game.save.inventory or {}
    if inv[id] and tonumber(inv[id])~=0 then return true end
    -- Some host/test fixtures use item rows rather than a flat keyed bag.
    for k,v in pairs(inv or {}) do
      if type(v)=="table" then
        local rid=v.id or v.item or k
        local count=v.count or v.qty or v.quantity or 1
        if tostring(rid)==tostring(id) and tonumber(count or 0)>0 then return true end
      end
    end
    return false
  end

  function R._partyKnows(game,move)
    move=tostring(move or ""):upper()
    for _,mon in ipairs((game and game.save and game.save.party) or {}) do
      for _,m in ipairs(mon.moves or {}) do
        local id=type(m)=="table" and (m.id or m.move) or m
        if tostring(id or ""):upper()==move then return true end
      end
    end
    return false
  end

  function R._badgeOwned(active,badge)
    if not active or not active.game or not badge then return false end
    if active.generation==1 then
      return R._inventoryHas(active.game,badge)
    end
    local badges=active.game.save and active.game.save.player and active.game.save.player.badges or {}
    if badges[badge] then return true end
    for i,name in ipairs(G2_BADGES) do if name==badge and badges[i] then return true end end
    return false
  end

  function R._badgeSourceLabel(active,target)
    if not active or not active.badgePlan then return nil end
    local source
    for s,b in pairs(active.badgePlan.gymToBadge or {}) do if tostring(b)==tostring(target) then source=s; break end end
    if not source then return nil end
    if active.generation==1 then
      local labels={
        ["OPP_BROCK#1"]="PEWTER GYM",["OPP_MISTY#1"]="CERULEAN GYM",["OPP_LT_SURGE#1"]="VERMILION GYM",
        ["OPP_ERIKA#1"]="CELADON GYM",["OPP_KOGA#1"]="FUCHSIA GYM",["OPP_SABRINA#1"]="SAFFRON GYM",
        ["OPP_BLAINE#1"]="CINNABAR GYM",["OPP_GIOVANNI#3"]="VIRIDIAN GYM",
      }
      return labels[source] or R._prettyWorldName(source)
    end
    local labels={
      ZEPHYR="VIOLET GYM",HIVE="AZALEA GYM",PLAIN="GOLDENROD GYM",FOG="ECRUTEAK GYM",
      MINERAL="OLIVINE GYM",STORM="CIANWOOD GYM",GLACIER="MAHOGANY GYM",RISING="BLACKTHORN GYM",
    }
    return labels[source] or R._prettyWorldName(source)
  end

  function R.logicCheck(game,activeOverride)
    local a=activeOverride or Runtime.active
    game=game or (a and a.game)
    if not a or not game then return {ok=false,message="No randomized seed is active."} end
    local out={ok=true,message="World logic is internally consistent.",warnings={}}
    if a.cfg.badges=="SAFE" then
      local start=a.progression and a.progression.start or nil
      local ok,why=R._validateSafeBadgeAssignment(a.generation,a.badgePlan,start)
      if not ok then out.ok=false; out.message=why; return out end
    end
    if a.cfg.field_items=="LOGIC_RANDOM" or a.cfg.field_items=="CHAOS" then
      local ok,why=R._validateLogicItemPlan(game,a.cfg)
      if not ok then out.ok=false; out.message=why; return out end
    end
    if a.generation==2 and a.cfg.field_items~="UNCHANGED" then
      local ok,why=R._validateNpcGiftItemPlan(game,a.cfg,a.giftItemPlan)
      if not ok then out.ok=false; out.message=why; return out end
    end

    -- A player-facing blocker check complements the seed proof. It explains
    -- the common "I have the HM but cannot use it" situation by naming the
    -- shuffled badge source instead of merely saying the move is unavailable.
    local badgeMap=(a.generation==1) and HM_BADGE_G1 or HM_BADGE_G2
    for move,badge in pairs(badgeMap) do
      local hm=hmItemForMove(game,move)
      if hm and R._inventoryHas(game,hm) and not R._badgeOwned(a,badge) then
        out.blocker={
          kind="BADGE",move=move,badge=badge,source=R._badgeSourceLabel(a,badge),
          text=("You own %s, but %s is required to use %s. Get it from %s."):format(
            R._prettyWorldName(hm),badgeDisplay(badge),move,R._badgeSourceLabel(a,badge) or "its shuffled gym")
        }
        out.message=out.blocker.text
        break
      end
    end

    local plan=a.logicItemPlan
    if plan and type(plan.sequence)=="table" then
      local byKey={}
      for _,d in ipairs(plan.defs or {}) do byKey[d.key]=d end
      local state={}
      for _,id in ipairs(plan.progressionItems or {}) do if R._inventoryHas(game,id) then state[id]=true end end
      for _,step in ipairs(plan.sequence) do
        local d=byKey[step.key]
        if d and not R._inventoryHas(game,step.item) and R._logicItemReqMet(d,state,plan.start,a.generation) then
          out.next={
            kind="ITEM",item=step.item,key=step.key,map=d.map,region=d.region,
            text=("Next reachable progression check: %s at %s."):format(
              R._prettyWorldName(step.item),R._prettyWorldName(d.map))
          }
          break
        end
      end
      -- ROCK SMASH is a TM in Gen 2, but it is progression-critical in the
      -- Burned Tower route. Call it out explicitly if the restrictive plan has
      -- not yet delivered it.
      if a.generation==2 and game.data.items and game.data.items.TM_ROCK_SMASH
          and not R._inventoryHas(game,"TM_ROCK_SMASH") then
        for _,step in ipairs(plan.sequence) do
          if step.item=="TM_ROCK_SMASH" then
            local d=byKey[step.key]
            out.warnings[#out.warnings+1]=("ROCK SMASH is required before Burned Tower progression; its seeded check is %s."):format(
              R._prettyWorldName(d and d.map or step.map))
            break
          end
        end
      end
    end
    return out
  end

  function R.spoilerData(game,activeOverride)
    local a=activeOverride or Runtime.active
    game=game or (a and a.game)
    if not a or not game then return nil,"No randomized seed is active." end
    local data={
      seed=a.seed,fingerprint=a.fingerprint,version=a.version,generation=a.generation,
      config=Core.copy(a.cfg),logic=R.logicCheck(game,a),badges={},progression={},useful={},npcGifts={},doors={},start=nil,
    }
    if a.progression and a.progression.start then
      data.start=Core.copy(a.progression.start)
      local proof=Logic and Logic.proof and Logic.proof(a.generation,a.progression.start.id) or nil
      data.startProof=proof
    end
    local sources=(a.generation==1) and G1_GYM_ORDER or G2_BADGES
    for _,source in ipairs(sources) do
      local target=a.badgePlan and a.badgePlan.gymToBadge and a.badgePlan.gymToBadge[source]
      if target then
        data.badges[#data.badges+1]={
          source=source,target=target,sourceLabel=R._badgeSourceLabel(a,target),owned=R._badgeOwned(a,target)
        }
      end
    end
    local plan=a.logicItemPlan
    if plan then
      local byKey={}
      for _,d in ipairs(plan.defs or {}) do byKey[d.key]=d end
      for _,step in ipairs(plan.sequence or {}) do
        local d=byKey[step.key]
        data.progression[#data.progression+1]={
          item=step.item,key=step.key,map=(d and d.map) or step.map,region=d and d.region,
          owned=R._inventoryHas(game,step.item),pinned=not not step.pinned,
        }
      end
      for _,step in ipairs(plan.usefulSequence or {}) do
        local d=byKey[step.key]
        data.useful[#data.useful+1]={
          item=step.item,key=step.key,map=(d and d.map) or step.map,region=d and d.region,
          owned=R._inventoryHas(game,step.item),
        }
      end
    end
    for _,row in ipairs((a.giftItemPlan and a.giftItemPlan.slots) or {}) do
      data.npcGifts[#data.npcGifts+1]={
        key=row.key,map=row.map,source=row.source,target=row.target,category=row.category,
      }
    end
    table.sort(data.npcGifts,function(x,y) return tostring(x.key)<tostring(y.key) end)
    for _,pair in ipairs((a.doorPlan and a.doorPlan.pairs) or {}) do data.doors[#data.doors+1]=Core.copy(pair) end
    return data
  end

  function R.spoilerText(game)
    local d,why=R.spoilerData(game)
    if not d then return nil,why end
    local lines={
      "UNIVERSAL RANDOMIZER 2.0 SPOILER / LOGIC CHECK",
      "SEED: "..tostring(d.seed),
      "FP: "..tostring(d.fingerprint),
      "GAME: "..tostring(d.version):upper(),
      "LOGIC: "..(d.logic.ok and "PASS" or "FAIL").." - "..tostring(d.logic.message),
    }
    if d.logic.next then lines[#lines+1]="NEXT: "..d.logic.next.text end
    for _,w in ipairs(d.logic.warnings or {}) do lines[#lines+1]="NOTE: "..w end
    if d.start then
      lines[#lines+1]=""
      lines[#lines+1]="RANDOM START: "..R._prettyWorldName(d.start.id)
      for i,step in ipairs((d.startProof and d.startProof.steps) or {}) do lines[#lines+1]=("  %d. %s"):format(i,step) end
    end
    if #d.badges>0 then
      lines[#lines+1]=""
      lines[#lines+1]="BADGES"
      for _,row in ipairs(d.badges) do
        lines[#lines+1]=("%s -> %s%s"):format(
          row.sourceLabel or R._prettyWorldName(row.source),badgeDisplay(row.target),row.owned and " [OWNED]" or "")
      end
    end
    if #d.progression>0 then
      lines[#lines+1]=""
      lines[#lines+1]="PROGRESSION ITEMS"
      for i,row in ipairs(d.progression) do
        lines[#lines+1]=("%02d %s @ %s%s"):format(
          i,R._prettyWorldName(row.item),R._prettyWorldName(row.map),row.owned and " [OWNED]" or "")
      end
    end
    if #d.useful>0 then
      lines[#lines+1]=""
      lines[#lines+1]="USEFUL LOGIC ITEMS"
      for _,row in ipairs(d.useful) do
        lines[#lines+1]=("%s @ %s%s"):format(
          R._prettyWorldName(row.item),R._prettyWorldName(row.map),row.owned and " [OWNED]" or "")
      end
    end
    if #d.npcGifts>0 then
      lines[#lines+1]=""
      lines[#lines+1]="NPC GIFT ITEMS"
      for _,row in ipairs(d.npcGifts) do
        lines[#lines+1]=("%s: %s -> %s"):format(
          R._prettyWorldName(row.map),R._prettyWorldName(row.source),R._prettyWorldName(row.target))
      end
    end
    if #d.doors>0 then
      lines[#lines+1]=""
      lines[#lines+1]="RANDOM DOORS"
      for _,pair in ipairs(d.doors) do
        local a=pair.a or pair[1] or pair.from
        local b=pair.b or pair[2] or pair.to
        lines[#lines+1]=R._prettyWorldName(a and (a.map or a.id) or "?").." <-> "..R._prettyWorldName(b and (b.map or b.id) or "?")
      end
    end
    return table.concat(lines,"\n")
  end

  function R.summary(active)
    if not active then return "VANILLA" end
    return ("%s %s %s"):format(active.version:upper(),active.seed,active.fingerprint)
  end

  return R
end
