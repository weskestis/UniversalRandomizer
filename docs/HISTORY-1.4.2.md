# Universal Randomizer 1.4.2

[Download the latest release](https://github.com/weskestis/UniversalRandomizer/releases/latest), or check for updates in the Gen1Recomp mod manager. Install the release ZIP as one mod. The manifest keeps the compatibility range `>=0.2.18 <1.0.0`; Crystal needs launcher 0.2.24 or newer.

This release fixes the Gen 2 `pokemon.TREECKO.dexEntry.heightFt/heightIn: unknown field` loader failure across the expanded roster, fixes first-screen validation of the Route 1 gift, and restores Random Start behavior that was missing from the public release.

## Random Start

Choose **WORLD + ITEMS > START: LOGIC** for a new run. This selects SAFE badges and logical key/HM placement. All 15 authored starts have modeled escape routes; the first Gym city is excluded in each generation.

- Randomizer Protection Guards and invisible connection blocks are removed. Old saved guard settings cannot turn them back on. Native story events still operate normally.
- In Gen 1 the portal waits until the real Pokédex bootstrap is complete and the player leaves Oak's Lab. In Gen 2 it arms after receiving Elm's starter and fires on the first exterior warp. It runs once.
- HMs are obtained through actual pickups and gifts. Cianwood keeps Fly behind Chuck; Cinnabar's local Surf/Secret Key route is included in the item solver. The portal does not grant story flags or preload HM items/moves.
- The local Pokémon Center becomes the initial respawn, then ordinary Center visits take over.
- Route difficulty uses fixed progression baselines plus the Wild/Trainer/Boss percentage settings. Raising the party's level does not raise the world's baseline. Route hints check whether the party can actually use the required field move.
- For a Saffron start, the local mart supplies Fresh Water. Buy it and give it to a native guard to open the gates.

Existing 1.4.1 saves retain their legacy item/start/badge placement mode. Guard removal and loader fixes apply on update, but start a **new run** for the restored progression placement logic. Existing party-relative level modes migrate to the fixed baseline policy. No inventory or completed story flags are reset.

## Keys, HMs and ordinary items

**SAFE** uses checked progression placements; **CHAOS** permits unreachable placements. Random Start LOGIC uses the authored location graph, including HM ownership, the badge needed to use it, and Gym access. In other runs, enable **KEYS + HMS** with item/gift randomization to use the ordinary route's progression pool. **ITEMS: LOGIC RANDOM** also selects the authored graph; changing SAFETY to CHAOS switches that pool to unchecked placement.

Keys and HMs are shuffled among audited field pickups and gifts. Proof-critical HMs may stay on their native checks when an isolated start needs that precise escape route. Oak's Parcel and the Squirtbottle stay fixed in SAFE because their native events can become missable. Mutually exclusive fossils, special events and custom quest rewards without authored requirements are outside the checked pool. A missing supported source or unsatisfied route fails validation rather than receiving a SAFE result.

Managed one-time SAFE gifts survive a full bag by going to the PC with a notice. Withdraw the item after making room. Native completion flags remain in effect. Ordinary gifts and purchases keep normal capacity behavior; CHAOS keeps native failure behavior.

Gift randomization covers native Gen 1/Gen 2 item commands, including variable-held item IDs, plus the audited Gen 1 Bike Shop, Oak aides, Route 1 sample, Coin Case, Old Amber and Fly callbacks. Field items include visible/hidden pickups and Gen 2 fruit trees. Field pickups are not randomized a second time as gifts. Custom rewards that bypass these interfaces are outside the adapter.

**MART SAFETY** keeps Poké Balls and Potions in marts and defaults on for new configurations. Set MARTS to SAFE or CHAOS to randomize stock. Progression keys are placed at audited pickups and gifts, not in mart stock.

## Similar-strength encounters

In **POKEMON**, enable **BST MATCH** and set **BST DIFFERENCE** from **0–500**; the default tolerance is **50**. Zero requires equal base-stat totals. The picker supports increments of 1, 10 and 50.

The bound applies to randomized starters, wild encounters, trainer replacements, static/gift Pokémon and trades. It uses the active cartridge's stats: five in Gen 1, six in Gen 2. If no eligible replacement exists, the source remains. Tight bounds can reduce variety and trade uniqueness. Automatic wild evolution is suppressed while BST matching is enabled so it cannot exceed the bound; evolution after capture is unchanged.

## Untamed Tohjo

Enable [Untamed Tohjo](https://github.com/goldenroddeptstore/untamed-tohjo) alongside the randomizer. The adapter supplies seeded species and levels to Untamed's callbacks for grass, Surf, fishing, time groups and swarms. Previews do not consume the encounter stream or change saved encounter tables. Untamed retains ownership of its chains, DVs, shinies, followers and roaming identities.

## Expanded content and other settings

The bundled roster covers National Dex #001–493 with generation-specific registration data, art, icons and cries. Gen 2 Pokédex height and weight use its own encoded integer fields; Gen 1 keeps split feet/inches and decimal pounds. Metric heights are corrected for all 493 source records. Native species keep their cartridge learnsets; added species use the bundled Platinum learnsets.

Other settings include battle rulesets GEN1–GEN4, base stats, types, evolutions, starters, rivals, movesets, TM compatibility, trainers, area encounter modes, statics, trades, abilities/natures under Gen 3/4 rules, AI strength and separate level percentages. Earlier release history is preserved in [the archived documentation](https://github.com/weskestis/UniversalRandomizer/blob/main/docs/HISTORY-THROUGH-1.4.1.md); historical guard and level-mode descriptions do not describe this release.

## Verification and development

Tests use Gen1Recomp 0.3.99 at `8b981540e882440f33ab09f1f56030e0ce4a8787` and Untamed 1.2.1 at `2a55770b4016e1da699b9eae79b5266afa2aa781`.

Coverage includes real host schemas/reference validation for the complete expanded installer in all six games; native NPC/script/VM award paths and full-bag recovery; cold setup; 450 SAFE and 450 CHAOS ordinary-route placements; 160 Random Start seeds covering all 15 starts; Continue placement snapshots; and actual Untamed spawning/battle queues. The map fixtures model the audited routes, not every possible modded map. No full ROM/Android playthrough was performed.

`tools/package_release.py` overlays `mod/` on the SHA-256-pinned 1.3.42 package and verifies every packed file hash. GitHub Actions tests the built ZIP under LuaJIT and Lua 5.4 before publishing `v1.4.2` and updating the repository ZIP.

For local tests, build the package and set `MOD_SOURCE` and `MOD_BASE` to its extracted mod folder, `HOST_SOURCE` to the pinned host checkout, and `UNTAMED_SOURCE` to the pinned Untamed `main.lua`. Run:

```sh
luajit tests/features.lua
luajit tests/progression_items.lua
luajit tests/startup_random_start.lua
luajit tests/expanded_registration.lua
python3 tests/run_lua.py tests/features.lua tests/progression_items.lua tests/startup_random_start.lua tests/expanded_registration.lua
```
