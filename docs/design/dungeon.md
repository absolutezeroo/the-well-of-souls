# Dungeon

## Floors

- **Walls** are cliffs drawn from a 16x16 tileset (`DungeonView`): plateau edges, inner corners,
  cliff faces. A face is the two wall cells over the floor, two tiles of one face that join: its
  top (`face_top*`: the plateau's rim, the face going down) over its foot (`face*`); the plateau
  above it goes on plain (its rim is the top's), unless a floor lies right above it (a wall
  three cells thick between two rooms): then it is the plateau's top edge, its rim on top. The tileset's middle row of the face (between
  top and foot) would make taller cliffs; a wall one cell thick shows the plateau's short edge
  (`wall_bottom*`). The mist leaves both cells of the face clear. The generator smooths every floor so only shapes the tiles can draw remain
  (no wall thinner than 3 cells between two floors, `DungeonGenerator.MIN_WALL_THICKNESS`: they
  looked like flimsy fences; no walls touching by a corner). So rooms keep 3 cells of rock between
  them (`DungeonConfig.room_gap`): at 2, smoothing opened the wall and two rooms merged into one
  sprawling space (30% of the open spaces held two rooms or more). Each new room is joined to the
  last one by an L-shaped corridor bent the way that cuts through fewer other rooms.
- **Props** (`data/props/`): crates, vases and barrels break under any attack and may drop loot;
  **powder kegs** blink then explode, hurting everyone (you too) and setting off other kegs.
  Explosions you trigger give you the XP of what they kill. Props block movement, sight and shots.
- **Bodies put down** never start inside a wall's, a prop's or a pond's shape (from inside one a
  body may never get out): the floor's monsters stand inside the rooms, away from their walls,
  and those put down near a spot later (summons, a trapped chest's, a split's, an encounter's, a
  camp's: `World.find_open_point_near()`) only where their body fits (`World.body_fits()`,
  `BODY_ROOM` 14 px or the monster's own radius), else on the nearest free cell's centre where it
  fits. Nor inside another living body: the physics would shove the two apart on the first
  frame, hard enough to push one into a wall or a crate. A room's monsters keep clear of each
  other (`FloorPopulator`), and `find_open_point_near()` keeps clear of every actor standing.
- **Hazards** (`data/hazards/`): each act has its own list (`ActDef.hazards`), and every hazard
  knows how to lay itself out in a room (`HazardDef.place()`). They hurt monsters too: lure them in.
  - **Traps**: rows of **spikes** firing in a wave, **pressure plates** that strike when stepped on,
    **flame vents** that also set you on fire, **arrow traps** (a plate wired to a slit in a wall:
    arrows fly across the room). They always warn before they strike.
  - **Holes**: anything that walks or is knocked in falls. Monsters are gone (you get the XP if
    you pushed them). The hero, on a floor, falls deeper into the Well: **the Deeps** (below).
    On a boss floor (a boss must not be frozen mid-fight, and its arena's floor crumbles), on the
    hidden floor and in the Deeps themselves he climbs out where he last stood safely instead and
    loses 15% of his max Health (`PitDef.fall_damage`). Rolling carries you over; flying monsters
    (bats, ghosts...) don't care. Walking monsters steer around holes, so knock them in.
  - **Crumbling floor**: cracked tiles that hold until someone stands on them, then give way.
    A crack that gave way is saved with the floor (`World.spent_data()` "collapsed"): a resumed
    run finds the hole there, not the crack again.
  - **Quicksand** (ruins) and **mud** (caves): very slow to cross, and they hurt if you stay.
  - Hazards are never placed where they could cut the stairs off.
- **Sealed stairs** (`StairsSeal`, `DungeonConfig` > Stairs seal): a normal floor's stairs stay
  sealed (dark, under a turning violet seal) until you have slain `seal_share` (70%) of the
  floor's monsters, `seal_max` (50) at most; every kill counts, ambush waves and summons too. The HUD counts them under
  the minimap ("Seal 12 / 18"); stepping on sealed stairs says how many are missing. When only
  `seal_reveal_left` (4) are missing, the minimap shows the monsters left. When the seal breaks,
  the stairs light up, the minimap shows them even unexplored and a golden light (`GuideWisp`)
  runs ahead of you along the way. The kills made on a floor are saved with the run
  (`World.spent_data()` "seal_kills"): resumed, the counter picks up where it was, and a broken
  seal stays broken. The floor's own monsters slain stay slain too (`"slain"`): the floor puts
  them down in an order its seed decides (`Monster.floor_index`), so the rebuilt floor leaves
  those numbers out (a number that comes out as another kind of monster stays, rather than the
  wrong one going); a hurt one comes back with its share of Health, and the monsters that came
  later and still stand come back where they stood. The rest of
  what the seed lays is kept the same way (see progression.md, "Saving and resuming"). No more running past everything: a floor is one
  phone session, 3 to 6 minutes (pillars.md "Pacing"; the target, to measure on the phone), so a
  run of twelve floors 40 to 70 minutes. Floors are 72x72
  cells with up to 15 rooms on Pilgrim, and bigger the harder the run (see Difficulty); boss
  floors keep that size. How a floor's fights, calm rooms and rewards are spread: "Pacing" below.
- **Biomes** (`data/biomes/`, `BiomeDef`): every floor is one world from end to end, picked among
  its act's (`ActDef.biomes`; the boss arena has `boss_biome`): Act I **Weeping Grotto**,
  **Pale Garden**, **Drowned Caverns**; Act II **Catacombs**, **Hushed Archive**; Act III
  **Cinder Ruins**, **Godless Temple**; Act IV **Sandchoked City** (sand streets, an abandoned market,
  oases and palms, a lion fountain) and **Tomb of the Dead Sun** (sarcophagi, burial chambers, gold). Nothing from another biome ever shows up. A biome has:
  - its **look** (`theme`: floor and wall tiles, tint, darkness, music) and its **lights**
    (candles in the crypt and the library, braziers in the ruins);
  - its **grounds** (`GroundLayerDef`: moss, sand, mud, shallow water, cobbles...): patches shaped
    by noise, drifting against the walls or keeping to the middle, drawn by a shader
    (`GroundLayer`) with rounded, ragged edges and a rim, in the art's chunky pixels;
  - its **scenes** (`SceneDef`, `data/biomes/scenes/`): little scenes made by hand, written as
    text plans (one string per row, a symbol per cell, `SceneKey` says what each one is: a prop, a
    piece of decor, a carpet, water; "." = keep free). Each has an anchor (against the top wall, a
    side wall, in a corner, in the middle, anywhere) and is mirrored now and then. A big room
    gets 2-3, a small one 1-2 (`scenes_big_room`, `scenes_small_room`), none where the hero
    arrives. A scene goes only where it fits whole, never at a corridor mouth and never walling
    anything off (`RoomSpace.stays_open`);
  - its **decor** (`DecorRuleDef`): a few small things, each with a reason to be where it is:
    at the foot of the walls (pebbles, ferns, dry scrub), right around a scene's furniture (books
    by the shelves, bones by the graves, gold by the sarcophagi) or on its ground (grass on moss).
    A few per room at most (`max_per_room`); the middle of the rooms and the corridors stay
    clear, so the fight stays readable. No piece is ever drawn over a wall: one that would
    overlap a wall is nudged off it (up to half a tile, `FloorDresser.fit_on_floor`, by its
    visible pixels), or left out if it can't fit (scenes' decor too). The floor tiles carry no
    decor of their own;
  - its **pots and crates** (`props`: baskets in the desert, mossy jars in the garden...).
  This is how Dead Cells, Enter the Gungeon or Brogue keep generated levels coherent: hand-made
  pieces per biome, laid out by the generator (`FloorDresser`).
