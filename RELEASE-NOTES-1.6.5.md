# Universal Randomizer 1.6.5 — Settings and progression audit

This release fixes conflicting setup choices and progression gaps, and makes Logic Random Start levels follow earned badges across all maps.

- **Keys + HMs: Off / Safe / Chaos** is directly selectable. Safe and Chaos synchronize Field items and Progression safety. Logic Random Start requires keys/HMs and Safe badges; its guide explains how to unlock the other choices.
- **Random Start levels stay protected on side paths and inside buildings.** At zero badges the ceilings are wild 7, trainer 9 and boss 12, before your percentage modifiers. Earned badges advance them; party level, walking and restarting do not. Lower native levels stay lower. Gen 2 includes Kanto badges, and Untamed refreshes without requiring a map change.
- **New SAFE progression worlds use checked placement plus independent sphere replay and withheld-reward checks.** Fixes include the Cerulean/west-Kanto separation, Fuji/Silph entrance gate, Fuchsia's Surf escape around Snorlax, Route 30's intro barrier, Route 32's badge, Ice Path's Waterfall approach, the Power Plant approach and the sixteen-badge Mt. Silver gate. Morty no longer has a false Rock Smash dependency.
- **Elm can finish the real Mystery Egg handoff after early badges or Togepi progress.** SAFE prioritizes his existing unfinished quest only after visiting Mr. Pokemon and obtaining the actual item. Native item consumption and Route 30 events remain intact.
- **Original and randomized SAFE starters** get four usable attacks and retain HM compatibility through their possible evolutions. Gen 2's native Rock Smash and Headbutt TM moves stay available in SAFE. HMs still need to be obtained, taught and unlocked by their actual badge.
- Native rosters, rules and sprites remain in use. The existing Type Bias STAB guarantee and 65%/35% ordinary selection split remain included.

**Update through the launcher and fully restart. Start a new run for the revised item/badge world proof.** Continue preserves an existing run's item placements and badge rewards; the level-cap fixes apply to existing Logic Random Start runs too. The Elm fix applies to existing SAFE runs. Owned Pokemon, moves and PP are preserved.

The audit exercises all six editions, 5,116 independent setting-value pairs per edition, all 360 core progression-setting combinations per edition, 45 edition/start pairs, 705 withheld rewards and 900 start/badge proofs. It also covers actual runtime hooks, native NPC/script integrations, Untamed, old-save snapshots and nineteen rendered menu views. The complete package is tested under LuaJIT and Lua 5.4. See the [audit report](https://github.com/weskestis/UniversalRandomizer/blob/main/docs/AUDIT-1.6.5.md) for scope and sources. This is an authored logic audit and automated runtime test, not a full Android/ROM playthrough or a guarantee for arbitrary extra quest mods. Chaos intentionally permits locks.

Engine compatibility remains `>=0.2.18 <1.0.0`; Crystal requires launcher 0.2.24+.
