# Universal Randomizer 1.4.0

[Download the latest release](https://github.com/weskestis/UniversalRandomizer/releases/latest), or check for updates in the Gen1Recomp mod manager. The launcher compatibility range remains `>=0.2.18 <1.0.0`; Crystal requires 0.2.24 or newer.

## Similar-strength runs and randomized items

In New Game > Randomizer setup:

- **POKEMON:** turn **BST MATCH** on, then set **BST DIFFERENCE** to **50** (any integer from 0 to 500). Zero means equal BST. The picker has +1/-1, +10/-10 and +50/-50 controls.
- **WORLD + ITEMS:** set **ITEMS** and **GIFT ITEMS** to **RANDOM**, set **MARTS** to **SAFE** or **CHAOS**, and leave **MART SAFETY** on.

BST matching applies to randomized starters, wild encounters, trainer replacements, static/gift Pokemon and trades. It uses the cartridge's stats: five in Gen 1, six in Gen 2. A replacement stays within the chosen absolute difference. When no eligible replacement exists, the source stays. Tight limits can reduce area variety and trade uniqueness. Automatic wild evolution is suppressed while BST matching is on so it cannot exceed the limit; ordinary evolution after capture is unaffected.

Gift-item randomization covers Gen 1 `give_item` and Gen 2 `giveitem`, `verbosegiveitem`, `verbosegiveitemvar`, including variable-held item IDs. Quantities, bag-full outcomes and event flags remain native. Key items and HMs stay protected; TM gifts remain TMs. Field items include visible/hidden pickups and Gen 2 fruit trees. Field pickups are not randomized a second time as gifts. Custom rewards that bypass these native commands are outside this adapter.

Mart Safety supplies Poke Balls and Potions to every native mart stock. It defaults on for new configurations; saved choices remain in effect. Existing runs keep their settings, with BST matching and gift-item randomization off until selected for a new run.

## Untamed Tohjo

Enable [Untamed Tohjo](https://github.com/goldenroddeptstore/untamed-tohjo) alongside this mod. No modified Untamed download is required. The adapter presents seeded species and levels to Untamed's own callbacks, including grass, surf, fishing tiers, time groups and swarm tables. Its sprites, stored wild Pokemon and queued battles read the same projected data. Native encounter tables are restored for other mods and normal gameplay; previews do not consume encounter RNG. Untamed's chains, DVs, shiny handling, followers and roaming-save identity stay under Untamed's control.

Tested against Untamed 1.2.1 (commit `2a55770b4016e1da699b9eae79b5266afa2aa781`) and Gen1Recomp 0.3.99. Automated headless checks cover the actual Untamed spawn/battle queue, the host's world facades and script VM. Android visuals, touch controls and a full playthrough have not been tested here.

## Development and verification

`mod/` contains the changed runtime sources. `tools/package_release.py` overlays them on the SHA-256-pinned 1.3.42 package, retaining the unchanged assets and updating every pack hash. GitHub Actions tests the complete built package before publishing the launcher-compatible `v1.4.0` tag and updating the repository ZIP.

For a local check, build the ZIP, extract it to `dist/mod`, set `MOD_SOURCE` and `MOD_BASE` to that folder, `HOST_SOURCE` to Gen1Recomp 0.3.99 and `UNTAMED_SOURCE` to the pinned Untamed `main.lua`, then run `luajit tests/features.lua`.

---

## Earlier feature documentation

## Gen1Recomp compatibility

Red, Blue, Yellow, Gold, and Silver remain supported on Gen1Recomp 0.2.18+. **Crystal is supported on Gen1Recomp 0.2.24+**, using the host's native Crystal engine/data identity. Gold, Silver, and Crystal share the randomizer's Gen 2 systems while retaining edition-specific host data and Crystal-specific trade metadata.

# Universal Randomizer 1.3.36 — Gen 1–4 Complete Scope














### 1.3.36 / Random Start guard + Percentage isolation fix

- Fixes LOGIC Random Start Protection Guards spawning as long walls/stacks across wide map connections.
- Wide exits now show one stable representative guard per blocked branch; the connection itself is blocked by a narrow Gen1Recomp connection bridge so the player cannot walk around the marker.
- Shared transit steps are never blocked when they are also the first step of the seeded correct route.
- PERCENTAGE is now mathematically isolated from Random Start progression: party level cannot cap, floor, or otherwise rewrite wild, trainer, boss, static, or Cianwood utility-gift levels.
- In PERCENTAGE, levels use only the native/randomized baseline plus the configured Wild/Trainer/Boss percentage. Protection Guards may still use the player's level as a pass/fail roadblock check; they do not modify encounter levels.
- HYBRID retains the Random Start local safety ceilings; PROGRESSION retains global party-relative scaling.
- Preserves the 1.3.35 authored battle-sprite send-out fix unchanged.

### 1.3.35 / Authored battle sprite send-out fix

- Treats every #001-493 replacement battle sprite as final authored artwork, including the original Gen 1/2 roster that now uses upgraded Gen 3+ art.
- Preserves the Poké Ball/poof send-out timing but skips cartridge-style intermediate sprite resize/resampling stages.
- Gen 1: authored sprites reveal at their exact final scale after the three-frame ball beat instead of 3/7 -> 5/7 resampling.
- Gen 2: authored sprites ignore only ANIM_SEND_OUT_MON's BG pic-resize stages; ball, OAM, shiny, cry, HUD and unrelated battle animations remain native.
- No randomizer, evolution, level scaling, Random Start, Protection Guard, UI, or battle-rule behavior is changed.

### 1.3.34 / Evolution-system correctness fix

- Fixes exact male/female parsing for gender-specific evolutions.
- Restores real Dawn/Dusk/Shiny/Sun/Oval Stone requirements instead of unresolved-item level fallbacks.
- Preserves held-item, trade-item, friendship, time, location, known-move, party-species, personality and branched evolution conditions through runtime Pokédex overlay rebuilds.
- Missing required evolution items now fail closed rather than turning into ordinary level evolutions.
- Nincada cast-off evolution is runtime-backed, including GEN4 Poke Ball consumption and randomized cast-off targets.

### 1.3.33 / World Settings visibility hotfix

- Fixes clipped/invisible World Settings values on Red/Blue/Yellow and keeps the same rows safe on Gold/Silver/Crystal.
- `RANDOM BADGES`, `RANDOM START`, and `PROTECTION GUARDS` use compact World Settings labels: `BADGES`, `START`, and `GUARDS`.
- The live Mod Options label is also shortened to `GUARDS` so its ON/OFF value remains visible.
- UI-only change: no seed, Random Start, Protection Guard, scaling, battle, save, or validation logic changed from 1.3.32.

### 1.3.32 / New Game validation-start fix

- Fixes a startup stall where holding or repeatedly pressing A on `VALIDATE + BEGIN` restarted the frame-staged seed validator every input frame instead of allowing the active validation to finish.
- Validation now owns the setup screen until its single 14-stage pass completes; repeated A/B/touch input cannot restart or cancel it mid-pass.
- Replaces the cramped right-side validation footer with a clear full-width `VALIDATING x/14` / `PLEASE WAIT` presentation.
- Validation-step/callback failures are now logged and returned to the setup screen instead of being silently swallowed.
- Oak/Elm startup finalization always releases the intro timeline even if a post-commit option/ruleset mirror throws, preventing a second class of post-validation startup hang.
- Verified on Red, Blue, Yellow, Gold, Silver, and Crystal with Gen1Recomp 0.2.24.

### 1.3.31 / Random Start final scaling authority

- Fixes a cross-generation level-scaling hole where a later encounter/trainer modifier, or a Gen-2 special encounter path, could restore high native levels after Universal Randomizer had already applied Random Start protection.
- PROGRESSION now receives a final outer level-authority pass after the rest of the hook chain, so the whole world stays in the current party-relative band even when Random Start is active.
- PERCENTAGE and HYBRID LOGIC Random Start apply the same final authority on the seeded guided route, while dangerous alternate routes retain their intended native-style difficulty and Protection Guard behavior.
- LOGIC Random Start initializes its guided-route state at the warp itself so the first encounter/trainer after arrival cannot see stale previous-map state.
- Gen-2 Headbutt and Rock Smash now receive the same final route-level authority as grass/cave/Surf/fishing encounters.
- Fresh guided starts prioritize an encounter-bearing first route when one is available, avoiding trainer-only/story interiors as the initial catch/progression leg.
- Verified together on Red, Blue, Yellow, Gold, Silver, and Crystal against Gen1Recomp 0.2.24.

### 1.3.28 / Gen-2 zero-HP battle guard

- Fixes a Gold/Silver/Crystal Gen 3/4 compatibility edge case where an end-of-turn compatibility effect could reduce the active Pokemon to 0 HP after the host's native faint sweep.
- 0-HP battlers are rejected by the action gate and post-turn KOs are immediately routed back through the native Gen-2 faint/replacement/loss pipeline before the command menu reopens.
- No seed generation, encounters, trainers, scaling, UI layout, or Crystal adapter behavior changed.

### 1.3.27 / 16:9 settings UI fix

- Randomizer setup and RANDO INFO now use a true 256×144 16:9 surface.
- Gold/Silver/Crystal opt into Gen1Recomp's Gen-2 widescreen compositor instead of clipping at the legacy 160px stack target.
- Long values such as `PERCENTAGE` and `FULL SLOT` render completely.
- Level rows use `PCT` text instead of unsupported Gen-2 `%` / `+` glyphs, e.g. `TRAINER LEVEL: -50 PCT`.
- No randomization or gameplay logic changed from 1.3.26.

### 1.3.26 / Gen1Recomp 0.2.24 + Crystal support

- Promotes Pokémon Crystal from the prepared/pending adapter to a first-class runtime target on Gen1Recomp 0.2.24+.
- Supports both canonical US Crystal revisions exposed by 0.2.24 (1.0 and 1.1).
- Uses Crystal's native seven-row NPC trade table and four dialog sets rather than truncating to Gold/Silver's six-row structure.
- Reuses the existing Gen 2 randomization, starter, encounter, static/gift, TM/HM, item, Mart, level-scaling, ability/nature and SAFE-progression systems against Crystal's edition-specific imported data.
- Red/Blue/Yellow/Gold/Silver behavior from 1.3.25 is preserved.

### 1.3.25 / menu readability hotfix

- Shortens the setup row from `RANDOM ABILITIES` to `ABILITIES` so Gen 1 visibly shows the selected `NORMAL / SAFE / CHAOS` value instead of clipping it off-screen.
- Shortens `LEVEL SCALING MODE` to `LEVEL MODE` so `PROGRESSION / PERCENTAGE / HYBRID` remain fully visible on Gen 2.
- Uses the same compact `LEVEL MODE` wording in live Mod Options.
- Shortens the live Mart Safety label to `MART SAFETY`; the row value still controls ON/OFF and behavior remains Ball + Potion safety.
- No randomization, seed, progression, or battle behavior changed from 1.3.24.

### 1.3.24 / early-matchup + Mart Safety

- SAFE randomized starters now receive a complete four-move damaging opening set when the active move registry permits it. The set is deterministic per seed, prioritizes distinct attack types, and includes a Fire/Flying/Rock/Ghost/Dark answer so native Wonder Guard Shedinja cannot hard-lock the starter.
- During the opening two-badge window, SAFE randomized trainer slots reject any species currently carrying Wonder Guard. After two badges, Wonder Guard behaves normally.
- Starter safety excludes self-KO/no-action/conditional-only opening attacks such as Selfdestruct, Explosion, Splash, Teleport, Dream Eater, Snore, Last Resort and Sucker Punch from the guaranteed four-move set.
- **MART SAFETY** is available in New Game → WORLD + ITEMS. When ON, every normal Poké Mart guarantees **Poké Ball + Potion** in addition to its normal or randomized stock.
- **MODS → Universal Randomizer → OPTIONS → MART SAFETY: BALL + POTION** can turn the guarantee on or off during an active save. Turning it off removes only safety-added stock and restores the seed's underlying mart inventory.
- Mart Safety defaults OFF, so existing behavior is unchanged unless the player chooses it.

### 1.3.23 / party-menu icon presentation polish

- Fixes species-specific party icons still passing through legacy cartridge icon transforms after the `pokemon.icon` path override.
- Red/Blue/Yellow now register all #001-493 mini-sprites as authored per-species RGBA icon entries, preventing Gen 1 OBP grayscale remapping and symmetric-half mirroring from mangling the replacement art.
- Gold/Silver now keep the authored icon colours instead of forcing every species through the shared party OBJ palette.
- Gold/Silver selected-row motion is reduced from the stock 8px slide / 2px bob to a subtle 2px nudge / 1px bob while retaining the two-frame species animation.
- Battle sprites, summary/front/back sprites, held-item logic, and gameplay/randomizer behavior are unchanged.

### 1.3.19 / unified progression scaling

- Extends the progression-aware level floor across every randomized/scaled battle category in Red, Blue, Yellow, Gold, and Silver.
- Wild and static/non-trainer enemy Pokemon use the stronger of their native level or roughly one level below the player's strongest party Pokemon, then apply Wild Level %.
- Normal trainers use the stronger of their native ace or roughly one level above the player's strongest party Pokemon, keep a deterministic three-level team band, then apply Trainer Level %.
- Bosses use the stronger of their native ace or roughly three levels above the player's strongest party Pokemon, keep the same tight band, then apply Boss Level %.
- Randomized gifts receive a progression floor near the current party but are not multiplied by Wild Level %, preventing beneficial gift scaling from being tied to an enemy-difficulty control.
- Native content that is already harder is never globally reduced; LOGIC Random Start safety caps remain authoritative where required.
- Explicit UNCHANGED/VANILLA + 0% paths retain vanilla levels.

### 1.3.18 / updater publication hotfix

- No gameplay/randomization changes from 1.3.17.
- Version bump only, to provide a clean semver target for Gen1Recomp GitHub release/update detection.
- Canonical GitHub release asset name: `universal_randomizer-1.3.18.zip`.

### 1.3.17 / progression-aware wild level band
- Randomized/scaled wild encounters no longer become obsolete just because the player has out-levelled an area's native table.
- The pre-modifier wild ceiling is now the higher of the area's strongest native encounter level or one level below the player's current strongest party Pokemon.
- Individual wilds are deterministically spread across a tight three-level band (`anchor-2 .. anchor`) so encounters retain natural level variety instead of all appearing at one level.
- The live Wild Level % is applied after that progression-aware band, preserving true -50%..+50% scaling.
- LOGIC Random Start safety caps still override the progression band where required, and `AREA ENCOUNTERS = VANILLA` plus `WILD LEVEL = 0%` still preserves exact vanilla slot levels.

### 1.3.16 / tight trainer-party level bands
- Randomized trainer and boss parties now use a tight three-level band anchored to that trainer's highest native party level instead of preserving extreme low filler slots.
- Teams keep level variety: multi-Pokémon parties are deterministically distributed across roughly `anchor-2 .. anchor` before the live Trainer/Boss % modifier is applied.
- Example: a native Lv8/Lv23 pair becomes roughly Lv22/Lv23 at 0%—not Lv8/Lv23 and not a flat Lv23/Lv23 team.
- Setting a non-zero Trainer/Boss Level % also uses the tight band even when trainer species are unchanged; `TRAINERS = UNCHANGED` at 0% still preserves vanilla per-slot levels.
- LOGIC Random Start safety caps remain hard ceilings before the user's live percentage is applied.

### 1.3.15 / upper wild-level baseline

Removes low-level slot rolls as the baseline for randomized wild encounters. When encounters are randomized, or when Wild Level % is explicitly non-zero, grass/cave/surf encounters use the highest native level in the current map/time-of-day table before the live -50%..+50% modifier is applied. Fishing uses the highest level for the current rod only, and Gen 2 Headbutt/Rock Smash use the highest level in their own encounter list. Exact vanilla slot-level behavior is preserved only when AREA ENCOUNTERS is VANILLA and WILD LEVEL % is 0. Random Start progression safety caps still apply before the live percentage, so isolated early starts remain safe.

### 1.3.14 / normal-start wild level coverage

Fixes live Wild Level % on normal starts. Gen 2 Headbutt and Rock Smash encounters bypass the shared `encounter.species` hook, so 1.3.13 randomized their species but left their original levels untouched; both paths now apply the same -50%..+50% live scaler as grass/cave/surf/fishing. When Kaizo Ultimate is stacked, changing a Universal Randomizer Wild/Trainer/Boss percentage now makes that Randomizer row authoritative by resetting only the matching Kaizo live percentage to 0% (Kaizo's documented defer-to-Randomizer state). This prevents a non-zero Kaizo Wild LV from silently overriding a value the player just changed in the Randomizer menu. Normal starts receive no Random Start progression cap.

### 1.3.13 / RBY SAFE-start progression audit

Red, Blue, and Yellow LOGIC Random Start now receive the same starter-level progression treatment as the Silver Cianwood fix. Cerulean starts persist the cart's post-Rocket guard arrangement so the low-level south exit is open without marking Bill/Rocket story events complete. Saffron starts set only the guard-drink transit permission so all four gates are usable. Lavender starts progression-compress Route 8. Fuchsia becomes a true isolated SAFE start: Koga's gym scales from current party/badge progression, a visible local Safari/Fuchsia pickup is forced to Surf, and the SAFE badge plan guarantees Soul Badge there. Cinnabar keeps its Surf/Fly escape families, but Blaine's gym and Mansion/local wild levels scale to progression, the forced escape HM now prefers visible pickups, and every randomized starter option is guaranteed compatibility with the selected escape HM when vanilla TM/HM compatibility is in use. These automatic RBY adjustments only lower early-inappropriate vanilla levels; once the player catches up, the content returns to its original level band before the user's live Trainer/Boss/Wild Level % is applied. Normal RBY progression and nonmatching random starts remain unchanged.

### 1.3.12 / Silver Cianwood SAFE-start progression

Cianwood remains in the Gen 2 LOGIC Random Start pool, but a run that actually begins there is now self-contained. The Mania/Shuckle gift becomes a deterministic non-legendary Flying-type (unless legendaries are enabled), is scaled near the player's current party level, and is guaranteed to know Fly. The Cianwood escape certificate is Fly/Storm based. Because vanilla Chuck is also locked behind a Strength boulder puzzle, the three Cianwood Gym boulders spawn in their solved arrangement only for a run whose seeded LOGIC start is Cianwood. Cianwood Gym trainer and Chuck levels scale to the player's current party and Johto-badge progression before the normal live Trainer/Boss Level % setting is applied. This scaling is scoped only to LOGIC runs whose seeded start is Cianwood; ordinary Silver/Gold playthroughs and other random starts keep vanilla gym progression.

### 1.3.11 / stacked-mod trainer HP finalization

Fixes the remaining trainer HP-bar case when Universal Randomizer is stacked with Kaizo Ultimate. Kaizo intentionally owns the final trainer/boss percentage when its matching live level setting is non-zero and wraps `trainer.party` outside the Randomizer. 1.3.10 filled current HP before that outer percentage could run, so a later level increase could enlarge max HP while preserving the lower current HP. 1.3.11 leaves constructed Gen 2 trainer HP/stat fields invalidated through the complete mod-hook chain and lets Gen1Recomp's post-hook `Mon.refreshStats` construct current HP and max HP together from the final species and final level. Raw Gen 1 trainer rows remain on the native `Pokemon.new` path.

### 1.3.10 / trainer HP-bar follow-up

Fixes the remaining Gen 2 trainer send-out HP-bar case that 1.3.9 could miss. The 1.3.9 reset was gated on both Gen 2 detection and a DV field. 1.3.10 instead recognizes already-constructed trainer Pokémon from their derived combat fields, invalidates stale HP/max-HP/stats after species/level randomization, immediately rebuilds the final stats when the Gen 2 helper is available, and explicitly starts a fresh trainer Pokémon at its final maximum HP. Raw Gen 1 trainer rows are left unchanged.

### 1.3.9 / Gen 2 trainer HP-bar hotfix

Fixes freshly generated Gold/Silver trainer Pokémon appearing partially damaged when trainer or boss level scaling raises their level. Gen 2 hands constructed trainer mons through the randomizer hook; their old current HP was surviving while the host recalculated a larger max HP. The randomizer now clears only derived trainer combat fields before the host refresh, so each newly generated trainer Pokémon enters at full HP using its final randomized species/level while preserving DVs, held items, and the rest of the trainer data.

### 1.3.8 / live mid-run level controls

Adds a second access point for level scaling without removing the New Game setup. While a randomized run is active, **MODS → Universal Randomizer → OPTIONS** now exposes independent **WILD LEVEL %**, **TRAINER LEVEL %**, and **BOSS LEVEL %** controls from -50% through +50% in 10% steps. Changes persist with the current randomizer config and take effect when the next wild encounter or trainer party is generated; an already-running battle is not rebuilt. Boss scaling is now independent of normal trainer scaling. Existing 1.3.7 saves migrate by inheriting their prior Trainer Level percentage for Boss Level so upgrade behavior is preserved.

### 1.3.7 / blackout runtime persistence

Fixes a blackout/whiteout lifecycle bug where Random Start's saved respawn location could survive while the process-local Randomizer runtime stopped owning subsequent trainer, boss, and wild level scaling. Blackouts now explicitly rehydrate the committed seed/config before the respawn warp, and trainer-party, fishing, enemy-AI, gift, script, and warp runtime seams self-recover from the saved seed if the active runtime object is missing. This keeps configured Trainer/Wild level percentages and boss/trainer AI active after a wipe instead of silently falling back to vanilla. Target baseline is Gen1Recomp 0.2.18+.

### 1.3.6 / Kaizo Ultimate interoperability

Corrects STRONG trainer/boss AI so Gen 1 uses the Gen 1 move-definition/data path and retains the selected live move instance (including PP/state) instead of constructing a detached action table. This makes STRONG AI safe when Universal Randomizer is stacked with Kaizo Ultimate 1.5.0-test3. Kaizo's non-zero level percentages take precedence only for the matching level category; 0% leaves the Randomizer level result unchanged.

### 1.3.3 / menu mini-sprite fix

Fixes the party/menu mini-sprites retaining the opaque chroma-key background from their source sheets. All 493 two-frame icons now have transparent backgrounds, so expanded species render as actual mini-sprites instead of colored squares. Verified in real 0.2.15 Red, Gold, and Silver party menus.

### 1.3.2 / Gen 2 expanded-starter runtime fix

Fixes the field-reported Gold/Silver case where a Gen 3/4 starter roll could still execute Elm's vanilla one-byte species operand, leaving Chikorita/Cyndaquil/Totodile visible in black and white. Expanded starter targets now temporarily bridge through the selected pedestal's cartridge index for `pokepic`, `cry`, `getmonname`, and `givepoke`, then restore the host definitions immediately. The chooser text is replaced independently of native-index availability. Real 0.2.15 runtime tests now open, preview, confirm, and receive all three balls in both Gold and Silver with expanded targets.

### 1.3.1 / Gen1Recomp 0.2.15 hotfix

This build fixes starter sets that could visibly retain vanilla starter species, restores full-color Oak/Elm starter previews on the current 0.2.15 host, and prevents randomizer menu/status text from drawing past the wide setup surface. See `TEST-REPORT-0.2.15-HOTFIX.txt` for the executed runtime checks.

This build deliberately stops at **Generation 4**. It combines the certified National Dex #001–493 content layer with an independent per-save battle-rules selector through Gen 4.

## Pokémon content

- NATIVE
- GEN 1 (#001–151)
- GEN 1–2 (#001–251)
- GEN 1–3 (#001–386)
- GEN 1–4 (#001–493)

All 493 species have front sprites, back sprites, party icons, species data, evolution references, and randomizer pool support. The selected Pokédex ceiling is used by starters, trainers, wild encounters, static/gift Pokémon, trades, evolutions, and SAFE validation.

## Battle rules selector

- RULESET: GEN 1
- RULESET: GEN 2
- RULESET: GEN 3
- RULESET: GEN 4

The ruleset is independent of the Pokédex pool, is committed with the seed, participates in the run fingerprint, restores on save load, and is locked for the seeded run so mechanics cannot be changed silently mid-run.

Core generation differences covered by the rules framework include host-native Gen 1/2 delegation where available, Gen 1 single-Special compatibility, split Sp. Atk/Sp. Def for Gen 2+, type-based physical/special behavior through Gen 3, move-specific physical/special categories for Gen 4, generation-aware type effectiveness, critical-hit handling, accuracy behavior, and damage variance.

## Scope lock

Generation 5+ Pokémon and a Gen 5 rules option are intentionally not exposed in this release. This keeps the project focused on a fully validated Gen 1–4 target.

## Runtime target

Release baseline: Gen1Recomp 0.2.18 for Red/Blue/Yellow/Gold/Silver; Gen1Recomp 0.2.24+ for Crystal. Silver uses its own Gen1Recomp version identity and ROM-derived data while sharing the Gen 2 randomizer/Elm/Random Start logic with Gold. Crystal uses the host's separate `engine="crystal"` lineage and edition-specific imported data while sharing the generation-wide randomizer framework. Crystal 1.0 and 1.1 are accepted by the 0.2.24 host.

See `TEST-REPORT.txt` for the exact certification boundary and checks.


## WIP Save 4 validation change
SAFE seed validation is now single-pass: preflight first, then one selected seed is constructed and validated. The old synchronous multi-candidate whole-registry retry loop has been removed to prevent Android startup freezes.

## WIP Save 5 — Retryable validation + seed hints

- AUTO SAFE validation now performs exactly one bounded seed attempt per press.
- A failed AUTO attempt leaves every selected option intact and changes the button to VALIDATE AGAIN; pressing it rolls a new candidate and tries once more.
- Manual seeds remain exact and are never silently replaced.
- Every readable sign can surface one deterministic hint generated from the committed seed and finalized randomized world data.
- Sign hint quality is intentionally mixed: trash, medium, and strong.
- Paid answers are available from the Start menu for 5000 Poke Dollars. One answer is generated per purchase with a useful bias (15% trash / 45% medium / 40% strong).
- Purchased answers have no category picker. A valid hint is selected first; money is then deducted.
- Paid hint progression is saved so repeated purchases advance deterministically within the same seed.

## WIP Save 6 Android expanded-pool validation optimization
The expanded Pokédex validation path now caches the move and HM pools used by bulk Pokemon mutation instead of rebuilding those registries for every species/learnset entry. This checkpoint specifically targets the observed difference where NATIVE validates but larger G1-2/G1-3/G1-4 pools can appear frozen on Android.

## WIP10 — Generation-native sprite bridge

Expanded Pokémon no longer use the old generic normalized battler set. The active
sprite bridge now uses original-generation source presentation for the expanded
roster:

- #152-251: Pokémon Gold/GSC front/back art and menu-icon style.
- #252-386: Pokémon Emerald 64x64 front/back art.
- #387-493: Pokémon Platinum 80x80 front/back art.
- Battle contexts keep the original source canvas and use Gen1Recomp's grounded
  battle-scale controls instead of destructively resizing the source image.
- Summary/Pokédex/evolution-style contexts use compact 56x56 canvases generated
  from those same native pixels so larger GBA/DS sprites do not overlap the
  Game Boy UI.
- Shiny battle/UI variants are generated from the original game's shiny palette
  where the live sprite seam exposes a shiny Pokémon instance.
- Party icons are sourced from the matching generation and adapted only to the
  Gen1Recomp party-menu sheet size.

Gen 1 Pokémon remain owned by the native Red/Blue/Yellow host renderer; on Gold,
#001-251 remain owned by Gold's native renderer. This avoids replacing art the
running game already presents correctly.


## WIP Save 11 visual/audio policy
All Pokémon #001-386 now have at least Gen 3-era front/back battle art; #387-493 retain Platinum Gen 4 art. All #001-493 receive species-specific cry audio from the Platinum source set on every host.


## Save 12 visual correction
- Gen 3 is the minimum visual floor for #001-386 on every sprite surface.
- Gen 4 native art remains for #387-493.
- All replacement art is forced true-color so cartridge palette remaps cannot recolor it.
- Gen 1 native 2x back-sprite scaling is disabled for 64x64 Gen 3 backs.
- Upgraded party icons now apply to native Gen 1/2 species as well as expanded species.


## Release candidate additions

- Random Badges: VANILLA / SAFE / CHAOS. SAFE Random Start requires SAFE badges and validates badge + HM escape chains for isolated starts.
- Kanto Random Start excludes Pallet Town and Viridian City. Cinnabar supports both Surf/Soul Badge and Fly/Thunder Badge escape plans.
- Gold Random Start arms when Elm grants the starter and consumes on the first exterior warp; it is one-shot across save/load state.
- Random Start now seeds the blackout/whiteout respawn at that start location immediately; until a Pokémon Center is reached, wipes cannot send the player back to the bedroom/home spawn.
- Random Abilities: NORMAL / SAFE / CHAOS; abilities are active only under Gen 3/4 rules.
- **Random Natures toggle:** ON/OFF in Pokémon Settings. ON assigns all 25 Gen 3/4 natures with their correct stat modifiers; OFF disables nature assignment/stat modifiers. Natures remain inactive under Gen 1/2 rules.
- Wild Levels, Trainer Levels, and Boss Levels: independent -50% through +50% controls in 10% steps. The same three percentages remain available at New Game setup and are also adjustable mid-run from the mod OPTIONS page.
- Trainer AI and Boss AI: NORMAL / STRONG. STRONG improves move choice without reading future input; bosses use the stronger weighting.
- Wide 304x144 Recomp-native setup screens and Run Info/share-code coverage for the new settings.

### 1.3.22 — First-Gym Random Start Exclusion

Random Start no longer selects the first Gym city in either generation. Pewter City is excluded from Red/Blue/Yellow LOGIC and CHAOS pools, and Violet City is excluded from Gold/Silver LOGIC and CHAOS pools. This prevents Random Start from accidentally collapsing back into the normal first-Gym progression route. Normal non-random progression through Pewter/Violet is unchanged.

## Version Notes

### 1.3.30

- Adds **Protection Guards: ON/OFF** to New Game setup and live Mod Options.
- Protection Guards default ON and apply to LOGIC Random Start in PERCENTAGE and HYBRID.
- Turning guards OFF removes physical roadblocks immediately while keeping the seeded correct route and sign hints active.
- Turning guards back ON rebuilds applicable roadblocks immediately.
- PERCENTAGE + LOGIC Random Start now uses the same one-route guided progression system as HYBRID: one playable route remains available while dangerous alternate exits keep their native percentage-scaled difficulty.
- Pure PROGRESSION remains global rubber-banding across the world and never activates route guards.
- Applies to Red, Blue, Yellow, Gold, Silver, and Crystal.

### 1.3.29

- Fixed Crystal/Gold/Silver LOGIC Random Start progression so a fresh starter is not surrounded only by mid/late-game native encounter levels.
- Landing-area wilds, local trainers, and the local Gym now use starter-appropriate safety ceilings that grow with badges/party progress.
- Covers normal/time encounters, Surf, fishing, Headbutt, Rock Smash, and local scripted statics without changing CHAOS or ordinary progression.





## 1.3.41

- Randomized wild encounters now guarantee that non-level evolution families are no longer left unevolved beyond Lv44. Stone, trade, friendship, held-item, gender, time, location, known-move, party-condition and other special-method families are promoted by Lv45 at the latest.
- Ordinary level evolutions still use their real evolution thresholds, even when that threshold is above Lv45.
- Expanded level-conditional branches such as Burmy/Combee gender evolutions and Tyrogue/Wurmple personality/stat branches retain their real level gates instead of being delayed to Lv45.
- When a special evolution has multiple valid branches (for example Eevee), the wild form is chosen deterministically from the active seeded evolution graph rather than always favoring the first table row.
- The rule is wild-encounter-only. Evolution requirements after capture are unchanged.

## 1.3.40

- Randomized wild encounters now promote ordinary level-evolution chains after the encounter's final level is known. A randomized species encountered at or above its normal level-evolution threshold appears in the appropriate evolved stage instead of remaining an implausibly high-level base form.
- The promotion pass runs after Percentage / Progression / Hybrid scaling and after LOGIC Random Start route caps, so a route that is lowered to starter levels does not accidentally keep a species evolved based on its old native level.
- Applies to grass/cave, Surf, fishing, and the Gen-2 Headbutt / Rock Smash bridges.
- Only unconditional level evolutions are automatic. Stone, trade, friendship, gender, time, known-move, location and other special evolutions are not forced merely because the encounter level is high.
- RANDOM evolution targets are respected because promotion follows the active randomized evolution graph.

## 1.3.39

- Fixes Gen-1-host starting moves for expanded Pokémon so caught/gift Pokémon use the cartridge's actual sequential four-move window instead of trimming only after the entire learnset scan.
- Stable-sorts only the expanded Platinum/Gen-4 level-up rows before adapting them to the Gen-1/Gen-2 engines. This corrects source-order cases such as Banette's Lv5 Night Shade / Lv8 Screech without rewriting native cartridge learnset order.
- Native Pokémon keep the learnset from the game being played. Added Pokémon use the bundled Platinum/Gen-4 level-up learnsets. The selectable battle RULESET does not swap learnset sources.
- RANDOM and TYPE BIAS movesets continue to randomize move identities while preserving every learn level.

## 1.3.38

- Fixes LOGIC Random Start + PERCENTAGE opening areas inheriting mid/late-game native levels (for example Lv20+ first-area encounters).
- PERCENTAGE still never reads party level for scaling. Instead, the seeded correct route receives a fixed route-position baseline: opening wilds cap at Lv7, normal trainers at Lv9, and bosses at Lv12 before the user's percentage modifier.
- The landing hub and first guided destination share the opening tier; later guided legs rise by fixed 3-level steps independent of party strength.
- Off-route areas keep their native/randomized percentage baseline and remain controlled by Protection Guards.

## 1.3.37

Fixes GEN 3/4 critical-hit, accuracy, and damage-variance RNG adaptation on Gold/Silver/Crystal.
