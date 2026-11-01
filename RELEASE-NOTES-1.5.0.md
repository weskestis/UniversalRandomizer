# Universal Randomizer 1.5.0 — Native Pokémon, rules and sprites

Update through the launcher, fully restart the game, and start a new run for the simplified setup.

- Red/Blue/Yellow use their native 151-species pool. Gold/Silver/Crystal use their native 251-species pool.
- Removes Gen 3/4 Pokémon, moves, items, abilities, natures, battle-rule code and replacement art/audio from the package.
- Removes cross-generation Pokédex/ruleset selectors and ability/nature options. Rules, move/type availability, sprites, palettes, icons, cries and animations come from the active cartridge.
- Keeps BST matching, logical HM/key-item randomization, CHAOS, safe marts, all 15 Random Start routes, guard removal, local respawn and Untamed compatibility.
- Cleans obsolete settings and prevents saved encounter caches from restoring removed species.

**Old saves:** native-content saves can continue. Saves that own unsupported Pokémon, moves or items remain for use with **1.4.2**; Continue displays a message without loading or rewriting them. Keep the old save slot and use a new slot for a native-only run. This release does not replace or delete your saved Pokémon automatically.

Launcher compatibility remains `>=0.2.18 <1.0.0`; Crystal requires 0.2.24+. Tests cover all six editions under LuaJIT and Lua 5.4, including actual registration/menu paths, native roster/move/type boundaries, visual ownership, protected Continue, progression, Random Start and Untamed integration. No full Android/ROM playthrough was performed.
