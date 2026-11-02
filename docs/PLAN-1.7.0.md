# Gen 1 world shuffle implementation

Authorized scope: Red/Blue/Yellow only. Keep Gold/Silver/Crystal generation,
configuration, runtime hooks and saved worlds on their released behavior.

- Independent Off/Safe/Chaos leader, gym entrance and dungeon entrance controls.
- Native leader identities/art/teams; reward/story ownership stays with the
  original gym check. Badges can follow the shuffled leader or shuffle separately.
- Separate or mixed entrance pools; real paired exits and whole double doors.
- Joint item/badge/entrance replay, source access gates, dungeon traversal gates,
  consumed quest capabilities, endgame access and a way back out.
- Deterministic, frame-staged validation with at most 50 attempts; constructive
  layouts on every attempt, never bypass validation or silently disable selected modes.
  Chaos is explicitly unchecked. Missing portal/roster data fails preflight; other
  unsupported data or impossible constraints fail closed during validation.
- Discovered-entrance journal, factual progression tracker, area/exact hints,
  always-present bogus/joke rumors, optional one-time trainer/capture rewards.
- Save all new world mappings/claims/discovery; no reroll on Continue.
- Native hook/VM regression tests, negative lock controls, R/B/Y option and start
  corpus, frozen Gen 2 snapshots, menu rendering and launcher package checks.

The structural proof assumes winnable combat and sufficient renewable money.
It cannot certify player decisions, arbitrary quest mods or unmodeled ROM data.
Do not label an unchecked Chaos seed as beatable.
