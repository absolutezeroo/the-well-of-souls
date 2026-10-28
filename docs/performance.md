# Performance

Village life uses four persistent `VillageResident` bodies, authored schedules and cached frame
lists. Proximity checks use squared distance to the one walker; there are no group scans or
per-frame arrays/strings. Sprite regions change only at the authored frame rate. Speech text is
translated on an actual greeting, with a cooldown, and hidden during modals. Static ground is
not redrawn for movement. Profile changes refresh residents in place rather than recreating
them or their timers; only the static dressing is rebuilt. Sayo's shared palette material is
applied directly to her figure and portrait; no textures are generated while walking.
The 16-pixel surface navigation grid (60 × 40 cells) rebuilds on profile refresh, not per frame.
Paths allocate only on appointment/obstacle changes. Clock text, world tint and appointment
selection update once per fictional minute (about 0.67 seconds), not every frame; the frame
loop only advances a scalar and checks the minute. The noticeboard is a static draw. There are
no per-NPC timers, wall-clock polls or dungeon navigation work for these routines. The four
animals follow the same rules: a path only for a new walk (every few seconds), their frame regions
changed at the authored rate, no `move_and_slide()` while they stand. An animated prop (a flag, a
swaying flower) sets its sprite's region only when its frame changes, and only on screen.

The game must hold 60 frames a second on a phone (the target is a Samsung S23 Ultra, on the
Compatibility renderer) in a crowded fight, and lay a floor without a long freeze. GDScript is
slow next to the engine: what costs is script work repeated every frame for every body, every
pickup and every slot. These rules keep it down; the probe below measures it.

## The rules

**No allocation in a hot path.** Code that runs every frame for every actor (or every slot,
pickup, light...) builds no array, dictionary, string or physics object:

- A literal array in a loop (`for dir in [Vector2i.LEFT, ...]`, `for angle in [0.0, 0.6]`) is a
  new array each time: use a `const` (`GridDirs.FOUR`, `MonsterSteering.HOLE_TURNS`).
- An array or dictionary built only to compare it with the last one (`[enabled, outline] ==
  _key`) allocates: keep the fields and compare them one by one (`BodyLook._told_*`).
- Names made at run time (`"skill_%d" % i`, `StringName(base + "_" + direction)`) intern a
  string every frame: `const` arrays of `StringName` (`PlayerControls.SKILL_ACTIONS`), or a cache made
  once (`RigAnimations._directed`).
- Physics queries keep their `PhysicsShapeQueryParameters2D` and shape and change only the
  transform and radius (`WorldSpace.body_fits`, `MonsterSteering._walk_is_clear`).
- A group scan (`get_tree().get_nodes_in_group()`) builds an array: things asked about every
  frame keep a registry (`Interactable.in_tree`, `LightSource.in_tree`), and the World hands out
  its lists once per frame (`actors_this_frame()`, one per physics step and one per drawn frame).
- A list filtered "in case one was freed" is filtered only when one was (`World._is_gone`).
- A buffer filled every frame is a member, reused (`LightField._moving`, `MonsterBuckets._found`);
  say so in its doc ("read it before the next call").

**Redraw on change.** `queue_redraw()` re-records every draw command of the node in GDScript.
Call it only when what `_draw()` shows changed:

- Keep a key of what the last `_draw()` showed (a frame index, a phase, a shake bit) and redraw
  when it differs: `Trap._draw_key()`, `Quicksand._sheet_frame()`, `HeatSource._flame_key()`,
  `RoomGates._drawn_amount`, `AbyssHud.Arrow.refresh()`. `LootShine` steps at 12 fps the same way.
  The title's picture (`TitleBackdrop.REDRAW_FPS`) too, and the dialogue's "more" arrow redraws
  only when it bobs.
- What waits for something runs only then: a list's drag helper (`TouchScroll`) processes only
  while a let-go list glides, the "more" arrow only while shown, and a Tree of Souls node asks
  `Profile.can_buy_node()` when the profile changes, not every frame (`SoulNodeButton._buyable`).
