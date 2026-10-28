# Tests and debug tools

## Getting Godot

The tests and tools need the Godot **4.7** editor binary (desktop, not an export template). On a
machine without it, the Linux build from the official release works headless:

```
curl -sSLO https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip
unzip Godot_v4.7-stable_linux.x86_64.zip   # then call it instead of `godot` below
```

On a fresh clone (no `.godot/` folder), import the project once first, or the first run fails on
missing resources: `godot --headless --import`. Errors printed by the import itself are normal on
the first run.

## Running the tests

From the project root:

```
python3 tools/run_tests.py                                                       # everything, in parallel: 3 to 4 min on 2 CPUs
godot --headless --fixed-fps 60 res://tests/run_tests.tscn -- --only=unit,title  # fast, about 1.5 min
godot --headless --fixed-fps 60 res://tests/run_tests.tscn                       # everything in one process: about 5 min
```

### Fast: in parallel, a test alone, a seed, the timings

Every suite is cut into **tests** (`TestSuite.test_cases()`), each run alone by the runner after
the shared state is put back (`_reset()` in `tests/run_tests.gd`: the profile, the settings as the
runner set them, the online layer, the touch device, no key held, no pause, no cheat, no run
save). A game test begins on a fresh `Game` (`GameTests._new_game()`: its first run on floor 1, no
act cards, the statistics accepted on a fake server; the floors' and weapons' tests on a hero of
Armor 999, `_on_sturdy_game()`). So any test runs alone, in any company, in any process. Names:
`unit.generation`, `game.pacts`, `title.pc`, `tutorial` (`--list` prints them all).

- **In parallel:** `python3 tools/run_tests.py [--jobs N] [--only=...] [--test=...] [--seed N]
  [--timings]` starts N Godot processes (default: one per CPU), each on its share
  (`--shard=i/N`), and merges what they print: every `FAIL:` with the test it came from, the
  checks per suite, the slowest tests, `N checks, M failed`, the wall and CPU time. Exit code =
  failed checks, plus one for a process that crashed or hung. Each process has its **own user
  folder**: `XDG_DATA_HOME` points at a new temporary folder (Linux; `config/custom_user_dir_name`
  stays as it is), so no process reads another's files, nor the real game's: the plain command
  reads and writes the user folder that every worktree and the game share. Every process's whole
  output stays in the log folder printed at the end: read it for engine errors (below).
- **Shares:** `--shard=i/n` (0-based) takes the i-th of n shares, balanced on each test's last time
  in `tests/timings.json` (the longest first, each to the lightest share; an unknown test counts
  5 s). `python3 tools/run_tests.py --save-timings` writes it again after a run: do it when tests
  are added or grow.
- **A test alone:** `--test=game.pacts,unit.generation` (full names, a suite's name, or a pattern
  with `*`: `--test='game.*abyss*'`), with the godot command or the Python one.
- **Seeds:** the run's seed is printed first (`Seed 1234`); `--seed=1234` plays it again. Each test
  seeds the global random numbers and its runs' worlds (`Game.seed_runs()`, every new run takes
  the next seed instead of a random one) from the seed and its own name, so a test plays the same
  floors whatever runs before it or beside it. A failure is replayed with
  `--seed=<the run's> --test=<its test>` (what the physics and the frame order do is the same
  run to run headless; anything that reads the clock is not).
- **Timings:** `--timings` prints every test's time at the end, slowest first. A test stuck for
  15 minutes (a coroutine that never resumes) fails and stops its process (`TEST_TIMEOUT`).

Where the time goes (2026-10-24, 2 CPUs shared with other work): a floor build is about 0.7 s
(generator, dresser, populator, nav grid, walls, ceiling: `World.build_floor()`; the rest of
`Game._enter_floor()` adds about 5%, so building floors without a Game gains little), a fresh
Game about 1 s. The slowest tests are the floor sweeps (`game.levels`, `game.pacts`,
`game.bodies_fit`, `game.biomes`, `unit.secret_rooms`, `unit.generation`), the title screen,
`game.saves` and the tutorial. A new test that builds floors in a loop shares its floors with
the checks that need the same ones (`LevelTests._note_ceiling()`) rather than build them again.

