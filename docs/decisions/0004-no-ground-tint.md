# 0004: Never tint the ground

**Status**: accepted, 2026-10-27.

**Context**: the village's grass was drawn under a dark multiply (0.5, 0.58, 0.57) and read as
brown mud; the paths and props lost their contrast with it.

**Decision**: darkness and mood come from light (LightField), palette-shifted tilesets, dithered
fog and composition, never from multiplying the pack's colours (docs/art-bible.md "Mood").

**Consequences**: a ground or room-floor tint keeps every channel at 0.75 or more, within 0.12 of
each other. Checked: `VillageTests._test_layout_rules`.
