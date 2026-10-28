# Difficulty and progression between runs

## Difficulty

Pressing Descend asks for a difficulty (`data/difficulties/`, `DifficultyDef`). Every value multiplies
the normal game:

| | Pilgrim | Keeper | Martyr | Nightmare |
|---|---|---|---|---|
| Monster HP | x0.7 | x1 | x1.3 | x1.7 |
| Monster damage (attacks, skills, traps, bursts) | x0.6 | x1 | x1.35 | x1.8 |
| Time to dodge (wind-ups, casts; never under 0.4 s, a boss's 0.5 s: decision 0008) | x1.35 | x1 | x0.85 | x0.7 |
| Monster speed | x0.9 | x1 | x1.05 | x1.15 |
| How far monsters spot you (`detect_range`) | x0.85 | x1 | x1.2 | x1.4 |
| Extra monsters per room | 0 | 0 | +1 | +2 |
| Floor size (`floor_size`) | 72x72 | 84x84 | 96x96 | 104x104 |
| Rooms per floor (`rooms`) | 15 | 19 | 23 | 27 |
| Boss HP | x0.7 | x1 | x1.3 | x1.6 |
| Elite chance | x0.5 | x1 | x1.4 | x1.7 |
| Drop chance | x1.2 | x1 | x1 | x0.9 |
| Drop quality (Magic, Rare, Epic) | x0.7 | x1 | x1 | x1 |
| Heal on each new floor | 25% | - | - | - |
| Light | brighter | - | darker | much darker |
| Souls | x0.65 | x1 | x1.6 | x2.5 |
| Feats count (achievements, the Tree's feats, records) | no | yes | yes | yes |

Pilgrim spares the hero but pays for it, and its card says so in red: about two thirds of the
souls (x0.65; with its smaller floors, a Pilgrim run pays about 0.6x a Keeper run that ends the
same way), rarer Magic, Rare and Epic gear (`loot_quality`), and no feats (`counts_feats`): its runs don't move
achievements, the Tree of Souls' feat nodes (so the oaths), the deepest floor or the victories.
Quests and the bestiary count everywhere. On every card, the souls line is red below x1 and green
above.

Bigger floors get more of everything with their rooms: monsters, chests, hazards, encounters and
items lying around. A floor starts with at most `max_monsters_per_floor` (110) monsters, so the
phone keeps up on Nightmare; the seal never asks for more than `seal_max` (50) kills.

Pilgrim, Keeper and Martyr are open; **Nightmare unlocks after a win on Martyr** (`unlocked_by`).
**Ascension**: a Nightmare win opens **Nightmare +1**, a +1 win opens +2, up to +10
(`data/ascension/`, `AscensionDef`, picked on a strip under the difficulty cards, which lists every
twist up to the chosen level, the next one and the souls multiplier). Each level adds exactly
one readable twist on top of the ones below (pillars.md): tougher monsters, harder hits, more
elites, higher prices, one more monster per room, faster monsters, tougher bosses, darker floors,
less max HP, harder hits again... and 10% more souls per level. None shortens the time to dodge
(the fairness floor would take it back anyway).
The last choice is remembered (gold frame), shown in the HUD and on the end-of-run screen.
The difficulty window (`DifficultyPanel`, one `DifficultyCard` each) says what changes in plain
words, compared with Keeper (`DifficultyCard.effects()`: "Monster health +30%", "Time to dodge
-15%", "+1 monster per room", "Monsters spot you sooner", "Bigger floors (+20%)"...; green helps,
red makes it harder), the souls it pays, and for a locked one what unlocks it.

## Between runs

The game opens on the **title screen** (`src/ui/title/`): play, visit the shrine, see your records.
A run left open (the app closed mid-run) shows **Resume the descent** above Descend, as wide as
the other buttons, its floor and level on a second line.
There is no class to pick: everyone starts the same, and becomes who they want during the run.
The bosses of each act are shown with what a run is; the Dawn Knell button (the daily run) opens a card that explains it (same
dungeon for everyone today, the day's start, your score); the records sit on a strip (souls to
spend, runs, victories, deepest floor, difficulty); the Shrine button wears an "Souls to offer"
badge when souls can buy something. The title-side windows (shrine, difficulty, options) use the
game's RPG skin like the bag (`MenuWindow` in `src/ui/common/`: an `RpgWindow` with its Close
button and a header line within reach, big switches, strips and badges).

**The Dawn Knell** (the daily run: the shrine's bell tolls each dawn, `DailyRun`, `DailyDialog`, the button under Descend): one run a day, the same all day (UTC),
offline. Each floor is generated from the day and its depth, everyone starts with the day's
weapon and relic (shown on the button), on Keeper. The day's first attempt is the official one
(counted when it starts: quitting doesn't give another); its score is kept with the best ever and
the days in a row (`Profile.daily_*`); later attempts that day are practice. Score: 1 per kill,
30 per floor, 150 per boss, 1000 for a victory, 1 per 5 gold picked up. The game over screen
shows it. **The day's omen** (from afar: the remote settings' `daily_omen` for that date,
`DailyRun.omen()`, docs/online.md "Remote settings"): on some days a curse or a floor event lies
on every normal floor of that day's Dawn Knell (not the first floor, not the wardens'; both ways
down), told on the Dawn Knell's card and in the log at the start. Most days have none. **The
same race for all:** the omen is the only remote value a Dawn Knell takes (no balance multiplier,
no event bonus), and its day, floors, weapon, relic, omen and board all come from the UTC day, so
a player in Tokyo and one in Paris play the same run at the same instant, and a resumed one keeps
its start values.

**Events** (the remote settings again): for a while (a weekend) the Well can hold an event, its
plaque on the title screen under Credits: its name, a souls bonus for runs started during it, a
floor event made more likely, the time left (the plaque leaves when it ends, even while the title
stays open). A run started during it keeps it to its end; the Dawn Knell never gets it. A
**message of the day** can take the tagline's place on the title.

### Online leaderboards

**The Roll of Souls** (`LeaderboardsPanel`, the **Leaderboards** button under the records on the
title screen, and the end screen of a Dawn Knell): one of the game's two online parts (with the
gameplay statistics, [interface.md](interface.md#privacy-and-credits)), on Talo (how it is built,
set up and protected: [../online.md](../online.md)). Everything else stays offline, and the game
plays the same without network or without a key in the build (the page then says the leaderboards
are unavailable). **Off until the player chooses to publish**: before that, nothing is sent and
the boards aren't even read.

- **The Dawn Knell's board** (`data/leaderboards/boards/daily_challenge.tres`): the day's
  official attempt only (never practice, never a debug run), its points, one entry per player and
  day, highest first. Tabs **Today** and **Yesterday**. The score is sent when the run ends (a
  death, or a win; a win then the endless floors sends the better one), queued while there is no
  network (`user://leaderboards.json`, not the save) and tried again after a minute, then less
  often (twice as long each time, at most 8 minutes, and when the app comes back); a score not
  sent before its day ends (UTC midnight) is dropped.
- **The page**: the first 50, the player's rank (and the lines around it when past the 50), the
  board's rule, a loading line, "no network" with **Try again**, "no one yet". Phone and PC, touch,
  mouse, keys (Q / E switch boards when there are several) and gamepad (MenuWindow, MenuNav).
- **The Well's Toll** (the page's last tab, *Le Tribut du Puits*): the world counters every
  player adds to (demons slain in the Well, wardens laid to rest, souls claimed, floors descended,
  potions drunk, Last Knells rung, Nameless Keepers, Dawn Knells answered, souls offered to the
  Tree), the world's number and the player's own share (numbers grouped per language). The title
  screen turns through them on a discreet line at the bottom. A run adds its share when it ends,
  only with the gameplay statistics' consent; the numbers are read once the player published their
  scores or accepted the statistics; offline or without a key, nothing shows. How it is built:
  [../online.md](../online.md#world-counters-the-wells-toll).
- **The choice and the name** ("Name your soul", `PseudonymDialog`): asked the first time the page
  opens or the day's official toll starts. It asks plainly **Publish your scores online?**, says
  what is published and to whom (the scores, a run summary and the pseudonym, public, on Talo),
  links the privacy policy, and offers **Don't publish** and **Publish my scores** side by side,
  the same size; Back is Don't publish. Not published: the page says so and its header button
  asks again; **Options > Privacy > Publish my scores online** turns it on or off (the first time
  through the same question). Published, the player is an anonymous player made on the device (a
  random id, nothing else) shown under a **pseudonym**, changed in Options > Privacy. 3 to 16
  characters among the font's letters (accents too), digits, spaces and `- _ . '`, at least one
  letter, no `#`, no refused word (`LeaderboardsConfig.banned_words`, read without case, accents
  or digits for letters). The default offered: "Soul". Turned off, nothing is ever sent nor read
  and what waited is dropped.
