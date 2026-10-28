# Balance

## Remote multipliers vs balance passes

The remote settings (docs/online.md "Remote settings") can multiply, per difficulty, every
monster's and boss's Health (`enemy_health_<difficulty>`, 0.5 to 2) and everything that hurts the
hero (`enemy_damage_<difficulty>`), and every run's souls (`souls_multiplier`, 0.5 to 3), from
Talo's dashboard, without an update. They land on the run's own copy of its `DifficultyDef`, so
`FloorRules` scales the floors with them like any difficulty number; a run keeps the values it
started with.

- **They are for hotfixes**: a released difficulty is broken (a wall on Martyr after a content
  update, a souls exploit) and the next build is days away. Set the multiplier, then make the real
  change.
- **Real changes go into the data** (`data/difficulties/*.tres`, the content), measured with the
  tools below and recorded in docs/balance-log.md, like any balance pass. When the build with the
  fix is out, put the multiplier back to `1` (or gate the old value to the old versions with
  `max_version`). A multiplier left on hides the data's true numbers from the balance tools,
  which never read the remote settings: they measure the data.
- They are coarse on purpose (a whole difficulty's monsters at once, no single monster, perk or
  item): anything finer is a balance pass, not a remote value.
- The events' souls bonus (`event_souls`) and floor event boost are content (a weekend's), not
  balance: they end by themselves.

## Tools

`tools/balance/` measures the game's balance on the real content and the real engine, so the
balancing work (the `game-balancer` agent, or a person) can measure, change data, and measure
again. Nothing in it is a hand-made list: weapons, perks, relics, families, runes, affixes, shrine
upgrades, elite affixes, monster ranks, monsters, bosses, encounters and difficulties are walked
from `ContentDB` and the `data/` folders (`BalanceContent`), so new content is measured on the
next run. Content found in `data/` but not used by the game is reported (table "Content").

### Running

From the project root (Godot 4.7; import the project first if `.godot/` is missing):

```
godot --headless --fixed-fps 60 res://tools/balance/balance.tscn -- --mode=all --jobs=2 --out=/tmp/balance
```

The tools take ids, which kept the game's first names when the dark-fantasy names came in
(docs/lexicon.md); reports may show either:

| Id (options, data, reports) | Name in the game |
|---|---|
| `easy`, `normal`, `hard`, `nightmare` (difficulties) | Pilgrim, Keeper, Martyr, Nightmare |
| `elite`, `epic`, `legendary`, `shiny` (monster ranks) | Elite, Fell, Legendary, Celestial |
| `multishot` (perk) | Hydra's Quiver |

Bosses, monsters, perks and affixes are named the same way: the `id` in the `.tres`, the
`display_name` on screen.

