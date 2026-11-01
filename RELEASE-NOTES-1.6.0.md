# Universal Randomizer 1.6.0 — Clear setup, wild modes and Random Start

Update through the launcher and fully restart the game. Start a new run to select the new wild-encounter settings; ongoing runs retain their existing encounter tables.

- Modern 640x360 setup: separate setting/value and explanation panels, controlled Up/Down navigation and Left/Right adjustment, clear action hints and confirmation before playing vanilla.
- Every setting has a description. Long explanations and errors wrap and scroll automatically; SELECT focuses the guide for manual Up/Down scrolling, Left/Right top/end, and B to return.
- Wild encounters > Wild Pokemon explicitly offers Balanced or Truly random. Truly random permits fully evolved native Pokemon at low levels, ignores the wild BST limit and disables forced wild evolution. Progression SAFE/CHAOS and legendaries remain separate choices.
- Fixes Gen 2 Random Start with unchanged starters and a cold Continue before leaving Elm's Lab. Only the real exterior lab exit consumes the portal.
- Explains Gen 1's native handoff: return Oak's Parcel for the Pokedex, then leave the lab. A reminder after the first lab exit and live run-status information make the wait visible.
- Keeps native sprites/rules, logical keys/HMs, local respawn, guard removal, BST matching, safe marts and Untamed support.

Automated tests cover all six games, both starter choices, saved portal state, unrestricted early-route species, menu input, scrolling, progression and Untamed. Complete packaged suites run under LuaJIT and Lua 5.4; the real menu is rendered with LOVE for layout/font bounds. No full Android/ROM playthrough was performed.

Saves with unsupported expanded content still need 1.4.2. They are protected before Continue adopts them. Launcher compatibility remains >=0.2.18 <1.0.0; Crystal requires 0.2.24+.
