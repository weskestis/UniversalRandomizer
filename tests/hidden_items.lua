-- Trainer reward locations, native identities and independent progression proofs.
-- World records use the established synthetic audit fixture plus pinned portals.
local root=os.getenv('MOD_SOURCE') or 'mod'
local base=os.getenv('MOD_BASE') or 'dist/baseline/mod'
local host=os.getenv('HOST_SOURCE') or '../host-source'
package.path=host..'/?.lua;'..package.path
unpack=table.unpack or unpack
dofile('tests/support/bit54.lua')
local version,gen='red',1
package.loaded['src.core.GameVersion']={get=function() return version end,generation=function() return gen end,isYellow=function() return version=='yellow' end}
local Core=dofile(base..'/core.lua')
local I=dofile(root..'/progression_items.lua')(Core)
local L=dofile(root..'/logic_graph.lua')(Core)
local G1=dofile(root..'/gen1_world.lua')(Core)
local G2=dofile(root..'/gen2_world.lua')(Core)
local Worlds=dofile(root..'/worlds.lua')(G1,G2)
local A=dofile(root..'/adaptive_gyms.lua')(Core,Worlds)
local hooks,events=require('src.mods.Hooks').new(),require('src.mods.Events').new()
local saved={}
local mod={hooks={wrap=function(_,n,f,p) return hooks:wrap(n,f,p,'universal_randomizer') end},events={on=function(_,n,f,p) return events:on(n,f,p,'universal_randomizer') end},
 save={get=function(_,k,d) if saved[k]==nil then return d end;return saved[k] end,set=function(_,k,v) saved[k]=v end},
 log={error=function(_,fmt,...) error(fmt:format(...)) end},world={removeNpc=function() end}}