| Option | What |
|---|---|
| `--mode=` | `model`, `arena`, `pack`, `marginal`, `economy`, `compound`, `gauntlet`, `all` (default `model`); `merge --in=a,b` combines earlier runs |
| `--quick` | a small subset of each mode (what the `balance` test suite runs) |
| `--only=act2,normal,king_slime` | restrict to acts (`act1`..`act4`: their bosses, builds, rooms, marginal values), difficulties, bosses, builds or weapons, in any mix |
| `--difficulty=` | `easy`, `normal`, `hard`, `nightmare`, `nightmare+N` (Nightmare with its first N ascensions); default all of easy..nightmare+10 (`--quick`: normal; the gauntlet: easy, normal, hard) |
| `--build=`, `--boss=`, `--bot=` | restrict the builds (`data/balance/builds/<name>.tres`), bosses, bots (`face_tank`, `kite`, `player`; the gauntlet runs `kite,player` unless told) |
| `--acts=2,4` | marginal values, rooms and the gauntlet: acts measured (default all) |
| `--picks=ignite,cinder_wake` | marginal values: only these picks (perk, relic, family, rune, affix ids), a new pick next to a few known ones; the "vs median" ratio then compares them among themselves |
| `--seed=N` | every measure starts from this seed (default 1): the same command gives the same numbers |
| `--all-pairs` | arena: every build against every boss, not only its act's |
| `--timeout=240` | arena and gauntlet: game seconds before a boss fight is a timeout |
| `--plain`, `--no-weapons` | arena: plain bosses only (no ranked fights); skip the weapon arena (targeted runs) |
| `--keeper=bow,magic_wand,katana,hammer` | arena: the bottom of the Well instead: Tôma alone (for scale), then a Nameless Keeper per weapon, built from a sample hero who took the keeper's place with it (`BalanceContent.keeper_snapshot`: level 15, the weapon Rare with Brutal and of the Fox, a Magic iron helm and a chain mail, the weapon's skills and a tome that suits it, the relics he keeps), against the last act's expected build, each difficulty and bot |
| `--hits` | arena: print every hit the hero takes in each fight measured (time, phase, what it was: the weapon, the skill and how long after its cast, a shockwave, adds; its push, the distance to the boss, a hole within 48 px, the boss' state) and every fall with what started it (a push, a roll, walking); with `--no-cache` to see them all |
| `--jobs=N` | worker processes sharing the measures (default 2, this machine's CPUs; `--jobs=1`: one process) |
| `--cache=<dir>`, `--no-cache` | where measures are kept between runs (default `user://balance_cache`); measure everything again (results still kept) |
| `--classic` | the game as seen (effects, HUD, light, a new game for every measure): the tools as they were before they simulated, slower, to compare |
| `--out=` | where the reports go (default `user://balance`) |

Each mode writes `<out>/<mode>/report.md`, `data.json`, `csv/<table>.csv` and `state.json`
(for `merge`); `--mode=all` also writes `<out>/report.md` and `<out>/data.json` with everything,
and prints a short summary (flags per category, the first ones). Exit code 0: flags are findings.
Every run also writes `<out>/summary.md` (printed too): time, measures made or kept, flags per
mode, the gauntlet's act x difficulty table when it ran.

How a run is made fast (`BalanceLab`, `BalanceJobs`):

- **A simulation.** The tools run the game with nothing to see (`Vfx.shown` off): effects,
  floating numbers, splats, light, ambience, the HUD and the bodies' looks are not made or not
  updated. Nothing a rule or a bot reads is skipped (a cell's warning, telegraph values), and the
  game and the tests always show everything (`vfx_tests` checks it). Visual code draws from the
  same random numbers as the game, so a fight can differ from the one `--classic` gives: within
  the seed noise (below), same verdicts.
- **Floors without their own monsters** (`World.unpeopled`), and a fresh measure rebuilds its
  floor in the running game instead of starting a new game (`BalanceLab.renew`).
- **Units of work shared by processes.** The engine measures are cut into units (a fight, a room,
  a gauntlet, a measured build, a floor); `--jobs=N` processes walk them in the same order, each
  taking the next one no other has claimed (`BalanceJobs`: a folder made per unit, the first one
  wins), then the first assembles the reports.
- **A cache.** A unit's result is kept (`--cache`) under its id, the seed and options, the code
  (every script of `src/` and `tools/balance/`) and the data it depends on (its act with its
  monsters, bosses and biomes, the build's perks, runes, affixes and gear, the difficulty, and
  what every measure uses: the hero, the combat rules, ranks, elite affixes, families, props, arenas, hazards): run
  again, only what a change touched is measured again. A code change measures everything again.
  `--no-cache` ignores what is kept.

Run time on 2 CPUs (2026-10-22, measured): `--mode=all --jobs=2` (all six difficulties, the
gauntlet and its curve) about 45 min from scratch (the tools before the simulation and the
units: 1 h 41 min, without the gauntlet), 30 s again with nothing changed (the cache); after a
data change only the units that read it. `--mode=all --quick` about 2 min (was 3); model ~5 s;
the act II-III boss fights of the expected builds on three difficulties ~1 min; the curve on
three difficulties ~8 min; the `balance` test suite a few minutes.

### What each mode measures

- **model** (static, seconds): the content's numbers put through the game's own code (a real
  `Player` gets each build; `FloorRules` scales monsters; `Combat`'s variance, crit and armor),
  fights as arithmetic. Every monster kind x every rank (plain, Elite with each affix, Fell and
  Legendary with spreads of affixes, Celestial) x every depth it appears at x every difficulty:
  health, armor, hit and damage per second on the act's expected build (after its armor), time to
  kill, hits to kill the hero, damage taken while killing it; rank chances per depth; the
  commons' curve and the ranks' ladder (medians per act on Keeper, table "monster_ladder"); the
  **floors' curve** (table "floor_curve"): every normal floor, what a room of it costs face to face
  (its room size, monsters by spawn weight, ranks with its chances) the hero an average player
  has there (`BalanceBuild.hero_at`: on an act's first floor what he brought in, a fresh hero in
  act I, later the act's expected build) and the same hero with the starting weapon. Every boss
  (alternates too) x every phase x every boss rank x every difficulty: health, armor, hit and
  damage per second per phase, time to kill, a face-tank estimate, the threat (share of the
  hero's health a face-tank fight costs) and the curve (act over act, difficulty over Keeper);
  each elite affix on each boss. Every weapon x every rarity x every armor value monsters have:
  DPS on each act's expected hero, weapon skills' damage and cooldowns. Builds, degenerate and
  family DPS ratios, a static perk estimate. Assumptions: 100% uptime; fans land 1 + 0.6 per
  extra projectile on a boss; status uptime 1 - exp(-rate x duration); DoTs of a kind don't stack;
  sustain capped by `SustainRules`; procs it can't place (chains, bursts, rolls, thorns) left out.
- **arena** (engine): real fights in the Game scene with a bot at the controls (`BalanceBot`):
  `face_tank` stands in reach and hits, uses skills when ready, never rolls or drinks; `kite`
  keeps its weapon's range and hits whenever in reach, steps out of swings, skill circles, leap
  lines, the cone of a fan of shots (while it is warned: the shots' own sides cancel out once
  they fly around the hero), shots, blinking arena cells, live traps and a wyrm's burning coils,
  keeps out of a cast's later blows (a fierce Quake's wider ring, a second volley or leg) until
  they have landed, steps across a drawn bow's or wand's line instead of backing off from it and,
  when only shots threaten it and its foe is out of reach, keeps closing in across their line
  (`BalanceBot.CLOSE_IN`: a boss that keeps his distance and shoots is reached between his
  volleys, not waited out of range), rolls only as a blow lands (within the roll's invulnerability), over holes if
  need be but only to land on solid ground with nothing in the way, never walks into a hole,
  cracked floor or a warned cell it can see (it steps off one under its feet) nor uses a skill
  that would carry it into one, and holds the hit that would set off a boss' shockwave when its
  roll isn't ready.
  Every boss x the builds of its act (expected on every difficulty; degenerate, family and baseline
  builds on Keeper and Martyr) x both bots; every boss rank (Fell, Legendary, Celestial, with the affixes
  the game rolls) with the expected build on Keeper and Martyr. Result, time, phase reached, boss
  health left (and the time to kill projected from it), damage dealt and taken, hits, healing by
  source (perk, rune, affix, family, skill, item, revive), damage taken by kind (melee, skill,
  shockwave, body: a wyrm's coils, blasts, adds, ticks, traps, falls; printed per fight), lowest
  health, second lives spent (a second life sends the hero to the Threshold's trial, which the
  bots play; what he takes and heals there is left out of the fight's numbers). Then the **weapon arena**:
  every weapon (Common, on the act's expected build otherwise) against every boss, kite, Keeper.
- **pack** (engine): on each act's last normal floor, Keeper and Martyr: three of each monster kind
  (time from first hurt to death, damage taken), mixed rooms of the act's list by spawn weight
  (room size of that depth and difficulty, 3 rooms) for every build of the act and both bots, and
  rooms with one ranked monster (Elite with each affix, Fell, Legendary, Celestial) + 2 commons.
- **marginal** (engine): every perk at each level, every relic, every family's bonus alone, every
  rune, every item affix, every shrine level (stats and starting perks), every encounter outcome,
  added alone to each act's expected build (Keeper). Each variant: DPS and boss time to kill on
  the act's boss as a dummy (no AI, health scaled to ~15 s for the base build; the hero
  untouchable, held at 45% health for the second half so low-health bonuses and heals show);
  pack clear time on a room of the act's monsters that don't fight back (cleaves, chains, kill
  effects); boss time to die = (health + ward) x revives / (the boss' DPS on that hero - sustain);
  effective health vs the act's monsters; damage taken in one live room at max level
  (informative). **Value = sqrt(boss TTK ratio x pack clear ratio) x boss time-to-die ratio - 1**.
  Ranked per act and category at max level; flagged beyond 2x / under 0.5x the category's median.
  A perk the build already has is measured from the build without it (its families kept awake);
  a family the build has awake is measured by putting it to sleep. Encounter outcomes that are
  not stats (a perk or relic gift, a heal, gold, items) are valued from the measured ones.
  Every measure starts on a fresh run of the same seed: a repeat gives +0% (table "marginal_base"),
  another seed shows how much is luck.
- **economy** (engine): every normal depth x difficulty, 2 floors each, generated by the game
  (its events, curses, merchants...) and harvested by its code: every monster slain, crate broken,
  chest opened; gold, XP, items by rarity, runes counted; a merchant's stock priced on each floor;
  ambushes and encounters valued from their data. Gold per floor (full clear and typical) vs stock
  prices, rerolls and rune removal; XP before each boss -> level (the expected builds' reasoning);
  rarity per depth and source; souls per run by result and difficulty vs the shrine's total; and
  a whole **Keeper career** (`BalanceSouls`, table "economy_campaign"): run after run (a career of
  results: first runs die to act I's boss, then act II, III, IV, then half the runs win), every
  source of souls added as expected values: the run's souls and the hidden floor, hunter ranks
  (from the kills of each kind measured on the floors), bestiary challenges (a chance per kill of
  each kind), achievements (from the counters a career reaches), quests (two runs a day) - against
  the Tree of Souls (a full tree: the dearer side of each fork; every node). The same for a
  **Pilgrim career** when Pilgrim is measured (`--difficulty=easy,normal`; table
  "economy_campaign_easy": Pilgrim's souls, no achievements since feats don't count there, a
  faster career of results), and **Pilgrim vs Keeper** (table "economy_pilgrim": what a run pays
  by how it ends, each career's runs to the tree). The assumptions are constants at the top of
  `balance_souls.gd`, each with its reason. Skipped with `--quick`.
- **compound** (engine): attack speed x crit x damage (Frenzy, Precision, Strength, War Banner
  alone and together vs the product of the parts); Hydra's Quiver and Prism on every ranged weapon at
  64, 128, 256 px; echo (Echo perk, Echo runes, of Echoes, Arcane Focus); burn stacking (Ignite,
  Ember, Burning, Kindling, Inferno); armor vs many weak hits (share of each act's monsters hitting
  each build for 1); healing vs the sustain cap (lifesteal stacks with and without `SustainRules`,
  in a room and on a boss dummy, and what a real boss fight's budget would pay).
- **gauntlet** (engine; the difficulties' measure): each act as a player meets it, the act's
  expected build on its last normal floor: 8 rooms one after the other (the act's monsters by
  spawn weight, the room size of that depth and difficulty, every monster rolled for a rank with
  the floor's own chances), Health and potions carried from room to room (2 Health Potions to
  start, those picked up on the way join them, a bot drinks one below 35% Health), then the
  act's boss with what is left. Bots: `kite` (a decent player) and `player`
  (the kite bot with a 0.3 s reaction: a threat is answered only once it has shown that long,
  `BalanceBot.REACTION`; an average player), `face_tank` when asked. Every act x Pilgrim, Keeper,
  Martyr by default. Tables "gauntlet" (rooms cleared, ranked met, damage taken and healed in the
  rooms, potions drunk, lowest Health, Health and potions at the boss, the **floor cost**: the
  share of Health and potion healing spent before the boss, the boss fight, the outcome) and
  "gauntlet_summary" (acts won, mean floor cost, per difficulty and bot); `summary.md` shows it
  as act x difficulty. No springs or shrines on the way, no walking between rooms, the earlier
  floors not played. Its **curve** part (`--gauntlet=curve`; `acts` for the acts alone): every
  normal floor, 6 rooms of its depth one after the other, no potions, for the hero there
  (`hero_at`) and the same with the starting weapon (Common, item level 1), each bot: the Health
  a floor costs (table "curve", and in `summary.md`). Sustain dominates it: a build with
  lifesteal comes out of most floors at full Health.

### Reading the report

`report.md` starts with the run (command, seed, time per part) and a table of contents; then
**FLAGS**: a count per category, then every flag numbered (F1, F2...; errors first): severity,
category (`model:` estimates, `arena:`/`pack:` real fights, `marginal:`, `economy:`, `compound:`),
subject, measured value, target, and why. Then the tables, numbered by section: 1 Builds,
2 Monsters, 3 Bosses, 4 Weapons, 5 Marginal values, 6 Economy, 7 Compound checks, 8 Content (in a
single mode's report the numbers start where its sections start). Long tables show their first
rows; the CSV (`csv/`) and `data.json` have every row. `data.json` holds every table (as rows of
named columns) and the raw measures (every fight, room, floor and variant) for scripts.

Errors are pillar breaks measured on the engine (a face-tank win, too much healing in a boss
fight); warnings are targets missed. Model flags are estimates: confirm them with the arena or the
lab before changing data.

### Targets (data/balance/targets.tres, a first proposal)

| Target | Value | Why |
|---|---|---|
| Boss time to kill, expected build, Keeper | 40-100 s (rare-rank boss <= 150 s) | under it the boss is not a fight; over it the fight drags on a phone |
| Face-tank (never dodges) with expected and degenerate builds | must lose to every boss from Keeper; a win after dying once (a second life, the Threshold played) counts as a loss (`facetank_second_life_is_loss`) | skill beats stats: standing and trading blows must never win (pillar 1); the boss killed him, and bosses are not tuned to kill twice around the rarest relic |
| Kite (keeps range, rolls) with the expected build | wins on Pilgrim and Keeper (boss fights and the gauntlet) | the fight must be beatable by playing it |
| A boss' dive (a rush or leap along a line), every boss (unit tests) | warns >= 0.45 s in the boss' last phase on Keeper (`dive_warning_min`); hits a band at most 8 px wider than its body each side (`dive_band_margin`); never slows | a person sees the line and steps off it; the Azure and Jade Wyrms' fierce dives warned 0.30 s on bands twice their body (2026-10-23) |
| Gauntlet, `player` bot (an average player) | wins every act on Pilgrim | Pilgrim stays accessible |
| Gauntlet on Keeper, `player` bot: floor cost (share of Health and potion healing spent on an act's last floor before the boss), mean over the acts | 20-60% | the rooms are a fight, not a stroll that hands out potions; the boss is still reached with a chance |
| Gauntlet on Keeper, `player` bot: acts won | >= 75% | Keeper is a real challenge for an average player, not a wall |
| Healing in a boss fight / damage taken | <= 25% expected, <= 50% degenerate and family (a second life's heal left out) | healing forgives mistakes, it doesn't out-heal a boss; a second life is not sustain |
| Boss hits to kill the expected build (Keeper) | 6-12 | one mistake isn't the end; ignoring the patterns kills |
| Common monster time to kill (expected build, Keeper) | 0.5-2.5 s | paper below, a slog above |
| Elite / Fell / Legendary / Celestial time to kill | 3-10 / 5-16 / 8-25 / 2-10 s | a short duel, a longer one, a mini-boss, a treasure |
| Rank ladder (medians per act, Keeper) | each rank >= x1.2 the time to kill of the one below, and costs more health | a rank is a clearly tougher fight, not a recolor |
| Commons' curve (median health lost killing one, act over act) | x1.05-x1.6, act II over act I up to x2.5 (was x0.9-x1.6) | each act's monsters a little harder than the last, no flat stretch ("you roll until floor 8", the owner); act I is gentle on purpose, so its step is bigger |
| Floors' curve (model, Keeper: a room of each normal floor for the hero there) | act I <= 25%; no act cheaper than the last (x0.9) | the first floors are where a player learns; no dip |
| Gauntlet curve (engine, Keeper, kite bot) | act I floors <= 25% of max Health | the first floors stay gentle; later floors are informative (the bots' sustain makes most of them free, see the balance log) |
| Common monster hits to kill the expected build | >= 6 | never a two-shot |
| Room damage (kite, expected build) / clear time | <= 35% of max health / <= 25 s | a room shouldn't cost half your life when you play well |
| Act curve (boss threat, act over act) | x0.9-x1.6 | a steady curve, no wall (pillar 5) |
| Difficulty vs Keeper (boss threat) | Pilgrim x0.2-0.7, Martyr x1.3-2.6, Nightmare x2-5, +5 x2.5-8, +10 x3-12 | Pilgrim forgiving, Nightmare demanding, ascensions add twists not walls |
| Any pick at max vs its category's median (marginal value) | 0.5x-2x | every pick a real choice (pillar 2) |
| Degenerate build DPS / expected build's | <= 2.5x | stacking pays, it doesn't trivialise (pillar 3) |
| Weapon DPS vs the median weapon (same rarity, same hero) | 0.75x-1.4x (phase 2C; was 0.6-1.6) | no trap, no only choice |
| Weapon arena: bosses beaten (Common, kite, Keeper) | >= 50% | a weapon that loses to most bosses is a trap |
| A stack of multiplying bonuses (compound) | <= 2.5x the expected build's DPS | check the products, not the parts |
| Most armored build: monsters hitting it for 1 | <= 50% of the act's | armor makes weak monsters weaker, not harmless |
| One sustain source alone, cut by the budget in rooms | <= 10% | a single Leech or Vampirism is never capped on packs |
| Gold between merchants / an average stock item | 0.8-3 items | buy something most visits, never everything |
| A reroll / rune removal vs a floor's gold | <= 35% / <= 60% | cheap enough to use |
| Runs to a full Tree of Souls, a Keeper career with every source (economy_campaign) | 40-60 (was: 15-60 runs dying in act II-III, run souls only) | a campaign, not a few evenings; the old target ignored the bestiary, achievements and quests, which paid more than the whole tree |
| Runs to the first node (Keeper career) | <= 2 | something to show for the first runs |
| Runs to a full tree, Pilgrim career / Keeper career (economy_pilgrim) | x1.25-x2; Pilgrim's first node by run 3; a Pilgrim run never pays more than a Keeper run that ends the same way | Pilgrim progresses, more slowly than Keeper, never faster for less risk |
| One-time souls (hunter ranks, challenges, achievements) in the first 10 runs | <= 20% of the full tree | the first hours' burst must not hand out the tree |

### Builds (data/balance/builds/)

- `baseline`: a fresh hero (level 1, the Katana).
- `expected_a1`..`expected_a4`: what an average player has at each act's boss. Level from the XP
  curve and the XP measured on Keeper floors (economy table "XP gathered before each act's boss",
  kills 80/75/65/60% of the act's monsters), one perk per level up leaning to families, a relic
  per boss slain, gear rarity from the loot weights at that depth, runes from bosses and elites,
  a few shrine levels. Each file's `description` says why.
- `degenerate_*`: one thing stacked as hard as the game allows at that act: lifesteal (each act),
  crit, attack speed, burn, thorns/armor, skills/cooldowns, max health.
- `family_<id>_a3`: each family built on purpose at act III (expected_a3's level and gear, 10
  perks leaning on the family, its runes).

To add a build: copy a `.tres` in `data/balance/builds/`, give it a unique `name`, `tags`
(`expected` - one per act -, `degenerate`, `family` + the family id, `baseline`), its act, level,
weapon (rarity, affix ids, rune ids), armors, perk ids -> stacks, shrine upgrade ids -> levels,
and say why in `description`. Unknown ids and impossible stacks are flagged ("build data").
To add a target: add an `@export` to `tools/balance/balance_targets.gd` with its reason, its value
and the same reason in `targets.tres`, and check it where it is measured (`flag()` in the mode);
add it to the table above. To change a target, say why in the [balance log](balance-log.md).

### Limits (read before trusting a number)

- **Repeatable, not luck-free.** The same command gives the same numbers (`--seed`); the lab
  replays each measure on a fresh run of the same seed, so two builds are compared on the same
  luck (table "marginal_base": a repeat gives +0%). Another seed moves a value by 2-40% (shown
  there too); a fight that ends with the boss at 2% may flip from one run of the tools to another
  (the arena runs each fight once). Read flags across several bosses or acts, not one fight.
- **The bots are decent, not good.** `kite` doesn't use the terrain, doesn't drink, and rolls
  only on what it sees coming (it still eats some shockwaves and falls when thrown off; each fight
  counts its falls, `falls_pushed` thrown in by a blow and `falls_walked` walked in, which should
  stay near 0); a lost kite fight means "hard for a careful player", not
  "impossible". `face_tank` is the pillar-1 test as written: it never dodges. `player` is `kite`
  answering every threat 0.3 s late, one fixed reaction for everything: a person is quicker on
  some patterns and slower or careless on others, and learns a boss. Read its numbers as "an
  average player's first meetings", not as a measured person.
- **Dummies don't fight back.** The marginal values' boss and rooms don't move or attack: slows,
  freezes, knockback, thorns and retaliation, roll effects and other crowd control show no value
  there (they are in the live rooms' "Taken" column and in the arena). A pick at +0% is either a
  trap or a defensive/control pick: read its description before calling it weak.
- **Saturation.** When a build already out-heals its act's boss (sustain >= the boss' damage per
  second), every defensive pick scores 0 (time to die is capped at 200 s): that is a finding
  about the build's sustain, not about the picks.
- **Quantised damage.** The dummy dies after a whole number of hits: picks worth under ~3% of
  damage can read +0%, and two levels can read the same.
- **The model is arithmetic.** It ignores movement, positioning and most procs; it is for
  coverage (every rank, depth, difficulty) and trends. The engine modes are the measures.

### Players' statistics (what real runs say)

The bots measure what the content *can* do; the gameplay statistics (players who consented, Talo
events) say what players *do*. `tools/stats/build_dashboard.py <export.zip> --json stats.json`
(docs/online.md "Reading the statistics": how to get the export) writes the same numbers as the
statistics page: `overall` (every version and difficulty, no dev data) and `views` keyed
`"<version>|<difficulty>|<dev 0/1>"` (`"all"` for every one; e.g. `"0.3.0|normal|0"`), each with
`overview`, `by_difficulty`, `by_ascension`, `depth` (per floor: reached, deaths, death rate),
`acts`, `causes`, `killers`, `bosses`, `entities` (`weapon`, `weapon_rarity`, `element`, `head`,
`body`, `armor`, `skill`, `perk`, `relic`, `set`, `rune`), `combos`, `potions`, `defence`,
`damage`, `skills_use`, `floor_times`, `economy`, `pacts`, `oaths`, `devices`. A row of a group
has `runs`, `finished`, `wins`, `win_rate`, its 95% interval `lo`..`hi`, `delta` (vs the view's
win rate), `avg_depth` and `conf` (`low` under `--min-sample` finished runs: don't act on it);
perks and relics add `offered`, `picked`, `pick_rate`, `banished`.

How the game-balancer uses it alongside the bots:

- **Find, then measure.** A boss whose players' win rate is low (`bosses`, sorted with the
  blocking ones first) or a floor with a high `death_rate` is a lead; the arena and the gauntlet
  on that act say whether it is the numbers (a fight the `player` bot also loses) or the reading
  (the bot wins, players don't: a telegraph, a pattern; not a stat change).
- **Picks.** A perk or relic with a high `pick_rate` and a positive `delta` on a good sample, or a
  weapon far above the others, is a candidate the marginal values should confirm; one nobody
  picks (`pick_rate` far under 1/3 on a choice of three) with no marginal-value problem is a
  description or a fun problem, not a number.
- **Potions and the roll.** `potions.avg_health_when_drunk`, `deaths_with_heal_left` and
  `defence` (dodge rate of winners vs losers) tell whether the gauntlet's assumptions (a bot
  drinks below 35% Health; the `player` bot's 0.3 s reaction) match players.
- **Read the limits**: the build is the one held at the end (survivorship), players pick
  difficulties, versions mix balance changes (filter by version), and a few hundred runs leave
  wide intervals. Quote the sample and the interval in the balance log when a change rests on it.

### Hooks in the game code (behaviour-neutral)

`Actor.healed(amount, source)` and `Actor.heal_source` tag every heal with what caused it (set for
the length of a call by `PerkSet`, `SkillSet.try_use` and `ConsumableDef.use`); nothing in the game
listens. `PerkSet.Entry.source_tag()` names a perk, family, rune or affix for it. That's all: the
tools drive the game through its input actions, its data and its public nodes.
