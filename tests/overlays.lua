local root=os.getenv('MOD_SOURCE') or 'mod'
local base=os.getenv('MOD_BASE') or 'dist/baseline/mod'
local host=os.getenv('HOST_SOURCE') or '../host-source'
package.path=host..'/?.lua;'..package.path
unpack=table.unpack or unpack
dofile('tests/support/bit54.lua')
local Core=dofile(base..'/core.lua');local Menu=dofile(root..'/menu.lua')
local saved={};local mod={save={get=function(_,k,d) return saved[k] or d end,set=function(_,k,v) saved[k]=v end}}
local R={active=function() end};local O=dofile(root..'/overlays.lua')(mod,Core,R,Menu)
local checks=0;local function check(v,msg) assert(v,msg);checks=checks+1 end
local width,height=1280,720
love={graphics={getDimensions=function() return width,height end},timer={getTime=function() return 0 end}}
local game={data={pokemon={},moves={}},save={party={}},stack={states={}},input={wasPressed=function() return false end}}
function game.stack:top() return self.states[#self.states] end
function game.stack:push(s) self.states[#self.states+1]=s end
function game.stack:pop() return table.remove(self.states) end
for _,dimensions in ipairs({{1280,720},{640,360},{390,844},{2560,1080}}) do
 width,height=dimensions[1],dimensions[2]
 local rows,all,family=O.layout(width,height)
 for _,id in ipairs(O.panels) do
  for _,scale in ipairs({.5,1,2.5}) do rows[id].scale=scale
   for _,pos in ipairs({0,.5,1}) do rows[id].x=pos;rows[id].y=pos
    local b=O.bounds(id,rows[id],width,height)
    check(b.x>=0 and b.y>=0 and b.x+b.w<=width and b.y+b.h<=height,'panel fits viewport at every scale/edge')
   end
  end
 end
 local s=O.editor(game);game.stack:push(s);local d=rows.run;d.auto=false;d.scale=1;d.x=.2;d.y=.2;O.store(rows,all,family)
 local b=O.bounds('run',d,width,height);O.hit={{id='run',b=b}};O.buttons={}
 local function pointer(phase,x,y,id) return O.pointer(game,{phase=phase,x=x,y=y,id=id or 'finger',source='touch'}) end
 check(pointer('pressed',b.x+20,b.y+20),'touch grabs overlay')
 check(pointer('moved',b.x+60,b.y+50),'touch drag consumed')
 pointer('released',b.x+60,b.y+50)
 local changed=O.layout(width,height).run;check(changed.x>.2 and changed.y>.2,'drag position persists')
 b=O.bounds('run',changed,width,height);O.hit={{id='run',b=b}}
 pointer('pressed',b.x+b.w-5,b.y+b.h-5,'mouse')
 pointer('moved',b.x+b.w+30,b.y+b.h+30,'mouse');pointer('released',b.x+b.w+30,b.y+b.h+30,'mouse')
 check(O.layout(width,height).run.scale>1,'mouse corner resize persists')
 pointer('pressed',b.x+20,b.y+20);pointer('cancelled',0,0);check(O.capture==nil,'focus loss releases pointer')
 local wasShown=O.layout(width,height).run.shown;O.editAction(s,3);check(O.layout(width,height).run.shown~=wasShown,'show toggle persists')
 O.editAction(s,1);check(game.stack:top()==nil,'Done closes editor')
end
width,height=1280,720;local l=O.layout(width,height);width,height=390,844;local p=O.layout(width,height)
check(l~=p,'portrait and landscape independent')
-- Pointer activation requires a complete click on the same row and menu.
local count=0;local rows={};for i=1,20 do rows[i]={label='Setting '..i} end
local menu=Menu.new(game,'Touch menu',rows,{onChoose=function() count=count+1 end})
menu:pointer({phase='pressed',id=1},40,85);menu:pointer({phase='released',id=1},40,85);check(count==1,'single finger tap chooses exactly once')
menu:pointer({phase='pressed',id=2},40,85);menu:pointer({phase='moved',id=2},40,10);menu:pointer({phase='released',id=2},40,10);check(count==1,'scroll drag never activates a row')
menu:pointer({phase='pressed',id=3},40,85);menu:pointer({phase='cancelled',id=3},40,85);menu:pointer({phase='released',id=3},40,85);check(count==1,'cancelled tap never chooses')
menu.locked=true;menu:pointer({phase='pressed',id=4},40,85);menu:pointer({phase='released',id=4},40,85);check(count==1,'validation blocks taps')
-- Native move learning is inspected, never replaced or answered here.
game.data.moves={CUT={name='CUT',power=50,type='NORMAL',accuracy=95,pp=30},SURF={name='SURF',power=95,type='WATER',accuracy=100,pp=15}}
game.data.pokemon.SQUIRTLE={types={'WATER'},growthRate='MEDIUM_SLOW'}
local m={species='SQUIRTLE',level=5,exp=135,moves={{id='CUT',pp=1}}}
local learning={mon=m,newMoveId='SURF',selecting=true,index=1,onDone=function() error('must never invoke') end}
game.stack:push(learning);local before=Core.copy(m)
local mon,new,old=O.learn(game);check(mon==m and new=='SURF' and old=='CUT','Gen 1 comparison reads native selected moves')
local lines=O.model(game,'learn',false);check(lines[1]:find('SURF',1,true),'comparison includes new move')
check(m.moves[1].id=='CUT' and m.moves[1].pp==1,'HM and current PP untouched')
check(O.moveLines(game,'SURF',m)[2]:find('STAB',1,true),'move info uses current native types')
game.stack:pop();game.data.gen2Encounters={};game.stack:push({phase='choose-forget',pendingLearn={index=1,move='SURF'},battle={party={m}},forgetIndex=1})
mon,new,old=O.learn(game);check(mon==m and new=='SURF' and old=='CUT','Gen 2 comparison reads native learning phase')
m.level=100;local f,label=O.exp(game,m);check(f==1 and label:find('MAX',1,true),'max-level EXP bounded')
print('PASS: '..checks..' overlay layout / touch / mouse / native move checks')

-- EXP comes from the native curve and species state, never a guessed percentage.
game.data.gen2Encounters=nil;m.level=5;m.exp=135+10
local Growth=require('src.pokemon.Growth')
local low=Growth.expForLevel('MEDIUM_SLOW',5);local high=Growth.expForLevel('MEDIUM_SLOW',6)
local fraction=O.exp(game,m);check(math.abs(fraction-(m.exp-low)/(high-low))<.00001,'Gen 1 native growth calculation')
game.data.gen2Encounters={};game.data.pokemon.SQUIRTLE.growthRate='GROWTH_MEDIUM_SLOW'
game.data.growth_rates={GROWTH_MEDIUM_SLOW={expForLevel=function(lv) return Growth.expForLevel('MEDIUM_SLOW',lv) end}}
m.experience=m.exp;m.exp=nil;fraction=O.exp(game,m);check(math.abs(fraction-(m.experience-low)/(high-low))<.00001,'Gen 2 native growth registry and experience field')
O.battle={wild=true,enemy={species='SQUIRTLE',dvs={attack=2,defense=10,speed=10,special=10}}}
local Mon=require('src.battle.gen2.Mon');local roll=Mon.isShiny;Mon.isShiny=function() error('HUD must not roll shininess') end
local status=O.model(game,'encounter',false);check(status[1]:find('SHINY',1,true),'native shiny state without RNG hook')
O.battle.enemy.shiny=false;status=O.model(game,'encounter',false);check(not status[1]:find('SHINY',1,true),'explicit native shiny flag respected')
Mon.isShiny=roll
check(O.effectDescription({effect='ATTACK_DOWN1_EFFECT'})=="Lowers the target's Attack by one stage.",'native effect shown as plain language')
print('PASS: '..checks..' overlay checks including native EXP and RNG-free shiny indication')
