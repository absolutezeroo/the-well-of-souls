# 0008: The fairness contract

**Status**: accepted, 2026-10-28 (decided by Claude on the owner's delegation; numbers to tune by
playing).

**Context**: 18 of 49 monsters wound up in under 0.4 s on Keeper (bats 0.2 s from floor 1), all
bosses fell under 0.4 s in their last phase, Nightmare+10 reached 0.13 s, volleys had no warning
and no attack had a warning sound. Damage per hit was already within budget.

**Decision**:
- A monster attack that hurts winds up at least **0.4 s**, a boss attack at least **0.5 s**,
  shockwaves, delayed blasts and traps at least **0.4 s** of visible warning, **after** every
  difficulty, ascension and phase multiplier (difficulty may lengthen, never shorten below).
- Every wind-up has at least two channels: the pose and red ground mark it already has, plus a
  short **warning sound**. The ground mark covers the real area and lasts until the hit.
- Damage budget on Keeper for the expected hero: an ordinary hit at most 20 % of max Health, a
  boss hit at most 30 % (already held; now a test).
- Off-screen threats about to fire get an edge marker.

**Consequences**: the floors live in data and are applied in one place; a test walks every
monster x difficulty x phase. Harder modes find their challenge in numbers, density and
patterns, not in warnings too short to react to.