local R=dofile(root..'/randomizer.lua')(mod,Core,dofile(base..'/adapters.lua'),I,L,Worlds,A)
local fixture=dofile('tests/support/audit_fixture.lua')({Core=Core,I=I,L=L,R=R,mod=mod,hooks=hooks,events=events,setVersion=function(g,v) gen,version=g,v end})
local native=dofile('tests/support/adaptive_native.lua')
local checks,plans=0,0
local function check(v,msg) assert(v,msg);checks=checks+1 end
local function stable(t)
 if type(t)~='table' then return tostring(t) end
 local out={};for _,k in ipairs(Core.sortedKeys(t)) do out[#out+1]=tostring(k)..'='..stable(t[k]) end
 return '{'..table.concat(out,',')..'}'
end
local function gameFor(v)
 local generation=(v=='red' or v=='blue' or v=='yellow') and 1 or 2
 local game=fixture(generation,v)
 local data=native[v=='blue' and 'red' or v=='silver' and 'gold' or v]
 -- Convert the synthetic world encounter/trade references to native species.
 local dex={};for id,d in pairs(data.pokemon) do dex[d.dex]=id end
 local function rewrite(t)
  for k,x in pairs(t) do
   if type(x)=='table' then rewrite(x)
   elseif type(x)=='string' and x:match('^MON_%d+$') then t[k]=assert(dex[tonumber(x:match('%d+'))]) end
  end
 end
 rewrite(game.data)
 for k,d in pairs(data) do game.data[k]=Core.copy(d) end
 game.data.items.BERRY={index=173,name='BERRY'};game.data.items.LEFTOVERS={index=146,name='LEFTOVERS'}
 game.data.type_chart={matchups={},types={}}
 game.save.pokedex.seen={}
 local ports=generation==1 and dofile(v=='yellow' and 'tests/support/gen1_portals_yellow.lua' or 'tests/support/gen1_portals.lua')
   or dofile('tests/support/gen2_portals.lua')[v=='crystal' and 'crystal' or 'gold']
 local maps=generation==1 and game.data.maps or game.data.gen2Maps
 for id,def in pairs(ports) do
  maps[id]=maps[id] or {id=id,objects={}}
  for k,x in pairs(def) do maps[id][k]=Core.copy(x) end
 end
 game.data.sprites={}
 for _,g in ipairs((generation==1 and G1 or G2).gyms) do
  game.data.sprites[g.sprite or g.name]={}
 end
 for class,t in pairs(game.data.trainers or {}) do t.pic='native/'..class..'.png' end
 return game
end


I.installHardcoded(mod,R);R.installHooks();Worlds.install(mod,R,I)
require('src.mods.Runtime').install(events,hooks)
local changed,chaosKeys=0,0
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
 for _,mode in ipairs({'OFF','SAFE','CHAOS'}) do for _,field in ipairs({'UNCHANGED','RANDOM','LOGIC_RANDOM'}) do
  local game=gameFor(v);local refs={}
  if gen==1 then
   game.data.field.hiddenItems.ROUTE_1={{item='POTION',x=1,y=1},{item='ANTIDOTE',x=2,y=1},{coins=100,x=3,y=1}}
   refs=game.data.field.hiddenItems.ROUTE_1
  else
   local m=game.data.gen2Maps.ROUTE_29;m.bgEvents={}
   for i=1,2 do local h={item=i==1 and 'POTION' or 'ANTIDOTE',event=900+i};refs[i]=h;m.bgEvents[i]={kind=7,x=i,y=1,hiddenItem=h} end
   m.bgEvents[3]={kind=7,x=5,y=1,hiddenItem={item='POTION',event=901}}
   -- The Machine Part uses a conditional native script in some caches and
   -- a hidden-item row in others; test the real hidden pickup representation.
   local gym=game.data.gen2Maps.CERULEAN_GYM
   gym.objects={};gym.bgEvents={{kind=7,x=2,y=2,hiddenItem={item='MACHINE_PART',event=999}}}
  end
  local originals=stable(refs)
  local cfg=R.defaults(game);cfg.hidden_items=mode;cfg.field_items=field;cfg.safety=mode=='CHAOS' and 'CHAOS' or 'SAFE'
  if field=='LOGIC_RANDOM' then cfg.trainer_checks=cfg.safety;cfg.gym_entrances=cfg.safety;cfg.dungeon_entrances=cfg.safety end
  local a,why=R.generate(game,cfg,37);check(a,v..' '..mode..' '..field..': '..tostring(why))
  check(R._validateHiddenItems(game,a.cfg),'hidden bindings valid')
  if mode=='OFF' then
   check(stable(refs)==originals,'Off is byte-for-byte vanilla hidden pickups')
   if gen==2 then
    check(game.data.gen2Maps.CERULEAN_GYM.bgEvents[1].hiddenItem.item=='MACHINE_PART','Off keeps hidden quest reward vanilla')
    if a.logicItemPlan then check(a.logicItemPlan.locations.CERULEAN_MACHINE=='MACHINE_PART','validator fixes Machine Part when hidden Off') end
   end
  elseif stable(refs)~=originals then changed=changed+1 end
  if gen==2 then
   local rows=game.data.gen2Maps.ROUTE_29.bgEvents
   check(rows[1].hiddenItem.item==rows[3].hiddenItem.item,'shared hidden event has one reward')
  else check(refs[3].coins==100,'hidden coins untouched') end
  local outcomes={};for _,row in ipairs(game.data._urHiddenItems.rows) do outcomes[row.key]=row.target end
  local first=game.data._urHiddenItems.rows[1];local value=first.refs[1].parent.item
  first.refs[1].parent.item='INVALID_ITEM'
  check(not R._validateHiddenItems(game,a.cfg),'invalid hidden payload rejected')
  first.refs[1].parent.item=value
  check(R.commit(a),'hidden setting saved');R.abortSavedActivation(game)
  local resumed,err=R.activateSaved(game);check(resumed,tostring(err))
  local loaded={};for _,row in ipairs(game.data._urHiddenItems.rows) do loaded[row.key]=row.target end
  check(stable(loaded)==stable(outcomes),'cold Continue preserves hidden assignments')
  check(resumed.cfg.hidden_items==mode,'hidden mode survives Continue')
 end end
 -- Legacy Continue keeps its old shared hidden/field policy and fingerprint.
 local oldGame=gameFor(v);local cfg=R.defaults(oldGame);cfg.hidden_items=nil;cfg.field_items='RANDOM'
 local a,why=R.generate(oldGame,cfg,42);check(a,tostring(why));check(a.cfg.hidden_items==nil,'missing old setting stays legacy')
 check(R.commit(a),'old policy saved');R.abortSavedActivation(oldGame)
 local restored,err=R.activateSaved(oldGame);check(restored and restored.cfg.hidden_items==nil,tostring(err))
 print('hidden items',v,'passed')
end
check(changed>20,'hidden items independently randomize')
print(('Hidden items: %d checks; %d changed layouts'):format(checks,changed))
