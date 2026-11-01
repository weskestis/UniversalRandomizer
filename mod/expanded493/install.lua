-- Universal Randomizer Gen 1-4 expanded content layer.
-- Data/art: generated from the user-supplied pokeplatinum source tree.
-- Host-native species are never overwritten here; this layer only registers
-- species missing from the active Red/Blue/Yellow/Gold data set.
local M = {}

local function loadData(mod, path)
  local src = assert(mod:read(path), "missing " .. path)
  local chunk, err = (loadstring or load)(src, "@" .. path)
  assert(chunk, err)
  return assert(chunk())
end

local function norm(s)
  return tostring(s or ""):upper():gsub("[^A-Z0-9]", "")
end

local TYPE_ALIAS = { PSYCHIC = "PSYCHIC_TYPE" }
local function typeId(x) return TYPE_ALIAS[x] or x end

local function exactErratic(n)
  n=math.floor(tonumber(n) or 1); local n3=n*n*n
  if n<=50 then return math.floor(((100-n)*n3)/50) end
  if n<=68 then return math.floor(((150-n)*n3)/100) end
  if n<=98 then return math.floor((math.floor((1911-10*n)/3)*n3)/500) end
  return math.floor(((160-n)*n3)/100)
end
local function exactFluctuating(n)
  n=math.floor(tonumber(n) or 1); local n3=n*n*n
  if n<=15 then return math.floor((math.floor((n+1)/3)+24)*n3/50) end
  if n<=36 then return math.floor((n+14)*n3/50) end
  return math.floor((math.floor(n/2)+32)*n3/50)
end

local GROWTH = {
  MEDIUM_FAST="MEDIUM_FAST", ERRATIC="ERRATIC", FLUCTUATING="FLUCTUATING",
  MEDIUM_SLOW="MEDIUM_SLOW", FAST="FAST", SLOW="SLOW",
}

-- Gold's extracted BaseData names its four cartridge growth curves with the
-- GROWTH_ prefix (GROWTH_MEDIUM_SLOW, etc.), while the expanded Platinum
-- source uses the later-generation names without it.  Erratic/Fluctuating
-- do not exist on the Gen 2 cartridge, so those remain mod-registered custom
-- curve ids.  Keeping this branch here prevents Gen 2 Mon.growthFor from
-- falling through to its cubic default for later species.
local function growthId(name, gen)
  name = GROWTH[name] or "MEDIUM_FAST"
  if gen == 2 and name ~= "ERRATIC" and name ~= "FLUCTUATING" then
    return "GROWTH_" .. name
  end
  return name
end

-- Gen IV Steel/Dark interactions. Existing host rows always win, so R/B/Y
-- keep their native Gen 1 quirks while the two added types have defined
-- interactions. Gold already owns these rows and is left untouched.
local EXTRA_MATCHUPS = {
  ["NORMAL>STEEL"]=5,
  ["FIRE>STEEL"]=20,["WATER>STEEL"]=10,["ELECTRIC>STEEL"]=10,["GRASS>STEEL"]=5,["ICE>STEEL"]=5,
  ["FIGHTING>STEEL"]=20,["POISON>STEEL"]=0,["GROUND>STEEL"]=20,["FLYING>STEEL"]=5,
  ["PSYCHIC>STEEL"]=5,["BUG>STEEL"]=5,["ROCK>STEEL"]=5,["GHOST>STEEL"]=5,["DRAGON>STEEL"]=5,
  ["DARK>STEEL"]=5,["STEEL>STEEL"]=5,
  ["FIGHTING>DARK"]=20,["PSYCHIC>DARK"]=0,["BUG>DARK"]=20,["GHOST>DARK"]=5,["DARK>DARK"]=5,
  ["DARK>PSYCHIC"]=20,["DARK>GHOST"]=20,["DARK>FIGHTING"]=5,
  ["STEEL>FIRE"]=5,["STEEL>WATER"]=5,["STEEL>ELECTRIC"]=5,["STEEL>ICE"]=20,["STEEL>ROCK"]=20,
}

local function currentGeneration()
  local ok,GV=pcall(require,"src.core.GameVersion")
  if ok and GV then
    if GV.generation and GV.get then return GV.generation(GV.get()) end
  end
  return 1
end

local function currentNativeMax()
  return currentGeneration()==2 and 251 or 151
end

local function resolveRegistryByNorm(registry)
  local by={}
  if registry and registry.each then
    for id,rec in registry:each() do
      by[norm(id)]=id
      if type(rec)=="table" and rec.name then by[norm(rec.name)]=id end
    end
  end
  return by
end

