# Universal Randomizer 1.4.2 — Loader and Random Start fixes

Update through the Gen1Recomp mod manager, or install the attached ZIP.

- Fixes the Gen 2 `TREECKO.dexEntry.heightFt/heightIn: unknown field` failure for the complete expanded roster. Converts Pokédex height/weight to the correct generation-specific fields and fixes metric heights for all 493 source entries.
- Fixes `unsupported native gift handler: route1-gift` during first-screen validation by initializing the native script registry before setup checks.
- Removes Random Start Protection Guards and invisible exit blocks, including old saved guard settings. Restores the real intro handoff, local respawn and fixed route levels.
- Restores checked key/HM placement for all 15 authored Random Start locations. Checks HM badges and Gym access, retains Cianwood's native Fly reward after Chuck, and does not preload HMs or fabricate story progress. CHAOS remains unchecked.
- Preserves managed one-time rewards through full-bag PC recovery. Saffron starts provide a purchasable guard drink rather than skipping the story event.
- Keeps Untamed previews separate from saved encounters and encounter RNG. Retains BST tolerance 0–500, default 50, and Mart Safety.

Existing 1.4.1 saves retain their original item/start/badge placement mode. Start a **new run** to use the restored progression placement logic. Old level modes migrate to fixed progression baselines; player inventory and story flags are preserved.

The manifest remains `>=0.2.18 <1.0.0`; Crystal needs 0.2.24+. Tested against pinned Gen1Recomp 0.3.99 and Untamed 1.2.1 under LuaJIT and Lua 5.4, including native schema/reference checks across six games, 450 SAFE/450 CHAOS ordinary placements, 160 Random Start seeds covering all 15 starts, native gift awards, full-bag recovery and Continue snapshots. No full Android/ROM playthrough was performed. Custom quests outside the authored progression model are not certified.