- **Chests** (`data/chests/`): walk up to one to open it. Some are trapped: they blow up or let
  monsters out (and keep only one item). A trapped chest rattles now and then... Every floor has
  one at least (`chests_min` 1, times the floor's size: two on the biggest floors), the first in
  a dead end (see "Pacing").
- **Two ways down** (`FloorRoute`, `dungeon_config.tres` > Routes): a normal floor ends on two
  stairs, and a boss arena opens two once the boss falls. Each leads to a different world of
  the act (`ActDef.biomes`), and may be cursed or hold a floor event: a wooden **sign** over each
  stairs says which ("Flooded Caverns / Ashen Breath - better loot"). The second way gets a twist
  more often (`route_twist_chance`), so the choice is often a calm way or a bold one. Floors
  before a boss have one way: the arena. The offer comes from the run's seed (the same all day in
  a daily run) and the way taken is saved (`RunState.routes`), so a resumed run rebuilds the same
  floor. The second stairs stand in the room farthest from both the start and the first stairs.
- **Curses** (`data/curses/`, `CurseDef`): the Well curses a whole floor. Never the first floor nor
  a boss floor, rarely on Pilgrim, more and more often up to Nightmare (`DifficultyDef.curse_chance`:
  5%, 12%, 20%, 35%). On arrival, the **curse card** (`CurseCard`) shows the Well's sigil forming
  out of souls, the curse's name, its story and its rule. A cursed floor has no floor event, but
  better loot and more gold.
  - **Frostbound**: ice over every room, snow falling, the cold getting into your bones.
    A few **campfires** (one where you arrive, 2-3 more: `CurseDef.spot_count`) warm you back
    up, with logs and stones scattered around them, never twice the same.
  - **Ashen Breath**: the air scorches, embers drift. **Oases** cool you down: a pond of real
    water tiles (`HeatSourceDef.pond`, nobody walks on it: `Layers.WATER`) of a random size, in
    a rough patch of grass with plants and flowers around, each one different. One is by where
    you arrive: in the first room, or, if it is too small, on the nearest free floor
    (`HazardDef.nearest_free_rect`), never in the rock.
  - **No camping**: stay too long by a campfire or an oasis (`camp_limit`, 12 s) and the light
    draws monsters in (`CampWatch`): a warning first, then a wave, bigger each time. They give
    nothing.
  - **Moonless Night**: the whole floor in the dark but right around you; monsters and traps hide
    in the black. The best loot of the three.
- **Temperature** (`BodyTemperature`, `dungeon_config.tres` > Temperature): the hero has a body
  temperature from -100 (frozen) to 100 (burning up), shown under the XP bar when it is not
  normal, with frost (or a burning haze) creeping in from the screen's edges
  (`temperature_overlay.gdshader`). Cold slows you down; frozen or burning up, you take damage
  every second. Campfires and springs (`HeatSourceDef` with `comfort`) bring it back to normal,
  and away from cold and heat it goes back to normal by itself.
- **Ambushes**: a floor may have a quiet, empty room, at the floor's peak (see "Pacing"). Walk in
  and spikes close the exits, monsters pour in, wave after wave, the last one led by an elite.
  Clear it for a big chest.
- **Elites** (`data/elites/`): any monster can be one, more often deeper and on harder
  difficulties. They glow in their color, show their name, are bigger and tougher, give 3x XP
  and always drop an item. Their affix is a perk, like the hero's: **Swift**, **Vampiric**
  (heals when hitting), **Bursting** (blows up when it dies), **Ironclad**, **Venomous**
  (poisons), **Thorned** (hurts who hits it).

## Pacing

A floor is laid like a level, not filled at random (decision 0012, pillars.md "Pacing";
`FloorPacing`, `DungeonConfig` > Population, Pacing). Its numbers are starting values to tune by
playing on the S23.

