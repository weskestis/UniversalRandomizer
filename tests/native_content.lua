-- Complete entry-point registration, menus, native pool boundaries, visual
-- ownership and non-destructive Continue checks for all six cartridge editions.
local root=os.getenv('MOD_SOURCE') or 'mod'
local base=os.getenv('MOD_BASE') or '../randomizer'
local host=os.getenv('HOST_SOURCE') or '../host-source'
package.path=host..'/?.lua;'..package.path
unpack=table.unpack or unpack
local gen,version=1,'red'
package.loaded['src.core.GameVersion']={get=function() return version end,generation=function() return gen end,isYellow=function() return version=='yellow' end}
package.loaded['src.render.TextBox']={new=function(_,text) return {text=text} end}
local partyMethods={drawIcon=function() end,iconX=function() end,iconBob=function() end}
package.loaded['src.ui.gen2.PartyMenu']=partyMethods
local Core=dofile(base..'/core.lua')
local Schemas=require('src.mods.Schemas')
local Hooks=require('src.mods.Hooks');local Events=require('src.mods.Events')
local count=0
local function check(ok,why) assert(ok,why);count=count+1 end
local function read(path)
  check(not path:find('expanded493',1,true) and path~='rulesets.lua','entry point must not load retired content')
  local f=io.open(root..'/'..path,'rb') or assert(io.open(base..'/'..path,'rb'),path)
  local data=f:read('*a');f:close();return data