- What moves continuously (a bob, a breathing glow, a trail) redraws only on screen:
  `Vfx.on_screen(node, reach)` (`reach`: how far its drawing goes from its origin). It is drawn
  again the frame it comes back into view. `MonsterOverlay` gates on `World.view_rect()`.
- Loot on the floor (`ItemPickup`) redraws only when its bob moved a pixel, its glow beat or
  its glint stepped (`_draw_key()`); it redrew every piece every frame (a hundred on screen:
  thousands of rects a frame, its rim one rect a pixel). A baked rim texture was tried: it drew
  more calls (a texture between the shadow's rects and the icon), so the rim stays rects.
- Something drawn in the node's own space (an actor's shadow) moves with the node: no redraw
  (`Actor._redraw_if_changed()`).
- A big static layer and a few moving things go on two nodes: the moving ones redraw every frame,
  the layer only when something lands or is added (`SplatLayer` and its `Air` child).
- Shader uniforms are set when their value changes (`LightField` moving lights, the pact's rune).
- A control on a panel that is hidden but kept stops processing (`ItemSlot`:
  `NOTIFICATION_VISIBILITY_CHANGED`); a HUD widget sets its parts only when the state they show
  changed (`Hud` belt, weapon and temperature; `PactLine` colour).

**Pools: what comes and goes by the dozen is kept, not made again** (decision of the design
audit, docs/design/pillars.md "Performance on the phone"). A shot (`Projectile`) and a damage number
(`FloatingText`) done with go back to their World's pool (`NodePool`, `WorldSpawner.shot_pool`,
`text_pool`): taken out of the tree at the end of the frame (it may be in a physics callback) and
kept, out of the physics and the groups; the next one fired or shown comes out of the pool and is
set up as new (`Projectile._reset()`, `FloatingText.restart()`). A pool keeps 48 at most (one more
is freed); the World frees what its pools keep when it goes. A pooled node must forget everything
of its last life in its setup: its hits, its trail, its halo and distortion children, its z.

