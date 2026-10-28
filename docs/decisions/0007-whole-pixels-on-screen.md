# 0007: Whole screen pixels for every art pixel

**Status**: accepted, 2026-10-28 (decided by Claude on the owner's delegation, after the audit;
the owner may replace it).

**Context**: at x1.5 canvas scale (the S23, 1080p) the dungeon and the temple's camera zoom 1.5
drew one art pixel on 4.5 screen pixels: columns of 4 and 5 alternate and shimmer when scrolling
(measured: 37 % and 38 % of runs). Elites were scaled 1.15-1.45, hits squashed x1.25.

**Decision**: the world camera's zoom is chosen so that screen pixels per art pixel
(2 x zoom x canvas scale) is a **whole number**, rounding **down** from the designed framing
(the wider view: more of the fight visible). Dungeon and temple: 3 screen pixels per art pixel
at 720 lines, 4 at 1080 (S23), 6 at 1440, 9 at 2160; the village keeps its exact 6 at 1080.
Pack art is never drawn at a fractional scale: ranks show by outline, aura and name, not size;
hit reactions use pre-drawn frames or a one-art-pixel offset, not a squash.

**Consequences**: a test checks the zoom at common resolutions and that no rig or prop is scaled
by a fraction (docs/art-bible.md "Grid and scale").
