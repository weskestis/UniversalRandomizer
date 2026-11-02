return function(mod,Core,R,Menu,O)
  local U={};local T=R.RunTools
  local function push(game,title,rows,choose,help)
    local s=Menu.new(game,title,rows,{onChoose=choose,help=help});game.stack:push(s);return s
  end
  local function copy(s,text)
    local ok=love.system and love.system.setClipboardText and pcall(love.system.setClipboardText,text)
    s.footer=ok and 'Copied to clipboard.' or 'Clipboard unavailable on this host. The full text is in the guide.'
  end
  local function report(game,title,text)
    return push(game,title,{{label='Read report',help=text},{label='Copy report',value='copy',help=text},{label='Back',value='back'}},function(item,s)
      if item.value=='copy' then copy(s,text) elseif item.value=='back' then s:close() end
    end)
  end
  local function apply(target,source)
    for k in pairs(target) do target[k]=nil end
    for k,v in pairs(source) do target[k]=Core.copy(v) end
  end
  local function preview(game,title,cfg,nextCfg,onApply,extra)
    local diff=(extra or '')..'\n\n'..T.diff(cfg,nextCfg)
    return push(game,title,{{label='Review all changes',help=diff},{label='Apply these settings',value='apply',help=diff},
      {label='Cancel',value='back',help='Keep the current settings.'}},function(item,s)
      if item.value=='back' then s:close()
      elseif item.value=='apply' then apply(cfg,nextCfg);s:close();if onApply then onApply() end end
    end)
  end
  local function presets(game,cfg,onApply)
    local rows={};for _,p in ipairs(T.presets) do rows[#rows+1]={label=p.name,value=p,help='Preview every setting this preset changes before applying it. You can edit any setting afterwards.'} end
    push(game,'Run presets',rows,function(item) preview(game,item.value.name,cfg,T.preset(game,item.value),onApply,
      item.value.id=='CHAOS' and 'CHAOS: locks and extreme encounters are allowed.' or 'SAFE: native progression checks remain enabled.') end)
  end
  local goalValues={'NATIVE','CHAMPION','BADGES','CHECKLIST'}
  local goalNames={NATIVE='Native ending',CHAMPION='Champion',BADGES='All badges',CHECKLIST='Random checklist',RED='Defeat Red'}
  function U.open(game,cfg,onImport,onSettings)
    local setup=cfg~=nil;local a=R.active();local s
    local function rebuild()
      local rows={}
      if setup then
        rows={
          {label='Presets',value='presets',help='Balanced adventure, Everything shuffled safely, or Absolute bullshit. Review all changes first.'},
          {label='Victory goal',value='goal',right=goalNames[cfg.victory_goal],help='Native ending preserves your current world settings. Custom goals enable the full progression graph and logical keys/HMs. All badges means 8 in Gen 1 and 16 in Gen 2. A checklist picks five native gym or final-boss objectives. SAFE requires a complete proof; CHAOS can contain locks.'},
          {label='Race mode',value='race',right=cfg.race_mode and 'On' or 'Off',help='Locks randomizer location hints, future gym rewards and spoiler exports until your goal is complete. Discovered entrances remain available. This is a spoiler guard, not anti-cheat; shared codes contain the seed.'},
          {label='Import run code',value='import',help='Copy a UR110 code to your phone or PC clipboard, choose this row, then review and apply. The exact cartridge and all settings must match. The imported seed is used for validation.'},
        }
      end
      rows[#rows+1]={label='Overlay layout',value='overlays',help='Enable, move and resize Run + splits, Party + EXP, Caught + shiny, Move details and Learn comparison. Drag with a finger or mouse; drag the lower-right corner to resize. SELECT cycles panels, A toggles, D-pad moves; START switches D-pad to resize, B saves and exits. Portrait and landscape are saved separately. Reset resets this orientation.'}
      if a and not setup then
        rows[#rows+1]={label='Victory progress',value='goals',right=goalNames[a.cfg.victory_goal or 'NATIVE'],help='Only real native wins and earned badges count. Completion does not stop you playing.'}
        rows[#rows+1]={label='Share run code',value='share',help='Copy the actual accepted seed and every setting. Import on the same cartridge with this version. Live setting changes are included; old captures cannot recreate an earlier configuration.'}
        rows[#rows+1]={label='Run recap',value='recap',help='Recorded gym order, boss splits, discoveries, blackouts and finish team. Bogus rumors are revealed only once the goal is complete.'}
      end
      rows[#rows+1]={label='Diagnostic report',value='diagnostic',help='A copyable report with version, seed, settings, validation attempt count, current map and recent transitions. It is copied locally; nothing is sent automatically.'}
      rows[#rows+1]={label='Back',value='back'};s.items=rows
    end
    local function choose(item)
      if item.value=='back' then s:close()
      elseif item.value=='presets' then presets(game,cfg,function() if onSettings then onSettings() end;rebuild() end)
      elseif item.value=='goal' then
        local values=Core.copy(goalValues);if game.data.gen2Encounters then values[#values+1]='RED' end
        local i=1;for j,v in ipairs(values) do if cfg.victory_goal==v then i=j end end
        local candidate=Core.copy(cfg);candidate.victory_goal=values[i%#values+1];candidate=R.normalizedConfig(candidate,game)
        preview(game,'Change victory goal',cfg,candidate,function() rebuild() end)
      elseif item.value=='race' then cfg.race_mode=not cfg.race_mode;rebuild()
      elseif item.value=='import' then
        local ok,code=pcall(function() return love.system.getClipboardText() end)
        local decoded,why;if ok then decoded,why=T.importCode(game,code) else why='Clipboard reading is unavailable on this host.' end
        if not decoded then report(game,'Import failed',why);return end
        preview(game,'Import run',cfg,decoded.cfg,function() if onImport then onImport(decoded.seed) end;rebuild() end,
          'Cartridge: '..decoded.edition..' / Seed: '..decoded.seed..'\nValidation uses this exact seed. Rejected seeds are not silently replaced.')
      elseif item.value=='overlays' then game.stack:push(O.editor(game))
      elseif item.value=='goals' then push(game,'Victory progress',T.goalRows(a))
      elseif item.value=='share' then report(game,'Share run',T.exportCode(a))
      elseif item.value=='recap' then report(game,'Run recap',T.recap(a))
      elseif item.value=='diagnostic' then report(game,'Diagnostic report',T.diagnostic(a)) end
    end
    s=Menu.new(game,'Run tools',{}, {onChoose=choose});rebuild();game.stack:push(s);return s
  end
  return U
end
