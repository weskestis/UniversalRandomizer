-- Untamed Tohjo 1.2.1 reads native tables (including fishing) and starts its
-- visible battles directly. Supply one consistent, seeded encounter view to
-- its owned callbacks. Ordinary encounters retain their native tables and
-- existing Randomizer hooks. No edits to Untamed, sprites, DVs or save data.
return function(mod,Core,Randomizer)
  local C={}
  local unpack=table.unpack or unpack
  local wrapped=setmetatable({},{__mode="k"})
  local cache,frame
  local function pack(...) return {n=select("#",...),...} end
  local function shallow(t)
    local out={}; for k,v in pairs(t or {}) do out[k]=v end; return out
  end
  local function capture(data)
    return {encounters=data.encounters,gen2Encounters=data.gen2Encounters,field=data.field}
  end
  local function assign(data,view)
    data.encounters=view.encounters; data.gen2Encounters=view.gen2Encounters; data.field=view.field
  end

  function C.buildView(a,mapId)
    local data=a.game.data
    local view=capture(data)
    -- Keep preview selection/counters separate from random step encounters.
    local preview=setmetatable({preview=true,wildMap={},areaPools={},areaUsed={},areaCounters={},
      areaHighVariety=Core.copy(a.areaHighVariety or {}),encounterRollState={},
      areaBaseSpecies={},areaExtraSpecies={}},{__index=a})
    local function transform(node,path,terrain)
      if type(node)~="table" then return node end
      local out={}
      for _,key in ipairs(Core.sortedKeys(node)) do
        out[key]=transform(node[key],path.."/"..tostring(key),terrain)
      end
      if node.species~=nil and node.species~=0 and type(node.level)=="number" then
        local enc=Randomizer.visibleEncounter(preview,node.species,node.level,mapId,terrain,path)
        out.species,out.level=enc.species,enc.level
      end
      return out
    end
    if a.generation==2 then
      local native=data.gen2Encounters or data.encounters or {}
      local enc=shallow(native)
      for _,kind in ipairs({"grass","water","swarmGrass","swarmWater"}) do
        if type(native[kind])=="table" then
          enc[kind]=shallow(native[kind])
          if native[kind][mapId] then
            local terrain=(kind=="water" or kind=="swarmWater") and "water" or "grass"
            enc[kind][mapId]=transform(native[kind][mapId],mapId.."/"..kind,terrain)
          end
        end
      end
      -- Time-group indirections remain intact. Both direct day/nite slots and
      -- indirect time groups receive the same species/level transformation.
      enc.fishGroups=transform(native.fishGroups,"fishGroups","fishing")
      enc.timeFishGroups=transform(native.timeFishGroups,"timeFishGroups","fishing")
      view.encounters=enc
      if data.gen2Encounters then view.gen2Encounters=enc end
    else
      view.encounters=shallow(data.encounters)
      if view.encounters[mapId] then
        local map=shallow(view.encounters[mapId]); view.encounters[mapId]=map
        for _,terrain in ipairs({"grass","water"}) do
          map[terrain]=transform(map[terrain],mapId.."/"..terrain,terrain)
        end
      end
      local field=shallow(data.field)
      local ok,FD=pcall(require,"src.world.FieldDefaults")
      local fishing=ok and FD.field and FD.field(data,"fishing") or field.fishing
      if fishing then
        field.fishing=transform(fishing,"fishing","fishing")
        for _,rod in pairs(fishing) do
          local key=type(rod)=="table" and rod.perMap
          if key and type(field[key])=="table" then
            field[key]=shallow(field[key])
            field[key][mapId]=transform(field[key][mapId],mapId.."/"..key,"fishing")
          end
        end
      end
      view.field=field
    end
    return view
  end

  local function currentView(game)
    local a=Randomizer.active()
    if not a or a.game~=game then return nil end
    local world=game.world or game.overworld
    local mapId=world and world.map and world.map.id
    if not mapId then return nil end
    local cfg=a.cfg
    local badges=Randomizer.startBadgeCount and Randomizer.startBadgeCount(a) or 0
    local signature=table.concat({mapId,badges,tostring(a.randomStartUsed),cfg.random_start or "",cfg.wild_levels or 0,a.fingerprint or ""},"|")
    if not cache or cache.active~=a or cache.signature~=signature
        or cache.encounters~=game.data.encounters or cache.gen2Encounters~=game.data.gen2Encounters
        or cache.field~=game.data.field then
      cache={active=a,signature=signature,encounters=game.data.encounters,
        gen2Encounters=game.data.gen2Encounters,field=game.data.field,
        view=C.buildView(a,mapId)}
    end
    return cache.view
  end

  local function withView(game,fn,...)
    if frame and frame.game==game then return fn(...) end
    local view=game and game.data and currentView(game)
    if not view then return fn(...) end
    local previous=frame
    local current={game=game,data=game.data,original=capture(game.data)}
    frame=current; assign(current.data,view)
    local result=pack(pcall(fn,...))
    assign(current.data,current.original); frame=previous
    if not result[1] then error(result[2],0) end
    return unpack(result,2,result.n)
  end

  local function withoutView(fn,...)
    local current=frame
    if not current then return fn(...) end
    assign(current.data,current.original); frame=nil
    local result=pack(pcall(fn,...))
    -- next() may load a save, change maps or replace a data table. Preserve
    -- those native changes and rebuild the view for Untamed's remaining tick.
    current.original=capture(current.data)
    local view=currentView(current.game)
    assign(current.data,view or current.original); frame=current
    if not result[1] then error(result[2],0) end
    return unpack(result,2,result.n)
  end

  function C.attach(game)
    local loader=game and game.mods
    if not loader then return end
    local function visit(groups,isHook)
      for _,list in pairs(groups or {}) do
        for _,entry in ipairs(list) do
          if entry.owner=="overworldmons" and wrapped[entry]~=entry.callback then
            local base=entry.callback
            if isHook then
              entry.callback=function(nextFn,...)
                local function nativeNext(...) return withoutView(nextFn,...) end
                return withView(mod.game or game,base,nativeNext,...)
              end
            else
              entry.callback=function(...) return withView(mod.game or game,base,...) end
            end
            wrapped[entry]=entry.callback
          end
        end
      end
    end
    visit(loader.events and loader.events.listeners,false)
    visit(loader.hooks and loader.hooks.chains,true)
  end

  -- Engine-internal integration uses the host's owner-tagged registrations,
  -- preserving registration order, priorities, removal and failure handling.
  -- It is independent of which mod was loaded first and tolerates reloading.
  local function attach(ev)
    local game=(ev and ev.game) or mod.game
    cache=nil; C.attach(game)
  end
  mod.events:on("mods.loaded",attach,100001)
  mod.events:on("game.ready",attach,100001)
  mod.events:on("save.loaded",attach,100001)
  mod.events:on("map.entered",function() cache=nil end,100001)
  mod.events:on("battle.ended",function() cache=nil end,100001)
  mod.events:on("mod.options_changed",function() cache=nil end,100001)
  mod.hooks:wrap("input.step",function(nextFn,game,dt)
    C.attach(game)
    return nextFn(game,dt)
  end,100001)
  return C
end
