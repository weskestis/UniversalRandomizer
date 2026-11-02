-- Synthetic cartridge-shaped records; runtime hooks/scripts come from the pinned host.
return function(ctx)
local Core,I,L,R,mod=ctx.Core,ctx.I,ctx.L,ctx.R,ctx.mod
local hooks,events=ctx.hooks,ctx.events
local function fixture(g,v)
 ctx.setVersion(g,v)
 local game={data={items={},pokemon={},maps={},moves={},field={flyWarps={},hiddenItems={}}},
   save={party={},inventory={},flags={},player={name='TEST',badges={}},pokedex={owned={}}},
   stack={rows={},push=function(self,row) self.rows[#self.rows+1]=row end}}
 if g==2 then game.data.gen2Maps={};game.data.gen2Encounters={};game.data.gen2Scripts={} end
 game.mods={hooks=hooks,events=events}
 local maps=g==1 and game.data.maps or game.data.gen2Maps
 local function map(id) maps[id]=maps[id] or {id=id,objects={},bgEvents={},warps={},connections={}};return maps[id] end
 local index=0
 local function item(id)
  if game.data.items[id] then return end
  index=index+1
  local hm=id:match('^HM_(.+)');local tm=id:match('^TM_(.+)')
  game.data.items[id]={index=index,name=id,price=100,keyItem=not hm and not tm,pocket=g==2 and (hm or tm) and 'TM_HM' or nil}
  if hm or tm then
   game.data.items[id].machine={kind=hm and 'HM' or 'TM',move=hm or tm}
   game.data.items[id].teaches=hm or tm;game.data.moves[hm or tm]={power=40,type='NORMAL'}
  end
 end
 for _,p in ipairs(I.catalog(g,v)) do
  item(p.item);local m=map(p.maps[1])
  if p.kind=='field' then m.objects[#m.objects+1]=g==1 and {item=p.item} or {itemball={item=p.item}} end
 end
 for _,d in ipairs(R._LOGIC_ITEM_DEFS[g]) do
  item(d.item);local m=map(d.map)
  if d.kind=='field' or d.kind=='auto' then
   local exists=false;for _,o in ipairs(m.objects) do if o.item==d.item or (o.itemball and o.itemball.item==d.item) then exists=true end end
   if not exists then m.objects[#m.objects+1]=g==1 and {item=d.item} or {itemball={item=d.item}} end
  end
 end
 for _,id in ipairs({'POKE_BALL','POTION','FRESH_WATER','ANTIDOTE','CARBOS'}) do item(id);game.data.items[id].keyItem=false;game.data.items[id].index=nil end
 local ordinary=map('ROUTE_1')
 for i=1,20 do local id='FILLER_'..i;item(id);game.data.items[id].keyItem=false;game.data.items[id].index=nil;ordinary.objects[#ordinary.objects+1]={item=id} end
 -- Required native field TM coverage and enough ordinary authored checks.
 for i=1,50 do
  local id='TM_'..i;item(id);game.data.items[id].machine.number=i;game.data.items[id].index=nil
  ordinary.objects[#ordinary.objects+1]={item=id}
 end
 -- Cinnabar has two independently reachable Mansion pickups before Surf.
 map('POKEMON_MANSION_1F').objects={{item='CARBOS'},{item='ANTIDOTE'}}
 for _,id in ipairs(L.logicStarts(g)) do
  local m=map(id);local center=id..'_POKECENTER_1F'
  m.warps={{destMap=center,x=4,y=5}};map(center).objects={{sprite='NURSE',x=3,y=1}}
  game.data.field.flyWarps[id]={x=4,y=6}
  for _,dest in ipairs(L.policy(g,id) or {}) do map(dest);m.connections[dest]={mapId=dest} end
 end
 for i,id in ipairs({'ROUTE_20','ROUTE_21'}) do map(id);map('CINNABAR_ISLAND').connections[id]={mapId=id} end
 if g==1 then game.data.text_pointers={SAFFRON_MART={CLERK={mart={'POKE_BALL','POTION','ANTIDOTE'}}}} end
 if g==2 then for _,m in pairs(maps) do for _,o in ipairs(m.objects) do if o.item then o.itemball={item=o.item};o.item=nil end end end end
 local starters=g==1 and (v=='yellow' and {'PIKACHU','EEVEE','MON_3'} or {'BULBASAUR','CHARMANDER','SQUIRTLE'}) or {'CHIKORITA','CYNDAQUIL','TOTODILE'}
 for dex=1,(g==1 and 151 or 251) do
  game.data.pokemon[starters[dex] or ('MON_'..dex)]={index=dex,dex=dex,types={'NORMAL'},baseStats={hp=50,attack=50,defense=50,speed=50,special=50,specialAttack=50,specialDefense=50},level1Moves={'TACKLE'},tmhm={},evolutions={}}
 end
 game.data.moves.TACKLE={index=33,power=40,type='NORMAL'}
 for i=1,25 do game.data.moves['MOVE_'..i]={index=i,power=40,type='NORMAL'} end
 -- Exercise every public setting with distinct native-shaped types, stage
 -- families, machine rows, trade personalities and ordinary shop stock.
 for i=1,25 do game.data.moves['MOVE_'..i].type=({'NORMAL','FIRE','WATER','GRASS','ELECTRIC'})[(i%5)+1] end
 if g==2 then
  game.data.moves.HEADBUTT={power=70,type='NORMAL'}
  game.data.items.TM_2.machine.move='HEADBUTT';game.data.items.TM_2.teaches='HEADBUTT'
 end
 game.data.typeChart={NORMAL={NORMAL=1},FIRE={GRASS=2},WATER={FIRE=2},GRASS={WATER=2},ELECTRIC={WATER=2}}
 for i=4,48,3 do
  game.data.pokemon['MON_'..i].evolutions={{method='LEVEL',level=16,species='MON_'..(i+1)}}
  game.data.pokemon['MON_'..(i+1)].evolutions={{method='LEVEL',level=36,species='MON_'..(i+2)}}
 end
 for _,def in pairs(game.data.pokemon) do
  def.types={({'NORMAL','FIRE','WATER','GRASS','ELECTRIC'})[(def.dex%5)+1]}
  if g==2 then def.level1Moves=nil;def.levelMoves={{level=1,move='TACKLE'},{level=8,move='MOVE_1'},{level=16,move='MOVE_2'}}
  else def.learnset={{level=8,move='MOVE_1'},{level=16,move='MOVE_2'}} end
 end
 item('WATER_STONE');game.data.items.WATER_STONE.keyItem=false;game.data.items.WATER_STONE.index=nil
 if g==1 then map('POWER_PLANT').objects[#map('POWER_PLANT').objects+1]={pokemon='MON_10',level=50} end
 local trades={}
 for i=1,(g==1 and 10 or v=='crystal' and 7 or 6) do
  trades[i]={id=i-1,give='MON_'..(20+i),get='MON_'..(40+i),dialog='TRADE_DIALOGSET_COLLECTOR',gender='TRADE_GENDER_EITHER',dvs={136,136},otId=123,nickname='TEST',otName='NPC'}
 end
 if g==1 then game.data.field.trades=trades
 else
  game.data.gen2Marts={lists={{'POKE_BALL','POTION','ANTIDOTE'}}}
  game.data.gen2EventTables={trades=trades,tradeTexts={},tradeBuffers={}}
  for _,row in ipairs({'TRADE_DIALOG_INTRO','TRADE_DIALOG_CANCEL','TRADE_DIALOG_WRONG','TRADE_DIALOG_COMPLETE','TRADE_DIALOG_AFTER'}) do
   game.data.gen2EventTables.tradeTexts[row]={};game.data.gen2EventTables.tradeBuffers[row]={}
   for _,name in ipairs({'COLLECTOR','HAPPY','NEWBIE','GIRL'}) do
    game.data.gen2EventTables.tradeTexts[row]['TRADE_DIALOGSET_'..name]='text';game.data.gen2EventTables.tradeBuffers[row]['TRADE_DIALOGSET_'..name]={}
   end
  end
 end
 local encounters={}
 for id in pairs(maps) do encounters[id]={grass={rate=255,slots={{species='MON_10',level=40},{species='MON_12',level=50}}}} end
 if g==1 then game.data.encounters=encounters
 else
  game.data.gen2Encounters.grass={}
  for id,row in pairs(encounters) do game.data.gen2Encounters.grass[id]=row.grass end
 end
 game.overworld={map={id=g==1 and 'OAKS_LAB' or 'ELMS_LAB'},npcs={}}
 if g==2 then game.world=game.overworld end
 mod.game=game
 return game,starters
end
return fixture
end