- **The tag** ("Clayton#4821"): every name shown to players carries four digits after a `#`,
  worked out from the player's anonymous online id, so two players may share a name but nobody
  can pass for another: the same on that device for good, typed by no one (a `#` is refused in a
  name). Shown on every row of the boards, the player's place, the page's "You appear as
  Clayton#4821", the question ("You will appear as..." under the field, following what is typed),
  Options > Privacy and the feedback's signature. How it is made:
  [../online.md](../online.md#names-and-tags).
- **Prepared, not shown yet** (data only, `submits` and `shown` off): the deepest floor and the
  fastest win on each of Pilgrim, Keeper and Martyr, the highest Nightmare ascension won, and La
  Veille's nights (when that mode exists).

Every run ends (death or victory) with **souls** (`DungeonConfig` > Souls, `souls_for_run()`):
a tenth of a soul per kill (the tenths add up over the run, rounded once at the end), 4 per floor
gone down, 10 per boss, 40 for a victory, times the difficulty. Going deeper pays, farming
monsters doesn't: in a run that dies at act III's boss on Keeper (about 80 souls), the kills are 25 of
them. Souls are kept forever (gold only lasts for the run). At the **shrine** (`ShrinePanel`)
they buy the nodes of the **Tree of Souls** (`data/shrine/soul_tree.tres`, `SoulTreeDef`,
`SoulNodeDef`). Four branches, each a fantasy, side by side on one screen (`SoulTreeView`):

| Branch | Nodes, top to bottom ("or": a fork, taking one shuts the other) | Oath at the end |
|---|---|---|
| Flesh | Vitality; Iron Skin or Communion (heal 5% a level when a floor is won); Provisions; Death Denied (a Phoenix Feather from the start: a second life through the trial of the Threshold, see builds.md) or Blood Pact (+20% max Health, heals 30% weaker) | Oath of the Colossus |
| Blade | Might; Keen Eye (+crit) or Quick Hands (+attack speed); Armory (pick the starting weapon, 5 levels); Spoils of the Fallen (elites drop Magic gear) | Oath of the Duelist |
| Arcana | Gift of the Arcane; Pyromancy, Templar's Vow (new items); Forbidden Library; Satchel of Tomes (start with a tome) or Swift Litany | Oath of the Heretic |
| Greed | Loaded Dice (rerolls); Swiftness, Exile (banishes); Master Smith, Cartographer (stairs, merchant and forge on the minimap); Haggler (-15% prices) or Laden Stalls (+2 items) | Oath of the Vulture |

A node opens once a node above it is bought; some also need a **feat** (an achievement: "?" on the
node, the feat in its card). Tapping a node shows on the right what it does now and next, what
opens it, and Buy. **Reset the tree** gives every soul back, every level of every node
(`SoulTreeDef.reset_cost`, 0: free), but it is earned: once every `reset_runs` (3) finished runs
(`Profile.runs_since_reset`, counted by `Profile.record_run`: a death or a win, daily and Pilgrim
runs included; a run won then lost in the endless floors counts once; a run given up before
floor `reset_min_depth` (2) doesn't count, so quick give-ups don't buy a new tree). Until then the button is
greyed and says "Reset in 2 runs"; a reset starts the count again. Saves from before the rule
start with a reset earned, so nobody is stuck with an old path. Each node's effect is an `UpgradeDef` (`data/upgrades/`):
stats, a head start, perk choices, new items, or run rules (kind `RULES`, read by `RunBoons`:
heals, gold, loot, the merchant, the minimap). The old shrine's levels carry over as they are.

**Oaths** (`data/oaths/`, `OathDef`): the end of each branch opens one. Once one is open (or the
Armory), "At the Well's Edge" (`OathPanel`) comes between the difficulty and the run: swear an
oath or none, and pick the starting weapon (Armory). An oath is an "X, but Y" start (table below).

**The Armory** is bought in 5 levels (`data/upgrades/armory.tres`: `armory_weapons`, an ordered
list, `armory_first` 3 at level 1, `armory_per_level` 2 more each level; costs 90 / 150 / 210 /
270 / 330 souls, 1050 in all). Level 1 opens one weapon per way to fight, the rare ones come last:

| Level | Adds | Weapons |
|---|---|---|
| 1 | Katana (the usual start), Bow, Frost Staff | 3 |
| 2 | Sai, Spark Wand | 5 |
| 3 | Lance, Battle Axe | 7 |
| 4 | Whip, Shuriken | 9 |
| 5 | Greatsword, Templar Sword | 11 |

A weapon in `content_db.tres` > Locked Items (the Templar Sword, opened by Templar's Vow) is
offered only once unlocked (`ShrineUpgrades.armory_weapons`). The oaths' weapons (War Hammer,
Rapier, Ember Tome) are not in the list: they come with their oath. Ninjaku and Pickaxe are left
to the floors. The node's detail says what the next level adds ("Now: 5 starting weapons >
Next: +2 weapons: Lance, Battle Axe", a weapon still locked marked so); the Well's Edge shows only
the weapons the level opened and "Armory level 3: 7 weapons. More in the Tree of Souls.". A
starting weapon the level no longer offers (an older save, a reset tree) falls back to the usual
Katana. Saves that bought the old one-level Armory keep it as level 1.

| Oath | Rule |
|---|---|
| Oath of the Colossus | the Hammer, +30% max Health, 15% slower |
| Oath of the Duelist | the Rapier, +10% crit chance, crits x2.5 (instead of x1.75), -20% max Health |
| Oath of the Heretic | the Book, +50% skill damage, attacks 20% slower |
| Oath of the Vulture | +35% gold and better loot, merchant 25% dearer |

Each oath card (and its node in the tree) lists the oath line by line (`OathDef.effects()`): the
weapon in plain text, every gain in green, every cost in red, so the price of an oath reads at a
glance. Every oath has at least one of each (a unit check).

Each oath also keeps its **vow** (`OathDef.lore`): the line a keeper of old swore at the bell
(docs/lore.md 6), shown dim above the rule when its node is picked at the shrine. Lore only:
the rule is always the plain list below it.

Not in the daily run (everyone starts the same). The run keeps its oath in the save (`RunState.oath`).
The choice changes only by the player's taps (`Profile.select_oath()`, `select_start_weapon()`):
opening the panel changes nothing, and a saved oath the tree no longer opens (a reset tree), or a
weapon the Armory no longer offers, stays saved and reads as none (`Game.sworn_oath()`,
`Game.picked_weapon()`), shown as Unsworn or the usual weapon.

**The pace of the tree** (measured: `tools/balance` economy mode, table "economy_campaign"): a
full tree (the dearer side of each fork) is a campaign of about 47 runs on Keeper (8765 souls), every source
counted (runs, quests, the bestiary's ranks and challenges, achievements), some 29 hours; the
first node is bought after the first run; the bestiary and the achievements pay about a sixth of
the tree in the first 10 runs (they used to pay more than the whole tree). Martyr and Nightmare
pay more per run (x1.6, x2.5, and more monsters). A career kept to **Pilgrim** (no achievements
there, its runs reaching the end sooner: table "economy_campaign_easy") fills the tree in about
64 runs (~43 hours): it progresses, more slowly than Keeper, never faster (it paid x0.5 until
2026-10-23: 77 runs, and a Pilgrim run brought under half a Keeper run's souls).

Locked items (`content_db.tres` > Locked Items) never appear on the floor until unlocked.
The `Profile` autoload keeps souls, upgrades and records in `user://profile.json` (works on phones).

## Saving and resuming

`SafeFile` writes and flushes a temporary file, verifies its error state, length and bytes,
then renames it over the destination. A short write never replaces the previous save; a failed
rename keeps the previous file and the complete recovery copy. Reads try a complete `.tmp`
when the main file is missing or damaged (including the title's Resume check). The options
(`Settings`, `user://settings.cfg`) are written beside and renamed the same way. `Profile.saved`
means the write succeeded. An imported cloud profile is validated, including nested counters,
and committed to disk before replacing memory; malformed input or disk failure leaves progress
unchanged. Older local profiles may omit fields introduced later. A local `profile.json` that is
damaged (a field of the wrong kind, an unreadable memorial, not JSON at all) is first copied
aside whole (`profile.json.damaged-<unix time>`, since the next save replaces it), then only its
damaged fields and entries are dropped (`Profile.repaired()`): one bad field never resets the
whole profile. Run fields with a wrong type,
including null in a non-nullable field or non-finite coordinates, are discarded before restoration.

The run in progress is saved (`RunSave`, `user://run.json`) when a floor begins and whenever the
app goes to the background (a phone call, switching apps, the window closed), never in the trial
of the Threshold, the Deeps or a debug run, and erased when the hero dies. **Resume the descent**
builds the floor again from its seed (`RunState.run_seed` and the depth: the same rooms, the same
things in them), puts the hero back exactly as saved (gear, bag, belt, perks, level, gold, Health),
and the run as it was (depth, souls, time and splits, the ways taken, the choices waiting, the
oath, the Nameless Keeper waiting, the last boss slain: its relic when the run goes on endless
after a win).

**What was used up stays used up** (`World.spent_data()`, the save's `floor`): putting the app
away and coming back never hands anything out again.
- By cell: chests opened, holes filled, cracks that gave way; secret rooms (their state, in the
  map's order), the pact sworn, the fragment read, the seal's kills.
- By number (`FloorLedger`): while a floor is laid, each item lying around, gold pile, prop and
  encounter gets the next number of its kind, in the order the seed lays them; what the hero took,
  broke or used is saved as [number, id] and taken off the rebuilt floor quietly (nothing
  dropped, no sound). The floor's own monsters keep their numbers the same way
  (`Monster.floor_index`, "slain"), the hidden floor's included. The id is a guard: a number that
  comes out as something else is left alone, better one too many than the wrong one gone.
  Nothing laid while the floor is built depends on the hero (a potion over the carry cap lies
  there as a potion, never turned to gold), so the same seed lays the same things.
- The floor's own monsters still standing come back where the seed put them, as it rolled them
  (rank, affixes), a hurt one with the **share of its Health** it had left ("wounded":
  [number, id, share]; at least 1).
- **Monsters that came later** and still stand (a summoner's calls, a trapped chest's or an
  encounter's monsters, a campfire's waves, what a slain one split into) come back **where they
  stood**, with their rank, affixes, share of Health and whether they were called in (no reward)
  ("later", by stable reference and id: a kind the game no longer has is skipped). Not an ambush's waves under
  way (an ambush quit mid-fight starts over), nor what stands in a living warden's arena (the fight
  starts over, the warden whole), nor statuses (seconds long), nor where the floor's own monsters
  had wandered.
- The ambush: cleared, it stays quiet, its chest back on the cell where it was put down.
- The merchant: his whole stock as it was (rerolled, sold to, locked, less what was bought) and
  his rerolls paid. An entry locked there and not bought also waits for the next merchant, and
  is never in his stock twice.
- What came later and is no monster (a monster's drop, a chest's loot) isn't saved: it is never
  laid again either. Except in a warden's cleared arena: a boss floor saved after its boss fell
  resumes there (`floor.arena_cleared`, `BossArena.clear_quietly()`), the warden gone, the stairs
  there, nothing given again (relic, heal, souls); what lies on its floor and wasn't laid by the
  seed (his loot, his gold: `floor.left`) lies there again; the hidden way opens again if the key
  is still in the bag; on the hidden floor, its hoard stands there again (open if it was). Only
  the bottom of the Well's fall still goes on at once (`boss_slain`, to its ending).
- The merchant, again from its seed: an entry locked there drops one rolled copy of itself, never
  an ordinary twin (`Merchant.drop_rolled_twins()`).
- Every kind of floor is restored this way, boss floors and the hidden floor too. A seal broken
  before quitting comes back open quietly (no sound, no guiding light, no Regeneration heal again).

**A game update in between**: the floor's block carries a stamp (`RunSave.floor_stamp()`: the
game's version and `RunSave.FLOOR_FORMAT`, bumped by hand when a change lays a seed otherwise
without a new version). Another build's floor may come out otherwise from the same seed, so its
cell and number data would land on the wrong things: the floor is laid fresh instead, a note says
so ("The Well has shifted since you left: this floor is laid anew."), and the hero and the run
come back whole.

**Stable content references**: items (including belt and rolled gear), perks, skills, oaths,
bosses, banished cards, merchant stock and later monsters use namespaced ids such as
`@item:katana`, independent of their current filename. `ContentCatalog` resolves them through
`data/save/content_catalog.tres`. Version 3 converts known legacy paths recursively without
changing unrelated data; version 1 still receives its original migration first. Historical
paths remain aliases even after the old file disappears. Removed content is skipped; unknown
paths never load arbitrary resources. The floor stamp and its rebuild rules are unchanged.

**Versions and damaged files**: `RunSave.VERSION` (3) is written in every save. An older one is
migrated (`RunSave._migrate()`, one step per version; version 1 saves keep their run and hero,
their floor is laid fresh, having no stamp), a newer one (a game rolled back) is not read. Every
field the game reads is checked against `RunSave.SHAPE` first: a field of the wrong kind (a
hand-edited or damaged file) is dropped and logged (`WARNING: Run save: ...`), and its default is
used, so a damaged save never stops the game; only a damaged hero makes the run unreadable.

## Quests

Every day, 3 **daily quests**; every week (from Monday), 3 **weekly quests**
(`data/quests/`, `QuestDef`, drawn by `QuestBoard` from the date: everyone gets the same ones,
UTC). "Slay 60 monsters", "Open 4 chests", "Reach floor 6 in one run", "Go through a cursed
floor", "Defeat 5 bosses", "Win a run"... They count what you do in any run during that day
or week (`Profile.period_stat`), pay their souls as soon as they're done (a toast in the game:
5-18 for a daily quest, 30-70 for a weekly one, more for a harder goal)
and show on the title screen (**Quests**, also a tab of the Codex) with the time left. Paying is
gameplay's (`QuestBoard.pay_finished()`, which emits `Events.quest_completed`): during a run (the
run's records), and when the title screen comes up for one finished in a run that ended before
paying it (a crash, an old save). The Codex only shows them: looking at its tab pays nothing.

## The Wardrobe

What the hero wears for the look alone: no number of the game changes with it. For now, auras
(`AuraDef`, drawn by `AuraVfx`: docs/vfx.md "Auras"); a new kind is a new `CosmeticDef.Slot`
and a subclass of `CosmeticDef`.

- **Data**: `data/cosmetics/` (one resource each), listed in `content_db.tres` > Cosmetics. Each
  has its id, name, words, Wardrobe order and what opens it (`unlock`, a `CosmeticUnlock`
  subclass: `WinUnlock` = a won descent, on a difficulty or any one). A new kind of condition is
  a new subclass. The unlock is asked of the profile each time (never stored), so changing it
  in the data applies to every profile.
- **The three auras**: **Dawn's Grace** (divine: a ring of light, rays turning, sparks rising;
  any won descent), **Shroud of the Deep** (dark: a pool of dark with a crawling edge, wisps
  sinking; won on Keeper), **Brand of the Pit** (demonic: embers flaring round a smouldering
  core, the halo flickering, embers flying; won on Nightmare).
- **The profile** keeps only what is worn per slot (`Profile.worn`, `"aura"` -> id). `Wardrobe`
  reads it: one locked since (the data changed) or gone from the game is worn as nothing,
  without touching the profile. A locked one can't be worn.
- **Where it shows**: the hero in every run (`Player.wear_aura()`, at the run's start), the hero
  by the Well on the title, the Wardrobe's preview, and the Nameless Keeper made from a hero
  (his snapshot keeps the aura's id, `AuraTrait`). The debug panel's **Next aura** puts each on
  the hero in turn for the run, locked or not (not a debug run: nothing changes).
- **The Wardrobe** (title screen, under Credits and Feedback): left, the hero wearing what is
  worn, turning round; right, a row per aura and "No aura": Wear, Worn, or (dimmed) what opens it.

## Codex: bestiary, achievements, runs

Five tabs: Quests, Bestiary, Achievements, Runs and **Voices** (what the Vigil-Keeper and the
keepers said, by speaker: presentation.md, "The Vigil-Keeper and the keepers").

**The bestiary** (codex tab, also in the pause menu): every monster and boss, unknown, *seen*
(it spotted you: `Profile.mark_seen`) or slain. Tap one for its page (`MonsterPage`): its look,
what it is, its stats and ways (flies, keeps its distance, traits, a boss' phases), its
**attacks** with an **animated preview** (`AttackPreview`: the same red warning, then the shots,
blast, charge, summons or heal, built from the WeaponDef / SkillDef data), and its challenges.
- **Hunter ranks** (`BestiaryRules`, `data/bestiary.tres`; `Bestiary`): Known (1 kill), Hunted
  (10), Mastered (30) for monsters, 1/3/6 for bosses. Each rank pays souls once
  (2/4/8, bosses 8/12/25); Mastered gives **+10% damage** to that kind for good.
- **Challenges** (`HuntChallenge`, watched by `HuntTracker`): every monster gets those that
  apply (an elite one, pushed into a hole, 3 within 5 s, untouched since it saw you, a crit
  finish; summoned monsters and the Threshold's spectres count for none), every boss its own (with a ranged weapon, with a melee one, under 90 s, without a
  potion, losing less than 25% HP) plus one with a given weapon (`MonsterDef.challenges`: the
  Bloated King with a Bow, the Ember Ronin with a Katana...). Done once, paid in souls, with a toast:
  2-4 for a monster's (3 for an elite one, 4 for a hole, 3 for a streak, 3 untouched, 2 for a crit
  finish), 5-15 for a boss' (melee 5, ranged 8, no potion 8, under 90 s 12, losing little Health 15,
  its weapon 12).

The **Codex** (`CodexPanel`, from the title screen and the pause menu) is built in code in the
game's skin (`RpgWindow`, like the bag and the forge): four tabs in its header, the souls you hold
on the right, and under the tabs a summary line plus one sentence saying what the tab is for
(souls are kept between runs and spent at the Shrine; gold is lost when a run ends). Lists scroll
with a finger (`TouchScroll`); `CodexRows` builds their rows, with a tick box for what is done.
- **Quests**: today's and this week's quests side by side, each with its goal, a progress bar,
  its reward in souls ("Received" once paid) and the time until new ones.
- **Bestiary**: act by act (floors, how many kinds slain), then the hidden floor's boss under a
  "???" heading until it was met (its floor's name after), a card per monster and boss
  (`CodexCard`: picture, its name on two lines when it must, never cut, rank, kills, a bar toward
  the next rank, gold frame once Mastered, Boss and Celestial badges; unknown ones are dark
  shapes until met; 192x206 so the longest names fit, « L'Accapareur Doré », « Sentinelle de la
  Brèche », in BODY: the title suite checks every card in French and English). Its page has three
  columns: look (drawn whole: a big warden's art is drawn smaller to fit its box, the Maw's too;
  dressed as in a fight, the Nameless Keeper a dark shade with his lantern), where it lives and
  its Celestial form (only for a kind that can come Celestial: `Bestiary.can_be_celestial()`,
  from the rules that roll the rare ranks; never Tôma, the Maw, the Nameless Keeper or the Deeps'
  demons); attacks with the preview, how it behaves and its stats
  (Health, Damage, Armor, Move speed, each with what the number means); hunter ranks (slay N,
  +X souls, done or not) and challenges. A warden's page has two tabs in its middle column,
  **Attacks** and **Chronicle** (`ChronicleRows`, asking `Narrative`): "Chapters 3 of 6, Fragments 1
  of 3", the open chapters in order with their lines, the locked ones as "???" with what opens them
  in plain words ("Slay it 4 times", "Find 2 fragments about it", "Reach floor 7"; a deed as its
  riddle in the Well's voice until the fragment that gives its rule away is found), its waking
  words, and its fragments (found ones are buttons that open their reading panel again, the
  others "???" with where they lie: "Found on the floors of Act II"). Unmet wardens show nothing
  but "Meet it to begin its chronicle".
- **Achievements** (`data/achievements/`, `AchievementDef`): a goal on one of the profile's counters
  (kills, elites, wardens, kinds of creatures, depth, victories on Martyr / Nightmare / ascension,
  monsters pushed into holes, chests, Epic items, encounters, gold or level in one run, secret
  rooms found, hidden bosses slain, trials of the Threshold won: *Not Yet*, the two endings), with a progress bar and its reward; the closest to done
  first. Reaching it pays souls, with a note at the top of the screen. A **secret** one
  (`AchievementDef.secret`) shows as "???" ("A secret feat. Some doors only open from the other
  side.") until reached: "Laid to Rest at Last" (slay the hidden floor's boss, 50 souls) would
  give the hidden floor away. "What the Walls Keep": find 5 secret rooms (25 souls).
- **Runs**: the fastest wins, then the last 20 runs: how each ended (victory, or the floor and
  what slew you), when, the difficulty (with its ascension: "Nightmare +3", one translated
  sentence), how far (floor N of 12), how long, level, weapon, kills
  and the souls earned, each fact its name over its value (a value wraps between words, never
  inside one).

## The two endings

The first win ends on the story's victory text (the first ending: the souls come back, the bell
rings, "the Well goes deeper still"). Afterwards a run is won at the bottom of the Well
(dungeon.md): when the Maw's mask crumbles, the **ending panel** (`EndingPanel`, the game's
skin, the game paused; Back doesn't close it) shows "What Is Left" / « Ce Qui Reste », a line,
and one card per ending (`FinaleDef.endings`, `EndingDef` in `data/story/endings/`):

| Ending (FR / EN) | Its button | What it means | Achievement |
|---|---|---|---|
| Le Dernier Glas / The Last Knell | « Sonner la cloche » / "Ring the bell" | seal the Maw: Tôma dies in peace, Hana rests, Kagari wakes | *Le Dernier Glas / The Last Knell* (100 souls, secret) |
| Le Gardien Sans Nom / The Nameless Keeper | « Prendre sa place » / "Take his place" | the hero stays down there, the nameless keeper of the seal; Tôma climbs back to wake the village | *Celui qui Veille / He Who Keeps Watch* (100 souls, secret) |

The choice is kept in the profile (`Profile.ending`, the last one chosen; "" before any) and
counted (`ending_bell`, `ending_keeper`: `AchievementDef.Stat.ENDING_BELL` and `ENDING_KEEPER`,
after the others), not on Pilgrim (like every feat). Then the victory screen takes the ending's
title and tells it (three short lines), with the run's numbers and souls as usual; Keep going
leads on to endless mode.

The endings shape the next runs (`EndingDef.keeper_change`): **take his place** keeps the hero as
the **Nameless Keeper** (`Profile.keeper`, a snapshot of him: monsters.md, "The Nameless
Keeper"), who waits at the bottom of the next runs instead of Tôma and the Maw, the last fight;
beating him frees him and the choice comes again (its lines told for him: `keeper_hint`,
`keeper_text`, `FinaleDef.keeper_choice_lore`). One waits at a time: taking his place again puts
this hero there instead. **Ring the bell** frees the one waiting: the bottom is Tôma's and the
Maw's again. The codex keeps the Keepers freed (his page). Pilgrim's endings count the same.

## Run timer (speedruns)

Every run is timed (`RunTimer`, `RunState.time`): in-game time, in real seconds (hit stops and
slow motion neither slow it nor make it jump: `HitStop.real_delta()` divides a frame's delta by
the time scale that frame began with, read before its physics where blows land), counting in the bag, the shop and the perk choices (deciding is part
of the run) but not in the pause menu, while a floor loads or during its title cards. It keeps
counting in the trial of the Threshold (a second life is part of the run). It is saved
with the run, so quitting and coming back doesn't reset it.

- **On screen**, under the map (`Hud.show_run_time()`; Options > Run timer hides it). Once the
  last boss falls, the win's time stays there, in gold, through endless mode.
- **Splits**: taking the stairs notes the floor's time (`RunState.splits`) and shows it a few
  seconds: "Floor 3  4:12.3  -0:05.2", green when ahead of the record run, red when behind.
  The hidden floor (dungeon.md) has no split of its own: it keeps the depth of the boss before
  it, and its time goes into the next floor's split. The bottom of the Well has one, after the
  last act's (13), the win's.
- **Records** (`Profile.best_times`, `best_splits`): the fastest win per difficulty and ascension
  level (`RunState.record_key()`: "normal", "nightmare/a3"), with its splits to race against.
  A run won at the bottom of the Well (`RunState.goes_to_bottom()`: the bottom was open when it
  began) is a longer race and has its own record ("normal/bottom", "nightmare/a3/bottom"): its
  splits race the last run to the bottom, and a first win's record stays the first win's.
  (Profiles from before kept a win at the bottom under the first win's key: it stays there.)
  Daily runs keep none (their own race).
- **Where it shows**: the end screens (the time, then "New record!" or the record to beat), the
  log, and the Codex > Runs (each run's time; the fastest wins, then the fastest to the Well's
  Bottom on their own line).

## Kagari's lasting changes

The [playable village](village.md) now sits between descents. Its first request is accepted from
the Veilleuse, recovered on floor 2 and returned to her: Ren wakes, roots recede and 15 souls
are awarded once. Her completed request unlocks Sayo's Last Verse: accept it, recover the sheet
on floor 4 and return to Sayo for her awakening, the western path cleared and 20 souls once.
An older profile with Ren already awake can accept this next request without starting over.
The Wanderer sells two one-time lamp restorations for 5 and 8 souls; neither
changes a run's kit. Every Take his place ending leaves a permanent equipped statue in the
village's memorial register, independent of the active Keeper and the capped codex/run history.
