# Gen 1 world audit — 1.7.0

## Scope and contract

New functionality is restricted to Red, Blue and Yellow. Gold/Silver/Crystal generation, configuration, run codes and existing runtime behavior are regression-compared with released commit `b768c771851b25f1fd1cd86d2729d97573851880`. Native species, mechanics and art remain in use.

The runtime reference remains Gen1Recomp 0.3.99 (`8b981540e882440f33ab09f1f56030e0ce4a8787`). Public sources are pinned and hash-checked in `tools/gen1_world_references.json`: 36 map object sources each from pret/pokered and pret/pokeyellow, plus the previous randomizer implementation for regression comparison. Tests use the actual extracted warp coordinates; species and item registries are synthetic cartridge-shaped fixtures. Native Lua hook dispatch, battle construction, inventory storage and script implementations come from the pinned host.

SAFE is a structural proof of the authored item/event/region model, not an exhaustive tile/ROM or combat solver. Battles are assumed winnable; money is renewable; the player can teach and retain required HMs and collect the native Flash aide's required species. Optional bonus checks never contain required progression. Unknown quest mods, modified internal puzzles, arbitrary player decisions and unmodeled content are not certified. No complete ROM or Android playthrough was performed. CHAOS is never labeled beatable.

## Checked world

Eight gyms and 15 outside portals across ten dungeon components are modeled: Mt. Moon, Rock Tunnel, Diglett's Cave, Seafoam Islands, Victory Road, Pokemon Tower, Mansion, Power Plant, Silph Co. and Cerulean Cave. Native internal floors and event scripts remain in charge. Forest, Safari, ship, Rocket Hideout, holes, elevators and internal teleport pads remain fixed.

The graph distinguishes Mt. Moon's one-way east ledge, both Rock Tunnel mouths, both Seafoam coasts, both Victory Road exits, the Route 2 east corridor, and the Power Plant's Surf approach. It accounts for Cut/Surf gym approaches, Secret Key, seven-gym Viridian access, Fuji before Silph, Card Key, Tower/Scope, League access and the Champion gate for Cerulean Cave. Seafoam traversal also requires access to its main 1F boulder component; the isolated west exit does not suffice. Victory Road conservatively requires access to the 1F starting switches before cross-dungeon traversal. Dark traversal conservatively requires Flash. Each field capability includes its real badge. Puzzles and battles inside reachable components are assumed completable with those capabilities.

SAFE begins with native progression plus the existing checked start-specific escape placements. Badge and item swaps must pass both the released item model and the expanded entrance model. Entrance swaps retain only layouts with all modeled item sources, all eight gym rewards, every selected portal and the Champion reachable. Rewards are collected after scanning an entire sphere. A separate final replay and a replay withholding each reward reject direct and multi-step self-locks. Mechanically paired warp tiles are checked for bijection and conflicting exits. Immediate paired returns remain available; crossing a multi-exit dungeon requires its traversal capabilities.

This is constructive generation: a complete layout is retained after each accepted change, including on the last allowed candidate. It does not silently switch selected shuffles Off or accept an invalid proof. The staged driver allows at most 50 candidates for Gen 1 and retains the original one-attempt driver for Gen 2. Retryable proof failures derive reproducible candidate seeds. Unsupported data/constraints and runtime faults fail closed. The 50 limit bounds the search; it cannot make unsatisfiable or arbitrary modded input beatable.

## Runtime and persistence

- Battle construction uses the shuffled native roster/name/portrait while retaining the original `oppClass#partyIndex` for native victory flags, rewards and battle-resume ownership. The enemy alone receives the target's native special moves when learnsets are unchanged. Player moves and PP are untouched.
- Gym metadata and NPC appearances are owned changes, restored on leaving a run; Continue refreshes the current gym immediately.
- Safe world shuffles require Shop essentials On, preventing ordinary shop randomization from removing renewable catching/healing supplies.
- Safe shuffled worlds cap encounters/trainers/bosses by actual earned badges, even without Random Start. Percentages are applied after the cap. Native lower levels remain lower.
- Saved worlds include destinations, native portal geometry, leaders, badges and item locations. Continue rejects a mismatched mapping rather than rerolling it. Journal entries are recorded only after the corresponding map entry.
- Every four new rumors includes one joke. Repeated signs do not advance the sequence. Paid hints share the sequence; the tracker uses actual inventory/party/gym flags.
- Bonus rewards are ordinary filler only, claimed once per trainer class/party or caught species. Failed storage cannot produce a capture reward. Full bags route rewards to the PC, and claims/logs survive Continue.

## Validation

The release runs LuaJIT and Lua 5.4 suites against the packaged mod, including the existing full settings/progression, starter/learnset, native-content, encounter and menu regressions. New coverage includes:

- Every enabled/disabled leader/gym/dungeon combination in Safe and Chaos across Red/Blue/Yellow.
- Every supported logical start, both entrance pool modes and both badge/leader policies in all three games.
- Native paired return coordinates, disabled-pool preservation, separate-pool membership and leader/badge permutations.
- Lift Key and Ticket self-locks, an HM/badge dependency cycle, Seafoam without Strength, wrong-side Seafoam/Victory Road boulder access, Mt. Moon ledges, missing native entrances and duplicate destinations.
- Cold Continue equality, actual warp-hook dispatch, journal discovery, hint cadence and repeat stability, bonus duplicates and full-bag fallback.
- Injected failures for the first 49 candidates, a fully checked 50th result, and persistent failure stopping exactly at 50 with no active invalid world.
- Native battle construction, original victory identity, target portrait/name, untouched player moves, and earned-badge level ceilings.
- Controller cycling through all new settings, shared-mode reconciliation, Gen 2 menu isolation, and 24 actual LOVE menu renders with font-bound assertions.

Exact run totals are recorded in the release workflow logs. The existing [1.6.5 audit](AUDIT-1.6.5.md) describes the retained logic and its assumptions. Coverage is extensive but does not enumerate the complete Cartesian product of every existing setting and every seed.
