# Settings and progression audit — 1.6.5

## Scope and proof contract

This audit covers Red, Blue, Yellow, Gold, Silver and Crystal using native species, moves, types and sprites. The runtime reference is Gen1Recomp 0.3.99 at `8b981540e882440f33ab09f1f56030e0ce4a8787`; Untamed Tohjo is pinned at `2a55770b4016e1da699b9eae79b5266afa2aa781`.

The Zelda/Archipelago model is an authored, monotone inventory/event graph. Starting with no assumed progression items, a sphere contains checks reachable from the current item, badge and story capabilities. Rewards are collected after scanning the entire sphere. SAFE placement begins with a complete native route, accepts only swaps preserving completion, then replays the final awards without relying on the fill's proposed order. Every reward is independently withheld; its own source must still be reachable. Badge permutations use the same graph and honor the start's escape constraints.

Completion means access to the modeled Champion route in Gen 1 or the sixteen-badge/Oak/Mt. Silver/Red route in Gen 2. Gym and story encounters in reachable regions are assumed beatable; combat outcomes, money management and the player's choice to teach/retain an HM move are not solved. Flash is conservatively required for dark-route progression. The model does not assume a dark-room navigation exploit, Poke Doll skip, Bicycle-gate skip, injected story flags, emergency teleport or Archipelago network connection.

This is not an exhaustive tile-level ROM verifier. Most test map/species records are synthetic and cartridge-shaped; native hook dispatch, NPC callbacks, script VMs and move constructors come from the pinned host. Reviewed native source gates supply independent negative controls. Custom quest mods and unmodeled event sources are outside the SAFE proof. No full Android/ROM playthrough was performed.

## Findings and corrections

| Area | Previous gap | Correction |
| --- | --- | --- |
| Keys + HMs | Boolean On could be locked while its description discussed Safe/Chaos. | Direct Off/Safe/Chaos choices, synchronized with the shared item/safety mode. Logic Start omits Off and explains why. |
| Incompatible modes | SAFE could coexist with unchecked badge rewards in some inputs. | The menu reconciles choices; new-run preflight rejects remaining contradictory raw inputs before seed generation. |
| Saved preferences | Old preferences could reactivate retired route options or planners in a new game. | Fresh setup selects the audited world and current start/badge policies; Continue retains its own saved policy. |
| Cerulean | Mt. Moon's one-way ledges were collapsed into west Kanto. | Separate regions; Cut/Diglett's Cave or the later native return route must actually reconnect them. |
| Silph Co. | Card Key could be treated as reachable before the entrance Rocket leaves. | Fuji rescue is required, with the Silph Scope/Tower dependency included. |
| Fuchsia | Route 12/11 was incorrectly treated as a free walking escape past Snorlax. | New Fuchsia starts retain native Safari Surf and Koga's Soul Badge; Surf bypasses Snorlax north toward Lavender. |
| Johto Route 30 | The intro battle barrier was omitted from the early-town connection. | Require the Mystery Egg handoff capability before the corridor opens. |
| Elm | Early badges or Togepi could permanently select later dialogue before the unfinished intro quest. | Resolve the native handoff from imported scripts and prioritize it only after the real Mr. Pokemon visit and with the real item. Original consumption and story-event commands complete the quest. |
| Ice Path | Blackthorn could be treated as access to Waterfall on the opposite side of the map. | Require the Radio Tower clearance and Strength approach from the west. |
| Johto Route 32 | Mystery Egg alone could make the south route reachable. | The actual Zephyr Badge is required too. |
| Morty | Rock Smash was incorrectly required for Burned Tower progression. | Remove the false gate; preserve Rock Smash as useful optional field access. |
| Power Plant | Being in east Kanto was treated as sufficient to start the Machine Part quest. | Require the Cut/Surf approach before its Cerulean reward is reachable. |
| Endgame | A coarse west-Kanto node stood in for Mt. Silver access. | Model Kanto leaders, Misty's quest, Blue's Cinnabar meeting, all sixteen badges and Oak's permission. |
| HM carriers | Original starters or keys-off settings could lose the protected carrier path. | SAFE starter families retain native HM compatibility through their evolution targets; actual items, badges and teaching remain necessary. |
| Starting levels | Protection depended on one suggested map; map visits could advance it. | Every map uses earned-badge ceilings after the portal. Side trips, interiors, re-entry and party levels do not advance them. |
| Gen 2 levels | Kanto badges use a separate save field. | Count both stores without double-counting name/index aliases. |
| Untamed | Projected tables could remain cached after a badge reward. | Cache identity includes earned badges and portal status, not party level. |

## Authored starts

Each Gen 1 row is exercised in Red, Blue and Yellow; each Gen 2 row in Gold, Silver and Crystal: 15 starts, 45 edition/start pairs. All use the same zero-badge ceilings: wild 7, trainer 9, boss 12 before modifiers. Native lower levels remain lower. The local objectives below establish access, not a guarantee that every adjacent grass patch can be reached without another field move.