- **Monsters follow the room's size**: a fight room gets its share by its open ground (no rock,
  chasm, pool or pillar), `monsters_per_room` (2) for every `room_cells` (70) cells on the first
  floor, plus the floor's extra ones (`extra_monsters_per_depth`, the difficulty's) for every 70
  cells too, the fraction rounded up as often as it is big; one at least, `max_monsters_per_room`
  (9, the difficulty's extra ones on top) at most (`FloorRules.room_monsters()`). A tough
  monster takes more of the share: an elite (any rank) or a big body (radius 14 or more) counts
  `tough_cost` (2). The floor's cap (`max_monsters_per_floor`, 130) counts the same way. A small
  side room holds two or three, a great hall eight or nine; a floor as a whole holds about what it
  did before (Pilgrim 47, Keeper 65, Martyr 86, Nightmare 97 on average).
- **A breather after a few fights**: walking the shortest way from the start to each stairs, the
  hero never crosses more than `max_fights_in_a_row` (3) fight rooms in a row (an ambush and a
  pact door count as fights). The room that would make one too many is kept calm (no monsters, no
  hazards): a spring or an altar goes there first, the floor's chest may, or only its crates and
  its scenes.
- **Build-up, peak, release**: the ambush and the pact door go in a room `peak_from`-`peak_to`
  (60-80%) of the way to the stairs when one fits (the walk's length to the room's heart against
  the walk to the stairs); a floor with neither there gets an elite in the fight room nearest that
  stretch (from floor `peak_elite_min_depth`, 2). The merchant and the forge come after the peak
  (80% of the way or more, by the stairs or beyond): what is earned on the way is spent there.
- **A treasure on every floor**: the first chest goes to a dead end (a room with one way in) when
  one has a free spot by its walls, else to a calm room on the way.
- **Room to move around pillars**: nothing standing (a scene's furniture, a lamp, a crate, a
  chest) within 2 cells of a shaped room's pillar (`FloorPopulator.PILLAR_CLEARANCE`), so no
  one-cell squeeze between them; the monsters may stand there.

Measured on 960 generated floors (`tools/levels/floor_probe.tscn` and `floor_report.py`: the four
difficulties, every floor of the run, 20 seeds; the 640 normal floors counted), before and after
(2026-10-28):

| | before | after |
|---|---|---|
| Fight rooms in a row on the way to the stairs | median 4, max 9; 64% of floors over 3 | 3 at most |
| Calm rooms (no monsters) | 6% of the rooms | 9% |
| Floors without a chest; chests in a dead end | 35%; 6% | 0%; 20% (1.6 a floor both times) |
| Monsters against the room's open cells | r = 0.02 | r = 0.64 |
| Ambush along the way; merchant and forge | 56%; 55% (median) | 68%; 85% |
| Open spaces holding two rooms or more; p90 size | 30%; 64 cells | 22%; 51 cells |
| Pillared rooms with a crate or lamp within 2 cells of a pillar | 930 of 1027 | 1 of 977 |
| Monsters a floor, Pilgrim / Keeper / Martyr / Nightmare | 47 / 65 / 86 / 97 | 49 / 68 / 91 / 97 |

`tests/suites/pacing_tests.gd` holds these on fixed seeds: fights in a row, a chest on every floor,
monsters by size (r >= 0.5), the peak and the release, merged spaces, pillars' room, the seal.

## Room shapes

A room is not always a rectangle (`RoomShapeDef`, `data/biomes/shapes/`). Each biome lists the
shapes its rooms may take (`BiomeDef.room_shapes`, each by its `spawn_weight` from its
`min_depth`, `max_per_floor` at most) and the weight of a plain rectangle (`plain_weight`, 35-40
against 45-55 for its shapes: some 40% of the rooms take a shape, the big ones reaching their cap
first). The room where the hero arrives is always plain.

| Shape | What | Biomes |
|---|---|---|
| Round Hall | a circle, 11-15 cells | grotto, garden, drowned, cinders |
| Oval Hall | an ellipse, 14-18 x 9-11 | grotto, drowned, city |
| Pillared Hall | two rows of pillars along the long sides | catacombs, archive, cinders, temple, city, tomb |
| Ring of Pillars | a round hall, a ring of pillars inside | grotto, garden, drowned, temple |
| Hall of Columns | a grid of columns, 3-4 cells apart, 15-17 x 13-15 | catacombs, archive, tomb |
| Crossing | two halls crossing (a plus) | garden, catacombs, archive, cinders, temple, city |
| Bent Hall | an L, one corner (at random) left out | grotto, drowned, archive, cinders, city |
| Eight-Sided Hall | the corners cut off | garden, catacombs, archive, temple, tomb |
| Alcove | a small eight-sided room, 5-7 cells | grotto, garden, catacombs, tomb |
| Gallery | long and narrow, 16-20 x 5-6 | catacombs, archive, temple, city, tomb |
| Ring Around the Rock | a round hall round a block of rock (cliffs, mist on it) | grotto, drowned, cinders |
| Pool Hall | a round hall round deep water (`WaterPool`: nobody walks in it, shots go over) | grotto, garden, drowned, city (an oasis) |
| Bridges Over the Dark | a chasm crossed by two walkways, a ledge all round (from floor 2) | catacombs, cinders, temple, tomb |

- **How**: the generator (`DungeonGenerator`, `RoomShaper`) asks the shape for a size, carves
  its outline, lets the corridors cut through it as through any room, then once every corridor
  is dug lays the core (`core`: ROCK, CHASM, POOL, inside a rim of `core_margin` cells, with
  `bridges`) and the pillars (`pillars`: ROWS, RING, GRID, never on the lanes through the
  middle where corridors come in). Anything that would cut a piece of floor off is taken back
  (`_finish`): every floor is one piece, its walls as solid as ever.
- **The plan**: `DungeonMap.rooms` keeps the rooms' rectangles; `DungeonMap.plans` (`RoomPlan`)
  holds each one's shape and **heart**, the walkable cell nearest its middle (its middle may be
  rock, a chasm or a pool): the start, the stairs, the merchant, the forge and encounters stand
  there. `DungeonMap.features` marks the chasm and pool cells, `pillars` the pillars;
  `is_ground()` is floor with none of them.
- **On the floor** (`RoomFeatures`): a chasm is holes in the biome's look (`BiomeDef.chasm`, else
  `DungeonConfig.chasm`): **a fall sends the hero into the Deeps**, as any hole, and monsters
  knocked in are gone. A pool is deep water (`BiomeDef.pool`: the oasis' in the city, else
  `DungeonConfig.pool`) drawn as a ground with a shore. Pillars are props: the shape's own
  (`pillar`), else one of the biome's (`BiomeDef.pillars`), the same in a whole hall.
