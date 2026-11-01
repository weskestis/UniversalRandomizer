# Universal Randomizer 1.6.1 — Reliable Type Bias learnsets

Type Bias could give a Pokemon no damaging same-type attack: matching status moves counted toward its 65% preference, and SAFE starter coverage could replace every matching attack. This release fixes both paths.

- Type Bias guarantees at least one usable damaging STAB attack in newly generated movesets at every level when the active cartridge has a suitable move. It follows randomized species types and works with SAFE or CHAOS.
- SAFE starter protection reserves that STAB attack before filling four distinct damaging moves with type diversity. Later learnset entries cannot evict the sole usable STAB attack from a generated moveset.
- Ordinary random rolls retain their 65% matching-type preference. The guarantee is separate; status, fixed-damage, OHKO/counter, sleep-dependent and self-destructing attacks do not satisfy it. Gen 1 Dragon has no qualifying native attack because Dragon Rage deals fixed damage. Native-only move limits remain in place.
- The scrolling Learnsets guide explains the chance, guarantee, exceptions and save behavior. Random and Unchanged retain their previous seeded learnsets and starter coverage.

Update through the launcher, fully restart, then Continue. Existing Type Bias runs use the corrected learnsets without a new seed. Already caught Pokemon keep their current moves, PP and PP Ups; the fix applies to new encounters and the species' future learnset. Players still choose which moves to learn or forget after capture.

Regression coverage uses the pinned Gen 1 and Gen 2 move constructors for all six editions, SAFE/CHAOS, original/randomized types, low/high encounter levels, duplicate learnset rows, sparse pools, staged setup and Continue. The packaged mod is tested under LuaJIT and Lua 5.4 alongside progression, Random Start, native content, Untamed, wild modes and menu tests. Actual LOVE menu rendering checks include the updated scrolling guide. No full Android/ROM playthrough was performed.

Game content, sprites and battle rules remain native. Engine compatibility remains `>=0.2.18 <1.0.0`; Crystal requires launcher 0.2.24+.
