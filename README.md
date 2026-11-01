# Universal Randomizer 1.6.4 — Field-item setting cycling fix

[Download the latest release](https://github.com/weskestis/UniversalRandomizer/releases/latest), or check for updates in the Gen1Recomp mod manager. Update and fully restart the game. Logical random remains selectable on every lap through Field items; settings no longer require an app restart to recover that option. Existing saves retain their original worlds, and the badge-validation and Type Bias fixes remain included.

## Field-item settings stay selectable

With Random Start off, **Field items** repeatedly cycles through **Unchanged > Shuffle > Random > Logical random > Chaos**, in either direction or with A. Previously, visiting Chaos left Progression safety on CHAOS, which immediately changed Logical random back to Chaos on subsequent laps.

The explicit selection now takes precedence: **Logical random selects SAFE progression safety**, while **Chaos selects CHAOS**. Choosing an ordinary field-item mode keeps the current safety choice. The guide explains these effects.

With **Random Start: Logic**, field items cycle between Logical random and Chaos, the two supported graph modes. Turning Random Start off restores the ordinary item choices. Selecting Logic Random Start also selects SAFE progression, Safe badges and logical key/HM placement. Explicitly switching Progression safety afterward still updates the graph item mode consistently.

The change affects setup controls. Existing saves, seed generation and item-placement algorithms retain their previous behavior.

## SAFE badges with Random Start off

The Crystal validation failure listing unreachable items such as Cut, Bicycle, Surf and the Squirtbottle came from an unchecked badge permutation being used outside Logic Random Start. A required early badge could end up behind its own gate, so the key/HM solver correctly rejected the resulting route.

**World + items > Badges: Safe** now builds a checked permutation for ordinary starts as well. It begins with the native route and accepts only badge swaps that preserve a complete item/badge path. Early required badges stay reachable; the remaining valid choices still vary with the seed. Field items, gifts and HMs continue to be randomized under their selected settings, with reachability checks enabled.

Choosing **Badges: Chaos** together with SAFE key/HM randomization now gives an immediate settings explanation: select Vanilla/Safe badges, or choose Chaos progression safety for unchecked placements. Retrying seeds is not presented as the solution to that incompatible combination. Failed validation details remain scrollable on the Validate/Retry row; highlighting Pokemon, World + items or Safety + seed displays that section's own guide.

Existing saves keep their original badge rewards and item locations on Continue. A new run always uses the corrected policy, including when preferences were saved by an older version. No ongoing world is silently rerolled. Logic Random Start keeps its existing authored start proofs and badge rules.

## Type Bias learnset fix

**Type Bias now guarantees at least one usable damaging STAB attack in a newly generated Pokemon's moveset at every level, whenever its native move pool has one.** This applies in SAFE and CHAOS, follows randomized species types, and survives SAFE starter coverage. SAFE starters still receive four distinct damaging attacks with type diversity where possible. This starter coverage is automatic under **Safety + seed > Progression safety: SAFE**; it is not a separate toggle. Type Bias itself works under both SAFE and CHAOS.

The ordinary random rolls still have a **65% chance per slot** to draw from matching types; those rolls can include status moves, and the unrestricted 35% can also select matching moves. The separate STAB guarantee repairs a moveset when needed, so 65% is not the final percentage of damaging STAB moves. Later unique moves cannot push out the only usable STAB attack from a freshly generated moveset. When a type has only one suitable attack, it can be relearned at the same level as a new coverage move so later encounters still gain new moves. Normal move-learning choices after capture remain yours.

Status moves, fixed-damage attacks, OHKO/counter moves, attacks requiring sleep, self-destructing attacks, and moves whose type or damage cannot promise STAB do not satisfy that guarantee. Gen 1 has no STAB-capable Dragon attack: Dragon Rage deals fixed damage. Those cases continue using only native moves rather than importing an attack or failing validation. The guarantee is availability of an attack, not a promise that every use hits or damages every opponent.

No new seed is required for the fix on an existing Type Bias run. Restart and Continue to rebuild its learnsets. Existing party, boxed and daycare Pokemon retain their chosen moves, PP and PP Ups; encounters created afterward use the corrected learnsets. Random and Unchanged learnset modes retain their previous seeded results. The in-game Learnsets guide now explains these odds, guarantees and exceptions and supports scrolling.

## Setup controls and explanations

The setup uses a modern 640x360 layout in both engines. Settings and their values occupy the left panel; a separate guide explains the highlighted setting, its current choice and interactions. Long descriptions and validation errors wrap without dropping text and scroll automatically. **SELECT** focuses the guide; **Up/Down** scrolls a line, **Left/Right** jumps to the beginning/end, and **B** returns to the settings.

**Up/Down** selects a setting; **Left/Right** changes its value in either direction; **A** chooses or opens an editor. Navigation repeat follows elapsed real time, so game-speed multipliers do not make a held direction race through the menu. Leaving setup with B opens a vanilla confirmation. Validation cannot be dismissed or restarted by a held button.

Open **Wild encounters > Wild Pokemon**:

- **Balanced** favors species with similar native base-stat totals. Early routes often have weaker or unevolved species; there is no first-stage-only rule.
- **Truly random** permits every allowed native evolution stage at low levels. It ignores the BST limit for wild Pokemon and never automatically evolves a selected species because of level. Starters/trainers/gifts/trades still honor their own settings and the BST limit. The legendary toggle still applies.

**Progression safety** is separate: SAFE can be combined with Truly random Pokemon. SAFE still retains a few essential Gen 2 HM-learner slots; CHAOS removes those protections. Encounter layout determines the saved area pool or slot mapping, so a randomized route does not contain the entire Pokedex. **Extra species: 0** keeps the base slot mapping; new runs keep species as rolled unless Balanced's **Wild evolution: Match level** is explicitly selected.

Existing runs keep their saved encounter tables and legacy balance/evolution policy. Start a new run to choose the new encounter controls; installing an update does not silently reroll an ongoing world.

## When Random Start triggers

Choose **World + items > Random Start: Logic**. Setup shows the current start setting, its prerequisites and a summary before validation. **Randomizer Info** shows whether the portal is off, waiting, ready or complete.

- **Red/Blue/Yellow:** choose a starter, finish the rival battle, collect Oak's Parcel from Viridian Mart, return it for the Pokedex, then leave Oak's Lab. The first lab exit is intentionally not the handoff. A one-time reminder after that first exit explains the remaining steps.
- **Gold/Silver/Crystal:** receive your starter and leave Elm's Lab for New Bark Town. Original starters now work as well as randomized starters. Saving/reloading before departure also works; an interior warp cannot consume the portal.

The portal runs once and preserves native story state. It does not manufacture the Pokedex/Parcel flags or preload HMs.

## Pokémon, rules and visuals

The randomizer now uses only content native to the game being played:

| Game | Pokémon pool | Battle engine and presentation |
| --- | --- | --- |
| Red / Blue / Yellow | Native #001–151 | That edition's default rules, sprites, palettes, icons, cries and animations |
| Gold / Silver / Crystal | Native #001–251 | That edition's default rules, sprites, palettes, icons, cries and animations |

The expanded Gen 3/4 Pokémon, moves, items, abilities, natures, battle-rule layer and replacement art/audio are removed from the package. Cross-generation Pokédex and ruleset selectors are removed, along with ability and nature settings. The game determines its own native roster and rules automatically; a Red run cannot select Gen 2 Pokémon or rules. Move randomization uses the cartridge's native move IDs. Type randomization cannot introduce Dark/Steel into Gen 1 or later-generation types into either engine.

Randomizer options for native systems remain: starters, rivals, stats, types, evolutions, movesets, TM compatibility, trainers, encounters, statics, trades, items, marts, badges, Random Start, AI strength and level percentages. Gen 2 does not show the Gen 1 bedroom-PC-item option.

## Existing saves

Native-content saves can continue. Retired configuration fields are normalized to the active cartridge, and saved encounter caches containing out-of-generation species are rebuilt with native choices. Original item/start/badge placement modes remain available for native legacy saves.

A save that actually owns unsupported Pokémon, moves or items needs [1.4.2](https://github.com/weskestis/UniversalRandomizer/releases/tag/v1.4.2). Continue shows a message before adopting such a save, leaving its contents untouched. Use the previous release for that run or start a new run in 1.6.4. No automatic species replacement or deletion is performed. Keep separate save slots for old expanded runs and new native runs.

## Random Start and item logic

Choose **World + items > Random Start: Logic** to select SAFE badges and logical key/HM placement. The 15 authored starts retain their modeled escape routes. Randomizer guards and invisible connection blocks remain removed. Native story events still operate normally.

The portal waits for the actual intro handoff, runs once, and establishes a local respawn. HMs come from real pickups and gifts: Cianwood keeps Fly after Chuck, and Cinnabar's local Surf/Secret Key route participates in the solver. A Saffron start supplies purchasable Fresh Water for its native guard event. Route levels use fixed progression baselines plus the Wild/Trainer/Boss percentage settings, independent of party level.

**SAFE** checks item, HM, badge and Gym dependencies. **CHAOS** permits unreachable placements. Other starts can use **KEYS + HMS** with field/gift randomization, or **ITEMS: LOGIC RANDOM** for the authored location graph. Proof-critical HMs may stay fixed when needed for an isolated start. Oak's Parcel and the Squirtbottle remain fixed in SAFE because their native events can become missable. Custom quests and unaudited event sources are outside the checked pool.

Managed one-time SAFE gifts go to the PC with a notice if the bag is full. Ordinary purchases keep native capacity behavior. Field/gift randomization includes native item commands, audited Gen 1 hardcoded callbacks, visible/hidden pickups and Gen 2 fruit trees. **MART SAFETY** keeps Poké Balls and Potions available and defaults on for new runs.

## Similar-strength encounters

Enable **BST MATCH** under POKEMON, then set **BST DIFFERENCE** from 0–500; the default tolerance is 50. The bound applies to randomized starters, balanced wild encounters, trainers, statics/gifts and trades using the active game's five-stat or six-stat total. With no eligible replacement, the native source remains. Truly random wilds ignore this bound. Automatic wild evolution is suppressed while BST matching is enabled so the result stays within the bound; evolution after capture is unchanged.

## Untamed Tohjo

[Untamed Tohjo](https://github.com/goldenroddeptstore/untamed-tohjo) remains supported. Its callbacks receive seeded native species and levels for grass, Surf, fishing, time groups and swarms. Previews do not consume the encounter stream or change saved encounter tables. Untamed retains ownership of its own followers, roaming identities and visual features.

## Compatibility and verification

The manifest remains `>=0.2.18 <1.0.0`. Crystal requires launcher 0.2.24+. Automated tests use Gen1Recomp 0.3.99 at `8b981540e882440f33ab09f1f56030e0ce4a8787` and Untamed 1.2.1 at `2a55770b4016e1da699b9eae79b5266afa2aa781`.

Checks cover all six editions: complete mod entry-point registration, visible settings, native species/move/type boundaries, untouched visual records and renderer methods, protected Continue behavior, actual native NPC/script/VM gifts, full-bag recovery, 450 SAFE/450 CHAOS ordinary placements, 160 Random Start seeds spanning all 15 starts, native legacy placement snapshots and Untamed spawning/battle queues. The new controls are exercised with input sequences, validation/re-entry checks and long-text scrolling. A 1,920-seed wild-mode matrix covers all six editions and four encounter layouts, and portal checks include original/randomized starters and cold Continue. Type Bias tests use the pinned engines' actual move constructors across all six editions, both safety modes, original/randomized types, 19 encounter levels, sparse STAB pools, staged setup and Continue. An additional 288-seed matrix checks SAFE badges with ordinary field/gift channels across all six games, and 72 ordinary-start runs check the full authored item graph. Cold Continue checks preserve both old and new badge policies. Field-item control checks repeat complete cycles with A, left and right, both starting safety choices, menu re-entry and Logic Random Start across all six games. Tests run under LuaJIT and Lua 5.4. Fourteen views of the actual menu are rendered in LOVE with real font-bound checks. No full Android/ROM playthrough was performed.

The package builder inherits only `core.lua` and `adapters.lua` from the SHA-256-pinned base, then adds reviewed `mod/` sources and current documentation. It does not carry forward obsolete installers, assets or rulesets. Every packed file hash is verified before publishing the launcher-compatible release and repository ZIP.

For local checks, build with `python3 tools/package_release.py --output dist`, set `MOD_SOURCE=dist/mod`, `MOD_BASE=dist/mod`, `HOST_SOURCE` to the pinned host checkout and `UNTAMED_SOURCE` to the pinned Untamed `main.lua`, then run:

```sh
luajit tests/features.lua
luajit tests/progression_items.lua
luajit tests/startup_random_start.lua
luajit tests/native_content.lua
luajit tests/wild_modes.lua
luajit tests/modern_menu.lua
luajit tests/type_bias.lua
python3 tests/run_lua.py tests/features.lua tests/progression_items.lua tests/startup_random_start.lua tests/native_content.lua tests/wild_modes.lua tests/modern_menu.lua tests/type_bias.lua
```
