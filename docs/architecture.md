# Architecture

How the code is laid out and how the pieces talk to each other. Code rules are in
[conventions.md](conventions.md); what each system does for the player is in [design/](design/).

## Project layout

```
assets/              Art, audio, fonts and the UI theme (Ninja Adventure pack)
  characters/          Hero and monster sprite sheets (4 directions, frame by frame), bosses/
  weapons/             Weapon icons + attack/ sheets (the weapon in hand, per direction and frame)
  fx/                  Sprite-sheet effects: slashes, claws, explosion, smoke, magic, flames
  props/               Crates, vases, barrels, powder kegs, lanterns, chests, trap pieces, holes, quicksand
  projectiles/         Arrows, fireballs, magic bolts
  items/               Item icons
  tiles/               Dungeon floors, cliffs and walls
  ui/                  Wood UI, round buttons (sphere/), icons, skill icons (skills/), perk icons (perks/), emotes
  fonts/               Pixel font
  audio/               Sound effects (sfx/), music (a track per place: docs/design/presentation.md "Music"), ambience beds and jingles
  shaders/             Rig (hit flash + death dissolve), screen look, damage vignette
  theme/               main_theme.tres: pixel UI theme used by every Control
data/                Game content as .tres resources (no code)
  content_db.tres      Index of everything that can spawn
  player/              Starting stats, kit, skills, leveling, the hero's feel (i-frames, aim ranges, swap cooldown)
  combat/              combat_rules.tres: the core combat numbers (crit, variance, armor weight, cooldown cap)
  dungeon/             The run (acts/), floor size, difficulty curve, floor looks (themes/)
  biomes/              The worlds a floor can be (one per file) and their hand-made scenes (scenes/), room
                       shapes (shapes/), signature rooms (set_pieces/), ceilings (ceilings/), pools (pools/)
  visuals/             SpriteFrames: hero.tres, monsters/, weapons/ (the animations themselves)
  audio/               Sounds as AudioStreamRandomizer (variations + pitch), sound_bank.tres, sound_mix.tres
  monsters/            One file per monster type, bosses in bosses/
  perks/               Level-up perks (common/) and boss relics (relics/)
  upgrades/            Shrine upgrades (bought with souls between runs)
  difficulties/        Pilgrim, Keeper, Martyr, Nightmare
  story/               story.tres: the game's name, the intro, victory and death texts; narrative.tres (how the
                       story is told), chronicles/ (each warden's), fragments/, fragment_looks/, conditions/
                       (shared reveal gates), cinematics/ (the boss meetings' steps); finale.tres (the bottom
                       of the Well) and its endings (endings/); dialogue/ (who speaks and what: the
                       Vigil-Keeper's tales, advice and shrine words, the keepers' lines; speakers/)
  props/               Breakable props and the lantern
  hazards/             Traps, arrow traps, holes, crumbling floor, quicksand and mud
  chests/              Chests (some trapped) and the big chest of ambushes
  elites/              Elite affixes (Swift, Vampiric, Bursting...)
  affixes/             Item affixes for Magic, Rare and Epic equipment (Sharp, of the Bear...)
  shop/                The merchant (stock, prices, look)
  encounters/          Spring of the Drowned, Blood Altar, Grinning Spirit, Keeper's Statue
  secrets/             What secret rooms hold (SecretRewardDef), the hidden floor (HiddenFloorDef)
  items/weapons/       Player weapons (monster/ = monster-only weapons)
  items/armors/        Head and body armor
  items/consumables/   Potions, scrolls, bombs...
  items/bag_categories.tres  The bag's compartments (tabs): which items go in each, their places
  items/tomes/         Skill tomes (teach a spell)
  skills/              Player, monster and boss skills
  leaderboards/        The online leaderboards (leaderboards.tres: LeaderboardsConfig) and their boards
                       (boards/: LeaderboardDef), see docs/online.md
  online/              privacy.tres (PrivacyDef: the contact placeholders, the consent rules, the short
                       policy), telemetry.tres (TelemetryDef: the statistics' events and fields),
                       world_stats.tres (WorldStatsDef: the world counters, the Well's Toll),
                       remote_config.tres (RemoteConfigDef: the remote settings' allow-list, RemoteKeyDef)
                       feedback.tres (FeedbackDef: the feedback form's categories and limits),
                       online_session.tres (OnlineSessionDef: the refused identity's wait, the retries' backoff)
  credits/             credits.tres (CreditsDef: who made what, licenses and their files)
  ui/                  Loading tips, input_prompts.tres (the controls as the player is told about them: the
                       Controls page, the keys prompts show, the gamepad families' button names)
src/
  autoload/            Events (signal bus), Sfx (sound player), HitStop (impact freeze), Profile (save), Settings (options),
                       InputDevice (the device in use), MenuNav (menus with keys and gamepads), PixelGrid (the canvas's scale), SoftKeyboard (typing on a phone),
                       OnlineSession (what the online services share: the server, the device's player,
                       the consent gates, the clock), Leaderboards (the online leaderboards), Privacy (the player's privacy choices),
                       Telemetry (the gameplay statistics, with consent), WorldStats (the world counters),
                       RemoteConfig (the remote settings: Talo's game config, checked against the allow-list),
                       Feedback (the player's feedback messages and their queue),
                       Presence (Talo's live connection: play sessions and online presence, with consent),
                       Account (the optional Talo account), CloudSave (the profile saved online for it)
  online/              The online pieces: RunSummary (a run that ended), PlayerName (the pseudonym's
                       filter), BoardBackend (offline) > TaloBackend (Talo's REST API), LiveLink (the live WebSocket), RunTelemetry (what
                       the statistics learn of a run), RemoteTuning (what the remote settings change in a run, saved with it),
                       FeedbackInfo (the game's details a feedback message can carry), PersistedQueue (a
                       service's versioned file, bounded queue, flush latch and retry with backoff)
  core/                Small shared helpers (physics layers, weighted random, SafeFile, NumberText,
                       GridDirs: the grid's directions as consts, for loops that run often)
  definitions/         Resource classes describing content (the "schema" of data/)
    effects/             Building blocks for skills and consumables
    passives/            Building blocks for perks (on hit, on kill, on dash...)
    items/               ItemDef > EquipmentDef > WeaponDef / ArmorDef, ConsumableDef
    loot/                LootTable, LootEntry
    hazards/             HazardDef > TrapDef > ArrowTrapDef, PitDef, QuicksandDef, HeatSourceDef, DarkRoomDef
    monster_traits/      MonsterTrait > GuardTrait, ThiefTrait, DeathBurstTrait, DeathSpawnTrait, PerkTrait
    biomes/              BiomeDef, GroundLayerDef, DecorRuleDef, SceneDef (hand-made scenes), SceneKey
    input/               InputPromptsDef, ActionPromptDef, PadGlyphsDef (what a control is called on each device),
                         DeviceText (a sentence for touch and one for keys and gamepads)
    story/               The story: ProgressCondition (conditions/; conditions on the run that ended:
                         conditions/run/, RunCondition), DeedCondition (deeds/), chronicles, chapters, waking
                         lines, fragments, NarrativeDef, CinematicDef and CinematicStep (cinematic/)
    dialogue/            SpeakerDef, DialogueDef, DialogueLineDef (who speaks, what may be said, when)
  dungeon/             Map data, generator (its rooms' shapes: RoomPlan; its secret rooms: SecretRoomPlan), drawing
  world/               World (owns the current floor), FloorRules (how hard and rewarding it is),
                       floor_kinds/ (FloorKind: what kind of floor is built and its own steps),
                       FloorSave (the floor's part of the save), HoleField (holes and cracked floor),
                       ActivityManager (who sleeps; MonsterBuckets: the awake ones by cell), WorldSpace (free cells, bodies, line of sight),
                       FloorOverrides (the debug panel's next floor),
                       NavGrid (pathfinding), FogOfWar (what the hero has seen), WallBuilder,
                       FloorPopulator, FloorLedger (what the hero used up of what the seed laid, for the
                       save), FragmentPlacer, BossArena (and its Storyteller), AmbushRoom, RoomGates, PitLayer, SecretRoom; PocketWorld
                       (a World built beside the floor for a while) > ThresholdWorld (the limbo of a second
                       life's trial), AbyssWorld (the Deeps a fall takes the hero to);
                       dressing/ (FloorDresser: a floor in its biome, RoomSpace); RoomFeatures (the shaped
                       rooms' chasms, pools and pillars); ceiling/ (CeilingLayer: what hangs over the rooms)
  entities/            Actor (shared base), Player (PlayerControls, PlayerPack, PlayerSave), Monster
                       (MonsterSteering, MonsterDrops, BossBrain), rig/ (ActorRig, GearLook, RigAnimations,
                       BodyTops), Projectile, ItemPickup, Stairs, Prop, Trap, Fragment,
                       hazards/ (Chest, CrumblingFloor, Quicksand, HeatSource, DarkRoom, FloorPatch),
                       ground/ (GroundLayer: a biome's ground, drawn by a shader)
  components/          Inventory, Equipment, SkillSet, PerkSet, StatusSet (burn...), Belt, TimedBonuses
  combat/              Damage rules, hits, projectile specs
  ai/                  StateMachine + monster states (Idle, Chase, Attack, Cast)
  vfx/                 Particles (particles/), sprite-sheet FX, emotes, afterimages, damage numbers; Vfx helpers
  ui/                  Title screen and shrine, story, act cards, HUD and minimap, touch controls, the action
                       bar and mouse controls, prompts (Prompts, PromptGlyph), inventory (its tabs, BagTab, and
                       actions/: BagAction), perk choice, pause
                       menu, options (OptionRows; its Controls and Privacy pages), end of run;
                       common/: the shared pieces (OrnateBoard under RpgWindow / RpgDialog, TabRow,
                       ItemCard, TapGate, UiParts, UiSkin's colors: design/interface.md "Shared
                       pieces"). UI listens to Events and never drives gameplay: a quest is paid by
                       QuestBoard.pay_finished(), an oath sworn through Profile.select_oath()
  game/                Game: main scene, floor flow, pauses; RunAnnouncer (the presenter: Events ->
                       the HUD and the log); debug/ (GameDebug: the debug entry points, DebugCheats,
                       DebugGallery); RunState (the run: depth, kills, bosses,
                       difficulty), RunRecords (stats, bestiary, achievements, history), OfferQueue
                       (perk choices waiting), GameMenus (the panels), ShrineUpgrades, RunSave (on disk),
                       Threshold (a second life's trial: the floor out of the tree, the hero in a limbo),
                       Abyss (the Deeps under a floor's holes), SubWorld (the hero's stay in a pocket world:
                       his world out of the tree as it is, back as it was; stays nest),
                       HiddenPassage (the way to the hidden floor); story/: Narrative (the story's progress
                       and answers), BossMeeting (a warden met: its cinematic), CinematicDirector (plays a
                       CinematicDef's steps), StoryBeat (what one telling holds), Dialogues (what a speaker
                       says now), RunFacts (what is known of a run as it ends)
tests/               Headless tests: run_tests (the runner; suites unit, title, game, tutorial, and balance:
                     opt-in), suites/ (the suites and the helpers they borrow: combat, floor, boss, the
                     online services...), support/ (TestSuite: checks, scene helpers, the bot;
                     FakeBoardBackend: a Talo server in memory), timings.json (each test's last time: the
                     shares are balanced on it)
tools/run_tests.py   The tests in parallel processes, each on its share with its own user folder (docs/testing.md)
online/              talo.cfg.example: the form of talo.cfg, the leaderboards' access key (never committed:
                     docs/online.md)
locale/              strings.csv: every player text, English (the key) and French (see Languages)
tools/i18n/          extract.py (keeps the CSV up to date), add_glyphs.py (French glyphs for the font)
tools/levels/        level_art.py (the deep water, paper boats and the ceilings' atlases, drawn in the pack's
                     palette), level_shots (screenshots of shapes, signature rooms, ceilings, the big map)
tools/balance/       Balance tools (not exported): model, arena, packs, marginal values, economy, compound
                     checks; builds and targets in data/balance/ (see docs/balance.md)
tools/perf/          perf_probe (not exported): floor generation and a 40-monster fight timed headless
                     with fixed seeds (see docs/performance.md)
```