- **What changes around them**: nothing is laid in a chasm, a pool or right beside them (props,
  traps, chests, monsters, decor); holes never cut a room in two (`PitDef.place`, a ring round a
  rock or a ledge round a chasm); monsters are put down only where their body fits (an elite's
  grown one too), by the physics and by the grid. Chasm rooms and signature rooms are never the
  merchant's, the forge's, a pact's or an ambush's (`RoomShapeDef.quiet_room`). The minimap draws
  the rooms as they are: round, the water blue, the chasms black. The Deeps' maze takes the
  shapes of its dressing biome (the Cinder Ruins'), without a signature room.
- **Boss arenas** keep their own shapes (`ArenaDef`: rect, oval, cross, pillars), and the hidden
  floor's rooms stay plain.

## Ceilings

What hangs over the rooms (`CeilingDef`, `data/biomes/ceilings/`, `BiomeDef.ceiling`), drawn over
the actors and **dithered away around anyone under it**, so the fight always reads:

| Biome | Overhead |
|---|---|
| Weeping Grotto | stalactites dripping, roots, moss fringes, roots down the side walls |
| Pale Garden | pale roots (Kagari's trees reaching down), vines with white flowers |
| Drowned Caverns | stalactites, wet moss, roots |
| Catacombs, Nameless Charnel | chains with hooks, a skull, a cage, bundles of bones; chains hung along the walls; cobwebs in the corners |
| Hushed Archive | torn old banners, cobwebs, hooks on chains |
| Godless Temple | red banners with the sun's sign, censers on chains with smoke rising off them, gilded chains |
| Cinder Ruins (and the Deeps) | charred beams across the rooms, some broken, censers, burnt roots |
| Sandchoked City | broken sandstone arches across the rooms, striped awnings, palm fronds, sand trickling from cracks |
| Tomb of the Dead Sun | broken arches, sun discs on gold chains, gilded chains, sand trickling |

- **Pieces** (`CeilingPieceDef`): a picture in the ceiling's one atlas (`assets/tiles/ceiling/`,
  drawn by `tools/levels/level_art.py` in the Ninja Adventure palette), where it hangs
  (`where`: TOP_WALL from the cliff above a room's top edge, SIDE_WALL, CORNER, OVER_ROOM from the
  unseen ceiling two cells or more from any wall, ACROSS from wall to wall), how many (`density`,
  `max_per_room`, `spacing`, `in_corridors`), how high (`height`: its flat shadow falls that far
  below it), `broken` (ACROSS: middles missing) and an `emitter` (`PixelMotes`: smoke, sand).
  A signature room's ceiling is thicker (`RoomShapeDef.ceiling_scale`). Never over a boss arena.
- **Drawing** (`CeilingLayer`, `src/world/ceiling/`): over the bodies (z 2), under the floor's
  light (z 3, so the room lights it) and the wall mist; shadows on the floor (z -6). Laid once
  per floor from its own stream of the seed, in chunks of 12 cells over the one atlas: a
  Nightmare floor (104 x 104, 27 rooms, 56-127 pieces) draws 1-3 more draw calls. Its shader
  (`ceiling.gdshader`) gets the hero and the 15 nearest bodies on screen every frame (feet,
  radius, height) and drops the ceiling's art pixels within `clear_radius` of a body's outline,
  then brings them back over `fade_band` by ordered dithering (docs/vfx.md: no smooth alpha).
  Nothing of it in a simulation (`Vfx.shown` off).

## Signature rooms

Each biome has a place of its own (`BiomeDef.set_pieces`, `RoomShapeDef` with `set_piece`,
`data/biomes/set_pieces/`): on `set_piece_chance` (40%) of its floors, one at most, dressed only
with its own scenes (`RoomShapeDef.scenes`), with a thicker ceiling. The first time the hero
walks in, its name shows on a banner and its line in the log (`World.set_piece_entered`, the
Game shows it).

| Biome | Room (FR / EN) | What |
|---|---|---|
| Weeping Grotto | Le Creux qui Pleure / The Weeping Hollow | a round cave round a pool, stalactites thick overhead, wet rocks, crystals |
| Pale Garden | Le Chœur des Racines / The Root Choir | a ring of old stumps under hanging roots, a flower bed |
| Drowned Caverns | La Salle des Noyés / The Drowned Hall | black water crossed by a causeway, paper boats on the bank |
| Catacombs | La Nef des Ossements / The Ossuary Nave | carved skulls in rows, coffins along the wall, bones in the corners and in chains |
| Hushed Archive | Les Rayonnages Engloutis / The Sunken Stacks | a ring of shelves round a reading desk |
| Cinder Ruins | Le Gouffre de Braise / The Ember Chasm | a burnt pit crossed by bridges, rubble, charred beams |
| Godless Temple | Le Cercle des Bûchers / The Pyre Circle | braziers in a ring round the shrine, censers smoking |
| Sandchoked City | La Salle du Trône Effondrée / The Collapsed Throne Hall | broken columns, a throne in the sand, broken arches |
| Tomb of the Dead Sun | La Fosse du Soleil Mort / The Pit of the Dead Sun | a round chasm crossed by four bridges, gold at its edge, sun discs on chains |

## The Deeps (Les Tréfonds)

A hole on a floor is not only a stumble: the hero **falls deeper into the Well**, into the Deeps
(`AbyssDef`, `data/abyss/abyss.tres`, set in `DungeonConfig` > Abyss; run by `Abyss`,
`src/game/abyss.gd`, hosted in an `AbyssWorld`). Under the Well there is more Well.

- **When.** A fall into a hole or through cracked floor on a normal floor (`Abyss.can_take()`).
  Not on a boss floor (the old rule there: climb out, lose 15%), not on the hidden floor, not
  from the Threshold or from the Deeps themselves (a hole down there: the old rule). Monsters
  knocked into a hole still die as before. Without a Deeps (the balance tools' bare arena,
  `DungeonConfig.abyss` empty) a fall is the old rule everywhere. A fall cut short by a new
  floor (the debug panel, a new run) ends there: the hero stands at its start
  (`Actor.cancel_fall()`), never dropped into the Deeps from a floor he didn't fall on.
- **The floor waits.** As for the Threshold (a shared `SubWorld`, `src/game/sub_world.gd`): the
  floor's `World` freezes and leaves the scene tree just as it is (its monsters, a pact's fight,
  an ambush, the shots in the air); a dark red veil falls; the hero lands in the Deeps, **hurt by
  the fall** (`fall_damage`: 5% of his max Health, less his Armor; it can kill), his statuses
  left behind, his torch burning low (`torch_level` 9, 12 on the floors).
