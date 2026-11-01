return function(mod, Core, Randomizer)
  local UI = {}
  local function helper(path)
    local source,err=mod:read(path);assert(source,err or path)
    return assert(load(source,"@"..mod.path.."/"..path))()
  end
  local Menu=helper("menu.lua")
  local Help=helper("settings_help.lua")
  local WILDS="UniversalRandomizerWildSettings"
  local CONFIRM="UniversalRandomizerConfirmVanilla"
  local NOTICE="UniversalRandomizerNotice"
  local SETUP = "UniversalRandomizerSetup"
  local POKEMON = "UniversalRandomizerPokemonSettings"
  local BATTLE = "UniversalRandomizerBattleSettings"
  local WORLD = "UniversalRandomizerWorldSettings"
  local RUN = "UniversalRandomizerRunSettings"
  local INFO = "UniversalRandomizerInfo"
  local SEED = "UniversalRandomizerSeed"
  local BST = "UniversalRandomizerBst"
  local HINT = "UniversalRandomizerHint"
  local BUY_HINT = "UniversalRandomizerBuyHint"

  local pendingValidation = nil
  mod.hooks:wrap("input.step",function(nextFn,game,dt)
    local out=nextFn(game,dt)
    local p=pendingValidation
    if p then
      local okStep,st=pcall(Randomizer.stepGenerate,p.handle)
      if not okStep then
        pendingValidation=nil
        local why="validation runtime error: "..tostring(st)
        if p.onDone then
          local okDone,doneErr=pcall(p.onDone,nil,why,1)
          if not okDone then mod.log:error("validation completion callback failed: %s",tostring(doneErr)) end
        else
          mod.log:error("%s",why)
        end
      else
        if p.onProgress then
          local okProgress,progressErr=pcall(p.onProgress,st)
          if not okProgress then mod.log:error("validation progress callback failed: %s",tostring(progressErr)) end
        end
        if st and st.done then
          pendingValidation=nil
          if p.onDone then
            local okDone,doneErr=pcall(p.onDone,st.active,st.error,1)
            if not okDone then mod.log:error("validation completion callback failed: %s",tostring(doneErr)) end
          end
        end
      end
    end
    return out
  end)

  local CHOICES = {
    safety = { "SAFE", "CHAOS" },
    bst_match = { false, true },
    base_stats = { "UNCHANGED", "SHUFFLE", "RANDOM" },
    types = { "UNCHANGED", "FOLLOW_EVOS", "RANDOM" },
    evolutions = { "UNCHANGED", "RANDOM" },
    impossible_evos = { false, true },
    starters = { "UNCHANGED", "RANDOM", "TWO_EVOS" },
    rival_starter = { false, true },
    movesets = { "UNCHANGED", "TYPE_BIAS", "RANDOM" },
    trainers = { "UNCHANGED", "RANDOM", "SIMILAR", "TYPE_THEMED" },
    wild_randomness = { "BALANCED", "UNRESTRICTED" },
    wild_evolution = { "AS_ROLLED", "LEVEL" },
    area_encounters = { "VANILLA", "HIGH_VARIETY", "AREA_POOL", "CHAOS_POOL", "FULL_SLOT_RANDOM" },
    extra_species = { 0, 1, 2, 3, 4, 5 },
    statics = { "UNCHANGED", "RANDOM", "SIMILAR" },
    tms = { "UNCHANGED", "RANDOM" },
    tm_compat = { "UNCHANGED", "TYPE_BIAS", "RANDOM", "FULL" },
    field_items = { "UNCHANGED", "SHUFFLE", "RANDOM", "LOGIC_RANDOM", "CHAOS" },
    gift_items = { "UNCHANGED", "RANDOM" },
    progression_items = { false, true },
    random_start = { "OFF", "LOGIC", "CHAOS" },
    badges = { "VANILLA", "SAFE", "CHAOS" },
    trainer_ai = { "NORMAL", "STRONG" },
    boss_ai = { "NORMAL", "STRONG" },
    pc_item = { false, true },
    marts = { "VANILLA", "SAFE", "CHAOS" },
    mart_safety = { false, true },
    allow_legendaries = { false, true },
    trades = { "UNCHANGED", "GIVEN", "BOTH" },
    seed_mode = { "AUTO", "MANUAL" },
  }
  local LEVELS = { -50, -40, -30, -20, -10, 0, 10, 20, 30, 40, 50 }

  local LABELS = {
    wild_randomness="Wild Pokemon",wild_evolution="Wild evolution",bst_match="BST limit",bst_difference="BST difference",
    safety="Progression safety",base_stats="Base stats",types="Pokemon types",evolutions="Evolution targets",
    starters="Starters",rival_starter="Rival starter",impossible_evos="Trade evolutions",movesets="Learnsets",
    trainers="Trainers",area_encounters="Encounter layout",extra_species="Extra species",statics="Fixed / gift Pokemon",
    tms="TM moves",tm_compat="TM/HM learning",field_items="Field items",gift_items="NPC item gifts",progression_items="Keys + HMs",
    pc_item="Bedroom PC item",marts="Shop inventory",mart_safety="Shop essentials",trades="NPC trades",badges="Gym badges",
    allow_legendaries="Legendaries",trainer_levels="Trainer levels",boss_levels="Boss levels",wild_levels="Wild levels",
    trainer_ai="Trainer AI",boss_ai="Boss AI",random_start="Random Start",seed_mode="Seed mode",manual_seed="Edit manual seed",
  }
  local DISPLAY = {
    UNCHANGED="Unchanged",VANILLA="Vanilla",FOLLOW_EVOS="Evolution linked",TWO_EVOS="Two evolutions",
    TYPE_BIAS="Type bias",TYPE_THEMED="Type themed",SHUFFLE="Shuffle",RANDOM="Random",SIMILAR="Similar strength",FULL="Full",
    SAFE="Safe",CHAOS="Chaos",NORMAL="Normal",STRONG="Strong",AUTO="Auto",MANUAL="Manual",GIVEN="Given",BOTH="Both",
    OFF="Off",LOGIC="Logic",HIGH_VARIETY="Variety",AREA_POOL="Area pool",CHAOS_POOL="Legacy chaos pool",FULL_SLOT_RANDOM="Slot by slot",
    LOGIC_RANDOM="Logical random",BALANCED="Balanced",UNRESTRICTED="Truly random",AS_ROLLED="As rolled",LEVEL="Match level",LEGACY="Legacy run",
  }


  local GROUPS = {
    [WILDS] = {title="Wild encounters",order={"wild_randomness","area_encounters","extra_species","wild_evolution","allow_legendaries","wild_levels","bst_match","bst_difference"}},
    [POKEMON] = {
      title = "Pokemon",
      order = { "bst_match", "bst_difference", "base_stats", "types", "evolutions", "impossible_evos", "starters", "rival_starter", "movesets", "allow_legendaries" },
    },
    [BATTLE] = {
      title = "Battles",
      order = { "trainers", "trainer_levels", "boss_levels", "trainer_ai", "boss_ai", "statics", "tms", "tm_compat" },
    },
    [WORLD] = {
      title = "World + items",
      order = { "random_start", "field_items", "gift_items", "progression_items", "pc_item", "marts", "mart_safety", "trades", "badges" },
    },
    [RUN] = {
      title = "Safety + seed",
      order = { "safety", "seed_mode", "manual_seed" },
    },
  }

  local function pretty(key,v)
    if type(v)=="number" and (key=="trainer_levels" or key=="boss_levels" or key=="wild_levels") then return (v>0 and "+" or "")..tostring(v).."%" end
    if type(v)=="number" and key=="extra_species" then return v==0 and "Off" or tostring(v) end
    if type(v)=="boolean" then
      if key=="allow_legendaries" then return v and "Allow" or "Block" end
      return v and "On" or "Off"
    end
    local raw=tostring(v)
    return DISPLAY[raw] or raw:gsub("_"," ")
  end

  local function settingRow(key,v)
    if key=="manual_seed" then return LABELS.manual_seed end
    if key=="random_start" and v=="LOGIC" then return "RANDOM START: LOGIC/BADGES" end
    return (LABELS[key] or key:upper())..": "..pretty(key,v)
  end

  -- World Settings has three route controls whose full labels can cross the
  -- legacy Gen-1 text clip even while the menu owns the 16:9 surface. Keep
  -- their values visible with compact labels; config keys/behavior are unchanged.
  local function worldSettingRow(key,v)
    if key=="badges" then return "BADGES: "..pretty(key,v) end
    if key=="random_start" then return "START: "..pretty(key,v) end
    return settingRow(key,v)
  end


  local function cycle(cfg,key,dir)
    local list=CHOICES[key]
    if not list then return end
    -- Logic starts need a graph-based item plan. Cycle only the supported
    -- choices instead of selecting an ordinary mode and silently undoing it.
    if key=="field_items" and cfg.random_start=="LOGIC" then list={"LOGIC_RANDOM","CHAOS"} end
    local cur=cfg[key]
    local pos=1
    for i,v in ipairs(list) do if v==cur then pos=i break end end
    cfg[key]=list[((pos-1+(dir or 1)) % #list)+1]
    if key=="wild_randomness" and cfg[key]=="UNRESTRICTED" then cfg.wild_evolution="AS_ROLLED" end
    if key=="random_start" and cfg[key]=="LOGIC" then
      cfg.safety="SAFE"; cfg.badges="SAFE"; cfg.field_items="LOGIC_RANDOM"; cfg.progression_items=true
    end
    -- The explicitly selected mode takes precedence over the previous safety
    -- value. Otherwise visiting Chaos makes Logical random disappear forever
    -- on subsequent laps through the list.
    if key=="field_items" then
      if cfg[key]=="LOGIC_RANDOM" then cfg.safety="SAFE"
      elseif cfg[key]=="CHAOS" then cfg.safety="CHAOS" end
    end
    if cfg.random_start=="LOGIC" or cfg.field_items=="LOGIC_RANDOM" or cfg.field_items=="CHAOS" then
      cfg.field_items=cfg.safety=="CHAOS" and "CHAOS" or "LOGIC_RANDOM"
      cfg.progression_items=true
    end
  end

  local function cycleLevel(cfg,key,dir)
    key=key or "trainer_levels"
    local pos=1
    for i,v in ipairs(LEVELS) do if v==cfg[key] then pos=i break end end
    cfg[key]=LEVELS[((pos-1+(dir or 1)) % #LEVELS)+1]
  end

  local function closeMenu(menu)
    if menu and menu.close then menu:close() end
  end

  local function tuneRandoMenu(menu) return menu end
  local function widen(menu) return menu end
  local function cartridge(game)
    local GV=require("src.core.GameVersion")
    return tostring(GV.get()):upper().." / native "..(GV.generation(GV.get())==2 and "251" or "151")
  end

  mod.content.screens:register(CONFIRM, {new=function(game,opts)
    return Menu.new(game,"Play without randomizer?",{
      {label="Keep configuring",value="keep",help="Return to your settings. Nothing is disabled."},
      {label="Play vanilla",value="vanilla",help="Disable this randomizer for the new run, including Random Start. Your preferred settings remain available next time."},
    },{onChoose=function(item,m)
      m:close();if item.value=="vanilla" then opts.onConfirm() end
    end})
  end})
  mod.content.screens:register(NOTICE, {new=function(game,opts)
    return Menu.new(game,opts.title or "Random Start",{{label="Continue",value="close",help=opts.text,helpTitle="Next step"}},
      {subtitle=cartridge(game),onChoose=function(_,m) m:close() end})
  end})

  mod.content.screens:register(SEED, {
    new=function(game,opts)
      opts=opts or {}
      local n=math.max(1,math.min(2147483646,math.floor(tonumber(opts.value) or 1)))
      local text=("%010d"):format(n)
      local digits={}
      for i=1,10 do digits[i]=tonumber(text:sub(i,i)) or 0 end
      local menu
      local function rebuild()
        local items={}
        for i=1,10 do items[#items+1]={label=("DIGIT %02d: %d"):format(i,digits[i]),value=i} end
        items[#items+1]={label="SAVE SEED",value="save"}
        menu.items=items
      end
      menu=tuneRandoMenu(Menu.new(game,"MANUAL SEED",{}, {
        wrap=true,pageJump=true,keyRepeat=true,
        onChoose=function(item,m)
          if item.value=="save" then
            local s=""; for i=1,10 do s=s..digits[i] end
            local value=tonumber(s) or 1
            value=math.max(1,math.min(2147483646,value))
            closeMenu(m); if opts.onDone then opts.onDone(value) end
          else
            local i=item.value; digits[i]=(digits[i]+1)%10; rebuild()
          end
        end,
        help=Help.describe("manual_seed",{},game,Randomizer),
        onAdjust=function(item,m,dir)
          if type(item.value)=="number" then digits[item.value]=(digits[item.value]+dir)%10; rebuild() end
        end,
      }))
      rebuild()
      return menu
    end,
  })

  mod.content.screens:register(BST, {
    new=function(game,opts)
      opts=opts or {}
      local value=math.max(0,math.min(500,math.floor(tonumber(opts.value) or 50)))
      local menu
      local function rebuild()
        menu.title="BST DIFFERENCE: "..value
        menu.items={
          {label="+1",value=1},{label="-1",value=-1},
          {label="+10",value=10},{label="-10",value=-10},
          {label="+50",value=50},{label="-50",value=-50},
          {label="SAVE",value="save"},
        }
      end
      menu=widen(tuneRandoMenu(Menu.new(game,"BST DIFFERENCE",{}, {
        wrap=true,pageJump=true,keyRepeat=true,
        onChoose=function(item,m)
          if item.value=="save" then
            closeMenu(m); if opts.onDone then opts.onDone(value) end
          else value=math.max(0,math.min(500,value+item.value)); rebuild() end
        end,
      })))
      menu.footer=Help.describe("bst_difference",{},game,Randomizer)
      rebuild(); return menu
    end,
  })

  local function registerGroup(id, spec)
    mod.content.screens:register(id, {
      new=function(game,opts)
        opts=opts or {}
        local cfg=assert(opts.cfg,"randomizer settings missing")
        local menu
        local function rebuild()
          local items={}
          for _,key in ipairs(spec.order) do
            local gen2=game and game.data and game.data.gen2Encounters~=nil
            local supported=(key~="pc_item" or not gen2)
            if id==WILDS and cfg.wild_randomness=="UNRESTRICTED" and (key=="wild_evolution" or key=="bst_match" or key=="bst_difference") then supported=false end
            if key=="bst_difference" and not cfg.bst_match then supported=false end
            if supported and (key~="manual_seed" or cfg.seed_mode=="MANUAL") then
              items[#items+1]={label=LABELS[key],right=key~="manual_seed" and pretty(key,cfg[key]) or "Edit",value=key,helpTitle=LABELS[key]..": "..pretty(key,cfg[key]),help=Help.describe(key,cfg,game,Randomizer)}
            end
          end
          items[#items+1]={label="Back",value="back",help="Return to setup. Your changes are kept until you begin or choose vanilla."}
          menu.items=items
        end
        menu=widen(tuneRandoMenu(Menu.new(game,spec.title,{}, {
          wrap=true,pageJump=true,keyRepeat=true,
          subtitle=cartridge(game),
          onAdjust=function(item,m,dir)
            local key=item.value
            if key=="trainer_levels" or key=="boss_levels" or key=="wild_levels" then cycleLevel(cfg,key,dir)
            elseif CHOICES[key] then cycle(cfg,key,dir)
            elseif key=="bst_difference" then cfg.bst_difference=math.max(0,math.min(500,cfg.bst_difference+dir)) end
            rebuild()
          end,
          onChoose=function(item,m)
            local key=item.value
            if key=="back" then closeMenu(m)
            elseif key=="trainer_levels" or key=="boss_levels" or key=="wild_levels" then cycleLevel(cfg,key); rebuild()
            elseif key=="bst_difference" then
              mod.ui.push(game,BST,{value=cfg.bst_difference,onDone=function(v) cfg.bst_difference=v; rebuild() end})
            elseif key=="manual_seed" then
              mod.ui.push(game,SEED,{value=cfg.manual_seed,onDone=function(v) cfg.manual_seed=v; rebuild() end})
            elseif CHOICES[key] then cycle(cfg,key); rebuild()
            end
          end,
        })))
        rebuild()
        return menu
      end,
    })
  end

  for id,spec in pairs(GROUPS) do registerGroup(id,spec) end

  mod.content.screens:register(SETUP, {
    new=function(game,opts)
      opts=opts or {}
      local cfg=Randomizer.defaults(game)
      local stored=mod.save:get("last_config",nil)
      if type(stored)=="table" then
        cfg=Randomizer.normalizedConfig(stored,game)
      end
      -- A fresh run uses the fixed badge planner even when preferences came
      -- from an older save. Continue retains its saved policy separately.
      cfg.badge_logic="CHECKED"
      if cfg.wild_randomness=="LEGACY" then
        cfg.wild_randomness=(cfg.safety=="CHAOS" or cfg.area_encounters=="CHAOS_POOL" or cfg.area_encounters=="FULL_SLOT_RANDOM") and "UNRESTRICTED" or "BALANCED"
        cfg.wild_evolution="AS_ROLLED"
      end
      local status="SELECT SETTINGS"
      local retryAttempt=0
      local validating=false
      local validationStage=0
      local validationTotal=14
      local validationError
      local menu
      local function rebuild()
        menu.items={
          {label="Pokemon",value="pokemon",right="Configure",help="Starters, stats, types, evolution targets, learnsets and BST matching. For balanced versus fully random route Pokemon, open Wild encounters."},
          {label="Wild encounters",value="wilds",right=function() return cfg.area_encounters=="VANILLA" and "Vanilla" or pretty("wild_randomness",cfg.wild_randomness) end,help="Choose Balanced or Truly random wild Pokemon, encounter layout, extra species, legendaries and wild levels. SAFE progression is a separate setting."},
          {label="Battles",value="battle",right="Configure",help="Trainer Pokemon, ordinary and boss levels, AI, fixed Pokemon and TMs."},
          {label="World + items",value="world",right=function() return "Start: "..pretty("random_start",cfg.random_start) end,help="Random Start, items, HMs, key items, shops and badges. "..Randomizer.randomStartStatus(game,cfg)},
          {label="Safety + seed",value="run",right=function() return pretty("safety",cfg.safety) end,help="SAFE checks supported progression; CHAOS allows locks. Neither silently changes the Wild Pokemon balance option."},
          {label=validating and "Validating..." or (retryAttempt>0 and "Retry validation" or "Validate + begin"),value="begin",right=function() return validating and (validationStage.." / "..validationTotal) or "Start run" end,help=validationError or ("Generate with these settings. Wild Pokemon: "..pretty("wild_randomness",cfg.wild_randomness)..". Progression: "..pretty("safety",cfg.safety)..". Random Start: "..pretty("random_start",cfg.random_start)..".\n\n"..Randomizer.randomStartStatus(game,cfg))},
          {label="Play vanilla",value="cancel",help="Ask before starting without the randomizer. Random Start and all randomization are disabled only after confirmation."},
        }
        menu.title=validating and status or "New run setup"
      end
      local function finishVanilla(m)
        Randomizer.clear(game)
        mod.save:set("last_config",Core.copy(cfg))
        closeMenu(m)
        if opts.onDone then opts.onDone(false) end
      end
      local function askVanilla()
        mod.ui.push(game,CONFIRM,{onConfirm=function() finishVanilla(menu) end})
      end
      menu=widen(tuneRandoMenu(Menu.new(game,"RANDO SETUP",{}, {
        wrap=true,pageJump=true,keyRepeat=true,
        subtitle=function() return cartridge(game) end,
        locked=function() return validating end,
        onChoose=function(item,m)
          -- 1.3.32: validation is frame-staged. Re-entering VALIDATE + BEGIN
          -- while it is running replaces the active handle and restarts at
          -- stage zero. A held/touch A press could therefore create an endless
          -- "Seed attempt 121..." loop that looked like the game had frozen.
          -- Freeze this setup menu until the one active validation finishes.
          if validating then return end
          local key=item.value
          if key=="pokemon" then mod.ui.push(game,POKEMON,{cfg=cfg})
          elseif key=="wilds" then mod.ui.push(game,WILDS,{cfg=cfg})
          elseif key=="battle" then mod.ui.push(game,BATTLE,{cfg=cfg})
          elseif key=="world" then mod.ui.push(game,WORLD,{cfg=cfg})
          elseif key=="run" then mod.ui.push(game,RUN,{cfg=cfg})
          elseif key=="begin" then
            validating=true; validationStage=0
            status="PREFLIGHT..."; validationError=nil; rebuild()
            local preOk,preflight,why,normalized=pcall(Randomizer.preflight,game,cfg)
            if not preOk then
              validating=false
              status="PREFLIGHT ERROR"
              mod.save:set("last_error",tostring(preflight))
              validationError="Validation error: "..tostring(preflight)
              rebuild()
              return
            end
            if not preflight then
              validating=false
              status="PREFLIGHT FAIL"
              mod.save:set("last_error",tostring(why))
              validationError=tostring(why)
              rebuild()
              return
            end
            cfg=normalized
            retryAttempt=retryAttempt+1
            status=(cfg.seed_mode=="MANUAL") and "VALIDATING MANUAL..." or ("SEED ATTEMPT "..tostring(retryAttempt).."...")
            rebuild()
            local requested=(cfg.seed_mode=="MANUAL") and cfg.manual_seed or nil
            local handle,err=Randomizer.beginGenerate(game,cfg,requested)
            if not handle then
              validating=false
              status=(cfg.seed_mode=="MANUAL") and "MANUAL SEED FAIL" or ("ATTEMPT "..tostring(retryAttempt).." FAILED")
              mod.save:set("last_error",tostring(err))
              validationError=tostring(err); rebuild(); return
            end
            status="VALIDATING: READY"; rebuild()
            pendingValidation={
              handle=handle,
              onProgress=function(st)
                if not st then return end
                validationStage=math.max(0,math.min(validationTotal,tonumber(st.stage) or validationStage))
                status="VALIDATING: "..tostring(st.label or "...")
                -- Keep validation progress in the full-width title/row. The
                -- old 96px right footer reduced stage names to stray-looking
                -- fragments on mobile/Gen 2 and encouraged players to press A
                -- again, which restarted validation.
                validationError=nil
                rebuild()
              end,
              onDone=function(active,genErr,attempts)
                validating=false
                validationStage=0
                if active then
                  local commitCallOk,committed,commitErr=pcall(Randomizer.commit,active)
                  if not commitCallOk then commitErr=committed; committed=false end
                  if not committed then
                    Randomizer.clear(game); status="COMMIT FAIL"
                    mod.save:set("last_error",tostring(commitErr)); validationError=tostring(commitErr); rebuild(); return
                  end
                  mod.save:set("last_config",Core.copy(cfg))
                  mod.save:set("validation_attempts",attempts or 1)
                  mod.save:set("last_error",nil)
                  status="PASS "..active.fingerprint
                  closeMenu(m)
                  if opts.onDone then opts.onDone(true,active) end
                else
                  status=(cfg.seed_mode=="MANUAL") and "MANUAL SEED FAIL" or ("ATTEMPT "..tostring(retryAttempt).." FAILED")
                  mod.save:set("last_error",tostring(genErr))
                  if cfg.seed_mode=="MANUAL" then validationError="Manual seed rejected: "..tostring(genErr)
                  else validationError="Press VALIDATE AGAIN for a new seed. "..tostring(genErr) end
                  rebuild()
                end
              end,
            }
          elseif key=="cancel" then askVanilla()
          end
        end,
        onCancel=function()
          if validating then return end
          askVanilla()
        end,
      })))
      local summaryKey
      menu.refresh=function()
        local key=table.concat({cfg.wild_randomness,cfg.random_start,cfg.area_encounters,cfg.safety},"|")
        if key~=summaryKey then summaryKey=key;rebuild() end
      end
      rebuild()
      return menu
    end,
  })

  mod.content.screens:register(BUY_HINT, {
    new=function(game)
      local function money()
        if game.save and game.save.player and game.save.player.money~=nil then return tonumber(game.save.player.money) or 0 end
        return tonumber(game.save and game.save.money) or 0
      end
      local menu
      local function rebuild(note)
        menu.items={
          {label="ONE RANDOM ANSWER"},
          {label="COST: 5000"},
          {label="MONEY: "..tostring(money())},
          {label="BUY",value="buy"},
          {label="CANCEL",value="cancel"},
        }
        menu.footer=note
      end
      menu=tuneRandoMenu(Menu.new(game,"BUY RANDO HINT",{}, {
        wrap=true,
        onChoose=function(item,m)
          if item.value=="cancel" then closeMenu(m); return end
          if item.value=="buy" then
            local text,err,tier=Randomizer.buyHint(game)
            if not text then rebuild(tostring(err)); return end
            closeMenu(m)
            mod.ui.push(game,HINT,{text=text,tier=tier})
          end
        end,
        onCancel=function(m) closeMenu(m) end,
      }))
      rebuild("Mostly medium/strong. Trash can happen.")
      return menu
    end,
  })

  mod.content.screens:register(HINT, {
    new=function(game,opts)
      opts=opts or {}
      local text=tostring(opts.text or "No hint available.")
      local tier=tostring(opts.tier or ""):upper()
      return Menu.new(game,"Randomizer hint",{{label="Close",value="close",help=text,helpTitle=tier~="" and ("Answer: "..tier) or "Your hint"}},
        {onChoose=function(_,m) m:close() end})
    end,
  })

  mod.content.screens:register(INFO, {
    new=function(game)
      local seed=mod.save:get("seed",nil)
      local cfg=Randomizer.normalizedConfig(mod.save:get("config",{}),game)
      local items={}
      if not seed then
        items[1]={label="VANILLA - NO SEED"}
      else
        items[#items+1]={label="SEED: "..tostring(seed)}
        items[#items+1]={label="FP: "..tostring(mod.save:get("fingerprint","?"))}
        items[#items+1]={label="Random Start",right=pretty("random_start",cfg.random_start),help=Randomizer.randomStartStatus(game,cfg)}
        items[#items+1]={label="Safety",right=pretty("safety",cfg.safety),help=Help.describe("safety",cfg,game,Randomizer)}
        local active=Randomizer.active()
        local plan=active and active.itemPlan
        if plan and plan.proof then
          items[#items+1]={label=plan.proof.checked and "KEY/HM LOGIC: PASS" or "KEY/HM LOGIC: CHAOS"}
          items[#items+1]={label="MOVED REWARDS: "..tostring(plan.changed or 0)}
        end
        items[#items+1]={label="TRIES: "..tostring(mod.save:get("validation_attempts",1))}
        local code=Randomizer.runCode and Randomizer.runCode() or nil
        if code then items[#items+1]={label="RUN CODE: "..code}; items[#items+1]={label="COPY RUN CODE",value="copy"} end
        local keys={"bst_match","bst_difference","base_stats","types","evolutions","impossible_evos","starters","rival_starter","movesets","trainers","area_encounters","wild_randomness","wild_evolution","extra_species","statics","tms","tm_compat","field_items","gift_items","progression_items","pc_item","marts","mart_safety","trades","badges","random_start","allow_legendaries","trainer_levels","boss_levels","wild_levels","trainer_ai","boss_ai"}
        for _,k in ipairs(keys) do items[#items+1]={label=LABELS[k],right=pretty(k,cfg[k]),help=Help.describe(k,cfg,game,Randomizer)} end
        local pc=mod.save:get("pc_start_item",nil)
        if pc then items[#items+1]={label="PC START: "..tostring(pc):gsub("_"," ")} end
      end
      return widen(tuneRandoMenu(Menu.new(game,"RANDO INFO",items,{pageJump=true,wrap=true,onChoose=function(item,m)
        if item and item.value=="copy" then
          local code=Randomizer.runCode and Randomizer.runCode()
          local ok=code and love and love.system and love.system.setClipboardText and pcall(love.system.setClipboardText,code)
          m.footer=ok and "RUN CODE COPIED" or "Clipboard unavailable; run code is shown above."
        end
      end})))
    end,
  })

  function UI.openSetup(game,onDone)
    mod.ui.push(game,SETUP,{onDone=onDone})
  end
  function UI.openInfo(game) mod.ui.push(game,INFO) end
  function UI.openHint(game,text,tier) mod.ui.push(game,HINT,{text=text,tier=tier}) end
  function UI.openBuyHint(game) mod.ui.push(game,BUY_HINT) end
  UI.SETUP,UI.INFO,UI.SEED,UI.HINT,UI.BUY_HINT=SETUP,INFO,SEED,HINT,BUY_HINT
  function UI.openNotice(game,text,title) mod.ui.push(game,NOTICE,{text=text,title=title}) end
  UI.POKEMON,UI.BATTLE,UI.WORLD,UI.RUN,UI.WILDS=POKEMON,BATTLE,WORLD,RUN,WILDS
  return UI
end
