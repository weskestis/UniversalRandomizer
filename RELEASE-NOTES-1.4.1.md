# Universal Randomizer 1.4.1 — Logical Keys and HMs

Key items and HMs can now be shuffled in a new run. Turn **KEYS + HMS: ON**, enable **ITEMS/GIFT ITEMS**, and use **SAFETY: SAFE** for checked placements. **SAFETY: CHAOS** skips those checks and can produce impossible seeds.

SAFE checks item dependencies and HM badges, rejects self-locks and circular chains, and preserves every reward in the supported pool. It supports every native HM and audited story rewards across Red, Blue, Yellow, Gold, Silver and Crystal. Starter evolution lines receive HM compatibility; managed Oak aide rewards do not require a randomized Pokédex count. Full-bag managed gifts go to the player's PC with a notice, preserving one-time rewards.

Oak's Parcel and the Squirtbottle remain fixed in SAFE because their native events can become missable. Mutually exclusive fossils, special event rewards and custom quests without authored logic are outside the pool. Shuffled-badge combinations that cannot satisfy the model are rejected; use **BADGES: VANILLA** for the standard route. See the README for coverage and limits.

Existing saves retain their original placements. Start a new run to enable the new shuffle. **RANDO INFO** displays the item-logic result.

Includes all 1.4.0 BST, gift-item, Mart Safety and Untamed Tohjo compatibility features. Launcher compatibility remains `>=0.2.18 <1.0.0` (Crystal requires 0.2.24+).

Validation: 450 SAFE/450 CHAOS model placements, native Gen 1 NPC/script callbacks, native Gen 2 VM gifts, full-bag recovery, staged generation and seed rebuilding; regression checks run against pinned Gen1Recomp 0.3.99 and Untamed 1.2.1. No full Android playthrough was performed.
