-- Render the actual menu without copyrighted game/ROM data.
-- A CI renderer must fail the job, never wait on LOVE's interactive error screen.
function love.errorhandler(message)
  io.stderr:write(debug.traceback(tostring(message), 2), '\n')
  os.exit(1)
end

function love.load()
  local repo=assert(os.getenv('UR_REPO'))
  local root=os.getenv('MOD_SOURCE') or (repo..'/mod')
  local base=os.getenv('MOD_BASE') or (repo..'/dist/1.5.0/mod')
  if root:sub(1,1)~='/' then root=repo..'/'..root end
  if base:sub(1,1)~='/' then base=repo..'/'..base end
  local output=assert(os.getenv('UR_MENU_OUTPUT'))
  local Core=dofile(base..'/core.lua')
  local gen,version=1,'red'
  package.loaded['src.core.GameVersion']={get=function() return version end,generation=function() return gen end}
  local screens={};local saved={last_config={wild_randomness='UNRESTRICTED',wild_evolution='AS_ROLLED',random_start='LOGIC',safety='SAFE'}}
  local game={data={},save={party={},flags={}},stack={}}
  local mod={path=root,game=game,save={get=function(_,k,d) return saved[k] or d end,set=function(_,k,v) saved[k]=v end},
    content={screens={register=function(_,id,s) screens[id]=s end}},hooks={wrap=function() end},ui={},
    read=function(_,p) local f=assert(io.open(root..'/'..p));local s=f:read('*a');f:close();return s end}
  local W=dofile(root..'/gen1_world.lua')(Core)
  local G2=dofile(root..'/gen2_world.lua')(Core)
  local Worlds=dofile(root..'/worlds.lua')(W,G2)
  local A=dofile(root..'/adaptive_gyms.lua')(Core,Worlds)
  local R=dofile(root..'/randomizer.lua')(mod,Core,{},nil,nil,Worlds,A)
  mod.events={on=function() end}
  R.AdaptiveBosses=dofile(root..'/adaptive_bosses.lua')(Core,Worlds,A,R)
  R.RunTools=dofile(root..'/run_tools.lua')(mod,Core,R,Worlds,A)
  local UI=dofile(root..'/ui.lua')(mod,Core,R)
  local cfg=R.normalizedConfig(saved.last_config,game)
  local G=love.graphics
  -- Assert all painted text fits within the logical canvas, with real font
  -- metrics. The content pane and list have their own narrower layout tests.
  local printText=G.print
  G.print=function(s,x,y,...)
    assert(x>=0 and y>=0 and x+G.getFont():getWidth(s)<=641,'text crosses canvas: '..tostring(s))
    assert(y+G.getFont():getHeight()<=360,'text crosses bottom: '..tostring(s))
    return printText(s,x,y,...)
  end
  local function render(menu,name,wide)
    local canvas=G.newCanvas(wide and 1280 or 640,wide and 720 or 360)
    G.setCanvas(canvas);G.clear()
    if wide then menu:drawWidescreen(1280,720) else menu:draw() end
    G.setCanvas()
    local bytes=canvas:newImageData():encode('png'):getString()
    local f=assert(io.open(output..'/'..name..'.png','wb'));f:write(bytes);f:close()
  end
  render(screens[UI.SETUP].new(game,{}),'setup',false)
  for _,row in ipairs({{UI.WILDS,'wilds'},{UI.WORLD,'world'},{UI.POKEMON,'pokemon'},{UI.BATTLE,'battles'},{UI.RUN,'safety'}}) do
    render(screens[row[1]].new(game,{cfg=cfg}),row[2],false)
  end
  cfg.movesets='TYPE_BIAS'
  local bias=screens[UI.POKEMON].new(game,{cfg=cfg})
  local found=false
  for i,row in ipairs(bias.items) do if row.value=='movesets' then bias.index=i;found=true;break end end
  assert(found,'Movesets setting is visible')
  bias:sync();bias:helpLayout()
  assert(bias:helpContent():find('65%',1,true) and bias.helpMax>0,'Type Bias guide explains odds and scrolls')
  render(bias,'type-bias',false)
  bias.helpFocus=true;bias.helpScroll=bias.helpMax
  render(bias,'type-bias-guide-end',false)
  cfg.gym_leaders='SAFE';cfg.gym_entrances='SAFE';cfg.dungeon_entrances='SAFE'
  local gyms=screens[UI.GYMS].new(game,{cfg=cfg})
  render(gyms,'gen1-world-settings',false)
  for i,row in ipairs(gyms.items) do if row.value=='dungeon_entrances' then gyms.index=i end end
  gyms:sync();gyms:helpLayout();gyms.helpFocus=true;gyms.helpScroll=gyms.helpMax
  render(gyms,'gen1-dungeon-guide-end',false)
  cfg.adaptive_gyms='SAFE'
  local adaptive=screens[UI.GYMS].new(game,{cfg=cfg})
  for i,row in ipairs(adaptive.items) do if row.value=='adaptive_gyms' then adaptive.index=i end end
  adaptive:sync();adaptive:helpLayout();render(adaptive,'gen1-adaptive-safe',false)
  adaptive.helpFocus=true;adaptive.helpScroll=adaptive.helpMax;render(adaptive,'gen1-adaptive-guide-end',false)
  local mock={generation=1,seed=42,version='red',game=game,cfg=cfg,gen1World={checked=true,leaders={},badges={}}}
  game.save.inventory={HM_SURF=1}
  for _,g in ipairs(W.gyms) do mock.gen1World.leaders[g.key]=g.key;mock.gen1World.badges[g.key]=g.badge end
  W.state(mock).journal['PEWTER_CITY#1']='SAFFRON_GYM#1'
  R.active=function() return mock end
  render(screens[UI.JOURNAL].new(game,{}),'gen1-entrance-journal',false)
  render(screens[UI.TRACKER].new(game,{}),'gen1-progression-tracker',false)
  render(screens[UI.HINT].new(game,{text=W.roasts[1],tier='bogus'}),'gen1-bogus-hint',false)
  R.active=function() return nil end
  gen=2;version='crystal';game.data.gen2Encounters={}
  cfg=R.defaults(game);cfg.gym_leaders='SAFE';cfg.gym_entrances='SAFE';cfg.dungeon_entrances='SAFE'
  render(screens[UI.SETUP].new(game,{}),'gen2-setup',false)
  local g2menu=screens[UI.GYMS].new(game,{cfg=cfg})
  render(g2menu,'gen2-world-settings',false)
  for i,row in ipairs(g2menu.items) do if row.value=='dungeon_entrances' then g2menu.index=i end end
  g2menu:sync();g2menu:helpLayout();g2menu.helpFocus=true;g2menu.helpScroll=g2menu.helpMax
  render(g2menu,'gen2-dungeon-guide-end',false)
  cfg.adaptive_gyms='CHAOS'
  adaptive=screens[UI.GYMS].new(game,{cfg=cfg})
  for i,row in ipairs(adaptive.items) do if row.value=='adaptive_gyms' then adaptive.index=i end end
  adaptive:sync();adaptive:helpLayout();render(adaptive,'gen2-adaptive-chaos',true)
  adaptive.helpFocus=true;adaptive.helpScroll=adaptive.helpMax;render(adaptive,'gen2-adaptive-guide-end',false)
  mock={generation=2,seed=42,version='crystal',game=game,cfg=cfg,gen2World={checked=true,leaders={},badges={}}}
  for _,g in ipairs(G2.gyms) do mock.gen2World.leaders[g.key]=g.key;mock.gen2World.badges[g.key]=g.badge end
  G2.state(mock).journal['VIOLET_CITY#2']='SEAFOAM_GYM#1'
  R.active=function() return mock end
  render(screens[UI.JOURNAL].new(game,{}),'gen2-entrance-journal',false)
  render(screens[UI.TRACKER].new(game,{}),'gen2-progression-tracker',false)
  render(screens[UI.HINT].new(game,{text=G2.roasts[3],tier='bogus'}),'gen2-bogus-hint',false)
  R.active=function() return nil end
  render(screens[UI.WILDS].new(game,{cfg=cfg}),'crystal-wide',true)
  local m=screens[UI.WILDS].new(game,{cfg=cfg});m:helpLayout();m.helpFocus=true;m.helpScroll=m.helpMax
  render(m,'guide-end',false)
  R.preflight=function()
    return false,'SAFE key/HM logic requires Badges: Vanilla or Safe. Choose one under World + items, or choose Progression safety: Chaos for unchecked placements.'
  end
  saved.last_config={random_start='OFF',badges='CHAOS',safety='SAFE',field_items='SHUFFLE',gift_items='RANDOM',progression_items=true}
  local failed=screens[UI.SETUP].new(game,{})
  for i,row in ipairs(failed.items) do if row.value=='begin' then failed.index=i end end
  failed.onChoose(failed.items[failed.index],failed)
  render(failed,'crystal-validation-error',false)
  failed.index=4;failed:sync()
  assert(failed:helpContent():find('Random Start, items',1,true),'section help remains available after validation failure')
  render(failed,'crystal-world-help-after-error',false)
  local itemCfg=R.defaults(game);itemCfg.field_items='LOGIC_RANDOM'
  local items=screens[UI.WORLD].new(game,{cfg=itemCfg})
  for i,row in ipairs(items.items) do if row.value=='field_items' then items.index=i;break end end
  for step=1,5 do items.onChoose(items.items[items.index],items) end
  assert(itemCfg.field_items=='LOGIC_RANDOM' and itemCfg.safety=='SAFE','Logical random survives a complete lap through Chaos')
  render(items,'crystal-field-items-after-wrap',false)
  items:helpLayout();items.helpFocus=true;items.helpScroll=items.helpMax
  render(items,'crystal-field-items-guide-end',false)
  local keysCfg=R.defaults(game);keysCfg.field_items='CHAOS';keysCfg.safety='CHAOS'
  local keys=screens[UI.WORLD].new(game,{cfg=keysCfg})
  for i,row in ipairs(keys.items) do if row.value=='progression_items' then keys.index=i;break end end
  keys:sync();render(keys,'crystal-keys-chaos',true)
  keys.onAdjust(keys.items[keys.index],keys,-1)
  assert(keysCfg.safety=='SAFE' and keysCfg.field_items=='LOGIC_RANDOM','Keys/HMs can select Safe directly')
  keys:sync();render(keys,'crystal-keys-safe',true)
  keys:helpLayout();keys.helpFocus=true;keys.helpScroll=keys.helpMax
  render(keys,'crystal-keys-guide-end',false)
  local levels=screens[UI.WILDS].new(game,{cfg=cfg})
  for i,row in ipairs(levels.items) do if row.value=='wild_levels' then levels.index=i;break end end
  levels:sync();render(levels,'crystal-start-level-guide',true)
  levels:helpLayout();levels.helpFocus=true;levels.helpScroll=levels.helpMax
  render(levels,'crystal-start-level-guide-end',false)
  print('PASS: actual LOVE rendering and font bounds for thirty-four menu views')
  love.event.quit(0)
end