The suites (`tests/suites/`, each a `TestSuite`):
- **village** (`VillageTests`, registered as `unit.village`, `title.village`, `game.village`):
  ordered quests and atomic purchases, failed-write rollback, persistent memorials and ending
  receipts, the real hub's movement/dialogues and saved-run protection, and quest evidence on
  procedural floors. `game.finale` also recovers an already committed ending while paused.
  Village checks also cover chained prerequisites, both infestation fronts, optional questions
  without progression side effects, translated proximity lines, sleeping echoes staying put,
  awake patrols, moving interaction targets, modal stops and no teleport on purchase.
  The isolated rendered review is described in [Kagari](design/village.md#validation).
- **unit**: the rules, the content database, 100 generated maps (and their walls), 40 boss arenas,
  inventory, equipment, perks, bosses, the profile, the online leaderboards' queue and filter
  (`LeaderboardTests`, on `FakeBoardBackend`: a server in memory), the privacy rules, the gameplay
  statistics and the credits' data (`PrivacyTests`), the world counters (`WorldStatsTests`), the remote settings (`RemoteConfigTests`), player feedback (`FeedbackTests`), what the online
  services share and their start-up in a release build in many orders (`OnlineSessionTests`),
  Talo's answers as `TaloBackend` reads them (`TaloContractTests`, a transport in memory). No
  game running: fast. A test that needs the release-only paths sets `OnlineSession.release_mode`;
  one that needs its own `user://` file names it per process (`OS.get_process_id()`): with the
  plain godot command, every worktree and every run shares one user folder (tools/run_tests.py
  gives each process its own).
- **title**: the title screen and its panels (the Leaderboards page with and without a server, the
  statistics' questions, Options > Privacy, the policy and the credits, the world counters' line
  and the Well's Toll page, the remote settings' event plaque and message of the day; the feedback
  form on the title, in French on three screens, and from the pause menu with a gamepad; typing on
  a phone with a fake keyboard, `SoftKeyboardTests`: the scale kept, the typing bar in the strip).
  No suite ever reaches the network: the runner gives `Leaderboards` an offline backend first,
  and `Privacy`, `Telemetry`, `WorldStats`, `RemoteConfig` and `Feedback` no file (docs/online.md, Tests). The game suite plays its run with
  the statistics accepted on a fake server and checks what its end sends.
- **game** (`GameTests`, about 70 tests, each on a fresh Game): a bot plays the real game (kills,
  level ups and perk choices, stairs, death and restart: `game.run`; saving and resuming, a
  mortal run deeper), then **combat** (projectiles, perks, skills,
  monsters and their traits, difficulty, weapons), **floor** (props, hazards, chests, ambushes,
  encounters, pact doors, the merchant, loot, curses, biomes, act cards, the belt; on 12 more
  floors, no body put down inside a wall or a prop), **boss** (a full boss fight
  with its phases and relic, then winning the run) and **finale** (the bottom of the Well after a
  win: the gate, saves around it, Tôma, the Maw's jaw, the endings, and with Boss stories on
  their meetings, last words and deeds; then the Nameless Keeper waiting instead of them: his
  gear, look and skills, a fight on a sturdy hero, his fall the last, the choice again, the
  debug panel's way down). The Keeper's rules and data (`keeper_tests.gd`, `KeeperTests`: the
  snapshot, the profile and the run keeping it, the boss built from it, his numbers) run in the
  unit suite.
- The story (`story_tests.gd`, `StoryTests`): its unit part runs in the unit suite (every
  warden's chronicle, lengths and translations, the reveal rule, conditions, deeds, what a meeting
  tells, fragments, the codex's Chronicle, the option), its game part at the end of the game suite
  (the cinematic in an arena, skipping, no replay on a run picked up again, Short and Off, a deed,
  fragments on the floors and their panel). The runner turns Boss stories off for every other test
  (`Settings.boss_stories`), as it does the tutorial hints; the story tests turn them on.
- The first minutes and the help (`first_run_tests.gd`, `FirstRunTests`, decisions 0010 and 0011):
  its title part (the first Play going straight down on Keeper, the privacy questions first, the
  time from launch to the first monster noticing the hero, story skipped, under 30 s at 60 fixed
  frames a second), its game parts as `game.first_steps`, `game.descend_again`, `game.assist`,
  `game.lower_difficulty` and `game.hints`. The runner turns the first runs' gentle start off for
  every other test (`FirstSteps.enabled`: a fresh profile's floor 1 would shelter the hero and
  change its first room's monsters); `first_steps` and the launch test turn it on.
- Keyboards, mice and gamepads (`pc_tests.gd`, `PcTests`): its unit part in the unit suite (the
  device in use from keys, gamepad buttons and sticks with the dead zone, touches and the mouse;
  the prompts per device and gamepad family; the input map; the settings; the canvas's scale at
  every screen size; MenuNav on a little menu), its title part in the title suite (the title's
  panels with keys: move, accept, Back, tabs; their layouts at every size; then a game begun in
  French: every in-run panel with its longest words inside 1280x720, 1540x720, 2340x1080 and
  2548x1296, `_test_french_panels()`), its game part in the
  game suite (the HUD per device, the mouse in a fight, pausing, every in-run panel with keys and a
  gamepad, the HUD's layout at every size, on touch and on keys). The runner starts every suite on
  touch (`InputDevice.use(TOUCH)`): the other tests play the phone's game.
- The bag's compartments, tabs and quick actions (`bag_tests.gd`, `BagTests`, on PcTests'
  helpers): its unit part in the unit suite (which compartment every item lands in, each one's
  own places, upgrades, an old save's list coming back past its places, the order in a tab,
  which dismantles ask first, the actions and their keys), its game part in the game suite (loot,
  auto loot and the merchant asking the item's compartment, a full tab, Dismantle the worse per
  tab; the bag on
  touch: tabs tapped, the card's buttons, new marks, the tab remembered, a right click; with a
  gamepad: LB / RB, A, X, Y, B, the confirmation for rare pieces, what is worn never broken; with
  keys: Q / E, Enter, X, Delete, G, Escape, Alt+Enter and F11 switching fullscreen and nothing
  else; and the bag inside a 1280x720 screen in French).
- The dialogue (`dialogue_tests.gd`, `DialogueTests`, on PcTests' helpers): its unit part in the
  unit suite (every speaker's lines: lengths, translations, codes, the reveal; the tale and the
  advice a staged death gets: a warden, its shockwave, a trap, the Deeps, the cold, the Threshold,
  early deaths again and again, potions left...; once, cooldowns and turns; the keepers' lines
  gated and kept; the save; the codex's Voices; the DialogueBox by touch, keys and gamepad), its
  title part in the title suite (the Vigil-Keeper at the shrine by touch, keys and gamepad, the
  lamps, her box at every size in French), its game part in the game suite (a real death told on
  the end screen, a trap's, the fallback line, the merchant's and the spirit's lines, the end
  screen in French at 1280x720 and the phones' sizes).
- The gameplay's core (`core_tests.gd`, `CoreTests`): its unit part in the unit suite (the numbers
  moved from code to data kept their values: combat rules, the hero's feel, the bosses' shockwave,
  chase and wander, ambushes, drops; FloorRules' answers equal the old hand-made products over
  every depth, difficulty, event and curse; the one twist roller and the ways down roll as before
  on the same numbers; the loot odds told are the odds rolled; each effect kind dresses itself;
  the same dice give the same hits), its game part in the game suite (a delayed heal and a
  delayed blast credited to what set them off; the floor's combat dice, apart from its own
  rolls; an encounter's gold and odds with the run's boons; an arrow trap's volley stopping out
  of the tree).
- Same seed, same floor (`floor_determinism_tests.gd`, `FloorDeterminismTests`, in the unit
  suite): floors of every kind (plain, cursed or plain by the debug panel, reached by a chosen
  way, with two ways down, a warden's, the hidden floor, the bottom of the Well) and one picked
  up again after things were used up on it, built on a World alone from fixed seeds, each
  fingerprinted (map, rooms, twist, world, every monster, item, prop and chest, the save's
  floor, the dice's state) against values recorded before the World was split. A refactor
  leaves them as they are; a change that moves them on purpose (content, generation) records
  the new values, which the failure prints.
- The floors' identity (`level_tests.gd`, `LevelTests`): its unit part in the unit suite (the
  room shapes' geometry; 20 floors a biome at every difficulty's size: one piece, solid walls,
  start, stairs, hearts and cracks on open ground, every listed shape used, a signature room now
  and then and never two; the Deeps' maze), its game part in the game suite after the biomes
  (built floors: nothing in rock, a chasm or a pool, chasms are holes, pools water, pillars
  standing, every open cell reachable, the minimap's round rooms; every biome's ceiling on the
  grid, its layers, its fade over the hero and a monster, none over an arena; every signature
  room forced on a floor, dressed, named once on a banner).
- **tutorial**: the hints' data, the first steps played with the real controls, the hints that come
  up once, menus, the options and the profile.

The runner prints `FAIL: <what>` for every failed check, a count per suite, then
`N checks, M failed`. The exit code is the number of failures (a suite that doesn't compile counts as
one).

**Engine errors fail the Python runner.** `tools/run_tests.py` counts every `SCRIPT ERROR:` and
unexpected `ERROR:` as a failure, even if the interrupted test prints no failed check. Only the
known resource/RID leaks explicitly reported **at exit** are exempt. Direct Godot runs still
return only failed checks: inspect their output. Damaged JSON is parsed quietly by `SafeFile`;
`WARNING: Run save: ...` from intentionally damaged/too-new saves remains expected.

`unit.audit_regressions` releases suspended network operations by signals to exercise uploads
changed in flight, sign-out/account changes, consent withdrawal, and stale Talo identities.
It also covers rejected profile writes, debug isolation, temporary-run recovery, status buffers,
shared frost atlases, translated offers and belt tuning. `game.trials` resumes a partly freed
soul; `game.status_looks` reaches the checks after returning to a pooled material.
Host-side checks: `GODOT=/path/to/godot python3 -m unittest discover -s tools/tests -v` tests the
runner's error classification and (Linux) forces a real short write with `RLIMIT_FSIZE` in an
isolated temporary Godot project, verifying that the previous save survives.

**Design rules** (`tools/design/check.py`, [art-bible.md](art-bible.md)): `tools/run_tests.py` runs
them first, whatever `--test` says, and prints breaks as `FAIL: design: ...`: every file under
`assets/` has its source in `REUSE.toml` with an approved licence; the world art's pixels are in
`assets/palette/world.hex` (needs Pillow, skipped with a note without it); no StyleBox built
outside `src/ui/common/`; no media outside `assets/`; AGENTS.md under 200 lines. The village
layout rules are `unit.village` (`VillageTests._test_layout_rules`). **Captures** for visual work:
`python3 tools/design/capture.py [outdir]` (village, whole map, temple, a conversation; 2340x1080,
1920x1080, 1280x720; each with a x4 zoom and a greyscale copy; needs a display, or xvfb-run).

- **balance** (opt-in: only with `--only=balance`): the balance tools' quick runs against the
  targets of `data/balance/targets.tres`. Some of its checks fail on purpose today (the balance
  work to do): they are printed as `FAIL (KNOWN ...)`.

**The same run twice is not the same run:** floors, loot and fights are random, so a check that
fails once and passes on a rerun is a flaky test, a bug to find (below), never a retry. The game
and tutorial suites were hunted for them on 2026-10-22 (one game run in three failed before).
Cutting the game suite into tests (2026-10-24) showed three more, each fixed in its setup: the
tutorial failed 3 checks whenever it ran after the game suite in one process (state left over,
now put back before every test), a boss win's record was compared to the second while records
keep milliseconds (two runs in three), and the Brood Mother's brood check needed a floor with
room for it (`SummonEffect.max_alive`). Replay one with its seed (above).

### No GDScript warnings

The editor's warnings (a local shadowing a property, an integer division, a static function
called on an instance, an unused signal, a needless `await`...) never show in a headless test.
The project is kept at zero; check it before calling a change done:

```
python3 tools/lint/gd_warnings.py      # prints them, exit 1 if there is any (about 1 min)
```

It starts a headless editor with its GDScript language server (`--lsp-port`), opens every script
of `src/`, `tests/` and `tools/` in it, prints what the server reports for each (warnings and
parse errors, with the project's own warning settings) and stops the editor. Godot is found as
`--godot PATH`, `$GODOT`, `godot` on the PATH, or a downloaded `Godot_v4.7-stable_linux.x86_64`
(the root, `_tool/`, `/tmp`); the project must have been imported once. The editor re-saves
`default_bus_layout.tres` when it starts: the tool puts it (and the project settings and the
roadmap) back as they were. Android's build template (`android/build/`, which carries its own
`.gdignore`, so the editor never scans it) is not ours and is left out. How to fix each kind:
docs/conventions.md, "No GDScript warnings".

## Writing a check

Each suite extends `TestSuite` (`tests/support/test_suite.gd`); its `test_cases()` lists its
tests ([name, Callable]; a suite of one piece keeps `run()`), and `before_cases()` /
`after_cases()` set up and put back what they share. A new game test is one more entry in
`GameTests.test_cases()` (`_on_game(...)`): it must hold alone, on a fresh Game, so set up what it
needs (never count on a test before it). Inside, `check(condition, "what should be true")` counts a check and prints the message
when it fails, so write the message as the rule ("projectiles stop on walls"). Game suites get the
real `Game` scene and wait with `await _frames(n)`; helpers find open cells, clear monsters, count
things on the floor and let a bot play (`_bot_play`). The runner sets English, empty save paths and
no tutorial hints, so a test never touches a player's files.

A rule fix comes with the check that would have caught it. Never weaken or skip a check to get a
green run; a balance target that can't be met yet is listed as known in the balance suite.

### Checks that hold on every floor (no flaky tests)

The game suites play real, random floors: a check passing once proves little. A check that fails
now and then is a bug, in the test's setup or in the game. Make the setup sure, keep the assertion:
- **Where:** never a fixed offset from the hero (a wall, a prop or a hole may be there). Ask the
  helpers: `_open_cell_near()` (open floor all around), `_clear_lane()` (a straight run of solid
  floor that a dash or a shot crosses: `_clear_ray()` tests the world's physics layer, which props
  are on, unlike `has_line_of_sight()`), `_free_points_away()`, `_point_without_props()` (where a
  blast breaks nothing). A body put down by hand must fit there (`_body_fits()`: a wall's or a
  prop's shape can reach into a free cell, and a body put inside one never gets out).
- **Who else:** the floor's monsters wander in, shoot, push, spot the hero in the first frames.
  `_clear_monsters()` (before they move, if what they would cue matters), a dormant target,
  `invincible` on the hero when a stray hit would spoil the test (not when the hit is it). A
  blow's push carries the hero a cell in a frame: `_walk_into_hole()` keeps him out of reach until
  he lands. Traps fire on their own: pick the hero's own shot (`Projectile._shooter`), not the
  newest one.
- **Statuses and looks:** a body watched for its statuses stands at a `_quiet_point()`: in view
  (a monster off screen sleeps), away from fires, ponds, sand and traps.
- **At rest:** `_stand_still()` before comparing where the hero stands (a step of leftover
  knockback, or a deferred freeze one physics step later, moves him).
- **Time:** `_frames(n)` waits n physics steps, one a frame (1/60 s) with `--fixed-fps 60`; a hit
  stop or a slow motion scales what happens in a step, not how many there are. Wait for something
  with a generous timeout (`_until(condition, seconds)`, `_until_deeps()`, `_until_trial()`)
  rather than a guess of frames that a slower step would miss, and never a timer
  (`create_timer(1.5)` after a killing blow waited a different number of steps under the hit
  stop's slow motion: the end screen is waited for with `_until()` now).
- **Counting the floor:** `_floor_things()` and `_things_diff()`, not `get_child_count()`: passing
  effects (dust, sparks, a column of light) stand among the floor's entities and come and go, and
  the bodies of monsters slain a moment ago go when their death has played.
- **Hints (tutorial):** another hint of the floor may have its say first: `_until_hint()`.
- **Leftovers:** a test puts back what it changed (holes: `_fill_holes()`; perks, XP, statuses).
  A lambda connected for a test captures nothing that a later test may free (or is disconnected).
- **Diagnose:** a check's message says what it saw (counts, distances, states), so one failure in
  a long run is enough to find the cause.

## Debug tools

In debug builds only (running from the Godot editor, on the phone too, or a debug export), a
**DBG** button next to pause (or F1) opens the `DebugPanel` (the game pauses). It has six tabs,
switched by a tap or a click, or with Q / E and a gamepad's LB / RB like the bag's; keys and a
gamepad move between its buttons (MenuNav). A toggle says its state ("Invisible: ON") and a
step its value ("Damage x5"), and both stay pressed while on.

- **World**: pick a depth and go there, next floor, rebuild the floor (plain unless you choose a
  **Curse** or a **floor Event** row: the floor is rebuilt with it, its card included,
  `World.overrides`, FloorOverrides). **Places**: the next boss floor, the hidden floor, the
  Deeps (as if the hero fell into a hole), the **Dawn Breach** (the hero a few steps from the
  Deeps' way out, down into them first if need be: `GameDebug.to_dawn_breach()`), the
  **Threshold trial** (the trial of a second life at once, no killing blow, no feather spent:
  `GameDebug.enter_threshold()`; lost, the hero dies as for real), the bottom of the Well (the
  final fight, FinaleDef), the Nameless Keeper (the bottom with the Keeper made from the hero as
  he is now).
  **Move**: to the stairs, to the boss room's doorway, to the next room, break the stairs' seal,
  **Reveal maps** (this floor's map and every next one's, seen as they begin). **Encounter**:
  pick any encounter and place it beside the hero; **Boss story** has the floor's warden tell its
  story again (its cinematic, `GameDebug.boss_story()`; nothing with Boss stories off).
  **Fragment**: pick any fragment of the past (with its warden) and place it beside the hero.
  **Pact door**: one button per pact: seals a dead-end room of this floor behind its door.
  **Aura**: **Next aura** puts each aura on the hero in turn (locked or not, then none), for
  this run's look only: not a debug run, the Wardrobe's choice unchanged.
- **Hero**: the cheats, kept across floors until the run ends (`DebugCheats`): god mode (nothing
  hurts), **Invisible** (monsters never notice him, and forget him if they had), **No
  cooldowns** (skills and the roll ready again at once), and three steps: **Damage** dealt
  x1 / x2 / x5 / x10 / one-shot, damage **Taken** x1 / x0.5 / x0.25 / x0.1 (at least 1 a blow),
  move **Speed** x1 / x1.5 / x2 / x3. Then full heal, +500 gold, level up, **Kill hero** (a blow
  nothing turns away: the end of the run, or the Threshold with a second life), freezing /
  burning / normal temperature, an Epic weapon, every consumable, every rune, the smith here, and
  **Give**: any weapon, armor, consumable, tome, rune, key, perk or relic, picked from its list.
- **Monsters**: **No AI** (every monster, bosses and new ones too, stands still: no step, no
  blow, no spell, no shockwave; a knockback still moves it), kill all, put all asleep, spawn any
  monster or boss of the game (plain, elite, or at a rare rank), make the next boss of a rank.
- **Gallery** (`DebugGallery`): pick a **Biome** (the nine of the acts, the bosses', the Deeps', the
  hidden floor's, the bottom of the Well's), its **Rooms** (as usual, every room but the first in
  one of its room shapes, or its signature room, marked with a star, for sure) and a **Ceiling**
  (its own, none, or any biome's), then **Build this floor**: a plain floor of its act, its map
  revealed. **Monsters of** an act (with its bosses), the hidden floor, the Deeps, the bottom of
  the Well or everything, then **Monster gallery**: a hall in the chosen biome's look, every one
  of them standing in rows, its name under its feet (none with the camera zoomed far out),
  bosses last; it turns No AI, Invisible and Full light on, to walk among them.
- **Tools**: the game's **speed** (x1 / x0.25 / x0.5 / x2, under the hit stops: `HitStop`), the
  camera's **zoom** (x1 / x0.75 / x0.5 / x0.35), **Full light** (every floor at its brightest,
  `World.relight()`), **Bodies & reach** (`DebugShapes`: each body's circle, the hero's weapon
  reach, each monster's attack range in red and how far it notices the hero, a line to its
  target, every area's collision shapes in orange: traps, shots, hazards' reaches, and the ground
  strikes still to land in magenta: a boss's delayed spells), **Frame rate** (`DebugOverlay`: frames per second, monsters awake / on the floor,
  shots in the air, nodes, draw calls), **Save & reload** (saves the run and picks it up again,
  as the title's Continue would; not in a debug run).
- **Remote**: the remote settings (`RemoteConfig`, docs/online.md "Remote settings"): every key of
  the allow-list with its value in use, last read and simulated, what was ignored and why, the
  kill switches; **Read now**, **Apply now**, and **Simulate**: any key set to a sample value (in
  bounds, out of bounds, an unknown id, a date) as if the server had it, checked the same way and
  applied at the next safe point (Apply now, the title, a new run; the run going on keeps its own
  values). Debug builds only; it doesn't make a debug run.

A line at the top of the screen names the cheats on, and says when the run is a **debug run**:
anything the panel does to the run (all but the Tools tab's views and the game's speed) makes it
one, and nothing of a debug run is kept: the run is never saved (the save stays as it was
before the first cheat), and the profile is saved once, then held (`Profile.held`) and read back
from its file when the run ends, dropping the souls, kills, records and achievements it gave.
Every cheat ends with the run (`Game._begin_run()`, leaving the game). Checks: `DebugTests`
(tests/suites/debug_tests.gd), from the unit and game suites.

Release exports have no button and no panel (`DebugPanel.is_available()`), and every
`DebugCheats` setter refuses outside a debug build: the hooks in `Actor`, `Monster`, `Player`,
`SkillSet`, `HitStop`, `GameCamera` and `World` stay inert.

## Architecture and reference regressions

`unit.architecture` checks every registered content reference, version 2 -> 3 migration,
rolled gear, removed/unknown targets, historical paths after relocation, shared skill ids and
idempotent cross-service wiring. The existing startup-order matrix now calls OnlineService's
typed boot/settle methods. `unit.floor_determinism` keeps every original fingerprint field;
it normalizes stable ids to the legacy reference spelling before comparing recorded hashes.
Game suites exercise the same public offer and spawning entry points after their extraction.

`python3 tools/saves/build_catalog.py --check` checks shipped registration. Host tests
(`python3 -m unittest discover -s tools/tests -v`) also verify alias preservation after moves,
rejection of historical-path reuse and duplicate ids, and separation of root/subresource ids.

## Monster modifiers

`unit.modifiers` checks ordered composition, resource deduplication, independent states,
immutable definitions, repeat ranking, tag/depth/species eligibility and symmetric exclusions.
`game.modifiers` applies Pestilent, verifies poison and expiry (ticks must not refresh their own
payload), saves/restores its id/modules/remaining Health, and checks the delayed death warning
and the absence of a burst after a fall. Existing combat/rank and save suites cover legacy
perks. The additional modifiers test Health thresholds, slow interaction, healing out of frenzy,
cold payload/expiry, actual Vampiric healing through Armor and ward absorption, riposte counting
and cooldown, rejection of secondary/lethal blows, dormant periodic clocks, fixed warning spots,
fall/floor cancellation and save/restore of all four ids/modules with fresh transient state.
Floor fingerprints intentionally change only for cases affected by the expanded pool from
floor 3; FLOOR_FORMAT 3 protects older floor ledgers. Device checks remain in the roadmap.


## Roguelike entry and retained lifetime regressions

unit.roguelike_entry asserts the actual project main scene is the roguelike title. The historical
unit.rpg_foundations/game.rpg_foundations names now cover shared command/session regressions:
independent/reused inputs, mute/detach and stale death/descent/fade continuations after restart.
The game checks also cover reentrant item/gold pickup, weak targets and generation-bound deferred
spawns/items/coins, and immediate world teardown before shader warm-up. No RPG campaign mode is
loaded by these tests. Product-specific campaign tests/documents remain in the
[separate-project archive](rpg-archive.md). Existing roguelike assertions are retained.