end
local function loadMod(path) return assert((loadstring or load)(read(path),'@'..path))() end
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
  version=v;gen=(v=='red' or v=='blue' or v=='yellow') and 1 or 2
  local max=gen==1 and 151 or 251
  local hooks,events=Hooks.new(),Events.new()
  local saved={last_config={ruleset='GEN4',pokedex='G1_4',abilities='CHAOS',random_natures=true}}
  local screens,hookNames,optionRows={},{},nil
  local content=setmetatable({screens={register=function(_,id,record)
    local ok,why=Schemas.check(Schemas.REGISTRIES.screens,'screens',id,record,'register',gen)
    check(ok,why);screens[id]=record
  end}},{__index=function(_,name) error('native mod must not register or override '..name) end})
  local mod={path=root,content=content,exports={},read=function(_,path) return read(path) end,
    save={get=function(_,k,d) if saved[k]==nil then return d end;return saved[k] end,set=function(_,k,v) saved[k]=v end},
    hooks={wrap=function(_,name,fn,p) hookNames[name]=true;return hooks:wrap(name,fn,p,'universal_randomizer') end},
    events={on=function(_,name,fn,p) return events:on(name,fn,p,'universal_randomizer') end},
    options={define=function(_,rows) optionRows=rows end},
    log={info=function() end,error=function(_,fmt,...) error(fmt:format(...)) end},
    ui={ListMenu={new=function(_,title,items,opts) return {title=title,items=items,opts=opts,index=1,close=function() end} end}}}
  local game={data={pokemon={},moves={},items={},maps={},field={}},save={options={ruleset='ur_gen4'},party={},inventory={},flags={}},
    stack={rows={},push=function(self,x) self.rows[#self.rows+1]=x end}}
  if gen==2 then game.data.gen2Maps={};game.data.gen2Encounters={} end
  mod.game=game;game.mods={hooks=hooks,events=events}
  local starters=gen==1 and (v=='yellow' and {'PIKACHU','EEVEE','MON_3'} or {'BULBASAUR','CHARMANDER','SQUIRTLE'}) or {'CHIKORITA','CYNDAQUIL','TOTODILE'}
  for dex=1,max do
    local id=starters[dex] or ('MON_'..dex)
    game.data.pokemon[id]={index=dex,dex=dex,name=id,types={'NORMAL'},baseStats={hp=50,attack=60,defense=70,speed=80},
      evolutions={},tmhm={},spriteFront='native/'..v..'/front/'..dex,spriteBack='native/'..v..'/back/'..dex,icon='native-icon-'..dex,cry='native-cry-'..dex}
    local d=game.data.pokemon[id]
    if gen==1 then d.baseStats.special=90;d.level1Moves={'TACKLE'};d.learnset={}
    else d.baseStats.specialAttack=90;d.baseStats.specialDefense=100;d.levelMoves={{level=1,move='TACKLE'}} end
  end
  for i=1,25 do game.data.moves['MOVE_'..i]={index=i,name='Move',type='NORMAL',power=40,pp=20} end
  game.data.pokemon[starters[2]].types={'FIRE'}
  game.data.pokemon[starters[3]].types={gen==2 and 'DARK' or 'WATER'}
  game.data.moves.TACKLE={index=33,name='Tackle',type='NORMAL',power=40,pp=35}
  -- Adversarial content simulates stale or externally supplied extra records.
  game.data.pokemon.REMOVED_MON={dex=max+1,index=max+1,types={'FAIRY'},baseStats={hp=50,attack=50,defense=50,speed=50,special=50}}
  game.data.pokemon.ZERO_DEX={dex=0,index=0,types={'FAIRY'},baseStats={hp=50,attack=50,defense=50,speed=50,special=50}}
  game.data.moves.REMOVED_MOVE={index=gen==1 and 166 or 252,type='FAIRY',power=100,pp=10}
  game.data.moves.UNINDEXED_MOVE={type='FAIRY',power=100,pp=10}
  game.data.items.POTION={name='Potion',index=1}
  local original=Core.copy(game.data.pokemon)
  local oldDraw,oldX,oldBob=partyMethods.drawIcon,partyMethods.iconX,partyMethods.iconBob
  loadMod('main.lua')(mod)
  check(partyMethods.drawIcon==oldDraw and partyMethods.iconX==oldX and partyMethods.iconBob==oldBob,'native party icon rendering remains owned by host')
  check(not hookNames['pokemon.sprite'] and not hookNames['pokemon.icon'],'no replacement sprite/icon hooks')
  check(not mod.exports.expanded493 and not mod.exports.rulesets and not mod.exports.urRulesetEngine,'no retired content exports')
  for id,d in pairs(game.data.pokemon) do
    local was=original[id]
    check(d.spriteFront==was.spriteFront and d.spriteBack==was.spriteBack and d.icon==was.icon and d.cry==was.cry,'native art/cry fields untouched: '..v..' '..id)
  end
  local cfg=mod.exports.normalizedConfig(saved.last_config,game)
  cfg.allow_legendaries=true
  check(cfg.pokedex=='NATIVE' and cfg.ruleset==(gen==1 and 'GEN1' or 'GEN2'),'old choices normalize to active cartridge')
  check(cfg.abilities==nil and cfg.random_natures==nil,'retired mechanics cannot survive settings migration')
  check(mod.exports.poolSize(game,cfg)==max,'exact native roster size for '..v)
  check(mod.exports.pokedexCap(game,{pokedex='G1_4'})==max,'old pool override cannot expand native roster')
  for _,row in ipairs(optionRows) do check(row.key~='ruleset' and row.key~='abilities' and row.key~='random_natures','live options native only') end
  local pushed
  mod.ui.push=function(g,id,opts) pushed={id=id,opts=opts,menu=screens[id].new(g,opts)} end
  local setup=screens.UniversalRandomizerSetup.new(game,{})
  for _,group in ipairs({'pokemon','wilds','battle','world','run'}) do
    setup.opts.onChoose({value=group},setup)
    for _,row in ipairs(pushed.menu.items) do
      check(row.value~='ruleset' and row.value~='pokedex' and row.value~='abilities' and row.value~='random_natures','removed option is absent from '..group)
    end
  end
  local R=loadMod('randomizer.lua')(mod,Core,dofile(base..'/adapters.lua'))
  for seed=1,150 do
    local target=R.selectSpecies(game,cfg,seed,'native-test',starters[1],'RANDOM')
    check(game.data.pokemon[target].dex<=max,'randomized species remains native')
    for _,move in ipairs(R._safeStarterCoverage(game,starters[1],seed)) do
      check(move~='REMOVED_MOVE' and move~='UNINDEXED_MOVE','randomized move remains native')
    end
  end
  cfg=R.defaults(game);cfg.mart_safety=false;cfg.progression_items=false;cfg.trainers='UNCHANGED';cfg.statics='UNCHANGED'
  cfg.base_stats='SHUFFLE';cfg.types='RANDOM';cfg.movesets='RANDOM'
  local a,why=R.generate(game,cfg,333);check(a~=nil,why)
  for id,d in pairs(game.data.pokemon) do
    check(d.spriteFront==original[id].spriteFront and d.spriteBack==original[id].spriteBack,'randomization retains native front/back sprites')
    if d.dex>=1 and d.dex<=max then
      for _,t in ipairs(d.types) do check(t~='FAIRY' and (gen==2 or (t~='STEEL' and t~='DARK')),'native type boundaries') end
    end
  end
  local ep={wildMap={slot=starters[1]},areaPools={route={starters[1]}},areaHighVariety={route={map={[starters[1]]=starters[1]},pool={starters[1]},sources={starters[1]}}}}
  check(R.nativeEncounterState(game,ep),'native encounter cache accepted')
  ep.areaHighVariety.route.map[starters[1]]='REMOVED_MON'
  check(not R.nativeEncounterState(game,ep),'expanded mapping cannot be restored from old cache')
  local N=loadMod('native_content.lua')(mod)
  local adopted=0;local method=gen==1 and 'restoreSave' or 'continueGame'
  game[method]=function() adopted=adopted+1;return 'loaded' end
  N.attach(game);local wrapped=game[method];N.attach(game)
  check(game[method]==wrapped and game.save.options.ruleset=='gen1_faithful','native rules restored and Continue guard installed once')
  local save={modData={universal_randomizer={seed=5}},options={ruleset='ur_gen4'},party={{species=starters[1],level=5,moves={{id='TACKLE'}}}},inventory={POTION=1},boxes={},daycare={}}
  check(game[method](game,save)=='loaded' and adopted==1,'native save can continue')
  check(save.options.ruleset=='gen1_faithful','incoming save cannot restore obsolete battle rules')
  save.party[1].species='REMOVED_MON'
  check(game[method](game,save)==false and adopted==1,'expanded save blocked before host adoption')
  check(save.party[1].species=='REMOVED_MON' and not save.orphaned,'blocked save is untouched')
  check(game.stack.rows[#game.stack.rows].text:find('1.4.2',1,true),'blocked Continue explains required release')
  save.party[1].species=starters[1];save.party[1].moves={{id='UNKNOWN_MODERN_MOVE'}}
  check(N.incompatibleSave(game,save)=='UNKNOWN_MODERN_MOVE','missing owned move protected')
  save.party[1].moves={{id='REMOVED_MOVE'}}
  check(N.incompatibleSave(game,save)=='REMOVED_MOVE','registered out-of-generation move protected')
  save.party[1].moves={{id='TACKLE'}};save.boxes={{{species='REMOVED_MON'}}}
  check(N.incompatibleSave(game,save)=='REMOVED_MON','boxed species protected')
  save.boxes={};save.daycare={mon={species='REMOVED_MON'}}
  check(N.incompatibleSave(game,save)=='REMOVED_MON','daycare species protected')
  save.daycare={};save.pcItems={UNKNOWN_MODERN_ITEM=1}
  check(N.incompatibleSave(game,save)=='UNKNOWN_MODERN_ITEM','unsupported PC item protected')
  save.pcItems={};save.party[1].item='UNKNOWN_MODERN_ITEM'
  check(N.incompatibleSave(game,save)=='UNKNOWN_MODERN_ITEM','unsupported held item protected')
end
print('PASS: '..count..' native content, menu, visual ownership and Continue checks across six games')
