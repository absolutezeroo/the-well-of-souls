# Balance log

Dated entries, newest first: what was measured, what changed and why, before/after numbers, open
questions. How to measure: [balance.md](balance.md).

## 2026-10-28 - Kagari's third rescue and lane lanterns (task_377)

What changed: a third village request, **Seeds of Mourning** (Gen's seed pouch on floor 5, after
Sayo's), pays **25 souls once**; the Wanderer's **Lanterns of the Lane** cost **10 souls once**
after it. Why these numbers: the chain's rewards grow by 5 souls per request with the floor they
send the hero to (15 at floor 2, 20 at floor 4, 25 at floor 5), and the three lamp services cost
5, 8 and 10: the village stays a one-time source of a few runs' worth of souls, beside the Tree
of Souls' nodes of 90 souls and more. A garden paying souls every village day was refused (no
recurring income outside runs; souls are Kagari's people brought back). Checked by
`unit.village` (each request deeper than the one before, paying at least as much, 30 at most).
Not measured with the bots: village rewards are one-time and outside runs.

## 2026-10-28 - The fairness contract: wind-up floors, one twist per ascension (decision 0008)

What changed: no wind-up of an attack that hurts goes under **0.4 s** (a boss's **0.5 s**; a
shockwave's, a burst's, a fuse's or a trap's warning **0.4 s**) after the difficulty's, an
ascension's and the phases' multipliers (`data/combat/combat_rules.tres`, "Fairness contract").
Before (the audit of 28 October, its raw data in the session's `audit_feel/fragments.md`): on
Keeper 18 of 49 monsters wound up under 0.4 s (bats and racoons 0.20 s from floor 1, rats and
skulls 0.25), every boss's third phase 0.29-0.39 s, the roar's shockwave 0.35 s, Nightmare+10
down to 0.13 s; the monsters' Volley (Eye, Sorcerer, Horned Augur) had no wind-up at all. Now:
every one of them at its floor on every difficulty, Volley 0.5 s (`cast_time`), the spike plate
0.4 s (was 0.35), the arrow plate 0.4 s (was 0.3). What is above the floor keeps its own and its
difficulty's share (Nightmare still x0.7 of a long wind-up).

Ascensions: **A6 Swift Stalkers** is now only "monsters 8% faster" (its "x0.9 time to dodge"
went: the floor would have taken most of it back, and two twists in one level read badly);
**A10 The Well's Heart** is only "+10% damage again" (its +15% monster Health went). At
Nightmare+10 monsters have x1.32 -> x1.15 Health from the ascensions and x1.21 damage as
before. Not re-measured with the bots: the expected effect is easier Keeper fights against
the fastest monsters (bats, racoons, rats, boss third phases) and a slightly easier
Nightmare+10; the challenge stays in numbers, density and patterns (the decision).

Damage budget, now a check (`unit.fairness`): on Keeper the expected hero's worst ordinary hit
is 13.3% of his max Health (a beast's charge at depth 7: 28 of 210), the worst boss hit 17.7%
(the Giant Frog's fierce leap at depth 3: 23 of 130), at the top of the hits' roll; budget 20% /
30%. Unchanged by this pass.

Feel numbers (presentation.md "Feel limits"): one input buffer of 0.12 s (was an attack-only
0.3 s, counted in game time) for the attack, the roll and the skills, in real time
(`PlayerDef.input_buffer`; core_tests' pin updated with it).

## 2026-10-28 - Floor pacing, bad-luck protection, a heal before bosses (decision 0012)

**Monsters by the room's size.** A fight room's share is now `room_cells` (70) open cells per
`monsters_per_room` (2) on the first floor, plus the floor's extra ones per 70 cells too
(`FloorRules.room_monsters()`), between 1 and `max_monsters_per_room` (9, was 6: a great hall may
hold more, a side room fewer); an elite or a big body (radius 14+) counts 2 (`tough_cost`); the
floor's cap counts the same way (`max_monsters_per_floor` 130, was 110 bodies: about 100 bodies).
Calm rooms on the way (`max_fights_in_a_row` 3) hold none. `room_cells` was set so a floor holds
what it did: measured on the same 960 floors (`tools/levels/floor_report.py`, 20 seeds, every
floor, the four difficulties), monsters a floor 47 / 65 / 86 / 97 before, 49 / 68 / 90 / 97 after
(Pilgrim / Keeper / Martyr / Nightmare), elites and big bodies counted twice 55 / 80 / 108 / 125
before, 57 / 83 / 113 / 123 after: the same fight, spread by size (r(open cells, monsters) 0.02 ->
0.64). The seal (70% of the floor's monsters) follows. The balance tools' room (`BalanceLab.
room_size()`) is a room of `room_cells` cells: what a room held before, except the deepest rooms on
Normal and up, now one monster more where the old cap of 6 cut them (model, `--mode=model`: same
rooms to floor 6, then +1 where capped).

**Chests**: one a floor at least (`chests_min` 1, `chests_max` 1, times the floor's size: two on
Martyr and Nightmare floors), was 0-2: 1.56 a floor before, 1.60 after, never none (35% of floors
had none).

**An elite at the peak** (from floor 2) on floors whose ambush or pact door isn't there: about
0.3 more elites a floor on average, within the counts above (it counts 2 in its room).

**Bad-luck protection** (`pity_after` 20, `pity_growth` 1): simulated on the plain odds (Rare or
better 5.7% on floor 1, 10% around floor 5, 15% around floor 9), the share of Rare finds becomes
7.4% / 10.8% / 15.4% (+30% / +8% / +3%) and the longest run without one 230 / 103 / 55 finds ->
38 / 34 / 29. Kept gentle on purpose: it cuts the long droughts, not the odds.

**A heal before every boss**: the Spring of the Last Vigil heals whole in the boss floor's first
room on every difficulty (Pilgrim already healed 25% on each new floor). The balance tools' boss
fights already start from a set Health (`BalanceArena`), so their measures don't move; in play a
hero who drinks meets the boss whole, whatever the floor before cost him.

Open: the floor's real length (3-6 min on the phone, telemetry `floor_times`), the density and the
calm rooms' share to tune by playing (roadmap).

## 2026-10-27 - Heal share only where the hero was hurt (tools only)

The heal share targets (arena "heal share", model "heal share") now judge only fights where the
hero took at least 30% of his max Health (`BalanceTargets.heal_share_min_taken`, targets.tres).
Seen on 2026-10-24: at the bottom of the Well the act IV expected build's kite bot took 30-200
damage and the Leech rune healed 30-100 of it, flagged "heal share > 25%" against Tôma too; that
is no sustain undoing a boss. No game data changed; not re-measured (the balance suite is slow).

## 2026-10-26 - Kagari's fictional day

The previously timeless hub now starts at 08:00 and advances one full day per 960 seconds
(16 minutes) of active play, including descents. Residents walk at 42 world units/second
between authored appointments. Menus and offline time add nothing; the clock changes neither
infestation, combat, rewards nor UTC bounty rotation. Night services remain reachable by
knocking, so the schedule imposes no waiting gate. This duration is an initial presentation
tuning, not measured player preference; S23/Windows play-testing remains on the roadmap.

## 2026-10-25 - Glacial, Frenzied, Vengeful and Unstable

Four additional modular affixes, each weight 5, no bosses: Glacial and Frenzied from floor 3,
Vengeful from 4, Unstable from 5. Glacial: 25% slow for 2 s on direct hits and a death burst
(radius 52, warning 0.8 s, dungeon damage 3). Frenzied: walking speed x1.3 at or below 50%
Health, no attack-speed bonus. Vengeful: 3 direct damaging hostile hits start a warning (0.9 s,
radius 48, dungeon damage 6), then 6 s cooldown after the warning. Unstable: same warned area
strike every 5 s of engagement. Warning durations use normal FloorRules telegraph scaling.
Rank Health factor x0.9 except Frenzied x1. Existing Vampiric remains 60% direct-hit healing;
new tests cover actual Armor/ward results and rejection of ticks. Incompatibilities prevent
multiple burst modules and Swift+Frenzied or Thorned+Vengeful combinations (full table in
monsters.md). Original affix values and rank limits are unchanged.

Real engine pack probe: seed 347348, Keeper, act II depth 5, expected_a2, one ranked skeleton
and two commons, maximum hero Health 210; bots face_tank and kite, two workers, no cache:

| Elite | Ranked TTK, contact / kite (s) | Total damage taken, contact / kite |
|---|---|---|
| Glacial | 3.68 / 6.02 | 13 / 0 |
| Frenzied | 5.03 / 5.68 | 3 / 0 |
| Vengeful | 3.38 / 5.25 | 0 / 0 |
| Unstable | 3.98 / 5.48 | 0 / 0 |
| Vampiric (unchanged) | 4.58 / 5.22 | 7 / 0 |

Every variant cleared. Report: zero errors, one pre-existing plain-bat TTK warning (0 s versus
0.5-2.5 s target). Use the same command as the previous entry. These are single-seed fights,
not evidence of global balance: Vengeful/Unstable caused no damage in this sample, and a final
death burst can fall after the pack tool stops measuring. Separate game.modifiers checks prove
the riposte/pulse damage, fuse, cooldown and cancellation rules. Broader difficulties/crowds
and warning readability on S23/Windows remain task_269. Balance models also need to honour
compatibility when enumerating hypothetical affix combinations; these rows explicitly validate
the actual single affix on the spawned monster. The new pool intentionally changes five floor
fingerprints; FLOOR_FORMAT 3 discards old floor ledgers while preserving hero/run state.

## 2026-10-25 - Composable monster modifiers and Pestilent

Pestilent is a new weighted affix from depth 4 (weight 5 versus 10 for the original affixes),
regular monsters only. Rank Health x0.9; direct-hit poison 2/s for 4 s. Death: a warned burst
of radius 52 after 0.8 s, dungeon-scaled base damage 4 and the same poison. No burst down a
hole; no combination with Venomous or Bursting. Existing affix values are unchanged.

Real engine pack probe, seed 347348, Keeper, act II depth 5, expected_a2, one ranked skeleton
and two commons; two workers, no cache. Both kite and face_tank cleared every measured ranked
variant. Pestilent ranked TTK: 6.02 s kite / 4.88 s face_tank, versus Venomous 6.60 / 4.28 s
and Bursting 5.03 / 4.58 s. Total damage taken: 0 / 13 Health (hero maximum 210), versus
Venomous 0 / 9 and Bursting 0 / 3. Command:

```
godot --headless --fixed-fps 60 res://tools/balance/balance.tscn -- --mode=pack --only=act2,expected_a2 --difficulty=normal --bot=face_tank,kite --jobs=2 --seed=347348 --no-cache
```

Limits: one seed/build/difficulty, not a broad balance verdict. Room timing stops at the last
kill, so a delayed final burst can land after the measure; its warning/payload and fall rules
are covered by game.modifiers separately. The report has no errors and one warning: plain bat
TTK 0.0 s against the 0.5-2.5 s target. Follow-up: distinguish instant kills and settle pending
death effects in pack tools. Phone readability, crowd cost and wider balance need play-testing.
The new pool intentionally changes five recorded floor fingerprints; FLOOR_FORMAT bumped to 2.

## 2026-10-24 - A ranged Nameless Keeper: measured, and his shots made a boss' (bow, wand)

**The tool first.** A Keeper with a bow or a wand (`ranged_keep_distance` 170) was a standoff:
the kite bot backed off every drawn bow as if it were a swing it could step out of, and dodged
every shot sideways without ever closing in, so neither side hurt the other (timeouts, the last
entry). Two changes to `BalanceBot` (kite and player): a drawn bow or wand is stepped across, not
backed off from; and when only shots threaten it (shots in flight, a drawn bow) and its foe is
out of reach, it keeps closing in across their line (`CLOSE_IN` 1: 45 degrees, faster forward
than a boss backing off at 100). A warned skill, a fan's cone included, is still left at full
speed first (with the fans counted as "only shots", Gorr's kite wins fell from 4 of 4 to 2 of 4).
The arena measures the bottom of the Well itself now: `--keeper=bow,magic_wand,katana,hammer`
(Tôma alone for scale, then a Keeper per weapon from a sample hero, `BalanceContent.
keeper_snapshot`: level 15, Rare weapon with Brutal and of the Fox, Magic helm and mail, the
weapon's skills and a tome: katana + Fire and Ignite, hammer + War with Bloodrage and Thorns,
wand + Thunder, bow + Frost and Hydra's Quiver).

Every other boss, kite, Keeper, act's expected build, seeds 1-2, old bot / new bot: the same
results but one (Azure Wyrm seed 2, a win at 30% / a loss at 3% left); 16 / 15 wins of 20, times
and Health left within the seeds' noise. The balance suite's guards hold (Gorr 4 of 4).

**Measured, as he was** (act IV's expected build, Keeper, seeds 1-4, the bot closing in; face-tank
seeds 1-2):

| Keeper | kite | player (0.3 s reaction) | face_tank |
|---|---|---|---|
| Tôma alone (scale) | 4 of 4, 53-59 s | 2 of 4 (losses at 0-2% left) | loss, 33-35% left |
| katana + Fire | 4 of 4, 81-95 s | 1 of 4 (losses at 1-16%) | loss, 80-81% |
| hammer + War | 4 of 4, 89-90 s | 3 of 4 (a loss at 22%) | loss, 78-79% |
| **bow** + Frost | 4 of 4, 84-98 s | **0 of 4, losses at 41-54% left** | loss, 60-70% |
| **magic wand** + Thunder | 4 of 4, 82-87 s | **0 of 4, losses at 44-58% left** | loss, 66-71% |

**Reading:** the kite bot beats every Keeper and standing in front of him loses (pillar 1), but
an average player loses to a bow or a wand Keeper at half his Health, where he beats Tôma and the
hammer Keeper and nearly the katana one. The hit logs say why: 19-24 hits of his *basic* shot a
fight, from 48 to 235 px. He shoots the hero's own weapon as the hero does: a bow's arrow at 600
a second (a wand's bolt 520), 0.42 s apart; the monsters' bolts fly 220-320, 1.3-2 s apart. Drawn
0.5 s and arriving in 0.2-0.4 s, no one reacting in 0.3 s steps out of it; and his skills' bolts
(the wand's Arcane Bolt) were let go in the hero's face (49 px), warned or not.

**Changed** (`data/monsters/bosses/nameless_keeper.tres`, design/monsters.md):
- `ranged_shot_speed` **320**: with a ranged weapon his shots fly 320 at most (the monsters'
  fastest bolts);
- `ranged_cooldown_min` **1.2 s**: they come 1.2 s apart at least (before his attack speed);
- `ranged_attack_windup` **0.75 s** (0.5): he draws longer than he swings (a shot reaches from
  afar; a swing is stepped out of);
- `shot_min_range` **90**: his shot skills from 90 px out (0), never a bolt in the hero's face.

Tried and dropped: his skills' shots at 320 too (a slow fan lingers: the bow Keeper went from 4
player wins of 4 to 1), shots warned 0.8 s (0.65; no better, within the noise).

**After** (seeds 1-6, Keeper, the final bot):

| Keeper | kite | player | face_tank |
|---|---|---|---|
| Tôma alone (scale) | 6 of 6, 53-59 s | 3 of 6 (losses at 0-13% left) | loss, 23-43% left |
| katana + Fire | 6 of 6, 88-101 s | 0 of 6 (losses at 2-13%) | loss, 74-82% |
| hammer + War | 6 of 6, 89-92 s | 3 of 6 (losses at 6-32%) | loss, 70-79% |
| **bow** + Frost | 6 of 6, 95-115 s, Health left 50-78% | **3 of 6 (losses at 8-29%)** | loss, 63-66% |
| **magic wand** + Thunder | 6 of 6, 78-86 s | **0 of 6, losses at 6-29%** (was 44-58) | loss, 58-67% |

On Martyr (seeds 1-2): the player bot loses every fight, Tôma's at 46% left and the Keepers' at
37-52%; kite beats the bow and katana Keepers, the wand one once in two (a loss at 2%), Tôma once
in two.

He stays a fight a little harder than Tôma alone for an average player, as one fight in place of
Tôma's and the Maw's should be; the wand is the hardest of them (its Arcane Bolt, a hero's 2.2x
nuke at 60%). Open: the bow Keeper's kite fights run 95-115 s, over the 100 s target (he backs
off at 100 and the melee bot chases: `ranged_keep_distance` 170 is the knob); the heal-share flags
of these fights are the expected build's Leech rune against the little damage a kite takes (Tôma's
too), not a Keeper's doing. Fixed on the way: `BalanceLab.renew` read `run.seed` (renamed
`run_seed`): a script error on every renewed measure (marginal, compound, packs), whose floor then
kept the last seed instead of its own.

## 2026-10-24 - Core audit: numbers moved to data (refactor, no change)

**Changed (no number):** the core combat numbers left the code for data with the same values:
`data/combat/combat_rules.tres` (`CombatRulesDef`: crit x1.75, variance ±15%, armor weight 1,
cooldown cap 50%, a delayed blast's push 260), the hero's feel on `PlayerDef` (i-frames 0.6 s, 1 s
after a fall, swap cooldown 1.5 s, aim range 520, melee assist 70, attack buffer 0.3 s), the
bosses' shockwave on `BossDef` (cooldown 3 s, 4 + 0.6 per floor, fuses 0.35 / 0.45), chase and
wander on `MonsterDef` (sight x1.6, gives up after 4 s, wanders at 35%), ambushes, overflow
potions, gold piles and ranked bosses' loot on `DungeonConfig`. Every floor number goes through
`FloorRules` (the run's boons included) and one twist roller; `tests/suites/core_tests.gd`
compares the new answers with the old formulas over every depth, difficulty, event and curse.
Two fixes that only show in the numbers told: an encounter's odds and gold now count the run's
boons (the roll always did), and delayed effects are credited to their source in the statistics
and these tools' heal breakdowns. One that changes the draws, not the odds: crits and variance
roll on the floor's own dice (`World.combat_rng`, from the floor's seed) instead of the engine's
global ones.

**Measured** (`--mode=all --quick --no-cache`, seeds 1 and 2, before and after): the model and
economy reports are **identical** (every static number the same). The engine measures moved by
the new dice only, within the seed noise (seed 1 against seed 2 before differs as much): act I
gauntlet a win both times (lowest Health 38% / 58% before, 65% / 65% after; 53.0 / 50.7 s before,
54.6 / 58.1 s after); King Slime fights the same verdicts (baseline and face-tank losses, kite
wins). One flag crossed its line on seed 1 only: the lifesteal build's heal share against King
Slime (kite) 54% (target <= 50%; seed 2: 41%, before 18-24%), healing 25 of 46 taken: less taken
in that fight, the same Leech healing; noise of one fight, to watch on the next full run.

## 2026-10-24 - The Nameless Keeper (new last fight, measured against Tôma)

**What changed:** after "take his place", the next runs' bottom of the Well is the Nameless
Keeper alone (docs/design/monsters.md, "The Nameless Keeper"), built from the hero's snapshot.
Numbers (`data/monsters/bosses/nameless_keeper.tres`): 2200 base Health (x0.8-1.3 by the hero's
level, 2% a level from 15), Armor 5, speed 100; his blow 16 before the floor (weapon damage +
attack, +1 per rarity step), Tôma's; his skills at 60% power (`skill_power` -0.4: a hero's skills
are nukes sized for a hero), cooldowns x1.6, warned 0.5-0.8 s; relics 1 level at most (Thorns
at 2 cost a hammer hero 55 small hits); the same phases as Tôma's (x0.85, x0.75, +2/+3 attack).
At floor 12 on Keeper: **10237 Health**, against Tôma's 6019 and Tôma + the Maw's 12038 (the
Maw only hurt a third of the time): one fight in place of two, a little shorter.

**Measured** (`_tool/keeper_probe.gd`: the arena's bots and FightLog, Act IV's expected build,
Keeper, seeds 1-2, the run resumed at the bottom with the snapshot; snapshots of a level 15 hero,
Rare weapon with Brutal/of the Fox, Magic helm and mail, his weapon's skills and a tome's):

| Fight | kite | face_tank |
|---|---|---|
| Tôma alone (for scale) | win 59 / 53 s, 11-12 hits, 298-371 taken | loss at 53-55% left, 20 s |
| Keeper, katana + Fire tome, Ignite | win 87 / 93 s, 3-4 hits, 71-124 taken | loss at 74-77%, 14-15 s |
| Keeper, War Hammer + War tome, Bloodrage, Thorns | win 90 / 96 s, 57-58 hits (Thorns, burns), 286-298 taken | loss at 79-80%, 13-15 s |
| Keeper, Magic Wand + Thunder tome | timeout at 61% / loss at 47% (233 s) | loss at 69-75%, 16-18 s |
| Keeper, bow + Frost tome, Hydra's Quiver | timeout, nothing dealt either way | loss at 71-72%, 20 s |

Before the skill and relic caps (skill power x1, relics 2 levels): the wand's casts hit for ~58 a
time (9 hits, 524 taken), the hammer's lost at 2-10% left.

**Reading:** standing and hitting loses against every snapshot (pillar 1); a kiting melee build
beats a melee Keeper in ~1.5x Tôma's time, losing a third of its Health or less. A ranged Keeper
(bow, wand) keeps 170 away and shoots: the kite bot, a Greatsword build, holds out of his shots
and never closes in (a standoff, not a fight): **not measured for a ranged Keeper**, open card.

## 2026-10-23 - Melee blows in four directions: zones swept to the aim (measured, no shift)

**Changed (a rule, no number):** melee blows are drawn in the body's four directions
(design/builds.md, "Blows in four directions"), and their zone is the blow's shape swept from
that cardinal to the exact aim, so nothing hit before is missed. It can only widen a zone: an arc
by the angle between the cardinal and the aim (0 to 45 degrees, about 22 on average: a katana's
120 covers 120-165, the rapier's 30 covers 30-75), a circle ahead by the slide between the two.
It only matters with several enemies in front at once; the enemy aimed at was always hit.

**Measured** (pack, Keeper, every act's builds and both bots, seed 1, the old rule restored by a
temporary switch for the "before"): clear time new/old median 1.000, mean 1.03 over 40 room sets;
monster kinds and ranked rooms 1.000. Damage taken +0.15 points. The only moves past 15% were
kite-bot rooms where one of three rooms timed out or the bot wandered (act III expected and
inferno builds); seeds 2 and 3 of those: face-tank within 1%, kite 8.36 -> 8.06 s and
29.0 -> 34.2 s (one kite room timing out; the old rule's runs time out in kite rooms too, the
lifesteal build at seed 1): bot noise, not the rule. No balance pass needed; no data number
changed.

## 2026-10-23 - Gorr hard but readable, readable dives on every boss, echoes capped, the bots and the holes (measured)

Keeper's level stays as the owner likes it ("sporty, much better"): no boss Health, damage,
cooldown or difficulty number moved. What changed are warnings that lied, bands wider than the
body, a stack that skipped the cooldown cap, a climb-out bug, and the bots' reading of the fights.

**How (new in the tools):** `--hits` (arena) prints every hit the hero takes (what it was, the
skill and how long after its cast, its push, the distance to the boss, a hole within 48 px) and
every fall with what started it (a push, a roll, walking); each fight now counts its falls
(`falls_pushed` thrown in by a blow, `falls_walked` walked in). All numbers below: arena, Keeper,
each act's expected build, plain bosses, the same seeds before and after.

### Gorr the One-Eyed (act II): the bots, then one lying warning

**Measured (seeds 1-8, the bots as the last pass left them):** kite 1 of 8 (losses at 2-19%),
player 0 of 8 (1-31%), face-tank 0 of 8 (31-42%). The hit log showed three things:

- **The "falls from his quake" were the bot walking into holes.** Of the 7 falls in those 16
  kite and player fights, 5 started with the hero walking at full speed (170) into a hole no blow
  had pushed him toward (the bot probed the ground 56 px ahead in one step: a one-cell hole lies
  between), 1 was the Iaido Dash carrying him over the boss into one, 1 a club blow.
- **The bot could not read a fan.** Gorr's eye beam (a fan of 5, fierce 2 x 7) was 31% of all
  the kite bot took (his last phase's fierce fan): the bot only sidestepped shots in flight, and the shots on
  either side of it pushed it both ways at once.
- **The fierce Quake's second ring hit outside its warning.** The warning drew 130 px; 0.5 s
  after the first ring, a second one reached 169 px with nothing drawn: a hero who left the
  circle as shown, standing still, was hit (18 hits in 8 kite fights, 10 of them while Gorr was
  already warning his next eye beam: the dodge out of the circle led into the fan).

**Changed:** the fierce Quake's warning draws its whole reach (`telegraph_radius` 130 -> 169,
`data/skills/boss/quake_fierce.tres`): leaving the circle shown is safe from both rings. The
rule is now a unit check on every boss: a circle's later blows land inside the circle it drew.
The bots (tools): they never walk into a hole, cracked floor or a warned cell they can see (probes
every 6 px, 30 px ahead) and step off one under their feet; a skill that carries them (Iaido Dash)
is used only when it lands on solid ground; a roll may cross a hole (it does in the game) but
must land on solid ground; they step out of a fan's cone while it is warned, and keep out of a
cast's later blows (a second ring, volley or leg) until they have landed.

**Tried and not kept (no measurable effect on the player bot):** Health 1150 -> 1050 (player 0
of 8, boss 1-21% left; kite fights no shorter), the fierce beam's warning 0.32 -> 0.45 s (0 of 8),
the beam only from 140 px instead of 100 (0 of 8).

**After (seeds 1-8):**

| | Kite | Player (0.3 s reaction) | Face-tank |
|---|---|---|---|
| Gorr, before (old bot) | 1 of 8 (2-19% left) | 0 of 8 (1-31%) | 0 of 8 (31-42%) |
| Gorr, new bot, data before | 8 of 8 (94-142 s) | 0 of 8 (5-31%) | 0 of 8 (31-45%) |
| Gorr, after | **8 of 8** (94-142 s) | **0 of 8** (5-31%) | **0 of 8** (31-45%) |
| The Mother of Tears (unchanged, new bot) | 8 of 8 (70-103 s) | 4 of 8 | 0 of 8 |
| The Azure Wyrm (unchanged, new bot) | 8 of 8 (86-131 s) | 1 of 8 (1-21%) | 0 of 8 |

The Quake fix changes nothing for the bots (they already read 169 px from the skill's data): it
is for a person, who reads the circle. Verdict: Gorr is hard, not unfair. What still makes him
the act's hardest for the player bot is his first phase: it loses 44 Health there (the Mother 12,
the Azure Wyrm 17), mostly to the plain eye beam (0.6 s warning) as it walks back into reach
after a club blow or a Quake threw it out; a person sees the lanes drawn and steps aside. His
fights are also the act's longest for the kite bot (94-142 s, the target is 40-100 s): his
Quake (every 3.6 s in his last phase) keeps a melee hero out of reach. Both open (roadmap): to
play-test before touching numbers.

### Readable dives on every boss (the Jade Wyrm and the others)

The Azure Wyrm's rule, checked on her alone, is now checked on every boss's dives from the data
(`UnitTests._test_boss_warnings`; numbers in `data/balance/targets.tres`: `dive_warning_min`
0.45 s in the boss' last phase on Keeper, `dive_band_margin` 8 px over the body each side; a
dive never slows). It found:

| Dive | Before | After |
|---|---|---|
| Jade Wyrm, Coil Rush (both) | band 44 px each side (her body: 24) | 30 px |
| Jade Wyrm, fierce Coil Rush | 0.30 s warning in phase 3 | 0.45 s (cast 0.5 -> 0.76) |
| Mire Matron (`giant_frog`, act I), fierce Frog Leap | 0.37 s | 0.45 s (cast 0.63 -> 0.76) |
| Gilded Hoarder (act IV), fierce Crushing Leap | 0.37 s | 0.45 s (cast 0.63 -> 0.76) |
| Master Tôma, fierce Keeper's Step (bottom) | 0.32 s | 0.45 s (cast 0.5 -> 0.71) |

And the circles' rule found the Ember Ronin's (`red_samurai`, act III) fierce Flame Arc: its second blow reached 117 px
around a drawn arc of 90. Now both blows are 90 (a second burst in the same arc: it catches a
hero who rolled through the first or stepped back in).

| (new bot) | Kite before -> after | Player | Face-tank |
|---|---|---|---|
| Jade Wyrm, seeds 1-8 | 6 -> **7 of 8** | 4 -> 3 of 8 | 0 -> 0 of 8 (6-32% left) |
| Mire Matron, seeds 1-8 | 3 -> 4 of 8 | 0 -> 0 of 8 | 0 -> 0 of 4 |
| Gilded Hoarder, seeds 1-4 | 4 -> 4 of 4 | 4 -> 4 of 4 | 0 -> 0 of 4 |
| Ember Ronin, seeds 1-4 | 1 -> 1 of 4 | 0 -> 0 of 4 | 0 -> 0 of 4 |

Within the seeds' noise: readable, not easier. Not measured: Master Tôma (the arena doesn't run
the bottom of the Well). Found on the way (open): the Mire Matron (act I) and the Ember Ronin
(act III) beat the kite bot on Keeper on most seeds.

### degenerate_skills_a3 face-tanking the Jade Wyrm: the build, not Devotion

It won standing still on 1-2 seeds of 4. Devotion healed 18-46 a fight (9-28% of the damage
taken, under the 50% for a degenerate build): not what won. Its damage did: the face-tank dealt
258-394 a second against the expected build's 134-159, and killed her in 13-17 s. The model put
it at 2.84x the expected build (target 2.5x), and taking each piece out showed the echoes as
the biggest (without them 1.85x; without the Sage's Codex 2.05x; without Arcane Power 2.22x):
the Echo perk (45%), three Echo runes and of Echoes (12% each) echoed **69%** of its casts, a
second cast for free on top of a cooldown already at the 50% cap.

**Changed (a rule, pillar 3):** every echo source counts together and stops at **45%**
(`DungeonConfig.skill_echo_max_chance`, `SkillEchoPassive.total_chance`): the Echo perk at its
third level reaches it alone, more sources only make it surer to get there. The texts say so
("all echoes together: 45% at most"). The model counts the cap.

| | Before | After |
|---|---|---|
| Model: degenerate_skills_a3 / expected_a3 | 2.84x | **2.52x** (target 2.5x: still flagged, by a hair) |
| Face-tank vs the Jade Wyrm (seeds 1-4) | 1 of 4 won (2 of 4 with the bot before) | **0 of 4** (boss 18-33% left) |
| Face-tank vs the Crimson Tengu / the Ember Ronin | 0 / 0 of 4 | 0 / 0 of 4 |
| Kite / player vs the act III bosses | 12 / 11 of 12 | 12 / 12 of 12 (19-54 s) |

Devotion is left as it is.

### The bots and the holes

**Measured:** the falls the card blamed on blows were mostly the bots' own steps (Gorr above).
With the bots taught (never walk into a hole they can see, roll over one only to land on solid
ground, dash only to land on it), the after set (180 fights, three acts) had 5 falls thrown by a
blow and 6 walked (the ground giving way under a bot standing still, a dash sliding along a
boss). One fight showed a game bug: the hero climbed out of a hole under the boss' body (where he
last stood) and its body pushed him back in: four falls in 1.5 s. **Fixed (game):** he climbs
out on the nearest free floor clear of a body (`Player._on_fell`,
`World.nearest_free_point(..., clear_of)`); a floor test holds it.

**Verdict on knockback near holes (for players): fair.** The blows that push are warned (a
swing, a circle), they push away from the boss (predictable), the holes are drawn, a roll crosses
them, and a fall in a boss arena costs 15% of max Health (13% after armor) and puts the hero back
on solid ground with a second of grace (no Deeps from a boss floor): about one hit. Thrown falls
were 1 in 36 fights for the bots. No design change proposed.

**Guards:** unit `_test_boss_warnings` (every boss: dives warn >= 0.45 s on Keeper in every
phase, bands <= body + 8 px, no slow; a circle's later blows inside it), the echo cap (combat
tests: the perk and three runes echo 45%, not 62%), the climb-out (floor tests). Balance suite:
the Azure Wyrm (kite >= 2 of 4), Gorr and the Jade Wyrm (kite >= 3 of 4) on Keeper, their
face-tank loses, no bot walks into a hole in those fights; degenerate_skills_a3 face-tanking the
Jade Wyrm loses on four seeds.

**Tests (after merging main):** unit,title 13947 checks, game 1983, tutorial 397: 0 failed. Balance suite 102 checks,
10 failed: the 8 known, "model: degenerate DPS" (degenerate_skills_a3, 2.84x -> 2.52x) and
"content: unlisted" (Tôma, the Maw, the Nameless Effigy), both failing before this pass; every
new guard passes (the Azure Wyrm 4/4, Gorr 4/4, the Jade Wyrm 4/4 kite wins; no walked fall).

**Open:**
- Gorr: 0 of 8 for the player bot (the act's hardest first phase, the longest fights); hard,
  readable: to play-test before any number moves.
- The Mire Matron (act I) kite 4 of 8, player 0 of 8; the Ember Ronin (act III) kite 1 of 4,
  player 0 of 4: both off "the kite bot wins on Keeper".
- A warning disappears when its cast lets go: the fierce Quake's second ring, a second volley
  or leg come with nothing drawn (now always inside what was drawn). Keeping the drawing until
  the last blow is a visual change (VFX).
- Fans warned 0.30-0.32 s in a last phase (Gorr's eye beam, the wyrms' breath and spit, the
  Mire Matron's Poison Spit): under a person's reaction at close range. A rule like the dives' is a
  proposal, not applied.
- Model: degenerate_skills_a3 still 2.52x (target 2.5x).

## 2026-10-23 - The Azure Wyrm hard but fair; Pilgrim's souls; a second life in the face-tank test (measured)

Keeper's level stays as the last pass left it (the owner: "sporty, much better"): no curve,
monster or difficulty number moved except Pilgrim's souls.

### The Azure Wyrm (act II): she beat the kite bot on Keeper on every seed

**Measured (arena, expected_a2, Keeper, seeds 1-8):** kite 0 of 4 (old bot), player 0, face-tank
0 (boss left at 5-32%). Her siblings: the Mother of Tears kite 7 of 8, player 4 of 8; Gorr kite 1
of 8, player 0 of 8 (see Open). The model hid it: her threat 206% (Gorr 164%, the Mother 221%),
her last phase's damage per second 30.5 (14.2, 23.8), the act's highest but not a wall. A probe
logging every hit (amount, knockback, her state, the hero's slow) found why:

- **A slow-lock.** Her fang, Frost Breath, Glacial Dive and Hailstorm all slowed 40% for 2 s:
  the hero was slowed for most of her last phase (9 of 13 hits taken while slowed in one fight),
  running 102 against her 115-135: he could neither leave her reach nor clear her dives.
- **Her dives killed.** In her last phase 4-6 dive hits of 16-40 (12-20% of max Health each)
  made 100-130 of the ~210 the kite bot took. On Keeper the fierce dive warned 0.30 s (0.5 s x her
  phases' 0.85 x 0.7), its two legs 0.55 s apart, the second with no warning of its own (a hero
  slowed by the first could not leave the line), and its hit band was 44 px each side of its line
  (`DashStrikeEffect.width` is a half-width): 88 px plus the hero, almost twice her body (radius 24).
- **Her coils.** Her body burns at a touch (WyrmBody); the bots never stepped off it: 20-117 of the
  damage in a lost fight came from the coils, counted as "shockwave" by the tools.

**Changed (data; her identity kept: a fast flying frost dragon whose breath slows, who dives and
bursts ice, whose body burns):**

| | Before | After |
|---|---|---|
| What slows | fang, breath, dive, hail: 40% for 2 s | fang and breath only, 40% for 1 s |
| Glacial Dive warning (cast) | 0.6 s (phase 3 on Keeper: fierce 0.30 s) | 0.75 s (fierce 0.8 s: 0.48 s) |
| Glacial Dive band | 44 px each side | 30 px each side (her body) |
| Fierce dive: second leg / cooldown | 0.55 s after / 4 s | 0.7 s after / 5 s |
| Fierce breath cooldown | 3 s | 3.5 s (as the plain one) |
| Her claw's wind-up | 0.5 s | 0.6 s (the act's others 0.65) |

Glacial Dive's text now says what it does ("Dives along a line and throws back what it touches";
it no longer chills). The tools: the kite bot steps off a wyrm's coils as off a live trap (a
player sees them), and the arena counts the coils as "body" (and blasts as "blasts"), no longer
as "shockwave".

**After (same seeds; Keeper, expected_a2):**

| | Kite | Player (0.3 s reaction) | Face-tank |
|---|---|---|---|
| Before, old bot (seeds 1-4) | 0 of 4 | 0 of 4 | 0 of 4 (boss 5-32% left) |
| Before, coil-aware bot (seeds 1-8) | 1 of 8 (losses at 4-23%) | 0 of 8 | 0 of 8 (5-33%) |
| After (seeds 1-8) | **6 of 8** (two lost to pits: falls 81, 108) | **2 of 8** | **0 of 8** (8-40% left) |
| The Mother of Tears / Gorr (unchanged) | 7 / 1 of 8 | 4 / 0 of 8 | 0 / 0 of 8 |

Pilgrim (seeds 1-4): every bot wins, as before (the face-tank may win there). Martyr: every bot
loses, as before and as her siblings. Degenerate builds (crit, lifesteal) face-tanking her lose on
Keeper and Martyr; kiting, they win on Keeper. Model: threat 206% -> 200%, last phase 30.5 ->
28.3 damage a second (the model counts both dive legs now; it can't see warnings, bands or slows,
which were the problem). The Jade Wyrm (act III, unchanged) is the same kind of dragon: with the
coil-aware bot her kite record goes from 1 to 3 of 4.

**Guards:** unit `_test_boss_slows`: no boss slows the hero from more than two things in a phase,
none for more than 2 s; the Azure Wyrm's dives warn >= 0.45 s in her last phase on Keeper, hit a
band her body could cross (<= radius + 8) and don't slow. Balance suite: the Azure Wyrm on Keeper
over four seeds, the kite bot wins at least 2 (it won 2: one fight lost to a pit), the face-tank
loses every time.

### A second life in the face-tank test

The bots now play the Threshold's trial of a second life (Phoenix Feather, Second Chance), so a
face-tank build with one died, came back and sometimes finished the boss: 3 "arena: face-tank
wins" errors, and the revive's heal counted in "arena: heal share".

**Decided:** a face-tank fight won only after dying once counts as a **loss**
(`targets.facetank_second_life_is_loss`), and a second life's heal is left out of the heal share
targets (still listed as "other (revive)"). Why: pillar 1 asks that the boss' patterns kill a hero
who never dodges, and they did; the second life is a once-a-run safety net the player paid for
(a relic, a shrine level) and pays again with the trial, so spending it on a boss is a real loss
for the run; tuning bosses to kill a face-tank twice would tune every boss around the rarest
relic, against everyone else. A face-tank that wins without dying is still an error. The arena
also records the second lives spent (`lives_used`, printed with each fight) and no longer counts
what the hero takes and heals inside the Threshold as part of the boss fight (the Deeps after a
fall still count: the fight threw him there).

**Before / after (arena, every boss and its act's builds, Keeper and Martyr, seed 1):**
"arena: face-tank wins" 3 -> 1 (degenerate_max_health_a4 vs the Gilded Hoarder and
degenerate_thorns_a4 vs the Dead Sun: both spent two lives; left: degenerate_skills_a3 vs the
Jade Wyrm, won at 23% without dying, Devotion's heals: a real break, open). "arena: heal share"
16 -> 7 (degenerate_max_health_a4 vs the Hoarder 69% -> 28%: most of its "healing" was its Leech
working on the Threshold's spectres). Left: degenerate_skills_a3 (68-100%, its skills' heals),
degenerate_thorns_a4 and degenerate_max_health_a4 vs the Dead Sun (53-56%), expected_a4's Leech
on Keeper (32-35% vs 25%): sustain findings, open.

### Pilgrim's souls

**Measured (economy mode, Pilgrim and Keeper, seed 1; new: a Pilgrim career in BalanceSouls,
table "economy_campaign_easy", and "economy_pilgrim"):** a Pilgrim run paid 0.44-0.47x a Keeper
run that ends the same way (x0.5, and its floors are smaller: 15 rooms, not 19): 6 souls for a
death at act I's boss (Keeper 13), 79 for a win (166). A career kept to Pilgrim (no achievements:
feats don't count there; its runs reach the end sooner, PILGRIM_CAREER: then 3 wins in 4) filled
the tree in 77 runs (Keeper: 47), 1.64x.

**Changed:** Pilgrim's souls x0.5 -> **x0.65** (`data/difficulties/easy.tres`).

| | Keeper | Pilgrim before | Pilgrim after |
|---|---|---|---|
| A run that dies at act I / II / III / IV's boss | 13 / 45 / 83 / 116 | 6 / 20 / 39 / 54 | **8 / 27 / 49 / 69** |
| A win | 166 | 79 | **101** |
| Same run, Pilgrim / Keeper | - | 0.44-0.47x | **0.59-0.62x** |
| Runs to a full tree (a career on it) | 47 (~29 h) | 77 | **64 (~43 h), 1.36x Keeper** |
| First node | run 1 | run 1 | run 1 |

Pilgrim still progresses more slowly than Keeper, per run and per hour, never faster for less
risk. **Targets (new):** a Pilgrim career fills the tree in 1.25-2x Keeper's runs, its first node
by run 3, and a Pilgrim run never pays more than a Keeper run with the same end. Unit guard:
Pilgrim's souls x0.6-0.75, below Keeper's. The card shows "Souls earned x0.65" (from the data);
docs/design/progression.md updated.

**Tests (after merging main):** unit,title 13869 checks, game 1953, tutorial 397: 0 failed; balance suite 85 checks, 10 failed: the
known ones plus "model: degenerate DPS" (degenerate_skills_a3 2.84x) and "content: unlisted"
(Tôma, the Maw, the Nameless Effigy), both failing before this pass.

**Open:**
- *Gorr the One-Eyed* (act II's main boss) is now the act's hardest on Keeper: kite 1 of 8, player
  0 of 8, the kite bot often thrown into pits by his quake (falls 54-162). The gauntlet's act II
  (which meets him) was won by both bots in the last pass; to measure on several seeds.
- *The Jade Wyrm* shares the Azure Wyrm's old dive (Coil Rush: 0.30 s warning in her last phase,
  44 px band, 0.55 s second leg); with the coil-aware bot she is kite 3 of 4 on Keeper. Same
  fixes to consider in an act III pass.
- *degenerate_skills_a3* wins face-tanking the Jade Wyrm without dying (Devotion's heals).
- The balance bots lose fights to pits (knocked back by blows): a person avoids edges better.

## 2026-10-22 - Keeper's curve: acts II and III carry their own threat (measured; and faster tools)

**Why (the owner, on Keeper):** first "I still feel I roll over everything", then, playing the
current main: "the fights are sporty now, much better" and "it gets tough after floor 8 or 9;
before that you roll, even with a level-1 weapon". So not a harder Keeper: the same level from
floor 9 on, floors 1-2 a gentle start, and floors 3-8 no longer a stroll.

**Measured on the current data first (seed 1).**

- *The model's commons' curve* (table "monster_ladder", Keeper, each act's last normal floor vs
  its expected build): a common cost the hero 1.2% / 1.7% / 1.8% / 2.5% of his Health from act I
  to IV, so act III was x1.07 over act II: the flat stretch the owner felt (floors 4-8). Elites
  4.7 / 8.3 / 12.0 / 16.9%.
- *The floors' curve* (new model table "floor_curve": a room of each normal floor, face to face,
  for the hero an average player has there, `BalanceBuild.hero_at`; Keeper): floor 1 14%, 2 3% |
  4 17%, 5 11% | 7 43%, 8 24% | 10 48%, 11 42%. With the starting weapon (Common, item level 1):
  4% | 23%, 18% | 71%, 38% | 75%, 54%. A saw (each act's first floor meets the hero who just left
  the last act), rising steeply only from act III.
- *The bosses' curve* (threat for the expected build, Keeper): 178% / 197% / 227% / 219%,
  Pilgrim x0.37-0.47, Martyr x1.76-1.88: inside its targets, left alone.
- *The engine* (new `--mode=gauntlet`: each act's last floor, 8 rooms with ranks rolled at the
  floor's chances, Health and potions carried, then its boss; bots `kite` and `player`, the kite
  bot answering threats 0.3 s late): every Keeper act won by both bots; the rooms' damage is
  healed back by the builds' lifesteal from act II on (a floor of 6 rooms: 80-650% of max Health
  taken, nearly all healed), and the hero reaches each boss with 3-5 potions after starting with
  2 (they drop on the way). Pilgrim: every act won. Martyr: the player bot loses three acts' bosses
  of four. Boss fights (expected builds, acts II-III, kite): Keeper 3 of 6 won (Demon Cyclops,
  Azure Wyrm, Jade Wyrm lost), Martyr 1 of 6, Pilgrim 6 of 6.

**What changed (data, and the rule to carry it):** an act can add its own threat to its
monsters, on every difficulty (`ActDef.monster_hp`, `monster_damage`, read by `FloorRules` for
monsters and what bosses call, not for bosses themselves, traps or the cold):

| Act | Monsters' Health | Monsters' damage |
|---|---|---|
| I (floors 1-3) | x1 | x1 |
| II (4-6) | x1.08 | x1.08 |
| III (7-9) | x1.1 | x1.1 |
| IV (10-12) | x1 | x1 |

Tried first: act II x1.15-x1.2 alone (the floors' curve then rises smoothly, but act III's
commons fall below act II's: x0.67, a dip), act III x1.15 with act II x1.1 (act IV only x1.04
over act III: flat at the top). The kept values are the smallest that make every step rise.

**Before / after (model, Keeper):**

| | Act I | Act II | Act III | Act IV |
|---|---|---|---|---|
| A common, Health lost killing it | 1.2% | 1.7% -> **2.1%** | 1.8% -> **2.3%** | 2.5% |
| Step over the act before | - | x1.42 -> **x1.77** | x1.07 -> **x1.07** | x1.35 -> **x1.09** |
| An Elite | 4.7% | 8.3% -> **9.7%** | 12.0% -> **14.4%** | 16.9% |
| A Legendary | - | 29% -> **35%** | 38% -> **47%** | 55% |
| A room, the hero there (floors) | 14%, 3% | 17%, 11% -> **20%, 13%** | 43%, 24% -> **53%, 29%** | 48%, 42% |
| A room, starting weapon | 4% | 23%, 18% -> **27%, 22%** | 71%, 38% -> **87%, 46%** | 75%, 54% |
| Pilgrim, a room | 5%, 1% | 6%, 3% -> **7%, 3%** | 11%, 6% -> **13%, 7%** | 11%, 9% |
| Martyr, a room | 40%, 8% | 49%, 33% -> **58%, 39%** | 120%, 70% -> **145%, 86%** | 138%, 122% |

Floors 1-2 and act IV are as they were; act III's floors now come up to act IV's, and act II's
sit between act I and act III. Bosses untouched (the boss curve is the same); the adds bosses
call in acts II and III hit a little harder.

**Engine, after (same seeds):** Keeper gauntlet: every act still won by both bots (act II's
lowest Health 30% -> 27% kite, 31% -> 25% player). Boss fights, acts II-III, expected builds,
kite: Keeper 3 -> 4 of 6 won, Martyr 1 -> 0 of 6, Pilgrim 6 -> 5 of 6: the one loss is the Demon
Cyclops' shockwave throwing the bot into a pit and the Deeps (seed 1); seeds 2-4: Pilgrim 9 of 9
act II fights won, Keeper 6 of 9 (Azure Wyrm lost on every seed, before as after). The engine's
per-floor curve (gauntlet `--gauntlet=curve`) is single-seed and dominated by lifesteal: it moves
within its noise.

**Targets (data/balance/targets.tres):** the commons' curve steps x1.05-x1.6 (was x0.9-x1.6: a
step of x0.9 allowed exactly the flat stretch the owner felt), act II over act I up to x2.5 (act I
is gentle on purpose; its commons meet a hero levelling 1 to 6); act I's floors at most 25% of max
Health (model: a room for a fresh hero; engine: a floor for the kite bot); new gauntlet targets
(Pilgrim's average player wins every act; on Keeper he wins 3 acts in 4 and spends 20-60% of his
Health and potions on a floor before its boss). **Guards:** unit checks (acts I and IV at x1, II
and III above, every act x1.5 at most; FloorRules leaves bosses out); balance suite: "model:
floor curve", "model: monster curve" with the new steps, act I's gauntlet (Pilgrim player bot and
Keeper kite bot win; floors 1-2 gentle). Regular suites (after merging main): unit,title 11134 checks, game
1708, tutorial 397: 0 failed. Balance suite: 79 checks, the known failures plus two unrelated ones
already failing before ("model: degenerate DPS" degenerate_skills_a3 2.84x, "content: unlisted":
nameless_effigy, master_toma, the Maw in no act). The bottom of the Well (Tôma, the Maw) is at
floor 12, act IV: its fight and its Damned keep x1, its 1.3-1.5x guard unchanged.

**Open:**
- *Lifesteal makes rooms free.* From act II on the expected builds heal back everything a room
  deals (`SustainRules`: 4% of max Health a second outside boss fights, 20% at once), and potions
  pile up for the bosses (the cap is 4 of a kind). The owner likes the current level, so it stays;
  if Keeper's floors still feel soft, the room rate (`rate_per_second`) is the knob, with the
  "one source alone cut <= 10%" target to revisit.
- *Azure Wyrm* beats the kite bot on Keeper on every seed: off the "kite wins on Keeper" target
  before and after; a candidate for its own pass.
- *The bots are not the owner*: they lose bosses he finds easy. The curve's shape is what was
  matched; absolute costs are for a slower player.

**The tools, faster.** Every engine measure is a unit of work: processes take the next unit no
other has claimed, results are kept in a cache keyed by the code and the data each unit reads, and
the game runs as a simulation (no effects, light, HUD or bodies' looks; floors without their own
monsters, rebuilt in place for a fresh measure). Wall time on this machine (2 CPUs), seed 1:

| Command | Before | After |
|---|---|---|
| `--mode=all --quick --jobs=2` | 183 s | 113 s (with the gauntlet and the curve, which did not exist) |
| `--mode=all --jobs=2` (six difficulties), first run | 6093 s (1 h 41 min) | 2729 s (45 min), with the gauntlet and its curve (+250 units the old tools had not) |
| the same again, nothing changed | 6093 s | 29 s (everything from the cache) |
| arena, acts II-III, expected builds, 3 difficulties (36 fights) | - | 40-55 s |

Same verdicts within the seed noise: 408 boss fights, 91% the same result (face-tank 96%, kite
86%), hero DPS -0.7% on average (sd 10%). `--classic` gives the old numbers back exactly (marginal
act II identical). The marginal values move by the seed noise (act I's base measure drew a +16%
luckier stream in one run: its "too weak" flags 24 -> 47): read them across runs, as before.
Found and fixed on the way: a fall into the Deeps or a second life's Threshold took the World out
of the tree mid-fight and the bots kept steering it (about 59,000 script errors in a full run,
old tools included); they now follow the hero there and make for the Dawn Breach.
Consequence in the final run: a build with a second life (Phoenix Feather, Death Denied) now
plays its Threshold trial and comes back, so three face-tank fights read as wins ("arena:
face-tank wins": degenerate_max_health_a4 vs Gilded Hoarder and degenerate_thorns_a4 vs the Dead
Sun at 0% Health and revived; degenerate_skills_a3 vs Jade Wyrm at 23%, Devotion's heals) and
the second life's heal counts in "arena: heal share" (14 -> 21 flags, the degenerate and the
expected act III-IV builds' Leech on Pilgrim and Keeper). The old tools lost those fights by
accident (the bot stood still in the Threshold). Open: whether the face-tank target should count
a second life as a loss.

## 2026-10-22 - The bottom of the Well: Tôma and the Maw (new fight, numbers set by rule)

**What changed:** after a first win, the run's last fight is the bottom of the Well
(docs/design/monsters.md, "The bottom of the Well"): Master Tôma, then the Maw, at Act IV's
depth (12), no relic between them.

**Numbers (set relative to Act IV's bosses, not measured in play):**
- Health: Tôma 1300 base, Armor 5; the Maw 1300, Armor 3. At floor 12 on Keeper (x2.65 for
  depth): 3445 + 3445 = 6890, against the Gilded Hoarder's 5101 (x1.35) and the Dead Sun's 4823
  (x1.43). `UnitTests._test_finale` keeps it within 1.3-1.5x of every Act IV boss.
- Time is longer than Health says: the Maw only takes damage while its jaw is open, 3.6 s out of
  about 11 (closed 6.5 + opening 0.75 + open 3.6 + closing 0.4: ~32%), ~37% from 60% (closed 5 s)
  and ~39% from 30% (closed 3.8 s, open 3.2 s). A hero who hits only in the windows needs about
  as long on the Maw as on two Act IV bosses; its closed time is spent dodging its lashes and
  killing the Damned it calls (they give XP and kills: summoned, so no gold, loot nor heal).
- Damage (power at floor 12, Keeper): Tôma 13 (katana) + 3 + 11 = 27 (+2, +3 by phase), the
  Gilded Hoarder's 24; his skills: Keeper's Step 6 + x1.0, Severing Arc 8 + x1.4 (1.25 s wind-up,
  96 radius), the lantern 6 + x1.2 (0.8 s cast + 1 s on the ground), fierce: two steps, three
  flames. The Maw: 9 + 4 + 11 = 24 (+2, +3); its bite x1.5 (36, 0.55 s warning, thrown back 460,
  every 1.3 s at most, only within 72 of its mouth while open); Tar Lash 6 + x1.1 per circle
  (3, fierce 5; 0.95 s each), False Dawn 6 + x1.0 per column (4 columns, 1.1 s), Dead Sun's Gaze
  7 rays of 6 + x0.6 (the eye beam's), 2-3 Damned at a time (4-5 at most).
- No shockwave for hitting the Maw (`shockwave_after_hits` 0): its bite punishes standing in its
  mouth instead, and only while it is open; the phase roars still throw the hero off. Tôma keeps
  the usual 8 / 7 / 5 hits.
- Its pull: 55 units a second while open, within 420 of its mouth (the hero runs 170): a ranged
  hero is drawn into bite range slowly, a melee hero has to step back out between bites.
- Rewards: Tôma 220 XP, no relic, no loot (his gold and rune drop as any boss'); the Maw 320 XP,
  3 relic choices (when the hero keeps going), 3 rolls of loot, 30 soul wisps; the win's souls as
  for any win.

**Not measured:** the balance tools were being reworked by another pass; no arena run was made.
Open questions: the fight's length and deaths for the balance bots (face-tank, kite) against
Act IV's bosses; whether 3.6 s windows are enough for slow weapons (War Hammer) once the bite's
warning pushes them out; the Damned's share of the damage taken in the last phase.

## 2026-10-22 - Charged attacks: hold the attack button (new mechanic, numbers set by rule)

**What changed:** holding the attack button no longer repeats the basic attack; past 0.22 s it
charges the weapon's charged attack (docs/design/builds.md, "Charged attacks"), unleashed on
release when full. Every hero's weapon has one (`data/skills/charged/`).

**Numbers (set by a rule, not measured in play):** one target's share of a charged attack is
2.2-3x a basic hit (skill power x multipliers vs the wielder's power x `projectile_damage` x
shots; `UnitTests._test_charged_attacks` holds the range): Katana 2.5, Ninjaku 2.5, Sai 2.6,
Rapier 2.6, Lance 2.6, Battle Axe 2.4 (all around), Greatsword 2.7, War Hammer 2.7, Pickaxe 2.5,
Whip 2.3, Templar Sword 2.5, Bow 2.56 (pierces all), Shuriken 2.85 (7 stars), Frost Staff 2.57
(+ a 50% slow nova), Spark Wand 2.47 (+ 3 jumps at 70%), Ember Tome 2.22 (+ burn, radius 64).
The price: 0.75-1.15 s of charge after the 0.22 s delay, moving at 45-60% speed meanwhile, no
basic attack while charging, a roll losing it. Per second it is below tapping: a katana taps
1/0.38 = 2.6 hits a second; a charged cut every 0.22 + 0.8 + ~0.1 s is 2.5 / 1.12 = 2.2 hits'
worth, before its wider area. It pays against packs (area, pierce) and to open a fight, not as
a rotation. Skill power raises it like a skill; "on skill" perks don't fire.

**The bots:** the test bot and the balance bot tap the attack button (a frame down, a frame up)
as fast as the weapon swings instead of holding it, so the measures keep to basic attacks, as
before (the attack buffer of 0.3 s keeps a tap pressed during the cooldown from being lost).
Open question: measure a "charger" bot (charges into packs) once the feel is confirmed on the
phone.

## 2026-10-22 - The Armory in 5 levels; the tree's reset earned by runs (measured, economy mode)

**Why (the owner):** "the starting weapons must be limited, you can have nearly everything": one
Armory node (250 souls) let a player start with any weapon the dungeon holds (15 of them, the
strongest included). And "the reset unlocks with runs, otherwise it's too easy": the free reset at
any time made every fork and path a free trial.

**What changed:**

| | Before | After |
|---|---|---|
| Armory | 1 level, 250 souls: any weapon the dungeon holds | 5 levels, 90 / 150 / 210 / 270 / 330 souls (`cost` 90, `cost_growth` 60; 1050 in all): 3 weapons, then +2 a level, 11 at the top |
| Armory weapons, in order (`armory_weapons`) | every weapon of the dungeon | Katana, Bow, Frost Staff / Sai, Spark Wand / Lance, Battle Axe / Whip, Shuriken / Greatsword, Templar Sword (locked until Paladin's Oath) |
| Not in the Armory | - | the oaths' weapons (War Hammer, Rapier, Ember Tome: with their oath), Ninjaku and Pickaxe (floors only) |
| Reset the tree | free, any time | free (every level refunded), once every 3 finished runs (`SoulTreeDef.reset_runs`); saves from before start with one earned |

Level 1 (90) costs about two early runs' souls with the bestiary and quests (a Keeper career has
505 souls at run 3), cheaper than the old node (250) since it now opens less; the top level (330)
is about two late runs (~170 a run). Old saves that bought the Armory keep it as level 1 (the
same id, level 1); a starting weapon outside it falls back to the Katana.

**Before / after** (engine, seed 1, economy mode, table "economy_campaign", Keeper career):

| | Before | After |
|---|---|---|
| Full tree (dearer side of each fork) | 7965 souls, run 42 (~26 h) | 8765 souls, run 47 (~29 h) |
| Every node | 9725 souls, run 53 (~33 h) | 10525 souls, run 58 (~37 h) |
| One-time pools / full tree | 46% | 42% |

Still inside the 40-60 runs target. Unit checks hold the new Armory (levels in data order, +2 a
level, nothing locked offered, costs rising, first level <= 150) and the reset rule.

**Open:** giving up a run right away (pause menu) still counts as a finished run toward the reset;
three quick give-ups earn one. A minimum depth or time could close that if it matters. The order
of the weapons is a judgement (one per way to fight first, the heavy and rare last), not measured:
the weapon arena (balance `arena` mode) would say which starts are strongest.

## 2026-10-22 - The Deeps: a fall's new cost (measured, a probe)

**Why:** a fall into a floor's hole now takes the hero into the Deeps (dungeon.md) instead of
costing 15% of his max Health; the Deeps themselves must be the cost: a short fight in the dark,
not a free detour nor a farm. Pacing and demons are new (`data/abyss/abyss.tres`,
`data/monsters/abyss/`).

**How:** a probe (`_tool/abyss_balance.gd`, not committed: `_tool/` is ignored) on Keeper: each
act's expected build (`expected_aN`, `BalanceBuild.apply`) falls on the act's second floor, then
walks the way to the Dawn Breach and fights (a `BalanceBot`) whatever comes within 100 px; 4 runs
an act, two bots. "Taken" is all the damage taken down there after the 5% fall; "net" is Health
in minus Health out (kills and lifesteal heal: the expected builds of acts II-IV carry
lifesteal, so their net is about 0).

| Act | Kite: out (s) | taken | net | gift | Face tank: out (s) | taken | net | gift | deaths |
|---|---|---|---|---|---|---|---|---|---|
| I | 13.9 | 6% | 6% | 4/4 | 14.0 | 24% | 24% | 4/4 | 0/8 |
| II | 30.8 | 11% | -3% | 2/4 | 12.8 | 15% | -3% | 4/4 | 0/8 |
| III (Warden) | 31.0 | 15% | -1% | 3/4 | 24.2 | 51% | -2% | 4/4 | 0/8 |
| IV (Warden) | 34.8 | 14% | -2% | 3/4 | 15.7 | 28% | -2% | 4/4 | 0/8 |

**Passes before these numbers:** first, a 44 x 36 maze of 6 rooms with waves only around the hero
(behind him as he walks): out in 7-25 s, 0% taken, every gift: no cost at all. Then rooms holding
1-2 demons, waves of 3 every 7 s up to 7 alive, half of them ahead: 50-140 s, 30-120 kills (a
farm, Health going up). Kept between: 8 rooms in 56 x 44, the door in the room farthest on foot
(it was the farthest as the crow flies), 1-2 demons a room, waves of 2 (+1 every second wave,
+1 an act) every 8 s (-1 s an act), at most 6 of them up (+1 an act), half ahead; the gift for
30 s (+5 an act). A bot knows the way: a player following the arrow takes longer and gets fewer
gifts.

**Souls:** 8 new kinds in the bestiary: hunter ranks 2/4/8 and up to 15 souls of challenges
each, about 200 souls of one-time sources (2.5% of the tree), within the campaign's targets.

**Open:** the face-tank bot takes 51% in Act III (the Warden at the door and Horned Augurs'
volleys): watch real runs; a death in the Deeps of a low-Health hero is possible on purpose
(the fall can kill). Not measured on Martyr/Nightmare (the demons scale with the difficulty like
the floors' monsters).

## 2026-10-21 - Souls: the Tree of Souls becomes a campaign (measured, economy mode)

**Why (the owner: "we get a lot of souls"):** measured on a whole Keeper career for the first
time (new `BalanceSouls`, economy table "economy_campaign": every source, run after run, from the
measured floors), a player filled the whole tree (7965 souls: every node, the dearer side of each
fork; 9725 with both sides) in **11 runs, about 4 hours**. Two causes: the one-time pools (hunter
ranks 4770, bestiary challenges 5885, achievements 1660) were worth **155% of the tree** on their
own, most of it paid in the first hours (4922 souls, 62% of the tree, in the first 10 runs); and
a run paid a soul a kill (75% of its souls), 330 for a death at act III's boss, ~555 late on.
The old target (15-60 runs dying in act II-III, run souls only) passed because it counted none of
the one-time sources.

**Targets (new, data/balance/targets.tres; the old run-only ones are retired):** a full tree in
40-60 runs of a Keeper career, every source counted (20-35 hours: a campaign, not a few
evenings); the first node after run 2 at the latest; hunter ranks, challenges and achievements
pay at most 20% of the tree in the first 10 runs. The career (constants in `balance_souls.gd`,
each with its reason): runs 1-2 die at act I's boss, 3-6 at act II's, 7-14 at act III's, 15-24 at
act IV's, then half the runs win; 2 runs a day for the quests (80% of dailies, 70% of weeklies
done); challenges as a chance per kill of the kind; 3.5 minutes a floor for the hours (not
measured: Codex > Runs has real times). Unit checks (`_test_soul_economy`) hold the run formula,
the late-run pace (40-80 runs from run souls alone), the one-time pools (<= 60% of the tree) and
the first run buying a node.

**What changed (income only, no node cost moved):**

| Source | Before | After |
|---|---|---|
| Run: per kill / floor / boss / win (now `DungeonConfig` > Souls, was hard-coded in `Profile`) | 1 / 5 / 20 / 100 | 0.1 (added up, rounded once) / 4 / 10 / 40 |
| Hidden floor's bonus | 60 | 20 |
| Hunter ranks, monsters / bosses | 5/15/40 / 30/60/120 | 2/4/8 / 8/12/25 |
| Monster challenges: elite, hole, streak, untouched, crit | 15, 10, 10, 15, 5 | 3, 4, 3, 3, 2 |
| Boss challenges: ranged, melee, under 90 s, no potion, healthy, its weapon (Effigy's) | 40, 40, 60, 50, 80, 70 (80) | 8, 5, 12, 8, 15, 12 (15) |
| Achievements (Keeper-career ones; Martyr/Nightmare/ascension kept: 150, 250, 400) | 5-100, 1660 in all | 5-75 (-25 to -40%), 1355 in all |
| Daily / weekly quests | 12-45 / 100-200 | 5-18 / 30-70 |

Kills are now about a third of a run's souls (25 of about 80 at act III's boss on Keeper) and depth the
rest: going deeper pays, farming monsters (endless mode) doesn't (~10 souls an endless floor vs
~12 a floor of a normal run).

**Before / after** (engine, seed 1, economy mode; run souls by result):

| Run souls | Pilgrim | Keeper | Martyr | Nightmare |
|---|---|---|---|---|
| Dies at act I's boss | 27 -> 6 | 60 -> 13 | 178 -> 29 | 440 -> 62 |
| Dies at act II's boss | 78 -> 21 | 190 -> 45 | 442 -> 85 | 905 -> 154 |
| Dies at act III's boss | 138 -> 36 | 330 -> 77 | 702 -> 141 | 1310 -> 241 |
| Dies at act IV's boss | 194 -> 51 | 479 -> 110 | 957 -> 196 | 1693 -> 326 |
| Wins | 254 -> 76 | 600 -> 161 | 1150 -> 276 | 1995 -> 451 |

| Keeper career (every source) | Before | After |
|---|---|---|
| After run 1 (dies at act I's boss) | 352 (4% of the tree) | 102 (1%): buys 2-3 first levels |
| After run 5 | 3023 (38%) | 887 (11%) |
| After run 10 (~4 h) | 7673 (96%) | 2101 (26%) |
| One-time souls in the first 10 runs | 4922 (62%) | 1387 (17%) |
| After run 20 (~10 h) | 15649 (196%) | 4005 (50%) |
| Full tree (7965) | run 11, ~4 h | run 42, ~26 h |
| Every node (9725) | run 14, ~6 h | run 53, ~33 h |
| Quests, per run (2 runs a day) | 49 | 18 |
| One-time pools in all (ranks, challenges, achievements) | 12320 (155% of the tree) | 3654 (46%) |

A typical run still buys something: early runs (act II-III deaths) bring 200-250 souls with the
bestiary and quests, against first levels of 25-60 and nodes of 120-180; late runs ~170 a run
(the run, quests, the last ranks) against levels and nodes of 140-700. Martyr and Nightmare pay
x1.6 and x2.5 plus more monsters (a Nightmare win 451). Pilgrim runs pay little (x0.5) but the
bestiary and quests pay as much there.

**Open:** the Armory is becoming a multi-level node (another pass): its new cost adds to the tree
and pushes the full tree a few runs later (each 150 souls ~ one late run; the target band 40-60
has room). The career and the per-kill challenge chances are assumptions; real run times and
results (Codex > Runs) would tell. Pilgrim's pace (runs pay x0.5) was not modelled. Unrelated,
found by the balance suite and left alone: `model: degenerate DPS` (degenerate_skills_a3 2.84x)
and `content: unlisted` (nameless_effigy in no act) fail outside KNOWN.

## 2026-10-21 - Every monster shot and dash warns before it comes (by rule, not measured in runs)

Monster skills that fire shots or dash had no warning on the floor during their cast (the
monster only glowed): Frost Breath, Poison Spit, Venom Spit, Eye Beam, Fire Ring, Solar Flare,
Wailing Ring, Slime Storm and Slime Rain, the feather and coin storms, Ink Ring, Throw Bomb,
Coil Rush, Frog Leap, Hoard Leap, Glacial Dive, Charge and Dive. Their cast now shows the lanes
of their shots (one per shot of a fan or a ring, `TelegraphView.show_skill`, 150 units long) or
the line of their dash, filling up like the other telegraphs. No number changed (cast times,
damage, counts are the same), but these attacks are easier to read and dodge, rings of shots
especially (the safe gaps show): bosses with shot rings (Weeping Spirit, Red Samurai, Sun
Wraith, King Slime, Crimson Tengu, Gilded Hoarder) are a little easier. To measure with the
arena (`boss` fights, hits taken per minute) in the next pass; shorten their cast times if they
fell below the target.

## 2026-10-21 - The Soul Moth throws soul flames, not fire (by rule, not measured in runs)

**Why:** the Soul Moth (act II support, `data/monsters/soul_moth.tres`) shot the fire `ghost_flame`
and set the hero on fire: orange flames on the body from a pale spirit. It now throws its own
**Soul Flame** (`data/items/weapons/monster/soul_flame.tres`, the spirit element's wisp): **7
damage** (was 5) and a spirit chill, **30% slower for 1.5 s** (shown as a pale flicker, not
rime), instead of a burn of 2 every 0.5 s for 3 s (up to 12 more). Its shot hurts less in total
but slows the hero while its wards protect the pack, which suits a support; cooldown, range and
speed are unchanged. To watch: act II packs with two moths (the chill keeps the hero in range of
the melee monsters it wards). Moles and Stone Moles now **Burrow** (`data/skills/monster/burrow.tres`)
instead of sharing the spirits' Blink: the same numbers (160 px in 0.12 s, cooldown 4 s), a puff of
earth instead of a ghost's vanishing. No other number changed.

## 2026-10-21 - Three supports stop shooting fire (by rule, not measured in runs)

**Why:** the Moss Heart, the Gilded Moth and the Sand Drummer (and the Soul Moth, see above) all borrowed the Ghost
Lantern's burning Ghost Flame, so a moth of the dead and a heart of moss set you on fire (docs/vfx.md:
fire is fire). Each now shoots its own element, same damage (5), cooldown (1.6 s), reach and speed:
the Gilded Moth a Gilded Mote (holy), **no burn** (was 2
every 0.5 s for 3 s, 12 damage); the Moss Heart Moss Spores (poison), **3 per second for 4 s** (12
damage, as the burn); the Sand Drummer a Sand Clod (earth) that **slows 30% for 1.2 s** instead of
burning (Sand Breath slows 35% for 1.5 s). The Gilded Moth and the drummer, supports kept at range, hurt
a little less; open question: whether the act II and IV packs feel softer (the moths rarely land
a shot while their wards hold). The Ember Heart and the Ghost Lantern keep the Ghost Flame.

## 2026-10-21 - The Frost Staff's shards chill (by rule, not measured in runs)

**Why:** the staff's shots are now the frost element's ice shards (docs/vfx.md), and a frost hit
shows as rime on the body; a frost staff whose shards didn't chill read as a lie. Its basic
attack (`data/items/weapons/stick.tres`) gets a small slow: **20% for 1 s** on hit (Ice Shards
35% for 1.5 s, Frost Nova 50% for 2.5 s, Frostbite 15% per level). It wakes the Frost synergy's
"+50% damage to slowed enemies" on every staff hit, so a staff + Frost family build gains the
bonus without its slowing perks: to measure with the Frost family arena build
(`data/balance/builds/family_frost_a3.tres`). No other number changed.

## 2026-10-21 - Dismantling gear for gold (new economy source, by rule, not measured in runs)

**Design (from the player's request: "the bag fills too fast"):** gear in the bag breaks down for
gold anywhere, one piece or every piece worse than what is worn (design/loot.md, Room in the bag).
With stacks and auto loot "Better only", it is the way out of a full bag between merchants.

**Numbers** (`data/items/dismantle.tres`): gold = value x rarity (1 / 1.8 / 3 / 5) x 0.15 x
(1 + 0.2 per item level above 1), runes set in it at 0.15 of their value. The merchant pays value
x rarity x 1.5 x (1 + 0.2 per floor above 1) x 0.25 = 0.375 x the same worth, so dismantling gives
**40% of what he pays on the item's own floor**, less on deeper floors (a unit check holds it under
for every item, rarity and level 1-15). Dismantle / merchant, gold:

| Item (value) | Lv 1 | Lv 3 | Lv 6 | Lv 10 |
|---|---|---|---|---|
| Katana (35), Common | 5 / 13 | 7 / 18 | 10 / 26 | 15 / 37 |
| Katana, Magic | 9 / 24 | 13 / 33 | 19 / 47 | 26 / 66 |
| Katana, Rare | 16 / 40 | 22 / 55 | 32 / 79 | 44 / 110 |
| Katana, Epic | 26 / 66 | 37 / 92 | 52 / 131 | 73 / 184 |
| Leather Cap (20), Common | 3 / 8 | 4 / 10 | 6 / 15 | 8 / 21 |
| Plate Armor (45), Rare | 20 / 50 | 28 / 71 | 40 / 101 | 57 / 142 |

For scale: a Health Potion costs 18 gold on floor 1, a reroll 10. A floor's worth of commons and
magics dismantled (5-8 pieces) is about one or two potions: a tidy-up, not an income. Not measured:
how much gold a whole run gains (the balance bot never fills its bag); if gold runs high, lower
`gold_share`.

## 2026-10-21 - Second lives go through the trial of the Threshold

**Design (from the player's request):** a revive (Phoenix Feather, Death Denied) no longer heals
in place: the killing blow sends the hero to a limbo where he must slay spectres before a
countdown ends; won, he comes back where he fell with the feather's old heal (half Health, a
quarter in a boss fight, unchanged) and its blast; lost, he dies. See design/builds.md.

**Numbers** (`data/threshold/threshold.tres`): 8 spectres in 25 s in act I, +2 spectres and +6 s
per act (10 in 31 s, 12 in 37 s, 14 in 43 s); 4 up at once, the next 0.7 s after a gap; spectres
at 70% of the same monster's Health (damage unchanged); the hero inside at 60% of his max Health;
1 s of grace when he is back.

**Measured** (a probe bot, not the balance tools: walks at the nearest spectre, holds attack,
rolls and casts every half second, drinks under a third of Health, no dodging; the level of the
depth, a floor-level Katana, Chain Mail and Iron Helm, no perks; 4 trials per depth):

| Depth (act) | Won | Seconds used (of the limit) | Lost by |
|---|---|---|---|
| 1, 3 (I) | 8/8 | 6-17 of 25 | - |
| 4, 6 (II) | 8/8 | 11-18 of 31 | - |
| 7, 9 (III) | 6/8 | 18-30 of 37 | death (9-11 of 12 slain) |
| 10, 12 (IV) | 5/8 | 27-39 of 43 | death (12-13 of 14 slain) |

A first draft (6 in 30 s, +2 and +4 s per act) was won in 6-9 s in act I: no pressure at all.
The bot only dies to damage, never to the clock: a hero with perks who dodges should win most
trials in acts I-II and have to fight for them in III-IV, which is the point (a second life,
not a free one). The balance tools' arena has no Threshold, so a revive still heals in place
there and the measured revive value (+100% / +50%) is unchanged; it is now an upper bound.

## 2026-10-21 - Secret rooms and the hidden floor's boss (new content, not yet measured in the arena)

**Secret rooms** (`dungeon_config.tres` > Secret rooms): 50% a normal floor, one room (two on
floors of 20+ rooms). The generator finds a place on 81% of Pilgrim floors, 93% on Keeper, 97% on
Martyr and Nightmare (300 seeds each, chance forced to 1), so about 40-48% of floors hide one, a
bit more on the big ones. Rewards by weight: Hidden Coffer 30 (2-3 items at quality 3.5, never
trapped: between a chest's 1.5 and the ambush's Big Chest 3.0, for a room the player had to find),
Forgotten Shrine 20, Buried Rune 20, Hoarder's Cache 20 (30-50 gold +6 a floor, after the floor's
gold rules), Sealed Draughts 15 (two rare consumables). Expected extra per floor is small (about
half a chest); no other number moved.

**The Nameless Effigy** (the hidden floor's boss, after Act II's boss, at depth 6): base 1500
Health, 6 Armor, 85 speed, 5% crit, the Ember Ronin's blade (12) and dash, the Mother of Tears'
wailing ring, the skeletons' call from two thirds, fierce versions at one third (wind-up x0.85 /
x0.7, cooldowns x0.85 / x0.7, +2 / +3 Attack, like the other bosses). Scaled by
`boss_hp_scale_per_depth` (0.33) at its floor, on Keeper:

| Boss | Floor | Health | Armor | Model TTK, expected build of its act |
|---|---|---|---|---|
| Azure Wyrm / Mother of Tears / Gorr | 6 | 2650 / 2783 / 3048 | 5 | 36.1 / 37.8 / 41.2 s (expected_a2, 78.6 DPS) |
| **The Nameless Effigy** | 6 | **3975** | 6 | about 52 s (by hand: 3975 / ~77 DPS after its armor) |
| Jade Wyrm / Crimson Tengu / Ember Ronin | 9 | 5278 / 5460 / 5642 | 5 | 37.8 / 39.0 / 40.2 s (expected_a3, 149 DPS) |

Its Health sits between the two acts' bosses (x1.3 Gorr's, x0.73 the Tengu's); against the hero of
floor 6 it is the longest boss fight so far (about 52 s against 36-41 s), on purpose: the floor is
optional, found by a secret, and pays a relic choice, a Big Chest and 60 souls (x the difficulty)
besides the usual boss souls. Its damage is the Ember Ronin's kit at depth 6 instead of 9 (Attack
+5 instead of +8). A unit check keeps its Health between the bosses around it.

**Open:** the balance model only measures the acts' bosses (it lists `nameless_effigy` as
unlisted content); the arena and the model should take the hidden boss at its floor with the act II
expected build (game-balancer pass), and the hidden floor's monsters (Act II's mix plus Cyclops,
3-5 per room in 3 rooms) at depth 6.

## 2026-10-21 - Pact doors: a relic for a hard rule, max Health if it breaks

**Design:** an optional risk room on some floors (`PactRoom`, `data/pacts/`, see
[design/dungeon.md](design/dungeon.md)). Swear the pact, fight the waves behind the sealed door
under its rule: kept, a choice of 3 relics (as after a boss); broken, max Health lost for the rest
of the run, the fight goes on, no relic.

| Pact | Rule | Waves (foes, +1 every 3 floors) | Elites | Cost if broken |
|---|---|---|---|---|
| Untouched | no damage taken | 2 x 2 | the last wave's leader | 12% max Health |
| Knell | all slain in 30 s + 2 s per floor below the first (34 s on floor 3, 46 s on floor 9) | 2 x 3 | the last wave's leader | 12% |
| Fast | no consumable | 3 x 3 | the last wave's leader | 10% |
| Tithe (floor 3+) | lose at most 50% of max Health | 2 x 1 | all of them | 15% |

- **How often:** `pact_chance` 0.7 per normal floor (not the first, not a boss floor); it also needs
  a free dead-end room. Measured with a probe building real floors (25 runs, floors 2-11 without
  the bosses, 175 floors, Keeper): 51% of the floors can hold one (89/175 at a chance of 1), so 31%
  get one at 0.7 (55/175). Pure generation (no merchant or forge taking rooms): 52-63% of the
  floors, from Pilgrim to Nightmare sizes.
- **Not measured yet:** how hard each rule is in play (no bot plays the rules). Open questions: the
  Knell's time (about 3 s per foe with the spawn pauses) and whether the Tithe's elites at depth 9+
  (2 x 4) are fair for a 15% cost. Watch the first playtests on the phone.

## 2026-10-20 - Item level: gear as strong as the floor it came from

**Design (from the player's request):** a floor-1 weapon must be worse than a floor-2 one, and
gear must not grow on its own: to get stronger, loot. Every weapon and armor now carries an item
level, the floor it was found or bought on (`EquipmentDef.item_level`, `ItemLevelRules`,
`data/items/item_levels.tres`). Rarity and affixes come on top.

- **Weapons:** +2 damage per second per level above 1, turned into damage per hit by the weapon's
  speed (`weapon_dps_per_level x cooldown`, divided by the shot share for ranged weapons). The same
  gain for every weapon, so the weapon band measured in phase 2C holds (it narrows toward 1).
- **Armor:** +1.5 Health per level on a body armor, +1 on a helm.
- **Compensation:** monsters and bosses grow at the same pace: `monster_hp_scale_per_depth`
  0.22 -> 0.32, `boss_hp_scale_per_depth` 0.22 -> 0.33. The act IV bosses lost more than the
  rest (the slow Greatsword gains most per hit, and the hero has a little more Health): Gilded
  Hoarder 1750 -> 1925 Health, Sun Wraith 1650 -> 1820, both Attack 2 -> 4.
- **Tools:** `BalanceBuildDef.item_level` (0 = the floor before its act's boss, the default), so
  every build carries gear of its depth.

**Measured (model, seed 1, Normal), phase 2C final -> item level:**

| | Before | Item level, no compensation | Final |
|---|---|---|---|
| Expected build DPS, acts I-IV | 49.5 / 66.3 / 119 / 134 | 53.3 / 78.6 / 149 / 191 | 53.3 / 78.6 / 149 / 191 |
| Boss TTK, act I-IV main boss | 27.1 / 38.8 / 37.2 / 47.2 s | - | 28.9 / 41.2 / 39.0 / 49.1 s |
| Boss threat (face-tank cost), acts I-IV | 170 / 195 / 234 / 210% | 157 / 159 / 176 / 138% | 178 / 197 / 227 / 219% |
| Act step, act IV vs III | x0.90 (target edge) | x0.79 | x0.96 |
| Commons, acts I-IV: time to kill | 0.6 / 0.8 / 1.0 / 1.2 s | 0.5 / 0.7 / 0.8 / 0.8 s | 0.6 / 0.9 / 1.0 / 1.1 s |
| Model flags | 58 | 73 | 51 |

So at the expected gear the game plays as tuned in phase 2, while a hero who keeps floor-1 gear
falls behind: at depth 11 a level-11 common Katana hits for 5 + 8 = 13, a level-1 one for 5.

**Full matrix after everything (phase 2A + 2B + 2C + item level, `--mode=all`, seed 1, 52 min),
vs the phase 2 baseline:** 677 flags (136 errors) -> 296 (28 errors). Face-tank wins in the
arena 29 -> 3, heal-share errors 107 -> 25, weapon flags (model) 35 -> 0, model monster/rank
flags 170 -> 38. The 3 face-tank wins were degenerate stacks living on two Phoenix Feathers
(shrine + relic), each bringing back half Health in a boss fight.

**Phoenix Feather in a boss fight:** back to a quarter of max Health instead of half
(`CheatDeathPassive.boss_fight_heal_ratio`, 0.25 on the feather; texts updated). Arena re-run on
the three builds (Normal and Hard): errors 19 -> 5. Left: `degenerate_max_health_a4` (411 Health,
29 Armor, Leech, two feathers) still wins face to face against the Sun Wraith at 0% health and
loses to the Gilded Hoarder with the boss at 5%; 4 heal-share errors just over 50% (51-56%) on
kite fights of the same degenerate builds.

**Still open:** the expected build's heal share on kite fights (26-59% vs a 25% target) comes from
the Leech rune within the boss-fight cap (0.4%/s): kite fights take little damage, so the share
of a small number reads high. The target may want to apply to face-tank fights only.

## 2026-10-20 - Phase 2C: perks, runes, affixes, weapons, economy

Merged with phases 2A and 2B before the final measures (the tables below say which). Domain:
perks, relics and the five families, runes, item affixes, weapons, shrine upgrades, shop
prices, gold. Not touched (other balancers): monsters, bosses, ranks, elites, difficulties,
the armor formula, the sustain rules. Measured on seed 1, Normal (model on Normal and Hard),
against the phase 2 baseline; each change re-measured with the same seed: `--mode=model`,
`--mode=compound`, `--mode=economy --difficulty=normal,nightmare`, `--mode=marginal --acts=2,3`.

### Rules fixed (code, with game tests in combat_tests.gd)

| Rule | Before | After | Why |
|---|---|---|---|
| Crit shockwaves (Thunderclap, Shatter rune) | the wave caught the enemy struck too (a second hit on every crit, itself able to crit) | the wave hurts the enemies *around* the target, never the one struck (`CritShockwavePassive.hits_target`, off) | crit chance x crit damage x the wave multiplied on a single boss: the crit build (Rapier, 82% crit, 3 Shatter runes) did 6.3x the expected build's damage and face-tanked act II bosses in 7-10 s. The descriptions already said "around" |
| Echoes (Echo perk, Echo runes, of Echoes) | every source rolled on every cast, echoes chained (68% with all of them: a skill cast ~3x per cooldown) | an echo can't echo: the cast an echo made ready rolls nothing; a skill is used at most twice per cooldown | bounded at x2 whatever the stack; each source still rolls on its own |
| Extra projectiles (Multishot, Prism runes) | each added a full shot, no limit (Multishot 2 + 2 Prism: 5 full shots, x5.2 on the Spark Wand at close range) | 2 extra projectiles at most from every source together, and the volley shares its damage: each extra shot adds 65% of a shot | a Prism rune was a free Multishot level; stacking them made every ranged weapon a shotgun |
| Skill recharge cap | 60% | 50% (`SkillSet.MAX_COOLDOWN_REDUCTION`) | with the echo bound, the cap was what left the skills build at 2.9x; only cooldown-stacking builds reach it |

The model (`balance_model.gd`) follows the three rules (the wave off the target, uses per
cooldown = 1 + the chance an echo fires, the cap and the damage share of extra projectiles).

### Data changed

| What | Before | After | Why |
|---|---|---|---|
| Rapier | 3 damage, 0.19 s | 2 damage, 0.31 s (15% crit kept) | 1.6-2.2x the median weapon: speed multiplies every flat Damage bonus |
| Sai | 0.22 s | 0.34 s | 1.4-2.0x the median |
| Ninjaku | 0.30 s | 0.34 s | 1.4x in acts III-IV |
| Pickaxe | 8 damage | 7 | 1.3x in acts I-II (it ignores armor already) |
| Shuriken | 2 damage | 8 (0.45 a star kept: a fan never hits 3x as hard) | 0.33x in act I: three stars of 4 damage did nothing against armor |
| Book | 0.6 s, 0.5 a shot | 0.55 s, 0.6 a shot | 0.6x |
| Frost Staff (stick) | 8 damage, 0.95 a shot | 10, 1.05 | 0.75x everywhere |
| Bow | 0.85 a shot | 0.9 | Epic bow at 0.75x in act I |
| Storm family | every 4th hit, chain to 3 | +15% attack speed, and every 3rd hit chains to 3 | +0-5% marginal value (chains do nothing on a boss); speed of the strike is Storm's theme |
| Arcane family | ring of 8 bolts at 0.5x power | 0.4x | Arcane 1.6x the expected build's DPS, top family pick in acts III-IV |
| Arcane Power | +15% skill damage per level | +12% | the skills build (2.9x after the echo rule) |
| Ignite | 2 per level a tick | 3 | -6% to +3% from act II: flat ticks against armor |
| Bloodrage | +15% per level below half Health | +20% | 4-12% |
| Blazing Roll | 0.4x power | 0.7x | 0-9% |
| Executioner | +60% per level | +75% | 8-18% (0.3x-0.9x the relic median) |
| Guardian Ring | +3 Armor | +2 (25 Health and the ward kept) | 2-13x the relic median, mostly from flat Armor |
| Fortified (affix) | +4 Armor | +3 | +301% in act III (21x the median): as much Armor as a Plate Armor from one affix |
| Ember rune | 35% chance, 2 a tick | 50%, 3 | -6% to +5% |
| Spark rune | every 4th hit, 0.5x | every 3rd hit, 0.6x | -3% to +5% |
| Burning (affix) | 2 a tick | 3 | -2% to +10% |
| Shocking (affix) | every 5th hit, 0.4x | every 4th hit, 0.5x | -5% to +6% |
| of Echoes | 10% | 12% | the echo rule makes stacking safe |
| Vampirism | 2 Health a kill per level | 3 | 0.15x the median in act II once 2A's boss-fight budget stopped paying it: buffed where it works, in packs (boss adds feed nothing) |
| Holy Light, Holy Shield, Smite (`HealEffect.boss_fight_ratio`, new) | full heal everywhere; Holy Light 35%, Holy Shield 10% | half during a boss fight; Holy Light 30%, Holy Shield 8% | the Templar Sword's spells (75-300 Health a fight) carried the face-tank wins of the act IV degenerate builds (phase 2A); out of boss fights they still forgive mistakes. Descriptions now say Health and Armor (were HP, DEF) |
| Gold | 45% drop chance, +0.6 a kill per floor, boss x15, crates +0.5 per floor | 30%, +0 per floor, boss x10, crates +0.25 | gold grew x6-x10 from floor 1 to 10 while prices grew x1.7 |
| Merchant | prices x1, +8% per floor, sells back 35% | x1.5, +20% per floor, sells back 25% (about the same gold back) | a visit's gold bought 4-23 average items |
| Shrine | 3150 souls in all | 4505 (stat levels' growth, Second Chance 400 -> 700, unlocks +20) | ~13 runs on Normal to buy it all (target 15-60) |
| Target: weapon DPS vs the median | 0.6x-1.6x | 0.75x-1.4x | every weapon fits the tighter band now; the old one allowed a 2.7x spread |

Not changed, on purpose:
- **Armor picks** (Frost Armor +252%, Sturdy, Toughness +119% in act III) came from the flat
  armor formula, which phase 2A replaced: only the outliers that were armor *on top of*
  something else moved (Fortified, Guardian Ring). Re-measured after the merge: Frost Armor
  +16-18%, Toughness +12-13%, Fortified +12-13% (tables below): no more outliers.
- **Leech rune** (+85% in act II = 8x the median) and Devotion: their whole value was the
  sustain budget, which phase 2A cut in boss fights (Leech now -1% / +3%).
- **Blood family's DPS** (1.06x the expected build): its power is sustain and low-health damage,
  which the DPS ratio can't see; as a marginal value it is the top family (act II 3.8x).
- **Slows, thorns, control** (Frostbite, Cold Snap, Rime, Frozen, of Thorns, Frost family) read
  +0% on dummies (Limits): left alone.

### Before / after

Weapons (model, after merging 2A; Common weapon on each act's expected hero, DPS vs the act boss
/ median weapon; every rarity now within 0.75-1.4x, Normal and Hard):

| Weapon | Before (act I / II / III / IV) | After |
|---|---|---|
| axe | 1.00x / 0.98x / 0.93x / 0.87x | 0.98x / 0.95x / 0.86x / 0.82x |
| big_sword | 1.04x / 1.02x / 0.93x / 0.88x | 1.02x / 0.98x / 0.87x / 0.82x |
| book | 0.59x / 0.60x / 0.83x / 0.81x | 0.89x / 0.99x / 0.99x / 1.00x |
| bow | 0.80x / 0.85x / 1.00x / 1.00x | 0.89x / 0.94x / 1.01x / 1.00x |
| hammer | 1.08x / 1.04x / 0.92x / 0.86x | 1.05x / 1.01x / 0.86x / 0.79x |
| katana | 1.00x / 1.04x / 1.18x / 1.16x | 1.02x / 1.05x / 1.12x / 1.11x |
| lance | 1.07x / 1.08x / 1.12x / 1.08x | 1.07x / 1.07x / 1.05x / 1.02x |
| magic_wand | 0.80x / 0.86x / 1.00x / 1.01x | 0.84x / 0.90x / 0.96x / 0.95x |
| ninjaku | 1.09x / 1.20x / 1.40x / 1.41x | 1.04x / 1.11x / 1.21x / 1.21x |
| pickaxe | 1.29x / 1.28x / 1.22x / 1.16x | 1.20x / 1.18x / 1.09x / 1.04x |
| rapier | 1.62x / 1.79x / 2.23x / 2.24x | 0.95x / 1.05x / 1.22x / 1.26x |
| sai | 1.44x / 1.58x / 1.97x / 1.97x | 1.05x / 1.13x / 1.27x / 1.28x |
| shuriken | 0.33x / 0.35x / 0.80x / 0.85x | 1.08x / 1.13x / 1.15x / 1.14x |
| stick | 0.76x / 0.75x / 0.77x / 0.74x | 0.94x / 0.94x / 0.85x / 0.81x |
| templar_sword | 0.92x / 0.93x / 0.99x / 0.96x | 0.93x / 0.92x / 0.93x / 0.91x |
| whip | 0.84x / 0.89x / 1.02x / 1.00x | 0.87x / 0.89x / 0.96x / 0.96x |

Degenerate and family builds (model, DPS vs the act's expected build on its boss, Normal):

| Build | Before | After |
|---|---|---|
| degenerate_crit_a2 (Rapier, 3 Shatter) | 6.28x | 1.67x |
| degenerate_skills_a3 (3 Echo runes, Echo, Codex) | 4.77x | 2.50x |
| degenerate_attack_speed_a1 (Sai) | 2.25x | 1.55x |
| degenerate_burn_a3 | 1.43x | 1.60x |
| family_arcane_a3 | 1.60x | 1.28x |
| family_frost_a3 | 1.38x | 1.39x |
| family_inferno_a3 | 1.25x | 1.35x |
| family_storm_a3 | 1.11x | 1.08x |
| family_blood_a3 | 0.98x | 1.06x |

(After merging phase 2A's armor formula. expected_a3 itself lost its Thunderclap hits on the
boss: 124 -> 119 DPS.)

Compound (engine, before merging 2A; dummy DPS vs the plain weapon / the expected build):

| Stack | Before | After |
|---|---|---|
| Spark Wand + Multishot 2 + 2 Prism, 64 px | x5.21 | x1.97 |
| Spark Wand + Multishot 2, 64 px | x3.10 | x1.97 |
| Bow + Multishot 2 + 2 Prism, 64 px | x3.78 | x1.48 |
| Frost Staff + Multishot 2 + 2 Prism, 64 px | x3.59 | x1.68 |
| A Prism rune on the Spark Wand | x1.78 | x1.61 |
| All echoes (act II) | x2.29 | x2.17 |
| Attack speed x crit x damage (act II) | x2.27 | x2.32 |
| Burns all together (act II) | x2.04 | x1.98 |

Economy (engine, seed 1, after merging 2A and 2B (rarer, tougher elites); items an average
merchant visit's gold buys, target 0.8-3):

| | Before | After |
|---|---|---|
| Normal, depths 1-2 | 4.7 / 4.4 | 2.4 / 1.8 |
| Normal, depths 4-5 | 8.4 / 11.5 | 2.6 / 3.2 |
| Normal, depths 7-8 | 22.7 / 14.5 | 3.3 / 2.1 |
| Normal, depths 10-11 | 19.0 / 17.4 | 2.5 / 1.8 |
| Easy, depths 1-11 | 2.5-10 | 1.1-2.2 |
| Hard, depths 1-11 | 5.9-35.5 | 2.2-5.2 |
| Nightmare, depths 1-11 | 11-44 | 4.0-5.4 |
| First reroll / a floor's gold (Normal) | 2-11% | 8-15% |
| Rune removal / a floor's gold (Normal) | 6-28% | 17-36% |
| Shrine, runs to buy it all: Normal dying at act II / III | 16.3 / 9.3 | 23.3 / 13.2 |
| Shrine, runs: Nightmare dying at act II / III | 3.4 / 2.4 | 4.9 / 3.4 |
| First run (dies at the act I boss, 61 souls) | buys a level | buys a level (30-40) |

Hard and Nightmare stay above 3 and their souls fill the shrine in 3-10 runs: the difficulties'
gold and soul multipliers belong to the difficulties (other balancer); proposal: Hard gold x0.7,
Nightmare x0.6 of today's. Normal depths 5 and 7 are just over 3 (3.2, 3.3).

Marginal values (engine, acts II and III, Normal, after merging 2A and 2B; value at max level,
x = vs the category's median). The medians fell a lot (2A's armor and boss-fight budget took
away most of the defensive and healing values; 2B's tougher monsters), so read the values, not
only the ratios. Picks over 2x / under 0.5x their median: act II 11 / 35 -> 11 / 36, act III
11 / 23 -> 8 / 26; most of the "under" are the blind spot (slows, thorns, kill heals, rolls: +0%
on dummies).

| Pick | Act II before | Act II after | Act III before | Act III after |
|---|---|---|---|---|
| Frost Armor x4 | +51% (1.4x) | +18% (1.7x) | +252% (12.3x) | +16% (0.9x) |
| Burning Thorns x3 | +38% (1.1x) | +13% (1.2x) | +188% (9.2x) | +12% (0.7x) |
| Thunderclap x3 | +84% (2.3x) | +3% (0.3x) | +71% (3.5x) | +24% (1.4x) |
| Vitality x5 | +50% (1.4x) | +45% (4.3x) | +87% (4.2x) | +53% (3.1x) |
| Frenzy x4 | +22% (0.6x) | +30% (2.8x) | +29% (1.4x) | +30% (1.7x) |
| Ignite x3 | -6% | +7% (0.7x) | +3% (0.1x) | +8% (0.5x) |
| Bloodrage x3 | +9% (0.3x) | +9% (0.8x) | +6% (0.3x) | +6% (0.3x) |
| Echo x3 | +24% (0.7x) | +3% (0.3x) | +30% (1.5x) | +7% (0.4x) |
| Devotion x3 | +72% (2.0x) | +2% (0.2x) | +4% (0.2x) | -2% |
| Vampirism x3 | +19% (0.5x) | +1% (0.1x) | +3% (0.1x) | -12% |
| Guardian Ring | +63% (1.9x) | +41% (2.0x) | +114% (5.7x) | +31% (1.3x) |
| Phoenix Feather | +100% (3.0x) | +100% (4.8x) | +100% (5.0x) | +100% (4.3x) |
| Executioner x2 | +11% (0.3x) | +11% (0.6x) | +18% (0.9x) | +16% (0.7x) |
| Storm family | -3% | +7% (1.5x) | +5% (0.7x) | +17% (1.6x) |
| Arcane family | +6% (1.0x) | +2% (0.5x) | +17% (2.1x) | +8% (0.8x) |
| Blood family (awake) | +24% (3.8x) | +15% (3.4x) | +0% | +12% (1.1x) |
| Leech rune | +85% (8.3x) | -1% | +10% (1.2x) | +3% (0.4x) |
| Fury rune | +23% (2.2x) | +5% (1.5x) | +19% (2.4x) | +9% (1.0x) |
| Spark rune | -3% | +0% | -1% | +9% (1.1x) |
| Ember rune | -6% | +0% | +2% (0.3x) | -7% |
| Echo rune | +1% (0.1x) | +0% | +6% (0.7x) | +10% (1.1x) |
| Fortified | +58% (16.8x) | +13% (1.6x) | +301% (21.3x) | +12% (2.3x) |
| Sturdy | +22% (6.5x) | +8% (1.0x) | +80% (5.6x) | +8% (1.5x) |
| Brutal | +30% (8.6x) | +19% (2.4x) | +23% (1.6x) | +12% (2.4x) |
| of Echoes | +1% (0.4x) | +0% | +6% (0.4x) | +10% (2.0x) |
| Shrine Toughness x3 | +34% (1.0x) | +13% (0.6x) | +119% (3.2x) | +12% (0.7x) |
| Shrine Might x5 | +39% (1.2x) | +21% (1.0x) | +21% (0.6x) | +21% (1.3x) |

- Phoenix Feather and Second Chance read +100% / +50% by construction (a revive doubles the time
  to die); Vitality is the remaining stat outlier on paper (+45-53%): health is worth more now
  that armor is weaker. Watch it, no change yet (one more measure after the monsters settle).
- Echo, Devotion, Leech, Vampirism fell with 2A's boss-fight budget and the echo rule; Leech is
  where it should be for a rune that the budget now limits. Brutal (+4 Damage on a weapon) is the
  top affix at 2.4x: flat damage on a single affix; next pass.

### Guards

- Game tests (`combat_tests.gd`): Multishot 2 + two Prism runes fire 3 shots sharing the damage;
  a Thunderclap crit doesn't hurt the enemy struck but hurts those around; a 100% echo gives one
  free cast, not a loop; the three healing spells heal in full outside a boss fight and carry a
  boss-fight share of at most half.
- Balance suite: `model: weapon DPS`, `model: degenerate DPS` and `economy: shop` (quick, two
  Normal floors) pass now (removed from KNOWN); new `family: <id> DPS` checks (each family
  1.0-1.5x the expected act III build: pass). `marginal: too weak` (Vampirism x3 in act II,
  0.05x) added to KNOWN as a measuring blind spot: kills heal nothing in a boss fight since 2A
  and the dummy rooms don't hurt, so a kill heal shows nothing in the lab; its value is pack
  sustain, buffed to 3 a kill. Suite after the merges: 73 checks, 9 failures, all KNOWN but
  `model: act curve` (act IV vs act III x0.90, at the edge of x0.9-1.6: the expected act III
  build lost its Thunderclap hits on the boss, so act III got a little longer).

### Open

- `model: act curve` act IV vs act III at x0.90 (edge): bosses' side.
- Weapon arena (kite bot, Common weapons) not re-run: it depends on the bosses and the kite bot
  being reworked in parallel; fast melee weapons lost 9 of 10 bosses mostly by taking hits in
  melee, not by damage. Re-run `--mode=arena` after merging.
- Armor picks and Leech after the armor formula and sustain changes (see above).
- Normal depths 5 and 7 a little over 3 items per visit; Nightmare's gold.
- Encounters: the Grinning Spirit's gold choices read +0% (gold isn't valued by the lab).

## 2026-10-20 - Phase 2B: common monsters, ranks, elite affixes, difficulties, depth scaling

Measured with `--mode=model` (every monster x rank x depth x difficulty, seed 1) before and after
each change, and `--mode=pack` (engine, Normal and Hard) after. Bosses, sustain, the armor rule,
perks, runes, gear and the economy were left to the other phase 2 passes (A and C): bosses keep
exactly their numbers (their depth scaling now has its own fields, set to the old values; the
model's boss tables and curve are unchanged by this pass).

**Read the last part first ("After merging phase 2A"):** the tables in between were measured
with the old flat armor; 2A's percentage armor made two of the damage changes compound, and
they were reverted.

**What was wrong.** Commons died in 0.2-0.9 s and cost the expected builds 0.3-0.8% of their
Health each (face to face); act II-IV commons needed 100-123 hits to kill the hero on Normal and
the cost *fell* act after act (0.8%, 0.3%, 0.3%, 0.4%: hero Armor grew 2 -> 13 while monster attack
grew +1 per floor). A rank was only more Health (Elite x2.5, Epic x3.5, Legendary x5) and no more
damage, so an Elite died in 1-1.8 s and a Legendary in 2.4-3.9 s for 2.5-3.6% of the hero's Health.

**Changes (data, plus two small rules):**

| What | Before | After | Why |
|---|---|---|---|
| Common monsters' base Health (`data/monsters/*.tres`) | - | x0.8-x2.6 each (act I x1.08-1.6, act II x1.6-2.6, act III x1.3-2.2, act IV x0.8-1.9); the spread compressed (fodder up more than tanks; Dune Rex, the slowest to kill, 85 -> 70) | time to kill to 0.6 / 0.8 / 0.9 / 1.2 s (medians, acts I-IV); act I capped at x1.6 so a level-1 hero on floor 1 still kills a rat in 3-4 hits |
| ~~Act II commons' attack (skeleton, sorcerer, skull, lantern, frost skull, soul moth, brood mother +2; eye, owl +1)~~ | 0 | ~~+1/+2~~ **reverted after 2A** | act II hit the hero for 1-3 after its Armor (7): the cheapest act. Not needed with 2A's armor (below) |
| Act III commons' attack (shaman, flam, reptile, dragon, kappa, octopus, ember heart) | 0 | +1 | keeps act III a little harder than act II |
| `monster_attack_per_depth` (now a float, rounded) | 1 | ~~1.5~~ **1.0 after 2A** (monsters only) | was: monster damage kept up with the hero's flat Armor. With 2A's armor it compounded (below) |
| `boss_hp_scale_per_depth`, `boss_attack_per_depth` (new) | (shared) | 0.22, 1.0 = the old values | bosses are tuned one by one (phase 2A): the monsters' scaling no longer moves them |
| `MonsterRankDef.hp_multiplier_per_depth` (new rule) | - | Elite 2.5 **+0.3**/floor, Epic **4.5 +0.45**, Legendary **6.5 +0.5**, Shiny **3.3 +0.15** | the hero's damage grows ~x10 over act I and ~x3 after: one flat multiplier makes either a floor-1 slog or a deep pushover. Depth 1/5/11: Elite x2.5/x3.7/x5.5, Epic -/x6.3/x9, Legendary -/x8.5/x11.5 |
| `MonsterRankDef.damage_multiplier` (new rule, not bosses) | x1 | Elite **x1.15**, Epic **x1.2**, Legendary **x1.3**, Shiny x1 | a rank is a threat, not only a sponge (kept small: flat Armor turns x1.3 raw into x1.5-x2 after Armor) |
| `elite_chance_per_depth` | 0.015 | **0.012** | tougher elites, a little rarer: act IV Normal 15% (was 18%) |
| Hard / Nightmare `elite_chance` | x1.6 / x2.5 | **x1.4 / x1.7** | with ranks 2-4x tougher, 56% of Nightmare act IV monsters came ranked; now 35% (Nightmare +5: 78% -> 45%; Normal 25% -> 22%). Also bosses' rare-rank chance on those difficulties |
| Ascension 3 "Elite Guard" | elites +50% | **+30%** | same reason; description updated |

`Monster.make_ranked` applies the rank's depth Health and damage (`Monster._depth`, set in
`setup`); `FloorRules.scale_monster` picks the boss or monster depth values; the model
(`foe_numbers`) does the same. README: rank table (Health, Damage per depth) and Elite chance
row updated.

**Before -> after (model, every difficulty, the act's last normal floor, the act's expected build, medians over
the act's monsters).** Time to kill · share of the hero's Health lost killing one face to face
(no dodging) · commons: average hits to kill the hero:

| Act | Difficulty | Common | Elite | Epic | Legendary | Shiny |
|---|---|---|---|---|---|---|
| 1 | easy | 0.2→**0.4** s · 0.3→**0.3**% · 64→**64** hits | 0.7→**1.1** s · 0.8→**1.8**% | - | - | 0.7→**1.4** s · 0.8→**1.2**% |
| 1 | normal | 0.4→**0.6** s · 0.8→**1.3**% · 32→**26** hits | 0.9→**1.6** s · 2.5→**5.2**% | - | - | 1.1→**1.9** s · 2.5→**4.3**% |
| 1 | hard | 0.5→**0.7** s · 1.7→**2.4**% · 21→**18** hits | 1.2→**2.1** s · 4.8→**10.2**% | - | - | 1.4→**2.5** s · 5.1→**8.4**% |
| 1 | nightmare | 0.6→**1.0** s · 3.5→**5.2**% · 14→**12** hits | 1.6→**2.8** s · 10.1→**18.4**% | - | - | 1.8→**3.3** s · 10.5→**18.0**% |
| 1 | nightmare+5 | 0.7→**1.1** s · 4.5→**6.7**% · 13→**11** hits | 1.9→**3.2** s · 12.8→**25.0**% | - | - | 2.0→**3.8** s · 13.6→**22.9**% |
| 1 | nightmare+10 | 0.8→**1.3** s · 5.8→**8.4**% · 12→**10** hits | 2.1→**3.7** s · 16.2→**33.6**% | - | - | 2.3→**4.4** s · 17.5→**29.3**% |
| 2 | easy | 0.2→**0.6** s · 0.1→**0.2**% · 200→**150** hits | 0.7→**2.3** s · 0.3→**1.4**% | 1.0→**4.1** s · 0.5→**3.3**% | 1.7→**6.3** s · 1.1→**7.4**% | 0.8→**2.3** s · 0.3→**0.9**% |
| 2 | normal | 0.4→**0.8** s · 0.3→**1.5**% · 100→**33** hits | 1.0→**3.3** s · 0.9→**9.2**% | 1.5→**5.9** s · 1.5→**19.0**% | 2.4→**9.1** s · 2.5→**35.2**% | 1.1→**3.3** s · 0.9→**5.9**% |
| 2 | hard | 0.5→**1.1** s · 1.0→**3.8**% · 40→**18** hits | 1.3→**4.4** s · 2.8→**19.8**% | 1.9→**7.8** s · 4.5→**42.5**% | 3.1→**11.8** s · 7.8→**75.2**% | 1.4→**4.2** s · 3.1→**14.7**% |
| 2 | nightmare | 0.6→**1.4** s · 2.4→**8.0**% · 22→**12** hits | 1.7→**5.7** s · 6.5→**42.8**% | 2.5→**10.6** s · 10.4→**89.8**% | 4.0→**15.8** s · 17.9→**150.8**% | 1.8→**5.5** s · 7.2→**31.0**% |
| 2 | nightmare+5 | 0.7→**1.6** s · 3.3→**10.8**% · 18→**10** hits | 1.9→**6.6** s · 8.9→**55.8**% | 2.9→**12.3** s · 14.2→**118.8**% | 4.7→**18.2** s · 24.2→**195.8**% | 2.1→**6.4** s · 9.9→**42.0**% |
| 2 | nightmare+10 | 0.8→**1.9** s · 4.6→**13.8**% · 15→**10** hits | 2.2→**7.7** s · 12.4→**74.5**% | 3.4→**14.1** s · 19.8→**155.5**% | 5.4→**20.9** s · 33.5→**264.8**% | 2.5→**7.3** s · 13.7→**54.0**% |
| 3 | easy | 0.4→**0.6** s · 0.1→**0.2**% · 229→**229** hits | 0.9→**3.0** s · 0.3→**1.8**% | 1.4→**5.3** s · 0.6→**4.7**% | 2.1→**7.3** s · 1.2→**9.3**% | 1.1→**2.8** s · 0.3→**0.7**% |
| 3 | normal | 0.5→**0.9** s · 0.3→**1.5**% · 108→**33** hits | 1.4→**4.3** s · 0.9→**11.9**% | 1.9→**7.7** s · 1.8→**23.4**% | 3.0→**10.8** s · 3.3→**40.8**% | 1.5→**3.9** s · 0.9→**6.7**% |
| 3 | hard | 0.7→**1.2** s · 1.1→**4.1**% · 38→**18** hits | 1.8→**5.7** s · 3.2→**27.1**% | 2.6→**10.1** s · 5.4→**56.6**% | 4.0→**14.2** s · 8.7→**91.3**% | 2.0→**5.1** s · 3.4→**17.9**% |
| 3 | nightmare | 0.9→**1.5** s · 3.1→**9.3**% · 19→**11** hits | 2.3→**7.5** s · 8.6→**57.9**% | 3.4→**13.4** s · 13.5→**116.2**% | 5.2→**19.1** s · 22.0→**191.0**% | 2.6→**6.7** s · 9.3→**40.3**% |
| 3 | nightmare+5 | 1.0→**1.8** s · 4.1→**12.1**% · 16→**10** hits | 2.6→**8.7** s · 11.5→**75.3**% | 3.8→**15.4** s · 18.4→**149.8**% | 6.0→**22.0** s · 29.3→**248.7**% | 3.0→**7.7** s · 12.4→**52.4**% |
| 3 | nightmare+10 | 1.1→**2.0** s · 5.5→**16.2**% · 14→**8** hits | 3.0→**10.0** s · 15.7→**103.1**% | 4.4→**17.8** s · 24.9→**198.9**% | 6.9→**25.3** s · 39.8→**333.8**% | 3.4→**8.9** s · 16.6→**70.3**% |
| 4 | easy | 0.5→**0.8** s · 0.1→**0.2**% · 285→**270** hits | 1.3→**4.9** s · 0.4→**2.0**% | 1.9→**8.4** s · 0.8→**5.5**% | 2.7→**10.9** s · 1.7→**10.8**% | 1.4→**3.9** s · 0.3→**1.0**% |
| 4 | normal | 0.7→**1.1** s · 0.4→**2.0**% · 123→**41** hits | 1.8→**7.0** s · 1.3→**18.4**% | 2.7→**12.1** s · 2.3→**36.7**% | 3.9→**16.1** s · 3.6→**64.2**% | 2.0→**5.5** s · 1.3→**9.5**% |
| 4 | hard | 0.9→**1.5** s · 1.7→**5.7**% · 41→**20** hits | 2.4→**9.1** s · 4.8→**44.7**% | 3.6→**15.7** s · 7.5→**88.1**% | 5.2→**21.5** s · 12.4→**147.4**% | 2.6→**7.2** s · 5.0→**27.2**% |
| 4 | nightmare | 1.1→**2.0** s · 4.8→**12.8**% · 20→**12** hits | 3.1→**11.9** s · 12.8→**97.9**% | 4.6→**20.7** s · 20.8→**192.3**% | 6.8→**29.6** s · 33.6→**315.1**% | 3.4→**9.4** s · 14.4→**61.6**% |
| 4 | nightmare+5 | 1.3→**2.3** s · 6.6→**17.5**% · 17→**10** hits | 3.6→**13.9** s · 17.8→**130.0**% | 5.3→**24.2** s · 29.2→**254.2**% | 8.0→**34.8** s · 46.5→**409.8**% | 3.9→**10.8** s · 19.8→**83.7**% |
| 4 | nightmare+10 | 1.5→**2.6** s · 9.1→**23.6**% · 14→**9** hits | 4.1→**16.2** s · 25.0→**174.2**% | 6.1→**28.8** s · 41.1→**340.4**% | 9.2→**41.0** s · 64.4→**566.5**% | 4.5→**12.4** s · 27.2→**113.3**% |

Commons' curve and ranks' ladder (new model table `monster_ladder`, Normal, medians):

| Act | Common TTK | Common Health lost | Step | Elite | Epic | Legendary | Shiny |
|---|---|---|---|---|---|---|---|
| I | 0.4 -> **0.6 s** | 0.8% -> **1.3%** | - | 0.9 -> **1.6 s** / 2.5% -> **5.2%** | - | - | 1.1 -> **1.9 s** |
| II | 0.4 -> **0.8 s** | 0.3% -> **1.5%** | x0.38 -> **x1.19** | 1.0 -> **3.3 s** / 0.9% -> **9.2%** | 1.5 -> **5.9 s** / **19%** | 2.4 -> **9.1 s** / **35%** | 1.1 -> **3.3 s** |
| III | 0.5 -> **0.9 s** | 0.3% -> **1.5%** | x1.0 -> **x1.02** | 1.4 -> **4.3 s** / 0.9% -> **11.9%** | 1.9 -> **7.7 s** / **23%** | 3.0 -> **10.8 s** / **41%** | 1.5 -> **3.9 s** |
| IV | 0.7 -> **1.2 s** | 0.4% -> **2.0%** | x1.33 -> **x1.29** | 1.8 -> **7.0 s** / 1.3% -> **18.4%** | 2.7 -> **12.1 s** / **37%** | 3.9 -> **16.0 s** / **64%** | 2.0 -> **5.5 s** |

Model flags (seed 1, all difficulties; per monster, Normal): monster TTK 24 -> **6**, Elite TTK
43 -> **16**, Epic 34 -> **7**, Legendary 34 -> **6**, Shiny 35 -> **8** (170 -> 43). New checks
"model: monster curve" and "model: rank ladder": 0 flags. Boss tables, the boss curve and the
difficulty curve: unchanged (bosses untouched).

What is left, and why it is left:
- **Act I ranks (all 10 act I Elites at 0.8-2.3 s, 7 Shinies).** The model measures them against
  the level-6 build that reaches the act I boss; the same monsters meet a level-1 hero with a tenth
  of that damage on floor 1. Raising them to 3 s would make a floor-1 Elite slime a 30-s slog for
  a fresh hero. The per-depth rank Health is the compromise (an Elite is x2.5 on floor 1, x3.7 on
  floor 5). Same for the swarm fodder (rat, bat, larva, snake at 0.3-0.4 s: one or two hits by
  design, "comes in numbers").
- **Act II-III fodder ranks** (Elite bat, skull, frost skull, thief racoon, flam: 1.2-2.7 s) and
  the **Dune Rex** ranks (Elite 11.3 s, Epic 19 s, Legendary 26 s: act IV's tank, plain 1.9 s after
  its Health 85 -> 70): edge cases of one multiplier on a spread of kinds.
- **Boss adds are commons (finding for phase 2A).** King Slime and Giant Frog call slimes, the act
  II/III/IV bosses skeletons, spirits, flams, gold racoons: they got this pass's Health and
  attack. The balance suite's duel "expected_a1 kite wins" vs King Slime now **fails**: baseline a
  win (hero min 45%, 70 taken in 8 hits); now a loss with the boss at 1-4% (128 taken in 14-15
  hits), with the slime's Health brought back to 28 (x1.08) for it; the rest is the +1 attack
  per hit at depth 3. A coin-flip fight, but a regression: phase 2A should decide (fewer or
  weaker adds in `data/skills/boss/call_*`, or a rule scaling boss-summoned adds with the boss
  depth values). Giant Frog's kite fight was already a loss in the baseline.
- **High difficulties.** Nightmare and its ascensions multiply Health x1.7-2.25 on top: an act IV
  Legendary takes 30 s on Nightmare and 41 s on Nightmare +10 (face to face it would cost 3-5x the
  hero's Health: it must be dodged, like a boss). The expected builds are the Normal ones (on
  Nightmare a player is 2-3 levels higher: economy table "XP before each act's boss"); the
  ranked share was cut instead of their Health (above). Watch it in real Nightmare runs.
- **Difficulty curve (boss threat): Easy act IV x0.12, Nightmare act IV x5.19.** Both come from the
  flat armor rule (`Combat.mitigate`): x0.6 damage against 13 Armor leaves 1-point hits on Easy;
  x1.8 against it more than triples them on Nightmare. Not fixed with difficulty numbers: phase
  2A's armor rule decides it.

**Depends on armor (phase 2A changes `Combat.mitigate`).** Every damage number above is after
today's flat armor (hero Armor 2 / 7 / 10 / 13 at acts I-IV). The new monster damage (+0.5 attack
per floor, act II +1/+2, act III +1, rank x1.15-x1.3) was kept small on purpose: under a
diminishing-returns armor the same raw numbers hit harder at act III-IV (where flat Armor now
eats 10-13 points of each hit) and softer in act I. After 2A lands, re-run `--mode=model` and
check: commons' hits to kill the hero >= 6 on Nightmare +10 (today 8-10), the "monster curve"
step (x0.9-1.6 per act), Elite/Legendary Health lost on Normal (today 5-18% / 35-64%), and the
difficulty curve (Easy act IV should rise toward x0.4, Nightmare act IV fall toward x3). If act
III-IV commons get too sharp, lower `monster_attack_per_depth` back toward 1.0 first.

**Rewards and economy (phase 2C).** XP, gold and drops per rank are unchanged, but ranked monsters
are rarer (Normal act IV 25% -> 22% of monsters, Hard and Nightmare more so) and take longer: the
souls, XP and gold per floor measured by `--mode=economy` move a little; re-measure there.

Engine (pack mode, Normal and Hard, expected builds): measured before the last touch-ups (act II
commons +20% Health, act III +1 attack, slime 34 -> 28, Dune Rex 85 -> 70), seed 1; medians:

| Act | Ranked + 2 commons, face-tank: Elite / Epic / Legendary / Shiny TTK (before -> after) | Rooms, expected build, kite: Health lost / clear | Face-tank |
|---|---|---|---|
| I Normal | 0.8 -> **1.5** / 1.8 -> **4.3** / 3.6 -> **6.0** / 0.8 -> **1.8** s | 0% -> 0% / 2.1 -> 3.6 s | 2% -> 2% |
| II Normal | 0.6 -> **2.2** / 0.1 -> **3.1** / 1.2 -> **4.2** / 0.9 -> **2.1** s | 0% -> 0% / 4.6 -> 6.8 s | 0% -> 0% |
| III Normal | 1.5 -> **5.1** / 1.8 -> **6.7** / 3.0 -> **9.7** / 2.2 -> **4.2** s | 0% -> 0% / 14.9 -> 14.7 s | 0% -> 0% |
| IV Normal | 1.8 -> **6.5** / 1.8 -> **6.0** / 3.0 -> **12.0** / 1.2 -> **5.4** s | 0% -> 0% / 9.3 -> 12.6 s | 1% -> 5% |
| III Hard | 0.2 -> **6.2** / 4.1 -> **13.4** / 4.1 -> **18.1** / 0.4 -> **6.0** s | 0% -> **10%** / 24.7 -> 23.2 s | 1% -> 14% |
| IV Hard | 0.3 -> **5.9** / 3.1 -> **10.6** / 3.6 -> **13.8** / 0.9 -> **5.9** s | 0% -> **2%** / 17.4 -> 19.3 s | 8% -> **25%** |

Ranked monsters now last a real duel on the engine too (the before column has engine noise:
0.1 s = slain in the hit that hurt it first). Mixed rooms still cost the kite bot almost nothing on
Normal (room damage is a ceiling target, <= 35%: met everywhere) and face-tanking them 0-5%: the
commons' extra damage shows on Hard (10-25%) and against ranked monsters (Normal face-tank: Epic
and Legendary rooms 2-27%). Act IV with the kite bot and the slow Greatsword: the Epic, Legendary
and Shiny rooms ran 30-49 s or to the timeout (the bot keeps range and swings rarely); face-tank
6-12 s. Watch that in play: if act IV ranks drag, lower `hp_multiplier_per_depth` first.

Guard tests: unit `_test_monster_ranks` (Elite < Epic < Legendary in Health at every depth, a
Shiny below an Epic, no rank weaker deeper, damage x1 < Elite <= Epic <= Legendary <= x1.5, a
Shiny hits like its kind; bosses scale with the boss depth values, monsters with theirs); floor
test (an Elite has the rank's Health at its depth and hits harder); balance suite: "model: monster
curve" and "model: rank ladder" (target `rank_ladder_step_min` = 1.2 in targets.tres).
Regular suites: unit,title 4734 checks, game 900, tutorial 273: 0 failed. Balance suite: the
known failures (fewer flags each), "duel: degenerate_lifesteal_a1 face-tank loses" now passes
(left in KNOWN for phase 2A to confirm), "duel: expected_a1 kite wins" newly failed before the 2A merge (it passes after it: below).

### After merging phase 2A (percentage armor): re-measured, two damage changes reverted

2A's `Combat.mitigate` (damage x damage / (damage + armor), at least 1) already makes the
commons hit for real: on top of it, this pass's extra monster damage compounded. Model on the
merged branch with every 2B change kept (Normal, medians): a common cost 1.4 / 2.3 / 2.7 / 4.0% of
the hero's Health (acts I-IV), act II stepped x1.71 over act I (flag), an act IV Elite 28% and
Legendary 90% face to face. Measured three variants (same seed):

| Variant | Commons' Health lost (I-IV) | Steps | Act IV Elite / Legendary | Flags |
|---|---|---|---|---|
| all 2B changes | 1.4 / 2.3 / 2.7 / 4.0% | x1.71, x1.17, x1.46 | 28% / 90% | monster curve |
| without act II/III attack | 1.4 / 2.2 / 2.6 / 4.0% | x1.64, x1.15, x1.55 | 28% / 90% | monster curve |
| also `monster_attack_per_depth` 1.0 | 1.2 / 1.7 / 1.7 / 2.7% | x1.40, x0.99, x1.64 | 19% / 62% | monster curve |
| **kept:** that + act III +1 attack | **1.2 / 1.7 / 1.7 / 2.7%** | **x1.40, x1.01, x1.59** | **19% / 62%** | none |

So the final state: **`monster_attack_per_depth` back to 1.0** (still its own field, a float),
**the act II attack bumps removed**, the act III +1 kept; Health, ranks, rank damage and elite
chances as above. Final model, Normal: commons need 27 / 40 / 31 / 34 hits to kill the expected
build (Nightmare +10: 12 / 13 / 11 / 12; target >= 6), Easy stays at 0.5-0.8% a common. The
difficulty curve (boss threat) is now inside its targets everywhere (Easy x0.38-0.47, Hard
x1.76-1.92, Nightmare x2.83-3.37, +5 x3.12-3.84, +10 x4.26-5.43): 2A's armor fixed what flat armor
broke, as expected. Model flags (per monster, Normal): monster TTK 6, Elite 17, Epic 7, Legendary
6, Shiny 8 (baseline 24 / 43 / 34 / 34 / 35); "monster curve" and "rank ladder": 0.

Phase 2 baseline -> final (merged, model, every difficulty, the act's last normal floor; time to
kill · share of the hero's Health lost killing one face to face · commons: hits to kill the hero):

| Act | Difficulty | Common | Elite | Epic | Legendary | Shiny |
|---|---|---|---|---|---|---|
| 1 | easy | 0.2→**0.4** s · 0.3→**0.5**% · 64→**43** hits | 0.7→**1.1** s · 0.8→**1.7**% | - | - | 0.7→**1.4** s · 0.8→**1.7**% |
| 1 | normal | 0.4→**0.6** s · 0.8→**1.2**% · 32→**27** hits | 0.9→**1.6** s · 2.5→**4.7**% | - | - | 1.1→**1.9** s · 2.5→**4.1**% |
| 1 | hard | 0.5→**0.7** s · 1.7→**2.1**% · 21→**21** hits | 1.2→**2.1** s · 4.8→**8.4**% | - | - | 1.4→**2.5** s · 5.1→**7.3**% |
| 1 | nightmare | 0.6→**1.0** s · 3.5→**4.3**% · 14→**14** hits | 1.6→**2.8** s · 10.1→**15.8**% | - | - | 1.8→**3.3** s · 10.5→**14.9**% |
| 1 | nightmare+5 | 0.7→**1.1** s · 4.5→**5.6**% · 13→**13** hits | 1.9→**3.2** s · 12.8→**22.0**% | - | - | 2.0→**3.8** s · 13.6→**19.4**% |
| 1 | nightmare+10 | 0.8→**1.3** s · 5.8→**7.2**% · 12→**12** hits | 2.1→**3.7** s · 16.2→**27.8**% | - | - | 2.3→**4.4** s · 17.5→**24.8**% |
| 2 | easy | 0.2→**0.6** s · 0.1→**0.5**% · 200→**95** hits | 0.7→**2.3** s · 0.3→**2.7**% | 1.0→**4.1** s · 0.5→**5.8**% | 1.7→**6.3** s · 1.1→**9.5**% | 0.8→**2.3** s · 0.3→**1.8**% |
| 2 | normal | 0.4→**0.8** s · 0.3→**1.7**% · 100→**40** hits | 1.0→**3.3** s · 0.9→**7.7**% | 1.5→**5.8** s · 1.5→**18.1**% | 2.4→**9.1** s · 2.5→**28.6**% | 1.1→**3.3** s · 0.9→**6.6**% |
| 2 | hard | 0.5→**1.1** s · 1.0→**3.4**% · 40→**26** hits | 1.3→**4.3** s · 2.8→**15.6**% | 1.9→**7.6** s · 4.5→**33.1**% | 3.1→**11.8** s · 7.8→**57.5**% | 1.4→**4.2** s · 3.1→**13.3**% |
| 2 | nightmare | 0.6→**1.4** s · 2.4→**6.6**% · 22→**18** hits | 1.7→**5.7** s · 6.5→**31.7**% | 2.5→**10.4** s · 10.4→**63.0**% | 4.0→**15.6** s · 17.9→**113.5**% | 1.8→**5.5** s · 7.2→**25.5**% |
| 2 | nightmare+5 | 0.7→**1.6** s · 3.3→**8.7**% · 18→**15** hits | 1.9→**6.6** s · 8.9→**40.1**% | 2.9→**12.1** s · 14.2→**80.5**% | 4.7→**18.0** s · 24.2→**148.2**% | 2.1→**6.4** s · 9.9→**34.0**% |
| 2 | nightmare+10 | 0.8→**1.9** s · 4.6→**11.6**% · 15→**13** hits | 2.2→**7.6** s · 12.4→**53.2**% | 3.4→**14.1** s · 19.8→**105.8**% | 5.4→**20.7** s · 33.5→**190.2**% | 2.5→**7.3** s · 13.7→**45.4**% |
| 3 | easy | 0.4→**0.6** s · 0.1→**0.5**% · 229→**62** hits | 0.9→**3.0** s · 0.3→**3.5**% | 1.4→**5.3** s · 0.6→**7.5**% | 2.1→**7.3** s · 1.2→**12.6**% | 1.1→**2.8** s · 0.3→**2.2**% |
| 3 | normal | 0.5→**0.9** s · 0.3→**1.7**% · 108→**31** hits | 1.4→**4.3** s · 0.9→**11.3**% | 1.9→**7.7** s · 1.8→**21.8**% | 3.0→**10.6** s · 3.3→**37.1**% | 1.5→**3.9** s · 0.9→**7.4**% |
| 3 | hard | 0.7→**1.2** s · 1.1→**3.4**% · 38→**20** hits | 1.8→**5.7** s · 3.2→**22.1**% | 2.6→**10.0** s · 5.4→**45.4**% | 4.0→**14.1** s · 8.7→**71.2**% | 2.0→**5.1** s · 3.4→**15.0**% |
| 3 | nightmare | 0.9→**1.5** s · 3.1→**7.0**% · 19→**14** hits | 2.3→**7.5** s · 8.6→**45.0**% | 3.4→**13.2** s · 13.5→**89.1**% | 5.2→**18.8** s · 22.0→**136.7**% | 2.6→**6.7** s · 9.3→**30.6**% |
| 3 | nightmare+5 | 1.0→**1.8** s · 4.1→**9.2**% · 16→**12** hits | 2.6→**8.7** s · 11.5→**57.9**% | 3.8→**15.3** s · 18.4→**116.2**% | 6.0→**21.6** s · 29.3→**176.2**% | 3.0→**7.7** s · 12.4→**39.8**% |
| 3 | nightmare+10 | 1.1→**2.0** s · 5.5→**12.0**% · 14→**11** hits | 3.0→**10.0** s · 15.7→**76.4**% | 4.4→**17.7** s · 24.9→**146.9**% | 6.9→**25.0** s · 39.8→**233.2**% | 3.4→**8.9** s · 16.6→**52.4**% |
| 4 | easy | 0.5→**0.8** s · 0.1→**0.8**% · 285→**72** hits | 1.3→**4.9** s · 0.4→**6.0**% | 1.9→**8.4** s · 0.8→**12.5**% | 2.7→**11.0** s · 1.7→**19.4**% | 1.4→**3.9** s · 0.3→**3.9**% |
| 4 | normal | 0.7→**1.1** s · 0.4→**2.7**% · 123→**34** hits | 1.8→**7.0** s · 1.3→**18.8**% | 2.7→**12.1** s · 2.3→**38.1**% | 3.9→**15.9** s · 3.6→**62.1**% | 2.0→**5.5** s · 1.3→**13.0**% |
| 4 | hard | 0.9→**1.5** s · 1.7→**5.4**% · 41→**22** hits | 2.4→**9.1** s · 4.8→**38.2**% | 3.6→**15.6** s · 7.5→**76.3**% | 5.2→**21.1** s · 12.4→**121.9**% | 2.6→**7.2** s · 5.0→**25.7**% |
| 4 | nightmare | 1.1→**2.0** s · 4.8→**10.8**% · 20→**15** hits | 3.1→**11.8** s · 12.8→**76.1**% | 4.6→**20.4** s · 20.8→**149.3**% | 6.8→**28.7** s · 33.6→**240.0**% | 3.4→**9.4** s · 14.4→**51.9**% |
| 4 | nightmare+5 | 1.3→**2.3** s · 6.6→**14.2**% · 17→**13** hits | 3.6→**13.7** s · 17.8→**99.6**% | 5.3→**23.6** s · 29.2→**195.1**% | 8.0→**33.5** s · 46.5→**313.0**% | 3.9→**10.8** s · 19.8→**68.1**% |
| 4 | nightmare+10 | 1.5→**2.6** s · 9.1→**18.9**% · 14→**12** hits | 4.1→**15.9** s · 25.0→**131.6**% | 6.1→**27.4** s · 41.1→**261.8**% | 9.2→**39.1** s · 64.4→**408.8**% | 4.5→**12.4** s · 27.2→**90.5**% |

Engine (pack mode, merged final data, Normal and Hard, seed 1, medians), baseline -> final:

| Act | Ranked + 2 commons, face-tank: Elite / Epic / Legendary / Shiny TTK | Rooms, expected build, kite: Health lost / clear | Face-tank |
|---|---|---|---|
| I Normal | 0.8 -> **1.1** / 1.8 -> **3.2** / 3.6 -> **5.0** / 0.8 -> **1.1** s | 0% -> 0% / 2.1 -> 2.3 s | 2% -> 2% |
| II Normal | 0.6 -> **2.5** / 0.1 -> **4.0** / 1.2 -> **5.1** / 0.9 -> **2.7** s | 0% -> 0% / 4.6 -> 5.1 s | 0% -> 0% |
| III Normal | 1.5 -> **5.2** / 1.8 -> **7.4** / 3.0 -> **8.9** / 2.2 -> **4.9** s | 0% -> 0% / 14.9 -> 11.1 s | 0% -> 2% |
| IV Normal | 1.8 -> **6.0** / 1.8 -> **9.0** / 3.0 -> **12.0** / 1.2 -> **5.4** s | 0% -> 0% / 9.3 -> 18.9 s | 1% -> 8% |
| III Hard | 0.2 -> **6.3** / 4.1 -> **14.1** / 4.1 -> **16.2** / 0.4 -> **6.0** s | 0% -> 0% / 24.7 -> 13.3 s | 1% -> 14% |
| IV Hard | 0.3 -> **6.9** / 3.1 -> **9.6** / 3.6 -> **13.8** / 0.9 -> **5.7** s | 0% -> 3% / 17.4 -> 22.2 s | 8% -> 24% |

Rooms are not too deadly after the merge: the kite bot loses 0-3% a room, the face-tank bot
2-8% on Normal and 14-24% on Hard (target <= 35% with the kite bot, every room clears in <= 23 s).
Ranked rooms face-tanked cost 0-27% on Normal, up to 49% (act III Hard Legendary). Pack flags:
monster TTK 31 -> 21, Elite 23 -> 16, Epic 3 -> 3, Legendary 3 -> 1, Shiny 2 -> 2 (the engine's
"time from first hurt" is noisy: a 0.1 s value is a monster slain by the hit that first hurt it).
Act IV with the kite bot and the slow Greatsword still drags on ranked rooms (22-38 s or the
timeout): watch it in play; `hp_multiplier_per_depth` is the knob.

After the merge, the balance suite's "duel: expected_a1 kite wins" **passes** again (King Slime:
kite win in 56 s, hero min 76%, with 2A's bot and armor); Giant Frog's kite fight is identical to
2A's own measure (loss, boss 22%), so the adds' new Health doesn't decide it. One new balance-suite
failure outside this pass's scope: "marginal: too weak: perk vampirism x3 (act 2) 0.02x median"
(phase 2C's area; vampirism heals on kills, and the lab's rooms now take longer to clear).
Regular suites on the merged branch: unit,title 4756 checks, game 901, tutorial 273: 0 failed.

## 2026-10-20 - Phase 2A: bosses, sustain, armor, the kite bot

Measured with the arena (`--mode=arena --plain --no-weapons`, seed 1, Normal and Hard, every
boss x the builds of its act x both bots) and the model, against the phase 2 baseline above.
The other two phase 2 passes (B: monsters, ranks, elites, difficulties; C: perks, runes,
affixes, weapons, shrine, economy) ran in parallel: their data is not in these numbers.

### What was wrong (root causes)

- **The kite bot played badly**, so "the kite loses" meant little. It backed off at the *start* of
  every wind-up or cast within 220 px (a melee hero stopped hitting for most of the fight: a
  third to a quarter of the face-tank's damage per second), rolled *early* (at 55% of a wind-up:
  the 0.23 s of invulnerability ended before the blow), rolled straight into pits (falls cost 15%
  of max Health each: up to 163 of 216 damage taken against the Weeping Spirit) and never saw the
  arena's warnings or traps.
- **Sustain in boss fights**: the budget refilled 2% of max Health a second and started full (20%):
  from act III one Leech rune paid back 66-100% of the damage taken.
- **Flat armor** (`Combat.mitigate`: damage minus armor, at least 1): every act IV monster hit a
  36-armor build for 1, act IV bosses' blows did 7 to the expected build (13 armor), and a boss's
  shockwave (a trap-sized blast, `dungeon_damage(4, 0.6)`) did 1-2 to anyone with armor: the
  boss' answer to face-tanking cost nothing.

### What changed and why

| Change | Before | After | Where |
|---|---|---|---|
| Kite bot | see above | hits whenever in reach (attacks don't root the hero); steps out of swings, skill circles (`telegraph_radius`, damage areas), off leap/rush lines, sideways from shots heading its way, off blinking arena cells and live traps; rolls only when the blow lands within the roll's invulnerability (swings and circles at 75%, casts of shots at 85% when close, shots under 0.15 s away, shockwave rings 0.25 s after they appear) and only where the whole roll (40-160 px) is solid ground; holds the hit that would set off a shockwave when its roll isn't ready | tools/balance/balance_bot.gd |
| Armor rule | `max(1, A - D)` | `max(1, round(A x A / (A + D)))` (`Combat.ARMOR_WEIGHT` = 1): about D points off a big hit (35 vs 5: 31), half of a hit the armor's size (20 vs 20: 10), never harmless (20 vs 36: 7) | src/combat/combat.gd; the tools' model, lab and compound checks call it; the bestiary's Armor line now says "a 10-damage hit does X, a 30-damage hit Y" |
| Boss-fight sustain | refill x0.5 (2% of max Health/s), budget 20% | refill x0.1 (**0.4%/s**), budget x0.25 (**5%**) while `World.is_boss_fight()` (`SustainRules.boss_fight_rate`, new `boss_fight_burst`) | data/dungeon/sustain.tres, sustain_rules.gd, sustain_meter.gd |
| Boss shockwave | `dungeon_damage(4, 0.6)` (6-14 before armor) | new `BossDef.shockwave_power` (share of the boss' power), **1.0** on every boss (11-29 on Normal): the face-tank takes it every few seconds, the kite rolls through or holds | boss_def.gd, monster.gd, data/monsters/bosses/* |
| Act IV bosses | Gilded Hoarder, Sun Wraith | +2 attack (base stats): act IV boss threat x0.93 -> x0.97 of act III (model) | gilded_hoarder.tres, sun_wraith.tres |
| Red Samurai | Flame Arc x1.6 skill power (37 DPS in its last phase, the highest of act III) | x1.3 (both versions) | data/skills/boss/flame_arc*.tres |
| Giant Frog | spit x0.6 every 3 s, leap x1.2, 800 Health | spit x0.5 (cooldown 3.5 s, fierce 3 s), leap x1.0 (both versions), 700 Health (act I's alternate was harder than act II bosses for the kite) | giant_frog.tres, poison_spit*.tres, frog_leap*.tres |
| Azure Wyrm | 1100 Health, Frost Breath and Hailstorm x0.5 (the kite lost it in every run, 12-26% left) | 1000 Health, x0.42 (all four skill files) | azure_wyrm.tres, frost_breath*.tres, hailstorm*.tres |

Tools: `--plain` and `--no-weapons` for targeted arena runs; each fight now logs the damage taken
by kind (melee, skill, shockwave, adds, ticks, traps, falls).

### Results

Model, boss threat act over act (expected builds, target x0.9-1.6): Normal x0.79 / x0.99 / x0.62
-> **x1.06 / x1.05 / x0.97**; Hard x0.90 / x1.10 / x0.70 -> x1.08 / x1.12 / x0.97 (the model doesn't
count shockwaves). "model: face-tank wins", "model: heal share" and "model: act curve" pass.

Summary, expected builds, plain bosses: the face-tank wins **0 of 10 on Normal (was 5) and 0 of
10 on Hard (was 3)**; heal share in boss fights 6-40% (was up to 100%; a single Leech rune heals
0.4% of max Health a second against a boss). The kite wins 6 of 10 on Normal (as before, but
without the Leech carry: before, its act III-IV wins healed 66-97% of the damage taken), 3 of 10
on Hard; its damage per second roughly doubled (act II: 14-24 -> 30-33). Its Normal losses are
close: Giant Frog 8-27% left, Azure Wyrm 5% (after its change), Red Samurai 0% (died with it),
Gilded Hoarder 3% (165 of its 365 damage from falls: a bot weakness; the earlier run won at 37%).

Expected builds vs every boss (engine; F face-tank, K kite; W win with the hero's lowest health,
L loss with the boss' health left; heal = healed / damage taken). Before = the baseline run; after
= the final rules and bot, before the last Giant Frog and Azure Wyrm changes (measured
separately below):

| Boss | Build | Diff | Bot | Before | After |
|---|---|---|---|---|---|
| king_slime | expected_a1 | hard | F | L 17s (boss 65%) | L 15s (boss 66%) |
| king_slime | expected_a1 | hard | K | L 72s (boss 15%) | W 68s (min 4%) |
| king_slime | expected_a1 | normal | F | L 23s (boss 27%) | L 19s (boss 33%) |
| king_slime | expected_a1 | normal | K | W 84s (min 45%) | W 60s (min 62%) |
| giant_frog | expected_a1 | hard | F | L 15s (boss 65%) | L 12s (boss 68%) |
| giant_frog | expected_a1 | hard | K | L 39s (boss 54%) | L 28s (boss 60%) |
| giant_frog | expected_a1 | normal | F | L 19s (boss 43%) | L 18s (boss 41%) |
| giant_frog | expected_a1 | normal | K | L 34s (boss 47%) | L 43s (boss 27%) |
| demon_cyclops | expected_a2 | hard | F | L 21s (boss 58%) | L 16s (boss 65%) |
| demon_cyclops | expected_a2 | hard | K | L 91s (boss 34%) | L 84s (boss 15%) |
| demon_cyclops | expected_a2 | normal | F | L 36s (boss 3%) | L 24s (boss 34%) |
| demon_cyclops | expected_a2 | normal | K | L 99s (boss 23%) | W 87s (min 10%) heal 6% |
| weeping_spirit | expected_a2 | hard | F | L 29s (boss 33%) | L 22s (boss 45%) |
| weeping_spirit | expected_a2 | hard | K | L 140s (boss 15%) | W 82s (min 19%) heal 6% |
| weeping_spirit | expected_a2 | normal | F | W 38s (min 32%) heal 7% | L 27s (boss 17%) |
| weeping_spirit | expected_a2 | normal | K | L 118s (boss 25%) | W 75s (min 57%) heal 12% |
| azure_wyrm | expected_a2 | hard | F | L 19s (boss 62%) | L 15s (boss 68%) |
| azure_wyrm | expected_a2 | hard | K | L 49s (boss 55%) | L 63s (boss 31%) |
| azure_wyrm | expected_a2 | normal | F | L 29s (boss 21%) | L 26s (boss 21%) |
| azure_wyrm | expected_a2 | normal | K | L 72s (boss 24%) | L 57s (boss 26%) |
| crimson_tengu | expected_a3 | hard | F | L 41s (boss 3%) heal 48% | L 17s (boss 64%) heal 10% |
| crimson_tengu | expected_a3 | hard | K | W 103s (min 59%) heal 83% | L 45s (boss 23%) heal 11% |
| crimson_tengu | expected_a3 | normal | F | W 40s (min 78%) heal 81% | L 28s (boss 19%) heal 13% |
| crimson_tengu | expected_a3 | normal | K | W 90s (min 62%) heal 73% | W 67s (min 36%) heal 28% |
| red_samurai | expected_a3 | hard | F | L 21s (boss 49%) heal 34% | L 14s (boss 65%) heal 8% |
| red_samurai | expected_a3 | hard | K | L 80s (boss 4%) heal 58% | L 34s (boss 49%) heal 13% |
| red_samurai | expected_a3 | normal | F | L 27s (boss 24%) heal 38% | L 19s (boss 39%) heal 9% |
| red_samurai | expected_a3 | normal | K | W 77s (min 24%) heal 66% | L 56s (boss 0%) heal 15% |
| jade_wyrm | expected_a3 | hard | F | W 40s (min 25%) heal 57% | L 19s (boss 51%) heal 10% |
| jade_wyrm | expected_a3 | hard | K | L 90s (boss 10%) heal 58% | L 49s (boss 30%) heal 13% |
| jade_wyrm | expected_a3 | normal | F | W 38s (min 80%) heal 82% | L 26s (boss 16%) heal 12% |
| jade_wyrm | expected_a3 | normal | K | W 81s (min 33%) heal 67% | W 57s (min 2%) heal 20% |
| gilded_hoarder | expected_a4 | hard | F | W 71s (min 7%) heal 62% | L 24s (boss 67%) heal 11% |
| gilded_hoarder | expected_a4 | hard | K | W 99s (min 4%) heal 66% | L 78s (boss 17%) heal 24% |
| gilded_hoarder | expected_a4 | normal | F | W 52s (min 83%) heal 100% | L 38s (boss 25%) heal 15% |
| gilded_hoarder | expected_a4 | normal | K | W 97s (min 81%) heal 97% | L 59s (boss 3%) heal 17% |
| sun_wraith | expected_a4 | hard | F | W 51s (min 37%) heal 64% | L 22s (boss 62%) heal 10% |
| sun_wraith | expected_a4 | hard | K | W 79s (min 85%) heal 100% | W 60s (min 24%) heal 18% |
| sun_wraith | expected_a4 | normal | F | W 44s (min 89%) heal 96% | L 26s (boss 42%) heal 11% |
| sun_wraith | expected_a4 | normal | K | W 62s (min 76%) heal 96% | W 62s (min 63%) heal 40% |

After the last Giant Frog and Azure Wyrm changes (Frog: leap x1.0 too, 700 Health, spit every 3.5 s; Wyrm: 1000 Health instead of 1100, Frost Breath and Hailstorm x0.42 instead of x0.5), same seed:

| Boss | Build | Diff | Bot | Before | After |
|---|---|---|---|---|---|
| giant_frog | expected_a1 | hard | F | L 15s (boss 65%) | L 12s (boss 65%) |
| giant_frog | expected_a1 | hard | K | L 39s (boss 54%) | L 43s (boss 26%) |
| giant_frog | expected_a1 | normal | F | L 19s (boss 43%) | L 16s (boss 37%) |
| giant_frog | expected_a1 | normal | K | L 34s (boss 47%) | L 36s (boss 22%) |
| azure_wyrm | expected_a2 | hard | F | L 19s (boss 62%) | L 17s (boss 58%) |
| azure_wyrm | expected_a2 | hard | K | L 49s (boss 55%) | L 69s (boss 13%) |
| azure_wyrm | expected_a2 | normal | F | L 29s (boss 21%) | L 29s (boss 12%) |
| azure_wyrm | expected_a2 | normal | K | L 72s (boss 24%) | L 67s (boss 5%) |

Degenerate builds (engine, measured before the Red Samurai / Giant Frog changes and the bot's
hold-the-last-hit refinement):

| Boss | Build | Diff | Bot | Before | After |
|---|---|---|---|---|---|
| king_slime | degenerate_attack_speed_a1 | hard | F | L 14s (boss 49%) | L 14s (boss 54%) |
| king_slime | degenerate_attack_speed_a1 | hard | K | L 66s (boss 21%) | L 67s (boss 8%) |
| king_slime | degenerate_attack_speed_a1 | normal | F | L 17s (boss 33%) | L 14s (boss 32%) |
| king_slime | degenerate_attack_speed_a1 | normal | K | L 62s (boss 10%) | W 56s (min 33%) |
| king_slime | degenerate_lifesteal_a1 | hard | F | L 25s (boss 47%) heal 38% | L 15s (boss 65%) heal 9% |
| king_slime | degenerate_lifesteal_a1 | hard | K | L 97s (boss 5%) heal 59% | W 66s (min 22%) heal 26% |
| king_slime | degenerate_lifesteal_a1 | normal | F | L 35s (boss 2%) heal 44% | L 23s (boss 33%) heal 11% |
| king_slime | degenerate_lifesteal_a1 | normal | K | W 66s (min 73%) heal 89% | W 49s (min 2%) heal 16% |
| giant_frog | degenerate_attack_speed_a1 | hard | F | L 12s (boss 49%) | L 9s (boss 63%) |
| giant_frog | degenerate_attack_speed_a1 | hard | K | L 23s (boss 66%) | L 31s (boss 33%) |
| giant_frog | degenerate_attack_speed_a1 | normal | F | L 13s (boss 36%) | L 12s (boss 32%) |
| giant_frog | degenerate_attack_speed_a1 | normal | K | L 30s (boss 51%) | L 30s (boss 28%) |
| giant_frog | degenerate_lifesteal_a1 | hard | F | L 22s (boss 42%) heal 37% | L 13s (boss 66%) heal 9% |
| giant_frog | degenerate_lifesteal_a1 | hard | K | L 51s (boss 34%) heal 50% | L 45s (boss 31%) heal 16% |
| giant_frog | degenerate_lifesteal_a1 | normal | F | L 24s (boss 30%) heal 37% | L 17s (boss 45%) heal 10% |
| giant_frog | degenerate_lifesteal_a1 | normal | K | L 60s (boss 25%) heal 50% | W 64s (min 25%) heal 27% |
| demon_cyclops | degenerate_crit_a2 | hard | F | W 9s (min 25%) | W 8s (min 19%) |
| demon_cyclops | degenerate_crit_a2 | hard | K | W 18s (min 54%) | W 26s (min 6%) |
| demon_cyclops | degenerate_crit_a2 | normal | F | W 8s (min 39%) | W 8s (min 12%) |
| demon_cyclops | degenerate_crit_a2 | normal | K | L 27s (boss 25%) | L 25s (boss 0%) |
| demon_cyclops | degenerate_lifesteal_a2 | hard | F | L 22s (boss 52%) heal 37% | L 13s (boss 72%) heal 8% |
| demon_cyclops | degenerate_lifesteal_a2 | hard | K | W 124s (min 5%) heal 66% | L 76s (boss 21%) heal 23% |
| demon_cyclops | degenerate_lifesteal_a2 | normal | F | L 24s (boss 38%) heal 38% | L 16s (boss 54%) heal 9% |
| demon_cyclops | degenerate_lifesteal_a2 | normal | K | W 98s (min 10%) heal 55% | L 62s (boss 10%) heal 17% |
| weeping_spirit | degenerate_crit_a2 | hard | F | W 8s (min 36%) | W 7s (min 3%) |
| weeping_spirit | degenerate_crit_a2 | hard | K | W 19s (min 75%) | W 18s (min 75%) |
| weeping_spirit | degenerate_crit_a2 | normal | F | W 7s (min 43%) | W 8s (min 39%) |
| weeping_spirit | degenerate_crit_a2 | normal | K | W 16s (min 73%) | W 20s (min 78%) |
| weeping_spirit | degenerate_lifesteal_a2 | hard | F | L 28s (boss 32%) heal 40% | L 17s (boss 57%) heal 9% |
| weeping_spirit | degenerate_lifesteal_a2 | hard | K | W 95s (min 30%) heal 70% | W 66s (min 44%) heal 34% |
| weeping_spirit | degenerate_lifesteal_a2 | normal | F | W 31s (min 31%) heal 53% | L 18s (boss 41%) heal 10% |
| weeping_spirit | degenerate_lifesteal_a2 | normal | K | W 88s (min 87%) heal 100% | W 52s (min 51%) heal 27% |
| azure_wyrm | degenerate_crit_a2 | hard | F | W 10s (min 32%) | L 10s (boss 0%) |
| azure_wyrm | degenerate_crit_a2 | hard | K | L 22s (boss 32%) | L 20s (boss 24%) |
| azure_wyrm | degenerate_crit_a2 | normal | F | W 7s (min 47%) | W 7s (min 30%) |
| azure_wyrm | degenerate_crit_a2 | normal | K | L 25s (boss 6%) | W 15s (min 46%) |
| azure_wyrm | degenerate_lifesteal_a2 | hard | F | L 19s (boss 65%) heal 34% | L 13s (boss 69%) heal 8% |
| azure_wyrm | degenerate_lifesteal_a2 | hard | K | L 61s (boss 42%) heal 54% | L 47s (boss 45%) heal 15% |
| azure_wyrm | degenerate_lifesteal_a2 | normal | F | L 31s (boss 15%) heal 43% | L 18s (boss 51%) heal 10% |
| azure_wyrm | degenerate_lifesteal_a2 | normal | K | L 107s (boss 20%) heal 64% | L 52s (boss 30%) heal 19% |
| crimson_tengu | degenerate_burn_a3 | hard | F | L 22s (boss 38%) heal 32% | L 19s (boss 51%) heal 31% |
| crimson_tengu | degenerate_burn_a3 | hard | K | L 65s (boss 25%) heal 32% | L 54s (boss 8%) heal 31% |
| crimson_tengu | degenerate_burn_a3 | normal | F | W 27s (min 5%) heal 41% | L 23s (boss 15%) heal 31% |
| crimson_tengu | degenerate_burn_a3 | normal | K | L 66s (boss 11%) heal 31% | W 62s (min 6%) heal 46% |
| crimson_tengu | degenerate_lifesteal_a3 | hard | F | L 25s (boss 59%) heal 39% | L 13s (boss 78%) heal 8% |
| crimson_tengu | degenerate_lifesteal_a3 | hard | K | L 113s (boss 16%) heal 64% | L 82s (boss 23%) heal 23% |
| crimson_tengu | degenerate_lifesteal_a3 | normal | F | L 40s (boss 7%) heal 48% | L 19s (boss 62%) heal 10% |
| crimson_tengu | degenerate_lifesteal_a3 | normal | K | L 101s (boss 26%) heal 50% | W 76s (min 42%) heal 33% |
| crimson_tengu | degenerate_skills_a3 | hard | F | L 20s (boss 22%) heal 34% | L 11s (boss 60%) heal 7% |
| crimson_tengu | degenerate_skills_a3 | hard | K | W 28s (min 96%) heal 100% | W 34s (min 78%) heal 45% |
| crimson_tengu | degenerate_skills_a3 | normal | F | W 18s (min 72%) heal 68% | W 15s (min 6%) heal 9% |
| crimson_tengu | degenerate_skills_a3 | normal | K | L 19s (boss 29%) heal 13% | W 15s (min 87%) heal 32% |
| red_samurai | degenerate_burn_a3 | hard | F | L 15s (boss 66%) heal 28% | L 13s (boss 70%) heal 31% |
| red_samurai | degenerate_burn_a3 | hard | K | L 36s (boss 70%) heal 25% | L 25s (boss 60%) heal 26% |
| red_samurai | degenerate_burn_a3 | normal | F | L 22s (boss 33%) heal 32% | L 18s (boss 39%) heal 30% |
| red_samurai | degenerate_burn_a3 | normal | K | L 38s (boss 32%) heal 29% | L 40s (boss 26%) heal 30% |
| red_samurai | degenerate_lifesteal_a3 | hard | F | L 17s (boss 68%) heal 33% | L 12s (boss 79%) heal 6% |
| red_samurai | degenerate_lifesteal_a3 | hard | K | L 37s (boss 84%) heal 43% | L 37s (boss 72%) heal 8% |
| red_samurai | degenerate_lifesteal_a3 | normal | F | L 26s (boss 52%) heal 40% | L 12s (boss 75%) heal 8% |
| red_samurai | degenerate_lifesteal_a3 | normal | K | L 66s (boss 41%) heal 55% | L 62s (boss 40%) heal 17% |
| red_samurai | degenerate_skills_a3 | hard | F | L 8s (boss 44%) heal 17% | L 7s (boss 43%) heal 5% |
| red_samurai | degenerate_skills_a3 | hard | K | W 24s (min 49%) heal 45% | W 18s (min 23%) heal 10% |
| red_samurai | degenerate_skills_a3 | normal | F | W 11s (min 40%) heal 39% | L 7s (boss 33%) heal 6% |
| red_samurai | degenerate_skills_a3 | normal | K | W 14s (min 84%) heal 94% | W 13s (min 11%) heal 8% |
| jade_wyrm | degenerate_burn_a3 | hard | F | L 22s (boss 43%) heal 29% | L 17s (boss 56%) heal 32% |
| jade_wyrm | degenerate_burn_a3 | hard | K | L 48s (boss 54%) heal 30% | L 47s (boss 31%) heal 31% |
| jade_wyrm | degenerate_burn_a3 | normal | F | L 31s (boss 2%) heal 31% | L 23s (boss 23%) heal 33% |
| jade_wyrm | degenerate_burn_a3 | normal | K | L 64s (boss 31%) heal 30% | L 50s (boss 5%) heal 31% |
| jade_wyrm | degenerate_lifesteal_a3 | hard | F | L 25s (boss 62%) heal 39% | L 17s (boss 68%) heal 9% |
| jade_wyrm | degenerate_lifesteal_a3 | hard | K | L 90s (boss 39%) heal 64% | L 59s (boss 40%) heal 17% |
| jade_wyrm | degenerate_lifesteal_a3 | normal | F | L 33s (boss 30%) heal 42% | L 19s (boss 63%) heal 10% |
| jade_wyrm | degenerate_lifesteal_a3 | normal | K | L 45s (boss 63%) heal 48% | L 50s (boss 38%) heal 15% |
| jade_wyrm | degenerate_skills_a3 | hard | F | W 18s (min 15%) heal 38% | L 14s (boss 48%) heal 8% |
| jade_wyrm | degenerate_skills_a3 | hard | K | W 28s (min 22%) heal 49% | W 19s (min 39%) heal 14% |
| jade_wyrm | degenerate_skills_a3 | normal | F | W 12s (min 55%) heal 49% | W 10s (min 32%) heal 11% |
| jade_wyrm | degenerate_skills_a3 | normal | K | W 20s (min 80%) heal 81% | W 11s (min 71%) heal 17% |
| gilded_hoarder | degenerate_lifesteal_a4 | hard | F | L 32s (boss 49%) heal 44% | L 17s (boss 66%) heal 9% |
| gilded_hoarder | degenerate_lifesteal_a4 | hard | K | L 129s (boss 33%) heal 69% | L 68s (boss 21%) heal 21% |
| gilded_hoarder | degenerate_lifesteal_a4 | normal | F | W 43s (min 3%) heal 51% | L 21s (boss 57%) heal 11% |
| gilded_hoarder | degenerate_lifesteal_a4 | normal | K | W 117s (min 5%) heal 72% | W 94s (min 30%) heal 36% |
| gilded_hoarder | degenerate_max_health_a4 | hard | F | W 117s (min 93%) heal 98% | L 76s (boss 33%) heal 55% |
| gilded_hoarder | degenerate_max_health_a4 | hard | K | W 235s (min 2%) heal 82% | W 161s (min 4%) heal 69% |
| gilded_hoarder | degenerate_max_health_a4 | normal | F | W 88s (min 99%) heal 98% | W 81s (min 4%) heal 57% |
| gilded_hoarder | degenerate_max_health_a4 | normal | K | W 189s (min 77%) heal 100% | W 128s (min 34%) heal 35% |
| gilded_hoarder | degenerate_thorns_a4 | hard | F | W 143s (min 77%) heal 63% | L 112s (boss 16%) heal 67% |
| gilded_hoarder | degenerate_thorns_a4 | hard | K | T 240s (boss 33%) heal 96% | T 240s (boss 14%) heal 73% |
| gilded_hoarder | degenerate_thorns_a4 | normal | F | W 116s (min 98%) heal 97% | W 103s (min 1%) heal 75% |
| gilded_hoarder | degenerate_thorns_a4 | normal | K | T 240s (boss 26%) heal 96% | W 233s (min 15%) heal 64% |
| sun_wraith | degenerate_lifesteal_a4 | hard | F | L 30s (boss 50%) heal 42% | L 18s (boss 63%) heal 10% |
| sun_wraith | degenerate_lifesteal_a4 | hard | K | L 99s (boss 3%) heal 59% | W 58s (min 22%) heal 22% |
| sun_wraith | degenerate_lifesteal_a4 | normal | F | L 39s (boss 0%) heal 45% | L 22s (boss 43%) heal 11% |
| sun_wraith | degenerate_lifesteal_a4 | normal | K | W 89s (min 86%) heal 100% | W 59s (min 43%) heal 29% |
| sun_wraith | degenerate_max_health_a4 | hard | F | W 82s (min 97%) heal 100% | W 79s (min 0%) heal 56% |
| sun_wraith | degenerate_max_health_a4 | hard | K | W 142s (min 73%) heal 79% | W 110s (min 18%) heal 29% |
| sun_wraith | degenerate_max_health_a4 | normal | F | W 69s (min 99%) heal 100% | W 65s (min 2%) heal 60% |
| sun_wraith | degenerate_max_health_a4 | normal | K | W 128s (min 10%) heal 69% | W 83s (min 72%) heal 46% |
| sun_wraith | degenerate_thorns_a4 | hard | F | W 98s (min 95%) heal 100% | L 92s (boss 1%) heal 63% |
| sun_wraith | degenerate_thorns_a4 | hard | K | T 240s (boss 6%) heal 92% | W 141s (min 56%) heal 71% |
| sun_wraith | degenerate_thorns_a4 | normal | F | W 75s (min 96%) heal 96% | W 80s (min 1%) heal 71% |
| sun_wraith | degenerate_thorns_a4 | normal | K | W 220s (min 90%) heal 98% | W 142s (min 6%) heal 76% |

Family builds (act III, Normal): the face-tank won 7 of 15 fights before, **0 of 15** after; their
heal share is 7-33% (was up to 65%). The kite wins 7 of 15 (was 7), Red Samurai being the wall
(all five lost at 11-15%: measured before the Flame Arc change).

### For the other passes

- **B (monsters, elites, difficulties): the armor rule makes monsters hit armored heroes 2-3x
  harder.** Model, every act monster at its depths on Normal vs the act's expected build:

  | Act | Expected build's armor | Average monster hit (before -> after) | Average damage per second | Average hits to kill the hero |
  |---|---|---|---|---|
  | I | 2 | 3.7 -> 4.4 | 2.5 -> 2.9 | 38 -> 30 |
  | II | 7 | 2.2 -> 5.3 | 1.6 -> 3.8 | 116 -> 40 |
  | III | 10 | 3.6 -> 8.0 | 2.0 -> 4.5 | 88 -> 30 |
  | IV | 13 | 3.2 -> 9.2 | 1.9 -> 5.6 | 119 -> 32 |

  Hits to kill the hero are still far above the target (>= 6), and rooms cost more (the
  baseline's "monsters are harmless" finding). Measure before also buffing monster damage: the two
  compound. The rule also helps the hero's small hits against armored monsters (5 vs 4 armor:
  3 instead of 1) and burns against armor (6 vs 5: 3 instead of 1).
- **C (perks, runes, relics, weapons, shrine):** the remaining face-tank wins on Normal are the
  builds' own power, not the bosses': `degenerate_crit_a2` kills act II bosses in 7-8 s (82%
  crit, 3 Shatter runes), `degenerate_skills_a3` kills Crimson Tengu and Jade Wyrm in 10-15 s;
  `degenerate_max_health_a4` and `degenerate_thorns_a4` beat both act IV bosses at 1-4% of their
  health, carried by two revives (Phoenix Feather / cheat death: 187-386 Health) and the Templar
  Sword's Holy Shield and Smite (unlimited healing spells: 75-300 Health a fight). Frost Armor
  and the Fortified affix lose much of their value with diminishing armor (re-measure them).
  Kill-heal picks lose their boss-fight credit in the lab: "marginal: too weak" now flags
  Vampirism x3 in act II (0.15x the median) because its value came from sustain the boss-fight
  budget no longer pays.

### Open

- Ranked bosses (Epic, Legendary, Shiny) were not re-measured (the kite's damage per second
  roughly doubled, so their projected 100-191 s should drop: measure).
- The heal-share target (<= 25% of the damage taken) reads high for good kite fights: a kite that
  takes 50 damage and heals 20 is at 40% while healing 0.4% of its Health a second. Proposal:
  check it on face-tank fights (where it means "out-healing the boss") and judge kite fights by
  healing per second vs the boss' damage per second on that build.
- The kite still loses some Hard fights and a few Normal ones by a little; it still eats some
  shockwaves (side hits from chains, shards and thorns can finish the streak) and falls when
  thrown off. A lost kite fight is "hard for a careful player", not "impossible".
- Guard checks (balance suite, `_boss_guards`): a 36-armor build is hit for more than 1 by most
  act IV monsters; a minute of boss-fight sustain heals <= 35% of the act IV build's Health; the
  expected build face-tanking each act's boss on Normal loses with <= 25% healed. Unit tests: the
  armor formula (monotonic, never harmless, the examples above) and the boss-fight budget.

## 2026-10-20 - Phase 2 baseline measured (tools only, no game data changed)

`--mode=all --jobs=2`, seed 1, all six difficulties (39 min; the marginal values were run again
after a fix to their dummy rooms and merged with `--mode=merge`). 136 errors, 541 warnings.
Headline numbers (report.md and data.json of that run are the "before" of phase 2):

- **Face-tank beats bosses.** Expected builds on Normal: the face-tank bot wins 5 of 10 boss
  fights (Weeping Spirit, Crimson Tengu, Jade Wyrm, Gilded Hoarder, Sun Wraith); on Hard 3. From
  act III, one Leech rune heals 66-100% of the damage taken in a boss fight (Gilded Hoarder:
  236 of 236; target <= 25%): the boss-fight budget (2% of max Health a second = 5.7/s at act IV)
  is as large as the act IV boss' damage per second on that build (5.65/s).
- **Flat armor.** Builds with 32-36 armor face-tank act IV bosses at 93-99% health; every act IV
  monster hits them for 1. Frost Armor x4 (+252%) and the Fortified affix (+301%) are the top
  picks of act III.
- **Degenerate stacks.** Crit (Rapier, 82% crit, 3 Shatter runes) kills act II bosses in 7-10 s
  standing still; skills/cooldowns (3 Echo runes, Echo, Devotion) in 11-18 s with Devotion's heals.
- **Monsters are harmless to the expected builds.** Rooms cost 0-2% of max health on Normal;
  commons die in 0.2-0.9 s, elites in 0.5-1.5 s (target 3-10 s); act II commons hit for 1-3.
- **The curve.** Boss threat act II vs act I x0.79, act IV vs act III x0.62 (act IV easier than
  act III). The kite bot loses all three act II bosses on Normal (boss at 23-25%).
- **Economy.** A merchant visit's gold buys 4-23 average items on Normal (target 0.8-3); the whole
  shrine (3150 souls) takes ~13 average runs on Normal, ~3 on Nightmare.

Open: see FLAGS of that report; method in .claude/agents/game-balancer.md.

## 2026-10-20 - Phase 1: rules and themes (no simulator yet)

Everything here was done by reading the code and the data; nothing was measured on the arena yet
(tools/balance is being built). Phase 2 measures and tunes the numbers below.

### Sustain rules changed (code, unit and game tests)

The owner could beat a boss by standing still with Vampirism or a life-drain rune. Causes found:
lifesteal rounded every hit up (`roundi`: 8% of a 7-damage hit healed 1, i.e. 14%; every bolt of
the Arcane ring healed 1), on-kill heals fed on a boss's summoned adds, and nothing limited
stacking (three Leech runes, Vampirism, the Blood family and the Fury rune all added up).

| Rule | Before | After | Where |
|---|---|---|---|
| Ticks and secondary hits | lifesteal only skipped them because `Actor.take_hit` drops the attacker of secondary hits; Ice Shards' shards and the Arcane ring of bolts were direct hits (lifesteal, chain counters, Kindling...) | `LifestealPassive` ignores `is_tick` / `is_secondary` itself; shots fired by passives are secondary (`ProjectileSpec.secondary`, `ProjectileEffect.secondary`, set on the Arcane ring and on kill-burst shards) and get no extra projectiles from Multishot / Prism | lifesteal_passive.gd, projectile.gd, kill_burst_passive.gd, world.gd |
| Rounding | `roundi` per hit (and `maxi(1, ...)` per kill for the Blood family) | fractions add up per actor (`SustainMeter.pending`), paid in whole points; nothing banked at full health | src/combat/sustain_meter.gd |
| Shared limit | none | one budget for every heal from hits, kills and skills (Leech, Vampirism, Devotion, the Blood family, Fury, Vampiric gear): holds **20%** of max Health, refills **4% of max Health per second** | data/dungeon/sustain.tres (`SustainRules`, `DungeonConfig.sustain`) |
| Boss fights | same as anywhere | the budget refills at **x0.5** (2% of max Health per second) while `World.is_boss_fight()` | `SustainRules.boss_fight_rate` |
| Summons and adds | on-kill heals counted every kill | summoned monsters (`Monster.summoned`) and, during a boss fight, every non-boss kill feed no on-kill heal (`Actor.can_heal_killer()`); Fortune drops nothing from summons either (their own loot was already off) | monster.gd, heal_on_kill / bloodlust / loot_on_kill passives |

Monsters keep whole-point accumulation but no budget (a Vampiric elite heals as before).
Potions, springs, healing spells (Smite, Holy Light, Holy Shield), the Easy difficulty's heal on a
new floor and the level-up full heal are not limited: they are deliberate, scarce or between
fights.

What it means for a 100-Health hero: up to 20 Health at once (a pack of 3 slain together with
Vampirism 3 still heals fully), then 4 per second; 2 per second against a boss. One Leech rune on
a katana (9 damage, 2.6 hits a second = 2.3 Health a second) is never cut against packs; against
a boss with 5 Armor (about 5 damage a hit, 1.3 a second) it is under the boss-fight limit too.
Three Leech runes, or Leech + Vampirism + Blood, hit the limit and stop there.

Leech: 8% -> **10%** (exact now instead of rounded up: at act I damage the old 8% healed 12-14%
per hit, so 10% keeps the pack fantasy). Description: "Your hits heal 10% of the damage they deal
(burns and side effects don't)."

Guard tests: unit `_test_sustain` (fractions, full health, the burst, the rate, the boss-fight
rate, a minute of stacked sustain stays under the limit, a single Leech rune is never cut);
game `_test_sustain_in_game` (a burn tick and a secondary hit heal nothing, 6 small hits heal
floor(total x 10%), a shard fired by a perk heals nothing, three Leech runes on 40-damage hits
every frame for a second heal no more than the budget, a summoned rat's death heals nothing, an
ordinary one does); boss `_test_boss_fight` (adds, summoned or not, heal nothing; the boss does).

### Families: what moved and why

Fantasies (pillar 4): Inferno = fire, burning; Frost = cold, slows, freezing; Blood = health, life
drain, low-health power; Storm = lightning, chains, speed of the strike; Arcane = skills, spells,
cooldowns. Plain-number perks belong to no family.

Before (common perks | relics):

| Family | Perks | Misfits |
|---|---|---|
| Inferno | Ignite, Frenzy, Kindling, Blazing Roll \| War Banner, Phoenix Feather | Frenzy (pure attack speed), War Banner (damage, crit, attack speed) |
| Frost | Frostbite, Cold Snap, Ice Shards \| Guardian Ring | only 3 common perks; Guardian Ring a plain ward |
| Blood | Vampirism, Strength, Vitality, Thorns \| Executioner | Strength (pure damage), Thorns (nothing about blood) |
| Storm | Precision, Thunderclap, Shock Roll, Swiftness \| Multishot | Precision (crits, nothing electric), Multishot (extra projectiles) |
| Arcane | Arcane Focus, Arcane Power, Devotion, Echo \| Sage's Codex, Multishot | - |
| none | Fortune, Iron Skin | |

After:

| Family | Common perks | Relics | Members |
|---|---|---|---|
| Inferno | Ignite, Kindling, Blazing Roll, **Burning Thorns** | Phoenix Feather | 5 |
| Frost | Frostbite, Cold Snap, Ice Shards, **Frost Armor** | Guardian Ring | 5 |
| Blood | Vampirism, Vitality, **Bloodrage** (new), **Devotion** | Executioner | 5 |
| Storm | **Frenzy**, Thunderclap, Shock Roll, Swiftness | - | 4 |
| Arcane | Arcane Focus, Arcane Power, Devotion, Echo | Sage's Codex, Multishot | 6 |
| none | **Strength**, **Precision**, Fortune | **War Banner** | |

- **Frenzy** Inferno -> Storm: attack speed is the speed of the strike; its icon (flying kunai)
  already said so. Color changed to Storm's.
- **War Banner** Inferno -> none: damage, crit and attack speed are plain numbers.
- **Multishot** Storm + Arcane -> Arcane: more projectiles (fireballs included) is a spell thing,
  nothing electric about it.
- **Precision** Storm -> none: crit chance and an opening crit are plain numbers.
- **Strength** Blood -> none: +damage is not blood.
- **Thorns** Blood -> Inferno, light rework **Burning Thorns**: enemies that hit you up close take
  4 damage per level *and catch fire* (2 every 0.5 s for 3 s). `ThornsPassive.status` (optional).
  Same id, same icon (orange spikes), Inferno's color. The "of Thorns" affix and Spiked elites
  are unchanged.
- **Iron Skin** none -> Frost, light rework **Frost Armor**: +1 Armor per level, and getting hit
  releases a wave of cold that throws enemies back *and slows them 40%* (once every 3 s).
  `RetaliatePassive.status` (optional). Same id, same icon (an icy shield), Frost's color.
- **Devotion** Arcane -> Arcane + Blood: healing with every skill is both.
- **Bloodrage** (new Blood common, icon recolored from Strength's): below half Health, +15% damage
  per level (max 3). `BloodlustPassive` bonus is now per level (the family and the Fury rune have
  1 level: unchanged).
- **Guardian Ring** stays Frost: "Every floor starts with a shell of frost that soaks up 20
  damage" (the ward already breaks in icy sparkles).

Every family has 4 common perks; sizes 4-6 with relics. Guard test: unit `_test_family_themes`
(4+ common perks each, sizes within 2, the moves above, plain-number perks familyless, no
HP/ATK/DEF in perk, family or rune texts).

Runes (all kept in their family):

| Rune | Family | Effect | Note |
|---|---|---|---|
| Ember | Inferno | hits 35% chance to burn | fits |
| Pyre | Inferno | burning deaths burst into flames | fits |
| Rime | Frost | hits slow 20% | fits |
| Shatter | Frost | crits release a shockwave | **was a plain shockwave**: now it also slows 40% for 1.5 s (`CritShockwavePassive.status`) |
| Leech | Blood | hits heal 10% of their damage | was 8% rounded up per hit |
| Fury | Blood | below half +30% damage, kills heal 2% | fits |
| Spark | Storm | every 4th hit chains to 2 | fits |
| Gale | Storm | the roll throws a gust | wind of a storm: fits |
| Echo | Arcane | skills 12% ready again | fits |
| Prism | Arcane | +1 projectile | fits; strength to measure (below) |

Plain words: "HP" replaced by "Health" in Vampirism, Devotion, Executioner, Phoenix Feather, the
Blood family, the Fury rune and the Vampiric affix.

### Static sanity pass

Fixed (clear-cut):
- **Strength** max level 5 -> 3 (+10 -> +6 damage). It was the only damage perk with 5 levels,
  and flat damage is worth double against flat Armor (`Combat.mitigate`): at max, a katana at
  level 6 (10 power) against a boss with 5 Armor went from 5 to 15 damage a hit (x3), against
  +48% for Frenzy or +60% for Arcane Power at max. Now x2.2 there, +60% raw.

Listed for phase 2 (need measuring, not clear-cut from reading):
- **Multishot** (max 2: three shots) and **Prism** (stackable, 3 sockets on an Epic) on
  single-shot weapons (Bow, Spark Wand, Fireball): up to x3-x4 damage if the fan hits; depends on
  range and spread (12 degrees per projectile).
- **Ignite** max 3: a flat 6 every 0.5 s (12 a second per target, AoE weapons spread it) is huge
  in act I (a slime has 26 Health) and fades later (Armor eats ticks, no depth scaling).
- **Vitality** max 5: +75 Health when the hero starts at 60.
- **Executioner** +120% at max under 35% Health.
- **Echo** perk 45% at max + Echo runes (each rolls on its own) + of Echoes: cooldown loops.
- **Frost Armor** max 4: +4 Armor makes many weak hits deal 1 (`Combat.mitigate` minimum).
- **Swiftness** +75% for 1.5 s after a roll at max, with roll-on-cooldown builds.

### Open questions for phase 2 (to measure with the arena)

1. Face-tank vs kite for each boss with: no sustain, one Leech rune, three Leech runes,
   Vampirism 3 + Blood awake + Fury. Must the face-tank lose with every one? Is
   `boss_fight_rate` 0.5 needed, enough, or too harsh (try 1.0 / 0.5 / 0.25)?
2. Packs: healing by source per minute with the same builds: does `burst` 20% / `rate` 4% leave
   Leech and Vampirism feeling good (most kills fully paid)? Target: a single sustain source is
   never capped on packs.
3. Family strength side by side (time to clear a pack room, boss time) for the five awake
   families: the Arcane ring is now secondary (no Frost/Kindling bonus, no lifesteal, no extra
   projectiles from Multishot/Prism) - check Arcane didn't fall behind; Storm has no relic.
4. Strength (now 3 levels) against Frenzy, Arcane Power, Kindling at max, on fast (Rapier, Sai)
   and slow (War Hammer) weapons, against Armor 0 and 5.
5. Multishot / Prism on Bow, Spark Wand, Fireball: damage per second at 64, 128, 256 px.
6. Ignite and Ember at act I vs act IV (flat burns against depth scaling and Armor).
7. Bloodrage + Blood + Fury below half Health (+115%): with sustain limited, is staying low a
   real risk/reward or a trap?
8. Vampiric elites and Vampiric bosses (60% lifesteal, monsters have no budget): fight length.
9. Burning Thorns and Frost Armor against swarms (Swarm floors) and act IV damage.
10. The level-up full heal: can a fight be turned by XP mid-boss? (summons give none; adds that
   are not summoned do: check BossDef summons all set `summoned`.)

## 2026-10-26 — Kagari's first restoration

A one-time story quest awards 15 souls on manual return of floor-two evidence to the Veilleuse.
The village merchant's market and memorial lamps cost 5 and 8 souls once. These purchases have
no combat effect, and village objectives are absent from daily descents. Ordinary dungeon loot,
starting kit, shrine prices and death rules are unchanged.

## 2026-10-26 — Sayo's last verse

After Ren's request is returned, Sayo offers a second one-time rescue with evidence on floor 4.
Manual return awards 20 souls, wakes Sayo and clears the western roots. Both village requests
together award 35 souls once per profile; neither can be repeated for farming or collected on
a daily descent. No new combat benefits or shop prices are introduced.

## 2026-10-28 — The first minutes and help without judgement (decisions 0010, 0011)

Not measured with the balance tools (no target moves): numbers set from the decisions and the
audit's probes, to check on the S23.

- **First steps** (`data/tutorial/first_steps.tres`): on floor 1 of a profile's first three runs,
  the start room shelters the hero until he has walked 110 px and swung once (the audit: hit
  standing still in 7 starts of 33, 17-26 s in); the nearest room with monsters holds one Slime
  instead of its pack: 10 Health, no Armor (the kind: 28 and 1), 40 px/s (55), wind-up 0.8 s
  (0.5), recovery 0.6 s (0.4). The starting katana (5 Damage, ±15 %) kills it in 2 or 3 ordinary
  blows. Floor 1 of those runs has that room's other monsters fewer, so its seal asks a few kills
  less.
- **The Souls' Aid** (`data/player/assist.tres`): 20 % less damage taken, +2 % after each death
  with it on, 80 % at most (Hades' God Mode's numbers), after Armor, at least 1. Aided runs go on
  no leaderboard and set no record; their souls are those of their difficulty.
- **Lowering the difficulty in a run** keeps the remote settings the run began with; its souls
  are the lower difficulty's from then on (paid at the end on the difficulty the run ends on).
