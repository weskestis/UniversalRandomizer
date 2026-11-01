-- Drive the actual setup screens with controller input and a bounded drawing
-- facade. The separate LOVE preview renders these same menu methods.
local root=os.getenv('MOD_SOURCE') or 'mod'
local base=os.getenv('MOD_BASE') or '../randomizer'
local Core=dofile(base..'/core.lua')
package.loaded['src.core.GameVersion']={get=function() return 'red' end,generation=function() return 1 end}
local clock=0;local draws={}
local G={}
function G.newFont(size) return {getWidth=function(_,s) return #s*size*.52 end} end
for _,name in ipairs({'setColor','setFont','push','pop','translate','scale'}) do G[name]=function() end end
function G.print(s,x,y) draws[#draws+1]={text=s,x=x,y=y} end
function G.rectangle() end
love={graphics=G,timer={getTime=function() return clock end}}
local n=0
local function check(v,s) assert(v,s);n=n+1 end
local saved,screens,hooks={},{},{}
local stack={states={}}
function stack:push(s) self.states[#self.states+1]=s end
function stack:top() return self.states[#self.states] end
function stack:pop() return table.remove(self.states) end
local input={pressed={},held={}}
function input:wasPressed(k) return self.pressed[k] end
function input:isDown(k) return self.held[k] end
local game={data={},save={flags={}},stack=stack,input=input}
local mod={game=game,path=root,save={get=function(_,k,d) if saved[k]==nil then return d end;return saved[k] end,set=function(_,k,v) saved[k]=v end},
 content={screens={register=function(_,id,s) screens[id]=s end}},hooks={wrap=function(_,name,fn) hooks[name]=fn end},
 log={error=function(_,fmt,...) error(fmt:format(...)) end},read=function(_,path) local f=assert(io.open(root..'/'..path));local s=f:read('*a');f:close();return s end,ui={}}
function mod.ui.push(g,id,opts) local m=screens[id].new(g,opts);stack:push(m);return m end
local R=dofile(root..'/randomizer.lua')(mod,Core,{})
local cleared,committed,ended=0,0,0
R.clear=function() cleared=cleared+1 end
R.preflight=function(g,cfg) return true,nil,R.normalizedConfig(cfg,g) end
R.beginGenerate=function(g,cfg) return {stage=0,cfg=cfg} end
R.stepGenerate=function(h)
 h.stage=h.stage+1;h.label='Stage '..h.stage
 if h.stage==14 then h.done=true;h.active={fingerprint='test',cfg=h.cfg} end
 return h
end
R.commit=function() committed=committed+1;return true end
local UI=dofile(root..'/ui.lua')(mod,Core,R)
local function frame(key,dt)
 input.pressed={};if key then input.pressed[key]=true end
 clock=clock+(dt or 1/60)
 local m=stack:top();if m then m:update(dt or 1/60) end
 input.pressed={};m=stack:top();if m then m:draw() end
end
local function selectRow(value)
 local m=stack:top()
 for i,row in ipairs(m.items) do if row.value==value then m.index=i;m:sync();return row end end
 error('missing row '..value)
end
local setup=mod.ui.push(game,UI.SETUP,{onDone=function() ended=ended+1 end})
check(select(1,setup:uiSize())==640 and select(2,setup:uiSize())==360,'Gen1 full modern canvas')
check(setup:drawsWidescreen(),'Gen2 uses explicit compositor path')
selectRow('wilds');frame('a')
local wilds=stack:top();selectRow('wild_randomness');frame('right')
check(wilds.items[1].right=='Truly random','right selects visible unrestricted mode')
for _,row in ipairs(wilds.items) do check(row.value~='wild_evolution' and row.value~='bst_match','unrestricted wilds do not offer conflicting limits') end
frame('select');check(wilds.helpFocus,'SELECT focuses explanation')
local before=wilds.items[1].right;frame('down');frame('right')
check(wilds.helpScroll==wilds.helpMax and wilds.helpMax>0,'manual help can reach the end')
check(wilds.items[1].right==before,'reading does not change settings')
frame('b');check(stack:top()==wilds and not wilds.helpFocus,'B leaves guide before leaving settings')
frame('b');frame()
check(stack:top()==setup and setup.items[2].right()=='Truly random','choice persists and setup summary refreshes')
selectRow('world');frame('a');local world=stack:top();selectRow('random_start');frame('right')
check(world.items[1].right=='Logic','Random Start is first and clearly enabled')
local body=world:helpContent()
check(body:find("Parcel",1,true) and body:find('first lab exit',1,true),'Gen1 portal prerequisite is explained')
frame('b');frame();check(setup.items[4].right()=='Start: Logic','setup shows actual start setting')
selectRow('battle');frame('a');local battle=stack:top();selectRow('trainers');frame('right')
check(battle.items[1].right=='Similar strength','right advances trainer option')
frame('left');check(battle.items[1].right=='Random','left reverses trainer option')
frame('b');selectRow('pokemon');frame('a');local pokemon=stack:top()
-- Held navigation uses elapsed real time, not the number of sped-up frames.
pokemon.index=1;input.held.down=true;frame('down');local after=pokemon.index
for i=1,100 do frame(nil,0) end
check(pokemon.index==after,'game speed cannot accelerate held input')
frame(nil,.2);frame(nil,.2);frame(nil,.02)
check(pokemon.index==after+1,'real-time hold repeat advances at controlled cadence')
input.held={};frame('b')
-- Every selectable option includes concrete help, not a clipped footer.
for _,id in ipairs({UI.POKEMON,UI.BATTLE,UI.WORLD,UI.RUN,UI.WILDS}) do
 local cfg=R.defaults(game);cfg.seed_mode='MANUAL';cfg.bst_match=true
 local menu=screens[id].new(game,{cfg=cfg})
 for _,row in ipairs(menu.items) do check(row.help and #row.help>30,'setting has substantial help: '..row.label) end
end
-- Scrolling keeps every word, including long error paths; both directions
-- and automatic scrolling eventually expose the final line.
local Menu=dofile(root..'/menu.lua')
local token=string.rep('long_error_path_',30)..'END_OF_ERROR'
local m=Menu.new(game,'Failure details',{{label='Retry',help=token}})
stack:push(m);frame();check(m.helpMax>0,'long errors overflow into scrollable guide')
local joined=table.concat(m.helpLines,'')
check(joined==token,'wrapping preserves the complete long error')
for _,line in ipairs(m.helpLines) do check(G.newFont(14):getWidth(line)<=220,'each guide line stays inside panel') end
for i=1,31 do frame(nil,.2) end
check(m.helpScroll>0,'idle explanations automatically scroll')
frame('select');frame('right');check(m.helpLines[#m.helpLines]:find('END_OF_ERROR',1,true),'end of error remains readable')
frame('b');frame('b')
local utf=Menu.new(game,'Unicode error',{{label='Read',help=string.rep('Pokémon_',60)}})
utf:helpLayout()
check(table.concat(utf.helpLines,'')==string.rep('Pokémon_',60),'Unicode text is preserved')
for _,line in ipairs(utf.helpLines) do
 local b=line:byte(1);check(not b or b<128 or b>=192,'wrapped lines start on a whole glyph')
end
-- Back must not silently play vanilla or consume the intro callback.
frame('b');local confirmation=stack:top()
check(confirmation~=setup and cleared==0 and ended==0,'Back opens explicit vanilla confirmation')
frame('b');check(stack:top()==setup and cleared==0,'canceling confirmation keeps setup')
-- Validation is locked against Back/re-entry until its one handle finishes.
selectRow('begin');frame('a');frame('b');frame('a')
check(stack:top()==setup and setup:isLocked() and ended==0,'validation cannot be dismissed or restarted')
for i=1,14 do hooks['input.step'](function() end,game,1/60) end
check(committed==1 and ended==1 and stack:top()==nil,'validation commits and releases intro exactly once')
-- The explicit vanilla choice still works.
mod.ui.push(game,UI.SETUP,{onDone=function() ended=ended+1 end});frame('b');selectRow('vanilla');frame('a')
check(cleared==1 and ended==2 and stack:top()==nil,'confirmed vanilla closes both menus exactly once')
print('PASS: '..n..' modern menu navigation, help, scrolling and validation checks')