**One heavy instantiation a frame.** Monsters called in (a trapped chest's, a slime's split, a
summoner's: `WorldSpawner.defer_monsters()`) come one a frame from the next frame on; a summoner's
first comes at once (`SummonEffect`), the rest after it. The ambushes' waves already came one at a
time (`ambush_spawn_interval`).

**Polls stop when there is nothing to find.** The tutorial looks around for its cues (a merchant
near, a chest near: group scans and lines of sight) four times a second only while a hint they
bring is still to see on this profile (`Tutorial._world_cues_left()`); `MenuNav` keeps the menus'
group as last asked and asks the tree again only when a menu came or went (`_refresh_menus()`),
with no dictionary built each frame; a weapon's aura ages its motes in place and reuses dead ones'
dictionaries; the hint ring is drawn again when its pulse moved a step (12 over its swing), its
arrow from two arrays kept.

**Quadratic loops get a grid.** Every monster looking at every other one (`MonsterSteering.keep_spacing`) asks
`World.activity.buckets` (`MonsterBuckets`) for those in the cells around it: the same ones, in the
same order, so the same sums and the same seeded fights. A line of sight asked every frame is
cast again only after 0.1 s or 4 px of movement (`MonsterSteering.can_see`).

**A crowd** (task: 145 monsters, 108 awake, 36 fps on the PC). What each awake monster costs
every frame adds up: on the development VM, 120 awake cost ~11-12 ms a frame headless (the
probe's `--pack=120`), of which ~5.5 ms its scripts and ~4 ms the engine's own physics (bodies
pushing each other: monsters collide with monsters). What was cut:

- The spacing push (`MonsterSteering.keep_spacing`) is summed one frame in `SPACING_EVERY` (3),
  each monster on its own beat, and kept between (1.9 -> 0.95 ms for 120).
- A monster's two overlays (`MonsterOverlay`) are drawn again only when what they show changed
  (its health, its ward) or moves every frame (an elite's aura, a guard's arc: `MonsterTrait.
  draws_under()`); they were drawn again every frame, two per monster (0.27 ms -> 0).
- A body out of view (`Actor._in_view()`, `Monster.VIEW_MARGIN` past `World.view_rect()`)
  keeps only its timers: no pose, tint or statuses (`ActorRig.on_view`), until it comes back.

- **Monsters don't collide with each other** (decided with Clayton, 25 October 2026): their
  collision mask has walls, water and the hero only. The engine no longer solves bodies pushing
  bodies in a heap (175 chasing the hero, the development VM: physics part 17.4 -> 14.5 ms a
  frame); they keep apart by steering, walking (`keep_spacing`) and standing
  (`MonsterSteering.stand_apart`, at most 60 % of their speed, out of a heap; `SPACING` 6 px).
- **Idle and chase think every second frame** (`StateMachine.THINK_EVERY`, each monster on its
  own beat, with the time gone since); strikes, casts and bosses every frame (`State.every_frame`):
  where to walk decided 1/30 s later is not felt.
Measured then (175 chasing, VM, per frame): the monsters' own physics scripts ~6 ms (their
`move_and_slide` ~2 ms, the rig's pose and tint ~1.5 ms, the spacing ~1.2 ms), the AI ~2 ms.
Measure the PC and the phone on an exported build: a run from the editor is a debug build, its
scripts slower and its debugger listening.

**Draw calls (a crowd batches).** The Compatibility renderer draws in one call a run of items
that share a texture and a material, in draw order; anything else between them, or another
material, starts a new call. A crowd of 200 of the same monster drew one call per body
(~280 calls, October 2026, measured with `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` under
xvfb), for two reasons, both cut:
- **Each body's own shader material** (its hit flash, statuses, rim: `BodyLook`): two materials
  never batch, even with the same shader. A monster at rest (no status, flash, crackle nor death)
  now wears a material shared by every body showing the same (its frame and rim: `BodyLook._pool`),
  and its own again the moment something moves on it; the hero (layers following its body) never
  shares.
- **The shadow drawn between two sprites** (an untextured disc in the actor's own `_draw`, so
  disc, sprite, disc, sprite...). It is on its own node one step down (`ActorShadow`, z_index -1,
  with the floor's markings): all the shadows first, then the sprites, each in a few calls.
Same kind: 284 -> 137 calls (the level's own ~125 included: the monsters 160 -> 11). Four
kinds mixed: 441 -> 226 (bodies of different sheets still alternate in the y order: one call
per change of sheet). Measure on the phone with the debug panel's line (draw calls).

**No GPU readback during play.** `Texture2D.get_image()` reads the texture back from the GPU on
the Compatibility renderer, a stall on a phone. What needs pixels reads each sheet once while the
floor loads and measures its frames on that copy (`BodyTops.warm`, `_sheets`). Frozen deaths also
prepare their fragment geometry and atlases at loading (`DeathPiecesVfx.warm_content`, including
summons and boss forms). Deaths sharing a frame and effect density reuse the same atlas; only
flight state is created at death. Baking uses private cosmetic dice, leaving gameplay's random
stream alone. The fracture pattern is shared, the flight still varies. New custom frames/elements
can bake from the CPU copy on first use; add them to warming if used during combat.

`StatusSet` reuses its tick snapshot and refreshes status-id/element lists only when membership
or appearance changes. Returned lists are read-only views: consume before a later refresh;
`StatusFx` copies only on change. `BodyLook` retains its ages and compares scalar shader values.
`CeilingLayer` keeps fixed nearest-body buffers, selects at most 16 bodies without sorting the
whole crowd, and uploads uniforms only when positions, sizes or count change. Headless regressions
check shared atlases and buffer semantics; load-time/memory cost and GPU frame pacing still need
measurement on exported S23 and Windows builds.

**Same results.** A shortcut must give the answer the plain way gave: the same floors from the
same seed (the probe prints a digest per floor) and the same fights. `tests/suites/perf_tests.gd`
checks the shortcuts against the plain ways (the spacing grid, the ring scan of
`nearest_free_point`, the body tops, the action names).

## The probe

`tools/perf/perf_probe.tscn` plays the real game headless with fixed seeds:

```
godot --headless --fixed-fps 60 res://tools/perf/perf_probe.tscn [-- --fight-frames=1200 --floors=4]
```

1. **Floor generation**: `--floors` seeds x 8 depths (1-4, 6-9; the boss floors included),
   `World.build_floor` timed. Each floor prints `digest N`: a change meant only to be faster must
   print the same digests (`--dump-depth=D` prints what a depth's digest is made of).
2. **A heavy fight**: on a fixed floor, a bot (the tests' `_bot_play`) fights a pack kept at 40
   monsters of 8 kinds (melee, ranged, casters, fliers) around it, its Health refilled, for
   `--fight-frames` physics frames. Each frame's physics part (from the physics step's start to
   the process step's) and process part (the scripts' `_process` and every `_draw`) are kept:
   average, 95th and 99th percentile (P99: what a phone's frame rate is judged on), the worst
   frame, and the share of frames over 16.7 ms (a missed 60 fps frame).

On Linux it measures the main thread's CPU time (`/proc/thread-self/schedstat`), so other
programs on the machine count little; elsewhere the wall clock. The numbers depend on the
machine: compare runs made on the same one, a few of each. Headless, nothing is rendered: the
draw calls and the GPU are not measured (the debug panel's stats on the phone are, task_98).

### Measured (October 2026, task_203)

On the development VM (2 CPUs shared with other jobs, Godot 4.7 headless, the main thread's CPU
time), two runs of each, before (main) and after:

| | before | after |
|---|---|---|
| Floor generation, average | 300 / 300 ms | 275 / 256 ms |
| Floor generation, 95th percentile | 459 / 477 ms | 451 / 385 ms |
| Fight, frame average (physics + process) | 4.05 / 4.22 ms | 3.95 / 4.14 ms |
| Fight, frame 95th percentile | 7.22 / 7.86 ms | 7.69 / 7.96 ms |
| Fight, physics part average | 3.51 / 3.59 ms | 3.28 / 3.53 ms |
| Fight, process part average | 0.54 / 0.63 ms | 0.61 / 0.67 ms |

The floors laid were the same (same digests) before and after. The fight goes otherwise after
(34 kills instead of 24): a monster sees the hero up to 0.1 s later (`MonsterSteering.can_see`), and the
fight's course drifts from there. With that one cache off, the fight is the same to the last
Health point (same digest) and costs 4.12 ms a frame. Headless, the fight's cost is mostly the
engine's physics and the monsters' AI; what the rules above save most (redraws, uniforms, a
GPU readback) is the renderer's and the phone's work, which a headless run doesn't measure: the
S23 has the last word (task_98).

**The entities split into parts (task_193).** Player, Monster, Actor and ActorRig handing their
jobs to PlayerControls, PlayerPack, MonsterSteering, MonsterDrops, GearLook... changed no result:
on the same machine, with the sight cache off (`MonsterSteering.SIGHT_RECHECK` 0), the 32 floors
printed the same digests and the fight the same digest (3286736254) before and after, two runs
each. Frame cost (physics + process, average): 4.40 / 4.04 ms before, 4.59 / 4.29 ms after on a
busier machine (its floor generation, untouched, went from 260 / 272 to 284 / 319 ms); runs
alternated before / after with `--floors=1`: 6.49, 5.01, 4.65 ms before and 5.43, 5.91, 4.92 ms
after, the same within the machine's noise. With `--floors=1` the fight's digest itself varies
from one run to the next on either side (the same code; task card in the roadmap). It follows
the memory layout, not the game's clock: with address randomization off
(`setarch x86_64 -R godot ...`) the runs mostly agree, so compare fights that way or over a few runs.

**Pools, one instantiation a frame, quiet polls (2026-10-28, task_414).** The same VM, the probe
with `--floors=2` (P99 added), two runs each, alternated, the main thread's CPU time; before = the
code without the pools (the floors' pacing already in):

| | before | after |
|---|---|---|
| Fight, process part average | 0.79 / 0.87 ms | 0.68 / 0.66 ms |
| Fight, process part P99 | 5.48 / 4.30 ms | 4.01 / 3.56 ms |
| Fight, frame average | 4.90 / 5.30 ms | 4.61 / 4.69 ms |
| Fight, frame P95 | 8.97 / 9.58 ms | 7.99 / 7.99 ms |
| Fight, frame P99 | 13.16 / 14.26 ms | 12.38 / 11.89 ms |
| Frames over 16.7 ms | 0.4 / 0.4% | 0.3 / 0.2% |

The fights go otherwise run to run (kills 47-58), so read these as a trend, not a measure: the
process part (the scripts, the drawing) about 15% lighter, the worst frames a little better. The
phone's renderer and allocator, where pools matter most, are not measured headless (task_98).

What is left (the roadmap has the cards): floor generation's hot spots are the dressing's
grounds (`FloorDresser._lay_ground`, dictionaries per cell), the ceiling's chunks and their mote
emitters (`CeilingLayer._make_chunks`), the walls' bodies (`WallBuilder`) and the light field's
bake; in a fight the engine's own physics (`move_and_slide` for each body) is most of the
physics part.

## Composed monster behaviours

MonsterTraits builds its native/affix list only at spawn and ranking, deduplicating shared
resource instances. Every frame reads that same list; per-monster states are cached by resource.
Under-drawing capability is cached as a boolean, including traits added after the overlay was
created. New trait hooks run only with their owner (sleeping monsters keep the existing sleep
policy). The example status/death modules allocate no frame state and reuse the existing poison
visuals. More behaviours still mean more work: validate large crowds and the warning readability
on S23; a headless regression is not a GPU measurement.

Frenzy and pulse state is created at spawn. Walking-speed hooks read Health and multiply a
scalar; they never rebuild StatBlock or add timed buffs every frame. Pulse updates decrement
scalars, consult the current target and use the existing sight cache only when a pulse is due.
A warning node and its VFX allocate once per triggered pulse, bounded by one pending warning
per behaviour and its data cooldown/interval. Frenzy emits one existing pop on entering the
threshold, not on every low-Health frame. These are implementation bounds, not an S23 frame-time
measurement; crowd checks remain task_269.


## Command and transition guards

Local input and PlayerControls reuse their PlayerCommand buffers; no arrays/dictionaries or
formatted action names are added per frame. Session tickets and typed deferred spawn batches
allocate only at lifecycle/spawn boundaries. Pickup transfer guards use booleans; deferred
insertion validates the floor id. BodyLook's one-time shader warm-up callback uses a weak sprite
reference, so closing/rejecting a world before placement produces no stale-node callback.
These are implementation bounds; no new S23 frame-time measurement is claimed.

## Village surface

VillageWalker samples movement and updates one existing rig. VillageHub scans a fixed typed
interaction registry; neither allocates arrays/dictionaries per physics step. Ground/path draw
commands and props change only with profile progress. Memorials have no combat bodies or AI;
the court renders one, the paged register at most one additional static rig. Its stone shader
uses the fragment COLOR directly (never squares a texture sample). Profile history grows only
when an ending is chosen. Device frame pacing and long-history cloud limits remain play-test
items; software desktop rendering is not an Android measurement.

The temple adds one cached 48×20 navigation grid and static room drawing. Only doorway changes
or new appointments allocate a route; room entry reuses the walker/rig and does not import
assets, regenerate a level or reload a scene. VillagePropView shares existing prop rendering.
One CanvasModulate switches between exterior daylight and the active room's authored lighting;
HUD/modals stay on their own CanvasLayer. No shadow-casting lights or runtime textures are added.

VillageWellVfx uses fixed-count arithmetic for at most 24 ambient/40 descent motes, at an
authored maximum 20 redraws/second (Kagari: 9/24 motes, 12 fps). Restored lamp positions are
cached on profile refresh. No per-frame collections, random draws, texture reads or lights
are introduced. The separate iris draws at most two rectangles per eight UI pixels per row
only during the final closing phase. Exterior effects stop redrawing inside a room. Reduced
effects caps motes at four and removes trails, the light column and lamp flames.