- **The place.** A small maze of the generator's rooms (`DungeonGenerator.generate_small`:
  8 rooms of 6 to 10 cells in 56 x 44, corridors 2 wide), its own look (`abyss_theme.tres`: dark
  cave tiles, an ember-red light ramp at ambient 2 out of 15, embers in the air, the burning ruins'
  grounds and decor, no scenes), a couple of holes (`hazards`, never cutting the way off), no
  lanterns, no stairs, no seal, no loot but what the demons drop.
- **The demons** (monsters.md, "The Deeps' demons") wait in the rooms (`room_demons`: 1-2 a
  room, asleep until they see him) and **crawl out of the dark in waves**: the first 2 s after the
  veil lifts, then every 8 s (1 s quicker each act, never under 3 s); 2 demons (+1 every second
  wave, +1 per act), half of them on the way ahead to the door (`ahead_share`: outrunning them is
  not a way out), the rest 6-11 cells around him (`AbyssWorld._spawn_point()`: random tries, then
  every cell of that ring, so a wave is whole whenever the maze has room); no more than 6 of the
  waves' demons up at once (+1 per act). 5% of them are elites. From Act III a **Breach Sentinel** stands in front of the
  door. No timer: the waves are the pressure. They are real monsters: XP, gold, kills, bestiary.
- **The way out: the Dawn Breach** (*La Brèche de l'Aube*, `AbyssDoor`): a doorway torn in the
  dark with daylight behind it, standing in the room farthest from where he lands **on foot**,
  lighting the cave around it (light 13, daylight white), drawn in holy's ramp (docs/vfx.md). To
  find it on a phone: a golden light runs ahead along the way when the veil lifts and every 20 s
  (`guide_every`), and an **arrow of light circles the hero toward it** while it is out of sight
  (`AbyssHud`). The top of the screen names it, with the seconds left for the dawn's gift.
- **Back up.** Stepping into the Breach brings him back to **the last safe spot by the hole**,
  and the hole fills in behind him (`AbyssDef.seal_hole`, `World.seal_hole()`: dust, solid floor)
  so a step to the side doesn't drop him straight back in; the floor's save keeps it filled
  (`World.spent_data()` "sealed": a resumed run fills it again, cracked floor included);
  his Health as he left the Deeps (the Deeps were the cost), with 1.5 s of grace (`return_grace`)
  and his torch back. **Out quick** (`quick_time`: 30 s, +5 s each act) earns **the dawn's gift**
  at his feet: gold (12, +8 an act, through the floor's gold rules) and a 60% roll of a potion, a
  greater potion or a bomb (`gift_loot`).
- **Death down there is death**: the run ends in the Deeps. With a second life the trial of the
  **Threshold opens from the Deeps** and, won, puts him back in the Deeps where he fell (builds.md).
- **Around it:** the run's clock keeps counting; nothing is saved while he is down there
  (`Game._save_run()`: a run picked up again is as it was before the fall); the bag, the belt
  and perk choices work (it is a fight like any other), but no menu opens on the way down or up;
  the floor's map, seal and boss bar are put away until he is back. The first fall shows a hint.

## Secret rooms

Some floors hide a small room behind a **cracked wall** (`SecretRoomPlan`, `SecretRoom`,
`dungeon_config.tres` > Secret rooms): `secret_room_chance` (50%) on a normal floor, one at most
(`secret_rooms_max`), two at most on floors of `secret_big_floor_rooms` (20) rooms or more
(Martyr, Nightmare). Never on a boss floor, the first room or a room with the stairs.

- **Where**: the generator plans it once the floor is made: a 7x5 room (`secret_room_size`) behind
  a wall of an existing room, joined to it by a passage through the rock 3 cells long
  (`secret_passage_length`) and 1 wide (`secret_passage_width`). Above a room first (the crack
  on a cliff face, where it reads best), else beside or below it. The rock all around it is at
  least `DungeonGenerator.MIN_WALL_THICKNESS` thick, so it never touches another floor and the
  main path never needs it. Its cells stay wall in the map (nothing walks, draws, lights or
  dresses them) until it opens. Planned from its own stream of the floor's seed: the rest of the
  floor is the same with or without it, and a daily run hides the same rooms for everyone.
- **The tells**, subtle but learnable: dark fissures on the stone and chips at its foot
  (`CrackedWall`, a prop in the wall), a faint draft of dust motes drifting into the room, now and
  then a whisper when the hero is close (`secret_whisper`). The first time one is in sight, a
  hint says what it is (`cracked_wall`). Nothing in front of it: the populator keeps its foot free.
- **Breaking in**: any hit of the hero (a blow, a shot, a skill) or a blast breaks it
  (`cracked_wall.tres` > hits: 1); monsters' blows don't, or they would give it away. The rock
  crumbles (sound, dust, debris, a shake), the passage and the room become floor
  (`World.open_cells()`: walls, light, mist, pathfinding and drawing redone), the room shows on the
  minimap, lanterns light it, and the log says "The wall gives way: a hidden room."
- **What it holds**: one of `secret_rewards` (`data/secrets/`, `SecretRewardDef`, by
  `spawn_weight` and `min_depth`, drawn from the floor's seed), its name floating over it:

  | Reward | Weight | What |
  |---|---|---|
  | Hidden Coffer | 30 | a chest better than the ones lying around (2-3 items, quality 3.5), never trapped |
  | Forgotten Shrine | 20 | an altar, a statue or a spring (an encounter) |
  | Buried Rune | 20 | a rune |
  | Hoarder's Cache | 20 | 30-50 gold, +6 a floor (the floor's gold rules apply) |
  | Sealed Draughts | 15 | two rare draughts or scrolls |

  In the acts of the hidden floor, the room may hold its key instead (below).
- **Saved**: a broken wall stays broken and a looted room stays empty after a resume
  (`World.spent_data()` > secrets: each room's state, and whether it held the key).
- **Counted**: secret rooms found go to the profile's stats (the feat "What the Walls Keep":
  find 5) and to the end-of-run screen ("Secret rooms found").

## The hidden floor

**The Nameless Charnel** (`data/secrets/nameless_charnel.tres`, `HiddenFloorDef`,
`dungeon_config.tres` > Hidden Floor): a floor between Act II and Act III that nothing announces.

- **The key**: a secret room of Act II (`key_acts`: [1]) holds the **Bone Key** instead of its
  reward half the time (`key_chance`), while the hero has none and the run hasn't been down yet.
  The key's card says only: "It fits no door on this side of the Warden."
- **The way**: slaying Act II's boss with the key in the bag opens a third way in the arena, a
  sealed fissure of cold light under a ring of runes (`HiddenWay`, opened by `HiddenPassage`), its
  sign naming the floor, beside the two usual stairs. Taking it is a choice: the stairs still lead
  on to Act III. Stepping in spends the key.
- **The floor**: a start room, three rooms of its own monsters (Skeleton, Frost Skull, Lost Soul,
  Hexer, Ghost Lantern, Soul Moth, Cyclops), then an arena (`DungeonGenerator.generate_hidden()`),
  in its own world (a cold catacomb, `nameless_charnel` biome and `charnel` theme), with its
  title card ("Between the Acts"). No curse, no event.
- **Its boss**: The Nameless Effigy (see monsters.md), in a Pillared Nave or a Round Pit. When it
  falls: the usual relic choice, a Big Chest, 20 souls on top of the run's (times the
  difficulty's), the secret feat "Laid to Rest at Last", and the arena's stairs to Act III's first
  floor (the same two ways the Act II boss offered).
- **Depth and the run**: the floor keeps the depth of the boss floor before it
  (`RunState.hidden_floor`): the HUD says Depth 6, its monsters and boss scale like floor 6, the
  run's numbering, records and quests don't move. Its floor seed is its own (the daily run's
  hidden floor is the same for everyone). Splits: the Act II boss floor's split is taken going
  down; the hidden floor takes none, its time goes into the next floor's. Saved like any floor:
  quitting on it comes back to it; quitting once its boss is dead goes on to Act III. Once a run
  (`RunState.hidden_done`): no more keys afterwards, in endless mode too.

## The bottom of the Well

**Le Fond du Puits / The Well's Bottom** (`data/story/finale.tres`, `FinaleDef`,
`dungeon_config.tres` > Finale): the run's true last floor, the final fight (monsters.md, "The
bottom of the Well"; the canon in docs/lore.md, section 7, step 7).

- **The gate** (`FinaleDef.victories_needed`: 1): a profile that never won a run wins it on
  Act IV's boss, exactly as before (the first ending: the victory screen's story, records,
  souls, ascension, endless). Once it has won (any difficulty, Pilgrim's too:
  `Profile.total_wins()`), a new run is marked `RunState.finale_open` (decided when it begins and
  saved: a run never changes course midway, an older save without it asks the profile).
