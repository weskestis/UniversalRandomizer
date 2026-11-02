-- Badge-driven gym teams. Only enemy party rows are built here; native gym
-- events, rewards, portraits, player Pokemon and world placements stay owned
-- by their existing systems.
return function(Core,Worlds)
  local A={schema=1}
  local G1,G2=Worlds.gen1 or Worlds,Worlds.gen2
  local themes={BROCK='ROCK',MISTY='WATER',LT_SURGE='ELECTRIC',ERIKA='GRASS',KOGA='POISON',
    SABRINA='PSYCHIC_TYPE',BLAINE='FIRE',GIOVANNI='GROUND',FALKNER='FLYING',BUGSY='BUG',WHITNEY='NORMAL',
    MORTY='GHOST',JASMINE='STEEL',CHUCK='FIGHTING',PRYCE='ICE',CLAIR='DRAGON',JANINE='POISON',BLUE='MIXED'}
  local legends={ARTICUNO=true,ZAPDOS=true,MOLTRES=true,MEWTWO=true,MEW=true,RAIKOU=true,ENTEI=true,
    SUICUNE=true,LUGIA=true,HO_OH=true,['HO-OH']=true,CELEBI=true}
  local unsafe={SONICBOOM=true,DRAGON_RAGE=true,SEISMIC_TOSS=true,NIGHT_SHADE=true,PSYWAVE=true,SUPER_FANG=true,
    FISSURE=true,GUILLOTINE=true,HORN_DRILL=true,COUNTER=true,MIRROR_COAT=true,BIDE=true,
    SELFDESTRUCT=true,SELF_DESTRUCT=true,EXPLOSION=true,METRONOME=true,MIRROR_MOVE=true,
    DREAM_EATER=true,SNORE=true,SLEEP_TALK=true,REST=true,ROLLOUT=true,FURY_CUTTER=true,
    DESTINY_BOND=true,PERISH_SONG=true,CURSE=true,FLAIL=true,REVERSAL=true,RETURN=true,FRUSTRATION=true,
    HIDDEN_POWER=true,PRESENT=true,MAGNITUDE=true,BEAT_UP=true}
  local multi={DOUBLESLAP=5,DOUBLE_SLAP=5,COMET_PUNCH=5,FURY_ATTACK=5,FURY_SWIPES=5,PIN_MISSILE=5,
    SPIKE_CANNON=5,BARRAGE=5,BONE_RUSH=5,DOUBLE_KICK=2,BONEMERANG=2,TWINEEDLE=2,TRIPLE_KICK=6}
  local basic={GROWL=true,TAIL_WHIP=true,LEER=true,HARDEN=true,DEFENSE_CURL=true}
  local middle={THUNDER_WAVE=true,STUN_SPORE=true,POISONPOWDER=true,POISON_POWDER=true,
    REFLECT=true,LIGHT_SCREEN=true,AGILITY=true,GROWTH=true,FOCUS_ENERGY=true}
  local late={SWORDS_DANCE=true,AMNESIA=true,ACID_ARMOR=true,RECOVER=true,SOFTBOILED=true,SOFT_BOILED=true,
    SYNTHESIS=true,MORNING_SUN=true,MOONLIGHT=true,TOXIC=true,HYPNOSIS=true,SLEEP_POWDER=true,SPORE=true}
  local function owned(v) return v==true or type(v)=='number' and v>0 end
  local function typed(def,wanted)
    if wanted=='MIXED' then return true end
    for _,t in ipairs(def.types or {}) do if t==wanted then return true end end
    return false
  end
  local function native(a,id,field)
    local row=a.adaptiveSource and a.adaptiveSource[id]
    local rec=row and row[field]
    if rec then return rec.value end
    return (a.game.data.pokemon[id] or {})[field]
  end
  function A.enabled(cfg) return cfg and cfg.adaptive_gyms and cfg.adaptive_gyms~='OFF' end
  function A.badges(a)
    local n=0
    if a.generation==1 then
      local inv=a.game.save.inventory or {}
      for _,g in ipairs(G1.gyms) do if owned(inv[g.badge]) then n=n+1 end end
    else
      local player=a.game.save.player or {}
      for _,g in ipairs(G2.gyms) do local rows=player[g.store] or {}
        if owned(rows[g.badge]) or owned(rows[g.index]) then n=n+1 end
      end
    end
    return n
  end
  function A.tier(n)
    n=math.max(0,math.floor(tonumber(n) or 0))
    return {count=math.min(6,2+math.max(0,n-1)),stage=n<2 and 0 or n<4 and 1 or 2,
      bst=n<2 and 340 or n<4 and 400 or n<6 and 470 or 600,
      offense=n<2 and 105 or n<4 and 125 or n<6 and 150 or 255,
      power=n<2 and 60 or n<4 and 80 or n<6 and 100 or 150,
      moves=n<2 and 2 or n<4 and 3 or 4,
      level=math.min(100,12+4*math.min(n,8)+5*math.max(0,n-8))}
  end
  function A.source(a,class,index)
    if a.generation==2 then return G2 and G2.source(a.game,class,index) end
    return G1.byKey[tostring(class)..'#'..tostring(index or 1)]
  end
  function A.target(a,source)
    local world=a.gen1World or a.gen2World
    local w=a.generation==2 and G2 or G1
    return w.byKey[world and world.leaders[source.key] or source.key]
  end
  local function className(g)
    return g.class or g.key:match('^OPP_(.-)#')
  end
  function A.theme(g) return g.theme or themes[className(g)] or 'MIXED' end
  function A.roster(a,g)
    if a.generation==2 then local t=G2.nativeTrainer(a.game,g.class);return t and t.roster end
    local c,p=g.key:match('^(.-)#(%d+)$');local t=a.game.data.trainers and a.game.data.trainers[c]
    return t and t.parties and t.parties[tonumber(p)]
  end
  function A.preflight(game,cfg)
    if not A.enabled(cfg) then return true end
    local a={game=game,generation=game.data.gen2Encounters and 2 or 1}
    local w=a.generation==2 and G2 or G1
    if not w then return false,'Adaptive gyms require the native gym adapter.' end
    for _,g in ipairs(w.gyms) do
      local roster=A.roster(a,g)
      if not roster or #roster==0 then return false,'Native adaptive gym roster missing: '..g.name end
    end
    return true
  end
  local function statTotal(a,def)
    local b=def.baseStats or {}
    local special=a.generation==1 and (b.special or b.specialAttack or 0)
      or ((b.specialAttack or b.special or 0)+(b.specialDefense or b.special or 0))/2
    return (b.hp or 0)+(b.attack or 0)+(b.defense or 0)+(b.speed or 0)+special,
      math.max(b.attack or 0,a.generation==1 and (b.special or 0) or (b.specialAttack or b.special or 0))
  end
  function A.catalog(a)
    if a.adaptiveCatalog then return a.adaptiveCatalog end
    local c={ids={},meta={},moves={}}
    for _,id in ipairs(Core.sortedKeys(a.game.data.pokemon or {})) do
      local def=a.game.data.pokemon[id];local dex=type(def)=='table' and tonumber(def.dex or def.index)
      if type(id)=='string' and type(def)=='table' and def.baseStats and dex and dex>=1
        and dex<=(a.generation==1 and 151 or 251) and not id:match('^MISSINGNO') and not id:match('^UNUSED')
        and not id:find('FOSSIL',1,true) and id~='MON_GHOST' then
        c.ids[#c.ids+1]=id;c.meta[id]={parents={},children={},stage=0,minLevel=1,root=id}
      end
    end
    for _,id in ipairs(c.ids) do
      for _,e in ipairs(native(a,id,'evolutions') or {}) do
        local target=e.species or e.into
        if c.meta[target] then
          local method=tostring(e.method or '')
          local level=(method:find('LEVEL',1,true) or method:find('STAT',1,true)) and tonumber(e.level)
            or method:find('TRADE',1,true) and 30 or 20
          c.meta[target].parents[#c.meta[target].parents+1]={id=id,level=level or 20}
          c.meta[id].children[#c.meta[id].children+1]=target
        end
      end
    end
    local done,visiting={},{}
    local function walk(id)
      local m=c.meta[id]
      if done[id] then return end
      if visiting[id] then error('Adaptive native evolution cycle: '..id) end
      visiting[id]=true
      if #m.parents>0 then
        m.minLevel=101
        for _,p in ipairs(m.parents) do
          walk(p.id);local pm=c.meta[p.id];local lv=math.max(pm.minLevel,p.level)
          m.stage=math.max(m.stage,pm.stage+1)
          if lv<m.minLevel or lv==m.minLevel and pm.root<m.root then m.minLevel=lv;m.root=pm.root end
        end
      end
      visiting[id]=nil;done[id]=true
    end
    for _,id in ipairs(c.ids) do
      walk(id)
      local pool,seen={},{}
      local function add(mid)
        mid=Core.resolveIndexedId(a.game.data.moves,mid) or mid
        local d=type(mid)=='string' and a.game.data.moves[mid]
        local index=d and tonumber(d.index)
        if d and (not index or index>=1 and index<=(a.generation==1 and 165 or 251))
          and mid~='STRUGGLE' and (tonumber(d.pp) or 0)>0 and not seen[mid] then
          pool[#pool+1]=mid;seen[mid]=true
        end
      end
      for _,m in ipairs(native(a,id,'level1Moves') or {}) do add(m) end
      for _,r in ipairs(native(a,id,'learnset') or native(a,id,'levelMoves') or {}) do add(r.move) end
      for _,m in ipairs(native(a,id,'tmhm') or {}) do add(m) end
      table.sort(pool);c.moves[id]=pool
    end
    a.adaptiveCatalog=c
    return c
  end
  function A.safeDamage(a,id,tier)
    local d=a.game.data.moves[id]
    if not d or unsafe[id] then return false end
    if a.generation==1 and (id=='WRAP' or id=='BIND' or id=='CLAMP' or id=='FIRE_SPIN') then return false end
    local effect=tostring(d.effect or ''):upper()
    if effect:find('OHKO',1,true) or effect:find('EXPLOSION',1,true) or effect:find('FIXED_DAMAGE',1,true) then return false end
    local power=(tonumber(d.power) or 0)*(multi[id] or 1)
    return power>1 and power<=tier.power and (tonumber(d.accuracy) or 100)>=70
  end
  function A.moves(a,id,n,chaos,rng,customTier)
    local c=A.catalog(a);local tier=customTier or A.tier(n);local def=a.game.data.pokemon[id]
    local pool=c.moves[id] or {};local out,used={},{}
    local function add(mid) if mid and not used[mid] then out[#out+1]=mid;used[mid]=true end end
    if chaos then
      local choices=Core.copy(pool)
      for i=#choices,2,-1 do local j=rng:int(1,i);choices[i],choices[j]=choices[j],choices[i] end
      for _,m in ipairs(choices) do if (tonumber(a.game.data.moves[m].power) or 0)>0 then add(m);break end end
      for _,m in ipairs(choices) do if #out<4 then add(m) end end
      return out
    end
    local attacks,utility={},{}
    for _,mid in ipairs(pool) do
      local d=a.game.data.moves[mid]
      if A.safeDamage(a,mid,tier) then attacks[#attacks+1]=mid
      elseif (tonumber(d.power) or 0)==0 and (basic[mid] or n>=2 and middle[mid] or n>=6 and late[mid]) then utility[#utility+1]=mid end
    end
    table.sort(attacks,function(x,y)
      local dx,dy=a.game.data.moves[x],a.game.data.moves[y]
      local sx=(dx.power or 0)*(multi[x] or 1)*math.min(100,tonumber(dx.accuracy) or 100)
      local sy=(dy.power or 0)*(multi[y] or 1)*math.min(100,tonumber(dy.accuracy) or 100)
      if sx~=sy then return sx>sy end;return x<y
    end)
    for _,mid in ipairs(attacks) do if typed(def,a.game.data.moves[mid].type) then add(mid);break end end
    if #out==0 then add(attacks[1]) end
    if #out==0 then return out end
    local firstType=a.game.data.moves[out[1]].type
    if n>=2 then for _,mid in ipairs(attacks) do if a.game.data.moves[mid].type~=firstType then add(mid);break end end end
    if #utility>0 then add(utility[rng:int(1,#utility)]) end
    local usedTypes={};for _,m in ipairs(out) do usedTypes[a.game.data.moves[m].type]=true end
    for _,mid in ipairs(attacks) do if #out<tier.moves and not usedTypes[a.game.data.moves[mid].type] then add(mid);usedTypes[a.game.data.moves[mid].type]=true end end
    for _,mid in ipairs(attacks) do if #out<tier.moves then add(mid) end end
    return out
  end
  function A.candidates(a,g,n,chaos,customTier)
    local c=A.catalog(a);local theme=A.theme(g);local tier=customTier or A.tier(n);local out={}
    for _,id in ipairs(c.ids) do
      local def=a.game.data.pokemon[id];local meta=c.meta[id]
      local bst,offense=statTotal(a,def)
      if (a.cfg.allow_legendaries or not legends[id]) and typed(def,theme)
        and (chaos or meta.stage<=tier.stage and meta.minLevel<=tier.level and bst<=tier.bst and offense<=tier.offense) then
        local usable=false
        for _,mid in ipairs(c.moves[id]) do
          if chaos or A.safeDamage(a,mid,tier) then usable=true;break end
        end
        if usable then out[#out+1]=id end
      end
    end
    return out
  end
  function A.validate(a)
    if not A.enabled(a.cfg) then return true end
    local w=a.generation==2 and G2 or G1
    for _,g in ipairs(w.gyms) do
      for n=0,(a.generation==2 and 16 or 8) do
        local pool=A.candidates(a,g,n,a.cfg.adaptive_gyms=='CHAOS')
        if #pool==0 then return false,'[seed] No eligible '..A.theme(g)..' adaptive gym team at '..n..' badges. Try another seed or types/stats settings.' end
      end
    end
    return true
  end
  function A.plan(a,class,index,n)
    if not A.enabled(a.cfg) then return nil end
    local source=A.source(a,class,index);if not source then return nil end
    local target=A.target(a,source);n=n or A.badges(a)
    local tier=A.tier(n);local chaos=a.cfg.adaptive_gyms=='CHAOS'
    local rng=Core.rng(Core.hash('adaptive-gyms-v1|'..source.key..'|'..target.key..'|'..n..'|'..a.cfg.adaptive_gyms,a.seed))
    local pool=A.candidates(a,target,n,chaos)
    assert(#pool>0,'Adaptive gym pool changed after validation')
    local count=chaos and rng:int(2,6) or tier.count
    local c=A.catalog(a);local preferred={}
    for _,m in ipairs(A.roster(a,target) or {}) do
      local id=Core.resolveIndexedId(a.game.data.pokemon,m.species) or m.species
      if c.meta[id] then preferred[c.meta[id].root]=true end
    end
    local picks,used={},{}
    local hasPreferred=false
    for _,id in ipairs(pool) do if preferred[c.meta[id].root] then hasPreferred=true;break end end
    for slot=1,count do
      local choices={};local best=-math.huge
      for _,id in ipairs(pool) do
        if not used[id] and (slot~=1 or not hasPreferred or preferred[c.meta[id].root]) then
          local meta=c.meta[id];local bst=statTotal(a,a.game.data.pokemon[id])
          local rank=chaos and 0 or meta.stage*1000+(preferred[meta.root] and 200 or 0)+math.floor(bst/20)
          if rank>best then best=rank;choices={id} elseif rank==best then choices[#choices+1]=id end
        end
      end
      if #choices==0 then used={};choices=pool end
      local id=choices[rng:int(1,#choices)];used[id]=true;picks[#picks+1]=id
    end
    -- Put the strongest member last, preserving a recognizable ace slot.
    table.sort(picks,function(x,y) local bx,by=statTotal(a,a.game.data.pokemon[x]),statTotal(a,a.game.data.pokemon[y]);if bx~=by then return bx<by end;return x<y end)
    local rows={};local pct=tonumber(a.cfg.boss_levels) or 0
    for slot,id in ipairs(picks) do
      local baseline=tier.level-math.min(2,count-slot)
      if not chaos then baseline=math.max(baseline,c.meta[id].minLevel) end
      local level=math.max(1,math.min(100,math.floor(baseline*(100+pct)/100+0.5)))
      local item
      if a.generation==2 and n>=4 then
        local name=n>=6 and 'LEFTOVERS' or 'BERRY'
        if a.game.data.items[name] then item=name end
      end
      rows[#rows+1]={species=id,level=level,moves=A.moves(a,id,n,chaos,rng),item=item}
    end
    return rows,{source=source.key,leader=target.key,theme=A.theme(target),badges=n,mode=a.cfg.adaptive_gyms}
  end
  function A.party(a,class,index,original)
    local rows=A.plan(a,class,index)
    if not rows then return nil end
    if a.generation==1 then return rows end
    local Mon=require('src.battle.gen2.Mon');local out={}
    for _,row in ipairs(rows) do
      local moves={};for _,mid in ipairs(row.moves) do local md=a.game.data.moves[mid];moves[#moves+1]={id=mid,pp=md.pp,maxPp=md.pp} end
      out[#out+1]=assert(Mon.new(a.game.data,row.species,row.level,{moves=moves,item=row.item,dvs={attack=9,defense=8,speed=8,special=8}}))
    end
    return out
  end
  return A
end