| Start | Local objective and checked escape |
| --- | --- |
| Cerulean | Bill's reward chain, Misty/Cascade and native S.S. Anne Cut; return through Diglett's Cave and the Route 2 tree. |
| Vermilion | Reach Cerulean/Bill through the Underground Path; obtain Cascade/Cut and return to west Kanto. |
| Lavender | Walk Route 8/Underground Path to Celadon, buy a native guard drink and open Saffron's exits. |
| Celadon | Buy a guard drink in the Department Store and use Saffron's native gates. |
| Saffron | Guaranteed purchasable Fresh Water in the local Mart; activate the native guard event. |
| Fuchsia | Native Safari Surf plus Koga's Soul Badge and a compatible starter; Routes 15/14/13 then Surf north around Route 12 Snorlax. Walking into Route 11 still needs the Flute. |
| Cinnabar | The audited Mansion 1F Carbos check carries Surf; obtain the shuffled Secret Key locally, beat Blaine for Soul and Surf to Pallet. No Seafoam shortcut without its own gates is assumed. |
| Cherrygrove | Mr. Pokemon/Mystery Egg progression, then return to Elm and follow the native story. |
| Azalea | Kurt/Well, Bugsy/Hive and native Ilex Cut; reach Goldenrod. |
| Goldenrod | Whitney/Plain, the fixed Squirtbottle and Sudowoodo; continue toward Ecruteak. |
| Ecruteak | Native Morty story/Fog and Dance Theater Surf; reach Cianwood, Chuck/Storm and Fly back to a visited early Johto town. |
| Olivine | Walk to Ecruteak, then the Surf/Chuck/Fly return chain. |
| Cianwood | The existing start-only solved boulder lane permits Chuck without a Strength lock; earn Storm and native Fly. The starter family and Mania gift provide compatible choices. Fly is never pre-taught or granted at the portal. |
| Mahogany | Walk through Route 42/Mount Mortar to Ecruteak, then the Surf/Chuck/Fly chain. |
| Blackthorn | Walk south down Route 45/46 ledges to Route 29/New Bark. Waterfall is not assumed obtainable from the wrong side of Ice Path; later progression must return through the normal west entrance. |

For the first eight badges, the wild ceiling is `7 + 4 * badges`; trainer and boss ceilings add 2 and 5. Gen 2 badges 9–16 add 5 each. Apply the selected percentage afterward and clamp to legal levels. At zero badges, capped wild encounters vary deterministically around 5–7. Existing lower encounters stay lower. This is a progression ceiling, not party scaling or a promise about species strength. Normal/Chaos starts retain native percentage scaling.

## Automated coverage

| Test area | Coverage |
| --- | --- |
| Independent settings | A verified 148-row covering array contains all 5,116 value pairs across 29 Pokemon, battle, wild, shop, trade and seed controls. Run in all six editions. Every offered level-percentage step is included. |
| Progression combinations | All 360 combinations of start, safety, badges, field items, NPC gifts and key/HM inclusion per edition. Identical normalized states are generated once. Across six editions, 720 contradictory inputs are rejected with explanations. |
| Generated configurations | 1,797 complete staged generations: 888 covering-array cases, 864 distinct world configurations and 45 edition/start runs. |
| Escape and badge proof | All 45 edition/start pairs; 20 additional checked badge permutations each (900 proofs); every resulting authored item location withheld once (705 checks). |
| Negative controls | Ticket behind S.S. Anne, multi-item cycles, Cut behind the Power Plant, false west-Kanto access, Snorlax walking escape, missing Silph/Fuji gate, Route 30 intro barrier, wrong Route 32 badge, wrong-side Ice Path access and false Morty/Rock Smash dependency. |
| Intro quest | Imported script-graph resolution and hook scope across Gold/Silver/Crystal, plus actual LuaJIT host VM execution. Early badge/Togepi positives; no item, no Mr. Pokemon visit, completed quest, another NPC/map and Chaos negatives. Native item consumption and Route 30 events are checked. |
| Runtime levels | Actual grass/fishing/static/trainer hooks on each start's suggested maps plus interiors and unlisted side paths. Exercise -50/0/+50%, early/late badges, party levels 5/80, extreme map-visit counts, low native teams and cold Continue. Both Gen 2 badge stores are tested at every count. |
| Untamed | Native callback ownership, actual spawn/battle queues in the existing feature suite, plus cache refresh at a badge reward and independence from party levels. |
| Menu | 21,970 controller/help checks: multiple forward/back/A laps, every visible row, dependency synchronization, Keys + HMs, validation errors and scrolling. Nineteen actual LOVE-rendered views with font-bound assertions. |
| Existing coverage | Native content/visual ownership, old item/badge snapshots, portals/respawn, ordinary item placement and full bags, 1,920 wild-mode seeds, and 4,304,161 Type Bias checks using native move constructors. |

Both LuaJIT and Lua 5.4 run the packaged-mod suites in the release workflow. Pairwise coverage does not enumerate the entire Cartesian product of all controls. The progression switches are exhaustively combined; the remaining controls use pairwise generation plus targeted cross-feature/runtime cases.