- **The way down**: with the bottom open, Act IV's boss is a warden like the others: its relic,
  no win; its arena opens a single way down (one stairs, its sign naming the bottom:
  `FinaleDef.route()`, `RunState.leads_to_finale()`). Only on the first pass (not in endless
  mode, not once won).
- **The floor**: a start room and an arena (`DungeonGenerator.generate_arena()`) in its own
  world (`well_bottom` biome and theme: grey stone, a violet grade, ambient light 3 of 15, no
  lamp in the arena: `FinaleDef.arena_lights` 0, the hero's lantern and the Maw's glow light it),
  an oval arena of 27x21 with no pillars and no changes (`data/arenas/well_bottom.tres`; a fight
  of several forms keeps its arena as it is). Its title card ("The End of the Descent"), no
  curse, no event, its own floor seed.
- **Depth and the run**: like the hidden floor it keeps the depth of the boss floor before it
  (`RunState.finale`): the HUD says Depth 12, Tôma and the Maw scale like floor 12. Act IV's
  floor gets its split going down; the bottom gets its own (`RunState.split_depth()`: 13), the
  win's time.
- **The win**: the last form's fall (`RunState.wins_with()`: `FinaleDef.final_boss()`) wins the
  run, with all its bookkeeping at once (`has_won`, the time and its record, the souls, the
  ascension, the history), then the choice of an ending (progression.md), then the victory
  screen and endless mode (the Maw's relic, the arena's stairs to depth 13).
- **Saves**: after Act IV's boss: picked up in his cleared arena, its stairs down to the bottom
  (progression.md, "a warden's cleared arena"). On the
  bottom: picked up there (the fight starts over from Tôma, like any boss floor). Won but the app
  put away before the choice (`RunState.ending_due`): picked up on the endless floor, the choice
  first.
- **The Nameless Keeper**: while one waits (`Profile.keeper`, the hero of a run that ended in
  "take his place"; copied into `RunState.keeper` when a run begins, saved with it, never in a
  daily run), he is the bottom's boss instead of Tôma and the Maw (`RunState.bottom_boss()`,
  `World.finale_boss`), and his fall alone wins the run (monsters.md, "The Nameless Keeper").
- **Debug**: the debug panel's "The Well's bottom" goes there at once (Tôma and the Maw);
  "Nameless Keeper" too, with the Keeper made from the hero as he is (a snapshot of this run,
  never written to the profile).

## Boss arenas

