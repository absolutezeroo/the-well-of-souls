# Mistakes not to repeat

Each line: what an AI agent did, and what now stops it. When a mistake gets through anyway, the
fix is a new check (a gap in the enforcement), and a line here. Read this before starting.

| When | What went wrong | What stops it now |
|---|---|---|
| 2026-10-26 | The game was turned into an RPG campaign before the owner decided | [decision 0001](decisions/0001-roguelike-only.md), AGENTS.md "Ask the owner first", `unit.roguelike_entry` |
| 2026-10-26 | A Craftpix pack (other palette, projection and licence) was imported for the temple | [0002](decisions/0002-one-art-source.md), `tools/design/check.py` (REUSE.toml provenance, world palette) |
| 2026-10-27 | Village conversations got white frames off the UI skin | [0003](decisions/0003-one-ui-skin.md), `tools/design/check.py` (no StyleBox outside src/ui/common/) |
| 2026-10-27 | The grass was multiplied by a dark tint and read as mud | [0004](decisions/0004-no-ground-tint.md), `VillageTests._test_layout_rules` |
| 2026-10-27 | Village houses and props were placed wherever there was room | [0006](decisions/0006-kagari-districts.md), docs/design/village.md "Placement rules", `VillageTests._test_layout_rules` |
| 2026-10-27 | Visual work was called done because the tests passed | AGENTS.md hard rule 8: captures (`tools/design/capture.py`), visual cards stop in `review` |
| 2026-10-25 | Several agents gave new roadmap cards the same ids | Read `next_id` just before writing; renumber when merging branches |
