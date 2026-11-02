-- Read-only native HUDs. Layout edits never send gameplay button presses.
return function(mod,Core,R,Menu)
  local O={schema=1,panels={'run','party','encounter','move','learn'}}
  local names={run='Run + splits',party='Party + EXP',encounter='Caught + shiny',move='Move details',learn='Learn comparison'}
  local widths={run=250,party=250,encounter=230,move=260,learn=270}
  local heights={run=190,party=160,encounter=100,move=160,learn=210}
  local fonts={}
  local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
  local function human(s) return tostring(s or '?'):gsub('_TYPE',''):gsub('_',' ') end
  local function top(game) return game.stack and game.stack:top() end
  local function font(n) n=math.max(10,math.floor(n));if not fonts[n] then fonts[n]=love.graphics.newFont(n) end;return fonts[n] end
  function O.layout(w,h)
    local family=w>=h and 'landscape' or 'portrait'
    local all=mod.save:get('overlay_layouts',{})
    if type(all)~='table' or all.schema~=1 then all={schema=1} end
    all[family]=all[family] or {}
    local rows=all[family]
    local unit=clamp(math.min(w,h)/480,.8,2)
    local defaults={};local cursor=42
    if family=='portrait' then
      local scale=math.min(1,(h-100)/(820*unit))
      for _,id in ipairs(O.panels) do
        local ph=heights[id]*unit*scale
        defaults[id]={x=.5,y=clamp((cursor-42)/math.max(1,h-ph-86),0,1),scale=scale,shown=false,auto=true}
        cursor=cursor+ph+8
      end
    else
      for _,id in ipairs(O.panels) do
        local left=id=='run' or id=='encounter'
        local scale=math.min(1,(h-100)/((left and 290 or 370)*unit))
        local ph=heights[id]*unit*scale
        local lower=id=='encounter' or id=='move' or id=='learn'
        local y=lower and ((left and 190 or 160)*unit*scale+10) or 0
        defaults[id]={x=left and 0 or 1,y=clamp(y/math.max(1,h-ph-86),0,1),scale=scale,shown=false,auto=true}
      end
    end
    for i,id in ipairs(O.panels) do
      local d=rows[id]
      if type(d)~='table' then d=defaults[id];rows[id]=d end
      if d.auto then local fresh=defaults[id];d.x,d.y,d.scale=fresh.x,fresh.y,fresh.scale end
      d.x=clamp(tonumber(d.x) or 0,0,1);d.y=clamp(tonumber(d.y) or 0,0,1);d.scale=clamp(tonumber(d.scale) or 1,.5,2.5)
      d.shown=d.shown==true
    end
    return rows,all,family
  end
  function O.bounds(id,d,w,h)
    local unit=clamp(math.min(w,h)/480,.8,2)
    local scale=math.min(unit*d.scale,(w-16)/widths[id],(h-86)/heights[id])
    local pw,ph=widths[id]*scale,heights[id]*scale
    return {x=8+d.x*math.max(0,w-pw-16),y=42+d.y*math.max(0,h-ph-86),w=pw,h=ph,s=scale}
  end
  function O.store(rows,all,family) all[family]=rows;mod.save:set('overlay_layouts',Core.copy(all)) end
  function O.exp(game,mon)
    if not mon then return 0,'EXP unavailable' end
    if (mon.level or 1)>=100 then return 1,'Lv.100 / MAX EXP' end
    local def=game.data.pokemon[mon.species] or {};local lv=mon.level or 1;local lo,hi,exp
    if game.data.gen2Encounters then
      local M=require('src.battle.gen2.Mon');local curve=M.growthFor(game.data,def.growthRate)
      lo,hi=M.experienceForLevel(curve,lv),M.experienceForLevel(curve,lv+1);exp=mon.experience
    else
      local G=require('src.pokemon.Growth');lo=G.expForLevel(def.growthRate,lv,game.data.growth_rates);hi=G.expForLevel(def.growthRate,lv+1,game.data.growth_rates);exp=mon.exp
    end
    if not exp or not hi or hi<=lo then return 0,'EXP unavailable' end
    return clamp((exp-lo)/(hi-lo),0,1),tostring(math.max(0,hi-exp))..' EXP to Lv.'..(lv+1)
  end
  local function selected(game)
    local s=top(game);if not s then return nil end
    if s.phase=='moveSelect' and s.player then
      local entry=(s.player.curMoves or {})[s.moveIndex or 1];return entry and entry.id,s.player.mon,s.player.curTypes
    elseif s.phase=='moves' and s.battle then
      local mon=s.battle.player;local entry=mon and (mon.moves or {})[s.moveIndex or 1]
      return entry and entry.id,mon,mon and (mon.types or (game.data.pokemon[mon.species] or {}).types)
    end
  end
  local effects={
    NO_ADDITIONAL='Deals damage.',NORMAL_HIT='Deals damage.',
    SLEEP='Puts the target to sleep.',POISON='Poisons the target.',TOXIC='Badly poisons the target.',
    PARALYZE='Paralyzes the target.',CONFUSION='Confuses the target.',CONFUSE='Confuses the target.',
    POISON_HIT='May poison the target.',BURN_HIT='May burn the target.',FREEZE_HIT='May freeze the target.',
    PARALYZE_HIT='May paralyze the target.',CONFUSION_HIT='May confuse the target.',CONFUSE_HIT='May confuse the target.',
    FLINCH_HIT='May make the target flinch if you move first.',
    ATTACK_TWICE='Hits twice.',DOUBLE_HIT='Hits twice.',TWO_TO_FIVE_ATTACKS='Hits two to five times.',MULTI_HIT='Hits two to five times.',
    TWINEEDLE='Hits twice and may poison.',POISON_MULTI_HIT='Hits twice and may poison.',
    DRAIN_HP='Restores HP from damage dealt.',LEECH_HIT='Restores HP from damage dealt.',DREAM_EATER='Drains HP from a sleeping target.',
    EXPLODE='The user faints after attacking.',SELFDESTRUCT='The user faints after attacking.',
    RECOIL='The user also takes recoil damage.',RECOIL_HIT='The user also takes recoil damage.',
    OHKO='Attempts a one-hit knockout.',SUPER_FANG="Removes half the target's current HP.",
    HEAL="Restores the user's HP.",LEECH_SEED='Seeds the target to drain HP each turn.',
    REFLECT='Reduces physical damage.',LIGHT_SCREEN='Reduces special damage.',MIST='Protects against stat reductions.',
    HAZE='Clears stat changes.',RESET_STATS='Clears stat changes.',
    SUBSTITUTE='Spends HP to create a substitute.',DISABLE='Temporarily disables a move.',
    METRONOME='Calls a randomly selected move.',MIMIC="Copies one of the target's moves.",MIRROR_MOVE="Repeats the target's last move.",
    TRANSFORM='Transforms into the target.',CONVERSION="Changes the user's type.",CONVERSION2="Changes the user's type based on the last move received.",
    SPLASH='Has no battle effect.',PAY_DAY='Scatters money to collect after battle.',
    SWIFT='Ignores ordinary accuracy checks.',ALWAYS_HIT='Ignores ordinary accuracy checks.',
    CHARGE='Charges before attacking.',FLY='Leaves the field before attacking next turn.',
    HYPER_BEAM='A powerful attack that can require a recharge turn.',JUMP_KICK='Hurts the user if the attack misses.',
    BIDE='Stores damage, then strikes back.',RAGE='Builds Attack when the user is hit.',
    THRASH_PETAL_DANCE='Attacks for several turns, then confuses the user.',RAMPAGE='Attacks for several turns, then confuses the user.',
    TRAPPING='Traps the target for several turns.',TRAP_TARGET='Traps the target for several turns.',
    SWITCH_AND_TELEPORT='Attempts to end a wild battle or force a switch.',TELEPORT='Attempts to escape a wild battle.',FORCE_SWITCH='Forces a switch or ends a wild battle.',
    SPECIAL_DAMAGE="Deals damage using this move's fixed or level-based rule.",LEVEL_DAMAGE="Deals damage equal to the user's level.",STATIC_DAMAGE='Deals a fixed amount of damage.',
    FOCUS_ENERGY="Changes critical-hit odds using this game's native rules.",
    PROTECT='Protects the user this turn; repeated use can fail.',ENDURE='Lets the user survive an attack this turn with 1 HP.',
    FALSE_SWIPE='Leaves the target with at least 1 HP.',BATON_PASS='Switches out while passing supported stat changes.',
    MEAN_LOOK='Prevents the target from escaping.',PERISH_SONG='Affected Pokemon faint when the countdown ends.',
    ATTRACT='Infatuates a compatible target.',ENCORE='Makes the target repeat its last move.',
    BELLY_DRUM='Spends HP to maximize Attack.',HEAL_BELL='Cures party status conditions.',
    RAIN_DANCE='Starts rain.',SUNNY_DAY='Starts harsh sunlight.',SANDSTORM='Starts a sandstorm.',
    SPIKES='Places entry damage on the opposing side.',SAFEGUARD='Protects against status conditions.',
    RAPID_SPIN='Attacks and removes supported trapping or entry hazards.',
    THIEF="May steal the target's held item.",SKETCH="Permanently copies the target's last move.",
    LOCK_ON='Helps the next attack hit.',PRIORITY_HIT='Usually attacks before ordinary moves.',
  }
  function O.effectDescription(d)
    local native=d.description or d.desc
    if type(native)=='string' and native~='' then return native end
    local e=tostring(d.effect or ''):gsub('^EFFECT_',''):gsub('_EFFECT$',''):gsub('_SIDE_EFFECT%d?$','_HIT')
    if effects[e] then return effects[e] end
    local stat=e:match('^(.-)_UP');local up=stat~=nil
    stat=stat or e:match('^(.-)_DOWN')
    local labels={ATTACK='Attack',DEFENSE='Defense',SPEED='Speed',SPECIAL='Special',SP_ATK='Special Attack',SP_DEF='Special Defense',ACCURACY='accuracy',EVASION='evasion'}
    if labels[stat] then
      local verb=up and 'raises' or 'lowers';local target=up and "the user's " or "the target's "
      if e:find('HIT',1,true) then return 'May '..verb:gsub('s$','')..' '..target..labels[stat]..'.' end
      local stages=e:match('2$') and 'two stages.' or 'one stage.'
      return verb:sub(1,1):upper()..verb:sub(2)..' '..target..labels[stat]..' by '..stages
    end
    return 'Uses '..human(d.name or 'this move').."'s native effect."
  end
  function O.moveLines(game,id,mon,types)
    local d=game.data.moves and game.data.moves[id];if not d then return {'No move selected'} end
    local stab=false;types=types or (mon and game.data.pokemon[mon.species] or {}).types
    for _,t in ipairs(types or {}) do if t==d.type then stab=true end end
    local power=tonumber(d.power) or 0
    local lines={human(d.name or id),human(d.type)..(stab and power>0 and ' / STAB' or ''),
      'Power '..(power>1 and power or '--')..'  Accuracy '..tostring(d.accuracy or '--'),
      'Base PP '..tostring(d.pp or '--')}
    local effect=O.effectDescription(d)
    lines[#lines+1]=tostring(effect):gsub('<NEXT>',' '):gsub('<LINE>',' ')
    lines[#lines+1]='Tap panel for full details.'
    return lines
  end
  function O.learn(game)
    local s=top(game);if not s then return nil end
    if s.newMoveId and s.mon and s.selecting then return s.mon,s.newMoveId,(s.mon.moves[s.index or 1] or {}).id end
    if s.phase=='choose-forget' and s.pendingLearn and s.battle then
      local p=s.pendingLearn;local m=s.battle.party[p.index]
      return m,p.move,m and (m.moves[s.forgetIndex or 1] or {}).id
    end
  end
  function O.model(game,id,preview)
    local a=R.active();local s=top(game);local battle=O.battle
    local player=battle and battle.player;local mon=player and (player.mon or player) or (game.save.party or {})[1]
    if id=='run' then
      if not a then return preview and {'Start a run to record time','Goals, gym order and splits','Blackouts and discoveries'} end
      local T=R.RunTools;local st=T.state(a);local done=0;local goals=a.objectives or T.objectives(a)
      for _,g in ipairs(goals) do if T.done(a,g.id) then done=done+1 end end
      local lines={T.clock(st.finishedAt or st.seconds)..(st.completed and ' / COMPLETE' or ''),
        'Goals '..done..'/'..#goals..'  Badges '..R.AdaptiveGyms.badges(a),'Blackouts '..st.blackouts..'  Caught '..st.caught}
      for i=math.max(1,#st.splits-2),#st.splits do local sp=st.splits[i];lines[#lines+1]=T.clock(sp.seconds)..' '..sp.label end
      return lines
    elseif id=='party' then
      if not mon then return preview and {'Active Pokemon','HP / stats / native EXP'} end
      local fraction,label=O.exp(game,mon);local st=player and player.curStats or mon.stats or {}
      return {human(mon.species)..' Lv.'..tostring(mon.level),'HP '..tostring(mon.hp)..' / '..tostring(mon.maxHp or st.hp),
        'ATK '..tostring(st.attack or '?')..' DEF '..tostring(st.defense or '?')..' SPD '..tostring(st.speed or '?'),label},fraction
    elseif id=='encounter' then
      if not battle or battle.link or battle.isLink or battle.linkBattle or battle.kind=='trainer' or battle.trainer or battle.ghost or battle.demo then return preview and {'Wild Pokemon caught marker','Native Gen 2 shiny indicator'} end
      local enemy=battle.enemy and (battle.enemy.mon or battle.enemy)
      if not enemy then return nil end
      local dex=(game.save.pokedex or {}).caught or {};local def=game.data.pokemon[enemy.species] or {}
      local caught=dex[enemy.species] or dex[def.dex]
      local shiny=false
      if game.data.gen2Encounters then shiny=enemy.shiny;if shiny==nil then shiny=require('src.battle.gen2.Mon').vanillaShiny(enemy.dvs) end end
      return {human(enemy.species)..(shiny and ' * SHINY *' or ''),(caught==true or type(caught)=='number' and caught>0) and 'Already caught' or 'Not caught yet'}
    elseif id=='move' then
      local mid,m,types=selected(game)
      return mid and O.moveLines(game,mid,m,types) or preview and {'Highlight a battle move','Type / power / accuracy / PP','STAB + native effect','Tap panel for full details'}
    elseif id=='learn' then
      local m,new,old=O.learn(game)
      if not m then return preview and {'Compare new and old moves','Native HM protections apply','Learning stays in game menu'} end
      local newer,older=O.moveLines(game,new,m),O.moveLines(game,old,m)
      return {'NEW: '..newer[1],newer[2],newer[3]..' / '..newer[4],
        'OLD: '..older[1],older[2],older[3]..' / '..older[4],'Choose in the native move list.'}
    end
  end
  local function panel(id,b,lines,bar,editing,selected,shown)
    local G=love.graphics;G.setColor(.035,.055,.10,.92);G.rectangle('fill',b.x,b.y,b.w,b.h,8,8)
    G.setColor(selected and .3 or .18,selected and .9 or .3,selected and .75 or .4,1)
    G.rectangle('line',b.x,b.y,b.w,b.h,8,8)
    G.setFont(font(14*b.s));G.setColor(.35,.9,.76,1)
    G.print(names[id]..(editing and (shown and ' / ON' or ' / OFF') or ''),b.x+10*b.s,b.y+8*b.s)
    G.setFont(font(13*b.s));G.setColor(.92,.95,1,1)
    local y=b.y+32*b.s
    local details=id=='move' or id=='learn'
    for _,line in ipairs(lines or {}) do
      local _,wrapped=G.getFont():getWrap(tostring(line),b.w-20*b.s)
      for _,part in ipairs(wrapped) do
        if y+16*b.s<=b.y+b.h-(details and 30 or 12)*b.s then G.print(part,b.x+10*b.s,y);y=y+17*b.s end
      end
    end
    if details then G.setColor(.35,.9,.76,1);G.print('Tap for full details',b.x+10*b.s,b.y+b.h-22*b.s) end
    if bar then G.setColor(.12,.22,.3,1);G.rectangle('fill',b.x+10*b.s,b.y+b.h-10*b.s,b.w-20*b.s,4*b.s)
      G.setColor(.35,.7,1,1);G.rectangle('fill',b.x+10*b.s,b.y+b.h-10*b.s,(b.w-20*b.s)*bar,4*b.s) end
    if editing then G.setColor(.4,.9,.76,1);G.rectangle('fill',b.x+b.w-22,b.y+b.h-22,20,20) end
  end
  function O.dimensions() return love.graphics.getDimensions() end
  function O.draw(game,viewport)
    local w,h=viewport.width,viewport.height;O.viewport=viewport
    local s=top(game);local editing=s and s.urOverlayEditor
    if s and s.urMenu and not editing then return end
    local rows=O.layout(w,h);local G=love.graphics;G.push('all');G.origin();G.setShader();G.setScissor()
    if editing then
      G.setColor(.02,.035,.06,1);G.rectangle('fill',0,0,w,h)
      G.setColor(.9,.96,1,1);G.setFont(font(14));G.print('Drag a panel. Its corner resizes it.',12,6)
      G.setFont(font(10));G.print('Pad: '..(s.resize and 'resize' or 'move')..'  START: switch  SELECT: panel  A: on/off',12,25)
    end
    O.hit={}
    local order=Core.copy(O.panels)
    if editing then for i,id in ipairs(order) do if id==s.selected then table.remove(order,i);break end end;order[#order+1]=s.selected end
    for _,id in ipairs(order) do
      if editing or rows[id].shown then
        local lines,bar=O.model(game,id,editing)
        if lines then
          local b=O.bounds(id,rows[id],w,h)
          if editing and s.selected~=id then
            local labelY=b.y+(w>=h and id=='learn' and 32 or 8)
            G.setColor(.2,.4,.45,.6);G.rectangle('line',b.x,b.y,b.w,b.h,6,6);G.setFont(font(12));G.setColor(.6,.75,.8,1);G.print(names[id],b.x+8,labelY)
            b.hit={x=b.x,y=labelY-4,w=b.w,h=24}
          else panel(id,b,lines,bar,editing,editing and s.selected==id,rows[id].shown) end
          O.hit[#O.hit+1]={id=id,b=b}
        end
      end
    end
    if editing then
      local labels={'Done','Panel','On/off','Smaller','Larger','Reset'};O.buttons={}
      for i,label in ipairs(labels) do
        local x=8+(i-1)*(w-16)/6;local b={x=x,y=h-36,w=(w-16)/6-3,h=30}
        G.setColor(.10,.24,.28,1);G.rectangle('fill',b.x,b.y,b.w,b.h,4,4)
        G.setColor(.9,1,1,1);G.setFont(font(12));G.printf(label,b.x,b.y+7,b.w,'center');O.buttons[i]=b
      end
    end
    G.pop()
  end
  local function inside(b,x,y) return b and x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h end
  function O.editAction(s,action)
    local w,h=O.dimensions();local rows,all,family=O.layout(w,h);local d=rows[s.selected]
    if action==1 then O.store(rows,all,family);s:close();return
    elseif action==2 then for i,id in ipairs(O.panels) do if id==s.selected then s.selected=O.panels[i%#O.panels+1];break end end
    elseif action==3 then d.shown=not d.shown
    elseif action==4 then d.auto=false;d.scale=clamp(d.scale-.1,.5,2.5)
    elseif action==5 then d.auto=false;d.scale=clamp(d.scale+.1,.5,2.5)
    elseif action==6 then all[family]=nil;mod.save:set('overlay_layouts',all);return end
    O.store(rows,all,family)
  end
  function O.editor(game)
    local s={game=game,selected='run',urOverlayEditor=true,holdsUIAnchors=true}
    function s:close() O.capture=nil;if top(game)==self then game.stack:pop() end end
    function s:draw() end
    function s:update()
      local input=game.input
      if input:wasPressed('b') then self:close();return end
      if input:wasPressed('a') then O.editAction(self,3)
      elseif input:wasPressed('select') then O.editAction(self,2)
      elseif input:wasPressed('start') then self.resize=not self.resize end
      local w,h=O.dimensions();local rows,all,family=O.layout(w,h);local d=rows[self.selected]
      for _,key in ipairs({'up','down','left','right'}) do if input:wasPressed(key) then
        d.auto=false
        if self.resize then d.scale=clamp(d.scale+((key=='up' or key=='right') and .1 or -.1),.5,2.5)
        elseif key=='up' or key=='down' then d.y=clamp(d.y+(key=='up' and -.025 or .025),0,1)
        else d.x=clamp(d.x+(key=='left' and -.025 or .025),0,1) end
        O.store(rows,all,family)
      end end
    end
    return s
  end
  function O.details(game,id)
    local lines
    if id=='learn' then
      local m,new,old=O.learn(game);if not m then return end
      lines={'New move'};for _,line in ipairs(O.moveLines(game,new,m)) do lines[#lines+1]=line end
      lines[#lines+1]='Current move';for _,line in ipairs(O.moveLines(game,old,m)) do lines[#lines+1]=line end
      lines[#lines+1]='Use the native move list to choose. Its HM protections still apply.'
    else
      local mid,m,types=selected(game);if not mid then return end
      lines=O.moveLines(game,mid,m,types)
    end
    game.stack:push(Menu.new(game,'Move details',{{label=lines[1],help=table.concat(lines,'\n')},{label='Back'}},
      {onChoose=function(_,s) s:close() end}))
  end
  function O.pointer(game,e)
    local s=top(game);local editing=s and s.urOverlayEditor;local c=O.capture
    if e.phase=='cancelled' then O.capture=nil;return c~=nil end
    if e.phase=='pressed' then
      if e.button and e.button~=1 then return false end
      if c then return true end
      if editing then
        for i,b in ipairs(O.buttons or {}) do if inside(b,e.x,e.y) then O.capture={id=e.id,owner=s,button=i,b=b,x=e.x,y=e.y};return true end end
      end
      for i=#(O.hit or {}),1,-1 do local hit=O.hit[i]
        if inside(hit.b.hit or hit.b,e.x,e.y) and (editing or hit.id=='move' or hit.id=='learn') then
          if editing then s.selected=hit.id end
          local w,h=O.dimensions();local rows,all,family=O.layout(w,h)
          O.capture={id=e.id,owner=s,panel=hit.id,x=e.x,y=e.y,b=hit.b,w=w,h=h,family=family,
            resize=editing and e.x>=hit.b.x+hit.b.w-28 and e.y>=hit.b.y+hit.b.h-28,
            original=Core.copy(rows[hit.id]),editing=editing}
          return true
        end
      end
      return editing or false
    end
    if not c or c.id~=e.id then return false end
    if c.owner~=s then O.capture=nil;return true end
    local w,h=O.dimensions()
    if c.w and (c.w~=w or c.h~=h) then O.capture=nil;return true end
    if e.phase=='moved' then
      local dx,dy=e.x-c.x,e.y-c.y;c.moved=c.moved or dx*dx+dy*dy>100
      if c.editing and c.panel then
        local rows,all,family=O.layout(w,h);local d=rows[c.panel];d.auto=false
        if c.resize then d.scale=clamp(c.original.scale*(1+math.max(dx/c.b.w,dy/c.b.h)),.5,2.5)
        else d.x=clamp(c.original.x+dx/math.max(1,w-c.b.w-16),0,1);d.y=clamp(c.original.y+dy/math.max(1,h-c.b.h-86),0,1) end
        O.store(rows,all,family)
      end
    elseif e.phase=='released' then
      O.capture=nil
      if not c.moved and inside(c.b,e.x,e.y) then
        if c.button then O.editAction(s,c.button)
        elseif not editing and (c.panel=='move' or c.panel=='learn') then O.details(game,c.panel) end
      end
    end
    return true
  end
  function O.install()
    mod.events:on('battle.started',function(ev) O.battle=ev and ev.battle end)
    mod.events:on('battle.ended',function() O.battle=nil end)
    mod.events:on('game.ready',function() O.battle=nil;O.capture=nil end)
    mod.events:on('save.loaded',function() O.battle=nil;O.capture=nil end)
    mod.hooks:wrap('render.hud',function(nextFn,game,v) local r=nextFn(game,v);O.draw(game,v);return r end,100)
  end
  return O
end
