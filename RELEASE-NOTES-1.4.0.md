# Universal Randomizer 1.4.0

- Add optional BST matching with an exact 0-500 difference setting; 50 is the initial value. Empty eligible pools preserve the source instead of exceeding the limit.
- Add gift-item randomization for native Gen 1/2 gift commands, with correct quantities and bag-full/event behavior. Preserve key items and HMs; keep TM gifts as TMs.
- Extend field-item randomization to Gen 2 fruit trees and avoid randomizing visible/hidden pickups twice.
- Enable Mart Safety by default for fresh configurations, retaining saved choices. Poké Balls and Potions remain in all native marts when enabled.
- Add automatic Untamed Tohjo 1.2.1 integration for visible grass/surf/fishing encounters, time-of-day groups and swarms. No patched companion download required.
- Correct VANILLA area mode so it preserves species.

**Suggested settings:** BST MATCH on, BST DIFFERENCE 50; ITEMS and GIFT ITEMS RANDOM; MARTS SAFE; MART SAFETY on. Choose these during a new game's Randomizer setup.

Existing runs retain their saved settings. BST matching and gift-item randomization start disabled for old configurations. The launcher range remains `>=0.2.18 <1.0.0`; Crystal requires 0.2.24+.

Validation: automated checks on LuaJIT and Lua 5.4, including the real Untamed spawn-to-battle queue and Gen1Recomp 0.3.99 world/script APIs. No Android visual/touch testing or full playthrough was performed. Custom item rewards that bypass native gift commands are not covered.
