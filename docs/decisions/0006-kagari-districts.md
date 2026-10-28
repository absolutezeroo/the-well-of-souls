# 0006: Kagari by districts

**Status**: accepted, 2026-10-27.

**Context**: the village was first empty, then cramped, then its houses and props were placed
wherever there was room, with no logic.

**Decision**: Kagari is a 1440x960 clearing laid out by districts (docs/design/village.md "The
layout of Kagari"): the temple north, the Well's square in the centre, the market west, the
memorial east, the sleeping homes north-west and north-east, the cottages south, the forest
around; props follow "Placement rules".

**Consequences**: moving a landmark or a district needs a new decision; props get an owner.
Checked: `VillageTests._test_layout_rules`.
