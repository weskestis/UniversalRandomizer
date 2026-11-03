# 1.11.0 item reward audit

## Scope and references

Red, Blue, Yellow, Gold, Silver and Crystal. The host remains pinned to Gen1Recomp v0.3.99, commit `8b981540e882440f33ab09f1f56030e0ce4a8787`; the Untamed reference remains `2a55770b4016e1da699b9eae79b5266afa2aa781`. Native trainer identities use the existing hash-verified pret corpus and generated native fixture. No new content, sprites or cross-generation rules are introduced.

## Trainer rewards

`trainer_checks` exposes only Off, Safe and Chaos. Old Some/All values remain readable solely to preserve saved runs. The hidden `dex_checks` compatibility value retains old fingerprints, but no menu or capture-award handler remains. Catch statistics are independent.

A seed selects about 25% of native class/member identities as reward sources. Selected audited sources join the existing finite item placement pool. Their initial filler is excluded from the unique progression-item list; the resulting item multiset is conserved. Safe placement accepts swaps only when the native item graph and expanded entrance graph still solve. Every reward is withheld independently to test source access. Delivery consults the assigned item before considering the ordinary chance path, ensuring a required reward cannot miss a second roll.

Authored Gen 1 sources cover the native gyms, persistent trainers in Viridian Forest and Routes 3/24/25, and Giovanni's Hideout/Silph battles. Route 3 needs Brock; the Hideout boss needs the Lift Key; Silph needs the Card Key and Fuji story; gyms retain their internal and story prerequisites. Gen 2 sources cover the 16 gyms, early Route 30 trainers after Egg delivery, Elder Li, and the two mandatory Radio Tower executive battles. Optional disappearing Rockets are not key locations. Clair's battle requires Strength; her later badge quest separately requires Surf/Whirlpool. Unknown trainer sources can roll ordinary Safe items but cannot receive required progression.

Native numeric/symbolic class and member identifiers resolve to one canonical identity. Shuffled leader presentation retains the original battle source. Losses, skipped battles, link battles and Gen 2 Battle Tower fights do not award items. Claims and reward history live in the save's mod state. Full bags use the existing PC fallback. Safe and Chaos both reject missing, duplicated or altered trainer bindings; Chaos does not claim an access proof.

## Hidden pickups

New runs separate hidden pickups from visible field-item randomization. Off preserves original item payloads; the conditional Gen 2 Machine Part is also pinned in the progression plan. Safe draws from the native ordinary item/TM pool, retains required hidden TMs, and leaves non-authored key sources fixed. Authored quest pickups remain under their existing exact access rules. Chaos permits native keys/HMs in ordinary hidden rewards. Coordinates, native collected flags, hidden coins and Itemfinder behavior are unchanged. Repeated Gen 2 hidden-event references share one reward.

The independent hidden-item validator checks mode, native payloads, Off preservation, Safe eligibility and every linked native reference. Old saves without the new setting retain the previous field-item RNG path and fingerprints. Seeded selections are stable across cold Continue. Share import permits the absent field in old 1.10.0 codes without silently changing it to the new Off policy.

## Validation and limitations

The 16 release suites run under LuaJIT and Lua 5.4. New trainer tests exercise all six editions, 138 selected trainer locations, real native victory-event dispatch, numeric/symbolic identities, seeded odds, guaranteed assigned delivery, full bags/PC, capture removal, duplicate claims, cold Continue, missing rewards and altered rules. Explicit negative cases cover Secret Key on Blaine, Lift Key on Giovanni, SecretPotion on Jasmine, Mystery Egg on Route 30 and Card Key on the final executive. Both independent graphs reject these locks; both accept Whirlpool on Clair's fight.

Hidden-item tests cross all six games, three hidden modes and three visible-field modes, including shared events, Machine Part preservation, invalid payloads, independent randomization and old/new save restoration. The controller-menu tests repeatedly cycle settings in both directions and through A selection. Real LOVE rendering checks 50 menu views plus 14 overlay views, including all new modes and scrolled guide endings. Prior release, adaptive team, native content, random start, Type Bias and Untamed compatibility suites remain gates.

Generation still stops within 50 candidates and never substitutes an unchecked world for a failed Safe proof. This is structural access certification for authored native content, assuming manageable combat/resources and normal HM use. Arbitrary external quest changes, player mistakes and Chaos are not an unconditional beatability guarantee. No physical Android playthrough is claimed.
