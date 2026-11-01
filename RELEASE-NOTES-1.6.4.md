# Universal Randomizer 1.6.4 — Field-item setting cycling fix

Logical random could disappear after the first lap through Field items. Visiting Chaos changed Progression safety to CHAOS, and that stale value immediately replaced Logical random with Chaos on later laps.

- Logical random remains selectable on every complete cycle with A, left or right. Selecting it restores SAFE progression safety; selecting Chaos enables CHAOS.
- With Random Start off, all five field-item modes remain available after wrapping and reopening the menu.
- With Logic Random Start, the row cycles between its two supported modes, Logical random and Chaos. Turning Random Start off restores the ordinary item choices.
- Selecting Logic Random Start explicitly enables SAFE progression, Safe badges and logical key/HM placement. Subsequent explicit safety changes still update the graph mode consistently.
- The scrolling guides explain these setting interactions. Existing saves and seed/item-placement algorithms are unchanged. The 1.6.3 badge-validation fix and Type Bias STAB fixes remain included.

Update through the launcher and fully restart once to load the update. Afterward, cycling through settings does not require restarting the app to restore Logical random.

Regression tests reproduce the second-lap failure, then exercise repeated A/left/right cycles in all six games, both initial safety choices, menu re-entry, Logic Random Start and explicit safety changes. Tests run under LuaJIT and Lua 5.4; fourteen actual LOVE menu views include Logical random after a full lap and its scrolling guide. The release workflow also runs the complete packaged-mod regression suite. No full Android/ROM playthrough was performed.

Engine compatibility remains `>=0.2.18 <1.0.0`; Crystal requires launcher 0.2.24+.
