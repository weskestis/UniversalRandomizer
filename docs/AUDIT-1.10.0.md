# 1.10.0 implementation and validation

## Scope and provenance

Native Red/Blue/Yellow and Gold/Silver/Crystal only. Host target: Gen1Recomp 0.3.99, commit `8b981540e882440f33ab09f1f56030e0ce4a8787`. Untamed compatibility reference remains `2a55770b4016e1da699b9eae79b5266afa2aa781`. Native species, moves, evolution and trainer fixtures use the existing hash-pinned pret sources. The manifest minimum now matches the pointer API dependency.

`mod/REFERENCE-MODS.md` records the nine uploaded reference archives and SHA-256 hashes. The release bundles original implementations of selected behavior, not those archives' code/assets. No voxel dependency, external badge-stat patch, Gen 1 shiny-rule change or global battle-transition replacement is included.

## Behavioral boundaries

- `adaptive_bosses.lua` recognizes native story identities and party members. Numeric and symbolic Gen 2 member IDs are resolved separately; later executives cannot accidentally use member 1. Gen 1 Yellow's native Rocket duo parties are included. Native callbacks, portraits, rewards and player Pokemon are retained.
- Safe teams use the native evolution/move catalog snapshotted before global mutations, badge counts and native story phase. Intro rival teams remain short/low-level. Rival starter continuity and Boss level percentage apply. Chaos retains native IDs but permits extreme teams.
- Custom goals require the existing complete world proof in Safe, including when entrances remain unshuffled. Gen 2 uses its separate adapter through all badges and Red. Gym wins use source identity even if a different leader is presented.
- Defaults are removed from the fingerprint input so 1.9.0 Off behavior remains reproducible. Existing recorder-less saves are marked partial rather than inventing earlier events.
- Share data is bounded, typed, checksummed and parsed without executing code. Unknown/duplicate keys, malformed values, wrong cartridges and normalization-changing combinations are rejected. Import only changes pending setup after review; the actual accepted seed is retained.
- Race mode suppresses randomizer location hints, seed-specific route reports, future gym details and spoiler exports before the chosen goal. Known entrances remain usable. This is not cryptographic anti-cheat.
- Run records are save/seed/cartridge scoped. Foreground elapsed time is independent of speed-up. Completion freezes finish statistics; later play can continue. Diagnostics contain bounded recent maps and configuration, not future item placements or personal file contents.
- Overlays use native experience curves, current move/type data and native Gen 2 shiny state without rolling RNG. Learning callbacks and HM protections are never replaced. A dedicated editor owns drags; the host virtual pad retains first refusal. Layouts are normalized and clamped, with separate orientation profiles and responsive untouched defaults.

## Tests

`tests/run_tools.lua` covers story teams from the native six-edition corpus; safe introductory fights; rival families; all presets; custom goals with shuffled and unshuffled worlds; race gates; code corruption and cartridge mismatch; save isolation; Continue; actual native battle construction and moves; source-based shuffled gym credit; and comparison against the published 1.9.0 generator.

`tests/overlays.lua` covers four viewport sizes, scale/edge bounds, touch drag, mouse resize, cancellation, save persistence, orientation independence, tap-versus-scroll separation, validation input lock, native Gen 1/2 move comparisons, untouched HM/PP data and capped EXP.

The modern-menu driver also exercises new story settings, preset review/cancellation and exact-seed clipboard import. The two LOVE preview drivers render 48 actual menu/overlay views, including phone portrait, phone landscape and desktop layouts. The existing driver checks font bounds; the overlay driver renders the actual production drawing code for inspection.

The complete prior feature, progression-item, startup, native-content, wild-mode, settings-combination, Type Bias, Gen 1/2 world, frozen-release and adaptive-gym suites remain release gates under both LuaJIT and Lua 5.4. CI also rebuilds native fixtures from pinned sources and verifies every packaged file hash. Publication runs only after these checks.

These are headless/runtime-constructor and rendering tests, not a physical Android session or full human playthrough. Structural progression certification assumes the authored native graph, manageable combat/resources and sensible HM use. External quest changes and Chaos are outside a universal beatability claim.
