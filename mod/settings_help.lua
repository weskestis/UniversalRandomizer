-- Player-facing descriptions live beside the actual setting keys. Every
-- selectable setting has help; the menu wraps and scrolls the whole string.
local H={}
local HELP={
  wild_randomness={
    BALANCED='Balanced favors Pokemon with a similar base-stat total to the original encounter. Early routes usually have weaker or unevolved Pokemon, but there is no first-evolution-only rule. Choose Truly random for every native evolution stage from the start. This choice is separate from SAFE item/progression logic.',
    UNRESTRICTED='Truly random can select any permitted native Pokemon, including fully evolved Pokemon at low levels. It ignores the BST limit for wilds and never forces an evolution based on level. Legendaries follow their own toggle. SAFE still keeps a few required HM-learner slots; choose CHAOS safety to remove those protections. The encounter layout determines whether each area uses a small pool or individual slots.',
    LEGACY='This saved run keeps the encounter policy used by its older version. SAFE favored similar strength in variety/pool modes; full-slot and chaos pools used unrestricted choices. Existing encounter tables are preserved. New runs offer explicit Balanced and Truly random choices.',
  },
  area_encounters={
    VANILLA='Keep the cartridge species in each area. Wild level percentages still apply. Wild Pokemon balance and extra species do not randomize a vanilla encounter table.',
    HIGH_VARIETY='One stable replacement per native species in each area, plus Extra species. When extras are enabled, encounters draw from that saved area pool. A route does not contain the whole Pokedex; choose Slot by slot for more independent replacements. The Wild Pokemon choice controls strength matching.',
    AREA_POOL='Build a stable pool of 8 distinct Pokemon per area, plus Extra species. Encounters draw from that saved pool. Wild Pokemon chooses Balanced or Truly random. The pool and draw position survive saving and restarting.',
    CHAOS_POOL='An older 8-plus-extras area pool. New Balanced / Truly random settings control its strength matching; legacy saves keep their original unrestricted pool. This does not turn item logic into CHAOS.',
    FULL_SLOT_RANDOM='Replace each native encounter slot independently, using the Wild Pokemon balance setting. The results stay fixed for the seed. Identical species-and-level rows share a replacement in Gen 1. Extra species, if enabled, also adds the area pool. Set extras to 0 for only the slot replacements.',
  },
  wild_evolution={AS_ROLLED='Keep the exact species selected by the encounter table. A low-level fully evolved Pokemon is allowed when the selection policy permits it. No form is changed just because of encounter level. Evolution after capture uses your Evolution settings.',LEVEL='After choosing an encounter, promote it along its evolution chain when its level reaches a normal level-evolution threshold. Other evolution methods may promote at level 45. This does not change how captured Pokemon evolve. BST limits take priority; Truly random always keeps the rolled species.'},
  safety={SAFE='Check the supported HM, item, badge and start dependencies, protect essential rewards and provide usable starter attacks. This is progression protection, not a Pokemon strength setting. You can combine SAFE with Truly random wild Pokemon. The solver covers the authored world, not arbitrary added quests.',CHAOS='Disable progression guarantees. HMs, keys and badges can be placed behind their own requirements, and a run can become impossible. Pokemon balance is chosen separately. A CHAOS starting town is also a separate setting.'},
  random_start={OFF='Begin in the normal starting town. No portal will trigger after leaving the lab.',LOGIC='Choose one of the authored starting towns with checked escape requirements. Selecting this also enables logical key/HM placement and SAFE badge shuffling. The portal happens once at the native intro handoff, not when you close setup.',CHAOS='Choose a starting town without a reachability guarantee. You may be stranded. This does not automatically change every item or Pokemon setting. The portal still waits for the native intro handoff.'},
  bst_match='BST means base-stat total: the sum of a species\' base stats. On enforces the chosen maximum difference for randomized starters, trainers, gifts, trades and balanced wilds. If nothing fits, the original species remains. Truly random wilds ignore this limit. Gen 1 uses five stats; Gen 2 uses six.',
  bst_difference='Set the maximum allowed base-stat-total difference, from 0 to 500. 50 gives roughly similar strength; 0 requires equal totals. This is a hard limit, not an evolution-stage filter. It applies only while BST limit is on; Truly random wilds are exempt.',
  base_stats='Unchanged keeps each Pokemon\'s native base stats. Shuffle redistributes its existing stat values among stats. Random generates a new distribution while preserving its total. Stats belong to the species, so the change affects both you and opponents.',
  types='Unchanged keeps native types. Evolution linked randomizes a family\'s types together. Random chooses types independently for each species. Only the active game\'s types are used: no Dark or Steel in Gen 1, and no Fairy in either generation.',
  evolutions='Unchanged keeps native evolution targets. Random changes what a Pokemon evolves into. The evolution method and requirements are handled separately by Trade evolutions. This does not restrict which stages can appear in the wild.',
  impossible_evos='On replaces trade-only or otherwise unsupported native evolution requirements with obtainable alternatives. Off keeps native requirements. This affects your Pokemon after capture, not the wild encounter pool.',
  starters='Unchanged keeps the normal starters. Random can choose any permitted native species. Two evolutions restricts starters to species with at least two remaining evolution stages. Only this setting has that stage restriction; it does not restrict wild encounters.',
  rival_starter='On makes the rival\'s corresponding starter follow the randomized starter mapping. Off leaves the rival\'s native starter choice. Other trainer Pokemon are controlled by Trainers.',
  movesets='Unchanged keeps native learnsets. Type bias favors moves matching the Pokemon\'s types. Random uses the native move pool without that preference. SAFE starter coverage can still supply usable damaging attacks to avoid an unwinnable opening battle.',
  trainers='Unchanged keeps trainer species. Random selects from the permitted native roster. Similar strength favors a comparable base-stat total. Type themed selects around a shared type. The BST limit and legendary toggle still apply. Trainer levels are set separately.',
  trainer_levels='Adjust ordinary trainer levels from -50% to +50% around their fixed route/native baseline. For example, +20% changes a baseline level 10 to 12. The value does not scale with your party\'s level. Bosses use their separate setting.',
  boss_levels='Adjust Gym leaders, rivals and other recognized boss levels from -50% to +50% around their fixed baseline. This overrides the ordinary Trainer levels percentage for those battles.',
  wild_levels='Adjust wild encounter levels from -50% to +50% around the route/native baseline. This changes level, not which evolution stage is selected. Your party\'s level never controls this baseline.',
  trainer_ai='Normal uses the native AI policy. Strong enables the supported stronger move-selection policy for ordinary trainers. This does not change their species, moves or level settings.',
  boss_ai='Normal uses the native boss AI policy. Strong enables the supported stronger move-selection policy for recognized bosses. Pokemon and level settings are separate.',
  extra_species='Add 0-5 distinct species to the seeded area encounter pool. With extras on, encounters can draw from that pool as well as the native replacement mapping. 0 keeps only the base mapping/pool. Extras never add Pokemon from another generation.',
  statics='Control fixed encounters and gifted Pokemon. Unchanged keeps the original species. Random uses the permitted native pool; Similar strength favors comparable base-stat totals. This is separate from gifted items.',
  tms='Random changes the native moves taught by TMs. HMs remain tied to their native field moves so the route logic can reason about them. TM/HM compatibility decides which Pokemon can learn the resulting moves.',
  tm_compat='Unchanged keeps native learnability. Type bias favors matching types. Random shuffles learnability. Full allows every selected Pokemon to learn all native TM/HM moves. SAFE may keep essential HM learners available.',
  field_items='Unchanged keeps pickups. Shuffle permutes eligible existing rewards. Random draws replacement items. Logical random uses the authored location/dependency solver for keys and HMs. CHAOS permits unchecked placements and also selects CHAOS safety. Random Start: Logic requires the logical placement mode.',
  gift_items='Random includes supported NPC item gifts in item randomization. This is different from Pokemon gifts. Protected/missable story rewards stay fixed in SAFE. Managed one-time SAFE gifts use the PC with a notice when the bag is full.',
  progression_items='Include supported HMs and key items in field/gift shuffling. SAFE checks their supported dependencies; CHAOS allows locks. Oak\'s Parcel and the Squirtbottle stay fixed in SAFE. Some escape-critical HMs may also stay fixed. Logical Random Start requires this on.',
  pc_item='Randomize the item stored in the bedroom PC at the start of a Gen 1 run. Gen 2 has no equivalent option here. This does not replace all items already stored in an existing save.',
  marts='Vanilla keeps shop inventory. Safe randomizes suitable ordinary stock. Chaos allows the broader supported shop pool. Mart safety is a separate switch that guarantees Pokeballs and Potions remain available.',
  mart_safety='Keep Pokeballs and Potions available in standard marts, including randomized shops, so catching and healing remain possible. A logical Saffron start also supplies Fresh Water for its native gate event.',
  trades='Unchanged keeps in-game NPC trades. Given randomizes the Pokemon received. Both also randomizes the requested Pokemon. This does not alter player-to-player link trades.',
  badges='Vanilla keeps Gym badge rewards. Safe shuffles them with supported field-move and progression checks. Chaos shuffles without those guarantees. Random Start: Logic automatically selects Safe badges when enabled.',
  allow_legendaries='Allow includes native legendary/mythical Pokemon in randomized pools. Block excludes them. Truly random still respects this toggle. Turning it on does not guarantee a legendary on every route.',
  seed_mode='Auto chooses a new seed for validation. Manual uses the number you enter, so the same game, settings and mod version can reproduce the run. A seed alone does not identify settings; the run code includes them.',
  manual_seed='Edit the seed one digit at a time. Left decreases a digit, right or A increases it. Select Save seed to accept; B discards this edit. Valid seeds are 1 through 2147483646.',
}
function H.describe(key,cfg,game,R)
  local value=HELP[key]
  if type(value)=='table' then value=value[cfg[key]] end
  if key=='random_start' and cfg.random_start~='OFF' then
    value=R.randomStartStatus(game,cfg)..'\n\n'..value
  end
  return value or ('Change '..tostring(key):gsub('_',' ')..'.')
end
H.keys=HELP
return H
