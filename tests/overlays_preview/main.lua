-- A CI renderer must fail the job, never wait on LOVE's interactive error screen.
function love.errorhandler(message)
 io.stderr:write(debug.traceback(tostring(message), 2), '\n')
 os.exit(1)
end

function love.load()
 local repo=assert(os.getenv('UR_REPO'));local root=os.getenv('MOD_SOURCE') or repo..'/mod';local base=os.getenv('MOD_BASE') or repo..'/dist/baseline/mod'
 if root:sub(1,1)~='/' then root=repo..'/'..root end;if base:sub(1,1)~='/' then base=repo..'/'..base end
 local host=os.getenv('HOST_SOURCE') or repo..'/../host-source';package.path=host..'/?.lua;'..package.path
 local out=assert(os.getenv('UR_MENU_OUTPUT'));local Core=dofile(base..'/core.lua');local Menu=dofile(root..'/menu.lua')
 local saved={};local game={data={pokemon={},moves={}},save={party={},inventory={},player={badges={},kantoBadges={}}},stack={states={}}}
 function game.stack:push(s) self.states[#self.states+1]=s end
 function game.stack:pop() return table.remove(self.states) end
 function game.stack:top() return self.states[#self.states] end
 local mod={game=game,save={get=function(_,k,d) if saved[k]==nil then return d end;return saved[k] end,set=function(_,k,v) saved[k]=v end}}
 local G1=dofile(root..'/gen1_world.lua')(Core);local G2=dofile(root..'/gen2_world.lua')(Core);local W=dofile(root..'/worlds.lua')(G1,G2)
 local A=dofile(root..'/adaptive_gyms.lua')(Core,W);local R=dofile(root..'/randomizer.lua')(mod,Core,{},nil,nil,W,A)
 local T=dofile(root..'/run_tools.lua')(mod,Core,R,W,A);R.RunTools=T
 local O=dofile(root..'/overlays.lua')(mod,Core,R,Menu);local U=dofile(root..'/run_tools_ui.lua')(mod,Core,R,Menu,O)
 local a={game=game,generation=1,version='red',seed=131,cfg=R.defaults(game)};R.active=function() return a end;T.start(a)
 game.data.pokemon.SQUIRTLE={types={'WATER'},growthRate='MEDIUM_SLOW'}
 game.data.moves={SURF={name='SURF',type='WATER',power=95,accuracy=100,pp=15,description='A strong Water attack. Also lets the player cross water after meeting native badge requirements.'},CUT={name='CUT',type='NORMAL',power=50,accuracy=95,pp=30}}
 local mon={species='SQUIRTLE',level=5,exp=135,hp=20,stats={hp=21,attack=12,defense=13,speed=10},moves={{id='CUT',pp=30}}};game.save.party={mon}
 local st=T.state(a);st.seconds=4279;st.blackouts=3;st.caught=7;st.splits={{label='Pewter Gym',seconds=940},{label='Cerulean Gym',seconds=2680}};st.items={HM_CUT={seconds=400,map='VERMILION_CITY'}}
 local G=love.graphics;local count=0
 local function save(canvas,name)
  G.setCanvas();local bytes=canvas:newImageData():encode('png'):getString();local f=assert(io.open(out..'/'..name..'.png','wb'));f:write(bytes);f:close();count=count+1
 end
 local function menu(s,name)
  local canvas=G.newCanvas(640,360);G.setCanvas(canvas);G.clear();s:draw();save(canvas,name)
 end
 local s=U.open(game,a.cfg);menu(s,'run-tools-setup')
 s.onChoose({value='presets'});menu(game.stack:top(),'preset-list')
 local preset=game.stack:top();preset.onChoose(preset.items[2]);menu(game.stack:top(),'preset-change-preview')
 game.stack.states={};s=U.open(game);menu(s,'run-tools-active')
 s.onChoose({value='goals'});menu(game.stack:top(),'goal-progress')
 game.stack.states={};s=U.open(game);s.onChoose({value='diagnostic'});menu(game.stack:top(),'diagnostic-report')
 game.stack.states={};s=U.open(game);s.onChoose({value='recap'});menu(game.stack:top(),'run-recap')
 for _,size in ipairs({{1280,720,'pc'},{640,360,'phone-landscape'},{390,844,'phone-portrait'}}) do
  local w,h,name=size[1],size[2],size[3]
  game.stack.states={};game.stack:push(O.editor(game))
  local canvas=G.newCanvas(w,h);G.setCanvas(canvas);G.clear();O.draw(game,{width=w,height=h});save(canvas,'overlay-editor-'..name)
  local rows,all,family=O.layout(w,h);for _,d in pairs(rows) do d.shown=true end;O.store(rows,all,family)
  game.stack.states={};game.stack:push({phase='moveSelect',player={mon=mon,curMoves={{id='SURF'}},curTypes={'WATER'}},moveIndex=1})
  O.battle={kind='wild',player={mon=mon},enemy={mon=mon}}
  canvas=G.newCanvas(w,h);G.setCanvas(canvas);G.clear(.09,.12,.16,1);O.draw(game,{width=w,height=h});save(canvas,'overlay-hud-'..name)
 end
 game.stack.states={};game.stack:push({newMoveId='SURF',mon=mon,index=1,selecting=true});O.details(game,'learn');menu(game.stack:top(),'learn-comparison-detail')
 print('PASS: actual LOVE rendering for '..count..' run-tools and overlay views')
 love.event.quit(0)
end
