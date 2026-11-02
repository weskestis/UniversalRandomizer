-- Imported-script shape follows native Elm/Mr. Pokemon branches. Exercise
-- command dispatch on both runtimes, plus the real host VM on LuaJIT.
return function(game,a,R,hooks,check)
 local maps=game.data.gen2Maps
 local oldElm,oldMr=maps.ELMS_LAB,maps.MR_POKEMONS_HOUSE
 local oldScripts,oldInventory=game.data.gen2Scripts,game.save.inventory
 local oldSafety=a.cfg.safety
 local egg=game.data.items.MYSTERY_EGG.index
 local main,handoff,advanced,mrScene,mrGift='01:2000','01:2100','01:2200','02:2000','02:2100'
 local other='01:2300'
 local offered,delivered,togepi,joey,battle,late=401,402,403,404,405,406
 local scripts={
  [main]={{op='faceplayer'},{op='opentext'},
   {op='checkevent',event=togepi},{op='iftrue',script=advanced},
   {op='checkflag',flag=27},{op='iftrue',script=advanced},
   {op='checkevent',event=delivered},{op='iftrue',script=advanced},
   {op='checkevent',event=offered},{op='iftrue',script=handoff},{op='end'}},
  [handoff]={{op='checkitem',item=egg},{op='iffalse',script=advanced},
   {op='takeitem',item=egg,quantity=1},{op='setevent',event=delivered},
   {op='clearevent',event=joey},{op='setevent',event=battle},{op='end'}},
  [advanced]={{op='setevent',event=late},{op='end'}},
  [mrScene]={{op='sdefer',script=mrGift},{op='end'}},
  [mrGift]={{op='giveitem',item=egg,quantity=1},{op='setevent',event=offered},{op='end'}},
  [other]={{op='opentext'},{op='setevent',event=late},{op='end'}},
 }
 maps.ELMS_LAB={objects={{scriptKey=main}}}
 maps.MR_POKEMONS_HOUSE={sceneScripts={{scriptKey=mrScene}}}
 game.data.gen2Scripts=scripts
 for _,case in ipairs({
  {name='early badge',ok=true}, {name='early Togepi',togepi=true,ok=true},
  {name='no item',noItem=true}, {name='no Mr. Pokemon visit',noVisit=true},
  {name='already delivered',done=true}, {name='other NPC',other=true},
  {name='other map',map='OTHER_LAB'}, {name='Chaos',chaos=true},
 }) do
  a.elmHandoff=nil;a.cfg.safety=case.chaos and 'CHAOS' or 'SAFE'
  game.save.inventory=case.noItem and {} or {MYSTERY_EGG=1}
  local states={[offered]=not case.noVisit,[delivered]=case.done,[togepi]=case.togepi,[joey]=true}
  local key=case.other and other or main
  local cmd=scripts[key][case.other and 1 or 2]
  local vm={scripts=scripts,events={get=function(_,id) return states[id] end}}
  local calls={}
  hooks:call('script.command',function(_,name,_,row) calls[#calls+1]={name,row};return name end,
   {game=game,vm=vm,scriptKey=key,mapId=case.map or 'ELMS_LAB'},'opentext',{},cmd)
  check(#calls==(case.ok and 2 or 1),'Elm hook scope: '..case.name)
  if case.ok then check(calls[2][1]=='sjump' and calls[2][2].script==handoff,'Elm uses the imported native handoff') end
  check(not states[battle] and states[delivered]==case.done and states[joey],
   'the hook itself never fabricates quest flags: '..case.name)
  if jit then
   local Vm=require('src.script.gen2.Vm')
   local flags=require('src.world.gen2.Events').new()
   for id,value in pairs(states) do if value then flags:set(id,true) end end
   a.elmHandoff=nil
   local took=0;local badge=true
   local native=Vm.new(scripts,{},flags,{
    mapId=function() return case.map or 'ELMS_LAB' end,
    getEngineFlag=function(id) return id==27 and badge end,
    hasItem=function(id) return id==egg and game.save.inventory.MYSTERY_EGG==1 end,
    takeItem=function(id,qty)
     if id==egg and qty==1 and game.save.inventory.MYSTERY_EGG==1 then
      game.save.inventory.MYSTERY_EGG=nil;took=took+1;return true
     end
     return false
    end,
   })
   native:start(key)
   check(not native:running(),'Elm native VM terminates: '..case.name)
   check(took==(case.ok and 1 or 0),'native handoff consumes exactly one real Egg: '..case.name)
   check(flags:get(delivered)==not not (case.done or case.ok),'native completion flag: '..case.name)
   check(flags:get(battle)==not not case.ok and flags:get(joey)==not case.ok,
    'native Route 30 barrier transition: '..case.name)
   check(badge and flags:get(togepi)==not not case.togepi,'later progress is preserved: '..case.name)
   check(flags:get(late)==not case.ok,'later dialogue remains available outside the pending handoff: '..case.name)
  end
 end
 maps.ELMS_LAB,maps.MR_POKEMONS_HOUSE=oldElm,oldMr
 game.data.gen2Scripts,game.save.inventory=oldScripts,oldInventory
 a.cfg.safety=oldSafety;a.elmHandoff=nil
end
