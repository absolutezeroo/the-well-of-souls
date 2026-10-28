# Visual effects: the style guide

How every effect in the Well is drawn, so that frost reads as frost wherever it comes from and a
spark never looks pasted onto the art. Read this before making or fixing an effect; the
`vfx` skill (`.claude/skills/vfx/`) walks through the work step by step.

The games this guide learns from (Dead Cells, Blasphemous, Hyper Light Drifter, Enter the
Gungeon) published no VFX bible. Their coherence comes from one constraint held without
exception: **every effect is born at the game's resolution and never rescaled**. Ours is: one
art pixel is 2 world units, and every effect lives on that grid, in its element's ramp, with
its element's shapes.

## 1. The pixel grid

The art is 16x16 pixel art drawn at 2x (`ActorRig`'s Visual node, scale 2): **1 art pixel =
2 world units**, and on screen always a **whole number of screen pixels**: in the dungeon 3 at
720 lines, 4 at 1080 (the phone), 6 at 1440, 9 at 2160; 6 in the village at 1080 (the camera's
zoom is made whole by `PixelGrid.camera_zoom()`, [decision 0007](decisions/0007-whole-pixels-on-screen.md)).
An effect whose pixels are smaller
(a "mixel"), stretched by 6.9x, or turned 37 degrees is a different game pasted over ours.

- **Positions and sizes snap to 2 units.** `PixelDraw.snap(v)`, `PixelDraw.snap_length(r)`.
- **Sheets are drawn at whole, even sizes**: `texel` 2 for a sheet authored at one art pixel per
  texel (all of ours). Never 0.4x, 0.95x, 2.5x, 6.875x. `SheetVfx` snaps any wanted size to the
  nearest even one (`PixelDraw.sheet_scale`); that is a safety net, not a design: 4x and 6x
  are chunky. A big effect is **composed** of many pieces at 2x (`ComposedVfx`, a nova of 30
  crystals) or **authored bigger**, never stretched.
- **No free rotation of pixel art.** A round thing (an orb, a spinning star, a ring) is drawn
  as it is. A long thing that points somewhere (a shard, an arrow) is **drawn in 16 directions**
  (`VfxSheetDef.Orient.ROWS`: the frost shard), or at worst turned to the nearest of 16 angles
  (`SNAPPED`: old arrows and slashes). Never `rotation = direction.angle()`.
- **No fractional scale of pack art** ([decision 0007](decisions/0007-whole-pixels-on-screen.md)):
  bodies, props and their flames stay at the art's 2x. A rank shows by its rim, aura and name,
  never by a bigger body (`MonsterRankDef.radius_multiplier` widens the gameplay body only); a
  hit drops the body one art pixel for 0.12 s (`ActorRig.FLINCH_TIME`), never a squash; a
  candle's flame is a smaller particle scene, never a scaled one; the Wyrm's wings fold by whole
  rows of their art (rows left out), its tail turns by quarter turns only; a plant leans by
  moving each row of its art by whole pixels (`DecorLayer.row_shift`), never a skew; a body
  without death frames falls over by a quarter turn in one step. Checked by `unit.vfx`
  ("whole scales"). **Exceptions**, transitions of half a second or less where the body leaves
  the world and the pack has no frames for it: a fall into a hole (`Actor`, shrinks and spins
  away), the hero's soul sinking at the Threshold (`Threshold._sink_soul`), a body drawn into a
  risen boss's mouth (`BossArena`). They also fade by alpha; redrawing them as dithered
  dissolves is on the roadmap.
- **A melee blow is drawn in the body's four directions.** Bodies, armor and the weapon in hand
  exist facing down, up, left and right only, so everything drawn for a melee blow (its arc or
  streak, a smash, a claw or bite sheet, the crescents and slams of charged blows and blade
  skills, the bits they shed, the charge's glow on a blade) is turned to the nearest of the four
  (`Blow.facing`, the same as the pose: `ActorRig.direction_name`), never to the exact aim. Its
  hit zone is swept from there to the exact aim (docs/design/builds.md, "Blows in four
  directions"). An effect that must stay at the exact aim says so in its data: an area or a
  thrust follows the facing only with `follows_facing` on (`DamageAreaEffect`,
  `DashStrikeEffect`). Shots, their trails and their launch from the hand, spells placed far off,
  spins and rushes keep the exact aim (16 directions for long things, as above).
- **No smooth shapes, no alpha gradients.** No `draw_circle`, `draw_arc`, alpha fades or
  `color.lerp` in an effect. Use stepped rings and discs of whole pixels
  (`PixelDraw.ring/disc/line/bit`) and fade by **ordered dithering** (a 4x4 Bayer matrix: each
  pixel fully there or gone): `PixelDraw.dither()` for `_draw()` code, the `dither_fade` shader
  for sprites. Alpha in a sheet is 1-bit (0 or 255).
- **Shaders and particles quantize in world space.** A shader that draws a shape (a swing, a
  telegraph, a blast) takes the art pixel its fragment falls in on the world's grid
  (`MODEL_MATRIX * VERTEX`, like `frozen_ground.gdshader`), and turns the shape with a uniform,
  never the node. A shader on a body works in the sprite's own texels instead (section 9).
  Particle scenes use `pixel_particles.gdshader` (corners snapped to the grid,
  fades dithered): even sizes in steps, no spin, `Gradient` interpolation CONSTANT.
- **Additive light only for emissive cores**, from the ramp's darker steps (it brightens without
  burning to white): glow halos (`GlowHalo`, section 5b), the level up's light. Sparks, dust,
  blood, smoke: opaque ramp colors, normal blending.

## 2. Readability (a phone screen in a busy fight)

Visual weight follows gameplay weight. From most to least contrast:

1. **The hero**: outlined, always the most readable thing.
2. **Enemy threats**: telegraphs and enemy shots. Warm "danger" rims (`TelegraphView`, the red
   warning ring of a death burst), solid edges a little larger than the hitbox. An enemy shot
   must not look like the hero's: same element, but the enemy's carries the danger language
   (warning, bigger silhouette); the hero's own effects are briefer and sparser.
3. **The hero's damage effects**: novas, shards, slashes. Short, they never hide a monster or
   a telegraph for long (Frost Nova's inner ring is sparse on purpose).
4. **Ambient**: dust, mist, wisps: the least saturated.

Shape doubles color, always: about 8% of men see red and green alike. Each element has its own
silhouette and particle shape (section 4), so a colorblind player still tells frost from storm.
No more than 3 flashes a second; one screen shake source, capped.

## 2b. Layers: under, among or over the actors

Every effect is on one of three layers (`VfxLayer`, `src/vfx/vfx_layer.gd`). Flat things on the
floor must never draw over the hero's feet, and a crystal must hide a monster standing behind it:

| Layer | What | Where it draws | Examples |
|---|---|---|---|
| `GROUND` | flat on the floor | z -1: under every actor, over the floor's marks (splats -8, footprints -5) | `Vfx.magic` sigil, `RingVfx` rings, telegraphs (`TelegraphView`, `CellWarning`), storm's crackles, poison's pool of gas (`GasPoolVfx`), mist at a body's feet, level-up rings, elite auras, afterimages |
| `STANDING` | upright, rooted on the floor | z 0 in the world's y-sorted Entities, sorted by its **base** (the bottom of its frame) | the nova pieces: frost crystals, fire licks, earth spikes, poison's trail clouds, blood jets, spirit flames, holy rays, shadow smoke, arcane runes; the ground bursting (earth's `blast`), Smite's column, Thunder's bolt, dust puffs |
| `AIR` | in flight or on a body | z 5-6: over every actor and over the floor's light | shots, impacts, hit flashes and bits, blade arcs (`SwingVfx`), bursts (a ball of fire: fire's `blast`, `BlastVfx`), beams, blood drawn into a drinker, halos (Holy Shield), the crit cross, sparks, smoke, damage numbers |

- A sheet says its layer: `VfxSheetDef.layer` (AIR when it doesn't say: shots, impacts, claws
  and halos need nothing). **A nova `piece`, a `strike` or a sigil must say GROUND or STANDING**
  (the vfx tests check every element's piece). `SheetVfx.play` / `ComposedVfx` read it; code
  that draws by hand calls `VfxLayer.apply(node, layer)`; `World.spawn_vfx` puts a standing
  effect among the actors. A plain texture played with `SheetVfx.create` is AIR unless
  `.on_layer(...)` says otherwise.
- A standing sheet's node sits at its base and draws its frame above it (`base_offset()`:
  half its height plus its `anchor`). A composed nova of standing pieces is one node per piece
  (`ComposedVfx.StandingPiece`); its wave edge and residue lie on the ground.
- GROUND and STANDING are under the floor's light (`LightField.Z` = 3), lit with the room like
  the floor and the actors. An emissive one lights itself (`VfxLayer.light_up`: a light in its
  core color while it lives), so a frost nova or a holy column keeps its colors in a dim room;
  a telegraph carries a red light (`TelegraphView.add_light`). Matter (blood, earth, steel)
  takes the room's light.
- A status on a body (`StatusFx`) is on the body (its crust, flames, bubbles sort with it); its
  mist at the feet is GROUND. The body itself is painted by its own shader (section 9).

### The ceiling: over the bodies, never hiding them

What hangs over the rooms (`CeilingLayer`, design/dungeon.md "Ceilings": roots, chains, banners,
arches) is decor, not an effect, but it is the one thing drawn **over the actors** that is not
in flight: z 2, over the Entities (z 0), under the floor's light (`LightField.Z` 3, so a dark room
darkens it like the rest) and the wall mist (4); its flat shadows lie on the floor at z -6, under
the bodies. Its rule: **no body is ever under it on screen**. `ceiling.gdshader` takes the hero
and the 15 nearest bodies in view each frame (feet, radius, height: a body is a segment from its
feet to its head) and drops every art pixel of the ceiling within `CeilingDef.clear_radius` of a
body's outline, then brings them back over `fade_band` by the 4x4 Bayer threshold of the art
pixel on the world's grid: a dithered edge, never a smooth alpha. Telegraphs and shots are not
under it (GROUND effects are under the bodies anyway; AIR ones at z 5-6 draw over it). Its art
is the pack's: one art pixel per texel at 2x, a 1-pixel dark outline, the pack's palette, on
positions snapped to 2 units (the tests check every piece).

### The hero's own effects never cover him

The hero is the most readable thing on screen (section 2), and the effects he makes himself are
the ones that would bury him: they leave from where he holds his weapon and go **behind his body
when they go north** (we see his back), **in front when they go south** (`VfxLayer.goes_behind`:
a direction whose y is below -0.2 of its length).

| Effect | Where it starts | North (back to us) | South, east, west |
|---|---|---|---|
| A shot (staff, wand, tome, bow, stars; skills' shots) | his hand (`Player.hand_point`: 6 above his center, 8 out along the aim), then 6 further | GROUND z for its first 30 units (his body's length: under every body), then over the bodies like any shot | over him (z 0, after the Entities) |
| A blade's arc, a thrust, a slash of a skill or a charged attack (`SwingVfx`), toward his pose's direction (section 1) | his chest; a thrust's streak from 12 out (`THRUST_START`) | STANDING, sorted by its origin just above his feet: behind him, over whoever stands further north | AIR |
| A hammer's smash, its matter (`Vfx.smash`) | where the head lands | STANDING (sorted by where it lands) | AIR |
| His glow while charging (`ChargeVfx`) | in his hand | behind his sprites (`VfxLayer.set_behind`) | in front of them |
| The charge's gauge, the level up's rings | at his feet | GROUND (under every body) | GROUND |
| The level up's column, Holy Shield's halo (`VfxLayer.on_body`) | around him | behind his sprites: their middle hidden by him, their sides and top shining round him | same |
| The level up's glints | at his sides (14+ out) | AIR, never over him | same |

- **Behind is tree order**: an actor draws nothing itself, its sprites are its `Rig`, a child.
  `show_behind_parent` only puts a node behind the actor's own (empty) drawing, so a column
  "behind" him was drawn over his Rig (what was still seen in front of him). `VfxLayer.on_body`
  moves a node behind before every child (the Rig first) and `is_behind_body` checks it.
- A ranged weapon plays no claw or burst over him: the shot itself is the attack (`ActorRig.play_attack`
  plays an `attack_fx` or the element's claw for melee weapons only).
- Checked in 8 directions for shots (staff, bow, stars), arcs and thrusts (katana, axe, lance,
  rapier), the glow in hand, the level up and Holy Shield (`CombatTests._test_own_effects`,
  `VfxTests._test_own_effects`).

## 3. Timing

- **The main action happens in the first quarter** of an effect's life, then it erodes. A nova
  reaches its edge in 0.12 s and lives 0.6 s.
- **An impact flash: 2-3 frames at full strength, no fade-in** (a hit has no anticipation),
  then down the ramp. `ImpactVfx.FLASH_TIME` = 2 frames.
- **Dissipation, never vanishing**: a sheet's last frame lingers and dithers away
  (`VfxSheetDef.linger`), particles go down their ramp then dither out, a shot at the end of its
  range breaks into a few bits. Nothing disappears on its last frame.
- **Telegraphs last at least 0.25 s plus the time to react** (about 15 frames + the dodge's
  start-up); they grow brighter and more solid as the hit comes, their edge is crisp.
- **A status shows exactly while it lasts**: rime grows when the chill lands and breaks into
  chips when it ends.
- Sheets play at 12-20 fps without interpolation (the hand-animated look); small motes may move
  every frame, on the grid.

## 4. Palette and elements

Each element owns **one ramp of 3-5 colors**, from a bright core to a dark edge, defined once in
`data/vfx/elements/<id>.tres` (`VfxElementDef.ramp`), plus a `residue` (what it leaves in the
air) and a `mark` (what it leaves on the floor). Everything the element draws takes these colors
only: shaders get them as uniforms (`blast.gdshader`), sprites are authored on them or painted in
them (`VfxRamp`), `_draw()` code picks steps with `element.shade(t)` (never a blend).

- **Bright core, dark edge.** The core is the rare near-white pixel of the screen; the dark edge
  outlines the effect on bright floors (the desert). **No pure white or black**, except a
  one-frame flash core. **Shadow is the one inverted**: a dark core and a bright edge, so the
  void has an identity in a world already violet and black.
- **One dominant hue per effect**, at most one secondary (a hit's sparks in what the monster is
  made of, the flash in the blow's element).
- `accent` names the ramp step used as the element's main color (lights, body tint, damage
  numbers). `Palette.FROST` and `Palette.FIRE` equal frost's and fire's accents (a test keeps
  them so).
- **Shadow and arcane are two elements.** The game has both a sorcerer's shadow (ink, the
  shadow staff, Shadow Step) and arcane magic (Arcane Bolt, the arcane synergy); arcane is a
  bright magenta magic with runes and orbits, shadow a dark smoke pulled inward.

### Element identity

| Element | Ramp (core → edge) | Shape language | Bit | Motion | Residue / mark |
|---|---|---|---|---|---|
| fire | `fff6d8 ffe18d ffad5d e46d3a 8f3e56` | licking teardrops, white-hot base, embers rising and dying | TEARDROP | RISE | smoke `3b3643` / scorch |
| frost | `ebf8ff 8feff1 79b8ce 4a72a8 2c3560` | angular faceted shards irregular in size and angle, crystals that grow and shatter, cold mist sinking. **Never a radial symmetric star** (that is a shuriken) | DIAMOND (angular chip) | FALL | mist `c8e4f0` / rime |
| water | `e3f1f5 71ddee 3da6bd 2d697b 1b3a46` | drops, splashes, ripples on the ground | DROP | FALL | spray / puddle |
| poison | `e6f7a0 9bd64a 5f9e3a 3c6644 2e2440` | bubbles that swell and pop, drips, clouds that sink and crawl | RING | SINK | murky gas `5f7160` / puddle |
| storm | `f4f0ff c9b8ff 8f73e6 4b3a99 251c4f` | electric violet-white: jagged forks of straight runs and sharp knees, flicker (1-3 frames on, a frame off with the afterglow, a second strike), never a plus | FORK | OUTWARD | none / scorch |
| holy | `fffbe8 ffe18d f1c471 bd7959 61372e` | rays, rings, columns from above, slow motes of light; the **4-point glint is holy's alone** | GLINT | FALL | none |
| shadow | `150d1f 3b2346 7a3a7e d24a86` | swirls, smoke, a ring that collapses, dithered edges, pulled inward | MOTE | CONVERGE | smoke `2a1f33` / stain |
| arcane | `ffe6fa f07ad8 b048c0 6a2a8a 2e1446` | runes, orbits, diamond glints (rhombi, hollow or filled), spirals | RUNE | ORBIT | none |
| blood | `ff9b8f e0394c a3162c 5a0a1e` | drops, spurts, ballistic arcs, stains that stay | DROP | FALL | none / stain |
| spirit | `f0fff8 b8f5dc 6fd6b4 3b8f86 234b52` | wisps, hollow rings, pale flames curling up, flicker | MOTE | RISE | ectoplasm |
| earth | `f5e6c4 d2b37d a3754e 6b5040 3b3238` | rock spikes, chunks flung on arcs, dust clouds, cracks | SQUARE | FALL | dust `c8b08a` / cracks |
| physical | `f2eaf1 c7c7c7 8c8c8c 4e484a` | steel: crescent arcs, short streaks along the blow, sparks | SQUARE | OUTWARD | none |

Mood (docs/lexicon.md): the Well is dark, so only emissive cores get the screen's rare bright,
saturated pixels; smoke, blood and ash stay in the muted ramps of the floors.

### Element kits

The kit's slots (`VfxElementDef`): `projectile` (its shot), `impact` (a shot landing), `piece`
(one piece of its novas, waves and trails, composed by `ComposedVfx`), `claw` (a creature's
blow), `blast` (its explosion, at 2x; a wider blast adds a ring of its pieces), `slow_look`
(the look of a body it slows, a `StatusLookDef`), `impact_sound`. Missing
slots fall back to code that still speaks the element (a burst in its ramp, a ring with its
bits on the rim).

| Element | Projectile | Impact | On the body | Nova / area | Telegraph | Sound family |
|---|---|---|---|---|---|---|
| fire (**done**) | `fire_bolt.png`: a white-hot ball, three tongues licking back and up, 16 directions; `fire_ray.png` for the eye beam | `fire_impact.png`: tongues out and up, flames breaking off, embers, dark smoke; `fire_blast.png` for explosions | heat crawling up the lower rim (body shader), a few `fire_flicker.png` flames and embers, a burst when it catches; killed: burnt to ash from the feet up | `fire_lick.png`: licks rising, curling, sinking to smoke, in rings, arcs (Flame Arc) and at a blast's edge | warm rim, embers creeping in | crackle (`flames`) |
| frost (**done**) | `frost_shard.png`: a faceted shard drawn in 16 directions, chips trailing | `frost_impact.png`: shards cracking outward, biggest early, chips falling, mist | rime creeping in from the edges and cold colors (body shader; heavy: a glint sweeping), two `frost_rime.png` crystals, ice chips, cold mist at the feet; killed: frozen, then shattered into pieces of its own art | `frost_crystal.png`: crystals growing from the ground in a ring, then shattering | the shared danger rim; frost chips inside | cracking ice, glassy chime |
| water | a drop (energy orb painted water) | splash, droplets, a ripple | drips (none yet) | ripples (`water_ripples.png`) | danger rim | splash |
| poison (**done**) | `poison_glob.png`: a round glob, a stubby tail and two drops sagging behind, 16 directions | `poison_splash.png`: droplets flung and falling, a cloud rising then sinking, bubbles popping, a puddle (and a puddle mark on the floor) | a splash, then a green wave up the body on each tick (body shader), bubbles (`poison_bubble.png`), a murky haze sinking at the feet; killed: melts into a puddle | one **pool of gas** on the ground (`GasPoolVfx`, `gas_pool.gdshader`): it wells out to the area's edge in its first eighth, a crisp rim of the brightest steps where the area ends (the dark edge under it where it sags), low wisps of murk drawn out sideways with the floor showing between them, bubbles (`poison_bubble.png`) swelling and popping, then it sinks and thins away (~1 s); its trails (a dash) and arcs (an area struck in front) are the same gas lying along the line or the sweep, welling out from one end to the other (`GasPoolVfx.along_line` / `along_arc`); `poison_cloud.png` lumps are left for nothing | danger rim; the pool's rim lands on the telegraph's circle | squelch, hiss |
| storm (**done**) | `storm_spark.png`: ball lightning, arcs leaping off it at uneven angles, flickering | `storm_impact.png`: forks out, off, a second strike, broken tips | a hit crackles over the body: forks on its rim for a frame or two (body shader, `crackles`); killed: a white flash, scattered in sparks | `storm_fork.png`: crackles on the ground around a ring; Thunder's `storm_bolt.png` falls from the sky on top (`DamageAreaEffect.strike`); chain lightning is a jagged `BeamVfx` | crisp flicker | crack, zap |
| holy (**done**) | none needed (no holy shot) | the hit's 4-point glints | short ray halo (none yet) | `holy_ray.png`: a sparse ring of thin shafts; Smite's `holy_column.png` falls on the target; Holy Shield's `holy_aegis.png` rises into a halo; heals and buffs draw `holy_sigil.png` (Vfx.magic, recolored for other colors) | rays converging | chime, bell |
| shadow (**done**) | `shadow_knot.png`: a dark knot, a burning broken rim, smoke curling in (all shadow shots are enemy threats) | `shadow_impact.png`: a ring collapsing inward, a puff | darkened silhouette, filaments sucked in (none yet) | `shadow_smoke.png`: smoke curling up and drawn back in (Shadow Step's trail) | the ground dims | whisper, low thrum |
| arcane (**done**) | `arcane_missile.png`: a diamond glint, three motes on a tilted orbit (behind ones darker) | `arcane_impact.png`: rune-diamonds turning outward | glyphs orbiting (none yet) | `arcane_rune.png`: glyphs lighting over the ground | runes lighting up | chime, hum |
| blood (**done**) | none (claws, spurts) | `blood_spurt.png`: a ragged splash, drops on arcs, specks (and a stain) | none (no bleed status) | `blood_jet.png`: jets out of the floor, breaking into drops, a stain (Battle Cry, a broken pact) | danger rim | wet impact |
| spirit (**done**) | `spirit_wisp.png`: a round pale head, a waving tail coming apart into motes, 16 directions | `spirit_ring.png`: a white knot, a hollow ring widening and breaking up, flames rising | `haunt` look: a pale flicker and a see-through rim (body shader), small pale flame licks (`spirit_mote.png`); killed: pale wisps rising | `spirit_flame.png`: pale flames curling up, their tops rising as motes (novas, blink trails, calls) | pale rim | sigh, chime |
| earth (**done**) | `earth_clod.png`: a lumpy clod tumbling (round: redrawn, never turned); `earth_swirl.png` for Sandstorm | `earth_impact.png`: chunks on arcs, dust rolling low; `earth_burst.png` for blasts: cracks, slabs and chunks thrown up, a wide dust cloud, cracks that stay a moment | none (sand slows without a look) | `earth_spike.png`: rock spikes thrusting up, cracking, crumbling into rubble | cracks spreading | crumble (`crumble`) |
| physical (**done**) | `arrow`, `kunai`, `spear`, the tengu's `feather` drawn in 16 rows (shurikens and coins spin as they are) | short streaks along the blow; the bits of the target's material (blood drops, bone chips, slime, sparks off armor, spirit motes, leaf chips); a crit cuts the `cutx` cross | none | steel crescents, spins and thrusts (`SlashDef` + `SwingVfx`), an enemy's with a red rim; plain rushes kick up dust | lines, cones and lanes | swish, clang |

## 5. The code

| What | Where | Use |
|---|---|---|
| `VfxElementDef` | `src/definitions/vfx/vfx_element_def.gd`, `data/vfx/elements/*.tres` | ramp, residue, mark (and `impact_mark`: the puddle or stain a landing leaves), bit, motion, emissive, kit sheets. `VfxElementDef.named(&"frost")`, `.core() .color() .edge() .shade(t)`, `or_color(element, color)` for old content |
| `VfxSheetDef` | `src/definitions/vfx/vfx_sheet_def.gd` (sub-resources of an element) | texture, frames (0 = square), orient (NONE / ROWS / SNAPPED), directions, variants, fps, loop, texel, recolor, anchor, linger. `VfxSheetDef.from_texture(tex, frames)`, `columns/cell_size/slices_evenly` (the one frame slicer) |
| `element` exports | `WeaponDef`, `ProjectileEffect`, `DamageAreaEffect` (+ `strike`: a sheet of its own at 2x on the area's middle), `DashStrikeEffect`, `DashEffect` (vanishes, a trail, appears), `HealEffect` / `BuffEffect` (the sigil's ramp; `BuffEffect.sheet` follows the user, else a ring of the element's pieces), `AllyEffect`, `SummonEffect`, `ChainLightningPassive` (a forked `BeamVfx`), `OnHitStatus.slow_element`, passives (`element`, `shard_element`, `crit_element`, `blast_element`), `DeathBurstTrait` | gameplay data points to an element instead of free colors; `HitInfo.element` carries it to the hit's flash |
| `PixelDraw` | `src/vfx/pixel_draw.gd` | `snap`, `snap_length`, `sheet_scale`, `dither`, `pixel`, `ring`, `disc`, `arc`, `line`, `polyline`, `polygon`, `bit` (an element's particle shape), `sheet` (draw a frame of a VfxSheetDef on the grid) |
| `GlowHalo`, `DistortionStamp`, `FxLook`, `ScreenEffects`, `ShaderWarmup` | `src/vfx/` | halos (`attach`, one light per glow), stamps of the one screen pass (`attach`, `of_element`), a sheet's shader (`for_sheet`, `for_piece`, `flame`, `rune`, `sprite`), the screen pass (`flash`, `of(tree)`), the warm-up (section 5b) |
| `VfxLayer` | `src/vfx/vfx_layer.gd` | `Layer.GROUND / STANDING / AIR` (section 2b), `apply(node, layer)`, `of(node)`, `light_up(node, element, reach)`; `VfxSheetDef.layer` |
| `Blow` | `src/combat/blow.gd` | a melee blow in the body's four directions: `Blow.of_weapon(origin, aim, weapon)` / `Blow.at(origin, aim, follows)`; `facing` (where everything is drawn), `aim`, `toward(point)` and `in_arc` (the zone swept to the aim), `cone` (a monster's warning) |
| `SlashDef`, `SwingVfx`, `SwingMatter` | `src/definitions/vfx/slash_def.gd`, `data/vfx/slashes/`, `src/vfx/swing_vfx.gd`, `src/vfx/swing_matter.gd` | a blade's blow drawn by `swing.gdshader`: CRESCENT / SPIN / THRUST, arc, thickness, strokes, reach_scale, jitter, `finisher` sheet; on `WeaponDef.slash`, `DamageAreaEffect.slash`, `DashStrikeEffect.slash`. `SwingVfx.slash(world, look, at, aim, reach, element, danger, second)`; an element's blow breaks into its matter (`SwingVfx.matter_of`) and sheds its bits (`SwingMatter`, section 11) |
| `ChargeVfx`, `LevelUpVfx` | `src/vfx/charge_vfx.gd`, `src/vfx/level_up_vfx.gd` | the charged attack's gauge at the feet (GROUND) and glow in hand (on the body, behind facing north); the level up's rings (GROUND), column (behind his sprites) and side glints (AIR) |
| Things in flight | `data/vfx/sheets/` (`arrow`, `kunai`, `spear`, `feather`), `tools/vfx/physical.py` | 16-row sheets: `ProjectileEffect.sheet`, `WeaponDef.projectile_sheet` (the `texture` stays the item's picture) |
| `ImpactMaterialDef` | `data/materials/` | `spark_bit`, `spark_motion`, `sparks_element()`: a hit's bits in what the target is made of (`Vfx.hit(..., material)`) |
| `VfxRamp` | `src/vfx/vfx_ramp.gd` | `recolor(texture, ramp)`: palette swap by luminance, cached (a sheet with `recolor` on is painted in its element's ramp) |
| `Vfx` | `src/vfx/vfx.gd` | `hit(..., element, material)` (a crit cuts `CRIT_CROSS`), `pop(world, at, element, radius, direction)`, `nova(world, at, radius, element)`, `arc(world, at, radius, facing, element)`, `trail(world, from, to, element)`, `dust_trail(world, from, to, duration)`, `explosion(world, at, radius, element, pieces)` |
| `SheetVfx` | `src/vfx/sheet_vfx.gd` | `play(sheet, at, direction, element)` (on the sheet's layer), `create(texture, ...)` (legacy: snapped, AIR), `.in_element(e)`, `.on_layer(l)`, lingering dither |
| `GasPoolVfx` | `src/vfx/gas_pool_vfx.gd` | `create(at, radius, element)`: a nova lying as one pool of its matter on the GROUND (an element with `pool`: poison), its `pool_bubble` welling in it; `Vfx.nova` picks it. `along_line(from, to, element, duration)` and `along_arc(at, radius, facing, element, sweep)`: the same gas along a trail or a sweep, picked by `ComposedVfx.line` / `arc` (so `Vfx.trail` and `Vfx.arc`) for such an element |
| `ComposedVfx` | `src/vfx/composed_vfx.gd` | `ring(at, radius, element)`, `arc(at, radius, facing, element)` (a sweep across the front: an area with `fx_follow_aim` and no sheet), `line(from, to, element)`: any size from pieces at 2x; standing pieces are nodes of their own among the actors (`StandingPiece`) |
| `ImpactVfx`, `RingVfx`, `BlastVfx` | `src/vfx/` | a hit's flash (`ImpactVfx.sparks`: bits only), a ring (GROUND), a burst: all in an element's ramp and bits |
| `TelegraphView` | `src/vfx/telegraph_view.gd`, `telegraph.gdshader` | CIRCLE, CONE, LINE, LANES (one per shot of a fan or ring); `show_skill(skill, angle, progress, body_radius)` picks the shape from the skill (radius, shots, dash, area) |
| Particles | `src/vfx/particles/`, `src/vfx/ambient/`, `pixel_particles.gdshader(.inc)` | materials `pixel_particles` (dither per art pixel), `_motes` (whole motes come and go), `_glow` (added light, stepped brightness); `PixelMotes` (`src/vfx/ambient/pixel_motes.gd`) simulates ambient motes by hand on the grid |
| `StatusLookDef`, `StatusFx` | `data/vfx/status_looks/`, `src/vfx/status_fx.gd` | particle, motes (EMBER, BUBBLE, CHIP), crust (rime), mist, burst, all at texel 2 in the element's ramp; `body` (HEAT, RIME, WAVE, FLICKER: what the body shader paints), `heavy_at` |
| `BodyLook`, `flash.gdshader` | `src/vfx/body_look.gd`, `assets/shaders/flash.gdshader` | the body shader (section 9): statuses, a storm hit's crackle, an elite's rim, deaths; `BodyLook.ramps()` / `row(element)`, `warm_up(parent)`; the rig's `look` |
| `RarityLookDef`, `ItemLook`, `LootShine`, `WeaponAura` | `src/definitions/items/rarity_look_def.gd`, `data/items/rarity_looks.tres`, `src/vfx/item_look.gd`, `src/entities/pickup/loot_shine.gd`, `src/vfx/weapon_aura.gd` | gear (section 10): a rarity's look on the ground, in a slot and worn (`ItemRarity.look`), the elements a weapon carries (`ItemLook.elements`, `Passive.look_element`), loot's parts on the floor, a weapon's motes; `BodyLook.follow` for a layer's own copy of the body shader |
| `DeathLookDef`, `DeathFx`, `DeathPiecesVfx` | `data/vfx/deaths/`, `src/vfx/death_fx.gd`, `src/vfx/death_pieces_vfx.gd` | a death by element (`VfxElementDef.death`, `HitInfo.element` of the killing blow, ticks included): style, timing, chunks, burst, shards, motes, piece, mark |
| Tools | `tools/vfx/` | `vfxkit.py` (palette-locked drawing), `recolor.py` (palette swap to a file), `check.py` (palette, hard alpha, whole cells), `strokes.py` (lines, jagged paths, rims, glints, rhombi, ellipses), `liquid.py` (round, wet shapes: tubes, lumps of gas, drops, bubbles, rings), one rebuildable script per kit: `frost.py`, `fire.py`, `earth.py`, `storm.py`, `holy.py`, `shadow.py`, `arcane.py`, `poison.py`, `blood.py`, `spirit.py` |

Which slow shows what: a slow carries an element (`StatusSet.apply_slow(..., element)`, frost
when none is given, none for the ground's own). Only an element with a `slow_look` shows on the
body: frost (and the cold of a frostbound floor) grows rime; sand, ink, spores and wails slow
without looking like ice.

## 5b. Shaders: light, space and screen

Shaders make what sheets can't: light around a core, bent space, motion inside a flame. They
obey the same grid as the art, so they never look like a filter laid over it.

**The grid trick.** Every effect shader takes the art pixel its fragment falls in on the
world's grid: `world = (MODEL_MATRIX * vec4(VERTEX, 0, 1)).xy` in `vertex()`, then
`cell = floor(world / 2.0)` (or the texel, `floor(UV / TEXTURE_PIXEL_SIZE)`, for a sheet at 2x).
Noise, dither, distance and rings are computed per cell, so no shader draws a pixel smaller
than the art's. Time is stepped (`stepped_time(TIME, 12.0)`): things move at the hand-animated
12-20 fps, never every frame. Colors come from the element's ramp (`uniform vec4 ramp[5]`, set
by `FxLook.five(element)`): a shader moves a pixel up or down the ramp (`ramp_index` finds a
texel's step), it never blends. Fades are ordered dithering (`bayer(cell)`); alpha is 1-bit.
In `fragment()`, `COLOR` already is the texel times the tint: use it (or `texture()` alone),
never `texture(TEXTURE, UV) * COLOR`, which squares every color (a mid step turns nearly
black: `dither_fade` did it until this pass, so every sheet was drawn darker than its ramp; the
rig's `flash.gdshader` did it too, so every body was drawn far darker than its art). To read the
texture at another texel, take the tint from `vertex()` (`varying vec4 tint; tint = COLOR;`) and
multiply by that. A vfx test scans every shader for the mistake.
The shared helpers are in `assets/shaders/fx.gdshaderinc`.

| Shader | On | Recipe | Uniforms |
|---|---|---|---|
| `glow_halo` | `GlowHalo` (projectiles' cores, braziers, campfires, a sheet's `halo`, frost glints) | two flat bands of added light (premultiplied, alpha 0) in the ramp's 0.7 step and its edge (`bright`: its 0.35 and 0.7 steps, the Maw's false sun), a checker one art pixel wide where bands meet; breathes by a pixel (12 fps) or flickers (storm) | `inner`, `outer` (radii), `inner_color`, `outer_color`, `inner_density`, `outer_density` (share of the color added), `pulse`, `strength` (0.4 on the brightest floor .. 1 in the dark), `squash` |
| `flame` | `FlameVfx` (braziers), campfires (`HeatSource`) | stepped value noise climbing the flame (texel space, 12 fps): patches a ramp step hotter or cooler, dark tips eaten away; never outside the frame's flame (copies overlap) | `ramp[5]`, `fps`, `climb`, `emissive` |
| `gas_pool` | poison's novas, trails and arcs (`GasPoolVfx`, `VfxElementDef.pool`) | per art pixel of the world (its distance from the shape's spine: the centre, a segment or an arc, `shape`; along a trail or an arc each part wells out after the one before, `sweep`): a lumpy disc growing to `radius` (ease out, the first eighth), its rim a band of the ramp's brightest steps (lit on top), the dark edge on its lower side only, a body of low wisps (noise stretched sideways, drifting at 8 fps) in the residue with patches a step greener, holes growing as it sinks, the rim breaking pixel by pixel | `ramp[5]`, `residue`, `radius`, `progress`, `seed`, `emissive`, `fps` |
| `gas` | poison's piece (`look = GAS`: its trails and arcs) | the top rim in the ramp's brightest steps (an emissive edge), murk welling a step greener, drifting noise holes the floor shows through: gas, not a bush | `ramp[5]`, `fps`, `thin`, `emissive` |
| `shimmer` | Smite's column (`look = SHIMMER`) | bands a step brighter climbing the column, one-sided edges flickering a pixel | `ramp[5]`, `band_gap`, `climb`, `fade` |
| `rune` | the holy sigil (`Vfx.magic`), arcane glyphs (`look = RUNE`, `glyph`), the pact's circle | a reveal mask: a ring drawn in a few arcs (each traced end to end, every other one the other way, in a hand's order), what is inside after, a glyph top-down, the stroke's tip in `head`; then burnt away in patches, each pixel turning to `ember` before it goes | `reveal`, `burn` (set in 24ths of a second), `order_mode`, `strokes`, `radius`, `squash`, `center`, `head`, `ember` |
| `fx_sprite` | code-drawn effects: nova pieces, shots, impacts | translucent draws dithered per art pixel; the emissive mask | `emissive` |
| `dither_fade` | `SheetVfx` (PLAIN), afterimages | as before, plus the emissive mask (blending off) | `fade`, `emissive` |
| `screen` | `ScreenEffects` (one per game) | the one screen pass, below | see below |

A sheet picks its shader with `VfxSheetDef.look` (PLAIN, SHIMMER, GAS, RUNE, FLAME) and may add
`flash_frames` (frames that flash the screen) and `halo` / `halo_at` (a glow around its core);
`FxLook.for_sheet` / `for_piece` build the material in the element's ramp.

**Light: halos and LightField.** A glow is one `GlowHalo` (the air around the core, two bands,
drawn right behind the core) plus at most one `LightSource` (the floor, lit in steps by
LightField). `GlowHalo.attach(parent, element, size, offset, pulse, light_level)` adds a light
only when the parent has none (a shot's Glow, a prop's lamp, `VfxLayer.light_up`), so nothing is
lit twice. Additive light on a bright floor washes out, so halos are sparser there
(`BRIGHT_FLOOR`, from the floor's ambient light). Only emissive elements glow. The biome's own
`bloom` is a flat rim one art pixel wide around bright pixels (the screen pass), never a blur.

**Space: the distortion pass.** Reading the screen costs a copy of it (a back-buffer copy per
canvas layer with a screen-reading item), so **only `screen.gdshader` reads the screen** (a test
checks it). Every distortion is a `DistortionStamp` (a Node2D in the group
`distortion_stamps`): `HEAT` (rows of art pixels sliding sideways above a fire, the waves
climbing, ragged edge), `COLD` (facets of 3x3 art pixels shifted a pixel through a frost
nova's front), `PULL` (rings of the picture drawn toward a shadow or arcane shot), `SHOCK` (a
blast's ring pushing outward, `ShockwaveVfx`). `ScreenEffects` gathers the stamps on screen each
frame, shockwaves first then the nearest, at most 8, and passes them as uniform arrays
(`stamps`, `stamp_info`); the shader adds their offsets per art pixel of the world (it knows the
camera: `view_origin`, `view_size`), rounds them to whole art pixels and reads the screen once.
An element says how it bends space (`VfxElementDef.distortion`: fire HEAT, frost COLD, shadow
and arcane PULL); `ComposedVfx` stamps its novas, projectiles their element's, `FlameVfx` and
campfires their heat. `DistortionStamp.attach(node, kind, size, power, seconds, offset)`.

**Screen: grading, the emissive mask, flashes.** Effects draw with blending off (they are 1-bit
anyway) and write their alpha: an emissive one writes `EMISSIVE_ALPHA` (1/3), matter 1. The
game's viewport is transparent while `ScreenEffects` lives, so anything opaque drawn over an
effect later (a monster in front of a crystal) writes 1 again. The screen pass keeps 75% of the
biome's grading, saturation and moon tint off those pixels (`emissive_keep`): frost stays cyan in
the warm ruins, fire keeps its yellows in the blue crypt. `ScreenEffects.flash(color)` lifts the
whole picture for one frame (Thunder's bolt, `flash_frames`), at most 3 a second, never when
Options > Graphics > Screen flashes is off.

**Fewer effects** drops what costs the most: no HEAT, COLD or PULL stamps (shockwaves stay), no
bloom (4 more reads of the screen per pixel), the halos' inner band only. **Warm-up:**
`ShaderWarmup` draws every shader of `FxLook.ALL` once under the world when the game starts, so
the phone compiles them then and not in the first fight; a new effect shader goes in that list.

**Cost** (measured when the pass was written, a busy fight in the crypt: 20 monsters, a ring of
fire, Thunder and a Spark Nova every half second, an explosion and an ink ring every second, a
brazier and a campfire; 1540x720). The screen used to be copied once more for every living
shockwave (each a screen-reading node of its own) and the bloom read 8 more pixels; now one copy,
at most 8 stamps, a 4-tap bloom. Software rendering (llvmpipe, so fill-bound like a phone's GPU):
before 444-490 ms a frame on average, after 255-330 ms; draw calls about the same (160-163 before,
155-178 after: halos are a quad each, alike ones share a material). Headless (scripts only):
p50 7.5-8.2 ms before, 7.7-7.9 ms after: gathering stamps and driving runes costs nothing
measurable. Not measured on the phone itself.

## 6. Adding or fixing an effect

1. **Pick the element** (section 4). Not sure? It is what the player would name it. A new
   element is a new file in `data/vfx/elements/` listed in `data/vfx/elements.tres`.
2. **Point the data at it**: `element` on the weapon, effect or passive; `slow_element` on a
   slowing `OnHitStatus`. Drop free colors and borrowed sprites (no shuriken for frost).
3. **Reuse the kit**: a shot without a texture is the element's projectile; an area without a
   sheet is its nova; a dash leaves its pieces. Only add a texture when the shot is a *thing*
   (an arrow, a coin).
4. **New art**: draw it on the ramp at 1 art pixel per texel with `tools/vfx/vfxkit.py` (or by
   hand, then `tools/vfx/recolor.py` and touch up), hard alpha, frames in a row, directions or
   variants in rows. Big effects: a piece to compose, not a big sheet to stretch.
   `python3 tools/vfx/check.py <png> <element> --cell WxH`. Commit the `.png.import` Godot makes.
5. **Wire it** as a `VfxSheetDef` sub-resource of the element (frames, orient, fps, anchor,
   linger, **layer**) or of the content; set frames explicitly for any non-square sheet.
6. **Test**: `tests/suites/vfx_tests.gd` (run by the unit suite) checks every element, every
   sheet's slicing and scale, and the frost kit; add the checks your element needs (its users
   point at it, none borrows another element's art).
7. **Look at it** (section 7) and fix until it passes the review.
8. **Docs**: the element's row here, and docs/design/presentation.md if the player sees it
   differently.

## 7. Review checklist

Screenshot it in the game at 1540x720 (the debug panel, or a probe scene in `_tool/` like the
`vfx` skill's), and a 4x nearest-neighbour crop. Then, for each frame:

- [ ] Its pixels are the size of the characters' pixels (no mixels, no 1-unit lines).
- [ ] Only its ramp's colors (+ residue): `check.py` on its sheets; no alpha gradient on screen.
- [ ] Its silhouette reads in one frame, and **reads as its element without color** (squint, or
      look at it in grey: is frost still faceted, storm still forked?).
- [ ] Nothing rotated off the 16 directions; round things not rotated at all; a melee blow's
      effects on the body's four directions, the way its pose faces (section 1).
- [ ] On its layer (section 2b): nothing flat draws over the hero's feet; an upright thing hides
      who stands behind it and is hidden by who stands in front.
- [ ] The main action is in the first quarter; the flash lasts 2-3 frames; it dissipates
      instead of vanishing.
- [ ] Its size and noise match its gameplay weight; it never hides a telegraph or an enemy shot.
- [ ] It reads on the darkest biome (the crypt) and the brightest (the desert), and keeps its
      colors under a warm grade (the ruins) if it shines.
- [ ] A shader on it moves at 12-20 fps in whole art pixels and only in its ramp; no smooth
      glow, no new screen-reading node (a distortion is a `DistortionStamp`).
- [ ] An enemy's version is told apart from the hero's at a glance.
- [ ] One dominant hue.

The small effects drawn in code keep the same rules (a unit check reads them,
`VfxTests._test_grid_rule_breaks`): a footprint is a sole of whole cells in four directions,
dithering away; an emote stands at 2x, pops one whole step (4x) for two frames, rises by art
pixels and dithers out (`dither_fade`); a damage number starts on an art pixel, rises by art
pixels and fades in three cuts (text has no dither); an arena's cell warning is a telegraph
(`TelegraphView.DANGER`, a crisp rim an art pixel thick, an on/off blink, the fill thickening in
steps); a splat dithers away and its shine is an opaque lighter step; a plain beam (a mender's)
goes down the ramp of its color (`VfxElementDef.or_color`) and dithers out.

## 8. Where each element stands

Frost is the reference kit, done in full. The foundation (grid helpers, ramps, palette swap,
slicer, element exports) serves the others; what each still needs:

- **Fire** (done, `tools/vfx/fire.py`): every fire shot, Flame Arc (licks sweeping across the
  front), Fire Touch's burning claw, the eye beam's rays, Blazing Roll, the Inferno family, the
  burn look, the campfire, flame vents and braziers (`FlameVfx`). Ghost Flame stays fire (the
  Ghost Lantern, the Ember Heart); the Soul Moth throws Soul Flames (spirit), the Gilded Moth, the Moss Heart and the Sand
  Drummer shoot their own element (holy, poison, earth; holy has no shot sheet: a dot). Left: candles
  still burn with particles; `fireball.png`, `fire_flames.png`, `flame.png` and `explosion.png`
  are unused.
- **Poison** (done, `tools/vfx/poison.py`): glob, splash with a puddle mark (`impact_mark`), gas
  cloud piece, venom fangs (16 rows), bubbles on a poisoned body, its ticks in its own green. Its
  novas are one pool of gas on the ground (`GasPoolVfx`): the ring of standing lumps read as
  bushes, lumpy, on a green floor. Its trails and arcs are that gas too, lying along the line or
  the sweep (`GasPoolVfx.along_line` / `along_arc`): `poison_cloud.png` is no longer drawn.
  Poison Spit, Venom Spit, Toxic Bloom (+fierce), Acid Spit, Poison Fang, the Jade Wyrm's Venom
  Fang, Spore Cloud and the Venomous elite all point at it. Left: no sound of its own.
- **Storm** (done): stays electric violet-white (holy owns gold); the Storm synergy, Thunder,
  its tome, Spark Wand, Spark Nova, Thunderclap, Shock Roll, Frenzy wear the storm's color.
  Thunder, Spark Wand/Nova, chain lightning (synergy, Spark Rune, Thundering), Thunderclap,
  Shock Roll and the Gale Rune are storm. A storm hit crackles over the body (section 9). Left:
  no shock status yet;
  `thunder.png` and the skill icons are unused/untouched art.
- **Holy** (done): Smite, Holy Light, Holy Shield, holy heals; `Vfx.magic` is the holy sigil
  for every heal, buff, learned skill, level up and sealed room (holy for gold, painted in the
  caller's color otherwise). `holy_circle.png`, `magic_spark.png`, `shield.png` (a flame-like
  wave) are unused; `magic_circle.png` is only the pact sigil (pact_room, 2.25x/1.5x).
  The Deeps' **Dawn Breach** (`AbyssDoor`, drawn in `_draw()`): a STANDING arch of holy's ramp
  (near-white heart, steps out to a dark torn rim that jags per row and crackles a pixel at
  10 fps), shafts leaking from its top, motes and glints drifting down (holy FALLs), a GROUND
  spill of daylight dithering out in front of it, a `GlowHalo`, and its own daylight-white
  `LightSource` (so the floor around it reads white in the Deeps' red, not as more embers). The
  arrow toward it (`AbyssHud.Arrow`) is UI: a holy wedge with a dark rim, cut in whole art pixels
  (3 interface units) at the nearest of 16 directions, circling the hero. Demons rising in the
  Deeps: shadow's pop and nova.
- **Shadow** (done): shadow_staff (Sorcerer), its Volley, the Octopus's Ink Bolt and Ink Ring,
  the Shaman's Hex Bolt fire the shadow knot; Shadow Step bursts into shadow, leaves smoke and
  its kunai land in shadow. Left: curses have no effects of their own.
- **Arcane** (done): Arcane Bolt and the Arcane synergy's ring fire the arcane missile; the
  arcane perks wear its color. Left: no arcane area or charge-up uses the rune piece yet.
- **Blood** (done, `tools/vfx/blood.py`): claws raking in three gashes (16 rows), a spurt with a
  stain, jets for its novas. Claws (spider, racoons, moles, owl), Battle Cry (`BuffEffect.element`),
  a broken pact, splats (`MonsterDef.splat_color`, `Palette.BLOOD` = its accent), the blood moon's
  ash (`PixelMotes`: grid flakes that tumble by shape), drinking blood (`BloodDrainVfx`: Vampiric
  elites and affix, Leech Rune, Vampirism, Bloodlust), Executioner's and Bloodrage's blows. No
  bleed status exists. Left: `bite` (rats, bats, skulls) is still a warm claw sheet.
- **Spirit** (done, `tools/vfx/spirit.py`): wisp, hollow ring, curling pale flame, spectral claws
  (16 rows), the `haunt` look (a wail slows with a pale flicker, never rime). Cold Touch, Wailing
  Ring (+fierce), Spirit Call (`SummonEffect.element`), Soul Ward (`AllyEffect.element`; the ward
  bubble is a flickering hollow shell with flames), the Soul Moth's Soul Flame, Blink (hero and
  monsters, `DashEffect.element`), the Threshold's sinking soul and rising spectres. Moles burrow
  instead (`burrow.tres`, earth). Left: soul wisps are drawn in code (on the grid, spirit ramp).
- **Earth / sand** (done, `tools/vfx/earth.py`): Rock Spike and Fissure paint `rock_spike.png`
  in earth at 2x, Ground Slam is a ring of spikes, Quake and Sundering Blow burst the ground,
  every boss's stomp (`Combat.shockwave`) and a trapped chest are dust and rubble (the powder
  keg stays fire), Sand Breath throws clods, the Sand Drummer a clod that slows, Sandstorm
  whirls. Left: no earth claw yet; `sandball.png` is unused.
- **Physical** (done): blades swing steel (or their element's) arcs on the grid, in the body's
  four directions (section 1); Cleave, Lash,
  Whirlwind, Flurry (its last stab the `cutx` cross), Iaido Dash, Piercing Thrust and the
  monsters' club, demon club and tengu blade are `SlashDef`s; arrows, kunai, the thrown spear
  and the Crimson Tengu's feathers are drawn in 16 rows; hits throw their material's bits.
  Shadow Step's kunai is the 16-row kunai too. Left: arrow traps turn `arrow.png` by quarter
  turns only (exact),
  the slime slam and body slam play `circularslash` unturned at 2x.
- **Everyone** (done): swings and telegraphs quantize in world space; monster shots warn with
  their lanes, dashes with their line; plain rushes leave dust and dithered afterimages in the
  dash's element; particles snap to the grid; props, pickups, auras, the pact sigil, stairs'
  seal and heat sources draw with `PixelDraw`; the trap's peek is at 2x; fog texels are art
  pixels; every effect is on a layer (section 2b). Left: sounds per element are not wired
  (`impact_sound` is empty everywhere); the actor's debug fallback body (no sprite) is smooth.
  Every element's sheets have their layer (a new sheet that says nothing is AIR: a nova piece,
  a strike or a mark must say GROUND or STANDING, the vfx tests check the pieces).
- **Light, space and screen** (done, section 5b): glow halos (shots, braziers, campfires, Smite's
  foot, Thunder's strike, frost glints), one distortion pass (heat, cold, pull, shockwaves), flame
  tongues, poison gas, Smite's shimmer, Thunder's flash, runes that draw themselves (the sigil,
  arcane glyphs, the pact's circle), the emissive mask. Left: candles, flame vents, the burn on
  bodies (the body shaders' work) and the poison puddle marks (SplatLayer) don't move yet; the
  level up's light and Holy Shield have no halo of their own.

- **Gear** (done, section 10): rarity shows on the ground (rim, glint, gold pulse, Epic's aura,
  motes and pillar of light), in slots (frames, Epic's sheen, rune gems in their element) and
  worn (a trim on the armor's hem and the weapon's outline, Epic's glint); a weapon carrying an
  element licks with it along its rim and throws its motes, in hand and at rest; the hero
  carries his weapon on his back or at his hip. Worn armor shows its affixes' marks (an element
  glittering on its trim, of Thorns' steel points); the bag's portrait is the hero's own rig,
  dressed alike (`HeroPortrait`).

- **The final fight** (the bottom of the Well, monsters.md): no new element. Marked spots on the
  ground (`GroundStrikeEffect`, `GroundStrike`) are the usual danger telegraph (`TelegraphView`,
  a filling circle with its red light, GROUND) followed by the element's nova where it lands, and
  a strike sheet when there is one: Tôma's lantern is **shadow** (the void closing in, its
  magenta edge flashed as a light: `glow`, on him as he raises it and on the spot), the Maw's
  tar lash is **earth** (the ground bursting), its False Dawn is **holy** (Smite's column falling
  on each spot), its Dead Sun's Gaze the eye beam's **fire** rays, its bite **blood**'s claw.
  The Maw's tar pool is a pre-drawn ragged puddle of art pixels with drips on the GROUND under it
  (`WeakPointTrait.draw_under`), its tentacles' cut ends sunk into it in the sheets themselves
  (each tentacle steps down to tar and dithers away on its own row). The Maw is the false sun:
  `lit_from_within` draws its body over the floor's light and the wall mist (z
  `PlateauMist.Z + 1`, under the AIR effects drawn after the actors) with a holy `GlowHalo`
  behind its mask (`bright`: its bands a step up the ramp, gold rather than brown, and wider than
  the mask, so it reads round it), and a golden `LightSource` on the floor, brighter while its jaw
  is open. (Until this pass none of it showed: the trait ran before the body existed.) Casting, it
  warns by a red rim round its silhouette (the body shader's rank rim, `MonsterDef.cast_warning`
  RIM: one art pixel, no dithered beat, none in the holes of its dithered tentacles) instead of
  the red glow every other monster takes, which turned its gold red-brown. Drawn over the actors,
  it would hide the hero standing by its tentacles: there he is drawn over it
  (`WeakPointTrait._keep_hero_in_front`). Its halo goes out once its mask has crumbled.

## 9. Shaders on bodies

A body's statuses, an elite's rim and its death are painted on the body itself by the rig's
shader (`assets/shaders/flash.gdshader`, on the `Visual` node: the body, armor, helmet and
weapon sprites share it; the hero's rare armor and his weapon wear copies that follow it, for
their trim: section 10), driven by `BodyLook` (`src/vfx/body_look.gd`, the rig's `look`).
StatusFx's flames, crystals, bubbles and mist stay as the accent; the shader is the base. One
shader for everything, flags as uniforms: each rig already had its own material (the hit
flash), so nothing about batching changes.

### The grid trick

- **Work in the sprite's texel space.** `vertex()` passes `VERTEX` (the sprite's local space:
  one unit = one texel = one art pixel, the Visual node scales it 2x) to a varying `local`;
  `floor(local)` is the art pixel a fragment is in. Noise is per texel (`hash(cell)`), dither
  is a 4x4 Bayer on the cell, heights are measured from the frame's bottom. Never `UV` noise:
  frames are AtlasTextures packed in one sheet, and UV changes with the frame.
- **Know the frame.** `frame_rect` (the shown frame's quad in local space, set on every frame
  change: `ActorRig._fit_frame`) bounds every neighbour read (`ALPHA_AT(off)`): frames are packed
  edge to edge in their sheet, and reading past the frame takes the next frame's pixels.
- **Colors are ramp steps, never blends.** `ramps` is a small texture, a row per element, its
  ramp in 5 steps core to edge (`BodyLook.ramps()`, `row(element)`; rounded to 8 bits by hand:
  `Image.set_pixel` truncates and would put 239 where the ramp says 240). A sprite color is
  repainted in an element by its brightness (`luma_step`: bright = core, the dark outline = the
  edge). Only the cold drain of a chill is a mix (toward a blue grey, in two steps).
- **Distances to the edge** are read along the four axes, up to 3-4 texels (`edge` = 1 on the
  rim): rime creeping inward, heat on the rim, a see-through rim. Outside the sprite (a texel
  touching it: `TOUCHES_BODY`): an elite's rim, storm's outer sparks; not when armor layers are
  on (a helmet's rim would cover the face: `outer_rim`).
- **Time is stepped**: `floor(TIME * 10)` for the licks of heat, 12 for flickers, 60 for a
  crackle's strikes, 24 for the frozen glint's sweep.
- **GLSL limits met on the way**: `TEXTURE` can't be passed to a function (the macros
  `ALPHA_AT`, `TOUCHES_BODY` read it inline); the node's `modulate` is applied after the
  shader, so a recolored death sets the rig's modulate white first (DeathFx), or the corpse's
  grey darkens its ramp; the room's light (LightField) is over the bodies, so near-white reads
  beige by the hero's torch: rime uses the cyan steps, the core only on its lit rim.

### Statuses (StatusLookDef.body)

| Body | Status | What the shader does |
|---|---|---|
| HEAT | burn | tongues of heat two texels wide, each its own height (changing 10 times a second), on the lower rim and dithered in the lower half: bright at the base, red at the tips; a white-hot crackle and an ember crawling up the outline now and then. No orange wash. |
| RIME | slow (frost, the cold) | colors drained toward a blue grey; rime from the edges inward, one texel deeper as the chill lasts (`chill` 0..1 over 1.2 s, jagged per texel), a lit cap on top, facet lines; the outline itself turns the ice's dark edge (on sand a pale rim made the body vanish). A slow at `heavy_at` (0.5) or more freezes: rime 3 texels deep and a glint sweeping diagonally every two seconds. |
| WAVE | poison | a sparse sickly rim; on each tick (`since_tick`) a wave rises up the body in 0.5 s: a bright crest, a dithered wake. |
| FLICKER | haunt (a wail) | the rim in the spirit's darker steps and half see-through (Bayer holes that move), the whole silhouette pale for a frame now and then (under two a second). |
| (hit) | storm (`VfxElementDef.crackles`) | for 10 frames, on, on, off, off, on...: forks of the core running down the body, the rim crackling, sparks just outside. Over the hit flash. |

Fewer effects (`Settings.fewer_effects`) turns all of these off, and the body takes the old
steady 45% tint of the status's color (`Actor._body_modulate`); a body without frames too.

### Deaths (DeathLookDef, `data/vfx/deaths/`)

The killing hit's element (`Actor.killing_element()`: `HitInfo.element`; a burn's or poison's
ticks carry theirs) picks `VfxElementDef.death`; none (a plain blow) is physical's.

| Style | Elements | Body | Off it |
|---|---|---|---|
| DISSOLVE | physical, blood | pixels gone in a random order behind a glowing edge (as before) | the body's chunks and a puff of smoke (`chunks`) |
| ASH | fire | burnt away from the feet up behind a ragged edge: core, bright, red steps; above it the body chars dark | embers rising off the front (`motes`), a scorch (`mark`) |
| SHATTER | frost | frozen from the edges in (core on the lit rim), cracks (a Voronoi of 5 texels) showing, gone at half way | `DeathPiecesVfx.shards`: the frame broken into ~a dozen pieces of its own art, painted in ice, lit top left, dark bottom right, thrown out, one bounce, lying a moment, dithered away; the frost impact |
| MELT | poison, water | each column sags toward the feet at its own pace, the base spreading; the ramp takes it from the top; dithered away | the element's puddle (`mark`) |
| SCATTER | storm, arcane | two frames of the core, then flickering in the ramp while its pixels fly apart | the element's impact (forks, rune diamonds) |
| ASCEND | holy | turned to light, lifted away from the feet up | the shaft of light (`piece`), motes rising off the front |
| IMPLODE | shadow | drawn into one point (texels sampled further out each frame), a dark inside and a bright rim, down to two dark texels | the shadow impact: a ring collapsing |
| WISP | spirit | pale, wavering and rising, dithered away from the feet first | pale flames (`piece`), motes |
| CRUMBLE | earth | turned to stone, cracking, the columns slumping, gone in dust | the earth impact: chunks and dust |

### Performance

- Plain bodies take a cheap branch (the shader as it was: one read, the flash): measured equal
  to the old shader. 30 bodies at the game's zoom, all burning, frozen and poisoned at once:
  about +2.5 ms of raster on llvmpipe (software GL, a bench of 30 bare rigs; old 2.5-3.2 ms, plain
  2.6-3.0, statuses 5.4-5.5, dying 4.8-5.2), which on a phone GPU is a few hundred thousand texel
  reads: nothing. Draw calls: unchanged (one per body, as before).
- CPU: `BodyLook.show_statuses` returns at once for a body with nothing on it; with three
  statuses about 20 us per body on a loaded desktop (it sets a uniform only when its value
  changes).
- The status particles were thinned now that the body carries the look (burn 11 flames a
  second to 4, two rime crystals instead of four, fewer bubbles and pale licks): fewer draw
  calls with a burning pack.
- `BodyLook.warm_up` draws the shader's busy path once under the floor when the world starts,
  so the Compatibility renderer compiles it while loading, not at the first burning monster.

## 10. Rarity and runes, and the weapon at rest

Loot used to look the same whatever it was: a plain katana and an Epic one with two runes were
the same sprite on the floor, on the hero and in his hand. Now an item says what it is wherever
it shows, in one language: its **rarity** is a ladder of signs (each step keeps the one below and
adds one), the **elements it carries** show as that element's kit, and the hero **carries his
weapon** when he isn't swinging it.

### Rarity (RarityLookDef)

One look per rarity in `data/items/rarity_looks.tres` (`RarityLookSet`, `ItemRarity.look(r)`),
each with a ramp written as an element's (`element`: a `VfxElementDef` sub-resource that is not
listed with the game's elements, so its halo, light, motes and the shader's steps come from the
same tools). Its accent is the rarity's color (`ItemRarity.COLORS`, a test keeps them equal).

| Rarity | Ramp (core → edge) | On the ground | In a slot | Worn (armor hem, weapon outline) |
|---|---|---|---|---|
| Common | `f6f2ea ebe6db b0aa9e 6e675f 3c3834` | plain: its shadow | plain | plain |
| Magic | `e8f3ff a8d0ff 5ea8ff 3a66c4 24306e` | a rim of its blue round the icon, a glint running over it (then 2.2 s of rest) | blue frame | blue trim |
| Rare | `fff6d8 ffe7a3 ffd166 c08a35 6a4220` | gold rim, a glint (1.6 s of rest), a gold ring lying under it and a pulse running out of it every 1.4 s (GROUND), a small light | gold frame | gold trim, a weapon's highlights gilded |
| Epic (shown as Epic; the monster rank `epic` is Fell, a different thing) | `f9e8ff e3b6ff c77dff 8a3fc4 581848` | purple rim, a glint (1.2 s of rest), an aura (a band of its dark step on the floor, its edge a step brighter, a checker only on its outer rim, breathing by a pixel; GROUND), motes rising (AIR), a halo (`GlowHalo`), a light, and a **pillar of light** 36 art pixels tall (STANDING): a near-white core, its color either side, wider at the foot, its upper half broken into dashes further and further apart and thinning to the core, a brighter stretch climbing it | purple frame and a **sheen**: a band two icon pixels wide crossing the icon on the diagonal at 20 fps, then a pause | purple trim, gilded highlights, a glint sweeping across every 2.5 s |

- The parts on the floor are `LootShine` children of the `ItemPickup`, each on its layer (the
  pillar sorts with the actors: a monster in front of it hides it). The icon's rim and glint are
  drawn by the pickup itself, on the icon's own pixels. A rune on the floor wears its element's
  rim and glint (`ItemLook.rune_element`).
- **Fewer effects** keeps what tells the rarity (the rim, the glint, the ring, the aura, the
  pillar) and drops the motes, the halo, the pillar's climbing light and the worn glint.
- **Armor affixes, worn** (`ActorRig.set_wear`, `ItemLook.elements` / `toothed`): an affix
  carrying an element (of Echoes: arcane) glitters on the piece's trim, a third of its hem
  pixels a bright step of the element's ramp changing ten times a second (the trim stays its
  rarity's around them); an affix without one may say how it looks worn
  (`ItemAffixDef.worn_teeth`: of Thorns turns the hem into steel points, every other hem pixel
  lit steel with a dark tip hanging a pixel under it: serrated in grey too). Stat affixes
  (Stalwart, of the Bear) carry nothing, like a weapon's (the rarity's trim says there are some;
  the item's card lists them). Shown on the hero and in the bag's portrait.
- Lessons: a dithered disc or a pillar faded by a Bayer pattern reads as a screen door (the
  first try); a band of one step with a checker only on its edge, and a pillar fading by whole
  rows missing, read as light. A trim on the whole rim of a worn armor painted the whole piece
  (the layers are 4-5 pixels thick): armor takes it on its **hem** only (`trim_hem`: the texel
  under it is empty: a tunic's hem, a helm's brim), weapons on their outline.

### Elements carried (ItemLook)

`ItemLook.elements(item)` is the one place that reads them, so new content shows for free, in
order: the weapon's own `element` (the Frost Staff, the Spark Wand, the Ember Tome), its runes
(`Passive.look_element()`: the passive's `element`, `blast_element`, `shard_element` or
`crit_element`; drinking blood (Lifesteal, Heal on kill, Bloodlust) is blood, Echo and Prism are
arcane), the statuses its hits leave (`on_hit`: burn is fire, poison is poison, a slow its
`slow_element` or frost), its affixes' statuses and passives. Bonuses alone (Sharp, of the Bear)
carry nothing. At most two show (`ItemLook.MOST`).

- **On the weapon** (in hand and at rest): the body shader's `imbue` paints half the pixels of
  its rim in the first element's ramp, changing ten times a second (a flicker of flame, a
  glitter of rime, storm's violet, blood's red), and `WeaponAura` throws a few motes born on the
  weapon's own pixels in each element's bit, ramp and motion: fire's teardrops rise, frost's
  chips fall, poison's rings sink, storm's forks fly out, holy's glints fall slowly, shadow's
  motes are drawn in, arcane's runes orbit, blood drops fall. Fewer effects: no motes.
- **The attacks**: every attack of a weapon carrying an element is drawn in it, section 11.
- **In a slot**: rune sockets are small gems cut in their rune's element (its color, a lit
  facet, a dark one).

### The weapon at rest

The hero (`ActorRig.carries_weapon`, `Actor._shows_gear()`: the Player) carries his weapon when
it isn't in his hand: `WeaponDef.back_sprite`, `back_kind`, `back_offset`.

- **Art**: `assets/weapons/back/<id>.png`, made by `tools/vfx/back_weapons.py` (rebuild:
  `python3 tools/vfx/back_weapons.py --preview /tmp/back_x8.png`). The hero is a 15-pixel chibi
  and a weapon in hand is about 10 pixels long, so the icons (14-23 pixels) are redrawn at that
  size in their own colors, never turned by code: a slung weapon along a 45-degree "/" diagonal
  (a profile along its length: core pixel, width, pixels across for a guard or a head, outlined
  by 4-neighbours), the end that rides over the shoulder (a hilt, an axe's or hammer's head, a
  lance's point, a staff's head) at the top right; hip things drawn as they are.
- **Where** (`GearLook._places()`, art pixels from the feet): `SLUNG` across the back, behind
  the body facing down, left and right (the top end peeking over the shoulder beside the big
  head), in front facing up (his back is to us), mirrored for up and right; `HIP` at the belt
  (the Ember Tome, shurikens, the coiled whip), in front except on the far side. Bows and staffs
  are slung. Sprites sit on whole art pixels (`centered` off, corners floored).
- **Bob**: it moves with the body's art frame by frame (the top row of the frame's art against
  the animation's first frame), so it never floats while he breathes, walks or rolls.
- **Hidden** while the weapon is in hand (the attack frames take over), while winding up and
  once dead. Monsters carry nothing (their weapons are claws and fists).
- **Draw order** in Squash: the weapon at rest, then its `WeaponAura` right after it (so motes of
  a weapon behind him are hidden by him), then Body, BodyArmor, Helmet, Weapon; facing up both
  move to the end, over the armor. No cape layer exists; a future one goes over the weapon at rest.

### On the body shader

Worn gear needs uniforms of its own while the body's statuses, flash and death stay one: the
hero's armor layers (above Common, or carrying an affix's mark) and his weapon (in hand and at rest share one material: they
never show together) wear **copies of the body shader** that follow the body's
(`BodyLook.follow(material, own_frame)`: every uniform BodyLook or the rig's flash sets is set
there too, but a weapon's `frame_rect`, which is its own sprite's). Their own uniforms: `trim`
(0 none, 1 its rim or hem in the rarity's steps, 2 and a weapon's brightest pixels gilded),
`trim_row`, `trim_hem`, `trim_sweep` (seconds between glints, 24 fps, then a pause), `imbue`,
`imbue_row` (on an armor: on its hem, a third of the pixels), `teeth`, `teeth_row` (of Thorns). Bodies keep them at 0: the cheap path tests two more uniforms. The hero draws up to
four materials instead of one (body, armor, helm, weapon): a few draw calls, for one actor.

## 11. Elemental attacks

"A katana, an axe... when I attack nothing changes. With fire, the slash should be red with
flames." Every attack of a weapon that carries an element (`ItemLook.elements`: its own
element, its runes, its affixes) is drawn **in** that element, end to end, not tinted: the
element's ramp, its shapes, its motion. Plain weapons stay steel. Monsters' blows keep their
weapon's own element.

**Which element.** The first element the weapon carries (`ItemLook.swing_element`: the weapon's
own, else in data order: runes, then statuses its hits leave, then affixes) draws the attack;
a second one (`ItemLook.second_element`) adds a few of its bits (a third of the first's). At most
two show, like the motes on the weapon (section 10).

**Arcs and thrusts** (`swing.gdshader` `matter`, from the element's bit by
`SwingVfx.matter_of`, so a new element is drawn as itself for free). The arc keeps its steel
shape (the head bright, bands down the ramp, the tail thinning) in the element's ramp, and its
edge breaks into the element's matter, per art pixel at 12 fps:

| Element | The arc | Off its edge (shader) | Bits shed (`SwingMatter`) |
|---|---|---|---|
| fire | red-orange-white, its tail eaten in drifting patches (licks) | flame tongues two pixels wide, each its own height (0-4), changing 12 times a second, hot at the foot, red at the tips | licks and embers rising and swaying |
| frost | faceted: every other column a step darker (lit and shaded faces) | ice crystals jutting from the edge, sharp, lit on one face | angular chips falling |
| poison | green, dark inner rim | drips hanging under it (screen down), longer as the blow goes | drips falling, bubbles welling out and sinking |
| storm | a violet body (a step darker) with a jagged white fork running through it, flickering | - | forks jumping off, a frame on and off |
| holy | gold, glints catching in it | short rays off the edge | glints drifting down |
| shadow, spirit | the ramp (shadow's inverted: a dark core, a bright edge), patches drifting away | wisps half there | motes drawn in (shadow) or rising (spirit) |
| arcane | magenta, hollow rune rhombi riding it | - | runes orbiting |
| blood, water | its ramp | droplets flung off | drops on ballistic arcs |
| earth | crumbling by 2x2 blocks, dark cracks | chunks breaking off | chunks falling |
| steel | as always | nothing | nothing |

An emissive element's arc writes the emissive mask (section 5b). Bits are born where the head
passes, live 0.12-0.5 s, go down the ramp and dither out; fewer effects halves them. A fire
teardrop bit is never bigger than one pixel and its tip (a bigger one is a plus: holy's glint).

**Overhead smashes** (the War Hammer: no arc, its head lands on the floor, `Vfx.smash`): steel
kicks up dust and a few steel sparks; an element bursts there in its own impact (fire's tongues,
frost's shards, storm's forks, poison's splash) and sheds its bits. Monsters' clubs keep their
slash (`club.tres`) or their `attack_fx` sheet painted in their element (`SheetVfx.in_element`).

**Shots.** A plain thing (an arrow, a star) from a weapon carrying an element flies **in** it
without becoming it (`ProjectileSpec.look_element`): the element's matter rides its back half
(fire's licks climbing off the shaft, rime crusting it with a glint, drips hanging, storm's
sparks crackling), its bits trail behind it (embers rising off the path, chips falling), a
shining element lights the floor around it (no halo: a checker round an arrow reads as a blur),
and it goes out in its bits at the end of its range. A magic shot is its element already (the
Frost Staff's shard) and stays it, its hits too; another element the weapon carries (an Ember
Rune on the Spark Wand) **rides its back**, behind its glowing core, and every other bit of its
trail is that element's (the shot keeps its own light and halo).

**The weapon's skills** (Volley and Arrow Rain on the bow, Ice Shards on the Frost Staff...:
`SkillDef.effects_for`) shoot in what the weapon's runes and affixes carry
(`ItemLook.passive_elements`: they work like perks, on every hit, skills included), dressed like
the basic shots (`ProjectileEffect.dressed_in`): Volley's arrows ride an Ember Rune's flames, a
Rime Rune crusts the stars of Shuriken Storm, Ice Shards carry flames. The weapon's own element
and its `on_hit` don't (a Burning bow's affix burns its basic arrows only, so Volley stays plain),
and only the look changes: a skill's hit lands in the element when the rune's rule acts on it
(the Ember Rune's roll), never always. A learned spell or a monster's cast stays as written.
The skills that are no shot wear them too (`DamageAreaEffect.dressed_in`,
`DashStrikeEffect.dressed_in`: a `look_element` drawn, the hits as written): a plain one is drawn
in the first element, the second shedding its bits (Cleave's and Whirlwind's arcs burn like the
basic swing, Arrow Rain's area falls as a nova of flames, Dash Strike's cut is fire); one of its
own element stays itself and the first other **rides** it (`Vfx.riding`: a sparse ring of that
element's pieces inside the area, a small pool for poison's gas; a blade's arc of its own element
sheds the other's bits): a Frost Nova from an Ember staff is crystals with licks of fire among
them, Ground Slam's earth gets a ring of flames.

**Charged attacks** (`ChargedAttackDef.dressed`): the weapon's element replaces the effect's
(a fire katana's Moonless Cut burns, a frost bow's Soulpiercer flies in rime, a storm hammer's
Anvil Fall bursts in lightning); the effect's own element (the hammer's earth, the Templar's
holy) or the weapon's second adds its bits; a magic shot keeps its element, the other riding
it (as above). Copies per pair of elements; the data stays as written. The charge's gauge and glow take the same element.

**The hit.** The swing always shows the element the weapon carries; the **hit** (its flash, its
sparks, the death it deals: `HitInfo.element`) lands in it only when the element surely acts on
that hit, so what the player sees on the target is what happens to it:

- the weapon's own element, or a status every hit leaves (a Burning, Frozen or Venomous affix,
  `ItemLook.hit_element`): every hit;
- a rune that works by chance (the Ember Rune's 50%): `BurnOnHitPassive` rolls before the hit
  lands (`HitInfo.rolled`) and the hit flashes in fire exactly when it sets the target burning;
- a rune that acts on every hit (the Rime Rune, Frostbite: `SlowOnHitPassive`): every hit;
- runes that act apart from the hit (the Spark Rune's chain every 3rd hit, the Shatter Rune's
  crit shockwave, the Gale Rune's roll) show their own effect when they fire; the hit stays steel;
- a charged attack is the element gathered: its hits land in it.

Checked for each element (fire, frost, storm, poison) on a katana, an axe, a lance, the War
Hammer and the Bow, plus plain steel (`CombatTests._test_elemental_attacks`); shots and the
weapon's skills with a rune in `_test_rune_shots` (shots, and the non-shot skills: Cleave, Arrow
Rain, Frost Nova, Dash Strike).

## 12. Auras

A cosmetic the hero wears (`AuraDef`, `AuraVfx`, design/progression.md "The Wardrobe"): three
parts, each on its rule.

- **The glow on the ground** (`aura_ground.gdshader`, drawing in `aura_ground.gdshaderinc`): an
  oval at the feet on the **GROUND** layer (under every body and every telegraph), per art pixel
  of the world's grid, its time stepped (10 fps), a pixel wider on the breath; sparse by ordered
  dithering (`density` 0.7 at most: the floor and a telegraph read through it). Its pattern is
  data (`AuraDef.Ground`): RAYS (a ring, a dithered glow, eight rays turning), POOL (a pool of
  dark, its edge crawling: written without the emissive mark), EMBERS (a smouldering core, a ring
  of embers each flaring on its own beat, sparks leaping off). A glowing one lights itself
  (`VfxLayer.light_up`, in the first of its colors that shines).
- **The halo** behind the body (`glow_halo.gdshader`: two flat bands of added light, a tall oval,
  breathing or flickering), seen round his sides and over his head, never over him
  (`VfxLayer.on_body`, behind).
- **The motes**: whole art pixels drawn by hand at 12 fps (no redraw in between), rising or
  sinking at his sides, behind him, dithered out as they end.
- **Colors** are steps of element ramps, picked in the data (`bright_shade`, `glow_shade`,
  `dim_shade`, `deep_shade` of the accent, `spark_shade` of the motes' element): a ramp runs from
  its core to its edge, bright to dark for light, dark to light for the shadow. The demonic aura
  keeps to dark crimson and the shadow's purple, away from the danger red of telegraphs and
  warning rims (checked: `CosmeticTests`).
- **Fewer effects**: the glow alone, still (no halo, no motes, nothing processed).
- **Out of a floor** (the title's hero, the Wardrobe's preview: `wear_on_sprite`) it stands
  beside the sprite at a floor's scale under it, its glow blended as a picture
  (`aura_ground_ui.gdshader`): written with blending off, it showed through the windows opened
  over the title's transparent viewport.


## Surface Well and lamps

`data/village/atmosphere.tres` points to the spirit and fire ramps. `VillageWellVfx` keeps ambient
soul motes faint; the descent gathers them in curved, broken tails and an upright dashed column.
Only PixelDraw grid shapes are used, at 12 fps, with no free sprite rotation, alpha fade, screen
flash, shake or screen texture. `WellDescent` moves the existing rig at its original scale, hides
it in the mouth and closes an opaque stepped iris before Loader. Reduced effects retains the
same timing/readability with four motes and without column, trails or lamp flames. Review frames
are produced by tools/village/review.tscn (descent_gather/fall/iris, FR/EN, both review resolutions).
The tint and input timing still need exported S23/Windows play-testing.
