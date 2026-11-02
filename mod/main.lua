return function(mod)
  local function localModule(path)
    local src,err=mod:read(path)
    assert(src,err or (path.." missing"))
    local chunk,cerr=load(src,"@"..mod.path.."/"..path)
    assert(chunk,cerr)
    return chunk()
  end

  local Core=localModule("core.lua")
  local Native=localModule("native_content.lua")(mod)
  Native.install()
  local Adapters=localModule("adapters.lua")
  local LogicFactory=localModule("logic_graph.lua")
  local Logic=LogicFactory(Core)
  local RandomizerFactory=localModule("randomizer.lua")
  local ItemLogic=localModule("progression_items.lua")(Core)
  local Gen1World=localModule("gen1_world.lua")(Core)
  local Gen2World=localModule("gen2_world.lua")(Core)
  local Worlds=localModule("worlds.lua")(Gen1World,Gen2World)
  local Randomizer=RandomizerFactory(mod,Core,Adapters,ItemLogic,Logic,Worlds)
  Worlds.install(mod,Randomizer,ItemLogic)
  local UIFactory=localModule("ui.lua")
  local UI=UIFactory(mod,Core,Randomizer)

  -- Live in-game controls are an ADDITIONAL access point: New Game setup remains
  -- authoritative when a run is created. The per-mod OPTIONS page mirrors the
  -- committed run and can change level scaling plus Mart Safety while active.
  local LEVEL_CHOICES={}
  for pct=-50,50,10 do
    LEVEL_CHOICES[#LEVEL_CHOICES+1]={(tostring(pct).." PCT"),pct}
  end
  mod.options:define({
    {key="wild_level_pct",type="choice",label="WILD LEVEL",default=0,choices=LEVEL_CHOICES},
    {key="trainer_level_pct",type="choice",label="TRAINER LEVEL",default=0,choices=LEVEL_CHOICES},
    {key="boss_level_pct",type="choice",label="BOSS LEVEL",default=0,choices=LEVEL_CHOICES},
    {key="mart_safety",type="toggle",label="MART SAFETY",default=false},
  })
  local LIVE_LEVEL_KEYS={
    wild_level_pct="wild_levels", trainer_level_pct="trainer_levels", boss_level_pct="boss_levels",
  }
  local function syncLevelOptionMirror(game,cfg)
    if not game or type(cfg)~="table" then return end
    local values={
      wild_level_pct=tonumber(cfg.wild_levels) or 0,
      trainer_level_pct=tonumber(cfg.trainer_levels) or 0,
      boss_level_pct=tonumber(cfg.boss_levels) or 0,
      mart_safety=not not cfg.mart_safety,
    }
    if game.save and game.save.options then
      game.save.options.modOptions=game.save.options.modOptions or {}
      game.save.options.modOptions.universal_randomizer=game.save.options.modOptions.universal_randomizer or {}
      for k,v in pairs(values) do game.save.options.modOptions.universal_randomizer[k]=v end
    end
    if game.mods then
      game.mods.modOptions=game.mods.modOptions or {}
      game.mods.modOptions.universal_randomizer=game.mods.modOptions.universal_randomizer or {}
      for k,v in pairs(values) do game.mods.modOptions.universal_randomizer[k]=v end
    end
    if game.writeOptions then pcall(game.writeOptions,game) end
  end

  -- 1.3.21: Gen1Recomp uses two different presentation paths here. Gen 1
  -- honors state:uiSize(), while Gen 2 always positions the state stack from
  -- a classic 160x144 origin. 1.3.20 widened the draw coordinates but did not
  -- give Game2 a matching wide-screen compositor, so on Gold/Silver the
  -- 304px menu began at the centred *160px* origin and ran off to the right.
  -- Keep one 304x144 layout and give each host generation its native centred
  -- presentation path. Other mods/ManagerState screens remain untouched.
  local function installWideRandomizerOptions()
    local okM,ManagerState=pcall(require,"src.mods.ManagerState")
    local okF,Font=pcall(require,"src.render.Font")
    local okT,Theme=pcall(require,"src.ui.Theme")
    if not okM or not ManagerState or not okF or not Font or not okT or not Theme
        or ManagerState.__universalRandomizerWideOptions then return end
    ManagerState.__universalRandomizerWideOptions=true
    local baseDraw=ManagerState.draw
    local baseUISize=ManagerState.uiSize
    local baseDrawsWidescreen=ManagerState.drawsWidescreen
    local baseDrawWidescreen=ManagerState.drawWidescreen

    local function isOurOptions(self)
      return self and self.screen=="options" and self.currentMod
        and self.currentMod.id=="universal_randomizer"
    end

    local function drawWideOptions(self)
      love.graphics.setColor(1,1,1,1)
      love.graphics.rectangle("fill",0,0,304,144)
      local rows=self.optionRows or {}
      local scroll=self.scroll or 0
      for slot=1,4 do
        local i=scroll+slot
        local row=rows[i]
        if not row then break end
        local tileY=(slot-1)*4
        Font.drawBox(0,tileY,38,4)
        love.graphics.setColor(0,0,0,1)
        Font.draw(tostring(row.label or ""),16,(tileY+1)*8)
        local value=row.value and row.value(self.game) or ""
        Font.draw(tostring(value or ""),176,(tileY+2)*8)
        if i==self.cursor then Font.drawCode(Theme.cursor,8,(tileY+1)*8) end
      end
      if scroll+4<#rows then Font.drawCode(Theme.moreArrow,288,128) end
      love.graphics.setColor(0,0,0,1)
      Font.draw(self.notice or "B:DONE (NO RESTART)",8,136)
      love.graphics.setColor(1,1,1,1)
      if self.overlay then self:drawOverlay() end
    end

    -- Gen 1: Game:draw resolves this state-sized surface before Renderer
    -- computes its letterbox, so the 304px canvas is centred correctly.
    function ManagerState:uiSize()
      if isOurOptions(self) then return 304,144 end
      if baseUISize then return baseUISize(self) end
      return 160,144
    end
    function ManagerState:draw()
      if not isOurOptions(self) then return baseDraw(self) end
      return drawWideOptions(self)
    end

    -- Gen 2: Game2 does not consult state:uiSize(). Opt this one screen into
    -- its widescreen-owner path and centre the WHOLE 304x144 composition in
    -- the available playfield. This is the placement 1.3.20 was missing.
    function ManagerState:drawsWidescreen()
      if isOurOptions(self) then return true end
      if baseDrawsWidescreen then return baseDrawsWidescreen(self) end
      return false
    end
    function ManagerState:drawWidescreen(w,h)
      if not isOurOptions(self) then
        if baseDrawWidescreen then return baseDrawWidescreen(self,w,h) end
        return
      end
      local G=love.graphics
      G.setColor(1,1,1,1)
      G.rectangle("fill",0,0,w,h)
      local scale=math.max(1,math.floor(math.min(w/304,h/144)))
      -- If a very small viewport cannot fit 304px at integer scale, use the
      -- exact fractional fit rather than clipping the right edge.
      if 304*scale>w or 144*scale>h then
        scale=math.min(w/304,h/144)
      end
      local ox=math.floor((w-304*scale)/2)
      local oy=math.floor((h-144*scale)/2)
      G.push()
      G.translate(ox,oy)
      G.scale(scale,scale)
      drawWideOptions(self)
      G.pop()
      G.setColor(1,1,1,1)
    end
  end
  installWideRandomizerOptions()

  mod.exports.adapters=Adapters
  mod.exports.logicGraph=Logic
  mod.exports.defaults=Randomizer.defaults
  mod.exports.normalizedConfig=Randomizer.normalizedConfig
  mod.exports.preflight=Randomizer.preflight
  mod.exports.pokedexCap=Randomizer.pokedexCap
  mod.exports.availablePokedexModes=Randomizer.availablePokedexModes
  mod.exports.poolSize=Randomizer.poolSize
  mod.exports.generate=Randomizer.generate
  -- Exposed for deterministic runtime/CI startup-flow probes. The in-game UI
  -- uses the same two functions one stage per input frame.
  mod.exports.beginGenerate=Randomizer.beginGenerate
  mod.exports.stepGenerate=Randomizer.stepGenerate
  mod.exports.commit=Randomizer.commit
  mod.exports.clear=function(game)
    local target=game or mod.game
    local out=Randomizer.clear(target)
    return out
  end
  mod.exports.setLiveLevelModifier=Randomizer.setLiveLevelModifier
  mod.exports.setLiveMartSafety=Randomizer.setLiveMartSafety
  mod.exports.active=Randomizer.active
  mod.exports.summary=Randomizer.summary
  mod.exports.runCode=Randomizer.runCode
  mod.exports.logicCheck=Randomizer.logicCheck
  mod.exports.spoilerData=Randomizer.spoilerData
  mod.exports.spoilerText=Randomizer.spoilerText
  mod.exports.hintForSign=Randomizer.hintForSign
  mod.exports.buyHint=Randomizer.buyHint
  -- Route-state exports are read-only/maintenance surfaces used by runtime
  -- certification and companion challenge mods; normal play advances them
  -- through map.entered automatically.
  mod.exports.routeProgressionState=Randomizer.routeProgressionState
  mod.exports.onMapEntered=Randomizer.onMapEntered
  mod.exports.refreshRouteRoadblocks=Randomizer.refreshRouteRoadblocks
  mod.exports.routeHint=Randomizer.routeHint

  Randomizer.installHooks()
  ItemLogic.installHardcoded(mod,Randomizer)
  localModule("gift_items.lua")(mod,Core,Randomizer,ItemLogic)
  localModule("untamed_compat.lua")(mod,Core,Randomizer)

  local function yieldKaizoLevelOwnership(game,cfgKey)
    -- Kaizo Ultimate intentionally owns a level category whenever its matching
    -- live percentage is non-zero. That is useful when the player changes the
    -- Kaizo menu, but it made a later change in the Randomizer menu appear to
    -- do nothing. Treat the menu touched last as authoritative: changing a
    -- Universal Randomizer level row resets only the matching Kaizo row to 0,
    -- which is Kaizo's documented "defer to Randomizer" value.
    if not game or not game.mods or not game.mods.modOptions then return end
    local modId="gen1_kaizo"
    local rows=game.mods.modOptions[modId]
    if type(rows)~="table" or rows[cfgKey]==nil or tonumber(rows[cfgKey])==0 then return end
    rows[cfgKey]=0
    if game.save and game.save.options then
      game.save.options.modOptions=game.save.options.modOptions or {}
      game.save.options.modOptions[modId]=game.save.options.modOptions[modId] or {}
      game.save.options.modOptions[modId][cfgKey]=0
    end
    if game.writeOptions then pcall(game.writeOptions,game) end
    if game.mods.events and game.mods.events.emit then
      pcall(game.mods.events.emit,game.mods.events,"mod.options_changed",
        {mod=modId,key=cfgKey,value=0})
    end
    mod.log:info("%s changed in Randomizer; Kaizo %s reset to 0%% (defer)",
      tostring(cfgKey),tostring(cfgKey))
  end

  mod.events:on("mod.options_changed",function(ev)
    if not ev or ev.mod~="universal_randomizer" then return end
    local game=mod.game or (Randomizer.active() and Randomizer.active().game)
    if ev.key=="mart_safety" then
      local ok,why=Randomizer.setLiveMartSafety(game,ev.value)
      local active=Randomizer.active()
      if ok and active and active.cfg.mart_safety~=not not ev.value then syncLevelOptionMirror(game,active.cfg) end
      if not ok and why~="no active randomizer seed" then mod.log:error("live Mart Safety rejected: %s",tostring(why)) end
      return
    end
    local cfgKey=LIVE_LEVEL_KEYS[ev.key]
    if not cfgKey then return end
    local ok,why=Randomizer.setLiveLevelModifier(game,cfgKey,ev.value)
    if ok then
      yieldKaizoLevelOwnership(game,cfgKey)
    elseif why~="no active randomizer seed" then
      mod.log:error("live level option rejected: %s",tostring(why))
    end
  end)

  -- The setup is part of a new game's Oak/Elm opening on both generations.
  -- No seed is committed before this step: settings first, validation second,
  -- seed commit third. Cancelling continues as a vanilla game.
  mod.hooks:wrap("intro.oak_speech.build",function(nextFn,steps,speech)
    steps=nextFn(steps,speech)
    if type(steps)~="table" then return steps end
    local inserted={
      id="universal_randomizer_setup",
      kind="fn",
      run=function(sp,done)
        Native.restoreRules(sp.game)
        UI.openSetup(sp.game,function(randomized,active)
          -- Never strand Oak/Elm's timeline if a post-commit presentation or
          -- option mirror fails. The setup UI already committed the seed; the
          -- intro callback must release its fn-step exactly once either way.
          local ok,why=pcall(function()
            if randomized and active then
              syncLevelOptionMirror(sp.game,active.cfg)
            end
          end)
          if not ok then mod.log:error("randomizer begin finalization failed: %s",tostring(why)) end
          done()
        end)
      end,
    }
    -- Put setup at the very front of the Oak/Elm timeline. The OakSpeech
    -- screen may already own the background/music, but no Professor text or
    -- naming prompt is allowed to run until the randomizer has been chosen.
    -- This keeps New Game -> Randomizer Setup -> Oak/Elm introduction.
    table.insert(steps,1,inserted)
    return steps
  end)

  local function activateSaved(game,context)
    local ok,active,err=pcall(Randomizer.activateSaved,game)
    if not ok then
      pcall(Randomizer.abortSavedActivation,game)
      mod.log:error("failed to %s saved randomizer seed: %s",context,tostring(active))
      return nil
    elseif not active then
      if err then mod.log:error("failed to %s saved randomizer seed: %s",context,tostring(err)) end
      return nil
    end
    syncLevelOptionMirror(game,active.cfg)
    return active
  end

  mod.events:on("game.ready",function(ev)
    local game=ev and (ev.game or ev) or mod.game
    if game then
      local ok,why=Randomizer.installGen1HardcodedBridges(game)
      if ok==false then mod.log:error("randomizer Gen 1 bridge unavailable: %s",tostring(why)) end
      local ok2,why2=Randomizer.installGen2EncounterBridges(game)
      if ok2==false then mod.log:error("randomizer Gen 2 encounter bridge unavailable: %s",tostring(why2)) end
    end
    if game then activateSaved(game,"activate") end
  end)

  mod.events:on("save.loaded",function(ev)
    local game=(ev and ev.game) or mod.game
    if game then activateSaved(game,"rebuild") end
  end)

  local pendingStartNotice
  -- Reconcile seeded route hints and level baselines after a map transition.
  mod.events:on("map.entered",function(ev)
    local game=(ev and ev.game) or mod.game
    if not game then return end
    local ok,why=pcall(Randomizer.onMapEntered,game,ev and ev.mapId,ev and ev.fromMapId)
    if not ok then mod.log:error("guided route map refresh failed: %s",tostring(why)) end
    pendingStartNotice=nil
    local a=Randomizer.active()
    local from=tostring(ev and ev.fromMapId or ""):gsub("_","")
    local to=tostring(ev and ev.mapId or ""):gsub("_","")
    local save=game.save or {}
    if a and a.generation==1 and a.cfg.random_start~="OFF" and not a.randomStartUsed
        and from=="OAKSLAB" and to=="PALLETTOWN" and #(save.party or {})>0
        and not ((save.flags or {}).EVENT_GOT_POKEDEX or save.pokedexReceived)
        and not mod.save:get("random_start_explained",false) then
      pendingStartNotice={game=game,active=a}
    end
  end,-50)
  mod.hooks:wrap("input.step",function(nextFn,game,dt)
    local out=nextFn(game,dt)
    local p=pendingStartNotice
    -- Wait for the fade/script to release the stack; never cover a native
    -- warp callback or eat its completion input with a new screen.
    if p and p.game.stack and p.game.stack.top and p.game.stack:top()==p.game.overworld then
      pendingStartNotice=nil
      if Randomizer.active()==p.active and not p.active.randomStartUsed then
        mod.save:set("random_start_explained",true)
        UI.openNotice(p.game,Randomizer.randomStartStatus(p.game),"Random Start is waiting")
      end
    end
    return out
  end)
  mod.events:on("save.loaded",function() pendingStartNotice=nil end)
  mod.events:on("world.blacked_out",function() pendingStartNotice=nil end)

  -- Deterministic seed hints belong on informational signs, never on arbitrary
  -- BGEVENT_READ scripts.  Gen 2 reports both ordinary town signs and things
  -- like Rocket switches as kind="sign"; opening our Hint screen immediately
  -- used to cover those progression scripts and could prevent the switch from
  -- receiving its YES/NO input.  Only pure text sign programs qualify, and the
  -- hint is deferred until the cartridge script has completed.
  local pendingSignHint = nil
  local function clearPendingSignHint() pendingSignHint=nil end
  mod.events:on("map.entered",clearPendingSignHint,-1000)
  mod.events:on("save.loaded",clearPendingSignHint,-1000)
  mod.events:on("world.blacked_out",clearPendingSignHint,-1000)
  local SAFE_SIGN_STD = { PokecenterSignScript=true, MartSignScript=true }
  local function gen2HintableSign(game, target)
    local key=target and target.scriptKey
    local scripts=game and game.world and game.world.scripts
    local rows=key and scripts and scripts[key]
    if type(rows)~="table" or #rows~=1 then return false end
    local row=rows[1] or {}
    if row.op=="jumptext" then return true end
    return row.op=="jumpstd" and SAFE_SIGN_STD[tostring(row.std)]==true
  end

  mod.events:on("world.interacted",function(ev)
    if not ev then return end
    if ev.kind~="sign" then return end
    local active=Randomizer.active()
    if not active then return end
    local game=mod.game or active.game
    local target=ev.target
    if game and game.world and game.world.scripts then
      -- Gold/Silver: conservatively reject any stateful/branching bg event.
      if not gen2HintableSign(game,target) then return end
      local text,tier=Randomizer.hintForSign(ev.mapId,ev.x,ev.y)
      if text then
        pendingSignHint={text=text,tier=tier,scriptKey=target and target.scriptKey,mapId=ev.mapId}
      end
      return
    end
    -- Gen 1 already distinguishes its sign arm from progression interactions.
    local text,tier=Randomizer.hintForSign(ev.mapId,ev.x,ev.y)
    if text then UI.openHint(game,text,tier) end
  end)

  mod.events:on("script.ended",function(ev)
    local p=pendingSignHint
    if not p then return end
    local ctx=ev and ev.ctx
    if not ev.completed or not ctx or ctx.generation~=2 then return end
    if p.scriptKey and ctx.scriptKey~=p.scriptKey then return end
    pendingSignHint=nil
    local active=Randomizer.active()
    local game=mod.game or (active and active.game)
    if game then UI.openHint(game,p.text,p.tier) end
  end)

  mod.hooks:wrap("ui.start_menu.items",function(nextFn,game,items)
    local out=nextFn(game,items)
    if type(out)~="table" then return out end
    -- Gen 1 Menu rows use onSelect; Gold's list rows use value and its main
    -- START menu hook normalizes mod rows with activate when present.
    out=mod.ui.insertBefore(out,"SAVE",{
      label="BUY HINT 5000",
      onSelect=function() UI.openBuyHint(game) end,
    })
    return mod.ui.insertBefore(out,"SAVE",{
      label="RANDO INFO",
      -- Keep this as a callback-only row. Gold's Gen2 StartMenu deliberately
      -- dispatches hook-added rows through onSelect only when value is nil; a
      -- synthetic value falls through to Game2:openStartMenuItem and does
      -- nothing. The same callback-only shape is native to Gen 1 as well.
      onSelect=function() UI.openInfo(game) end,
    })
  end)
end