**Rule of thumb:** `data/` says *what* exists, `src/definitions/` says *what a thing can have*,
the rest of `src/` says *how it behaves*. Balancing never requires touching code.

## How things fit together

- **Game** creates the Player, asks **World** to build each floor and handles pause and game over.
  Every floor is reached the same way, `Game.transition_to_floor()` (the stairs, a run's first
  floor, the debug panel's). The Game keeps to the flow; what the run shows and says (a new act,
  a floor's twist and goal, a warden's name, fall and last words, the souls, the clock and its
  splits, ambushes, deeds) is the `RunAnnouncer`'s: it listens to `Events`
  (`floor_entered`, `split_timed`, `run_souls_changed`, the boss signals...), the World's
  `set_piece_entered` and the `RunTimer`'s `ticked`, and drives the HUD. Nothing in gameplay
  calls the HUD to announce (HiddenPassage and RunTimer emit). The debug panel's ways to a floor
  are `Game.debug` (`GameDebug`).
- **World** is the floor and the gateway to it (spawning, queries), made of focused parts so
  it doesn't grow back into one script: `build_floor()` does what every floor shares, always in
  the same order, and asks its `FloorKind` (`floor_kinds/`, chosen by `FloorKind.choose()` from
  the run's state: `NormalFloorKind`, `RouteFloorKind` for a way chosen, `BossFloorKind`,
  `HiddenFloorKind`, `FinaleFloorKind`, and `ForcedFloorKind` wrapping any of them for a debug
  twist) for its boss, twist, world, arena, map and what lies on it, so a new kind of floor is a
  new subclass. The save's part of the floor is `FloorSave` (`spent_data()` / `restore_spent()`,
  its format unchanged, with `FloorLedger`), the holes and cracked floor `HoleField`
  (`World.holes`), the sleep `ActivityManager` (`World.activity`), the spatial questions
  `WorldSpace` (`World.space`; the World keeps their one-line methods, `find_open_point_near()`,
  `is_solid_ground()`... since everything asks them), the debug panel's next floor
  `FloorOverrides` (`World.overrides`). Same seed, same floor: `FloorDeterminismTests` (unit)
  fingerprints a floor of every kind, and one picked up again, against recorded values.
