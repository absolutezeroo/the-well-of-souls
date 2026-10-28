# 0001: A real-time action roguelike, nothing else

**Status**: accepted, 2026-10-26.

**Context**: an agent turned the game into a persistent RPG campaign (open world, regions,
campaign saves) before the owner had decided death, character count or the roguelike's future.
It was reverted the same day; the prototype is archived (docs/rpg-archive.md).

**Decision**: this repository is a real-time action roguelike: runs, floors, death, souls, the
hub of Kagari between descents. A future RPG is a separate project.

**Consequences**: never add or switch to another genre, mode or core loop, and never change the
run's structure without a new decision. Checked: `unit.roguelike_entry` (F5 launches the title and
descent flow).
