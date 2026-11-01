-- Render the actual menu without copyrighted game/ROM data.
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
  local R=dofile(root..'/randomizer.lua')(mod,Core,{})
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
  gen=2;version='crystal';game.data.gen2Encounters={}
  render(screens[UI.WILDS].new(game,{cfg=cfg}),'crystal-wide',true)
  local m=screens[UI.WILDS].new(game,{cfg=cfg});m:helpLayout();m.helpFocus=true;m.helpScroll=m.helpMax
  render(m,'guide-end',false)
  R.preflight=function()
    return false,'SAFE key/HM logic requires Badges: Vanilla or Safe. Choose one under World + items, or choose Progression safety: Chaos for unchecked placements.'
  end
  saved.last_config={random_start='OFF',badges='CHAOS',safety='SAFE',field_items='SHUFFLE',gift_items='RANDOM',progression_items=true}
  local failed=screens[UI.SETUP].new(game,{})
  failed.index=6;failed.onChoose(failed.items[6],failed)
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
  print('PASS: actual LOVE rendering and font bounds for fourteen menu views')
  love.event.quit(0)
end
