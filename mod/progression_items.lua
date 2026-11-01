-- Native R/B/Y/G/S/C progression rewards. SAFE uses a conservative, monotone
-- item/badge model; CHAOS uses the same finite pool without reachability checks.
-- Event-only/custom rewards with no authored access rule remain native in SAFE.
return function(Core)
  local I={schema=1}
  local receipts={
    ['route1-gift']='_Route1Youngster1GotPotionText',
    bicycle='_BikeShopExchangedVoucherText',amber='_Museum1FScientist2ReceivedOldAmberText',
    ['coin-case']='_CeladonDinerGymGuideReceivedCoinCaseText',fly='_Route16FlyHouseBrunetteGirlReceivedHM02Text',
    cut='_SSAnneCaptainsRoomCaptainReceivedHM01Text',surf='_SafariZoneSecretHouseFishingGuruReceivedHM03Text',
    strength='_WardensHouseWardenReceivedHM04Text',ticket='_SSTicketReceivedText',flute='_MrFujisHouseMrFujiReceivedPokeFluteText',
  }
  local function canonical(s) return tostring(s or ''):upper():gsub('[^A-Z0-9]','') end
  I.canonical=canonical
  local function row(id,item,kind,maps,needs,extra)
    local r=extra or {};r.id=id;r.item=item;r.kind=kind;r.maps=maps;r.needs=needs or {};return r
  end
  local function rule(out,token,needs) out[#out+1]={token=token,needs=needs} end
  function I.catalog(gen,version)
    if gen==1 then return {
      -- The clerk stops giving the parcel reward after Oak's delivery,
      -- even if it was never collected. Keep that source fixed in SAFE.
      row('parcel','OAKS_PARCEL','gift',{'VIRIDIAN_MART'},{},{fixedSafe=true}),
      row('route1-gift','POTION','gift',{'ROUTE_1'},{},
        {talk='TEXT_ROUTE1_YOUNGSTER1'}),
      row('town-map','TOWN_MAP','gift',{'BLUES_HOUSE'},{'OAKS_PARCEL'}),
      row('ticket','S_S_TICKET','gift',{'BILLS_HOUSE'},{'@EARLY'}),
      row('voucher','BIKE_VOUCHER','gift',{'POKEMON_FAN_CLUB'},{'@EARLY'}),
      row('bicycle','BICYCLE','gift',{'BIKE_SHOP'},{'@EARLY','BIKE_VOUCHER'},
        {talk='TEXT_BIKESHOP_CLERK',hideOwnedCheck=true}),
      row('old-rod','OLD_ROD','gift',{'VERMILION_OLD_ROD_HOUSE'},{'@EARLY'}),
      row('flash','HM_FLASH','gift',{'ROUTE_2_GATE'},{'@EARLY'},
        {talk='TEXT_ROUTE2GATE_OAKS_AIDE',aideFlag='EVENT_GOT_HM05',portFlag='EVENT_GOT_HM_FLASH'}),
      row('itemfinder','ITEMFINDER','gift',{'ROUTE_11_GATE_2F'},{'@EAST'},
        {talk='TEXT_ROUTE11GATE2F_OAKS_AIDE',aideFlag='EVENT_GOT_ITEMFINDER'}),
      row('cut','HM_CUT','gift',{'SS_ANNE_CAPTAINS_ROOM'},{'@EARLY','S_S_TICKET'}),
      row('amber','OLD_AMBER','gift',{'MUSEUM_1F'},{'@EARLY','USE_CUT'},
        {talk='TEXT_MUSEUM1F_SCIENTIST2'}),
      row('coin-case','COIN_CASE','gift',{'CELADON_DINER'},{'@EAST'},
        {talk='TEXT_CELADONDINER_GYM_GUIDE'}),
      row('fly','HM_FLY','gift',{'ROUTE_16_FLY_HOUSE'},{'@EAST','USE_CUT'},
        {talk='TEXT_ROUTE16FLYHOUSE_BRUNETTE_GIRL'}),
      row('lift-key','LIFT_KEY','field',{'ROCKET_HIDEOUT_B4F'},{'@EAST'}),
      row('scope','SILPH_SCOPE','field',{'ROCKET_HIDEOUT_B4F'},{'@EAST','LIFT_KEY'}),
      row('flute','POKE_FLUTE','gift',{'MR_FUJIS_HOUSE'},{'@EAST','SILPH_SCOPE'}),
      row('card-key','CARD_KEY','field',{'SILPH_CO_5F'},{'@EAST'}),
      row('good-rod','GOOD_ROD','gift',{'FUCHSIA_GOOD_ROD_HOUSE'},{'@FUCHSIA'}),
      row('super-rod','SUPER_ROD','gift',{'ROUTE_12_SUPER_ROD_HOUSE'},{'@FUCHSIA'}),
      row('teeth','GOLD_TEETH','field',{'SAFARI_ZONE_WEST'},{'@FUCHSIA'}),
      row('surf','HM_SURF','gift',{'SAFARI_ZONE_SECRET_HOUSE'},{'@FUCHSIA'}),
      row('strength','HM_STRENGTH','gift',{'WARDENS_HOUSE'},{'@FUCHSIA','GOLD_TEETH'}),
      row('exp-all','EXP_ALL','gift',{'ROUTE_15_GATE_2F'},{'@FUCHSIA'},
        {talk='TEXT_ROUTE15GATE2F_OAKS_AIDE',aideFlag='EVENT_GOT_EXP_ALL'}),
      row('secret-key','SECRET_KEY','field',{'POKEMON_MANSION_B1F'},{'@CINNABAR'}),
    } end
    local rows={
      row('route29-potion','POTION','field',{'ROUTE_29'},{}),
      row('mystery-egg','MYSTERY_EGG','gift',{'MR_POKEMONS_HOUSE'},{}),
      row('flash','HM_FLASH','gift',{'SPROUT_TOWER_3F'},{'@EARLY'}),
      row('old-rod','OLD_ROD','gift',{'ROUTE_32_POKECENTER_1F'},{'@AZALEA'}),
      row('cut','HM_CUT','gift',{'ILEX_FOREST'},{'@AZALEA'}),
      row('bicycle','BICYCLE','gift',{'GOLDENROD_BIKE_SHOP'},{'@GOLDENROD'}),
      row('coin-case','COIN_CASE','field',{'GOLDENROD_UNDERGROUND'},{'@GOLDENROD'}),
      -- The native flower-shop reward disappears after Sudowoodo is cleared.
      -- Keeping this source fixed avoids making a required reward missable.
      row('squirtbottle','SQUIRTBOTTLE','gift',{'GOLDENROD_FLOWER_SHOP'},{'@GOLDENROD','BADGE_PLAIN'},{fixedSafe=true}),
      row('surf','HM_SURF','gift',{'DANCE_THEATER'},{'@ECRUTEAK'}),
      row('itemfinder','ITEMFINDER','gift',{'ECRUTEAK_ITEMFINDER_HOUSE'},{'@ECRUTEAK'}),
      row('good-rod','GOOD_ROD','gift',{'OLIVINE_GOOD_ROD_HOUSE'},{'@ECRUTEAK'}),
      row('strength','HM_STRENGTH','gift',{'OLIVINE_CAFE'},{'@ECRUTEAK'}),
      row('secretpotion','SECRETPOTION','gift',{'CIANWOOD_PHARMACY'},{'@CIANWOOD'}),
      row('fly','HM_FLY','gift',{'CIANWOOD_CITY'},{'GYM_STORM'}),
      row('red-scale','RED_SCALE','gift',{'LAKE_OF_RAGE'},{'@ROCKET_BASE'}),
      row('whirlpool','HM_WHIRLPOOL','gift',{'TEAM_ROCKET_BASE_B2F'},{'@ROCKET_BASE'}),
      row('basement-key','BASEMENT_KEY','gift',{'RADIO_TOWER_5F'},{'@RADIO'}),
      row('card-key','CARD_KEY','gift',{'GOLDENROD_UNDERGROUND_WAREHOUSE'},{'@RADIO','BASEMENT_KEY'}),
      row('waterfall','HM_WATERFALL','field',{'ICE_PATH_1F'},{'@BLACKTHORN'}),
      row('ticket','S_S_TICKET','gift',{'ELMS_LAB'},{'@CHAMPION'}),
      row('super-rod','SUPER_ROD','gift',{'ROUTE_12_SUPER_ROD_HOUSE'},{'@KANTO'}),
      row('machine-part','MACHINE_PART','field',{'CERULEAN_GYM'},{'@POWER_PLANT'}),
      row('lost-item','LOST_ITEM','gift',{'POKEMON_FAN_CLUB'},{'@POWER'}),
      row('pass','PASS','gift',{'COPYCATS_HOUSE_2F'},{'@POWER','LOST_ITEM'}),
    }
    if version=='crystal' then
      rows[#rows+1]=row('clear-bell','CLEAR_BELL','gift',{'RADIO_TOWER_5F'},{'@RADIO_CLEAR'})
      -- Buena is absent during the takeover. Model the reward after it ends,
      -- so missing an earlier visit can never lock a required item away.
      rows[#rows+1]=row('blue-card','BLUE_CARD','gift',{'RADIO_TOWER_2F'},{'@RADIO_CLEAR'})
      rows[#rows+1]=row('silver-wing','SILVER_WING','gift',{'PEWTER_CITY'},{'@POWER'})
    else
      rows[#rows+1]=row('radio-wing',version=='silver' and 'SILVER_WING' or 'RAINBOW_WING','gift',{'RADIO_TOWER_5F'},{'@RADIO_CLEAR'})
      rows[#rows+1]=row('pewter-wing',version=='silver' and 'RAINBOW_WING' or 'SILVER_WING','gift',{'PEWTER_CITY'},{'@POWER'})
    end
    return rows
  end

  function I.rules(gen,badges)
    local r={}
    local function add(token,...) rule(r,token,{...}) end
    local function gym(source,needs)
      rule(r,'GYM_'..source,needs)
      local sourceKey=source
      if gen==1 then
        sourceKey=({BOULDER='OPP_BROCK#1',CASCADE='OPP_MISTY#1',THUNDER='OPP_LT_SURGE#1',RAINBOW='OPP_ERIKA#1',SOUL='OPP_KOGA#1',MARSH='OPP_SABRINA#1',VOLCANO='OPP_BLAINE#1',EARTH='OPP_GIOVANNI#3'})[source]
      end
      local target=badges and badges.gymToBadge and badges.gymToBadge[sourceKey] or source
      if gen==1 then target=tostring(target):gsub('BADGE$','') end
      add('BADGE_'..target,'GYM_'..source)
    end
    if gen==1 then
      add('@EARLY','OAKS_PARCEL')
      gym('BOULDER',{'@EARLY'});gym('CASCADE',{'@EARLY'})
      add('USE_CUT','HM_CUT','BADGE_CASCADE');add('USE_FLASH','HM_FLASH','BADGE_BOULDER')
      add('USE_SURF','HM_SURF','BADGE_SOUL');add('USE_STRENGTH','HM_STRENGTH','BADGE_RAINBOW')
      add('@EAST','@EARLY','USE_CUT','USE_FLASH')
      gym('THUNDER',{'@EARLY','USE_CUT'});gym('RAINBOW',{'@EAST','USE_CUT'})
      add('@FUCHSIA','@EAST','POKE_FLUTE');gym('SOUL',{'@FUCHSIA'})
      gym('MARSH',{'@EAST','CARD_KEY'})
      add('@CINNABAR','@FUCHSIA','USE_SURF');gym('VOLCANO',{'@CINNABAR','SECRET_KEY'})
      gym('EARTH',{'GYM_BOULDER','GYM_CASCADE','GYM_THUNDER','GYM_RAINBOW','GYM_SOUL','GYM_MARSH','GYM_VOLCANO'})
      add('@CHAMPION','GYM_EARTH','USE_SURF','USE_STRENGTH')
    else
      add('@EARLY','MYSTERY_EGG');gym('ZEPHYR',{'@EARLY'})
      add('@AZALEA','@EARLY','BADGE_ZEPHYR');gym('HIVE',{'@AZALEA'})
      add('USE_CUT','HM_CUT','BADGE_HIVE');add('USE_SURF','HM_SURF','BADGE_FOG')
      add('USE_STRENGTH','HM_STRENGTH','BADGE_PLAIN');add('USE_WHIRLPOOL','HM_WHIRLPOOL','BADGE_GLACIER')
      add('USE_WATERFALL','HM_WATERFALL','BADGE_RISING')
      add('@GOLDENROD','@AZALEA','USE_CUT');gym('PLAIN',{'@GOLDENROD'})
      add('@ECRUTEAK','@GOLDENROD','SQUIRTBOTTLE');gym('FOG',{'@ECRUTEAK'})
      add('@CIANWOOD','@ECRUTEAK','USE_SURF');gym('STORM',{'@CIANWOOD','USE_STRENGTH'})
      gym('MINERAL',{'@ECRUTEAK','SECRETPOTION'})
      add('@ROCKET_BASE','@ECRUTEAK','USE_SURF');gym('GLACIER',{'@ROCKET_BASE'})
      add('@RADIO','GYM_ZEPHYR','GYM_HIVE','GYM_PLAIN','GYM_FOG','GYM_STORM','GYM_MINERAL','GYM_GLACIER')
      add('@RADIO_CLEAR','@RADIO','BASEMENT_KEY','CARD_KEY')
      add('@BLACKTHORN','@RADIO_CLEAR','USE_STRENGTH')
      gym('RISING',{'@BLACKTHORN','USE_SURF','USE_WHIRLPOOL'})
      add('@CHAMPION','GYM_RISING','USE_SURF','USE_WATERFALL','USE_STRENGTH')
      add('@KANTO','@CHAMPION','S_S_TICKET')
      add('@POWER_PLANT','@KANTO','USE_CUT','USE_SURF')
      add('@POWER','@POWER_PLANT','MACHINE_PART')
    end
    return r
  end
  local function hasAll(have,needs)
    for _,id in ipairs(needs or {}) do if not have[id] then return false end end
    return true
  end
  function I.solve(locations,placement,rules,initial,goal)
    local have=Core.copy(initial or {});local reached,spheres={},{}
    for pass=1,#locations+#rules+2 do
      local changed=false
      for _,r in ipairs(rules) do
        if not have[r.token] and hasAll(have,r.needs) then have[r.token]=true;changed=true end
      end
      local sphere={}
      -- Add rewards after scanning the whole sphere; no intra-pass ordering
      -- can make a self-locked item count as its own prerequisite.
      for _,loc in ipairs(locations) do
        if not reached[loc.id] and hasAll(have,loc.needs) then
          reached[loc.id]=true;sphere[#sphere+1]={location=loc.id,item=placement[loc.id] or loc.item}
        end
      end
      for _,entry in ipairs(sphere) do have[entry.item]=true;changed=true end
      if #sphere>0 then spheres[#spheres+1]=sphere end
      if not changed then break end
    end
    local blocked={};for _,loc in ipairs(locations) do if not reached[loc.id] then blocked[#blocked+1]=loc.id end end
    return #blocked==0 and (not goal or have[goal]==true),{spheres=spheres,blocked=blocked,have=have,goal=goal}
  end

  function I.place(locations,rules,seed,chaos,initial,goal)
    local placement,active={},{}
    for _,loc in ipairs(locations) do
      placement[loc.id]=loc.item
      if loc.shuffle and (chaos or not loc.fixedSafe) then active[#active+1]=loc end
    end
    local rng=Core.rng(Core.hash('progression-items-v1',seed))
    if chaos then
      local pool={};for i,loc in ipairs(active) do pool[i]=loc.item end
      rng:shuffle(pool);for i,loc in ipairs(active) do placement[loc.id]=pool[i] end
      return placement,{mode='CHAOS',checked=false}
    end
    local ok,proof=I.solve(locations,placement,rules,initial,goal)
    if not ok then return nil,'native item/badge route is unreachable: '..table.concat(proof.blocked,', ') end
    -- Start with a proven route, then only accept permutations that retain a
    -- complete route. A one-to-one pool cannot erase a required key or HM.
    for attempt=1,math.max(1,#active*10) do
      local first,second=rng:pick(active),rng:pick(active)
      if first and second and first~=second then
        placement[first.id],placement[second.id]=placement[second.id],placement[first.id]
        if not I.solve(locations,placement,rules,initial,goal) then
          placement[first.id],placement[second.id]=placement[second.id],placement[first.id]
        end
      end
    end
    local pass,certificate=I.solve(locations,placement,rules,initial,goal)
    assert(pass,'item placement lost its reachability proof')
    certificate.mode='SAFE';certificate.checked=true
    return placement,certificate
  end

  function I.resolveItems(game,gen)
    local ids,tokens={},{}
    local hmMoves=gen==1 and {'CUT','FLY','SURF','STRENGTH','FLASH'} or {'CUT','FLY','SURF','STRENGTH','FLASH','WHIRLPOOL','WATERFALL'}
    for _,id in ipairs(Core.sortedKeys(game.data.items or {})) do
      local def=game.data.items[id]
      if type(def)=='table' then
        local token=id
        local machine=def.machine
        local kind=machine and machine.kind
        if kind=='HM' or tostring(id):match('^HM') then
          local move=machine and machine.move or def.teaches
          if not move then move=hmMoves[tonumber(machine and machine.number) or tonumber(tostring(id):match('(%d+)'))] end
          if move then token='HM_'..move end
        elseif canonical(id)=='SECRETPOTION' then token='SECRETPOTION'
        elseif id=='S_S_AQUA_TICKET' then token='S_S_TICKET' end
        ids[token]=ids[token] or id;tokens[id]=token
      end
    end
    return ids,tokens
  end

  local function fields(game,gen)
    local out={}
    local maps=gen==2 and game.data.gen2Maps or game.data.maps
    local function add(map,parent,key)
      local raw=parent[key];local id=Core.resolveIndexedId(game.data.items,raw) or raw
      out[#out+1]={map=map,parent=parent,key=key,source=id,template=raw}
    end
    for _,mapId in ipairs(Core.sortedKeys(maps or {})) do
      local map=maps[mapId]
      for _,obj in ipairs(map.objects or {}) do
        if gen==1 and obj.item~=nil then add(mapId,obj,'item') end
        if gen==2 and obj.itemball and obj.itemball.item~=nil then add(mapId,obj.itemball,'item') end
      end
      if gen==2 then for _,ev in ipairs(map.bgEvents or {}) do
        if ev.hiddenItem and ev.hiddenItem.item~=nil then add(mapId,ev.hiddenItem,'item') end
      end end
    end
    if gen==1 then for mapId,rows in pairs(game.data.field and game.data.field.hiddenItems or {}) do
      for _,r in ipairs(rows) do if r.item~=nil then add(mapId,r,'item') end end
    end end
    return out
  end
  function I.prepare(game,cfg,gen,version)
    if not cfg.progression_items or (cfg.field_items=='UNCHANGED' and cfg.gift_items=='UNCHANGED') then return nil end
    local ids,tokens=I.resolveItems(game,gen)
    local locations,byGift,byReceipt={},{},{}
    local refs=fields(game,gen)
    local maps=gen==2 and game.data.gen2Maps or game.data.maps
    local actualMaps={};for id in pairs(maps or {}) do actualMaps[canonical(id)]=id end
    local reserved=setmetatable({},{__mode='k'})
    for _,profile in ipairs(I.catalog(gen,version)) do
      local itemId=ids[profile.item]
      local matchingMaps={};for _,m in ipairs(profile.maps) do
        local actual=actualMaps[canonical(m)];if actual then matchingMaps[actual]=true end
      end
      if itemId and next(matchingMaps) then
        local loc=Core.copy(profile);loc.refs={};loc.actual=itemId;loc.mapSet=matchingMaps
        if gen==1 then loc.receipt=receipts[loc.id] end
        if loc.kind=='field' then
          for _,ref in ipairs(refs) do
            if matchingMaps[ref.map] and ref.source==itemId then loc.refs[#loc.refs+1]=ref end
          end
        end
        if loc.kind=='gift' or #loc.refs>0 then
          loc.shuffle=(loc.kind=='gift' and cfg.gift_items~='UNCHANGED') or (loc.kind=='field' and cfg.field_items~='UNCHANGED')
          locations[#locations+1]=loc
          if loc.shuffle then
            for _,ref in ipairs(loc.refs) do reserved[ref.parent]=reserved[ref.parent] or {};reserved[ref.parent][ref.key]=true end
          end
          if loc.kind=='gift' then for m in pairs(matchingMaps) do
            byGift[canonical(m)..'|'..itemId]=loc
            if loc.receipt then byReceipt[canonical(m)..'|'..loc.receipt]=loc end
          end end
          if gen==1 and loc.talk and I.installed and cfg.safety=='SAFE' then
            assert(I.hardcodedAvailable[loc.maps[1]..'|'..loc.talk],'unsupported native gift handler: '..loc.id)
          end
        end
      end
    end
    local plan={locations=locations,byGift=byGift,byReceipt=byReceipt,ids=ids,tokens=tokens,reserved=reserved,gen=gen,version=version}
    game.data._urItemPlan=plan
    return plan
  end
  function I.reserved(game,parent,key)
    local p=game.data._urItemPlan
    return p and p.reserved[parent] and p.reserved[parent][key] or false
  end
  function I.finish(game,cfg,seed,badges,escape)
    local plan=game.data._urItemPlan;if not plan then return nil end
    local initial={}
    if escape and escape.certificate and escape.certificate.move then
      initial['HM_'..escape.certificate.move]=true
      local badge=escape.certificate.badge
      if badge then initial['BADGE_'..tostring(badge):gsub('BADGE$','')]=true end
    end
    plan.rules=I.rules(plan.gen,badges);plan.initial=initial
    plan.goal=plan.gen==1 and '@CHAMPION' or '@POWER'
    local placement,proof=I.place(plan.locations,plan.rules,seed,cfg.safety=='CHAOS',initial,plan.goal)
    if not placement then error('key/HM logic: '..tostring(proof),0) end
    plan.placement=placement;plan.proof=proof;plan.changed=0
    for _,loc in ipairs(plan.locations) do
      loc.target=assert(plan.ids[placement[loc.id]],'progression target missing')
      if loc.target~=loc.actual then plan.changed=plan.changed+1 end
      if loc.shuffle then for _,ref in ipairs(loc.refs) do
        ref.parent[ref.key]=type(ref.template)=='number' and game.data.items[loc.target].index or loc.target
      end end
    end
    return plan
  end
  function I.gift(plan,mapId,source)
    local loc=plan and plan.byGift[canonical(mapId)..'|'..tostring(source)]
    return loc and loc.target or source,loc~=nil,loc
  end
  function I.receipt(plan,mapId,label,game)
    local loc=plan and plan.byReceipt and plan.byReceipt[canonical(mapId)..'|'..tostring(label)]
    if not loc or loc.target==loc.actual then return nil end
    local def=game.data.items[loc.target]
    return 'You received\n'..tostring(def and def.name or loc.target)..'!'
  end
  function I.validate(game)
    local plan=game.data._urItemPlan;if not plan then return true end
    if not plan.placement or not plan.proof then return false,'progression placement was not built' end
    if plan.proof.checked then
      local ok,proof=I.solve(plan.locations,plan.placement,plan.rules,plan.initial,plan.goal)
      if not ok then return false,'unreachable progression rewards: '..table.concat(proof.blocked,', ') end
    end
    for _,loc in ipairs(plan.locations) do if loc.shuffle then
      for _,ref in ipairs(loc.refs) do
        local id=Core.resolveIndexedId(game.data.items,ref.parent[ref.key]) or ref.parent[ref.key]
        if id~=loc.target then return false,'progression pickup changed after validation: '..loc.id end
      end
    end end
    return true
  end

  -- Story scripts sometimes consume their quest token, hide an NPC, or set a
  -- one-time flag without checking GiveItem's result. SAFE keeps that award
  -- recoverable in the player's PC if the bag refuses it. Reserve just this
  -- reward's space, even when the PC is full; ordinary storage limits stay put.
  function I.storeInPC(game,id,qty)
    local save=assert(game.save,'progression reward needs a save')
    save.pcItems=save.pcItems or {}
    save.pcItems[id]=(save.pcItems[id] or 0)+(qty or 1)
    return true
  end
  function I.pcMessage(game,id)
    local def=game.data.items[id]
    return 'BAG FULL.\n'..tostring(def and def.name or id)..' was sent\nto your PC.\fMake room, then use\nWITHDRAW ITEM.'
  end
  function I.award(game,id,qty,safe,add,data)
    local ok=add(game.save,id,qty,data or game.data)
    if ok~=false then return ok,false end
    if not safe then return false,false end
    I.storeInPC(game,id,qty)
    return true,true
  end

  function I.installHardcoded(mod,R)
    if I.installed then return end
    I.installed=true
    local ok,Bag=pcall(require,'src.inventory.Bag')
    if not ok then error('progression gift bridge unavailable',0) end
    local contexts=setmetatable({},{__mode='k'})
    local originalAdd=Bag.add
    Bag.add=function(save,id,qty,data)
      local context=contexts[save]
      if not context or context.used or id~=context.source then return originalAdd(save,id,qty,data) end
      local awarded,pc=I.award(context.game,context.target,qty,context.safe,originalAdd,data)
      if awarded~=false then context.used=true end
      context.pc=pc
      return awarded
    end
    -- Command handlers and hand-ported asynchronous conversations use the
    -- same narrowly scoped bridge. PC withdrawals, shops, trades and other
    -- Bag.add callers never create a context and are left untouched.
    function I.beginAward(game,source,target,safe)
      local c={game=game,source=source,target=target,safe=safe}
      local previous=contexts[game.save];contexts[game.save]=c
      return c,function() if contexts[game.save]==c then contexts[game.save]=previous end end
    end
    local installed={};I.hardcodedAvailable=installed
    function I.attachHardcoded()
      if require('src.core.GameVersion').generation()~=1 then return end
      local okMS,MS=pcall(require,'src.script.MapScripts')
      if not okMS then return end
      for _,profile in ipairs(I.catalog(1,'red')) do
        if profile.talk then
          local mapId=profile.maps[1];local key=mapId..'|'..profile.talk
          local base=MS.baseTalk(mapId,profile.talk)
          if type(base)=='function' and base~=installed[key] then
            local wrapper
            wrapper=function(game,ow,npc,done)
              local a=R.active()
              local target,handled,loc=I.gift(a and a.game==game and a.itemPlan,mapId,profile.item)
              if not handled then return base(game,ow,npc,done) end
              done=done or function() end
              local TextBox=require('src.render.TextBox')
              local function say(message,after) game.stack:push(TextBox.new(game,message,after)) end
              -- Randomized encounters cannot guarantee 10/30/50 caught
              -- species. Managed aide rewards use location access, without
              -- altering the player's real Pokedex or native completion flag.
              if profile.aideFlag and a.cfg.safety=='SAFE' then
                local flags=game.save.flags
                if flags[profile.aideFlag] or (profile.portFlag and flags[profile.portFlag]) then
                  return say('I already gave you\nyour reward.',done)
                end
                local granted,pc=I.award(game,target,1,true,originalAdd)
                if granted==false then return say('Your bag is full.',done) end
                flags[profile.aideFlag]=true
                local name=(game.data.items[target] or {}).name or target
                return say(pc and I.pcMessage(game,target) or ('You received\n'..name..'!'),done)
              end
              local c,clear=I.beginAward(game,loc.actual,target,a.cfg.safety=='SAFE')
              local def=game.data.items[loc.actual]
              local oldName=def and def.name
              if def and game.data.items[target] then def.name=game.data.items[target].name end
              local label=loc.receipt
              local oldText=label and game.data.text and game.data.text[label]
              if label and game.data.text and target~=loc.actual then
                game.data.text[label]=I.receipt(a.itemPlan,mapId,label,game)
              end
              local function restore()
                clear();if def then def.name=oldName end
                if label and game.data.text then game.data.text[label]=oldText end
              end
              c.restore=restore
              local function finished(...)
                restore()
                if c.pc then return say(I.pcMessage(game,target),done) end
                return done(...)
              end
              -- The Bike Shop's legacy inventory check is not a completion
              -- flag once the BICYCLE can be found at another location.
              local owned=game.save.inventory and game.save.inventory[loc.actual]
              if profile.hideOwnedCheck then game.save.inventory[loc.actual]=nil end
              local success,result=pcall(base,game,ow,npc,finished)
              if profile.hideOwnedCheck then game.save.inventory[loc.actual]=owned end
              if not success then restore();error(result,0) end
              return result
            end
            MS.attachBase(mapId,{talk={[profile.talk]=wrapper}})
            installed[key]=wrapper
          end
        end
      end
    end
    mod.events:on('game.ready',function() I.attachHardcoded() end,200)
    local function clearAll()
      for save,c in pairs(contexts) do if c.restore then c.restore() end;contexts[save]=nil end
    end
    mod.events:on('save.loading',clearAll,200)
    mod.events:on('map.exited',clearAll,200)
    mod.events:on('save.loaded',function() clearAll();I.attachHardcoded() end,200)
    I.attachHardcoded()
  end
  return I
end
