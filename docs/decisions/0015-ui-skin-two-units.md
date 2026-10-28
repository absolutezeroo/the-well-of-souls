# 0015: The UI skin at 2 units per art pixel

**Status**: accepted, 2026-10-28 (decided by Claude on the owner's delegation; follows
[0007](0007-whole-pixels-on-screen.md) for the interface).

**Context**: the Kenney skin and the wood widgets came as 16-pixel art enlarged x3: 3 UI units per
art pixel, so 4.5 screen pixels on the S23's x1.5 canvas (measured on the pause dialog's border:
runs of 4 and 5 screen pixels, 22 % and 31 %). The HUD's 32-pixel spheres were stretched to their
touch circles (6.75 screen pixels a pixel for the attack button, 4.5 for a skill). The interface
page kept this as a written exception until "an art decision" chose 2 or 4 units per pixel.

**Decision**: the skin is stored at **2 units per art pixel** (the pack's x3 pieces taken back to
their pixels and doubled, nothing redrawn), the grid of the font and of the world's art: whole on
every canvas scale the game uses (x1, x1.5, x2, x2.5, x3). 4 units would have made every frame a
third bigger and eaten the phone's room. Nine-patch margins count whole art pixels; layouts keep
their sizes (content margins unchanged). The UI's own pictures (round buttons, icons, codex
previews) are drawn as big as their room allows with whole screen pixels per art pixel, rounded
down like the cameras (`PixelGrid.art_scale()`); a touch area never shrinks with its art.

**Consequences**: no x3 texture in assets/ui/rpg/ or assets/ui/wood/ and no odd skin margin
(`PcTests._test_skin_grid()`); round buttons on whole screen pixels at every scale and size
(`_test_round_buttons_whole()`); `tools/ui/rescale_skin.py --check`. A new skin piece is stored
at x2.