- **World** generates a `DungeonMap`, rolls the floor's curse or event (`FloorRoute.roll_twist()`,
  the one roller, also the ways down's), builds its `FloorRules` (difficulty x event x curse x
  depth, and the run's boons for drops and gold: `drop_quality()`, `floor_gold()`; ask it, never
  multiply by hand), the walls (`WallBuilder`)
  and pathfinding (`NavGrid`), then lets `FloorPopulator` spawn monsters and items picked from
  `ContentDB` by depth. Anything can shake the screen with `Events.screen_shake`.
- **Actor** (base of Player and Monster) handles stats, HP, attacks, knockback, dashes and falls.
  Final stats = base stats + equipment bonuses + perks + timed buffs (`TimedBonuses`).
- **Entities are composed, not grown** (the three biggest scripts stay focused): a new job for an
  actor goes in a part it owns, the node keeping a one-line method only where many callers ask it.
  - **Actor** owns its components (`Equipment`, `SkillSet`, `PerkSet`, `StatusSet`,
    `SustainMeter`, `TimedBonuses`); what a blow taken shows is `HitFeedback`'s, its ward's look
    `WardVfx`'s, a body without a sprite `BodySketch`'s (src/vfx/). Who it is is asked, never
    tested: `strikes_in_carried_elements()` (the hero's hits wear his runes' elements: Combat),
    `_draws_ward_on_body()`, `_shows_gear()`.
  - **Player**: `controls` (`PlayerControls`: the input actions, the aim, the attack button, its
    charge and the skill and belt buttons; the Player acts: `attack()`, `unleash()`), `pack`
    (`PlayerPack`: picking up, the bag and the belt, wearing, drinking, dropping, dismantling;
    the UI's bag actions call it), `PlayerSave` (his part of the save, its format unchanged).
    The signals the HUD listens to stay on the Player.
  - **Monster**: `steering` (`MonsterSteering`: clear walks, sight, being stuck, spacing, holes;
    the AI asks the Monster's `has_clear_walk()`, `can_see()`, `is_stuck()`), `drops`
    (`MonsterDrops`: XP, loot, a rank's extras, runes, gold), `brain` (`BossBrain`, bosses only),
    and each trait's per-monster values (`trait_state()`, the trait's own typed state class).
  - **ActorRig** picks what the body plays (`RigAnimations`) and keeps the armor layers on its
    frame; the gear's looks (trims, elements, teeth, the weapon at rest and its aura) are laid
    out by its `GearLook` (`rig.gear`), bobbing with the body's art (`BodyTops`).
- **Combat** (`src/combat/`): every hit is made by `Combat.make_hit()`, its numbers (crit, variance,
  armor weight, the cooldown cap) in `data/combat/combat_rules.tres` (`CombatRulesDef`, read as
  `Combat.RULES`), its rolls on the floor's combat dice (`World.combat_rng`, seeded from the
  floor's seed apart from `World.rng`: the same seed and the same blows give the same fight, a
  daily run's floors stay the same for everyone, and a hit never shifts what the floor rolls next).
  A prop counts blows, not damage (`Combat.break_props()`).
- **Weapons** are shared: a monster attacks with a `WeaponDef` exactly like the player.
- **Skills and consumables** are both lists of `Effect` resources
  (damage area, projectile, heal, dash, buff). New effect = new class extending `Effect`. What a
  kind does when dressed in a weapon's elements (a skill, a charged attack), warned of by a boss
  or tamed is asked of it (`Effect`'s virtuals: `dressed_for_skill()`, `dressed_for_charge()`,
  `as_boss_skill()`, `telegraph_kind()`, `ai_reach()`, `hit_status()`...), never tested by type.
  A delayed effect (`Effect.delay`) is credited to what set it off (`Actor.with_source()`).
  Items work the same way: using one from the bag is the item's own `use_from_bag()`.
- **Monsters** are driven by a `StateMachine`: Idle (wander) > Chase (path or straight line, use skills)
  > Attack (telegraphed wind-up, strike, recovery). Skills with a `cast_time` go through Cast
  (glow, red circle, cast animation) so the player can dodge them.
  - **Moving**: Chase walks straight at the target only when its body can (`Monster.has_clear_walk()`:
    a shape cast of its width against walls and corners, plus no water, hole or prop on the line);
    otherwise it follows the A* path, its corners cut where the body fits. Walking but getting
    nowhere for 0.3 s (`is_stuck()`), it takes the path, then steps aside and looks again. Monsters
    keep a little space between them (no pile-up in doorways); wandering ones never pick a way
    into a wall.
  - **Sight**: `detect_radius()` is the kind's reach times the difficulty's `detect_range`
    (Pilgrim x0.85, Keeper x1, Martyr x1.2, Nightmare x1.4); chasing, they see 1.6x further
    (`MonsterDef.chase_sight_multiplier`) and give up after 4 s unseen (`chase_give_up_after`).
  - **Bosses**: their phases, the shockwave answering a streak of hits and the intro they wait out
    are a `BossBrain` (`Monster.brain`, made for a `BossDef` only; its numbers on the `BossDef`).
  - **Sleep**: what isn't seen isn't run. A few times a second the World lets monsters off screen
    (beyond a 256 px margin) and out of reach of the hero sleep: no AI, no movement, no animation
    (`Monster.set_awake()`, `ActivityManager`, `World.activity.awake`). Hunting monsters and bosses stay awake; a hit
    wakes a sleeper. On a crowded Nightmare floor, monsters cost about a quarter of what they did.
- **Game** offers the perk choices (pausing the game; a level up's only when the player taps the
  perk button, `open_offers()`) and reacts to boss fights through `Events`. Its `Interactor` gives
  the HUD's Interact button to the nearest `Interactable` (merchant, forge, encounter, pact): nothing
  opens by walking up to it.
- **UI** listens to signals (`Events`, Player signals) and never drives gameplay directly.
  Touch controls only press input actions, so keyboard, gamepad and touch share one code path;
  the mouse's clicks in a fight do the same (`MouseControls`).
- **Devices** (design/interface.md "Devices"): `InputDevice` says which device is in use; the HUD
  swaps its touch controls for the `ActionBar` (which mirrors them) on keys and gamepads; `Prompts`
  turns an action into the key or button to show (`PromptGlyph` draws it as a cap) from the input
  map and `data/ui/input_prompts.tres` (`InputPromptsDef`: the controls told about, the gamepad
  families' names, the dead zone), and picks a sentence's version for the device (`DeviceText`,
  `HintDef.button_text`, `Prompts.pick()`); `MenuNav` lets keys and gamepads use every window.

- **The story** (design/presentation.md "Boss stories"): the content is data (`data/story/`, a
  `BossChronicleDef` on each `BossDef`), gated by `ProgressCondition`s. `Narrative` (static, like
  `Bestiary`) is the only code writing the story's part of the Profile and answers what is open,
  told, found and done, and what a meeting tells (`plan()`). When the hero walks into an arena,
  `BossArena.start()` asks the World's `Storyteller` (the Game's `BossMeeting`) and waits for it:
  the Game pauses, a `CinematicDirector` runs the `CinematicDef`'s steps on a `CinematicView`
  (its own CanvasLayer, 7), then the boss wakes. `FragmentPlacer` lays fragments while a floor is
  populated; reading one goes through the Interactor and `Events.fragment_requested`. Deeds are
  checked by the `HuntTracker` at a warden's death; what the run did is `RunState.marks` (set by
  `RunRecords` from the Events).
- **The dialogue** (design/presentation.md "The Vigil-Keeper and the keepers"): `DialogueDef`s of
  `DialogueLineDef`s, gated by the same conditions; `Dialogues` picks a line and keeps it said
  through `Narrative` (`Profile.lines_told`). When the hero falls, the Game reads `RunFacts` at once
  (`Game.end_facts`: the killer and the cause come from `Player.killer_def` and
  `Actor.death_cause`, itself from the killing `HitInfo.cause`); the end screen asks
  `NarrativeDef.tell_end()` and shows it in a `DialogueBox` (`src/ui/dialogue/`). The title screen
  puts the shrine's speaker by the Well (`ShrineKeeper`) and opens a `DialogueScreen`; the shop,
  forge and encounter panels show their def's `dialogue` line where their greeting was.

## Autoloads

Each with one job, in `project.godot`'s order (> Autoload). The eleven game ones depend on each
other in one direction only; the seven online ones share `OnlineSession` (docs/online.md "The
shared session"):

| Autoload | Script | Job |
|---|---|---|
| `Events` | `src/autoload/events.gd` | Signal bus for notifications (screen shake, camera kick, boss fight...). Emit and listen; never use it to give orders. One documented exception, the `*_requested` signals (`shop_`, `forge_`, `encounter_`, `pact_`, `fragment_`, `perk_offer_requested`): gameplay (an `Interactable` used, an encounter's gift) asking the **Game** to open its panel. Only the Game connects them, never a UI node; the panel opened drives nothing but the choice it shows |
| `Sfx` | `src/autoload/sfx.gd` | Plays combat, world (positional) and UI sounds from `data/audio/sound_bank.tres`, each on its bus, mixed by `data/audio/sound_mix.tres`; the music, crossfaded (which track plays where: `Soundtrack`) |
| `HitStop` | `src/autoload/hit_stop.gd` | Impact freeze and slow motion |
| `Profile` | `src/autoload/profile.gd` | What lasts between runs: souls, Tree of Souls, records, bestiary, quests (`user://profile.json`) |
| `Settings` | `src/autoload/settings.gd` | Options and language (`user://settings.cfg`) |
| `InputDevice` | `src/autoload/input_device.gd` | The device in use (touch, keyboard and mouse, gamepad and its family) from the last real input; `changed` for the HUD, prompts and menus |
| `TouchScrolling` | `src/autoload/touch_scrolling.gd` | Adds finger scrolling to every `ScrollContainer` |
| `Loader` | `src/autoload/scene_loader.gd` | Loading screen between the title and the game |
| `SoftKeyboard` | `src/autoload/soft_keyboard.gd` | While a phone's keyboard is up over a text field, shows the field in a readable bar in the strip the keyboard leaves; tells `PixelGrid` a keyboard's resize so the UI keeps its scale (design/interface.md, Screens) |
| `PixelGrid` | `src/autoload/pixel_grid.gd` | Picks the canvas's scale (whole steps of 0.5, the interface size option; the camera keeps the framing: `world_zoom()`) and shifts the screen a quarter of a pixel so text and pixel art at half-pixel spots draw whole (design/interface.md, Text and Screens) |
| `MenuNav` | `src/autoload/menu_nav.gd` | Menus with keys and gamepads: the menu on top (group "menu") holds the focus, directions with wrap, tabs, the focus frame |
| `OnlineSession` | `src/autoload/online_session.gd` | What every online service shares: the backend (Talo, or offline without a key), the device's random id and its Talo player (one identify at a time for all), the consent gates, the clock, `release_mode`. Its own file, `user://online.json` |
| `Leaderboards` | `src/autoload/leaderboards.gd` | The online leaderboards (docs/online.md): queues the scores of runs that end (`Events.run_ended`), sends them through the session, reads the boards for the page. Its own file, `user://leaderboards.json` |
| `Privacy` | `src/autoload/privacy.gd` | The player's privacy choices: the age question, the statistics' consent and when it is asked again, "delete my online data" (docs/privacy-ops.md). `user://privacy.json` |
| `Telemetry` | `src/autoload/telemetry.gd` | The gameplay statistics, with consent: a `RunTelemetry` per run, its events queued and sent in batches. `user://telemetry.json` |
| `WorldStats` | `src/autoload/world_stats.gd` | The world counters (the Well's Toll): the player's share of each, sent with consent from release builds, and the world's numbers read for the title and the page. `user://world_stats.json` |
| `RemoteConfig` | `src/autoload/remote_config.gd` | The remote settings: Talo's game config checked against the allow-list, applied at safe points, the kill switches. `user://remote_config.json` |
| `Feedback` | `src/autoload/feedback.gd` | The player's feedback messages, queued and sent to Talo's game feedback. `user://feedback.json` |
| `Account` | `src/autoload/account.gd` | The optional account (Talo player auth): register, sign in and out, reset and change the password, delete; one session per account, "Stay signed in". `user://account.json` |
| `CloudSave` | `src/autoload/cloud_save.gd` | The profile as the account's online save (Talo game saves): revisions, uploads after writes, a newer copy taken out of a run, the conflict choice. `user://cloud_save.json` |
| `Presence` | `src/autoload/presence.gd` | Talo's live connection (`LiveLink`, a WebSocket) while the statistics are allowed: a play session and the player shown online; closed in the background (docs/online.md "Sessions and presence"). No file |

**Start-up order.** Godot makes every autoload (`_init()`) before any `_ready()`. The online ones
read their data and file in `_init()` and ask no other service there, so from `_ready()` on any
may call any other whatever the list's order (`OnlineSessionTests` starts them in 14 orders).

The test runner empties `Profile.save_path`, `Settings.path` and `RunSave.path` (one per test
process), turns the tutorial hints and boss stories off, forces English and touch input, and resets
the whole online layer with `OnlineSession.use_all_for_tests()`: no file, an offline backend, no
timer, nothing queued, never the network. In a test launch the online files start with no path, so
the player's real ones are not even read while the autoloads start.

## Rendering

The rules that keep frames cheap on a phone (no allocation in hot paths, redraw on change, no
GPU readback while playing) and the probe that measures them: docs/performance.md.

- **Drawing the floor**: `DungeonView` draws the map in 8x8-cell chunks, each its own canvas item,
  so the renderer skips the ones off screen; inside a chunk, tiles go texture by texture to batch.
  About 90 draw calls whatever the floor's size (it was ~1500 on a big floor).
- **The ceiling** (`CeilingLayer`, design/dungeon.md "Ceilings") is drawn the same way: chunks of
  12 cells, each one canvas item over its biome's one atlas, plus its shadows' chunks; per frame
  only the bodies' places go to its shader. Measured on Nightmare floors (104 x 104, 56-127
  pieces): 1-3 more draw calls, render time within llvmpipe's noise.
- **Mist over the walls** (`PlateauMist`, `plateau_mist.gdshader`): a volumetric mist over the
  plateau above the cliffs (and all around the map). Every frame a ray goes down through its
  height in 6 slices (3 with Fewer effects) for each pixel of a small viewport over the view,
  one pixel per art pixel: a 3D noise drifting with the wind and slowly rising, thick at the
  bottom and wispy on top, densities adding up (Beer-Lambert), in dithered steps. Seen from the
  south like the art, it rises up the screen a little over the room behind a wall, and its
  layers lean with the camera. It is lit by the floor's light (`LightField.light_texture()`):
  lamps by a wall and the hero's torch glow in it, scattered softly; away from them it stays
  dark. Thin at the rim so the cliff's edge stays readable. Colors and thickness per theme
  (`DungeonTheme` > Mist).
  The light goes with it: a lamp by a wall reaches into the mist over the rim, losing two levels
  a tile instead of one, and light that went into the mist never comes out the other side (no
  light through the walls). Moving lights (the torch, shots) do the same in the light shader.

## Ownership and stable persistence

`Game` owns `GameOffers`, a child node for the whole perk-choice interaction (dealing, rerolls,
banishes, postponement). Panel signals target that child and disappear with it. `OfferQueue`
remains the saved data; Game keeps its public open/queue/show entry points as delegates.
`World` owns `WorldSpawner`, which receives the entity, projectile and effect layers after
those nodes are ready. Creation, placement, ranks and loot use exactly the same floor rules
and random stream; World keeps the public factory facade used by effects and floor kinds.

All online autoloads implement `OnlineService`'s typed lifecycle: `boot()` reads local state,
`settle()` may consult other initialized services, `use_for_tests()` resets isolated state.
`OnlineSession.services` is typed; reset and startup no longer discover methods by strings.
`OnlineLinks.bind()` is the single, idempotent composition point for subscriptions between
autoloads: privacy/leaderboards -> world statistics and remote config, privacy/identity ->
presence, profile/account -> cloud save. It binds public reconciliation callbacks after all
`_init()` methods, from OnlineSession's `_ready()`. Gameplay subscriptions remain with each
service. Autoload facades and the existing consent gates retain their roles.

`ContentCatalog` maps stable namespaced save ids to current Resource targets. The generated
`data/save/content_catalog.tres` also keeps historical paths. `RunSave` loads it lazily, so
the class dependency graph does not preload content recursively. Version 3 migrates references
in older runs; resource-file references inside `.tres` and `.tscn` remain ordinary paths.
See progression.md and adding-content.md for migration and registration rules.

## Monster modifier ownership

`EliteAffixDef` declares compatibility and reusable traits; `WorldSpawner` samples compatible
choices and `Monster.make_ranked()` validates saved/manual lists and the rank limit again.
`MonsterTraits` owns one monster's cached active list and private typed states, while the
Resource definitions stay shared and immutable. Native hooks precede affix hooks in data order.
Monster dispatches the existing hooks through that list, and MonsterOverlay reads its cached
under-drawing flag. No per-frame merge or trait-array allocation is introduced. Affix ids remain
the persistence boundary, so changing a filename does not change a saved modifier.

The `move_speed_multiplier` hook derives transient movement changes without editing cached
stats. The post-damage `on_damaged` hook lets a trait react to actual damage; reactions reject
lethal and secondary hits themselves. `FrenzyTrait` uses the first; `WarnedPulseTrait` uses the
second plus update, with per-owner counters and a GroundStrike owning the warning lifetime.


## Run lifetime and command producers

GameSession holds the current RunState, live hero and World. Game.run/player are compatibility
views. Opaque session tickets prevent a previous death timer, descent request or fade from
acting on a restarted run. Session ownership is runtime-only, not a persistent RPG campaign.

PlayerControls samples a reused PlayerCommand once each physics step. LocalPlayerInput reads
the shared keyboard/gamepad/touch actions; BufferedPlayerInput provides independent intentions
for tools/tests. Existing components still validate costs, cooldowns and inventory. The
[separate RPG experiment](rpg-archive.md) has been removed from the active product; none of its
campaign stores, fixed-region coordinators or launch screens are kept on main.

## The playable surface

The title now enters [Kagari](design/village.md), a small persistent village between procedural
descents. VillageHub/VillageWalker own peaceful movement and modal requests; VillageProgress
commits its quests/services in Profile, and VillageExpedition adds recoverable evidence to
ordinary floors through Events. VillageMemorial reuses the equipped hero rig in a static stone
pose. RunState's opaque journey_id makes ending receipts and statues idempotent across crashes;
it does not consume gameplay dice. The archived RPG remains a separate project.

VillageResident owns each surface routine, idle frames and proximity speech, with no combat
actor or dungeon RNG. VillageView preserves residents across profile refreshes. VillageHub's
fixed interaction registry follows their actual positions and pauses routines during modals.
VillageTopicDef carries the questions and stage-gated replies selected by VillageProgress;
quest prerequisites and the separate infestation fronts are authored in the same village data.

VillageClock advances a Profile-owned elapsed-play scalar in VillageHub and the pausable
VillageExpedition node (Game itself processes while paused). VillageClockDef owns tuning and
daylight; VillageActivityDef owns individual appointments. VillageNavigation shares a surface
AStarGrid2D between residents; no dungeon AI/pathfinding depends on it. VillageQuestRows adds
read-only village cards to the existing codex, shared by the HUD, world noticeboard and pause.

VillageInteriorDef registers peaceful rooms on the hub manifest. The same VillageWalker moves
between exterior and interior coordinates, updating camera/interaction scope atomically.
VillageInteriorView/Floor draw the authored room, and VillagePropView shares prop rendering
and collision with the square. Residents route through a doorway before changing their room;
VillageNavigation caches per-room grids. No Loader transition, new autoload, RunState mutation
or additional persistent store is involved. Interactions require the walker and target to be
in the same room, even if a stale focus survived a previous frame.

VillageAtmosphereDef owns surface/descent art tuning. VillageWellVfx draws ambient spirits and
restored lamp flames; WellDescent owns the cancellable cinematic and emits completion once.
VillageHub commits launch flags and calls Loader only then. VillagePanel is a standalone compact
conversation/service presenter using Ninja Adventure frames and the existing MenuNav/TouchScroll.
The @tool layout scene lives under tools/village and never instantiates runtime Profile/Hub.
