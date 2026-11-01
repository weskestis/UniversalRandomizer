# Universal Randomizer 1.5.0 — Native game content

[Download the latest release](https://github.com/weskestis/UniversalRandomizer/releases/latest), or check for updates in the Gen1Recomp mod manager. Update, fully restart the game, and start a new run to use the simplified setup.

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

A save that actually owns unsupported Pokémon, moves or items needs [1.4.2](https://github.com/weskestis/UniversalRandomizer/releases/tag/v1.4.2). Continue shows a message before adopting such a save, leaving its contents untouched. Use the previous release for that run or start a new run in 1.5.0. No automatic species replacement or deletion is performed. Keep separate save slots for old expanded runs and new native runs.

## Random Start and item logic

Choose **WORLD + ITEMS > START: LOGIC** to select SAFE badges and logical key/HM placement. The 15 authored starts retain their modeled escape routes. Randomizer guards and invisible connection blocks remain removed. Native story events still operate normally.

The portal waits for the actual intro handoff, runs once, and establishes a local respawn. HMs come from real pickups and gifts: Cianwood keeps Fly after Chuck, and Cinnabar's local Surf/Secret Key route participates in the solver. A Saffron start supplies purchasable Fresh Water for its native guard event. Route levels use fixed progression baselines plus the Wild/Trainer/Boss percentage settings, independent of party level.

**SAFE** checks item, HM, badge and Gym dependencies. **CHAOS** permits unreachable placements. Other starts can use **KEYS + HMS** with field/gift randomization, or **ITEMS: LOGIC RANDOM** for the authored location graph. Proof-critical HMs may stay fixed when needed for an isolated start. Oak's Parcel and the Squirtbottle remain fixed in SAFE because their native events can become missable. Custom quests and unaudited event sources are outside the checked pool.

Managed one-time SAFE gifts go to the PC with a notice if the bag is full. Ordinary purchases keep native capacity behavior. Field/gift randomization includes native item commands, audited Gen 1 hardcoded callbacks, visible/hidden pickups and Gen 2 fruit trees. **MART SAFETY** keeps Poké Balls and Potions available and defaults on for new runs.

## Similar-strength encounters

Enable **BST MATCH** under POKEMON, then set **BST DIFFERENCE** from 0–500; the default tolerance is 50. The bound applies to randomized starters, wild encounters, trainers, statics/gifts and trades using the active game's five-stat or six-stat total. With no eligible replacement, the native source remains. Automatic wild evolution is suppressed while BST matching is enabled so the result stays within the bound; evolution after capture is unchanged.

## Untamed Tohjo

[Untamed Tohjo](https://github.com/goldenroddeptstore/untamed-tohjo) remains supported. Its callbacks receive seeded native species and levels for grass, Surf, fishing, time groups and swarms. Previews do not consume the encounter stream or change saved encounter tables. Untamed retains ownership of its own followers, roaming identities and visual features.

## Compatibility and verification

The manifest remains `>=0.2.18 <1.0.0`. Crystal requires launcher 0.2.24+. Automated tests use Gen1Recomp 0.3.99 at `8b981540e882440f33ab09f1f56030e0ce4a8787` and Untamed 1.2.1 at `2a55770b4016e1da699b9eae79b5266afa2aa781`.

Checks cover all six editions: complete mod entry-point registration, visible settings, native species/move/type boundaries, untouched visual records and renderer methods, protected Continue behavior, actual native NPC/script/VM gifts, full-bag recovery, 450 SAFE/450 CHAOS ordinary placements, 160 Random Start seeds spanning all 15 starts, native legacy placement snapshots and Untamed spawning/battle queues. Tests run under LuaJIT and Lua 5.4. No full Android/ROM playthrough was performed.

The package builder inherits only `core.lua` and `adapters.lua` from the SHA-256-pinned base, then adds reviewed `mod/` sources and current documentation. It does not carry forward obsolete installers, assets or rulesets. Every packed file hash is verified before publishing the launcher-compatible release and repository ZIP.

For local checks, build with `python3 tools/package_release.py --output dist`, set `MOD_SOURCE=dist/mod`, `MOD_BASE=dist/mod`, `HOST_SOURCE` to the pinned host checkout and `UNTAMED_SOURCE` to the pinned Untamed `main.lua`, then run:

```sh
luajit tests/features.lua
luajit tests/progression_items.lua
luajit tests/startup_random_start.lua
luajit tests/native_content.lua
python3 tests/run_lua.py tests/features.lua tests/progression_items.lua tests/startup_random_start.lua tests/native_content.lua
```
