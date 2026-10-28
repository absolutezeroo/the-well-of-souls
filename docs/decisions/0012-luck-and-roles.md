# 0012: Engineered luck and declared roles

**Status**: accepted, 2026-10-28 (decided by Claude on the owner's delegation).

**Decision**:
- **Bad-luck protection**: after a streak of drops without a Rare or better item, the chance of
  one grows until it comes.
- **A heal before every boss**: the boss floor's starting room holds a healing spring on every
  difficulty.
- **No repeats in a run**: floor events, curses, encounters, pacts and trials are drawn without
  replacement while others remain.
- Every perk, relic and affix declares a **role** (`staple` or `build_around`). Force, Precision,
  Fortune and War Banner stay outside the families as staples (docs/design/builds.md); themed
  affixes join their element's family.
- **Floor pacing**: monsters in a room follow its floor area; at most 3 fight rooms in a row on
  the way to the stairs; at least one treasure per floor.
