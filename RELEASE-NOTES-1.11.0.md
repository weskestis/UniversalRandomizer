# Universal Randomizer 1.11.0

Update through the launcher mod manager, then fully restart. Requires launcher 0.3.99+. All six supported games retain their native Pokemon, rules and sprites.

- **World + items → Randomize Trainers (items): Off / Safe / Chaos.** Roughly one quarter of distinct native trainer rosters have a seeded item drop. Safe uses native items/TMs and lets keys/HMs move to audited trainer victories. Assigned rewards are guaranteed when you win; required progression never depends on a second chance roll. Chaos permits unchecked keys/HMs. Repeated wins cannot farm the same reward. Full bags send rewards to the PC; the progression tracker records them.
- **Capture rewards removed**, including their event handler. Catch statistics in the recap remain.
- **World + items → Hidden items: Off / Safe / Chaos.** Off preserves vanilla hidden pickups, including the Gen 2 Machine Part. Safe randomizes ordinary hidden rewards independently of visible field items, preserving required TMs and audited quest dependencies. Required keys/HMs cannot be placed at unaudited hidden coordinates. Chaos adds native keys/HMs to the hidden pool. Coordinates, collection flags, hidden coins and Itemfinder behavior remain native.
- **Validator integration:** trainer identities and reward bindings are reconstructed from native data; both progression graphs check local gates, badge permissions, random starts and shuffled entrances. Self-locking rewards are rejected. Chaos validates real items and bindings without claiming beatability. Hidden pickups are checked for mode, valid items and shared-event consistency.

New controls default Off. Existing saves retain their worlds and original hidden/field-item policy; old Some/All trainer settings keep their ordinary rewards. Start a new run for the new modes. Existing 1.10.0 share codes remain supported. The modern menu explains the rules and scrolls long guides.

Release checks cover all six games under LuaJIT and Lua 5.4, native battle events, full-bag delivery, save/Continue, progression locks, prior-release comparisons and actual menu/overlay renders. These are automated checks, not a physical Android playthrough. Safe certifies the authored access model with manageable battles and resources; Chaos may be unbeatable. See `docs/AUDIT-1.11.0.md`.