## Save compatibility

New runs store `world_logic = AUDITED`. Saves without that field use the original planner, preserving their item and badge world. Legacy snapshot tests verify this boundary; Continue does not reroll an ongoing seed. Old configurations cannot silently enable the retired guards or party-relative level policies. Level protection applies to all active Logic starts after the portal, including legacy worlds. The Elm handoff correction also applies to existing SAFE worlds without changing their item placements. The diagnostic identifies legacy worlds rather than claiming that the new proof has been applied to them.

New worlds use the `UR165` run-code namespace; older worlds retain `UR14`. Owned party, boxed and daycare Pokemon keep their chosen moves/PP. New SAFE original starters receive the same four-attack protection already used for randomized starters; new SAFE starter evolution paths retain HM carriers. Chaos is explicitly unchecked and may be impossible.

## Primary references

The reviewed file URLs, immutable revisions and SHA-256 hashes are recorded in [audit_references.json](../tools/audit_references.json). The native sources are authoritative for cartridge gates; Archipelago supplies a comparison model, not replacement game data. AP-only options such as extra keys, skips and added boulders are not imported.

- [Archipelago 0.6.7 Pokemon RB region rules](https://github.com/ArchipelagoMW/Archipelago/blob/0.6.7/worlds/pokemon_rb/regions.py): Snorlax junctions, field-move access and one-way connections.
- [Archipelago 0.6.7 level scaling](https://github.com/ArchipelagoMW/Archipelago/blob/0.6.7/worlds/pokemon_rb/level_scaling.py): reachable-sphere progression as distinct from counting map visits. This mod uses its own earned-badge ceiling, not AP's ROM level scaler.
- [pret/pokered Route 12](https://github.com/pret/pokered/blob/0dbf95cd12f5b1511c62ce69efe283000f780a8f/data/maps/objects/Route12.asm): native Snorlax location; checked alongside the pinned host's story and object callbacks.
- [pret/pokegold Burned Tower](https://github.com/pret/pokegold/blob/f2cde36f49b994c143bfd18582182302fdc76492/maps/BurnedTower1F.asm) and [pret/pokecrystal Burned Tower](https://github.com/pret/pokecrystal/blob/3c813b0b4d82b39bf62185aceffb76fd6026c70b/maps/BurnedTower1F.asm): native story sequence, without a mandatory Rock Smash item gate.
- [Crystal Elm's Lab](https://github.com/pret/pokecrystal/blob/3c813b0b4d82b39bf62185aceffb76fd6026c70b/maps/ElmsLab.asm), [Mr. Pokemon's House](https://github.com/pret/pokecrystal/blob/3c813b0b4d82b39bf62185aceffb76fd6026c70b/maps/MrPokemonsHouse.asm), and [Route 30](https://github.com/pret/pokecrystal/blob/3c813b0b4d82b39bf62185aceffb76fd6026c70b/maps/Route30.asm): native intro event order and the battle barrier.
- [Crystal Ice Path 1F](https://github.com/pret/pokecrystal/blob/3c813b0b4d82b39bf62185aceffb76fd6026c70b/maps/IcePath1F.asm) and [Mahogany](https://github.com/pret/pokecrystal/blob/3c813b0b4d82b39bf62185aceffb76fd6026c70b/maps/MahoganyTown.asm): separate Ice Path approaches and Radio Tower clearance.
- [Crystal Power Plant](https://github.com/pret/pokecrystal/blob/3c813b0b4d82b39bf62185aceffb76fd6026c70b/maps/PowerPlant.asm), [Cerulean Gym](https://github.com/pret/pokecrystal/blob/3c813b0b4d82b39bf62185aceffb76fd6026c70b/maps/CeruleanGym.asm), and [Route 25](https://github.com/pret/pokecrystal/blob/3c813b0b4d82b39bf62185aceffb76fd6026c70b/maps/Route25.asm): Machine Part and Misty story gates.
- [Crystal Cinnabar](https://github.com/pret/pokecrystal/blob/3c813b0b4d82b39bf62185aceffb76fd6026c70b/maps/CinnabarIsland.asm), [Viridian Gym](https://github.com/pret/pokecrystal/blob/3c813b0b4d82b39bf62185aceffb76fd6026c70b/maps/ViridianGym.asm), and [Oak's Lab](https://github.com/pret/pokecrystal/blob/3c813b0b4d82b39bf62185aceffb76fd6026c70b/maps/OaksLab.asm): Blue's meeting, Earth Badge and sixteen-badge Mt. Silver permission.
- [Gold Dragon's Den](https://github.com/pret/pokegold/blob/f2cde36f49b994c143bfd18582182302fdc76492/maps/DragonsDenB1F.asm) and [Crystal Dragon's Den](https://github.com/pret/pokecrystal/blob/3c813b0b4d82b39bf62185aceffb76fd6026c70b/maps/DragonsDenB1F.asm): native Rising Badge scripts and variant behavior.

Native maps, game art and reference ROMs are not bundled with the release. Only the mod's code and documentation are packaged.
