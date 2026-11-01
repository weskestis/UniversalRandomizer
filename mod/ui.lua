return function(mod, Core, Randomizer)
  local UI = {}
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
    ruleset = { "GEN1", "GEN2", "GEN3", "GEN4" },
    pokedex = { "NATIVE", "G1", "G1_2", "G1_3", "G1_4" },
    bst_match = { false, true },
    base_stats = { "UNCHANGED", "SHUFFLE", "RANDOM" },
    types = { "UNCHANGED", "FOLLOW_EVOS", "RANDOM" },
    evolutions = { "UNCHANGED", "RANDOM" },
    impossible_evos = { false, true },
    starters = { "UNCHANGED", "RANDOM", "TWO_EVOS" },
    rival_starter = { false, true },
    movesets = { "UNCHANGED", "TYPE_BIAS", "RANDOM" },
    trainers = { "UNCHANGED", "RANDOM", "SIMILAR", "TYPE_THEMED" },
    area_encounters = { "VANILLA", "HIGH_VARIETY", "AREA_POOL", "CHAOS_POOL", "FULL_SLOT_RANDOM" },
    extra_species = { 0, 1, 2, 3, 4, 5 },
    statics = { "UNCHANGED", "RANDOM", "SIMILAR" },
    tms = { "UNCHANGED", "RANDOM" },
    tm_compat = { "UNCHANGED", "TYPE_BIAS", "RANDOM", "FULL" },
    field_items = { "UNCHANGED", "SHUFFLE", "RANDOM" },
    gift_items = { "UNCHANGED", "RANDOM" },
    progression_items = { false, true },
    random_start = { "OFF", "LOGIC", "CHAOS" },
    badges = { "VANILLA", "SAFE", "CHAOS" },
    abilities = { "NORMAL", "SAFE", "CHAOS" },
    random_natures = { false, true },
    trainer_ai = { "NORMAL", "STRONG" },
    boss_ai = { "NORMAL", "STRONG" },
    pc_item = { false, true },
    marts = { "VANILLA", "SAFE", "CHAOS" },
    mart_safety = { false, true },
    protection_guards = { true, false },
    allow_legendaries = { false, true },
    trades = { "UNCHANGED", "GIVEN", "BOTH" },
    level_mode = { "PROGRESSION", "PERCENTAGE", "HYBRID" },
    seed_mode = { "AUTO", "MANUAL" },
  }
  local LEVELS = { -50, -40, -30, -20, -10, 0, 10, 20, 30, 40, 50 }

  -- Compact native-160px labels.  Settings rows are rendered as ONE string
  -- instead of ListMenu's independent left/right columns, so values can never
  -- overprint their labels on the Game Boy-width canvas.
  local LABELS = {
    bst_match="BST MATCH", bst_difference="BST DIFFERENCE", gift_items="GIFT ITEMS", progression_items="KEYS + HMS",
    safety="SAFETY", ruleset="RULESET", pokedex="POKEDEX", base_stats="STATS", types="TYPES", evolutions="EVOS",
    starters="STARTER", rival_starter="RIVAL START", impossible_evos="TRADE EVOS",
    movesets="MOVES", trainers="TRAINER", area_encounters="AREA MODE", extra_species="EXTRA/AREA", statics="GIFTS",
    tms="TM MOVES", tm_compat="TM/HM", field_items="ITEMS", pc_item="PC ITEM", marts="MARTS", mart_safety="MART SAFETY", protection_guards="PROTECTION GUARDS", trades="TRADES",
    allow_legendaries="LEGENDS", level_mode="LEVEL MODE", trainer_levels="TRAINER LEVEL", boss_levels="BOSS LEVEL", wild_levels="WILD LEVEL", trainer_ai="TRAINER AI", boss_ai="BOSS AI", random_start="RANDOM START", badges="RANDOM BADGES", abilities="ABILITIES", random_natures="NATURES", seed_mode="SEED",
    manual_seed="EDIT MANUAL SEED",
  }

  local DISPLAY = {
    UNCHANGED="VANILLA", FOLLOW_EVOS="EVO LINK", TWO_EVOS="2 EVOS",
    TYPE_BIAS="TYPE BIAS", TYPE_THEMED="THEMED",
    SHUFFLE="SHUFFLE", RANDOM="RANDOM", SIMILAR="SIMILAR", FULL="FULL",
    SAFE="SAFE", CHAOS="CHAOS", NORMAL="NORMAL", AUTO="AUTO", MANUAL="MANUAL",
    PROGRESSION="PROGRESSION", PERCENTAGE="PERCENTAGE", HYBRID="HYBRID",
    GIVEN="GIVEN", BOTH="BOTH", OFF="OFF", LOGIC="LOGIC",
    NATIVE="NATIVE", G1="GEN 1", G1_2="GEN 1-2", G1_3="GEN 1-3", G1_4="GEN 1-4",
    GEN1="GEN 1", GEN2="GEN 2", GEN3="GEN 3", GEN4="GEN 4",
    HIGH_VARIETY="HI VARIETY", AREA_POOL="AREA POOL", CHAOS_POOL="CHAOS POOL", FULL_SLOT_RANDOM="FULL SLOT",
  }


  local GROUPS = {
    [POKEMON] = {
      title = "POKEMON SETTINGS",
      order = { "pokedex", "bst_match", "bst_difference", "base_stats", "types", "evolutions", "impossible_evos", "starters", "rival_starter", "movesets", "abilities", "random_natures", "allow_legendaries" },
    },
    [BATTLE] = {
      title = "BATTLE SETTINGS",
      order = { "ruleset", "level_mode", "trainers", "trainer_levels", "boss_levels", "trainer_ai", "boss_ai", "area_encounters", "wild_levels", "extra_species", "statics", "tms", "tm_compat" },
    },
    [WORLD] = {
      title = "WORLD SETTINGS",
      order = { "field_items", "gift_items", "progression_items", "pc_item", "marts", "mart_safety", "trades", "badges", "random_start", "protection_guards" },
    },
    [RUN] = {
      title = "SAFETY + SEED",
      order = { "safety", "seed_mode", "manual_seed" },
    },
  }

  local function pretty(key,v)
    if type(v)=="number" and (key=="trainer_levels" or key=="boss_levels" or key=="wild_levels") then return tostring(v).." PCT" end
    if type(v)=="number" and key=="extra_species" then return v==0 and "OFF" or tostring(v) end
    if type(v)=="boolean" then
      if key=="allow_legendaries" then return v and "ALLOW" or "BLOCK" end
      return v and "ON" or "OFF"
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
    if key=="protection_guards" then return "GUARDS: "..pretty(key,v) end
    return settingRow(key,v)
  end


  local function cycle(cfg,key)
    local list=CHOICES[key]
    if not list then return end
    local cur=cfg[key]
    local pos=1
    for i,v in ipairs(list) do if v==cur then pos=i break end end
    cfg[key]=list[(pos % #list)+1]
    if key=="random_start" and cfg[key]=="LOGIC" and cfg.badges=="VANILLA" then cfg.badges="SAFE" end
  end

  local function cycleLevel(cfg,key)
    key=key or "trainer_levels"
    local pos=1
    for i,v in ipairs(LEVELS) do if v==cfg[key] then pos=i break end end
    cfg[key]=LEVELS[(pos % #LEVELS)+1]
  end

  local function closeMenu(menu)
    if menu and menu.close then menu:close() end
  end

  -- The launcher/game speed option can make frame-based key repeat feel twice
  -- as fast. Force this mod's own setup screens to a calmer cadence AFTER
  -- ListMenu construction, so a global ui.list_menu hook cannot accelerate it.
  local function tuneRandoMenu(menu)
    if menu then
      menu.repeatDelay=32
      menu.repeatRate=8
    end
    return menu
  end

  -- Pixel-accurate clipping/wrapping for the host font. Settings and
  -- validation errors can contain variable-width or multi-byte glyphs, so
  -- character-count wrapping is not sufficient on the 304px setup surface.
  local function fitText(Font, text, budget)
    text=tostring(text or "")
    if budget<=0 or text=="" then return "" end
    if Font.width(text)<=budget then return text end
    local suffix="..."
    local spans=Font.split(text)
    local fit=Font.spansFitting(spans,math.max(0,budget-Font.width(suffix)))
    if fit<=0 then return "" end
    return text:sub(1,spans[fit].to)..suffix
  end

  local function drawWrapped(Font, text, x, y, width, bottom)
    local line=""
    for word in tostring(text or ""):gmatch("%S+") do
      local candidate=(line=="") and word or (line.." "..word)
      if Font.width(candidate)<=width then
        line=candidate
      else
        if line~="" and y<=bottom then Font.draw(fitText(Font,line,width),x,y); y=y+10 end
        line=word
        if y>bottom then break end
        -- Long unbroken tokens (hashes/errors) are clipped rather than drawn
        -- through the edge of the status pane.
        if Font.width(line)>width then
          Font.draw(fitText(Font,line,width),x,y); y=y+10; line=""
        end
      end
    end
    if line~="" and y<=bottom then Font.draw(fitText(Font,line,width),x,y) end
  end

  -- Native 16:9 settings surface.  Gen 1 honors uiSize(), but Gen 2's
  -- Game2 compositor intentionally keeps ordinary stack states on the classic
  -- 160x144 canvas unless they opt into drawsWidescreen/drawWidescreen.  The
  -- 1.3.26 menu only widened its draw coordinates, so Crystal/Gold/Silver
  -- still clipped every row at x=160 (for example PERCENTAGE -> PERCEN and
  -- -50% -> just '-').  Give every Randomizer settings/info ListMenu a real
  -- 256x144 16:9 surface and an explicit Gen-2 widescreen owner path.
  local WIDE_W,WIDE_H=256,144
  local function widen(menu)
    if not menu then return menu end
    menu.holdsUIAnchors=true
    menu.isOpaque=true

    local function drawCanvas(self)
      local Font=require("src.render.Font")
      local Theme=require("src.ui.Theme")
      love.graphics.setColor(1,1,1,1)
      love.graphics.rectangle("fill",0,0,WIDE_W,WIDE_H)
      love.graphics.setColor(0,0,0,1)
      Font.draw(tostring(self.title or "RANDOMIZER"),8,4)
      local rows=self.rows or 7
      for row=1,rows do
        local i=(self.scroll or 0)+row
        local item=self.items[i]
        if not item then break end
        local y=8+row*16
        -- 232px of row text is enough for the longest current Randomizer row
        -- while leaving the cursor and right gutter inside the 16:9 canvas.
        Font.draw(fitText(Font,item.label,WIDE_W-24),16,y)
        if i==self.index then Font.drawCode(Theme.cursor,8,y) end
      end
      if self.footer then
        local text=tostring(type(self.footer)=="function" and self.footer() or self.footer)
        -- Keep status/help off the normal row text. It wraps aggressively on
        -- 16:9 rather than forcing the whole menu back onto the 160px canvas.
        drawWrapped(Font,text,152,20,WIDE_W-160,132)
      end
    end

    -- Gen 1 / any host path that respects state:uiSize().
    menu.uiSize=function() return WIDE_W,WIDE_H end
    menu.draw=drawCanvas

    -- Gen 2 (Gold/Silver/Crystal): Game2 only allocates a wider target for a
    -- state that owns a widescreen layer.  Paint the same 256x144 menu into
    -- that layer at the largest clean integer scale, centered in the viewport.
    menu.drawsWidescreen=function() return true end
    menu.drawWidescreen=function(self,w,h)
      local G=love.graphics
      G.setColor(1,1,1,1)
      G.rectangle("fill",0,0,w,h)
      local scale=math.floor(math.min(w/WIDE_W,h/WIDE_H))
      if scale<1 then scale=math.min(w/WIDE_W,h/WIDE_H) end
      local ox=math.floor((w-WIDE_W*scale)/2)
      local oy=math.floor((h-WIDE_H*scale)/2)
      G.push()
      G.translate(ox,oy)
      G.scale(scale,scale)
      drawCanvas(self)
      G.pop()
      G.setColor(1,1,1,1)
    end
    return menu
  end

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
      menu=tuneRandoMenu(mod.ui.ListMenu.new(game,"MANUAL SEED",{}, {
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
        onSelectKey=function(item)
          if type(item.value)=="number" then digits[item.value]=(digits[item.value]+9)%10; rebuild() end
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
      menu=widen(tuneRandoMenu(mod.ui.ListMenu.new(game,"BST DIFFERENCE",{}, {
        wrap=true,pageJump=true,keyRepeat=true,
        onChoose=function(item,m)
          if item.value=="save" then
            closeMenu(m); if opts.onDone then opts.onDone(value) end
          else value=math.max(0,math.min(500,value+item.value)); rebuild() end
        end,
      })))
      menu.footer="0 = equal BST. Range 0-500."
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
            local levelPct=(key=="trainer_levels" or key=="boss_levels" or key=="wild_levels")
            if levelPct and cfg.level_mode=="PROGRESSION" then supported=false end
            if key=="bst_difference" and not cfg.bst_match then supported=false end
            if key=="protection_guards" and (cfg.random_start~="LOGIC" or cfg.level_mode=="PROGRESSION") then supported=false end
            if supported and (key~="manual_seed" or cfg.seed_mode=="MANUAL") then
              items[#items+1]={label=(id==WORLD and worldSettingRow(key,cfg[key]) or settingRow(key,cfg[key])),value=key}
            end
          end
          items[#items+1]={label="BACK",value="back"}
          menu.items=items
        end
        menu=widen(tuneRandoMenu(mod.ui.ListMenu.new(game,spec.title,{}, {
          wrap=true,pageJump=true,keyRepeat=true,
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
      local cfg=Randomizer.defaults()
      local stored=mod.save:get("last_config",nil)
      if type(stored)=="table" then
        cfg=Randomizer.normalizedConfig(stored)
        -- 1.2.x configs predate RULESET. Migrate their default to the host
        -- cartridge generation instead of silently making a Gold setup Gen 1.
        if stored.ruleset==nil and game and game.data and game.data.gen2Encounters then cfg.ruleset="GEN2" end
      elseif game and game.data and game.data.gen2Encounters then
        cfg.ruleset="GEN2"
      end
      local status="SELECT SETTINGS"
      local retryAttempt=0
      local validating=false
      local validationStage=0
      local validationTotal=14
      local menu
      local function rebuild()
        menu.items={
          {label="POKEMON",value="pokemon"},
          {label="BATTLE + WILDS",value="battle"},
          {label="WORLD + ITEMS",value="world"},
          {label="SAFETY + SEED",value="run"},
          {label=validating and "PLEASE WAIT" or (retryAttempt>0 and ("VALIDATE AGAIN ("..tostring(retryAttempt+1)..")") or "VALIDATE + BEGIN"),value="begin"},
          {label="PLAY VANILLA",value="cancel"},
        }
        menu.title=validating and (("VALIDATING %d/%d"):format(validationStage,validationTotal)) or "RANDO SETUP"
      end
      local function finishVanilla(m)
        Randomizer.clear(game)
        mod.save:set("last_config",Core.copy(cfg))
        closeMenu(m)
        if opts.onDone then opts.onDone(false) end
      end
      menu=widen(tuneRandoMenu(mod.ui.ListMenu.new(game,"RANDO SETUP",{}, {
        wrap=true,pageJump=true,keyRepeat=true,
        onChoose=function(item,m)
          -- 1.3.32: validation is frame-staged. Re-entering VALIDATE + BEGIN
          -- while it is running replaces the active handle and restarts at
          -- stage zero. A held/touch A press could therefore create an endless
          -- "Seed attempt 121..." loop that looked like the game had frozen.
          -- Freeze this setup menu until the one active validation finishes.
          if validating then return end
          local key=item.value
          if key=="pokemon" then mod.ui.push(game,POKEMON,{cfg=cfg})
          elseif key=="battle" then mod.ui.push(game,BATTLE,{cfg=cfg})
          elseif key=="world" then mod.ui.push(game,WORLD,{cfg=cfg})
          elseif key=="run" then mod.ui.push(game,RUN,{cfg=cfg})
          elseif key=="begin" then
            validating=true; validationStage=0
            status="PREFLIGHT..."; m.footer=nil; rebuild()
            local preOk,preflight,why,normalized=pcall(Randomizer.preflight,game,cfg)
            if not preOk then
              validating=false
              status="PREFLIGHT ERROR"
              mod.save:set("last_error",tostring(preflight))
              m.footer="Validation error: "..tostring(preflight)
              rebuild()
              return
            end
            if not preflight then
              validating=false
              status="PREFLIGHT FAIL"
              mod.save:set("last_error",tostring(why))
              m.footer=tostring(why)
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
              m.footer=tostring(err); rebuild(); return
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
                m.footer=nil
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
                    mod.save:set("last_error",tostring(commitErr)); m.footer=tostring(commitErr); rebuild(); return
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
                  if cfg.seed_mode=="MANUAL" then m.footer="Manual seed rejected: "..tostring(genErr)
                  else m.footer="Press VALIDATE AGAIN for a new seed. "..tostring(genErr) end
                  rebuild()
                end
              end,
            }
          elseif key=="cancel" then finishVanilla(m)
          end
        end,
        onCancel=function()
          if validating then return end
          finishVanilla(menu)
        end,
      })))
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
      menu=tuneRandoMenu(mod.ui.ListMenu.new(game,"BUY RANDO HINT",{}, {
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
      local words={}
      for w in text:gmatch("%S+") do words[#words+1]=w end
      local lines={}
      local cur=""
      for _,w in ipairs(words) do
        if #cur==0 then cur=w
        elseif #cur+#w+1<=19 then cur=cur.." "..w
        else lines[#lines+1]=cur; cur=w end
      end
      if #cur>0 then lines[#lines+1]=cur end
      local items={}
      if tier~="" then items[#items+1]={label="ANSWER: "..tier} end
      for _,line in ipairs(lines) do items[#items+1]={label=line} end
      items[#items+1]={label="CLOSE",value="close"}
      return tuneRandoMenu(mod.ui.ListMenu.new(game,"RANDO HINT",items,{
        wrap=true,pageJump=true,
        onChoose=function(item,m) if item.value=="close" then closeMenu(m) end end,
        onCancel=function(m) closeMenu(m) end,
      }))
    end,
  })

  mod.content.screens:register(INFO, {
    new=function(game)
      local seed=mod.save:get("seed",nil)
      local cfg=Randomizer.normalizedConfig(mod.save:get("config",{}))
      local items={}
      if not seed then
        items[1]={label="VANILLA - NO SEED"}
      else
        items[#items+1]={label="SEED: "..tostring(seed)}
        items[#items+1]={label="FP: "..tostring(mod.save:get("fingerprint","?"))}
        items[#items+1]={label="SAFETY: "..tostring(cfg.safety or "?")}
        local active=Randomizer.active()
        local plan=active and active.itemPlan
        if plan and plan.proof then
          items[#items+1]={label=plan.proof.checked and "KEY/HM LOGIC: PASS" or "KEY/HM LOGIC: CHAOS"}
          items[#items+1]={label="MOVED REWARDS: "..tostring(plan.changed or 0)}
        end
        items[#items+1]={label="TRIES: "..tostring(mod.save:get("validation_attempts",1))}
        local code=Randomizer.runCode and Randomizer.runCode() or nil
        if code then items[#items+1]={label="RUN CODE: "..code}; items[#items+1]={label="COPY RUN CODE",value="copy"} end
        local keys={"ruleset","pokedex","bst_match","bst_difference","base_stats","types","evolutions","impossible_evos","starters","rival_starter","movesets","abilities","trainers","area_encounters","extra_species","statics","tms","tm_compat","field_items","gift_items","progression_items","pc_item","marts","mart_safety","trades","badges","random_start","protection_guards","allow_legendaries","trainer_levels","boss_levels","wild_levels","trainer_ai","boss_ai"}
        for _,k in ipairs(keys) do items[#items+1]={label=settingRow(k,cfg[k])} end
        local pc=mod.save:get("pc_start_item",nil)
        if pc then items[#items+1]={label="PC START: "..tostring(pc):gsub("_"," ")} end
      end
      return widen(tuneRandoMenu(mod.ui.ListMenu.new(game,"RANDO INFO",items,{pageJump=true,wrap=true,onChoose=function(item,m)
        if item and item.value=="copy" then
          local code=Randomizer.runCode and Randomizer.runCode()
          local ok=code and love and love.system and love.system.setClipboardText and pcall(love.system.setClipboardText,code)
          m.footer=ok and "RUN CODE COPIED" or "Clipboard unavailable; run code is shown above."
        else closeMenu(m) end
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
  UI.POKEMON,UI.BATTLE,UI.WORLD,UI.RUN=POKEMON,BATTLE,WORLD,RUN
  return UI
end
