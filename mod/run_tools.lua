-- Save-scoped run records and a deliberately non-executable share format.
return function(mod,Core,R,W,A)
  local T={schema=1,version='1.10.0',defaults={adaptive_bosses='OFF',victory_goal='NATIVE',race_mode=false}}
  local modes={OFF=true,SAFE=true,CHAOS=true}
  local goals={NATIVE=true,CHAMPION=true,BADGES=true,RED=true,CHECKLIST=true}
  local function active() return R.active() end
  local function world(a) return a.generation==2 and W.gen2 or W.gen1 end
  local function human(v) return tostring(v or '?'):gsub('OPP_',''):gsub('_',' ') end
  local function edition(game)
    local ok,V=pcall(require,'src.core.GameVersion');return ok and V.get() or game.version or (game.data.gen2Encounters and 'crystal' or 'red')
  end
  function T.fingerprintConfig(c)
    local out=Core.copy(c)
    for k,v in pairs(T.defaults) do if out[k]==v then out[k]=nil end end
    return out
  end
  function T.preflight(game,c)
    if not modes[c.adaptive_bosses] then return false,'Unknown story boss mode.' end
    if not goals[c.victory_goal] then return false,'Unknown victory goal.' end
    if type(c.race_mode)~='boolean' then return false,'Race mode must be On or Off.' end
    if c.victory_goal=='RED' and not game.data.gen2Encounters then return false,'Red is a native Gen 2 goal only.' end
    return true
  end
  function T.objectives(a)
    local mode=a.cfg.victory_goal or 'NATIVE';local out={}
    if mode=='NATIVE' or mode=='CHAMPION' then return {{id='CHAMPION',label='Become Champion'}} end
    if mode=='RED' then return {{id='RED',label='Defeat Red'}} end
    for _,g in ipairs(world(a).gyms) do out[#out+1]={id='GYM:'..g.key,label='Clear '..human(g.map)} end
    if mode=='BADGES' then return {{id='BADGES',label='Earn all '..(a.generation==2 and 16 or 8)..' badges'}} end
    out[#out+1]={id='CHAMPION',label='Become Champion'}
    if a.generation==2 then out[#out+1]={id='RED',label='Defeat Red'} end
    local rng=Core.rng(Core.hash('goals-v1',a.seed))
    for i=#out,2,-1 do local j=rng:int(1,i);out[i],out[j]=out[j],out[i] end
    while #out>5 do table.remove(out) end
    return out
  end
  function T.prepare(a)
    a.objectives=T.objectives(a)
    if a.cfg.victory_goal~='NATIVE' and a.cfg.victory_goal~=nil and a.cfg.safety=='SAFE' then
      local p=a.gen1World or a.gen2World
      if not p or not p.checked or not p.proof or not p.proof.complete then return false,'[seed] Custom goal requires a complete native progression proof.' end
    end
    return true
  end
  function T.persist(a)
    if a and a.runRecord then mod.save:set('run_record',Core.copy(a.runRecord)) end
  end
  function T.newRecord(a)
    return {schema=1,seed=a.seed,edition=a.version,seconds=0,blackouts=0,battles=0,caught=0,
      wins={},splits={},discoveries={},items={},recent={},completed=false,finishTeam={}}
  end
  function T.start(a)
    if a.runRecord then return end
    a.runRecord=T.newRecord(a);T.persist(a)
  end
  function T.restore(a)
    local saved=mod.save:get('run_record',nil)
    if type(saved)=='table' and saved.schema==1 and saved.seed==a.seed and saved.edition==a.version then a.runRecord=Core.copy(saved)
    else a.runRecord=T.newRecord(a);a.runRecord.partial=true end
    T.persist(a)
  end
  function T.clear() mod.save:set('run_record',nil) end
  function T.state(a) a=a or active();if not a then return nil end;if not a.runRecord then T.restore(a) end;return a.runRecord end
  function T.locked(a) a=a or active();return a and a.cfg.race_mode and not (T.state(a).completed) or false end
  function T.clock(seconds)
    local n=math.max(0,math.floor(tonumber(seconds) or 0))
    return ('%02d:%02d:%02d'):format(math.floor(n/3600),math.floor(n/60)%60,n%60)
  end
  function T.done(a,id)
    local st=T.state(a)
    if id=='BADGES' then return A.badges(a)>=(a.generation==2 and 16 or 8) end
    return not not st.wins[id]
  end
  function T.check(a)
    local st=T.state(a);if not st or st.completed then return end
    for _,o in ipairs(a.objectives or T.objectives(a)) do if not T.done(a,o.id) then return end end
    st.completed=true;st.finishedAt=st.seconds;st.finishTeam={}
    for _,m in ipairs(a.game.save.party or {}) do
      local moves={};for _,x in ipairs(m.moves or {}) do moves[#moves+1]=type(x)=='table' and (x.id or x.move) or x end
      st.finishTeam[#st.finishTeam+1]={species=m.species,level=m.level,moves=moves}
    end
    local w=a.gen1State or a.gen2State
    st.rumors=Core.copy(w and w.rumors or {})
    mod.save:set('last_recap',Core.copy(st));T.persist(a)
  end
  function T.win(a,id,label)
    local st=T.state(a);if st.completed or st.wins[id] then return end
    st.wins[id]=true;st.splits[#st.splits+1]={id=id,label=label,seconds=st.seconds};T.check(a);T.persist(a)
  end
  function T.battleEnd(ev)
    local a=active();local b=ev and ev.battle
    if not a or not b or ev.skipped or b.link or b.isLink or b.linkBattle then return end
    local st=T.state(a);if st.completed then return end;st.battles=st.battles+1
    if ev.result=='win' then
      local class,index=b.oppClass,b.partyIndex
      if a.generation==2 and b.trainer and not b.wild then
        class=b.trainer.classId or b.trainer.class;index=b.trainer.member or b.trainer.memberId or b.trainer.index or 1
      end
      local s=class and A.source(a,class,index)
      if b._urSourceTrainer then
        local sourceClass,sourceIndex=b._urSourceTrainer:match('^(.-)#(%d+)$')
        if sourceClass then s=A.source(a,sourceClass,tonumber(sourceIndex)) or s end
      end
      if s then T.win(a,'GYM:'..s.key,human(s.map)) end
      local c=tostring(class or ''):gsub('^OPP_','')
      if c=='RIVAL3' or c=='CHAMPION' then T.win(a,'CHAMPION','Champion') end
      if a.generation==2 and c=='RED' then T.win(a,'RED','Red') end
      if class and not s and c~='RIVAL3' and c~='CHAMPION' and c~='RED' then
        local boss=R.AdaptiveBosses and R.AdaptiveBosses.source(a,class,index)
        if boss then T.win(a,'BOSS:'..boss.key,boss.label or human(boss.key)) end
      end
    end
    T.persist(a)
  end
  function T.goalRows(a)
    local rows={};if not a then return {{label='Start a run to track goals'}} end
    for _,o in ipairs(a.objectives or T.objectives(a)) do rows[#rows+1]={label=o.label,right=T.done(a,o.id) and 'Done' or 'Pending',help='This objective uses the native encounter or badge reward. Shuffled gym identities do not move completion credit.'} end
    local st=T.state(a)
    rows[#rows+1]={label=st.completed and 'Goal complete!' or 'Run in progress',right=T.clock(st.finishedAt or st.seconds),help='The clock counts foreground session time, including menus. Fast-forward does not speed it up. Background time is excluded.'}
    return rows
  end
  function T.recap(a)
    local st=a and T.state(a) or mod.save:get('last_recap',nil)
    if not st then return 'No run has been recorded yet.' end
    local lines={'UNIVERSAL RANDOMIZER '..T.version,st.completed and 'GOAL COMPLETE' or 'RUN IN PROGRESS',
      'Time: '..T.clock(st.finishedAt or st.seconds),'Blackouts: '..st.blackouts,'Battles: '..st.battles,'Catches: '..st.caught}
    if st.partial then lines[#lines+1]='Tracking began after this save was created; earlier events are unavailable.' end
    for _,s in ipairs(st.splits) do lines[#lines+1]=T.clock(s.seconds)..'  '..s.label end
    lines[#lines+1]='Discovered areas: '..tostring(#Core.sortedKeys(st.discoveries))
    for _,id in ipairs(Core.sortedKeys(st.discoveries)) do lines[#lines+1]='Visited: '..human(id) end
    for _,id in ipairs(Core.sortedKeys(st.items or {})) do local found=st.items[id];lines[#lines+1]=T.clock(found.seconds)..' Found '..human(id)..' @ '..human(found.map) end
    if st.completed then
      lines[#lines+1]='Finish team:'
      for _,m in ipairs(st.finishTeam) do lines[#lines+1]=human(m.species)..' Lv.'..tostring(m.level)..' / '..table.concat(m.moves,', ') end
      lines[#lines+1]='Rumor reveal:'
      for _,key in ipairs(Core.sortedKeys(st.rumors or {})) do local r=st.rumors[key];lines[#lines+1]=(r.tier=='bogus' and '[BOGUS] ' or '[FACTUAL] ')..r.text end
    end
    return table.concat(lines,'\n')
  end
  -- Typed key/value records with a checksum; never load(), eval(), or deserialize Lua.
  function T.exportCode(a,cfg,seed)
    cfg=cfg or a.cfg;seed=seed or a.seed
    local parts={}
    for _,k in ipairs(Core.sortedKeys(cfg)) do
      local v=cfg[k]
      if type(v)=='string' then v='s'..v:gsub('[^%w_%-]',function(c) return ('%%%02X'):format(c:byte()) end)
      elseif type(v)=='boolean' then v=v and 'b1' or 'b0'
      elseif type(v)=='number' then v='n'..tostring(v) else error('Unsupported share setting: '..k) end
      parts[#parts+1]=k..'='..v
    end
    local body=(a.version or edition(a.game))..':'..tostring(seed)..':'..table.concat(parts,';')
    return 'UR110:'..tostring(Core.hash(body,110))..':'..body
  end
  function T.importCode(game,code)
    if type(code)~='string' or #code>16000 then return nil,'Invalid or oversized run code.' end
    code=code:gsub('%s','')
    local checksum,v,seed,payload=code:match('^UR110:(%d+):([%w]+):(%d+):(.+)$')
    if not checksum then return nil,'Use a complete UR110 code copied by version 1.10.0.' end
    local body=v..':'..seed..':'..payload
    if tonumber(checksum)~=Core.hash(body,110) then return nil,'Run code checksum failed. Copy the full code again.' end
    if v~=edition(game) then return nil,'This code is for '..v..'. Open that cartridge first.' end
    seed=tonumber(seed);if seed<1 or seed>2147483646 or seed~=math.floor(seed) then return nil,'Invalid seed.' end
    local defaults=R.defaults(game);local cfg={}
    for field in (payload..';'):gmatch('(.-);') do
      local k,typ,raw=field:match('^([%w_]+)=([sbn])(.*)$')
      if not k or defaults[k]==nil or cfg[k]~=nil then return nil,'Unknown or duplicate setting in code.' end
      local value
      if typ=='s' then
        if raw:gsub('%%[%x][%x]',''):find('%',1,true) then return nil,'Malformed setting escape.' end
        value=raw:gsub('%%(%x%x)',function(hex) return string.char(tonumber(hex,16)) end)
      elseif typ=='b' then if raw~='0' and raw~='1' then return nil,'Invalid toggle.' end;value=raw=='1'
      else value=tonumber(raw);if not value or value~=value or math.abs(value)>2147483646 then return nil,'Invalid number.' end end
      if type(value)~=type(defaults[k]) then return nil,'Setting type mismatch: '..k end
      cfg[k]=value
    end
    for k in pairs(defaults) do if cfg[k]==nil then return nil,'Incomplete settings: '..k end end
    local ok,why,normalized=R.preflight(game,cfg)
    if not ok then return nil,why end
    -- Normalization may migrate old settings, but a current code must be exact.
    for k,vv in pairs(cfg) do if normalized[k]~=vv then return nil,'Unsupported setting combination in code: '..k end end
    return {cfg=cfg,seed=seed,edition=v}
  end
  T.presets={
    {id='BALANCED',name='Balanced adventure',values={safety='SAFE',starters='RANDOM',movesets='TYPE_BIAS',trainers='SIMILAR',wild_randomness='BALANCED',adaptive_gyms='SAFE',adaptive_bosses='SAFE',mart_safety=true,impossible_evos=true}},
    {id='SHUFFLED',name='Everything shuffled safely',values={safety='SAFE',starters='RANDOM',movesets='TYPE_BIAS',trainers='RANDOM',random_start='LOGIC',field_items='LOGIC_RANDOM',gift_items='RANDOM',progression_items=true,marts='SAFE',mart_safety=true,badges='SAFE',gym_leaders='SAFE',gym_entrances='SAFE',dungeon_entrances='SAFE',adaptive_gyms='SAFE',adaptive_bosses='SAFE',victory_goal='CHAMPION',impossible_evos=true}},
    {id='CHAOS',name='Absolute bullshit',values={safety='CHAOS',starters='RANDOM',movesets='RANDOM',trainers='RANDOM',wild_randomness='UNRESTRICTED',random_start='CHAOS',field_items='CHAOS',gift_items='RANDOM',progression_items=true,marts='CHAOS',badges='CHAOS',gym_leaders='CHAOS',gym_entrances='CHAOS',dungeon_entrances='CHAOS',adaptive_gyms='CHAOS',adaptive_bosses='CHAOS',victory_goal='CHAMPION',allow_legendaries=true}},
  }
  function T.preset(game,p)
    local c=R.defaults(game);for k,v in pairs(p.values) do c[k]=v end
    return R.normalizedConfig(c,game)
  end
  function T.diff(before,after)
    local rows={};for _,k in ipairs(Core.sortedKeys(after)) do if before[k]~=after[k] then rows[#rows+1]=human(k)..': '..tostring(before[k])..' -> '..tostring(after[k]) end end
    return #rows>0 and table.concat(rows,'\n') or 'No settings would change.'
  end
  function T.diagnostic(a)
    a=a or active();local lines={'Universal Randomizer '..T.version,'Host target: v0.3.99 / Gen 1 + Gen 2',
      'Last error: '..tostring(mod.save:get('last_error','none'))}
    if a then
      local st=T.state(a)
      lines[#lines+1]='Cartridge: '..a.version;lines[#lines+1]='Seed: '..a.seed;lines[#lines+1]='Fingerprint: '..tostring(a.fingerprint)
      lines[#lines+1]='Validation attempts: '..tostring(mod.save:get('validation_attempts',1))
      lines[#lines+1]='Map: '..tostring(st.recent[#st.recent] or a.routeRuntimeMapId or '?')
      lines[#lines+1]='Recent maps: '..table.concat(st.recent,' -> ')
      lines[#lines+1]='Config: '..T.exportCode(a)
      lines[#lines+1]='Goal complete: '..tostring(st.completed)
    end
    return table.concat(lines,'\n')
  end
  function T.observeItems(a)
    local st=T.state(a);if st.completed then return end;st.items=st.items or {}
    for id,def in pairs(a.game.data.items or {}) do
      if type(id)=='string' and type(def)=='table' and (def.keyItem or id:match('^HM_') or id:match('^HM%d'))
        and R._inventoryHas(a.game,id) and not st.items[id] then
        st.items[id]={seconds=st.seconds,map=st.recent[#st.recent] or a.routeRuntimeMapId or '?'}
      end
    end
  end
  function T.install()
    local tracker=W.tracker
    W.tracker=function(a,...)
      local rows=tracker(a,...)
      if T.locked(a) then
        for _,row in ipairs(rows) do
          if row.right=='Not cleared' then row.help='Clear this native gym to record its reward. Future leaders and rewards are hidden in race mode.' end
        end
      end
      return rows
    end
    mod.events:on('battle.ended',T.battleEnd)
    mod.events:on('world.blacked_out',function() local a=active();if a then local s=T.state(a);if not s.completed then s.blackouts=s.blackouts+1;T.persist(a) end end end)
    mod.events:on('pokemon.caught',function(ev) local a=active();if a and ev and ev.mon then local s=T.state(a);if not s.completed then s.caught=s.caught+1;T.persist(a) end end end)
    mod.events:on('map.entered',function(ev)
      local a=active();if not a or not ev or not ev.mapId then return end
      local s=T.state(a);local id=tostring(ev.mapId);if not s.completed then s.discoveries[id]=true end
      if s.recent[#s.recent]~=id then s.recent[#s.recent+1]=id end
      while #s.recent>16 do table.remove(s.recent,1) end;T.check(a);T.persist(a)
    end)
    local last,lastSave,lastActive,lastObserve
    mod.hooks:wrap('input.step',function(nextFn,game,dt)
      local result=nextFn(game,dt);local now=love and love.timer and love.timer.getTime and love.timer.getTime()
      local a=active()
      if a~=lastActive then last=nil;lastSave=nil;lastObserve=nil;lastActive=a end
      if a and a.game==game and now then
        local s=T.state(a);local elapsed=last and now-last or 0
        local focused=not love.window or not love.window.hasFocus or love.window.hasFocus()
        if focused and elapsed>=0 and elapsed<=2 and not s.completed then s.seconds=s.seconds+elapsed end
        if not lastObserve or now-lastObserve>=1 then T.observeItems(a);lastObserve=now end
        T.check(a)
        if not lastSave or now-lastSave>=15 then T.persist(a);lastSave=now end
      end
      last=now;return result
    end)
    mod.hooks:wrap('save.write',function(nextFn,...) T.persist(active());return nextFn(...) end)
  end
  return T
end
