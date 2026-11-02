# Universal Randomizer 1.10.0 — Run tools and adjustable overlays

[Download the latest release](https://github.com/weskestis/UniversalRandomizer/releases/latest), or update through the launcher mod manager and fully restart the game. **Launcher 0.3.99 or newer is required** for its source-safe touch/mouse pointer API. Red, Blue, Yellow, Gold, Silver and Crystal retain their own native Pokemon, rules and sprites.

## New controls

- **New run setup → Battles → Adaptive story bosses:** Off / Safe / Chaos for rivals, Giovanni, Yellow's Jessie & James, Rocket executives, the Elite Four, Champions and Gen 2 Red. Gym teams have their own setting under Gyms + entrances.
- **New run setup → Run tools:** presets with a complete change preview, victory goal, race mode, clipboard run-code import and overlay layout.
- **Rando Info → Run tools:** victory progress, share code, recorded recap, diagnostics and live overlay layout.

New gameplay controls default Off / Native ending on existing configurations. Old seeds, native content and existing adaptive gym plans retain their prior behavior. New gameplay choices require a new run; overlay layouts can be edited during play. The new recorder starts when an older save is first opened and cannot reconstruct earlier events.

## Phone and PC overlays

Open **Run tools → Overlay layout**, select a panel and switch it On. Panels start Off to avoid covering an existing HUD. Five panels are available: Run + splits, Party + EXP, Caught + shiny, Move details, and Learn comparison.

Drag a panel with a finger or mouse. Drag its lower-right corner to resize it, or use Smaller / Larger. Portrait and landscape layouts are saved separately with the save; positions are clamped to the current screen. Unedited defaults reflow when the window changes size. Reset resets this orientation. Move and Learn panels share default space because their native screens are mutually exclusive.

Controller/virtual-pad controls: SELECT changes the panel, A toggles it, the D-pad moves it, START switches the D-pad between movement and resizing, and B saves/exits. The native virtual pad keeps ownership of touches that start on its buttons. Dragging is available only inside the explicit editor. Touch/click menu rows select them; swiping scrolls without activating a row. Footer buttons support navigation and setting changes.

Move details follow the highlighted battle move: native type, power, accuracy, PP, STAB and effect text. Tap the Move or Learn panel to open the full scrolling guide. Learn comparison reads the game's existing choice; native HM deletion checks and callbacks remain in charge. The EXP panel reads actual experience and growth curves. The caught marker is for wild encounters. Shiny indication uses native Gen 2 state; this release does not introduce Gen 1 shiny odds or replacement sprites.

The uploaded reference mods inspired these independently implemented features. See [reference credits](mod/REFERENCE-MODS.md). Duplicate external HUDs can be left installed with our corresponding panel Off. Voxel-only layouts, external badge-stat assumptions and global battle-transition overrides are not bundled.

## Story bosses

Safe uses earned badges and the native encounter phase to choose team size, native evolution forms, strength limits and usable moves. Opening rivals remain single-Pokemon, low-level encounters. Later story fights cannot gain early-game strength just because they are geographically late. Rival starter continuity, the legendary toggle and Boss level % remain effective. Chaos allows 1–6 Pokemon and removes the early form/strength limits; it still uses the game's native content. Neither mode changes story scripts, rewards or the player's Pokemon.

This setting takes authority over ordinary Trainers and Learnsets choices for the supported story encounters. High Boss level percentages and Chaos can make fights difficult. The progression proof establishes access, not guaranteed combat wins.

## Goals, sharing and records

Victory choices are Native ending / Champion / All badges / Random checklist, plus Defeat Red in Gen 2. Native ending records Champion completion without changing world settings. A checklist chooses five deterministic native gym/final-boss objectives. All badges requires eight actual badges in Gen 1 or sixteen in Gen 2. A shuffled gym credits the original location, not its presented leader. Completing the goal records the finish without stopping play.

Custom goals enable the full authored world proof and logical key/HM plan, even with unshuffled entrances. The change preview shows those dependent settings. Safe requires a complete proof; Chaos permits locks. Generation retains the existing 50-candidate bound and never accepts a failed Safe proof.

Presets are Balanced adventure, Everything shuffled safely, and Absolute bullshit. Each starts from the native defaults, previews every changed setting, and remains editable afterwards.

**Share run code** copies a checksummed `UR110` code containing the actual accepted seed and every setting. On the same cartridge, copy it to the clipboard, choose Import run code during setup, review, and apply. The imported seed is validated exactly; it is not silently rerolled. Opening the seed controls or applying a preset clears the imported-seed override. Codes require this format/version and matching game data/mod configuration. The old compact display codes cannot be imported.

Race mode hides randomizer location rumors, future gym details and spoiler exports until goal completion. Known entrance discoveries stay visible. This is spoiler prevention, not anti-cheat: share codes contain the seed.

The recorder tracks foreground session time (including menus), gym and story-boss splits, visited areas, observed key/HM acquisitions, catches and blackouts. Fast-forward does not accelerate the timer and background time is excluded. After completion, the recap freezes the finish team and reveals which recorded rumors were bogus. Events before installing this recorder are unavailable. Diagnostic reports copy locally and include version, seed/configuration, validation attempts and recent maps; nothing is sent automatically.

## Adaptive gym teams

Available in Red, Blue, Yellow, Gold, Silver and Crystal. This controls the active leader's team, including a shuffled leader. Native portraits, sprites, badge rewards and gym completion events retain their existing ownership.

| Mode | Team behavior |
| --- | --- |
| Off | Retains the existing trainer and shuffled-leader behavior. |
| Safe | Two Pokemon at 0–1 badges, three at 2, four at 3, five at 4, six at 5+. Early basic forms, bounded strength and simple moves; stronger native evolutions and coverage become eligible later. |
| Chaos | A seeded team of 2–6 Pokemon without early evolution, strength or move-power restrictions. Impossible fights are possible. |

Both modes keep the leader's type theme using the species' current types; Blue uses mixed types. Eligible members of the native leader's evolution families are preferred. Pools stay within the active game's native species and legal native moves. The legendary toggle still applies. Gen 2 adds held Berries from four badges and Leftovers from six; Gen 1 has no held items.

The highest team level is **12 + 4 per badge through eight**, then **+5 per badge** in Gen 2; other members are up to two levels lower. **Boss level %** applies once afterward, bounded to levels 1–100. All 16 Gen 2 badges count. Party level, map visits and reloading never raise the difficulty. The same seed, leader and badge count produce the same team.

Adaptive teams takes precedence over Trainer Pokemon, BST limits, randomized learnsets and TM compatibility **for gym opponents only**. It uses original native evolution families and legal level-up/TM move pools even when those player-facing systems are randomized. Current species stats/types still apply. Safe ensures a usable damaging move and prefers usable STAB when the native legal pool and tier allow it; it does not import moves to fill a missing type. Other trainers and owned Pokemon retain their settings, moves and PP.

Combat safety is independent of world progression safety: Safe teams can be used with a Chaos world, and Chaos teams with a checked world. Safe means bounded team construction, not guaranteed victory. High Boss percentages can still make an opening fight difficult. Every native leader and badge tier is checked before accepting an adaptive seed; unsupported rosters or empty eligible pools fail validation. Adaptive seeds get a versioned run code. Off preserves released 1.8.0 fingerprints, run codes and worlds. See the [adaptive-team audit](docs/AUDIT-1.9.0.md).

## Gyms, dungeons and progression

Open **Gyms + entrances** in New run setup:

| Setting | Choices and behavior |
| --- | --- |
| Gym leaders | Off / Safe / Chaos. Shuffle the eight Gen 1 or sixteen Gen 2 native identities, rosters and sprites; Trainer Pokemon settings apply unless Adaptive teams is enabled. |
| Badge pairing | Independent uses the badge setting separately. With leader pairs each leader with their native badge. Gen 2 badges stay within their Johto/Kanto sets. |
| Gym entrances | Off / Safe / Chaos. Shuffle paired gym doors. |
| Dungeon entrances | Off / Safe / Chaos. Gen 1: 15 entrances across 10 components. Gen 2: 18 across 12. |
| Entrance pools | Separate gym/dungeon pools, or mix the enabled categories. Gen 2 Safe keeps the two regions apart; Chaos can cross regions. |
| Hint detail | Area or Exact. Every four new rumors include one bogus roast. |
| Trainer / capture rewards | Off / Some / All. Optional one-time ordinary items; full bags use the PC. |

Enabled shuffles share one Safe/Chaos policy and select the matching logical keys/HMs plan. Safe also keeps Shop essentials On, ensuring Poke Balls and Potions remain available. Safe constructs a complete route, accepts only changes preserving that route, and independently replays the resulting item, badge, story and entrance dependencies. Every reward is withheld to check for locks at its own source. Validation is spread across frames and stops after at most **50 candidates**; it never accepts an unproven Safe candidate. A valid native starting layout is retained throughout constructive generation, so success does not depend on blind rerolls.

The beatability contract covers the **authored native progression model**, assuming winnable battles, renewable money and sensible use of obtained HMs. It is not an unconditional guarantee for arbitrary quest mods, missing game data or every player decision. Chaos explicitly allows impossible worlds. See the [Gen 2 audit](docs/AUDIT-1.8.0.md) and [Gen 1 audit](docs/AUDIT-1.7.0.md).

Gen 1 dungeon entrances: Mt. Moon, Rock Tunnel, Diglett's Cave, Seafoam Islands, Victory Road, Pokemon Tower, Pokemon Mansion, Power Plant, Silph Co. and Cerulean Cave. Their internal layouts stay native. Forest, Safari Zone, S.S. Anne, Rocket Hideout, holes and internal teleport pads stay fixed. Both halves of a double door stay together and exits return to their paired source.

Gen 2 dungeon entrances: Sprout Tower, Union Cave, Slowpoke Well, Burned Tower, Olivine Lighthouse, Ice Path, Dragon's Den, Tohjo Falls, Rock Tunnel, Diglett's Cave, Mt. Moon and Mt. Silver. Internal floors and special/scripted transitions remain native. Safe keeps Johto and Kanto entrances separate because an early Kanto badge can skip Johto's exact-count Radio Tower event. The combined proof reaches all 16 badges and access to Red.

Safe shuffled worlds cap wild/trainer/boss levels by earned badges on every map, including a normal starting town: zero-badge ceilings are 7 / 9 / 12, increasing by four per badge through eight, then five per Kanto-era badge, before your percentage modifiers. Lower native levels stay lower. Gym locations retain their story flags and TM rewards; moving a leader cannot award another location's completion.

Open **Rando Info → Entrance journal / Progression tracker** for discovered doors, actual gym completion, HM readiness and bonus reward history. The tracker never invents requirements. Signs and paid hints share a saved rumor sequence; rereading a sign repeats its answer. The deliberately useless hints are rude jokes, not progression instructions.

World mappings, item locations, physical portal identities, discoveries and reward claims are saved. Continue checks them against the certified layout instead of silently rerolling. Existing Gen 1 worlds retain their selected item/badge settings; new shuffles default Off. New Gen 2 controls default Off on existing saves; start a new run to select shuffles. Crystal badge awards use its native engine flag numbers. All games retain their native Pokemon and sprites.

## Retained 1.6.5 behavior

The settings, starter protection, Type Bias fix, item logic and Random Start controls below remain available. Owned Pokemon keep their moves and PP.

## Keys + HMs and dependent settings

**Keys + HMs now offers Off, Safe and Chaos directly**, instead of a locked On toggle. With Logic Random Start, it offers Safe and Chaos; turn Random Start off to choose Off.

| Choice | Effect |
| --- | --- |
| Safe | Selects Logical random field items and SAFE progression safety; keys, HMs and badges share a checked world plan. |
| Chaos | Selects Chaos field items and CHAOS progression safety; locks are allowed. |
| Off | Excludes keys/HMs and switches graph field modes to ordinary Random. Requires Random Start off or Chaos. |

Field items still cycles through all five choices on every lap. Logic Random Start restricts that row to the two supported graph modes and keeps badges on Safe. Choosing Chaos badges selects CHAOS safety; choosing SAFE safety replaces Chaos badges with Safe. The guide explains these dependencies and scrolls through the entire description. Ordinary NPC gifts can remain unchanged while the graph controls its supported key/HM gift checks.

## Logic Random Start levels

After the native intro portal, earned badges set a ceiling on **every map**, including side paths, interiors, fishing, fixed battles and Untamed encounters. Map visits, reloading and party levels do not advance the ceiling. Native encounters below it stay lower; trainer teams retain their relative level order. Your Wild, Trainer and Boss percentage modifiers apply afterward.

| Earned badges | Wild ceiling | Trainer ceiling | Boss ceiling |
| --- | ---: | ---: | ---: |
| 0 | 7 | 9 | 12 |
| 1 | 11 | 13 | 16 |
| 4 | 23 | 25 | 28 |
| 8 | 39 | 41 | 44 |
| 16, Gen 2 only | 79 | 81 | 84 |

These are ceilings before the selected percentage, not fixed levels for every encounter. Fresh-start wilds commonly range from 5–7. Gen 2 counts both the Johto and Kanto badge stores. Untamed refreshes its projected encounter tables when a badge is earned, even without a map change. Safe world shuffles also apply these ceilings with Random Start Off. Other normal and Chaos starts retain native percentage scaling.

## Revised progression proof

New SAFE worlds use Zelda/Archipelago-style reachable spheres, checked item swaps, and a separate replay of the final placement. Each reward is also withheld in turn to check that its own source does not depend on it. This is local logic; no Archipelago server or ROM patch is required.

The corrected model separates Cerulean from west Kanto, checks Fuji's rescue before Silph Co., requires Surf around Snorlax for a Fuchsia escape, and respects Johto's Route 30 intro barrier and Route 32 badge gate. It removes the false Rock Smash requirement for Morty, checks the Power Plant approach, and includes Kanto badges and Oak's Mt. Silver permission. Escape-critical rewards remain pinned where necessary; other supported keys/HMs still shuffle.

In SAFE Gen 2 runs, holding the real Mystery Egg after visiting Mr. Pokemon lets Elm finish the native handoff even if an early badge or Togepi would otherwise select later dialogue. His original item removal and story events still run; the mod does not synthesize quest completion. Blackthorn starts must approach Waterfall through Ice Path's correct entrance after the Radio Tower story.

SAFE now protects original starters as well as randomized starters. Their possible evolution paths retain HM compatibility even when key randomization is off. Field HMs still require the real item, badge and a taught move. New SAFE Gen 2 runs also preserve the native Rock Smash and Headbutt TM moves.

See the [audit report](docs/AUDIT-1.6.5.md) for the per-start routes, setting matrix, sources and limits.

## Type Bias learnset fix

**Type Bias now guarantees at least one usable damaging STAB attack in a newly generated Pokemon's moveset at every level, whenever its native move pool has one.** This applies in SAFE and CHAOS, follows randomized species types, and survives SAFE starter coverage. SAFE starters still receive four distinct damaging attacks with type diversity where possible. This starter coverage is automatic under **Safety + seed > Progression safety: SAFE**; it is not a separate toggle. Type Bias itself works under both SAFE and CHAOS.

The ordinary random rolls still have a **65% chance per slot** to draw from matching types; those rolls can include status moves, and the unrestricted 35% can also select matching moves. The separate STAB guarantee repairs a moveset when needed, so 65% is not the final percentage of damaging STAB moves. Later unique moves cannot push out the only usable STAB attack from a freshly generated moveset. When a type has only one suitable attack, it can be relearned at the same level as a new coverage move so later encounters still gain new moves. Normal move-learning choices after capture remain yours.

Status moves, fixed-damage attacks, OHKO/counter moves, attacks requiring sleep, self-destructing attacks, and moves whose type or damage cannot promise STAB do not satisfy that guarantee. Gen 1 has no STAB-capable Dragon attack: Dragon Rage deals fixed damage. Those cases continue using only native moves rather than importing an attack or failing validation. The guarantee is availability of an attack, not a promise that every use hits or damages every opponent.

No new seed is required for the fix on an existing Type Bias run. Restart and Continue to rebuild its learnsets. Existing party, boxed and daycare Pokemon retain their chosen moves, PP and PP Ups; encounters created afterward use the corrected learnsets. Random and Unchanged learnset modes retain their seeded results apart from the explicit new SAFE coverage for original starters. The in-game Learnsets guide now explains these odds, guarantees and exceptions and supports scrolling.

## Setup controls and explanations

The setup uses a modern 640x360 layout in both engines. Settings and their values occupy the left panel; a separate guide explains the highlighted setting, its current choice and interactions. Long descriptions and validation errors wrap without dropping text and scroll automatically. **SELECT** focuses the guide; **Up/Down** scrolls a line, **Left/Right** jumps to the beginning/end, and **B** returns to the settings.

**Up/Down** selects a setting; **Left/Right** changes its value in either direction; **A** chooses or opens an editor. Navigation repeat follows elapsed real time, so game-speed multipliers do not make a held direction race through the menu. Leaving setup with B opens a vanilla confirmation. Validation cannot be dismissed or restarted by a held button.

Open **Wild encounters > Wild Pokemon**:

- **Balanced** favors species with similar native base-stat totals. Early routes often have weaker or unevolved species; there is no first-stage-only rule.
- **Truly random** permits every allowed native evolution stage at low levels. It ignores the BST limit for wild Pokemon and never automatically evolves a selected species because of level. Starters/trainers/gifts/trades still honor their own settings and the BST limit. The legendary toggle still applies.

**Progression safety** is separate: SAFE can be combined with Truly random Pokemon. SAFE still retains a few essential Gen 2 HM-learner slots; CHAOS removes those protections. Encounter layout determines the saved area pool or slot mapping, so a randomized route does not contain the entire Pokedex. **Extra species: 0** keeps the base slot mapping; new runs keep species as rolled unless Balanced's **Wild evolution: Match level** is explicitly selected.

Existing runs keep their saved encounter tables and legacy balance/evolution policy. Start a new run to choose the new encounter controls; installing an update does not silently reroll an ongoing world.

## When Random Start triggers

Choose **World + items > Random Start: Logic**. Setup shows the current start setting, its prerequisites and a summary before validation. **Randomizer Info** shows whether the portal is off, waiting, ready or complete.

- **Red/Blue/Yellow:** choose a starter, finish the rival battle, collect Oak's Parcel from Viridian Mart, return it for the Pokedex, then leave Oak's Lab. The first lab exit is intentionally not the handoff. A one-time reminder after that first exit explains the remaining steps.
- **Gold/Silver/Crystal:** receive your starter and leave Elm's Lab for New Bark Town. Original starters now work as well as randomized starters. Saving/reloading before departure also works; an interior warp cannot consume the portal.

The portal runs once and preserves native story state. It does not manufacture the Pokedex/Parcel flags or preload HMs.

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

A save that actually owns unsupported Pokémon, moves or items needs [1.4.2](https://github.com/weskestis/UniversalRandomizer/releases/tag/v1.4.2). Continue shows a message before adopting such a save, leaving its contents untouched. Use the previous release for that run or start a new run in 1.9.0. No automatic species replacement or deletion is performed. Keep separate save slots for old expanded runs and new native runs.

## Random Start and item logic

Choose **World + items > Random Start: Logic** to select SAFE badges and logical key/HM placement. The 15 authored starts use the audited escape routes described above. Randomizer guards and invisible connection blocks remain removed. Native story events still operate normally.

The portal waits for the actual intro handoff, runs once, and establishes a local respawn. HMs come from real pickups and gifts: Cianwood keeps Fly after Chuck, and Cinnabar's local Surf/Secret Key route participates in the solver. A Saffron start supplies purchasable Fresh Water for its native guard event. After the portal, earned badges advance the level ceilings described above; party level has no effect.

**SAFE** checks item, HM, badge and Gym dependencies. **CHAOS** permits unreachable placements. Use **Keys + HMs: Safe** to select the authored graph, including with Random Start off. Ordinary Shuffle/Random item modes also check their supported keys/HMs when enabled under SAFE. Proof-critical HMs may stay fixed when needed for an isolated start. Oak's Parcel and the Squirtbottle remain fixed in SAFE because their native events can become missable. Custom quests and unaudited event sources are outside the checked pool.

Managed one-time SAFE gifts go to the PC with a notice if the bag is full. Ordinary purchases keep native capacity behavior. Field/gift randomization includes native item commands, audited Gen 1 hardcoded callbacks, visible/hidden pickups and Gen 2 fruit trees. **MART SAFETY** keeps Poké Balls and Potions available and defaults on for new runs.

## Similar-strength encounters

Enable **BST MATCH** under POKEMON, then set **BST DIFFERENCE** from 0–500; the default tolerance is 50. The bound applies to randomized starters, balanced wild encounters, trainers, statics/gifts and trades using the active game's five-stat or six-stat total. With no eligible replacement, the native source remains. Truly random wilds ignore this bound. Automatic wild evolution is suppressed while BST matching is enabled so the result stays within the bound; evolution after capture is unchanged.

## Untamed Tohjo

[Untamed Tohjo](https://github.com/goldenroddeptstore/untamed-tohjo) remains supported. Its callbacks receive seeded native species and levels for grass, Surf, fishing, time groups and swarms. Previews do not consume the encounter stream or change saved encounter tables. Untamed retains ownership of its own followers, roaming identities and visual features.

## Compatibility and verification

The manifest is `>=0.3.99 <1.0.0`; the minimum supplies the touch/mouse APIs used by this release. Automated tests use Gen1Recomp 0.3.99 at `8b981540e882440f33ab09f1f56030e0ce4a8787` and Untamed 1.2.1 at `2a55770b4016e1da699b9eae79b5266afa2aa781`.

Checks cover all six editions: complete mod entry-point registration, visible settings, native species/move/type boundaries, untouched visual records and renderer methods, protected Continue behavior, actual native NPC/script/VM gifts, full-bag recovery, 450 SAFE/450 CHAOS ordinary placements, 160 Random Start seeds spanning all 15 starts, native legacy placement snapshots and Untamed spawning/battle queues. The new controls are exercised with input sequences, validation/re-entry checks and long-text scrolling. A 1,920-seed wild-mode matrix covers all six editions and four encounter layouts, and portal checks include original/randomized starters and cold Continue. Type Bias tests use the pinned engines' actual move constructors across all six editions, both safety modes, original/randomized types, 19 encounter levels, sparse STAB pools, staged setup and Continue. An additional 288-seed matrix checks SAFE badges with ordinary field/gift channels across all six games, and 72 ordinary-start runs check the full authored item graph. Cold Continue checks preserve both old and new badge policies. Field-item control checks repeat complete cycles with A, left and right, both starting safety choices, menu re-entry and Logic Random Start across all six games. Tests run under LuaJIT and Lua 5.4. The additional audit covers 5,116 setting-value pairs in all six games, all 360 core progression-setting combinations per game, all 45 edition/start pairs, 705 withheld rewards, 900 start/badge proofs, and runtime level hooks. Thirty views of the actual menu are rendered in LOVE with real font-bound checks. No full Android/ROM playthrough was performed.

The package builder inherits only `core.lua` and `adapters.lua` from the SHA-256-pinned base, then adds reviewed `mod/` sources and current documentation. It does not carry forward obsolete installers, assets or rulesets. Every packed file hash is verified before publishing the launcher-compatible release and repository ZIP.

For local checks, build with `python3 tools/package_release.py --output dist`, set `MOD_SOURCE=dist/mod`, `MOD_BASE=dist/mod`, `HOST_SOURCE` to the pinned host checkout and `UNTAMED_SOURCE` to the pinned Untamed `main.lua`, fetch the pinned test references before the regression suites, then run:

```sh
python3 tools/fetch_gen1_world_references.py
python3 tools/fetch_gen2_world_references.py
luajit tests/features.lua
luajit tests/progression_items.lua
luajit tests/startup_random_start.lua
luajit tests/native_content.lua
luajit tests/wild_modes.lua
luajit tests/modern_menu.lua
luajit tests/settings_progression_audit.lua
luajit tests/type_bias.lua
luajit tests/gen1_world.lua
luajit tests/gen2_world.lua
luajit tests/gen1_release_regression.lua
python3 tests/run_lua.py tests/features.lua tests/progression_items.lua tests/startup_random_start.lua tests/native_content.lua tests/wild_modes.lua tests/modern_menu.lua tests/settings_progression_audit.lua tests/type_bias.lua tests/gen1_world.lua tests/gen2_world.lua tests/gen1_release_regression.lua
```
