-- Native cartridge content owns all species records, artwork and battle rules.
-- The only compatibility work here removes settings left by our old overlay
-- and prevents opening an expanded save with missing owned content.
return function(mod)
  local N={}
  local function cap(game)
    local GV=require('src.core.GameVersion')
    return (GV.generation(GV.get())==2) and 251 or 151
  end
  local function resolve(registry,id)
    if registry and registry[id] then return registry[id] end
    if type(id)=='number' then
      for _,def in pairs(registry or {}) do
        if type(def)=='table' and def.index==id then return def end
      end
    end
  end
  function N.restoreRules(game,loaded)
    if not game then return end
    local function reset(options)
      if options and tostring(options.ruleset):match('^ur_gen[1-4]$') then
        options.ruleset='gen1_faithful'
      end
    end
    reset(game.options);reset(game.save and game.save.options);reset(loaded and loaded.options)
    mod.save:set('pre_randomizer_ruleset',nil)
  end
  function N.incompatibleSave(game,save)
    local md=save and save.modData and save.modData.universal_randomizer
    if not (md and md.seed) then return nil end
    local data=game.data or {};local max=cap(game);local seen={}
    local function mons(node)
      if type(node)~='table' or seen[node] then return nil end
      seen[node]=true
      if node.species then
        local d=resolve(data.pokemon,node.species)
        local dex=d and tonumber(d.dex)
        if not dex or dex<1 or dex>max then return tostring(node.species) end
        for _,slot in ipairs(node.moves or {}) do
          local id=type(slot)=='table' and (slot.id or slot.move) or slot
          if id and id~=0 and id~='' then
            local move=resolve(data.moves,id);local index=move and tonumber(move.index)
            if not index or index<1 or index>(max==151 and 165 or 251) then return tostring(id) end
          end
        end
        local held=node.item or node.heldItem
        if held and held~=0 and held~='NO_ITEM' and not resolve(data.items,held) then return tostring(held) end
      else
        for _,value in pairs(node) do local why=mons(value);if why then return why end end
      end
    end
    for _,key in ipairs({'party','boxes','daycare'}) do local why=mons(save[key]);if why then return why end end
    for _,key in ipairs({'inventory','pcItems'}) do
      for id in pairs(save[key] or {}) do
        if not resolve(data.items,id) then return tostring(id) end
      end
    end
  end
  function N.attach(game)
    if not game then return end
    N.restoreRules(game)
    if game._urNativeSaveGuard then return end
    local method=type(game.continueGame)=='function' and 'continueGame' or 'restoreSave'
    local original=game[method]
    if type(original)~='function' then return end
    game._urNativeSaveGuard=true
    game[method]=function(self,save,...)
      if N.incompatibleSave(self,save) then
        local TextBox=require('src.render.TextBox')
        self.stack:push(TextBox.new(self,'This save needs\nRandomizer 1.4.2.\nUse that version or\nstart a NEW GAME.'))
        return false
      end
      N.restoreRules(self,save)
      return original(self,save,...)
    end
  end
  function N.install()
    mod.events:on('game.ready',function(ev) N.attach((ev and ev.game) or mod.game) end,250)
    mod.events:on('save.loaded',function(ev) N.restoreRules((ev and ev.game) or mod.game) end,250)
  end
  return N
end
