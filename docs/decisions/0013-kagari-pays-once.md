# 0013: Kagari pays once, in line with depth; a home opens when its sleeper wakes

**Status**: accepted, 2026-10-28 (decided by Claude on the owner's delegation).

**Context**: making Kagari "give more to do" (task_377) suggested a garden bringing a small
reward. A recurring village income (a daily harvest, a gift every fictional day) would pay souls
for time spent outside the descents, and in the canon souls are Kagari's people brought back from
the Well: a garden cannot grow them. The homes, meanwhile, were facades that could never be
entered (task_383).

**Decision**:
- A village request pays its souls **once**, when returned. Nothing in Kagari pays souls, items,
  statistics or consumables again or over time; restorations are bought once and change only the
  village (the services' existing rule).
- Each request after the first waits for the one before, sends the hero **deeper** and pays **at
  least as much, at most 30 souls** (15 at floor 2, 20 at floor 4, 25 at floor 5 today).
- A sleeper's home stands overgrown and **sealed** until its quest is returned; then the same house
  from the pack stands in its place and opens (`VillagePropDef.shown_after`,
  `VillageInteriorDef.opens_after`).

**Consequences**: a new kind of village reward (a daily gift, a harvest) needs a new decision.
Checked by `unit.village` (`_test_sequence`: the chain's order, depth and rewards) and
`title.village` (a sleeping home cannot be entered; a woken one opens with its facade).
