return function(mod, Core, Randomizer, ItemLogic)
  local G={}
  local GIVE={giveitem=true,verbosegiveitem=true,verbosegiveitemvar=true}
  local pickupLists=setmetatable({},{__mode="k"})

  -- Field pickups already have their own seeded replacements. Mark only the
  -- engine's generated pickup lists, without changing any opcode/operand.
  function G.installPickupMarkers()
    local ok,H=pcall(require,"src.world.gen2.HiddenItems")
    if not ok or not H then return end
    for _,name in ipairs({"pickupScript","ballPickupScript"}) do
      local original=H[name]
      if type(original)=="function" and not G[name] then
        G[name]=original
        H[name]=function(...)
          local list=original(...)
          if type(list)=="table" then pickupLists[list]=true end
          return list
        end
      end
    end
  end

  local function identity(ctx)
    local map=ctx and (ctx.mapId or (ctx.overworld and ctx.overworld.map and ctx.overworld.map.id)) or "?"
    local script=ctx and ctx.scriptKey
    -- Never hash a table's memory address: retries/reloads must agree.
    if type(script)~="string" and type(script)~="number" then script=ctx and ctx.object or "gift" end
    return tostring(map).."|"..tostring(script or "gift")
  end

  local function pickup(ctx)
    if not ctx then return false end
    if pickupLists[ctx.scriptKey] then return true end
    local vm=ctx.vm
    return vm and pickupLists[vm.cmdList] or false
  end

  function G.rewrite(ctx,name,args,cmd,game)
    if pickup(ctx) then return args,cmd end
    if name=="give_item" and type(args)=="table" then
      local mapped=Randomizer.itemGift(game,args[1],identity(ctx))
      if mapped==args[1] then return args,cmd end
      local out=Core.copy(args); out[1]=mapped
      -- Native give_item fills the string buffer with the actual award. Use
      -- its normal receipt instead of a hardcoded 'received POTION' string.
      if out[3]~=false then out[3]=nil end
      return out,cmd
    end
    if type(cmd)~="table" then return args,cmd end
    if not GIVE[name] and name~="getitemname" then return args,cmd end
    local source=cmd.item or (cmd.args and cmd.args[1]) or (args and args[1])
    if source==255 or (name=="getitemname" and source==0) then source=ctx and ctx.vm and ((ctx.vm.scriptVar or 0)%256) end
    if source==nil then return args,cmd end
    if name=="getitemname" then
      -- Only rewrite a name lookup associated with an award in this list.
      -- Generic name queries also describe costs and quest requirements.
      local found=false
      for _,row in ipairs(ctx and ctx.vm and ctx.vm.cmdList or {}) do
        if GIVE[row.op] then
          local item=row.item or (row.args and row.args[1])
          if item==source or item==255 then found=true; break end
        end
      end
      if not found then return args,cmd end
    end
    local mapped=Randomizer.itemGift(game,source,identity(ctx))
    if mapped==source then return args,cmd end
    local out=Core.copy(cmd); out.item=mapped
    -- Keep quantity, var id and success/branch behavior intact. Named item
    -- takes precedence in the native VM even when ITEM_FROM_MEM was used.
    if out.args and #out.args>0 then out.args[1]=mapped end
    return args,out
  end

  G.installPickupMarkers()
  local unpack=table.unpack or unpack
  local function pack(...) return {n=select("#",...),...} end
  mod.hooks:wrap("script.command",function(nextFn,ctx,name,args,cmd)
    local game=ctx and ctx.game or mod.game
    if name=="fruittree" and ctx and ctx.vm and ctx.vm.fruitTreeItemFn then
      local vm=ctx.vm
      local original=vm.fruitTreeItemFn
      vm.fruitTreeItemFn=function(tree)
        return Randomizer.fieldTreeItem(game,original(tree),tree)
      end
      local out=pack(pcall(nextFn,ctx,name,args,cmd))
      vm.fruitTreeItemFn=original
      if not out[1] then error(out[2],0) end
      return unpack(out,2,out.n)
    end
    local newArgs,newCmd=G.rewrite(ctx,name,args,cmd,game)
    local a=ItemLogic and Randomizer.active and Randomizer.active()
    if a and a.game==game and name=='show_text' and args then
      local text=ItemLogic.receipt(a.itemPlan,identity(ctx):match('^([^|]+)'),args[1],game)
      if text then newArgs=Core.copy(args);newArgs[1]=text end
    end
    local source=(name=='give_item' and args and args[1]) or
      (GIVE[name] and cmd and (cmd.item or (cmd.args and cmd.args[1])))
    if source==255 then source=ctx and ctx.vm and ((ctx.vm.scriptVar or 0)%256) end
    local sourceId=game and game.data and (Core.resolveIndexedId(game.data.items,source) or source)
    local map=identity(ctx):match('^([^|]+)')
    local target,managed
    if a and a.game==game and not pickup(ctx) then target,managed=ItemLogic.gift(a.itemPlan,map,sourceId) end
    if managed and name=='give_item' then
      local c,clear=ItemLogic.beginAward(game,target,target,a.cfg.safety=='SAFE')
      local result=pack(pcall(nextFn,ctx,name,newArgs,newCmd))
      clear()
      if not result[1] then error(result[2],0) end
      if c.pc then require('src.script.Commands').show_text(ctx,ItemLogic.pcMessage(game,target)) end
      return unpack(result,2,result.n)
    elseif managed and GIVE[name] and ctx.vm and ctx.vm.giveItemFn then
      local vm=ctx.vm;local original=vm.giveItemFn
      vm.giveItemFn=function(item,qty)
        local granted=original(item,qty)
        if granted==false and a.cfg.safety=='SAFE' then
          ItemLogic.storeInPC(game,target,qty)
          vm:showRaw(ItemLogic.pcMessage(game,target))
          return true
        end
        return granted
      end
      local result=pack(pcall(nextFn,ctx,name,newArgs,newCmd))
      vm.giveItemFn=original
      if not result[1] then error(result[2],0) end
      return unpack(result,2,result.n)
    end
    return nextFn(ctx,name,newArgs,newCmd)
  end,100)
  return G
end
