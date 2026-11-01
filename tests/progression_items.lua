local root=os.getenv('MOD_SOURCE') or 'mod'
local base=os.getenv('MOD_BASE') or '../randomizer'
local host=os.getenv('HOST_SOURCE') or '../host-source'
package.path=host..'/?.lua;'..package.path
unpack=table.unpack or unpack
local gen,version=1,'red'
package.loaded['src.core.GameVersion']={get=function() return version end,generation=function() return gen end,isYellow=function() return version=='yellow' end}
local Core=dofile(base..'/core.lua')
local I=dofile(root..'/progression_items.lua')(Core)
local Hooks=require('src.mods.Hooks');local Events=require('src.mods.Events')
local hooks,events=Hooks.new(),Events.new()
local mod={hooks={wrap=function(_,n,f,p) return hooks:wrap(n,f,p,'universal_randomizer') end},events={on=function(_,n,f,p) return events:on(n,f,p,'universal_randomizer') end}}
local R=dofile(root..'/randomizer.lua')(mod,Core,dofile(base..'/adapters.lua'),I)
local n=0
local function check(ok,msg) assert(ok,msg);n=n+1 end
check(R.defaults().progression_items,'new runs enable logical keys/HMs')
check(R.normalizedConfig({}).progression_items==false,'saved runs keep their old placements')
check(R.normalizedConfig({progression_items=true}).progression_items,'explicit setting persists')
-- Independent graph examples: both a direct self-lock and a two-key cycle.
local locks={{id='cave',item='SURF',needs={'SURF'}},{id='mountain',item='CUT',needs={'CUT'}}}
check(not I.solve(locks,{},{}),'self-locked HMs rejected')
check(not I.solve(locks,{cave='CUT',mountain='SURF'},{}),'circular HM chain rejected')
local chain={{id='start',item='CUT',needs={}},{id='forest',item='SURF',needs={'CUT'}},{id='island',item='KEY',needs={'SURF'}}}
local pass,proof=I.solve(chain,{},{{token='DONE',needs={'KEY'}}},nil,'DONE')
check(pass and #proof.spheres==3,'three independently reachable collection spheres')
local badRules={{token='USE_SURF',needs={'HM_SURF','BADGE_FOG'}},{token='BADGE_FOG',needs={'USE_SURF'}}}
check(not I.solve({{id='beach',item='HM_SURF'}},{},badRules,nil,'USE_SURF'),'badge dependency cannot certify itself')

local g1rules=I.rules(1,{gymToBadge={['OPP_BROCK#1']='CASCADEBADGE',['OPP_MISTY#1']='BOULDERBADGE'}})
check(I.solve(I.catalog(1,'red'),{},g1rules,nil,'@CHAMPION'),'native trainer-key badge mapping accepted')
local g1lock=I.rules(1,{gymToBadge={['OPP_BROCK#1']='EARTHBADGE',['OPP_GIOVANNI#3']='BOULDERBADGE'}})
check(not I.solve(I.catalog(1,'red'),{},g1lock,nil,'@CHAMPION'),'late Flash badge route rejected')
local g2lock=I.rules(2,{gymToBadge={ZEPHYR='RISING',RISING='ZEPHYR'}})
check(not I.solve(I.catalog(2,'crystal'),{},g2lock,nil,'@POWER'),'Gen2 route badge dependency honored')

local start=os.clock();local chaosLocks=0
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
 local g=(v=='red' or v=='blue' or v=='yellow') and 1 or 2
 local locations=I.catalog(g,v);local rules=I.rules(g)
 local goal=g==1 and '@CHAMPION' or '@POWER'
 local expected={};for _,loc in ipairs(locations) do loc.shuffle=true;expected[loc.item]=(expected[loc.item] or 0)+1 end
 for seed=1,75 do
  local p,cert=I.place(locations,rules,seed,false,nil,goal)
  check(p and cert.checked and I.solve(locations,p,rules,nil,goal),'SAFE complete route '..v..'/'..seed)
  local count={};for _,item in pairs(p) do count[item]=(count[item] or 0)+1 end
  for item,num in pairs(expected) do check(count[item]==num,'required reward preserved exactly once: '..item) end
  if seed==1 then
   local again=I.place(locations,rules,seed,false,nil,goal)
   for key,item in pairs(p) do check(again[key]==item,'placement deterministic across reload') end
  end
  local chaos,uncert=I.place(locations,rules,seed,true,nil,goal)
  check(uncert.checked==false and uncert.mode=='CHAOS','CHAOS is explicitly unchecked')
  if not I.solve(locations,chaos,rules,nil,goal) then chaosLocks=chaosLocks+1 end
 end
end
check(chaosLocks>0,'CHAOS permits placements rejected by SAFE')
print(('Placement corpus: 450 SAFE seeds and 450 CHAOS seeds in %.2fs'):format(os.clock()-start))

local function fixture(g,v,numeric)
 local game={data={items={},pokemon={},maps={},gen2Maps=g==2 and {} or nil},save={inventory={},flags={},pokedex={owned={}},player={name='TEST'}}}
 local maps=g==2 and game.data.gen2Maps or game.data.maps
 for index,loc in ipairs(I.catalog(g,v)) do
  game.data.items[loc.item]={index=index,name=loc.item,keyItem=loc.item~='POTION',pocket=g==2 and (loc.item:match('^HM_') and 'TM_HM' or loc.item=='POTION' and 'ITEM' or 'KEY_ITEM') or nil}
  if loc.item:match('^HM_') then game.data.items[loc.item].teaches=loc.item:sub(4);game.data.items[loc.item].machine={kind='HM',move=loc.item:sub(4)} end
  local map=loc.maps[1];maps[map]=maps[map] or {objects={},bgEvents={}}
  if loc.kind=='field' then
   local value=numeric and index or loc.item
   if g==1 then table.insert(maps[map].objects,{item=value})
   elseif loc.id=='machine-part' then table.insert(maps[map].bgEvents,{hiddenItem={item=value,event=index}})
   else table.insert(maps[map].objects,{itemball={item=value},eventFlag=index}) end
  end
 end
 return game
end
local cfg=R.defaults();cfg.field_items='RANDOM';cfg.gift_items='RANDOM'
for g=1,2 do
 gen=g;version=g==1 and 'red' or 'crystal'
 for _,numeric in ipairs({false,true}) do
  local game=fixture(g,version,numeric)
  local plan=I.prepare(game,cfg,g,version)
  check(#plan.locations==#I.catalog(g,version),'all native profiles found')
  I.finish(game,cfg,77)
  check(I.validate(game),'field mutations agree with certificate')
  check(plan.changed>5,'shuffle moves multiple keys/HMs')
  for _,loc in ipairs(plan.locations) do
   if loc.kind=='gift' then
    local mapped,handled=I.gift(plan,loc.maps[1]:gsub('_',''),loc.actual)
    check(handled and mapped==loc.target,'normalized map and gift award match proof')
   end
   for _,ref in ipairs(loc.refs) do
    check(I.reserved(game,ref.parent,ref.key),'planned field reward excluded from ordinary RNG')
    check(type(ref.parent[ref.key])==(numeric and 'number' or 'string'),'native item representation preserved')
   end
  end
  local ref
  for _,loc in ipairs(plan.locations) do if #loc.refs>0 then ref=loc.refs[1];break end end
  ref.parent[ref.key]='CORRUPTED'
  check(not I.validate(game),'post-placement overwrite detected')
 end
end
-- A mixed setting must not quietly randomize the disabled item channel.
gen=1;version='red'
local game=fixture(1,'red');local fieldOnly=Core.copy(cfg);fieldOnly.gift_items='UNCHANGED'
local p=I.prepare(game,fieldOnly,1,'red');I.finish(game,fieldOnly,28)
for _,loc in ipairs(p.locations) do if loc.kind=='gift' then check(loc.actual==loc.target,'disabled gift channel unchanged') end end
local alias=fixture(2,'crystal');alias.data.items.HM_03={index=222,machine={kind='HM',move='SURF'}};alias.data.items.HM_SURF=nil
check(I.resolveItems(alias,2).HM_SURF=='HM_03','HM semantics resolved across cache naming')

-- Exercise the production staged generator, restoration and saved-seed rebuild.
for _,v in ipairs({'crystal','gold','silver','red','blue','yellow'}) do
 gen=(v=='red' or v=='blue' or v=='yellow') and 1 or 2;version=v
 local full=fixture(gen,v)
 local starters=gen==1 and (v=='yellow' and {'PIKACHU','EEVEE','MON_3'} or {'BULBASAUR','CHARMANDER','SQUIRTLE'}) or {'CHIKORITA','CYNDAQUIL','TOTODILE'}
 for dex=1,(gen==1 and 151 or 251) do
  local id=starters[dex] or ('MON_'..dex)
  full.data.pokemon[id]={index=dex,dex=dex,types={'NORMAL'},baseStats={hp=50,attack=50,defense=50,speed=50,special=50,specialAttack=50,specialDefense=50},level1Moves={'TACKLE'},tmhm={},evolutions={}}
 end
 full.data.pokemon[starters[1]].evolutions={{species='MON_4'}}
 full.data.moves={TACKLE={index=33,power=40,type='NORMAL'}}
 for i=1,25 do full.data.moves['MOVE_'..i]={index=i,power=40,type='NORMAL'} end
 for _,def in pairs(full.data.items) do if def.teaches then full.data.moves[def.teaches]={power=40,type='NORMAL'} end end
 for i=1,12 do full.data.items['FILLER_'..i]={name='Filler',price=100} end
 local maps=gen==1 and full.data.maps or full.data.gen2Maps
 maps.TEST={objects=gen==1 and {{item='FILLER_1'}} or {{itemball={item='FILLER_1'}}}}
 local native=Core.copy(full)
 local settings=R.defaults();settings.field_items='SHUFFLE';settings.gift_items='RANDOM';settings.mart_safety=false
 settings.starters='UNCHANGED';settings.statics='UNCHANGED';settings.trainers='UNCHANGED'
 local function generate(seed)
  local state,reason=R.beginGenerate(full,settings,seed or 99)
  check(state~=nil,reason or 'staged preflight')
  for i=1,14 do R.stepGenerate(state) end
  check(state.done and state.active~=nil,state.error or 'staged generation completes')
  return state.active
 end
 local first=generate()
 check(first.itemPlan and first.itemPlan.proof.checked,'active run retains checked item placement')
 check(Core.tableHas(full.data.pokemon[starters[1]].tmhm,'SURF'),'starter can learn progression HM')
 check(Core.tableHas(full.data.pokemon.MON_4.tmhm,'SURF'),'evolved starter can learn progression HM')
 local saved=Core.copy(first.itemPlan.placement)
 local second=generate()
 for key,item in pairs(saved) do check(second.itemPlan.placement[key]==item,'restoration and regeneration retain placement') end
 settings.progression_items=false
 local disabled=generate()
 check(disabled.itemPlan==nil,'disabling feature clears stale plan')
 check(not Core.tableHas(full.data.pokemon.MON_4.tmhm,'SURF'),'restoration removes feature-specific HM compatibility')
 -- The reported Crystal failure: SAFE badges with a normal start used an
 -- unrestricted permutation and rejected every downstream key/HM location.
 settings.badges='SAFE';settings.random_start='OFF';settings.progression_items=true
 local badgeWorlds={}
 for _,channels in ipairs({{'SHUFFLE','RANDOM'},{'RANDOM','RANDOM'},{'UNCHANGED','RANDOM'},{'SHUFFLE','UNCHANGED'}}) do
  settings.field_items,settings.gift_items=channels[1],channels[2]
  for seed=1,12 do
   local active=generate(seed)
   local p=active.itemPlan
   check(p and p.proof.checked,'ordinary start keeps logical key/HM validation enabled')
   local rules=I.rules(gen,active.badgePlan)
   check(I.solve(p.locations,p.placement,rules,p.initial,p.goal),'combined shuffled badges and real reward channels remain reachable: '..v)
   check(I.solve(I.catalog(gen,v),{},rules,nil,p.goal),'SAFE badges also permit native item progression')
   local keys=Core.sortedKeys(active.badgePlan.gymToBadge);local parts={}
   for _,k in ipairs(keys) do parts[#parts+1]=k..'='..active.badgePlan.gymToBadge[k] end
   badgeWorlds[table.concat(parts,'|')]=true
   if gen==2 then
    check(active.badgePlan.gymToBadge.ZEPHYR=='ZEPHYR','Route 32 badge remains reachable before leaving Violet')
   end
  end
 end
 check(#Core.sortedKeys(badgeWorlds)>1,'SAFE badges still randomize the valid permutations')
 -- Badge safety must work even when item randomization is disabled.
 settings.field_items='UNCHANGED';settings.gift_items='UNCHANGED';settings.progression_items=false
 local badgeOnly=generate(73)
 check(badgeOnly.itemPlan==nil and I.solve(I.catalog(gen,v),{},I.rules(gen,badgeOnly.badgePlan),nil,gen==1 and '@CHAMPION' or '@POWER'),'badge-only SAFE runs retain a complete native route')
 local broken=Core.copy(badgeOnly.badgePlan);local keys=Core.sortedKeys(broken.gymToBadge)
 broken.gymToBadge[keys[1]]=broken.gymToBadge[keys[2]]
 check(not R._validateSafeBadgeAssignment(gen,broken),'duplicate badges cannot pass the checked validator')
 -- Incompatible settings fail preflight with a specific change to make,
 -- rather than pretending that repeatedly drawing a seed can solve them.
 settings.badges='CHAOS';settings.progression_items=true;settings.gift_items='RANDOM'
 local ok,why=R.preflight(full,settings)
 check(not ok and why:find('Badges: Vanilla or Safe',1,true),'SAFE items and CHAOS badges give actionable preflight feedback')
 settings.safety='CHAOS'
 local chaotic=generate(73)
 check(chaotic.itemPlan.proof.checked==false and chaotic.badgePlan.mode=='CHAOS','explicit CHAOS still permits unchecked badge/item placement')
 -- Cold Continue must reproduce both new checked runs and old badge worlds.
 for _,legacy in ipairs({false,true}) do
  local cold=Core.copy(native)
  local cfg=Core.copy(badgeOnly.cfg);if legacy then cfg.badge_logic=nil end
  local data={seed=73,config=cfg,version=v}
  local coldMod={game=cold,save={get=function(_,k,d) if data[k]==nil then return d end;return data[k] end,set=function(_,k,val) data[k]=val end}}
  local coldR=dofile(root..'/randomizer.lua')(coldMod,Core,dofile(base..'/adapters.lua'),I)
  local expected=legacy and R._legacyBadgePlan(cold,cfg,73) or badgeOnly.badgePlan
  local restored,err=coldR.activateSaved(cold);check(restored~=nil,err)
  check(restored.cfg.badge_logic==(legacy and 'LEGACY' or 'CHECKED'),'Continue keeps the run-owned badge policy')
  for source,target in pairs(expected.gymToBadge) do check(restored.badgePlan.gymToBadge[source]==target,'cold Continue preserves each earned/future badge reward') end
 end
end
gen=1;version='red'

-- Actual hand-ported NPC callbacks, with only the rendering widget replaced.
package.loaded['src.render.TextBox']={new=function(g,text,done,opts) return {text=text,done=done,opts=opts} end,soundOpts=function() return {} end}
local MS=require('src.script.MapScripts')
for _,path in ipairs({'data.scripts.story2','data.scripts.story4','data.scripts.story5','data.scripts.flavor.museum_1f'}) do
 for map,entry in pairs(require(path)) do MS.attachBase(map,entry) end
end
local a
R.active=function() return a end
R.itemGift=function(g,src,key,map) return R.itemGiftForRun(a,src,key,map) end
I.installHardcoded(mod,R)
local Bag=require('src.inventory.Bag')
local function context()
 game=fixture(1,'red');mod.game=game
 game.stack={rows={},push=function(self,row) self.rows[#self.rows+1]=row end}
 game.data.text=setmetatable({},{__index=function(_,key) return key end})
 I.prepare(game,cfg,1,'red');I.finish(game,cfg,32)
 a={game=game,cfg=cfg,itemPlan=game.data._urItemPlan,seed=32}
 return game
end
local function drain()
 for i=1,30 do
  local box=table.remove(game.stack.rows)
  if not box then return end
  if box.opts and box.opts.choice then box.opts.choice(true) elseif box.done then box.done() end
 end
 error('dialogue did not finish')
end
context()
local bike=a.itemPlan.byGift['BIKESHOP|BICYCLE'];bike.target='HM_SURF'
game.save.inventory.BICYCLE=1;game.save.inventory.BIKE_VOUCHER=1
local complete=0
MS.baseTalk('BIKE_SHOP','TEXT_BIKESHOP_CLERK')(game,{},nil,function() complete=complete+1 end)
check(not game.save.inventory.HM_SURF,'native bike reward is asynchronous')
check(game.save.inventory.BICYCLE==1,'source inventory restored immediately')
drain()
check(game.save.inventory.HM_SURF==1 and not game.save.inventory.BIKE_VOUCHER,'actual bike callback grants mapped HM and consumes voucher')
check(game.save.flags.EVENT_GOT_BICYCLE and complete==1,'native one-time completion preserved')
check(Bag.add(game.save,'BICYCLE',1,game.data) and game.save.inventory.BICYCLE==2,'unrelated Bag.add remains native')
MS.baseTalk('BIKE_SHOP','TEXT_BIKESHOP_CLERK')(game,{},nil,function() end);drain()
check(game.save.inventory.HM_SURF==1,'completed conversation does not duplicate reward')
local once=MS.baseTalk('BIKE_SHOP','TEXT_BIKESHOP_CLERK')
I.attachHardcoded()
check(MS.baseTalk('BIKE_SHOP','TEXT_BIKESHOP_CLERK')==once,'repeated attach does not stack wrappers')
local reloaded=dofile(host..'/data/scripts/story2.lua').BIKE_SHOP
local nativeReload=reloaded.talk.TEXT_BIKESHOP_CLERK
MS.attachBase('BIKE_SHOP',reloaded)
-- The registry's engine contribution can be refreshed on a cartridge reload.
I.attachHardcoded()
check(MS.baseTalk('BIKE_SHOP','TEXT_BIKESHOP_CLERK')~=nativeReload,'cartridge reload reinstalls the bridge')
context()
local aide=a.itemPlan.byGift['ROUTE2GATE|HM_FLASH'];aide.target='HM_CUT'
MS.baseTalk('ROUTE_2_GATE','TEXT_ROUTE2GATE_OAKS_AIDE')(game,{},nil,function() end);drain()
check(game.save.inventory.HM_CUT==1 and game.save.flags.EVENT_GOT_HM05,'SAFE aide reward reachable without randomized dex-count assumptions')
check(next(game.save.pokedex.owned)==nil,'aide bridge does not fabricate catches')
context();game.data.constants={bagSize=1};game.save.inventory.POTION=1
local route=a.itemPlan.byGift['ROUTE1|POTION'];route.target='HM_CUT'
MS.baseTalk('ROUTE_1','TEXT_ROUTE1_YOUNGSTER1')(game,{},nil,function() end);drain()
check(game.save.pcItems.HM_CUT==1 and game.save.flags.EVENT_GOT_POTION_SAMPLE,'one-time sample reward survives full bag in PC')
Bag.remove(game.save,'POTION',1,game.data)
check(Bag.add(game.save,'HM_CUT',1,game.data),'stored HM can be withdrawn after making room')
Bag.pcRemove(game.save,'HM_CUT',1,game.data)
check(game.save.inventory.HM_CUT==1 and not game.save.pcItems.HM_CUT,'native PC withdrawal preserves exactly one HM')

-- Native Gen1 script command yields through the bridge without leaking its
-- temporary award context to later bag operations.
if jit then
 context();game.data.constants={bagSize=1};game.save.inventory.POTION=1
 a.itemPlan.byGift['BILLSHOUSE|S_S_TICKET'].target='HM_SURF'
 dofile(root..'/gift_items.lua')(mod,Core,R,I)
 require('src.mods.Runtime').install(events,hooks)
 local runner=require('src.script.ScriptRunner').new(game,{map={id='BILLS_HOUSE'}})
 runner:run({{'give_item','S_S_TICKET',1},{'set_flag','AWARD_DONE'}})
 drain()
 check(not runner:isRunning() and game.save.flags.AWARD_DONE,'native Gen1 script resumes after reward and PC notice')
 check(game.save.pcItems.HM_SURF==1,'native Gen1 gift maps and survives bag refusal')
 check(Bag.add(game.save,'HM_CUT',1,game.data)==false,'finished command does not intercept unrelated awards')
end

-- Native Gen2 VM consumes one-time event flags even without a bag-full arm.
-- The managed award must therefore survive failure before that flag is set.
if jit then
 gen=2;version='crystal'
 game=fixture(2,'crystal');mod.game=game
 I.prepare(game,cfg,2,'crystal');I.finish(game,cfg,24)
 a={game=game,cfg=cfg,itemPlan=game.data._urItemPlan,seed=24}
 local gift=a.itemPlan.byGift['RADIOTOWER5F|BASEMENT_KEY']
 gift.target='HM_SURF'
 local Vm=require('src.script.gen2.Vm');local Flags=require('src.world.gen2.Events')
 local flags=Flags.new();local awarded={};local messages={}
 local vm=Vm.new({GIFT={{op='giveitem',item=game.data.items.BASEMENT_KEY.index,quantity=1},{op='setevent',event=99},{op='end'}}},{},flags,{
  mapId=function() return 'RADIO_TOWER_5F' end,
  giveItem=function(id,qty) awarded[#awarded+1]={id,qty};return false end,
  showText=function(text,done) messages[#messages+1]=text;done() end,
 })
 vm:start('GIFT')
 check(not vm:running() and flags:get(99),'native one-time VM finishes after PC fallback')
 check(#awarded==1 and awarded[1][1]==game.data.items.HM_SURF.index,'VM uses planned reward once')
 check(game.save.pcItems.HM_SURF==1 and #messages>0,'failed native award retained and PC notice shown')
 local orig=vm.giveItemFn;check(orig(1,1)==false,'VM award function restored')
end
print(('PASS: %d progression checks'):format(n))
