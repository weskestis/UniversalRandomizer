-- Run the complete expanded installer through the pinned host's real registry
-- schemas and reference validator. Native ROM records are small fixtures; every
-- added record is the actual packaged mod content, without permissive mocks.
local root=os.getenv('MOD_SOURCE') or 'mod'
local base=os.getenv('MOD_BASE') or '../randomizer'
local host=os.getenv('HOST_SOURCE') or '../host-source'
package.path=host..'/?.lua;'..package.path
unpack=table.unpack or unpack
local gen,version=1,'red'
package.loaded['src.core.GameVersion']={get=function() return version end,generation=function() return gen end}
local Schemas=require('src.mods.Schemas')
local Registry=require('src.mods.Registry')
local Core=dofile(base..'/core.lua')
local checks=0
local function check(ok,msg) assert(ok,msg);checks=checks+1 end
local function read(path)
  local f=io.open(root..'/'..path,'rb') or assert(io.open(base..'/'..path,'rb'),path)
  local s=f:read('*a');f:close();return s
end
local function loadMod(path) return assert((loadstring or load)(read(path),'@'..path))() end
local src=loadMod('expanded493/source.lua')
local meta=loadMod('expanded493/dexmeta.lua')
check(meta[1].heightM==0.7 and meta[1].heightFt==2 and meta[1].heightIn==4,'Bulbasaur dimensions use meters')
check(meta[252].heightM==0.5 and meta[252].heightFt==1 and meta[252].heightIn==8,'Treecko dimensions')
check(meta[321].heightM==14.5,'Wailord dimensions retain large legitimate heights')
for dex=1,493 do
  local m=assert(meta[dex])
  local meters=(m.heightFt*12+m.heightIn)*0.0254
  check(math.abs(meters-m.heightM)<=0.01271,'metric/imperial height agrees: '..dex)
  check(math.abs(m.weight*0.45359237-m.weightKg)<0.023,'metric/imperial weight agrees: '..dex)
end

for _,v in ipairs({'red','blue','yellow','gold','silver','crystal'}) do
  version=v;gen=(v=='red' or v=='blue' or v=='yellow') and 1 or 2
  local max=gen==1 and 151 or 251
  local regs,bases={},{}
  for _,name in ipairs({'pokemon','moves','items','move_effects','item_effects','type_chart','growth_rates','evolution_methods','icons','constants'}) do
    local spec=Schemas.REGISTRIES[name]
    local registry=Registry.new(name,spec)
    local native={};bases[name]=native;registry.base=function() return native end
    for _,method in ipairs({'register','patch','override'}) do
      registry[method]=function(self,id,value)
        local ok,why=Schemas.check(spec,name,id,value,method,gen)
        check(ok,why or (name..'.'..id))
        return Registry[method](self,id,value,'universal_randomizer')
      end
    end
    regs[name]=registry
  end
  for _,sp in ipairs(src.species) do
    if sp.dex<=max then bases.pokemon[sp.id]={id=sp.id,name=sp.name,dex=sp.dex} end
    for _,t in ipairs(sp.types) do
      local id=t=='PSYCHIC' and 'PSYCHIC_TYPE' or t
      if gen==2 or (id~='DARK' and id~='STEEL') then bases.type_chart[id]={name=id,category='physical'} end
    end
  end
  -- The host seeds built-in types as engine ops; this registry deliberately
  -- has no direct base lookup into the cartridge's numeric matchup table.
  for id,value in pairs(bases.type_chart) do Registry.register(regs.type_chart,id,value,Schemas.ENGINE) end
  for _,id in ipairs({'LEVEL','ITEM','TRADE','EVOLVE_LEVEL','EVOLVE_ITEM','EVOLVE_TRADE','EVOLVE_HAPPINESS','EVOLVE_STAT'}) do
    bases.evolution_methods[id]={check=function() return false end}
  end
  for _,id in ipairs({'MEDIUM_FAST','MEDIUM_SLOW','FAST','SLOW'}) do
    bases.growth_rates[gen==2 and 'GROWTH_'..id or id]={expForLevel=function(n) return n*n*n end}
  end
  for _,id in ipairs({'FIRE_STONE','WATER_STONE','THUNDER_STONE','LEAF_STONE','MOON_STONE','SUN_STONE'}) do
    bases.items[id]={name=id,price=2100,tossable=true}
  end
  bases.move_effects.NO_ADDITIONAL_EFFECT={kind='full'}
  bases.constants.dexSize=max
  local events={}
  local mod={path=base,content=regs,read=function(_,p) return read(p) end,
    events={on=function(_,name,fn) events[name]=events[name] or {};table.insert(events[name],fn) end},
    hooks={wrap=function() end},save={get=function(_,_,d) return d end}}
  local api=loadMod('expanded493/install.lua').install(mod)
  local count=0;local data={pokemon={},items={}}
  for id,record in regs.pokemon:each() do
    data.pokemon[id]=Core.copy(record)
    if record.dex>max then
      count=count+1
      local d=record.dexEntry
      check(d~=meta[record.dex],'Dex registration does not alias source metadata')
      if gen==2 then
        check(d.heightFt==nil and d.heightIn==nil,'Gen 1 height fields cannot leak into Gen 2')
        check(d.height%100<12 and d.weight%1==0,'Gen 2 native height/weight encoding')
      else
        check(d.height==nil and d.heightIn<12,'Gen 1 keeps split height fields')
      end
      for _,path in ipairs({record.spriteFront,record.spriteBack}) do
        local f=io.open(path,'rb');check(f~=nil,'sprite exists: '..path);if f then f:close() end
      end
    end
  end
  check(count==493-max,'all expanded species installed for '..v)
  local problems=Schemas.crossValidate({content=regs,generation=gen},data)
  local messages={};for i,p in ipairs(problems) do if i<=25 then messages[#messages+1]=p.message end end
  check(#problems==0,table.concat(messages,'\n'))
  for id,record in regs.items:each() do data.items[id]=record end
  for _,r in pairs(regs) do r:freeze() end
  api.applyEvolutionOverlay({data=data},493)
  for id,record in pairs(data.pokemon) do
    if record.dex>max then
      local ok,why=Schemas.check(Schemas.REGISTRIES.pokemon,'pokemon',id,record,'register',gen)
      check(ok,why)
    end
  end
  if gen==2 then
    local bad=Core.copy(data.pokemon.TREECKO)
    bad.dexEntry.heightFt=1;bad.dexEntry.heightIn=8
    local ok,why=Schemas.check(Schemas.REGISTRIES.pokemon,'pokemon','TREECKO',bad,'register',2)
    check(not ok and why:find('heightFt',1,true) and why:find('heightIn',1,true),'test reproduces both reported unknown fields')
    data.gen2Pokedex={entries={},newOrder={},alphabeticalOrder={}}
    require('src.core.gen2.PokedexText').apply(data)
    for id in pairs(api.addedDex) do
      local species=api.addedDex[id];local d=data.gen2Pokedex.entries[species];local m=meta[id]
      check(d.height==m.heightFt*100+m.heightIn and d.weight==math.floor(m.weight*10+0.5),'native Dex displays converted dimensions: '..species)
      check(d.heightM==m.heightM and d.weightKg==m.weightKg,'native metric Dex dimensions: '..species)
    end
  end
end
print('PASS: '..checks..' expanded registration/schema checks across six games')
