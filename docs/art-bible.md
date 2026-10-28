# Art bible

How Le Puits des Âmes looks, and the rules that keep it one game. **Binding** for every change
to art, levels, the village and the interface, by people and by AI agents alike. Effects have
their own, more detailed guide, [vfx.md](vfx.md): this page extends its grid rules to all the
world art and does not repeat them.

The rules marked **checked** fail a test or `tools/design/check.py` (run by
`python3 tools/run_tests.py`); the others are checked by looking (see the end of this page). A
rule's number is either from a cited source, from the project's own settings, or a starting
value set by the owner: never "fix" a number that is not wrong by these rules.

The research behind this page (map and UI design, game feel, art direction, the other pillars,
how to keep AI agents on course), with its sources, is summarised in the owner's report "Bible
de design et règles IA" (October 2026). Binding pieces of it live here and in:
[design/village.md "Placement rules"](design/village.md#placement-rules),
[design/interface.md "One skin"](design/interface.md#one-skin-binding),
[design/presentation.md "Feel limits"](design/presentation.md#feel-limits),
[design/pillars.md](design/pillars.md), and [decisions/](decisions/README.md).

## Sources

**One world pack, one UI skin. Never import another pack's art** ([decision 0002](decisions/0002-one-art-source.md)).

| What | Comes from | Licence |
|---|---|---|
| World art: tiles, props, characters, monsters, bosses, items, weapons, world effects | **Ninja Adventure** by Pixel-boy and AAA ([itch.io](https://pixel-boy.itch.io/ninja-adventure-asset-pack)), copied unchanged or derived on its colours | CC0 |
| Window skin: wooden boards, gold border, ribbon, insets, slots | **Kenney** Pixel UI Pack and Fantasy UI Borders (`assets/ui/rpg/`) | CC0 |
| Icons, emotes, small UI pieces, wood widgets | Ninja Adventure and its Godot example project | CC0 |
| Font | Pixel Operator (`assets/fonts/`) | CC0 |
| Sound and music | Ninja Adventure, Kenney Impact Sounds (each folder's `CREDITS.txt`) | CC0 |

Every file under `assets/` is covered by `REUSE.toml` (source, licence, what was changed): a new
file in a new place fails the check until its source is recorded, and a new source or licence is
the owner's decision. The full pack is not in the repository (89 MB with audio): download it
from itch.io ("Ninja Adventure - Asset Pack.zip"), extract it outside the project, and copy in
**only the sheets you use**, unchanged.

Which pack sheet each project atlas is (byte-identical unless said):

| Project file | Pack file (`Ninja Adventure - Asset Pack/`) |
|---|---|
| `assets/tiles/floor.png` | `Backgrounds/Tilesets/TilesetFloor.png` (grass, dirt and sand with autotile edges) |
| `assets/tiles/floor_detail.png` | `Backgrounds/Tilesets/TilesetFloorDetail.png` |
| `assets/tiles/house.png` | `Backgrounds/Tilesets/TilesetHouse.png` (houses, shops, temple, torii, statues, banners) |
| `assets/tiles/interior_floor.png` | `Backgrounds/Tilesets/Interior/TilesetInteriorFloor.png` |
| `assets/tiles/interior_wall.png` | `Backgrounds/Tilesets/Interior/TilesetWallSimple.png` |
| `assets/tiles/relief.png`, `relief_detail.png` | `Backgrounds/Tilesets/TilesetRelief.png`, `TilesetReliefDetail.png` |
| `assets/tiles/desert.png`, `dungeon.png` | `Backgrounds/Tilesets/TilesetDesert.png`, `TilesetDungeon.png` |
| `assets/tiles/nature.png`, `ruins.png` | `Backgrounds/Tilesets/TilesetNature.png`, `TilesetVillageAbandoned.png` (same layout, retouched for the game) |
| `assets/tiles/furniture.png` | the pack's interior furniture (barrels, crates, sacks, washing line, hay), from an earlier version of the pack |
| water pools, `assets/tiles/ceiling/*` | drawn for the game from the biome tilesets, on the world palette |
| `assets/props/well.png` | `Backgrounds/Tilesets/TilesetDesert.png`, the well at (0, 48), recoloured colour for colour onto the grey stone of TilesetHouse's grey statues (the pack's own sand-to-grey twins) |
| `assets/characters/**`, `assets/items/**`, `assets/weapons/**` | `Actor/`, `Items/` (most unchanged; hero wear, runes, fragments and new bosses drawn for the game on the pack's colours) |

Before anything else, **look in the pack**: it has 45+ characters, 20+ monsters, houses, shops,
temples, statues, banners, furniture, interiors, animated flags, flowers, water and animals.

## Grid and scale

- A tile is **16 art pixels**; **1 art pixel = 2 world units**; the village's ground cell is 32
  units (`VillageGround.CELL`).
- On screen an art pixel is always a **whole number of screen pixels**: a world camera's zoom is
  its designed framing rounded down to the nearest whole size, the wider view (dungeon and
  temple: 3 at 720 lines, 4 at 1080 and on the S23, 6 at 1440, 9 at 2160; the village 6 at 1080).
  Never 4.5: columns of 4 and 5 alternate and shimmer when the view scrolls
  ([decision 0007](decisions/0007-whole-pixels-on-screen.md), `PixelGrid.camera_zoom()`).
  **Checked** (`unit.pc`).
- Pack art is shown at **scale 2**. A whole step (3 for a building that must read larger, like
  the temple) is allowed; **never 1.5, 2.5, 0.95** or any fraction to make something fit (it
  makes "mixels": pixels of different sizes side by side), not even for a moment: a rank shows
  by rim, aura and name, a hit by a one-pixel flinch, a smaller flame is a smaller piece
  ([vfx.md](vfx.md) section 1, its listed exceptions). **Checked** for the village (`unit.village`),
  bodies, ranks, props' flames, the Wyrm and plants (`unit.vfx`).
- Positions of static art on even units; **rotation 0** (pre-drawn directions only, [vfx.md](vfx.md));
  texture filter **Nearest**, no mipmaps (the project default, never overridden).
- The pack's projection: straight top-down with the front faces of walls and houses visible.
  Nothing in perspective or isometric.
- The pack's outline: a dark 1-pixel outline on characters and props; its light from above.

## Palette

- Every opaque pixel of the world art (`assets/tiles`, `props`, `characters`, `items`,
  `weapons`, `projectiles`) is a colour of `assets/palette/world.hex`: Ninja Adventure's colours
  and the project's approved recolours. **Checked**: another pack's art fails at once.
- New art is drawn or recoloured onto those colours (`tools/vfx/recolor.py`). The snapshot is
  only re-taken by the owner (`tools/design/check.py --snapshot-palette <pack folder>`).
- Effects use their element's ramp ([vfx.md](vfx.md), checked by `tools/vfx/check.py`).
- Alpha is binary (fully opaque or fully transparent), fades are dithered.

## Mood: darken with light, never by multiplying

The game is dark fantasy drawn with a bright, friendly pack. The darkness comes from **story,
sound, light and composition**, never from tinting the pack's colours
([decision 0004](decisions/0004-no-ground-tint.md)). A multiply works channel by channel: a
grass green times a warm dark tint becomes olive brown ("mud"), and the value contrast between
ground, paths and props collapses, so the scene also reads worse.

| Tool | Status |
|---|---|
| Darkness as light: `LightField` (a dark veil cut by lit areas, dithered on the grid) | **The main tool** |
| Palette-shifted variants of a tileset ("night", "crypt"), each colour one or two steps down its own ramp, on the world palette | Allowed |
| Dark-fantasy composition with pack pieces: bones, chains, cracked stone, dead trees, candles, banners, the Well's roots | Allowed |
| Dithered fog or vignette on its own `CanvasLayer` | Allowed |
| The village clock's `CanvasModulate` (day/night) | Tolerated: a gentle grade, actors and UI readable |
| A floor's screen grading (`AmbienceDef`, `screen.gdshader`) | Allowed to colour a biome, if with the theme's tint a mid-tone keeps every channel ≥ 0.6 ([decision 0009](decisions/0009-world-tints.md)). **Checked** (`unit.vfx`, "tints") |
| `modulate`/`self_modulate`/a tint on ground tiles, per room, on a dungeon theme (`DungeonTheme.tint`) or on a village prop | **Forbidden** beyond a light, neutral dim: every channel ≥ 0.75 and within 0.12 of each other; none at all on Kagari's props. **Checked** for the village ground, room floors and props (`unit.village`) and the dungeon themes (`unit.vfx`) |
| A narrative exception listed by [decision 0009](decisions/0009-world-tints.md): the Threshold, the Deeps, the Well's Bottom, the Blood Moon, curses | May go further, flagged in its data (`narrative_exception` on the theme or the mood); the hero, threats and telegraphs still read in the greyscale capture |

**Readability is value, not colour**: look at the greyscale capture. Ground is the least
contrasted layer, obstacles in between, interactive things, NPCs and threats the most. A
decoration is never brighter or more saturated than a chest, an NPC or a door near it.

**Colour roles** (reserved, and always doubled by a shape or an icon): danger is warm red-orange
on telegraphs and outlines (`TelegraphView`); rarity follows its fixed ramp (`ItemLook`);
interactive things stand out from the decor; souls are the Well's cold light.

## Composing a scene

- Calm base ground (one or two plain variants), detail on edges and in a few detail tiles
  (flowers, stones, cracks), never in regular rows (`VillageGround` hashes each cell).
- One landmark per screen. At most three families of props per room, all of the place's biome.
- Every prop has a reason to be there: see [design/village.md "Placement rules"](design/village.md#placement-rules)
  for the village and [design/dungeon.md](design/dungeon.md) for floors.
- Never resize a prop to fill a space: choose another piece or combine several.

## Import or reject: a grid, not a taste

| The candidate asset | Decision |
|---|---|
| Another pixel size, or only usable at a non-whole scale | Reject |
| Another projection (strict top-down, isometric, perspective) | Reject |
| No outline, or an anti-aliased one, where the pack has a dark 1-pixel outline | Reject |
| Much more detail, shades or dithering than the tiles around it | Reject |
| Light baked from another direction | Reject |
| A licence other than CC0 without the owner's written approval | Reject |
| Only its colours differ | Recolour onto the world palette, retouch by hand, then run the checks |

Order of preference: a Ninja Adventure piece already in `assets/`; one from the pack; a
combination or retouch of pack pieces; new 16-pixel art drawn (or generated from pack sprites as
references) on the world palette and cleaned by hand; **never** a third-party pack of another
style. The white-marble Craftpix temple of October 2026 failed four of these rows at once: no
recolouring could have saved it.

## Before adding or using an asset

A "no" means: stop, and ask the owner (AGENTS.md "Ask the owner first").

1. Nothing already in `assets/` or the pack does the job.
2. Source known, licence CC0, `REUSE.toml` updated in the same commit (**checked**).
3. Same family: world art is Ninja Adventure, UI is the Kenney skin.
4. 16-pixel density, scale 2 (or a whole step), rotation 0, Nearest.
5. Every opaque pixel in the world palette, binary alpha (**checked**).
6. Same projection, outline and light as the pack (look at the zoomed capture).
7. Not more detailed than its neighbours.
8. Placed beside the hero and a door: plausible proportions.
9. No new tint on world art (**checked** for the village and the dungeon's themes).
10. Greyscale capture: hero, monsters, telegraphs and interactive things still stand out.
11. Captures before/after attached to the roadmap card, with what could not be checked.

## Check with your eyes

Tests do not see the game. Every visual change ends with captures:

```
python3 tools/design/capture.py            # village, village map, temple, a conversation
xvfb-run -a godot --rendering-driver opengl3 --resolution 1540x720 res://tools/levels/level_shots.tscn -- <outdir> <tag> <plan>   # dungeon floors
```

`capture.py` writes each shot at 2340x1080 (the phone), 1920x1080 and 1280x720, with a ×4 zoom
of the centre (to see the pixel grid: no mixels, no blur) and a greyscale copy (to see
readability). Compare with the previous captures, side by side with the existing art, and attach
them to the roadmap card. A visual card ends in `review`, never `done`: the owner judges on the
phone.

## Do / don't

| Do | Don't |
|---|---|
| Look in `assets/` and the Ninja Adventure pack first | Import a pack "because it has the right object" |
| Show art at scale 2 on even positions | Scale a sprite to 1.5 or 2.5 to fit |
| Make mood with `LightField`, recoloured tilesets, dithered fog | Multiply ground tiles by a dark colour |
| Record source and licence in `REUSE.toml` in the same commit | Add a PNG without its source |
| Attach captures (1:1, zoomed, grey) | Say "done" because the tests pass |
| Keep decoration duller than interactive things | Make a decorative prop brighter than a chest or an NPC |
| Give every prop an owner and a reason | Scatter props "to fill" |
