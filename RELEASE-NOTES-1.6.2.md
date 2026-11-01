# Universal Randomizer 1.6.2 — Reliable Type Bias learnsets

This update includes the damaging-STAB fix and handles native types with only one qualifying attack without freezing their later coverage moves.

- **Learnsets > Type bias** guarantees at least one usable damaging same-type attack in newly generated movesets at every level when the native cartridge has one. The guarantee follows randomized species types and works with both SAFE and CHAOS.
- Ordinary rolls keep their 65% matching-type preference, which can include status moves. A separate guarantee supplies usable STAB. Status, fixed-damage, OHKO/counter, sleep-dependent and self-destructing moves do not satisfy it. Gen 1 Dragon has no qualifying attack because Dragon Rage deals fixed damage.
- If a type has just one qualifying attack, such as Gen 1 Ghost's Lick, later encounters can gain new coverage moves and relearn STAB at the same level. Duplicate and same-level entries follow the native move constructor's rules.
- Automatic starter coverage under **Safety + seed > Progression safety: SAFE** reserves STAB before filling four distinct damaging attacks. There is no separate starter-protection toggle. Type Bias also works in CHAOS.
- The scrolling Learnsets guide explains the odds, guarantee and exceptions. Random and Unchanged retain their previous seeded learnsets and starter coverage.

Update through the launcher, fully restart, then Continue. No new seed is required for an existing Type Bias run. Already caught Pokemon keep their moves, PP and PP Ups; new encounters use the corrected learnsets. Learning and forgetting moves after capture remain player choices.

Tests cover the pinned native move constructors for all six games, original/randomized types, both safety modes, low/high levels, single-attack pools, staged setup and cold Continue. Both LuaJIT and Lua 5.4 run the packaged mod's regression suite, including progression, Random Start, Untamed, native content, wild modes and menu behavior. Ten actual LOVE menu views are rendered, including the Type Bias guide and its scrolling end. No full Android/ROM playthrough was performed.

Pokemon, moves, sprites and battle rules remain native. Engine compatibility remains `>=0.2.18 <1.0.0`; Crystal requires launcher 0.2.24+.
