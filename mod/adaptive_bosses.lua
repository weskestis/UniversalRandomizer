-- Native story encounters retain their scripts, identities and rewards.
return function(Core,W,A,R)
  local B={schema=1}
  local classes={RIVAL1='MIXED',RIVAL2='MIXED',RIVAL3='MIXED',GIOVANNI='GROUND',
    EXECUTIVEM='MIXED',EXECUTIVEF='MIXED',LORELEI='ICE',BRUNO='FIGHTING',AGATHA='GHOST',
    LANCE='DRAGON',WILL='PSYCHIC_TYPE',KOGA='POISON',KAREN='DARK',CHAMPION='DRAGON',RED='MIXED'}
  function B.enabled(c) return c and c.adaptive_bosses and c.adaptive_bosses~='OFF' end
  function B.source(a,class,index)
    if A.source(a,class,index) then return nil end -- gym ownership is independent
    local name=tostring(class):gsub('^OPP_','');local roster
    if a.generation==1 then
      local entry=a.game.data.trainers and a.game.data.trainers[class]
      roster=entry and entry.parties and entry.parties[tonumber(index) or 1]
    else
      local data=a.game.data.gen2Trainers or a.game.data.trainers
      for id,entry in pairs(data and data.classes or {}) do
        if class==id or class==entry.index then
          name=id
          for i,row in ipairs(entry.trainers or {}) do
            if i==(index==nil and 1 or tonumber(index)) or row.id==index then roster=row.party;index=i;break end
          end
          break
        end
      end
    end
    local duo=a.generation==1 and a.version=='yellow' and name=='ROCKET' and (tonumber(index) or 0)>=42
    if not (classes[name] or duo) or not roster or #roster==0 then return nil end
    local peak=1;for _,m in ipairs(roster) do peak=math.max(peak,tonumber(m.level) or 1) end
    return {key=name..'#'..tostring(index or 1),class=name,theme=classes[name] or 'MIXED',label=duo and ('Jessie & James '..tostring(index)) or nil,roster=roster,peak=peak,
      rival=name:match('^RIVAL')~=nil}
  end
  function B.encounters(a)
    local out={}
    if a.generation==1 then
      for _,class in ipairs(Core.sortedKeys(a.game.data.trainers or {})) do
        for i in ipairs(a.game.data.trainers[class].parties or {}) do
          local s=B.source(a,class,i);if s then out[#out+1]={class=class,index=i,source=s} end
        end
      end
    else
      local data=a.game.data.gen2Trainers or a.game.data.trainers
      for _,class in ipairs(Core.sortedKeys(data and data.classes or {})) do
        for i in ipairs(data.classes[class].trainers or {}) do
          local s=B.source(a,class,i);if s then out[#out+1]={class=class,index=i,source=s} end
        end
      end
    end
    return out
  end
  function B.profile(source,n)
    -- Early rivals remain short introductory fights even if approached late.
    local phase=source.peak<=44 and math.max(0,math.ceil((source.peak-12)/4))
      or 8+math.ceil((source.peak-44)/5)
    local strength=math.min(n,phase);local tier=A.tier(strength)
    tier.level=math.min(source.peak,tier.level)
    tier.count=math.min(#source.roster,tier.count)
    if source.peak<=9 then tier.count=1;tier.power=40;tier.moves=2 end
    return tier,strength
  end
  function B.plan(a,class,index,n)
    if not B.enabled(a.cfg) then return nil end
    local s=B.source(a,class,index);if not s then return nil end
    n=n or A.badges(a);local tier,strength=B.profile(s,n)
    local chaos=a.cfg.adaptive_bosses=='CHAOS'
    local rng=Core.rng(Core.hash('story-bosses-v1|'..s.key..'|'..n..'|'..a.cfg.adaptive_bosses,a.seed))
    local pool=A.candidates(a,s,strength,chaos,tier)
    if #pool==0 then return nil,'[seed] No safe native story team: '..s.key..' at '..n..' badges.' end
    local catalog=A.catalog(a);local count=chaos and rng:int(1,6) or tier.count
    local rows,used={},{}
    for slot=1,count do
      local choices={}
      for _,id in ipairs(pool) do if not used[id] then choices[#choices+1]=id end end
      if #choices==0 then choices=pool end
      local id=choices[rng:int(1,#choices)]
      local level=math.max(1,tier.level-math.min(2,count-slot))
      if s.rival and a.cfg.rival_starter and slot==count then
        local original=s.roster[#s.roster].species
        local mapped=R.rivalStarterPick(a,class,index,original,level) or original
        local root=catalog.meta[mapped] and catalog.meta[mapped].root
        local family={}
        for _,candidate in ipairs(pool) do
          if catalog.meta[candidate].root==root then family[#family+1]=candidate end
        end
        if #family==0 then return nil,'[seed] Rival starter has no eligible native story form: '..tostring(mapped) end
        table.sort(family,function(x,y)
          local mx,my=catalog.meta[x],catalog.meta[y]
          if mx.stage~=my.stage then return mx.stage>my.stage end;return x<y
        end)
        id=family[1]
      end
      used[id]=true
      if not chaos then level=math.max(level,catalog.meta[id].minLevel) end
      level=math.max(1,math.min(100,math.floor(level*(100+(tonumber(a.cfg.boss_levels) or 0))/100+.5)))
      rows[#rows+1]={species=id,level=level,moves=A.moves(a,id,strength,chaos,rng,tier)}
    end
    return rows,{source=s.key,badges=n,mode=a.cfg.adaptive_bosses}
  end
  function B.validate(a)
    if not B.enabled(a.cfg) then return true end
    local encounters=B.encounters(a)
    if #encounters==0 then return false,'Native story trainer data is unavailable.' end
    for _,e in ipairs(encounters) do
      for n=0,(a.generation==1 and 8 or 16) do
        local rows,why=B.plan(a,e.class,e.index,n)
        if not rows then return false,why end
        for _,row in ipairs(rows) do if #row.moves==0 then return false,'[seed] Story boss has no usable native moves: '..row.species end end
      end
    end
    return true
  end
  function B.party(a,class,index)
    local rows,why=B.plan(a,class,index)
    if not rows then if why then error(why) end;return nil end
    if a.generation==1 then return rows end
    local Mon=require('src.battle.gen2.Mon');local out={}
    for _,row in ipairs(rows) do
      local moves={};for _,mid in ipairs(row.moves) do local d=a.game.data.moves[mid];moves[#moves+1]={id=mid,pp=d.pp,maxPp=d.pp} end
      out[#out+1]=assert(Mon.new(a.game.data,row.species,row.level,{moves=moves,dvs={attack=9,defense=8,speed=8,special=8}}))
    end
    return out
  end
  return B
end
