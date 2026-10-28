# 0016: A monster's tempo is kept under the wind-up floors

**Status**: accepted, 2026-10-28 (decided by Claude on the owner's delegation; follows
[0008](0008-fairness-contract.md): "harder modes find their challenge in numbers, density and
patterns").

**Context**: the floors of 0008 made every short wind-up longer and added that time to the
monster's cycle: a bat bit every 1.3 s instead of 1.1, a boss's last phase lost the rhythm its
multipliers gave it, Nightmare (x0.7 wind-ups) slowed everything held at the floor. The
fastest monsters, the bosses' last phases and Nightmare+10 got easier for a reason that is not
readability.

**Decision**: what a floor adds to a monster's wind-up or cast comes off the wait before its next
blow or that skill (`CombatRulesDef.floor_tempo_kept`, 1: all of it; never below the blow's
recovery, the hero's opening after it). The warning is longer, the rhythm is the one its data,
the difficulty and its phase give it.

**Consequences**: tuning a monster's pace means its cooldown and recovery, never a wind-up under
the floor. `game.fairness` checks a rat's wait after a bite; the balance log (2026-10-28) has the
measures.
