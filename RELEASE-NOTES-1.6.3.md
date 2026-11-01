# Universal Randomizer 1.6.3 — Normal-start validation fix

Crystal could repeatedly reject a new run with `key/HM logic: native item/badge route is unreachable`. SAFE badges were using an unchecked shuffle whenever Random Start was off, putting required badges behind their own progression gates. This update fixes that path for all six supported games.

- **Badges: Safe** checks the native item/badge route even with Random Start off. It accepts only safe swaps, preserving early required badges while randomizing the remaining valid choices. Field items, gifts, HMs and keys still use the selected randomization settings and reachability checks.
- **Badges: Chaos** combined with SAFE key/HM randomization now gives a specific preflight explanation. Choose Vanilla/Safe badges, or Chaos progression safety for intentionally unchecked placement.
- Validation errors stay on the Validate/Retry row and remain scrollable. Selecting another section shows its own explanation instead of the stale error.
- Existing saves retain their original badge/item world on Continue. New setup uses the fix even with older saved preferences. Logic Random Start retains its authored escape proofs and badge assignments.
- The Type Bias STAB fix, ordinary 65% matching-type / 35% full-pool rolls, native Pokemon/rules/sprites, and Untamed compatibility remain included.

Update through the launcher, fully restart, then validate the new run again. For checked item progression, keep Progression safety on SAFE and choose Vanilla or Safe badges.

Regression coverage reproduces the video's Crystal error, then checks 288 ordinary-start field/gift combinations and 72 authored-graph runs across all six games, badge-only runs, explicit CHAOS, and old/new cold Continue. The packaged mod also runs the existing progression, Random Start, native content, Type Bias, Untamed, wild-mode and menu tests under LuaJIT and Lua 5.4. Twelve actual LOVE menu views include the failure screen and restored section guide. No full Android/ROM playthrough was performed.

Engine compatibility remains `>=0.2.18 <1.0.0`; Crystal requires launcher 0.2.24+.