A boss floor is a start room and an arena picked among `DungeonConfig.arenas` (or the boss' own,
`BossDef.arenas`: the Wyrms want room). **A heal before every boss** (decision 0012): the start
room holds the **Spring of the Last Vigil** (`DungeonConfig.boss_spring`,
`data/encounters/vigil_spring.tres`), two cells from where the hero arrives, on every difficulty
(the hidden floor's and the bottom of the Well's first room too): Drink, healed whole, no cost
and no risk, once (`BossFloorKind.place_spring()`). An `ArenaDef` (`data/arenas/`) has a size, a shape (rect,
**oval**, **cross**), pillars (props: cover from shots) and **changes** (`ArenaShiftDef`), one at
each of the boss' next phases (`Monster.phase_entered`): the cells blink red (`CellWarning`), then
become cracked floor, pits or spikes, in a pattern (the **edge** crumbling in, a **cross** of
spikes through the middle, **corners** falling away, **scattered** holes). Never under the hero,
the boss or the middle (where the stairs appear).

| Arena | Size, shape | Changes |
|---|---|---|
| Great Hall | 27x19, 4 pillars | the edge crumbles, then the ground caves in |
| Round Pit | 27x21 oval | a cross of spikes, then the pit closes in |
| Cross Court | 29x23 cross, 4 pillars | spikes here and there, then holes |
| Pillared Nave | 31x17, two rows of pillars | the corners fall away, then a cross of spikes |
| Old Chamber | 21x15 | the floor cracks, then caves in |

## Special floors and bosses

Bosses have a lot of HP and stand their ground: they ignore 95% of the knockback, so no weapon can
keep one away from you (`MonsterDef.knockback_resistance`). Big monsters resist half of it, and
elites at least half.

- **Special floors** (`data/floor_events/`, `FloorEventDef`): 30% of the normal floors after the first
  (`dungeon_config.tres` > Floor events) are announced when you arrive: **The Wandering Dead** (elites, dim),
  **Hoard of the Dead** (chests and gold, more traps), **The Swarm** (hordes of weak monsters),
  **Utter Dark** (very dark, better loot), **Silent Halls** (few monsters, the merchant, encounters),
  **Blood Moon** (monsters hit harder, double gold). They multiply monsters, HP, damage, elites,
  light, chests, hazards, encounters, gold and loot quality.
- **Two bosses per act** (`ActDef.boss` + `other_bosses`): each run draws one per act (saved with
  the run; the title screen shows both). Bloated King or the **Mire Matron** (leaps, poison spit, calls
  its brood); Gorr the One-Eyed or the **Mother of Tears** (a freezing wail, blinks, calls lost souls);
  Crimson Tengu or the **Ember Ronin** (arcs of fire, dashes, a ring of fire). Gilded Hoarder or the
  **Dead Sun** (a burning sun buried with the kingdom: solar flares, blinks, calls its embers).

## Blood Moon

A floor event (`data/floor_events/blood_moon.tres`): frenzied monsters, double gold, and its own
look over the biome (`FloorEventDef.atmosphere`, the biome's sounds stay; `ambient_tint` reddens
the light): a crimson grade, a great red glow breathing over the top of the screen
(`AmbienceDef.moon_color`), edges darkening to blood and beating like a heart
(`vignette_color`, `vignette_pulse`, in `screen.gdshader`), red moonlight shafts and mist, falling
red ash (`src/vfx/ambient/blood_ash.tscn`).

## Encounters