local function stableLevelRows(rows)
  local keyed={}
  local sorted=true
  local previous=-math.huge
  for i,row in ipairs(rows or {}) do
    local level=tonumber(row and row.level) or math.huge
    if level<previous then sorted=false end
    previous=level
    keyed[#keyed+1]={row=row,index=i,level=level}
  end
  if sorted then return rows or {} end
  table.sort(keyed,function(a,b)
    if a.level==b.level then return a.index<b.index end
    return a.level<b.level
  end)
  local out={}
  for _,entry in ipairs(keyed) do out[#out+1]=entry.row end
  return out
end

local function resolveDataByNorm(rows)
  local by={}
  for id,rec in pairs(rows or {}) do
    by[norm(id)]=id
    if type(rec)=="table" and rec.name then by[norm(rec.name)]=id end
  end
  return by
end

local function registerGrowth(mod)
  local Growth=require("src.pokemon.Growth")
  Growth.CURVES.ERRATIC=exactErratic
  Growth.CURVES.FLUCTUATING=exactFluctuating
  local reg=mod.content.growth_rates
  if reg then
    if reg:get("ERRATIC") then reg:patch("ERRATIC",{expForLevel=exactErratic}) else reg:register("ERRATIC",{expForLevel=exactErratic}) end
    if reg:get("FLUCTUATING") then reg:patch("FLUCTUATING",{expForLevel=exactFluctuating}) else reg:register("FLUCTUATING",{expForLevel=exactFluctuating}) end
  end
end

local function registerTypes(mod)
  local chart=mod.content.type_chart
  if not chart then return end
  if not chart:get("STEEL") then chart:register("STEEL",{name="Steel",category="physical"}) end
  if not chart:get("DARK") then chart:register("DARK",{name="Dark",category="special"}) end
  if not chart:get("MYSTERY") then chart:register("MYSTERY",{name="???",category="special"}) end
  for key,mult in pairs(EXTRA_MATCHUPS) do
    local a,b=key:match("^([^>]+)>(.+)$")
    local id=typeId(a)..">"..typeId(b)
    if chart:get(id)==nil then chart:register(id,{multiplier=mult}) end
  end
end

local function buildMoveResolver(mod,src,fallback)
  local moves=assert(mod.content.moves,"moves registry unavailable")
  local effects=mod.content.move_effects
  local existing=resolveRegistryByNorm(moves)
  local fb={}
  for _,m in ipairs(fallback.moves or {}) do fb[norm(m.id)]=m; fb[norm(m.name)]=m end
  local byEnum={}
  local function safeEffect(f, sourceEffect)
    if sourceEffect and effects and effects:get(sourceEffect) then return sourceEffect end
    local e=f and f.effect or "NO_ADDITIONAL_EFFECT"
    return (effects and effects:get(e)) and e or "NO_ADDITIONAL_EFFECT"
  end
  for _,sm in ipairs(src.moves or {}) do
    local key=norm(sm.enum)
    local f=fb[key] or fb[norm(sm.name)]
    local id=existing[key] or existing[norm(sm.name)]
    if not id and f then id=existing[norm(f.id)] or existing[norm(f.name)] end
    if not id then id=(f and f.id) or key end
    byEnum[sm.enum]=id
    if not moves:get(id) then
      local rec={id=id,name=sm.name,type=typeId(sm.type),power=sm.power,accuracy=sm.accuracy,pp=sm.pp,
        category=sm.category,effect=safeEffect(f,sm.effect)}
      if sm.priority and sm.priority~=0 then rec.priority=sm.priority end
      local eff=tostring(sm.effect or "")
      if eff:find("HIGH_CRIT") or eff=="BATTLE_EFFECT_HIGH_CRITICAL" then rec.highCrit=true end
      if eff=="BATTLE_EFFECT_HIT_TWICE" then rec.multiHit=2
      elseif eff=="BATTLE_EFFECT_HIT_THREE_TIMES" then rec.multiHit=3
      elseif eff=="BATTLE_EFFECT_MULTI_HIT" or eff=="BATTLE_EFFECT_POISON_MULTI_HIT" then rec.multiHit={2,2,2,3,3,3,4,5} end
      if eff=="BATTLE_EFFECT_20_DAMAGE_FLAT" then rec.fixedDamage=20
      elseif eff=="BATTLE_EFFECT_40_DAMAGE_FLAT" then rec.fixedDamage=40
      elseif eff=="BATTLE_EFFECT_LEVEL_DAMAGE_FLAT" then rec.fixedDamage=function(ctx) return (ctx.user and (ctx.user.level or (ctx.user.mon and ctx.user.mon.level))) or 1 end end
      if f then
        for _,k in ipairs({"highCrit","fixedDamage","chargeText","semiInvulnerable","multiHit","counterable"}) do
          if f[k]~=nil then rec[k]=f[k] end
        end
      end
      moves:register(id,rec)
      existing[norm(id)]=id; existing[norm(sm.name)]=id
    end
  end
  return byEnum
end

local function registerSpecialEvolutionInfrastructure(mod, gen)
  local reg=mod.content.evolution_methods
  if not reg then return end
  local function add(id,check,desc)
    if reg:get(id)==nil then reg:register(id,{check=check,describe=function() return desc or "Special condition" end}) end
  end
  local function daypart()
    local game=mod.game
    local tod=game and game.save and (game.save.timeOfDay or game.save.time) or nil
    if tod=="NITE" or tod=="NITE_F" then return "NIGHT" end
    if tod=="MORN" or tod=="DAY" then return "DAY" end
    local h=tonumber(os.date("%H")) or 12
    return (h>=20 or h<4) and "NIGHT" or "DAY"
  end
  local function friendship(mon) return tonumber(mon and (mon.happiness or mon.ukFriendship)) or 0 end
  local function gender(mon)
    if mon and mon.ukGender then return mon.ukGender end
    local atk=(mon and mon.dvs and (mon.dvs.attack or mon.dvs.atk)) or 8
    return (tonumber(atk) or 8)>=8 and "male" or "female"
  end
  if gen==1 then
    add("U493_HAPPY",function(_,mon,_,tr) return tr.kind=="levelup" and friendship(mon)>=220 end,"High friendship")
    add("U493_HAPPY_DAY",function(_,mon,_,tr) return tr.kind=="levelup" and friendship(mon)>=220 and daypart()=="DAY" end,"High friendship (day)")
    add("U493_HAPPY_NIGHT",function(_,mon,_,tr) return tr.kind=="levelup" and friendship(mon)>=220 and daypart()=="NIGHT" end,"High friendship (night)")
    add("U493_STAT_GT",function(_,mon,e,tr) return tr.kind=="levelup" and mon.level>=(e.level or 1) and (mon.stats.attack or 0)>(mon.stats.defense or 0) end,"Level + ATK > DEF")
    add("U493_STAT_LT",function(_,mon,e,tr) return tr.kind=="levelup" and mon.level>=(e.level or 1) and (mon.stats.attack or 0)<(mon.stats.defense or 0) end,"Level + ATK < DEF")
    add("U493_STAT_EQ",function(_,mon,e,tr) return tr.kind=="levelup" and mon.level>=(e.level or 1) and (mon.stats.attack or 0)==(mon.stats.defense or 0) end,"Level + ATK = DEF")
    add("U493_LEVEL_MALE",function(_,mon,e,tr) return tr.kind=="levelup" and mon.level>=(e.level or 1) and gender(mon)=="male" end,"Level (male)")
    add("U493_LEVEL_FEMALE",function(_,mon,e,tr) return tr.kind=="levelup" and mon.level>=(e.level or 1) and gender(mon)=="female" end,"Level (female)")
  end
end

local function genderRatioByte(s)
  local m={
    GENDER_RATIO_MALE_ONLY=0,GENDER_RATIO_FEMALE_12_5=31,GENDER_RATIO_FEMALE_25=63,
    GENDER_RATIO_FEMALE_50=127,GENDER_RATIO_FEMALE_75=191,GENDER_RATIO_FEMALE_87_5=223,
    GENDER_RATIO_FEMALE_ONLY=254,GENDER_RATIO_GENDERLESS=255,
  }
  return m[s] or 127
end

-- Evolution-only items that do not exist in one or both native Gen1/Gen2
-- item tables.  They are real item triggers, never compatibility shortcuts to
-- ordinary level evolutions.  SUN_STONE matters on a Gen-1 host; the Gen-4
-- stones matter on every host when the expanded dex is enabled.
local EVOLUTION_USE_ITEMS = {
  SUN_STONE   = { name="Sun Stone",   price=2100 },
  SHINY_STONE = { name="Shiny Stone", price=2100 },
  DUSK_STONE  = { name="Dusk Stone",  price=2100 },
  DAWN_STONE  = { name="Dawn Stone",  price=2100 },
}

-- A Gen-1 host cannot represent "trade while holding X" natively.  The
-- expanded adapter has always encoded direct item-use as that host's
-- compatibility route; registering those items as targeted field effects is
-- what makes that route actually reachable.  Gen 2 keeps its native
-- trade+held-item path and does not receive this direct-use conversion.
local GEN1_TRADE_ITEM_TRIGGERS = {
  DEEPSEASCALE=true, DEEPSEATOOTH=true, DRAGON_SCALE=true,
  DUBIOUS_DISC=true, ELECTIRIZER=true, KINGS_ROCK=true,
  MAGMARIZER=true, METAL_COAT=true, PROTECTOR=true,
  REAPER_CLOTH=true, UPGRADE=true,
}

local function registerEvolutionUseItems(mod, gen)
  local effects=mod.content.item_effects
  local items=mod.content.items
  if not effects or not items then return {registered=0,patched=0} end
  local ids={}
  for id in pairs(EVOLUTION_USE_ITEMS) do ids[id]=true end
  if gen==1 then for id in pairs(GEN1_TRADE_ITEM_TRIGGERS) do ids[id]=true end end
  local registered,patched=0,0
  local noEffect="It won't have any\neffect."

  for id in pairs(ids) do
    local addedEffect=false
    if effects:get(id)==nil then
      if gen==2 then
        effects:register(id,{
          action="stone", field=true, needsTarget=true,
          use=function(ctx)
            local mon=ctx and ctx.mon
            if not mon or mon.item=="EVERSTONE" then return {used=false,text=noEffect} end
            local Evolution=require("src.core.gen2.Evolution")
            local entry=Evolution.checkMon(ctx.data,mon,{force=true,item=ctx.item})
            if not entry then return {used=false,text=noEffect} end
            return {used=true,evolution=entry}
          end,
        })
      else
        effects:register(id,{
          field=true,battle=false,needsTarget=true,
          use=function(ctx)
            local mon=ctx and ctx.target
            if not mon then return "failed",{noEffect} end
            local game=mod.game or {data=ctx.data,save=ctx.save}
            local Evolution=require("src.pokemon.Evolution")
            local target=Evolution.pendingFor(game,mon,{kind="item",item=ctx.itemId})
            if not target then return "failed",{noEffect} end
            return "consumed",nil,{evolveTo=target}
          end,
        })
      end
      addedEffect=true
      registered=registered+1
    end
    local def=items:get(id)
    local meta=EVOLUTION_USE_ITEMS[id]
    if not def then
      local rec={id=id,name=(meta and meta.name) or id,price=(meta and meta.price) or 2100,
        tossable=true,needsTarget=true}
      -- Gen 1 dispatches custom field use through itemDef.effect.  Gen 2
      -- dispatches by item id through gen2ItemEffects, so leave its item
      -- record untouched by Gen-1-only metadata.
      if gen==1 then rec.effect=id end
      items:register(id,rec)
      registered=registered+1
    elseif gen==1 and addedEffect then
      -- Preserve native records.  Patch only a Gen-1 item for which this mod
      -- actually had to add the evolution-use effect.
      items:patch(id,{needsTarget=true,effect=id})
      patched=patched+1
    end
  end
  return {registered=registered,patched=patched}
end

local function makeEvolutionAdapter(mod,src,gen,speciesIdByDex,itemByNorm,moveByEnum)
  local sourceById={}; for _,sp in ipairs(src.species) do sourceById[sp.id]=sp end
  local reg=mod.content.evolution_methods
  local function targetId(enum)
    local raw=tostring(enum or "")
    local key=raw:gsub("^SPECIES_","")
    local sp=sourceById[key] or sourceById[raw]
    return sp and speciesIdByDex[sp.dex] or key
  end
  local function itemId(raw)
    raw=tostring(raw or ""):gsub("^ITEM_","")
    return itemByNorm[norm(raw)]
  end
  local sourceByRuntime={}
  for _,sp in ipairs(src.species or {}) do
    sourceByRuntime[speciesIdByDex[sp.dex] or sp.id]=sp
  end
  local function monGender(mon)
    if not mon then return "unknown" end
    local g=mon.gender or mon.ukGender
    if type(g)=="string" then
      g=g:lower()
      if g=="male" or g=="female" then return g end
    end
    -- Gen-1 has no gender field.  Derive it from the source species ratio and
    -- the DVs so Combee's 12.5% female ratio and single-sex species are not
    -- accidentally treated as a 50/50 split.
    local sp=sourceByRuntime[mon.species]
    local ratio=genderRatioByte(sp and sp.gender)
    if ratio==255 then return "unknown" end
    if ratio==254 then return "female" end
    if ratio==0 then return "male" end
    local atk=tonumber(mon.dvs and (mon.dvs.attack or mon.dvs.atk)) or 0
    local threshold=math.floor((ratio+1)/16)
    return atk<threshold and "female" or "male"
  end
  local function mapId()
    local g=mod.game; local w=g and g.world
    local m=w and (w.map or w.currentMap)
    return tostring((type(m)=="table" and (m.id or m.name)) or (g and g.save and g.save.map) or ""):upper()
  end
  local function hasMove(mon,enum)
    local raw=tostring(enum or "")
    local key=raw:gsub("^MOVE_","")
    local wanted=moveByEnum[raw] or moveByEnum[key] or key
    for _,mv in ipairs((mon and mon.moves) or {}) do if mv.id==wanted or mv==wanted then return true end end
    return false
  end
  local function partyHas(enum)
    local want=targetId(enum); local party=mod.game and mod.game.save and mod.game.save.party or {}
    for _,m in ipairs(party or {}) do if m.species==want then return true end end
    return false
  end
  local function stableBit(mon)
    local d=mon and mon.dvs or {}; local v=tonumber(d.attack or d.atk or 0)*4096+tonumber(d.defense or d.def or 0)*256+tonumber(d.speed or d.spd or 0)*16+tonumber(d.special or d.sp or 0)
    return v%10
  end
  local function specialMethod(source,e,check1,check2,desc,opts)
    -- Stable content-time ID. Runtime Pokedex-cap application rebuilds evolution
    -- rows after the mod registries have been frozen; IDs therefore cannot
    -- depend on the order in which adapters happen to be visited.  Derive the
    -- method ID only from immutable source evolution metadata so the exact same
    -- ID is reused at runtime and no late registry write is attempted.
    local targetDex=(sourceById[e.target] and sourceById[e.target].dex) or 0
    local parts={tostring(e.method or "SPECIAL")}
    for _,v in ipairs(e.args or {}) do parts[#parts+1]=tostring(v) end
    local sig=table.concat(parts,"_"):gsub("[^%w]+","_"):upper()
    if #sig>42 then sig=sig:sub(1,42) end
    local id=("U493_%03d_%03d_%s"):format(source.dex,targetDex,sig)
    if reg and reg:get(id)==nil then
      if gen==2 then
        local record={check=check2,describe=function() return desc or "Special condition" end}
        for k,v in pairs(opts or {}) do record[k]=v end
        reg:register(id,record)
      else
        reg:register(id,{check=check1,describe=function() return desc or "Special condition" end})
      end
    end
    return id
  end
  local function rowFor(e,source)
    source=source or {dex=0}
    local m=e.method; local a=e.args or {}; local target=targetId(e.target)
    local row=gen==2 and {into=target} or {species=target}
    if m=="EVO_LEVEL" or m=="EVO_LEVEL_NINJASK" then
      row.method=gen==2 and "EVOLVE_LEVEL" or "LEVEL"; row.level=tonumber(a[1]) or 1
    elseif m=="EVO_USE_ITEM" then
      local it=itemId(a[1]); if it then row.method=gen==2 and "EVOLVE_ITEM" or "ITEM"; row.item=it
      else
        -- A missing required item must never degrade into an ordinary level
        -- evolution.  Keep the row inert so validation can surface the missing
        -- bridge instead of silently evolving on the next level.
        row.method=specialMethod(source,e,function() return false end,function() return false end,"Unresolved evolution item")
      end
    elseif m=="EVO_USE_ITEM_MALE" or m=="EVO_USE_ITEM_FEMALE" then
      local it=itemId(a[1]); local sex=(m=="EVO_USE_ITEM_FEMALE") and "female" or "male"
      row.method=specialMethod(source,e,
        function(_,mon,_,tr) return it~=nil and tr.kind=="item" and tr.item==it and monGender(mon)==sex end,
        function(entry,mon,ctx) return it~=nil and ctx.force and ctx.item==it and monGender(mon)==sex end,
        "Item ("..sex..")", {requiresForce=true})
    elseif m=="EVO_TRADE" then row.method=gen==2 and "EVOLVE_TRADE" or "TRADE"
    elseif m=="EVO_TRADE_WITH_HELD_ITEM" then
      local it=itemId(a[1])
      if gen==2 and it then row.method="EVOLVE_TRADE"; row.item=it
      else row.method=specialMethod(source,e,
        function(_,mon,_,tr) return it~=nil and ((tr.kind=="trade" and (mon.item==it or mon.ukHeldItem==it)) or (tr.kind=="item" and tr.item==it)) end,
        function(_,mon,ctx) return it~=nil and ctx.link and mon.item==it end,"Trade with item") end
    elseif m=="EVO_LEVEL_HAPPINESS" then row.method=gen==2 and "EVOLVE_HAPPINESS" or "U493_HAPPY"
    elseif m=="EVO_LEVEL_HAPPINESS_DAY" then row.method=gen==2 and "EVOLVE_HAPPINESS" or "U493_HAPPY_DAY"; if gen==2 then row.time="MORNDAY" end
    elseif m=="EVO_LEVEL_HAPPINESS_NIGHT" then row.method=gen==2 and "EVOLVE_HAPPINESS" or "U493_HAPPY_NIGHT"; if gen==2 then row.time="NITE" end
    elseif m=="EVO_LEVEL_ATK_GT_DEF" or m=="EVO_LEVEL_ATK_LT_DEF" or m=="EVO_LEVEL_ATK_EQ_DEF" then
      row.level=tonumber(a[1]) or 1
      if gen==2 then row.method="EVOLVE_STAT"; row.comparison=({EVO_LEVEL_ATK_GT_DEF="ATK_GT_DEF",EVO_LEVEL_ATK_LT_DEF="ATK_LT_DEF",EVO_LEVEL_ATK_EQ_DEF="ATK_EQ_DEF"})[m]
      else row.method=({EVO_LEVEL_ATK_GT_DEF="U493_STAT_GT",EVO_LEVEL_ATK_LT_DEF="U493_STAT_LT",EVO_LEVEL_ATK_EQ_DEF="U493_STAT_EQ"})[m] end
    elseif m=="EVO_LEVEL_MALE" or m=="EVO_LEVEL_FEMALE" then
      local lv=tonumber(a[1]) or 1
      local sex=(m=="EVO_LEVEL_FEMALE") and "female" or "male"
      row.method=specialMethod(source,e,
        function(_,mon,_,tr) return tr.kind=="levelup" and (mon.level or 1)>=lv and monGender(mon)==sex end,
        function(_,mon,ctx) return not ctx.force and not ctx.link and (mon.level or 1)>=lv and monGender(mon)==sex end,
        "Level ("..sex..")")
    elseif m=="EVO_LEVEL_KNOW_MOVE" then
      local lv=tonumber(a[1]) or 1; local move=a[2] or a[1]
      if tonumber(a[1])==nil then lv=1; move=a[1] end
      row.method=specialMethod(source,e,function(_,mon,_,tr) return tr.kind=="levelup" and mon.level>=lv and hasMove(mon,move) end,function(_,mon,ctx) return not ctx.force and not ctx.link and mon.level>=lv and hasMove(mon,move) end,"Level knowing move")
    elseif m=="EVO_LEVEL_MAGNETIC_FIELD" or m=="EVO_LEVEL_MOSS_ROCK" or m=="EVO_LEVEL_ICE_ROCK" then
      local needle=m=="EVO_LEVEL_MAGNETIC_FIELD" and {"POWER","MT_CORONET"} or m=="EVO_LEVEL_MOSS_ROCK" and {"FOREST","ETERNA"} or {"ICE","SNOW"}
      row.method=specialMethod(source,e,function(_,_,_,tr) local x=mapId(); return tr.kind=="levelup" and (x:find(needle[1]) or x:find(needle[2])) end,function(_,_,ctx) local x=mapId(); return not ctx.force and not ctx.link and (x:find(needle[1]) or x:find(needle[2])) end,"Special location")
    elseif m=="EVO_LEVEL_WITH_HELD_ITEM_DAY" or m=="EVO_LEVEL_WITH_HELD_ITEM_NIGHT" then
      local it=itemId(a[1]); local night=m:find("NIGHT")~=nil
      local function timeOK() local h=tonumber(os.date("%H")) or 12; local n=h>=20 or h<4; return n==night end
      row.method=specialMethod(source,e,function(_,mon,_,tr) return it~=nil and tr.kind=="levelup" and timeOK() and (mon.item==it or mon.ukHeldItem==it) end,function(_,mon,ctx) local tod=ctx.timeOfDay; local n=tod=="NITE" or tod=="NITE_F"; return it~=nil and not ctx.force and not ctx.link and n==night and mon.item==it end,"Level holding item")
    elseif m=="EVO_LEVEL_PID_LOW" or m=="EVO_LEVEL_PID_HIGH" then
      local lv=tonumber(a[1]) or 7; local high=m:find("HIGH")~=nil
      row.method=specialMethod(source,e,function(_,mon,_,tr) return tr.kind=="levelup" and mon.level>=lv and ((stableBit(mon)>=5)==high) end,function(_,mon,ctx) return not ctx.force and not ctx.link and mon.level>=lv and ((stableBit(mon)>=5)==high) end,"Personality branch")
    elseif m=="EVO_LEVEL_BEAUTY" then
      local req=tonumber(a[1]) or 170
      row.method=specialMethod(source,e,function(_,mon,_,tr) return tr.kind=="levelup" and (tonumber(mon.beauty) or 0)>=req end,function(_,mon,ctx) return not ctx.force and not ctx.link and (tonumber(mon.beauty) or 0)>=req end,"Beauty")
    elseif m=="EVO_LEVEL_SPECIES_IN_PARTY" then
      local need=a[1]
      row.method=specialMethod(source,e,function(_,mon,_,tr) return tr.kind=="levelup" and partyHas(need) end,function(_,mon,ctx) return not ctx.force and not ctx.link and partyHas(need) end,"Species in party")
    elseif m=="EVO_LEVEL_SHEDINJA" then
      -- Shedinja is created by the pokemon.evolved side-spawn listener after
      -- Nincada -> Ninjask; this row is retained as an executable named method
      -- that intentionally never replaces the primary Ninjask evolution.
      row.method=specialMethod(source,e,function() return false end,function() return false end,"Ninjask side evolution")
    else
      local lv=tonumber(a[1]) or 1
      row.method=specialMethod(source,e,function(_,mon,_,tr) return tr.kind=="levelup" and mon.level>=lv end,function(_,mon,ctx) return not ctx.force and not ctx.link and mon.level>=lv end,"Generation 4 special evolution")
    end
    return row
  end
  return rowFor
end

-- The host closes nested Dex records to generation-specific fields. Gen 2
-- encodes feet/inches as FFFII and pounds in tenths; Gen 1 keeps split height
-- fields and decimal pounds. Never pass the shared source record through.
local function dexEntryForGeneration(meta, gen)
  if not meta then return nil end
  local entry={kind=meta.kind,text=meta.text,text2=meta.text2,
    heightM=meta.heightM,weightKg=meta.weightKg}
  if gen==2 then
    entry.height=meta.heightFt*100+meta.heightIn
    entry.weight=math.floor(meta.weight*10+0.5)
  else
    entry.heightFt=meta.heightFt;entry.heightIn=meta.heightIn
    entry.weight=meta.weight
  end
  return entry
end

function M.install(mod)
  local src=loadData(mod,"expanded493/source.lua")
  local fallback=loadData(mod,"expanded493/fallback_moves.lua")
  local abilityData=loadData(mod,"expanded493/abilities.lua")
  local heldItemData=loadData(mod,"expanded493/held_items.lua")
  local dexMeta=loadData(mod,"expanded493/dexmeta.lua")
  local nativeStyle=loadData(mod,"expanded493/native_assets/style.lua")
  local gen=currentGeneration(); local nativeMax=currentNativeMax()
  registerGrowth(mod); registerTypes(mod); registerSpecialEvolutionInfrastructure(mod,gen)
  local modernEffects=loadData(mod,"expanded493/modern_effects.lua")
  local effectAudit=modernEffects(mod,src)
  -- Oval Stone is a held evolution requirement, not a use-stone.  Mark it as
  -- a modern holdable with no battle effect so both host generations can carry
  -- the real Happiny condition.
  heldItemData.OVAL_STONE=heldItemData.OVAL_STONE or {id="OVAL_STONE",name="Oval Stone",holdEffect="HOLD_EFFECT_NONE",effectParam=0,price=2100,flingPower=30}
  local modernItems=loadData(mod,"expanded493/modern_items.lua")
  local itemAudit=modernItems(mod,heldItemData)
  local evolutionItemAudit=registerEvolutionUseItems(mod,gen)
  local moveByEnum=buildMoveResolver(mod,src,fallback)
  local pokemon=assert(mod.content.pokemon,"pokemon registry unavailable")
  local speciesByDex={}; local existingByNorm={}
  for id,rec in pokemon:each() do
    existingByNorm[norm(id)]=id; if type(rec)=="table" and rec.name then existingByNorm[norm(rec.name)]=id end
    if type(rec)=="table" and tonumber(rec.dex) then speciesByDex[tonumber(rec.dex)]=id end
  end
  for _,sp in ipairs(src.species) do speciesByDex[sp.dex]=speciesByDex[sp.dex] or existingByNorm[norm(sp.id)] or sp.id end
  local itemByNorm=resolveRegistryByNorm(mod.content.items)
  local contentItemByNorm={}; for k,v in pairs(itemByNorm) do contentItemByNorm[k]=v end
  local adaptEvo=makeEvolutionAdapter(mod,src,gen,speciesByDex,itemByNorm,moveByEnum)

  -- Register every custom evolution method while content registries are still
  -- writable.  applyCap() later re-adapts native + expanded species from the
  -- Gen-4 source after Loader:load has frozen registries, so every method that
  -- can appear in those rows must already exist before the loader finishes.
  for _,sp in ipairs(src.species) do
    for _,e in ipairs(sp.evolutions or {}) do adaptEvo(e,sp) end
  end

  local function expandedIconPath(dex)
    return mod.path..("/expanded493/native_assets/icons/%03d.png"):format(dex)
  end

  local exactBaseExp={}
  local addedDex={}
  local spByDex,sourceDexById={},{}; for _,sp in ipairs(src.species) do spByDex[sp.dex]=sp; sourceDexById[sp.id]=sp.dex end

  for _,sp in ipairs(src.species) do
    if sp.dex>nativeMax and pokemon:get(speciesByDex[sp.dex])==nil then
      local id=speciesByDex[sp.dex]
      local evos={}; for _,e in ipairs(sp.evolutions or {}) do evos[#evos+1]=adaptEvo(e,sp) end
      local level1,learn,levelMoves={},{},{}
      local seen={}
      -- Later-generation source rows are normally level-sorted, but a few
      -- retail/source tables (notably Platinum BANETTE) are not.  Both host
      -- generations build a caught/gift mon's opening four moves by walking
      -- the rows in order, so normalize only the EXPANDED compatibility rows
      -- before translating them.  Native cartridge species stay untouched.
      for _,r in ipairs(stableLevelRows(sp.levelup)) do
        local mid=moveByEnum[r.move]
        if mid then
          levelMoves[#levelMoves+1]={level=r.level,move=mid}
          if r.level<=1 then if not seen[mid] then level1[#level1+1]=mid; seen[mid]=true end else learn[#learn+1]={level=r.level,move=mid} end
        end
      end
      if #level1==0 and #levelMoves>0 then level1[1]=levelMoves[1].move end
      local tmhm,seenTm={},{}
      for _,me in ipairs(sp.tmhm or {}) do local mid=moveByEnum[me]; if mid and not seenTm[mid] then seenTm[mid]=true; tmhm[#tmhm+1]=mid end end
      local base={hp=sp.stats.hp,attack=sp.stats.attack,defense=sp.stats.defense,speed=sp.stats.speed}
      local rec
      if gen==2 then
        base.specialAttack=sp.stats.spAttack; base.specialDefense=sp.stats.spDefense
        rec={id=id,name=sp.name,dex=sp.dex,types={typeId(sp.types[1]),typeId(sp.types[2])},baseStats=base,
          catchRate=sp.catchRate,baseExp=math.min(255,sp.baseExp),growthRate=growthId(sp.growth,gen),
          genderRatio=genderRatioByte(sp.gender),eggGroups=sp.eggGroups,levelMoves=levelMoves,tmhm=tmhm,evolutions=evos,
          spriteFront=mod.path..("/expanded493/native_assets/ui_front/%03d.png"):format(sp.dex),
          spriteBack=mod.path..("/expanded493/native_assets/ui_back/%03d.png"):format(sp.dex),picSize=math.min(7,(nativeStyle[sp.dex] and nativeStyle[sp.dex].frontSize) or 7),trueColor=true,
          battleScaleFront=(nativeStyle[sp.dex] and nativeStyle[sp.dex].battleScaleFront) or 1.0,
          battleScaleBack=(nativeStyle[sp.dex] and nativeStyle[sp.dex].battleScaleBackGen2) or 1.0,dexEntry=dexEntryForGeneration(dexMeta[sp.dex],gen)}
      else
        base.special=sp.stats.special
        rec={id=id,name=sp.name,dex=sp.dex,types={typeId(sp.types[1]),typeId(sp.types[2])},baseStats=base,
          catchRate=sp.catchRate,baseExp=math.min(255,sp.baseExp),growthRate=growthId(sp.growth,gen),
          level1Moves=level1,learnset=learn,tmhm=tmhm,evolutions=evos,
          spriteFront=mod.path..("/expanded493/native_assets/ui_front/%03d.png"):format(sp.dex),
          spriteBack=mod.path..("/expanded493/native_assets/ui_back/%03d.png"):format(sp.dex),frontSize=math.min(7,(nativeStyle[sp.dex] and nativeStyle[sp.dex].frontSize) or 7),trueColor=true,
          battleScaleFront=(nativeStyle[sp.dex] and nativeStyle[sp.dex].battleScaleFront) or 1.0,
          battleScaleBack=(nativeStyle[sp.dex] and nativeStyle[sp.dex].battleScaleBackGen1) or 1.0,dexEntry=dexEntryForGeneration(dexMeta[sp.dex],gen),
          icon={image=expandedIconPath(sp.dex),frames=2}}
      end
      pokemon:register(id,rec); exactBaseExp[id]=sp.baseExp; addedDex[sp.dex]=id
      if mod.content.icons then
        if gen==2 then
          local sheet="ICON_U493_"..tostring(sp.dex)
          if mod.content.icons:get(sheet)==nil then mod.content.icons:register(sheet,{image=expandedIconPath(sp.dex),width=16,height=32,frames=2}) end
          if mod.content.icons:get(id)==nil then mod.content.icons:register(id,sheet) end
        elseif mod.content.icons:get(id)==nil then
          mod.content.icons:register(id,{image=expandedIconPath(sp.dex),frames=2})
        end
      end
    end
  end

  local constants=mod.content.constants
  if constants then local d=constants:get("dexSize"); if type(d)=="number" and d<493 then constants:patch("dexSize",493) end end

  local api={maxDex=493,nativeMax=nativeMax,addedDex=addedDex,source=src,effectAudit=effectAudit,itemAudit=itemAudit,evolutionItemAudit=evolutionItemAudit,heldItemData=heldItemData,abilityData=abilityData,dexMeta=dexMeta}
  function api.hasDex(game,dex)
    for _,def in pairs(game and game.data and game.data.pokemon or {}) do if tonumber(def.dex)==dex then return true end end
    return false
  end
  function api.isRenderReady(game,dex)
    if dex<=nativeMax then return api.hasDex(game,dex) end
    local id=addedDex[dex]; local d=id and game and game.data and game.data.pokemon and game.data.pokemon[id]
    return d and d.spriteFront and d.spriteBack and true or false
  end
  function api.applyEvolutionOverlay(game,cap)
    if not (game and game.data and game.data.pokemon) or cap<=nativeMax then return end
    local idByDex={}; for id,d in pairs(game.data.pokemon) do if tonumber(d.dex) then idByDex[tonumber(d.dex)]=id end end
    local itemMap=resolveDataByNorm(game.data.items)
    -- Loader-time registered modern items are authoritative even if an imported
    -- native item table did not originally contain that id.  Never let a later
    -- Pokédex-cap overlay rebuild forget them and reinterpret the method.
    for k,v in pairs(contentItemByNorm) do if itemMap[k]==nil then itemMap[k]=v end end
    local moveMap={}
    for enum,id in pairs(moveByEnum) do moveMap[enum]=id end
    local rowAdapt=makeEvolutionAdapter(mod,src,gen,idByDex,itemMap,moveMap)
    for dex=1,math.min(cap,493) do
      local sp=spByDex[dex]; local id=idByDex[dex]; local def=id and game.data.pokemon[id]
      if sp and def then
        local rows={}
        for _,e in ipairs(sp.evolutions or {}) do
          local t=sourceDexById[e.target]
          if t and t<=cap and idByDex[t] then rows[#rows+1]=rowAdapt(e,sp) end
        end
        def.evolutions=rows
      end
    end
  end

  -- Authored battle sprites (#001-493) are already final raster artwork.
  -- The cartridge send-out animation normally redraws a mon through coarse
  -- intermediate resize stages (Gen 1: 3/7 -> 5/7; Gen 2: 3x3/5x5 or
  -- 2x2/4x4 BG squares).  That is correct for native tile art but visibly
  -- changes/resamples our Gen 3/4 replacement sprites as they leave the ball.
  -- Keep the ball/poof beat, then reveal the exact authored sprite at its
  -- normal battle scale.  This applies to the entire replacement roster,
  -- including cartridge-native #001-151/#001-251, not only expanded species.
  -- Gen 1's cartridge WriteMonMoves fills four slots sequentially and shifts
  -- the oldest slot immediately whenever a fifth distinct move is reached.
  -- Gen1Recomp 0.2.24 instead accumulated every distinct historical move and
  -- trimmed only after the full scan.  That differs whenever a later learnset
  -- row repeats a move that had already fallen out of the four active slots
  -- (JIRACHI is the expanded-roster example).  Use the cartridge algorithm so
  -- wild/gift/trainer construction and randomized learnsets agree with actual
  -- level-up history.  The scan deliberately stops on the first future row,
  -- preserving native R/B/Y table-order quirks; expanded rows were stably
  -- level-sorted above for compatibility.
  local function installGen1StartingMoveCompatibility()
    if gen~=1 then return end
    local ok,Pokemon=pcall(require,"src.pokemon.Pokemon")
    if not ok or not Pokemon or Pokemon.__universalRandomizerMovesAtLevel then return end
    Pokemon.__universalRandomizerMovesAtLevel=true
    function Pokemon.movesAtLevel(speciesDef,level)
      local known={}
      local function add(move)
        if move==nil then return end
        for _,existing in ipairs(known) do if existing==move then return end end
        known[#known+1]=move
        if #known>4 then table.remove(known,1) end
      end
      for _,move in ipairs((speciesDef and speciesDef.level1Moves) or {}) do add(move) end
      for _,row in ipairs((speciesDef and speciesDef.learnset) or {}) do
        local moveLevel=tonumber(row and row.level) or math.huge
        if moveLevel>(tonumber(level) or 1) then break end
        add(row.move)
      end
      return known
    end
  end
  installGen1StartingMoveCompatibility()

  local function installAuthoredSendOutRendering()
    if gen==1 then
      local ok,BattleState=pcall(require,"src.battle.BattleState")
      if ok and BattleState and not BattleState.__universalRandomizerAuthoredSendOut then
        BattleState.__universalRandomizerAuthoredSendOut=true
        local baseGrowInScale=BattleState.growInScale
        function BattleState:growInScale(battler)
          local scale=baseGrowInScale(self,battler)
          if scale==nil then return nil end
          local mon=battler and battler.mon
          local def=mon and self.data and self.data.pokemon
            and self.data.pokemon[mon.species]
          if def and def.urAuthoredBattleSprite then
            -- Preserve the three-frame ball beat (0), but never draw an
            -- authored sprite at a resampled intermediate size.
            return scale==0 and 0 or 1
          end
          return scale
        end
      end
    elseif gen==2 then
      local ok,BattleState=pcall(require,"src.ui.gen2.BattleState")
      if ok and BattleState and not BattleState.__universalRandomizerAuthoredSendOut then
        BattleState.__universalRandomizerAuthoredSendOut=true
        local baseAnimPicState=BattleState.animPicState
        function BattleState:animPicState(side)
          local state=baseAnimPicState(self,side)
          if state and self.anim and self.anim.animId=="ANIM_SEND_OUT_MON" then
            local mon=self.activeMon and self:activeMon(side) or nil
            local data=self.game and self.game.data
            local def=mon and data and data.pokemon and data.pokemon[mon.species]
            if def and def.urAuthoredBattleSprite then
              -- Leave all ball/OAM/shiny timing intact; only suppress the
              -- cartridge BG resize that would resample the authored image.
              state.size=nil
            end
          end
          return state
        end
      end
    end
  end
  installAuthoredSendOutRendering()

  -- Generation-native sprite bridge.  Non-battle UI uses compact canvases
  -- made from the same original-game pixels; battle draws use the untouched
  -- Gold/Emerald/Platinum source canvases and the species scale metadata above.
  if mod.hooks then
    mod.hooks:wrap("pokemon.sprite",function(next,path,ctx)
      path=next(path,ctx)
      local species=ctx and ctx.species
      local data=ctx and ctx.data
      local def=species and data and data.pokemon and data.pokemon[species]
      local dex=def and tonumber(def.dex)
      if not dex or dex<1 or dex>493 then return path end
      local side=(ctx and ctx.side)=="back" and "back" or "front"
      local shiny=(ctx and ctx.shiny) or (ctx and ctx.mon and ctx.mon.shiny)

      -- Every replacement in native_assets is already full-colour artwork.
      -- This flag is essential: without it Gen1Recomp applies the cartridge's
      -- 4-shade/GBC palette to Gen 3/4 pixels, which is why Save 11's title,
      -- Oak demo, summary and battle sprites looked washed-out/orange.
      if ctx then ctx.trueColor=true end

      if (ctx and ctx.kind)=="battle" then
        local dir=shiny and (side.."_shiny") or side
        return mod.path..("/expanded493/native_assets/%s/%03d.png"):format(dir,dex)
      end
      local dir=shiny and ("ui_"..side.."_shiny") or ("ui_"..side)
      return mod.path..("/expanded493/native_assets/%s/%03d.png"):format(dir,dex)
    end)
    mod.hooks:wrap("pokemon.icon",function(next,path,ctx)
      path=next(path,ctx)
      local species=ctx and ctx.species
      local data=ctx and ctx.data
      local def=species and data and data.pokemon and data.pokemon[species]
      local dex=def and tonumber(def.dex)
      -- Gen 3 is now the visual floor for the ENTIRE #001-386 roster, so
      -- cartridge-native Gen 1/2 species must use the upgraded icon too.
      if dex and dex>=1 and dex<=493 then return expandedIconPath(dex) end
      return path
    end)
  end

  mod.events:on("game.ready",function(ev)
    local game=ev and (ev.game or ev)
    if not (game and game.data and game.data.pokemon) then return end
    -- Complete National Dex #001-493 cry bridge.  Use the authentic Platinum
    -- cry WAVs bundled from the user-supplied pokeplatinum source tree so every
    -- species has a real species-specific cry on every supported cartridge host.
    game.data.audio=game.data.audio or {}
    game.data.audio.cries=game.data.audio.cries or {}

    -- Normalize ALL #001-493 species to the per-species calibrated battle
    -- canvases. Front assets are baked into the host's true 56x56 enemy box,
    -- so they render at 1x on both Gen 1 and Gen 2 without touching the
    -- player HUD. Back assets are baked into 64x64; Gen 1 draws them at 1x
    -- and Gen 2 maps them into its native 48x48 player box at 0.75x.
    for _,def in pairs(game.data.pokemon) do
      local dex=tonumber(def and def.dex)
      if dex and dex>=1 and dex<=493 then
        def.trueColor=true
        def.urAuthoredBattleSprite=true
        def.battleScaleFront=1.0
        def.battleScaleBack=(gen==2 and 0.75 or 1.0)
      end
    end
    for species,def in pairs(game.data.pokemon) do
      local dex=tonumber(def and def.dex)
      if dex and dex>=1 and dex<=493 then
        game.data.audio.cries[species]=mod.path..("/expanded493/native_assets/cries/%03d.wav"):format(dex)
      end
    end
    for id,v in pairs(exactBaseExp) do if game.data.pokemon[id] then game.data.pokemon[id].baseExp=v end end
    -- Keep the source generation's six-stat block beside every species,
    -- including cartridge-native #001-151/#001-251. Gen 4/5 rulesets on a
    -- Gen 1 host can then use distinct SpA/SpD without replacing the save's
    -- native five-stat structure. Randomized base-stat modes may mutate this
    -- sidecar while the normal host UI/save representation stays compatible.
    local idByDex={}
    for id,d in pairs(game.data.pokemon) do if type(d)=="table" and tonumber(d.dex) then idByDex[tonumber(d.dex)]=id end end

    -- 1.3.23 party/menu icon polish. The pokemon.icon hook changes only the
    -- resolved path. Gen 1 can still remember the cartridge icon *class* and
    -- run that replacement through OBP grayscale + left-half mirroring; Gen 2
    -- can still route it through the shared party OBJ palette. Both transforms
    -- are correct for native 2bpp icon classes but damage our authored
    -- species-specific RGBA icon sheets. Register the replacement as actual
    -- per-species icon metadata so the host knows it is custom art.
    if game.data.icons then
      if gen==1 then
        game.data.icons.bySpecies=game.data.icons.bySpecies or {}
        for species,def in pairs(game.data.pokemon) do
          local dex=tonumber(def and def.dex)
          if dex and dex>=1 and dex<=493 then
            local authored={image=expandedIconPath(dex),frames=2,urTrueColor=true}
            game.data.icons.bySpecies[species]=authored
            def.icon=authored
          end
        end
      elseif gen==2 then
        game.data.icons.icons=game.data.icons.icons or {}
        game.data.icons.species=game.data.icons.species or {}
        for species,def in pairs(game.data.pokemon) do
          local dex=tonumber(def and def.dex)
          if dex and dex>=1 and dex<=493 then
            local sheet="ICON_U493_"..tostring(dex)
            game.data.icons.icons[sheet]={id=sheet,image=expandedIconPath(dex),width=16,height=32,frames=2,urTrueColor=true}
            game.data.icons.species[species]=sheet
          end
        end
      end
    end
    if gen==2 and game.data.gen2Pokedex then
      local gd=game.data.gen2Pokedex
      gd.entries=gd.entries or {}; gd.newOrder=gd.newOrder or {}; gd.alphabeticalOrder=gd.alphabeticalOrder or {}
      local newSeen={}
      for _,id in ipairs(gd.newOrder) do newSeen[id]=true end
      for dex=1,493 do
        local id=idByDex[dex]; local dm=dexMeta[dex]
        if id and dm and not gd.entries[id] then
          gd.entries[id]={dex=dex,kind=dm.kind,height=dm.heightFt*100+dm.heightIn,weight=math.floor(dm.weight*10+0.5),heightM=dm.heightM,weightKg=dm.weightKg,text=dm.text}
          if not newSeen[id] then gd.newOrder[#gd.newOrder+1]=id; newSeen[id]=true end
        end
      end
      gd.alphabeticalOrder={}
      for id in pairs(gd.entries) do gd.alphabeticalOrder[#gd.alphabeticalOrder+1]=id end
      table.sort(gd.alphabeticalOrder,function(a,b) return tostring((game.data.pokemon[a] and game.data.pokemon[a].name) or a)<tostring((game.data.pokemon[b] and game.data.pokemon[b].name) or b) end)
    end
    for dex,sp in pairs(spByDex) do
      local id=idByDex[dex]; local d=id and game.data.pokemon[id]
      if d then
        d.urModernBaseStats={hp=sp.stats.hp,attack=sp.stats.attack,defense=sp.stats.defense,speed=sp.stats.speed,
          specialAttack=sp.stats.spAttack,specialDefense=sp.stats.spDefense}
        local ad=abilityData and abilityData.species and abilityData.species[dex]
        d.urAbilities=ad and ad.abilities or {}
        d.urBaseFriendship=ad and ad.baseFriendship or 70
      end
    end
  end)
  -- Nincada cast-off evolution: after the primary level evolution, create the
  -- side-row target as a second party member when its generation rules allow it.
  mod.events:on("pokemon.evolved",function(ev)
    local game=mod.game
    if not (game and ev and ev.fromSpecies and ev.toSpecies and game.save and game.save.party) then return end
    local from=game.data.pokemon[ev.fromSpecies]
    if not (from and tonumber(from.dex)==290) then return end
    if #game.save.party>=6 then return end

    -- Platinum/GEN4 semantics require one ordinary POKE BALL in the Bag and
    -- consume it to create Shedinja.  GEN1/2/3 rules retain Nincada's original
    -- Generation III behavior, where party space alone is sufficient.
    local cfg=(mod.save and mod.save.get and mod.save:get("config",{})) or {}
    local needsBall=cfg.ruleset=="GEN4"
    local inventory=game.save.inventory or {}
    local pokeBallId=nil
    for id,d in pairs(game.data.items or {}) do
      if norm(id)=="POKEBALL" or (type(d)=="table" and norm(d.name)=="POKEBALL") then pokeBallId=id; break end
    end
    if needsBall and (not pokeBallId or (tonumber(inventory[pokeBallId]) or 0)<1) then return end

    -- The cast-off target is the second Nincada evolution row itself.  This
    -- matters when EVOLUTIONS=RANDOM: mutateEvolutions randomizes that target
    -- while preserving the special side-spawn condition, so the runtime must
    -- create the randomized target rather than silently hard-code Shedinja.
    local sideId=nil
    for _,row in ipairs(from.evolutions or {}) do
      if tostring(row.method or ""):find("EVO_LEVEL_SHEDINJA",1,true) then
        sideId=row.species or row.into; break
      end
    end
    if not sideId or not game.data.pokemon[sideId] then return end
    local srcMon=ev.mon
    local copy={}
    for k,v in pairs(srcMon or {}) do copy[k]=v end
    copy.species=sideId; copy.nickname=nil
    if srcMon and srcMon.moves then copy.moves={}; for i,m in ipairs(srcMon.moves) do copy.moves[i]={id=m.id,pp=m.pp} end end

    if gen==2 then
      local ok,Mon=pcall(require,"src.battle.gen2.Mon")
      if ok and Mon and Mon.refreshStats then Mon.refreshStats(copy,game.data) end
    else
      local ok,Stats=pcall(require,"src.pokemon.Stats")
      if ok and Stats and Stats.calc then copy.stats=Stats.calc(game.data.pokemon[sideId],copy.level,copy.dvs,copy.statExp) end
    end
    -- Shedinja itself is the one-HP exception to the ordinary stat formula.
    -- A randomized cast-off target uses its own normal HP/stat block.
    local sideDef=game.data.pokemon[sideId]
    if tonumber(sideDef and sideDef.dex)==292 then
      copy.stats=copy.stats or {}; copy.stats.hp=1; copy.hp=1; copy.maxHp=1
    elseif copy.stats then
      copy.maxHp=copy.stats.hp; copy.hp=math.max(1,math.min(tonumber(copy.hp) or copy.stats.hp,copy.stats.hp))
    end
    table.insert(game.save.party,copy)

    if needsBall then
      inventory[pokeBallId]=inventory[pokeBallId]-1
      if inventory[pokeBallId]<=0 then inventory[pokeBallId]=nil end
    end
    if game.save.pokedex then game.save.pokedex.seen[sideId]=true; game.save.pokedex.owned[sideId]=true end
  end)

  return api
end

return M