Some rooms hold something strange (`data/encounters/`, `EncounterDef`): stand by it, tap Interact (its own word:
Drink, Offer, Talk, Kneel; see [interface.md](interface.md#nothing-opens-by-itself)) and choose.
Each choice has a cost (gold, a part of your max health) and outcomes drawn by weight
(`EncounterChoice`, `EncounterOutcome`: heal, hurt, gold, an item of some quality, a choice of
perks or relics, monsters or elites, any `Effect`). Each can be used once. The panel shows every
outcome in words with its odds before you choose; the words come from the outcome's fields
(`EncounterOutcome.summary()`), so new encounters explain themselves. An encounter has a room of
its own and nothing (chest, prop, hazard, another encounter) within
`DungeonConfig.encounter_clearance` cells (2) of it.

| Encounter | Choice | What may happen |
|---|---|---|
| Spring of the Drowned | Drink | healed (55%), a strong buff for a minute (25%), cursed water hurts (20%) |
| Blood Altar | Offer your blood (-15% max health) | a choice of relics |
| Grinning Spirit | Wager 30 / 80 gold (more each floor) | an item, sometimes a great one... or it laughs and runs |
| Keeper's Statue | Kneel | a choice of perks (50%), or two elites (50%) |
| Spring of the Last Vigil (a boss floor's first room only, see "Boss arenas") | Drink | healed whole (100%) |

**No repeats** (decision 0012, `RunLuck`): a floor's encounters are drawn among those the run has
drawn least, so each comes once before any comes twice; floor events, curses (the ways down's
twists included: the two ways never share one), pacts and trials are drawn the same way. A floor
laid again from its seed (a run picked up) sees only what the floors above it drew, so it draws
the same; what the run drew is saved with it (`"luck"`).

The Keeper's Statue stands beside **an empty niche** (`EncounterDef.niche`, `EncounterNiche`):
drawn next to it on the floor, its inscription told under the statue's text in the panel. Before
the keeper may be named (`keeper_named`, docs/lore.md section 7) it is an empty niche, a name
scratched away and one line left; after, the hero reads the name (`revealed_text`). Nothing to
choose: it changes no rule.

## Pact doors

Some floors hold a sealed side room behind a marked door (`PactRoom`, `data/pacts/`, `PactDef`):
crimson spikes across the doorway, a stele standing in it, a sigil of blood and gold on the floor
before it, candles inside on either side (`DungeonConfig.pact_light`) and a red glow. Seen once,
the room and its door go on the minimap (a red mark, grey once spent). Standing by the stele and
tapping Interact (**Read the pact**; walking up opens nothing) shows the pact (`PactPanel`, in the RPG skin, the game paused): its lore line, then three cards,
**the rule** in plain words (and that the door seals until every foe is slain), **kept** (in
green: a choice of relics, as after a boss) and **broken** (in red: the max Health this hero would
lose, and what would be left). **Swear the pact** sinks the stele and opens the door; **Leave**
changes nothing (Interact asks again).

Walking in seals the door and the waves come, as in an ambush (`AmbushRoom`: `PactDef.waves` of
`wave_size` foes, +1 every 3 floors). The rule is watched on a copy of `PactDef.rule` (a
`PactRule` subclass: each listens to the hero for its own thing) until the last foe falls:

- **Kept**: the sigil turns gold, a burst of light, a banner and a toast, and a choice of
  `relic_choices` (3) relics (rare perks) a moment later. It waits in the run's offers, so a save
  keeps it.
- **Broken**: at once, `max_hp_cost` of the hero's max Health is lost for the rest of the run (in
  the hero's save), a banner and a toast say how much. The fight goes on; the door opens once the
  waves are slain, and the relic is lost.

During the fight a line under the map (`PactLine`) names the pact and the rule's state: gold while
it holds, red once broken, green once kept; the minimap outlines the room.

| Pact (FR / EN) | Rule | Fight | Broken costs |
|---|---|---|---|
| Pacte de l'Intouché / Pact of the Untouched | take no damage until the last foe falls (`DamageTakenRule`, 0%) | 2 waves of 2 (+1 / 3 floors), the last led by an elite | 12% max Health |
| Pacte du Glas / Pact of the Knell | slay every foe within 30 s + 2 s per floor below the first, from the door sealing (`TimeLimitRule`); the countdown is on the HUD | 2 waves of 3, the last led by an elite | 12% |
| Pacte du Jeûne / Pact of the Fast | no potion, bomb or scroll (`NoConsumableRule`) | 3 waves of 3, the last led by an elite | 10% |
| Pacte de la Dîme / Pact of the Tithe (from floor 3) | lose no more than half your max Health in all (`DamageTakenRule`, 50%) | 2 waves of 1, every foe an elite | 15% |

Any damage counts for the Untouched and the Tithe (blows, shots, traps, burns, falls); a blow a
ward soaks whole does not.

**Where**: `dungeon_config.tres` > Pacts: `pact_chance` (0.7) per normal floor, never the first
floor nor a boss floor, one at most. It also needs a room that can be sealed without cutting
anything off (`PactRoom.find_room()`): not the first room, no stairs in or by it, a single door on
one side (at most `corridor_width` + 3 cells), and the rest of the floor still joined without it.
About half the floors have one free (the merchant's and the smith's rooms are taken first, the
ambush never takes it), so about **a third of the floors** get a pact door (measured: 55 on 175
floors). Nothing else goes in the room: no monsters, chests, encounters, hazards or items. The
pact and its room come from the floor's seed (`PactRoom.floor_rng()`, its own generator so the rest
of the floor is the same with or without it): a daily run has the same pacts for everyone.

**Saves**: a floor's save (`World.spent_data()`) says whether its pact was sworn. A resumed run
rebuilds the floor with its door open and spent: never offered again. A pact left half-fought by
quitting is lost (no relic); a cost already paid stays paid.

The first pact door seen brings a tutorial hint. Debug panel: "Pact door" spawns one of each in a
dead-end room of the current floor.

## Room trials

A floor may hold a trial (« épreuve », `RoomTrial`, `data/trials/`, `TrialDef`): something to do
besides reaching the stairs, optional, in the Well's voice. **One thing of its own a floor**: only
a normal floor past the first with no curse and no floor event (cold, night, heat...), never a
boss floor, and a floor with a trial has no pact door (`DungeonConfig` > Room trials:
`trial_chance` 0.45 of those floors). It comes from the floor's seed (its own generator,
`RoomTrial.floor_rng()`: the rest of the floor is laid the same), so a daily run has the same.
As the floor begins a banner names it and the log says its call; under the minimap a line says
its objective ("Souls freed: 2 / 4", `TrialLine`); the minimap marks what is left to do once
seen; each step is a toast, the end a banner ("Trial done") and the log's last line. Each step
brings foes (`foes_per_step`, +1 every `depths_per_extra_foe` floors). Done, it pays
(`bonus_souls` to the run, paid at its end like the hidden floor's; `relic_choices` relics if
any: the Game, on `Events.trial_completed`). A floor's save keeps its steps done (`"trial"`): a
resumed floor finds them done again, quietly (no foes, no reward again). A partly freed soul
also keeps its progress and whether its foes were already called, so resuming beside it never
calls a second wave. Older saves without that state start untouched souls normally. Debug panel:
"Room trial" lays one on the current floor.

| Trial (FR / EN) | What to do | Each step | Reward |
|---|---|---|---|
| Les Âmes de Kagari / The Souls of Kagari | free 3-4 souls held by chains of tar in the floor's biggest quiet room: stand by each for 3 s (stepping away stops the count, it is not lost) | the first moment by a soul, the Well sends foes to take it back; freed, it rises (spirit nova, light) and gives back 6% of max Health | 25 souls |
| Le Sceau Défait / The Unbound Seal | light the 5 lanterns standing cold in other rooms (Interact: "Kindle"); a dead-end room is shut behind violet spikes, a star drawn before its door, a point for each lantern | the dark answers each lantern with foes around it; its point of the star lights | the door opens on its hoard (a big chest, seen through the bars all along), 15 souls |

The souls are villagers' figures (the merchant's, the smith's, the Vigil-Keeper's frames),
washed pale and see-through in spirit's ramp, a soft halo behind them (`CaptiveSoul`); the seal's
star and the lanterns' flames are drawn on the art's grid at 8 and 12 fps (`SealTrial`,
`SealLantern`). The trials' lore: the souls Tôma gave to the Well on the moonless night; the seal
whose knots he undid, tied back here one flame at a time (docs/lore.md).

## Creation ownership

`WorldSpawner`, owned by World and given its layers explicitly, creates entities, projectiles,
loot and their ranks/placement. Public World methods delegate to it. Floor generation, rules,
activity, saving and geometry remain their existing components; no spawn ordering or floor
dice change. The twelve recorded floor fingerprints stay unchanged after normalizing only
the save-reference spelling (version 3 ids back to the recorded legacy paths).
