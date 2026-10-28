# Skills, perks and builds

## Skills

There are no classes: what you hold and what you learn decides how you play.
The hero has **4 skill buttons**:

| Button | Skill | Comes from |
|---|---|---|
| 1 | Roll | always (`PlayerDef.innate_skills`) |
| 2, 3 | two weapon skills | the equipped weapon (`WeaponDef.skills`) |
| 4 | a learned spell | the last **skill tome** you read (`SkillTomeDef`) |

| Style | Weapons | Their skills |
|---|---|---|
| Warrior | Katana, Sai, Lance, Battle Axe, War Hammer, Pickaxe, Greatsword, Whip | Whirlwind, Iaido Dash, Flurry, Shadow Step, Piercing Thrust, Spear Throw, Cleave, Ground Slam, Fissure, Rock Spike, Sundering Blow, Lash, Battle Cry |
| Ninja | Ninjaku, Shuriken (3 stars a throw) | Kunai Fan, Shuriken Storm (a ring of 16), Shadow Step |
| Duelist | Rapier (fast, crits) | Riposte (leap back, then crits and speed), Piercing Thrust |
| Archer | Bow (arrows pierce one enemy) | Volley (5 arrows), Arrow Rain (4 hits on an area ahead) |
| Mage | Spark Wand, Frost Staff (its shards chill: 20% slower for 1 s), Ember Tome | Spark Nova, Arcane Bolt, Frost Nova (slow), Ice Shards (slow), Fireball, Fire Wave (burn) |
| Paladin | Templar Sword | Smite (damage + heal), Holy Shield (Armor + heal; both heal half during a boss fight) |

The weapon in the hero's hand is animated frame by frame with the attack. For weapons without a
hand-drawn sheet, the sheet is baked from the item sprite rotated around its handle (a swing,
a heavy swing, a thrust, a lash or an aim; 4 directions x 4 frames, `assets/weapons/attack/`).

### Blows in four directions

The hero walks in every direction, but his body, his armor and the weapon in his hand are drawn
facing down, up, left or right only; so are his **melee blows**, for the charm of it and so that
what is drawn over him follows his pose (`Blow`, `src/combat/blow.gd`). A blow aimed at the
closest enemy is struck toward the nearest of the four directions (`Blow.cardinal`, the rig's own
`direction_name`): the pose, the arc or the thrust's streak, the hammer's smash, the sheet or
claw a weapon plays and every effect of a charged blow are drawn that way, for the whole blow.

- **Diagonals stay hittable.** The blow's zone is its shape **swept from the cardinal to the
  exact aim** (never more than 45 degrees): it hits what it draws, plus everything the same blow
  aimed straight at the target would have hit. An arc of `arc_degrees` aimed 30 degrees off the
  right covers from its right edge to the far edge of the aimed arc; a circle `offset` ahead (a
  charged crescent, the hammer's slam) is slid from the cardinal to the aim; a thrust from where
  he stands (the lance's charged thrust) is turned likewise. So the narrowest blows (the whip's
  22 degrees, the rapier's 30) still run through the enemy they were aimed at on a diagonal, and
  no weapon misses what it hit before. A blow pressed against the body still hits whatever the
  angle.
- **What follows:** every melee weapon's basic blow (`Blow.of_weapon`), and the effects flagged
  `follows_facing` (`DamageAreaEffect`, `DashStrikeEffect` when it does not move): the
  blade blows of weapon skills (Cleave, Flurry's stabs, Sundering Blow) and of charged attacks
  (Moonless Cut, Crossed Shadows, Viper's Litany, Impaling Reach, Grave Sweep's sweep, Anvil
  Fall, Rockbreaker, Flaying Arc, Judgement). A unit check makes every hero's blade blow follow.
  A thrust's random jitter (Flurry's stabs) moves it sideways instead of turning it; Crossed
  Shadows' second cut is still turned up to 40 degrees (its cross).
- **What stays at the exact aim:** shots (arrows, bolts, stars, spells, thrown kunai and spears:
  they leave his hand toward the enemy, their trails follow their flight), spells placed far off
  (Thunder, Arrow Rain, Fissure, Rock Spike, Smite), blows all around (spins: Whirlwind, Lash,
  the axe's wheel, a body slam's 360 degrees), and rushes that move him (Iaido Dash, Piercing
  Thrust, Heartseeker, Grave Sweep's lunge): he dashes where he aims, moving being free, and the
  cut is drawn along his path. The charge's glow sits on the blade held in his pose for a melee
  weapon, where the shot will leave his hand for a ranged one.
- **Monsters** strike the same way with their melee weapons (their bodies are drawn in four
  directions too): the swing, claw or bite is drawn the way the body faces, and the red warning
  cone shows the swept zone (`Blow.cone`). Their skills' slashes (Tôma's wide slash and dashes)
  are still drawn at the exact aim.

### Charged attacks

Every hero's weapon has a **charged attack** (`WeaponDef.charged`, a `ChargedAttackDef` in
`data/skills/charged/<weapon id>.tres`; monsters' weapons have none). A **tap** on the attack
button is one basic attack, as before, aimed at the closest enemy. **Holding** it no longer
repeats the attack: past `PlayerDef.charge_delay` (0.22 s, so a tap never charges) the charge
fills over the weapon's `charge_time`, the hero moving at `move_speed_scale` of his speed and
winding up toward the closest enemy (or the way he walks). Full, it flashes and chimes
(`charge_full_sound`); **letting go** then unleashes the weapon's charged attack toward the
closest enemy; let go earlier, it is wasted. A roll (or any skill), a weapon swap or a fall cancels
the charge until the button is let go; being hit does not (holding the blow is the risk). A
charge is never saved. Keyboard (J / Space) and gamepad (X) hold the same way (`AttackCharge`,
`PlayerControls.update_attack`).

It is no skill: no cooldown of its own (the weapon swings again after its usual cooldown), no
"on skill" perk (Echo, Devotion, the Arcane ring). Its damage goes through its effects like a
skill's (`skill power x multiplier`); the multipliers are 2.2-3 times a basic hit (for a ranged
weapon, its `projectile_damage` x shots; a unit check holds the range), the price being the
charge and moving slower meanwhile. A weapon carrying an element unleashes it in that element
(docs/vfx.md, "Elemental attacks"). The weapon's card says "Hold: <name>. <what it does>".

| Weapon | Charged attack | What it does | x a basic hit | Charge (s) | Speed |
|---|---|---|---|---|---|
| Katana | Moonless Cut | a wide double crescent (200 degrees, radius 62) | 2.5 | 0.8 | 55% |
| Ninjaku | Crossed Shadows | two crossing cuts, 0.1 s apart (1.25 + 1.25) | 2.5 | 0.75 | 60% |
| Sai | Viper's Litany | three quick stabs, the last harder (0.8 + 0.8 + 1.0) | 2.6 | 0.75 | 60% |
| Rapier | Heartseeker | a short lunge (90) through every enemy in line | 2.6 | 0.75 | 60% |
| Lance | Impaling Reach | a long thrust (150) through every enemy in line, without moving | 2.6 | 0.9 | 55% |
| Battle Axe | Headsman's Wheel | a full spin, radius 80, heavy knockback | 2.4 | 1.1 | 50% |
| Greatsword | Grave Sweep | a lunge (110) cutting all in its way, then a wide sweep (1.6 + 1.1) | 2.7 | 1.1 | 50% |
| War Hammer | Anvil Fall | slams the ground ahead (44 out, clear of him): an earth blast, radius 85, hurls enemies | 2.7 | 1.15 | 45% |
| Pickaxe | Rockbreaker | the ground bursts in rubble ahead (radius 58) | 2.5 | 0.95 | 50% |
| Whip | Flaying Arc | a long crack far ahead (radius 70, 62 out) | 2.3 | 0.85 | 55% |
| Templar Sword | Judgement | a wide blessed crescent (holy) | 2.5 | 0.9 | 55% |
| Bow | Soulpiercer | a heavy arrow through every enemy in its path (2.3 vs 0.9) | 2.56 | 0.9 | 55% |
| Shuriken | Bladed Gale | a fan of 7 stars that pierce one enemy (7 x 0.55 vs 3 x 0.45) | 2.85 | 0.8 | 60% |
| Frost Staff | Glacial Lance | a great ice shard (drawn bigger, 16 directions) shattering into a frost nova (radius 64) that slows 50% for 2 s (2.7 vs 1.05) | 2.57 | 1.0 | 50% |
| Spark Wand | Forked Wrath | a bolt from the hand to the closest enemy ahead, leaping to 3 more (each 70% of the last; 2.1 vs 0.85) | 2.47 | 0.85 | 55% |
| Ember Tome | Pyre Heart | a great fireball exploding (radius 64), burning (4.0 vs 3 x 0.6) | 2.22 | 1.05 | 50% |

Shown: a gauge of twelve steps on the floor around his feet and on the attack button's rim, in
the element the weapon carries (steel when plain), the weapon held up in his hand with the
element's motes drawn into it; full, a flash of the core and a beat (under three a second).
The first time, a hint points at the attack button ("Hold the big button to charge your
weapon...", after the weapon skills' hint).

Tomes (found on the floor, dropped by casters and bosses) teach Holy Light, Battle Cry, Frost Nova,
Fireball, Blink or Thunder, whatever weapon you hold: a warrior can heal, a mage can blink.
Battle Cry bursts jets of blood out of the floor around the hero; Blink vanishes and appears in
a hollow ring of pale flames, leaving flames along the way (both on their element's kit,
docs/vfx.md).
Swapping weapons swaps buttons 2 and 3 (new skills start on a short cooldown, so swapping can't skip
cooldowns); the roll and the learned spell stay.

Skill damage uses **skill power** (`power x (1 + skill_power)`), and cooldowns shrink with
**cooldown reduction** (50% max, `CombatRulesDef.max_cooldown_reduction` in `data/combat/combat_rules.tres`): the Arcane Focus perk, the
Sage's Codex relic and the of Haste affix push a caster build; the Shadow Cloak gives some cooldown
reduction. **Echoes** (a skill ready again at once: the Echo perk, 15% a level; Echo runes and of
Echoes, 12% each) count together and stop at **45%** (`DungeonConfig.skill_echo_max_chance`): the
Echo perk at its third level reaches it alone, more sources only make it surer to get there. An
echo can't echo (a skill is used at most twice per cooldown). Stacked without the cap, the act III
caster build echoed 69% of its casts on top of the cooldown cap (balance-log 2026-10-23).

A skill is a list of `Effect`s, each with an optional **delay** (combos: Flurry is three stabs,
Fissure three bursts running forward). Effects: damage area (with a sheet effect, a status, an offset),
projectiles (fans, rings, pierce, explosions, status), dash, dash strike (cuts everything along the
path), heal, buff, summon. Statuses (`OnHitStatus`): burn and slow.

## Perks and relics

Every level up offers **1 perk out of 3** (`PlayerDef.perk_choices`, before shrine bonuses),
but **only when the player asks**: a level up opens
nothing and never pauses. It is a short moment in the world instead (rings of golden light widening
around the hero and a column of light behind him, `LevelUpVfx`; "Level up" floating up; a chime),
and the choice waits behind the HUD's **perk button** (left of the minimap: a glowing star with how
many choices wait on a badge, `OffersButton`). Tapping it (or C, the left trigger) opens the choice
and pauses the game; several waiting choices follow one another, with Reroll and Banish as below.
**Later** (or Back) puts the one on screen off: back to the fight, it waits at the head of the line
with the same cards (putting off never rerolls). Choices wait as long as the player wants, across
floors, and are saved with the run, the one on screen with its cards (`OfferQueue`, `RunSave`). `GameOffers` owns dealing, rerolls, banishes and postponement;
its panel subscriptions follow the Game child's lifetime.
Saved titles/subtitles are English message keys, with the level stored separately; translation
happens when shown, so changing language also changes waiting offers. Older rendered titles are
recovered through the installed translations when possible.
Taking a perk again levels it up (up to its `max_stacks`). Bosses drop a choice of **relics** (rare
perks), one of them a relic that bends a rule (below, "Rule-bending relics"), and so does a kept
pact, without one (pact doors, see [dungeon.md](dungeon.md)).

**What waits, what comes by itself** (`OfferQueue.Offer.on_demand`). Level ups wait: they come
mid-fight, where a window over the screen broke the fight's flow. Relics (a boss', a kept pact's,
the hidden floor's boss) still come up by themselves, a moment (`Game.RELIC_DELAY`) after the
fight is won: the room is quiet, the reward is the point of the fight, and seeing it at once keeps
that moment; an encounter's gift ("A boon", a relic) too, right after its own panel. Any of them
put off with Later then waits behind the button like a level up. While the player is choosing
(after a tap on the button) every waiting choice follows in turn; otherwise only the automatic
ones show. There is no first perk at the start of a run (the daily run's relic is simply given).
The game's API for bots and tools: `Game.pending_offers()` (how many wait) and
`Game.open_offers()` (what the button does).

The choice comes in softly (`PerkChoicePanel`): the world dims and the board rises into place
over 0.2 s, the cards fading in one after another, with the UI's open sound.

Everything on a card is spelled out for someone who never played a roguelike: "New perk (up to
level 3)" or "Level 1 > 2 (max 3)", what it does, and a box per **family** with its name, little
squares for the perks of it you hold (this one included), how many more it takes and what its
bonus does; the card that would complete a family glows and says "AWAKENS!". One line under the
title says what families are. In the bag, **Perks** opens "Your perks" (`BuildWindow`): every
family with its progress and bonus, and every perk taken with its level and effect.

A `PerkDef` (in `data/perks/`) is stat bonuses + a list of `Passive`s, both multiplied by its level:

| Passive | Hook | Used by |
|---|---|---|
| `HealOnKillPassive` | on kill (not summons) | Vampirism |
| `LifestealPassive` | on hit (direct hits only) | the Leech rune, Vampiric elites |
| `HealOnSkillPassive` | on skill | Devotion |
| `ThornsPassive` | on damaged (can leave a status) | Burning Thorns |
| `RetaliatePassive` | on damaged (cooldown, can leave a status) | Frost Armor: getting hit throws enemies back and chills them |
| `MomentumPassive` | on dash, before a hit | Swiftness: hits right after a roll deal more |
| `OpenerPassive` | before a hit | Precision: the first blow on an unhurt enemy is a crit |
| `FloorWardPassive` | on a new floor | Guardian Ring: every floor starts with a ward |
| `BurnOnHitPassive` | on hit | Ignite (burn status) |
| `CritShockwavePassive` | on hit (crits, can leave a status) | Thunderclap, the Shatter rune |
| `DashShockwavePassive` | on dash (can leave a status) | Shock Roll, Cold Snap, Blazing Roll |
| `SlowOnHitPassive` | on hit | Frostbite |
| `StatusDamagePassive` | before a hit (burning/poisoned/slowed target) | Kindling, the Frost family |
| `KillBurstPassive` | on kill (shards out of the body, a blast) | Ice Shards, the Inferno family |
| `SkillEchoPassive` | on skill (cooldown back to 0) | Echo |
| `EffectsOnSkillPassive` | on skill (any `Effect`) | the Arcane family |
| `ChainLightningPassive` | every few hits | the Storm family |
| `BloodlustPassive` | before a hit (wounded), on kill | Bloodrage, the Blood family, the Fury rune |
| `LootOnKillPassive` | on kill | Fortune |
| `ExecutePassive` | before a hit | Executioner |
| `ExtraProjectilesPassive` | every volley | Hydra's Quiver |
| `CheatDeathPassive` | before dying (opens the Threshold, see below) | Phoenix Feather (and Death Denied's) |
| `EmberTrailPassive` | on dash (an `EmberTrail` on the floor) | Cinder Wake |
| `SplitShotPassive` | on hit, a direct shot (`HitInfo.shot`) | Riven Glyph |
| `CritLeapPassive` | on hit (crits) | Leaping Bolt |
| `OverkillBurstPassive` | before a hit (Health left), on hit (the killing blow) | Burst Veins |
| `FrostOrbitPassive` | every frame (`Passive.tick`, shards drawn by `FrostOrbitVfx`) | Rime Halo |
| `RollStrikePassive` | on skill (the roll: pays), every frame while rolling (cuts) | Bleeding Stride |
| `SkillHungerPassive` | every frame (holds the cooldowns, `SkillSet.wind`), on kill, on hit (a boss) | Starving Litany |
| `RestlessStormPassive` | every frame (moving or standing still near a foe) | Restless Storm |
| `PyreKillPassive` (a `KillBurstPassive`) | on kill (a blast; the owner in it pays) | Funeral Pyre |
| `WinterAuraPassive` | every frame (a chill pulse every 0.25 s) | Heart of Winter |

**Acting over time** (`Passive.ticks()` / `tick()`): a passive that does something by itself
(shards circling the hero) says so, and only those are called each physics frame
(`PerkSet.tick()`, from `Actor._tick_timers()`); the others cost nothing there.

Damage caused by a passive (burn, thorns, shockwaves, chains, Ice Shards' shards, the Arcane
ring of bolts: `ProjectileSpec.secondary`) is a *secondary* hit: it never triggers other on-hit
perks (no lifesteal, no chain counter), and passive shots get no extra projectiles, so effects
can't chain forever.

**Healing from hits, kills and skills** (`SustainRules`, `data/dungeon/sustain.tres`, set in
`DungeonConfig` > Sustain; `SustainMeter`, `Actor.sustain_heal()`): Leech, Vampirism, Devotion,
the Blood family, the Fury rune and Vampiric gear all draw from one budget. It holds 20% of the
hero's max health (a pack slain at once still heals well) and refills 4% of it per second. While a
boss fight is on it holds a quarter of that (5%) and refills a tenth as fast (0.4% a second,
`boss_fight_burst`, `boss_fight_rate`): healing there forgives a mistake, it can't out-heal a boss. Healing is paid in whole
points, the fractions adding up (10% of a 7-damage hit is 0.7, not 1). Burn and poison ticks and
secondary hits heal nothing, and summoned monsters and a boss's adds feed no "on kill" heal (nor
Fortune's loot). Potions, springs, healing spells and level ups are not limited. Perks are stored per actor in a `PerkSet`,
so monsters could use them too (elites, later).

### Second lives: the trial of the Threshold

A second life (`CheatDeathPassive`: the Phoenix Feather relic, one per level, and the feather the
Tree of Souls' **Death Denied** gives) no longer heals the hero where he stands. The killing blow
pulls him into **the Threshold** (FR *le Seuil*), a limbo between life and death, for a trial
against the clock: **slay the spectres before the knell**. Won, he comes back to the very spot he
fell on, just after, with the feather's heal (`heal_ratio`: half his max Health,
`boss_fight_heal_ratio`: a quarter during a boss fight) and its blast around him, plus a second
of grace (he blinks, nothing hurts him: monsters were frozen mid-swing). Lost (the countdown runs
out, or he falls in there), he is put back where he fell and **dies for real**: the normal end of
the run, and what slew him is still what slew him the first time.

- **The floor waits.** The floor's `World` leaves the scene tree as it is while he is away
  (`Threshold`, `src/game/threshold.gd`): its monsters, their Health and statuses, an elite's
  affixes, a boss mid-fight and its arena, the shots in the air, nothing moves and nothing is lost.
  The hero's own statuses stay behind (cleared on the way in and on the way back).
- **The limbo** is a `ThresholdWorld` (`src/world/threshold_world.gd`, a `World` built beside the
  floor): one oval arena in the mist (`ArenaDef` `data/threshold/limbo_arena.tres`, pale lamps for
  pillars), no stairs, no seal, no loot. He fights at `hero_health` of his max Health (60%).
  Spectres of the act he fell in rise around him, a few at a time, and come for him: pale,
  see-through, `monster_health` of their Health (70%), and worth nothing (summoned: no XP, gold,
  loot, bestiary kill, challenge or "on kill" heal).
- **The rules** (`ThresholdDef`, `data/threshold/threshold.tres`, named by the passive's `trial`):

  | Act | Spectres to slay | Seconds |
  |---|---|---|
  | I | 8 | 25 |
  | II | 10 | 31 |
  | III | 12 | 37 |
  | IV (and endless, by act) | 14 | 43 |

  (`kills` + `kills_per_act` x act, `time_limit` + `time_per_act` x act; 4 spectres up at once,
  the next one 0.7 s after a gap opens, never closer than 5 cells.)
- **Once per stack:** each feather opens one trial (`memory.used`). A blow taken inside the trial
  is the trial's to judge: a second, unused feather doesn't save him in there.
- **Around it:** the run's clock keeps counting; nothing is saved during the trial (a run picked
  up again is as it was before the killing blow); the bag stays shut, the perk and Interact buttons are put away and perk choices wait;
  the pause menu works. Without a Threshold in the scene (the balance tools' bare arena, which
  also has no game around it), a second life heals in place as before, so revives still read in
  the measures.
- **From the Deeps** (dungeon.md, "The Deeps"): a killing blow down there (a demon's, or the fall
  itself) opens the Threshold from the Deeps. The Deeps wait out of the tree as the floor does
  (and the floor goes on waiting under them: the stays nest, `SubWorld`); won, the hero comes back
  **into the Deeps**, where he fell, and must still find the Dawn Breach; lost, he dies down
  there. The Threshold never sends him into the Deeps (its limbo has no holes, and
  `Abyss.can_take()` refuses while a trial is on).

### Families (synergies)

Most perks and relics belong to a **family** (`SynergyDef`, `data/perks/synergies/`, listed in
`content_db.tres` > Synergies; a perk names its own in `PerkDef.synergies`). Holding **3 different
perks** of a family wakes its bonus for the rest of the run: a change in how you play, not a number.

| Family | Perks and relics | Awake |
|---|---|---|
| **Inferno** | Ignite, Kindling, Blazing Roll, Burning Thorns, Cinder Wake, Phoenix Feather, Funeral Pyre | enemies that die burning explode and set everything around on fire |
| **Frost** | Frostbite, Cold Snap, Ice Shards, Frost Armor, Rime Halo, Guardian Ring, Heart of Winter | slowed enemies take +50%, crits freeze them |
| **Blood** | Vampirism, Vitality, Bloodrage, Devotion, Burst Veins, Executioner, Bleeding Stride | below half Health +40% damage, every kill heals 4% max Health |
| **Storm** | Frenzy, Thunderclap, Shock Roll, Swiftness, Leaping Bolt, Restless Storm | attacks 15% faster; every 3rd hit, lightning jumps to 3 enemies |
| **Arcane** | Arcane Focus, Arcane Power, Devotion, Echo, Riven Glyph, Sage's Codex, Hydra's Quiver, Starving Litany | every skill also fires a ring of 8 bolts |

A perk sits in a family only if its effect plainly belongs to it (Inferno: fire and burning;
Frost: cold, slows, freezing; Blood: health, life drain, low-health power; Storm: lightning,
chains, speed of the strike; Arcane: skills, spells, cooldowns). Plain-number perks (Strength,
Precision, Fortune, War Banner) belong to none. Why: [balance.md](../balance.md) and the [balance log](../balance-log.md).

### Roles

Every perk, relic and affix has a purpose (decision 0012; Slay the Spire's "every card has a
purpose"): `role` (`BuildRole`) is **staple**, a solid pick in any build, or **build-around**,
something that changes how you play and asks for its family. A build-around always belongs to a
family (`PerkDef.synergies`, `ItemAffixDef.family`); a staple may or may not. `unit.roles` refuses a
perk, relic or affix without a role, or a build-around without a family.

| Role | Perks and relics | Affixes |
|---|---|---|
| Staple, no family | Strength, Precision, Fortune, War Banner | Brutal, Ironbound, Light, Unerring, Sharp, Stalwart, Swift, Venomous, of Fury, of Haste, of Sorcery, of the Bear, of the Fox, of the Titan, of Thorns |
| Staple, in a family | Arcane Focus, Arcane Power, Sage's Codex (Arcane); Frenzy, Swiftness (Storm); Vitality (Blood); Guardian Ring (Frost) | |
| Build-around | Ignite, Kindling, Blazing Roll, Burning Thorns, Cinder Wake, Phoenix Feather (Inferno); Frostbite, Cold Snap, Ice Shards, Frost Armor, Rime Halo (Frost); Vampirism, Bloodrage, Devotion, Burst Veins, Executioner (Blood); Thunderclap, Shock Roll, Leaping Bolt (Storm); Echo, Devotion, Riven Glyph, Hydra's Quiver (Arcane); the five relics that bend a rule, one per family | Burning, of Embers (Inferno); Frozen, Shattering (Frost); Thundering (Storm); Vampiric (Blood); of Echoes (Arcane) |

A new perk, relic or affix declares its role with its numbers: a staple is plain numbers or a
modest effect worth taking anywhere; a build-around's effect plainly belongs to its family.

### Rule-bending relics

Isaac's and Gungeon's best items change a rule rather than a number, with a price or a twist.
Five relics do (`PerkDef.twist`), one per family, each readable in one line:

| Relic | Family | The rule bent | The price |
|---|---|---|---|
| **Bleeding Stride** | Blood | the roll cuts every enemy it passes through for 150% of your Damage | each roll costs 4% of max Health |
| **Starving Litany** | Arcane | skills (not the roll) recharge only by slaying: a quarter of their wait a kill, 3% a blow on a warden; +60% skill damage | no recharge with time |
| **Restless Storm** | Storm | while foes are near and you move, lightning strikes the nearest every 0.7 s (your Damage) | standing still a second, it strikes you (3% max Health a second) |
| **Funeral Pyre** | Inferno | every foe you slay explodes (120% of your Damage, radius 72, sets on fire) | the blast burns you too if you stand in it (6% max Health) |
| **Heart of Winter** | Frost | foes within three steps (100) are slowed by 35% (it feeds the Frost family) | you move 20% slower (-34) |

- **Only wardens offer them**, one card of the three of every warden's relics while some are left
  (`OfferQueue.add_relic`, `Offer.twists`, `ContentDB.pick_perks(..., twists)`); a reroll keeps one,
  banishing it brings another. Level ups, pacts, trials and encounters' gifts never offer one,
  nor is one the daily run's relic (the day is the same for everyone). The card says
  "Relic that bends a rule" in the danger color.
- **A relic's own price never deals the last blow**: it leaves 1 Health, and it is a tick (no hit
  stop, no free invulnerability: standing still under the storm must not shelter the hero). A
  roll's invulnerability spares him the pyre's blast; the storm rages only with a foe within
  150 (a shop, a talk, a quiet room are left alone).
- The Nameless Keeper never wears them (his relics are a list of plain ones, `kept_perks`).

### Behaviour perks (the audit of 2026-10-28)

Players' first complaint about roguelikes that feel the same run after run is perks that "just
add stats" (research, "Ce qui manque au roguelike"). Past the four staples, a perk should make
something happen in the world that changes how you play: where you roll, what you shoot first,
whether you dive into the pack. The audit sorted the 24 perks and relics past the staples:

| Kind | Perks | |
|---|---|---|
| Numbers only | Arcane Focus, Arcane Power, Frenzy, Vitality, Sage's Codex | staples of their family: kept as they are |
| A number under a condition | Kindling, Bloodrage, Executioner, Swiftness | the families' payoffs (burning, low Health, wounded foes, after a roll): kept |
| A status or a heal on a hook | Ignite, Frostbite, Vampirism, Devotion, Burning Thorns | |
| Something happens in the world | Blazing Roll, Cold Snap, Shock Roll (a wave on the roll), Thunderclap (a wave on a crit), Ice Shards (shards from a kill), Frost Armor (a wave when hurt), Hydra's Quiver, Echo, Phoenix Feather, Guardian Ring | three of them the same wave on the roll |

So five perks were added, one per family, each a new kind of behaviour (a new `Passive`, no
branch in `Actor`): **Cinder Wake** (Inferno: the roll leaves a trail of embers for 3 s that
burns what stands in it, so you roll around a pack and fight at the trail's edge), **Riven
Glyph** (Arcane: a shot that strikes splits into 3 bolts flying on, +2 a level, 30% of the hit
each: the archer aims at the front of a crowd), **Leaping Bolt** (Storm: a crit leaps to the
nearest other enemy for 70% of it, one more leap a level: the enemy standing apart), **Burst
Veins** (Blood: a killing blow's damage past the Health left bursts onto the enemies around,
50% of your Damage a level at least, twice your Damage at most: heavy blows on weak foes clear
packs) and **Rime Halo** (Frost: 2 shards of ice circle you, +1 a level, cutting and chilling
what they pass through, each enemy once every 0.6 s: you stay close and circle). All are
build-arounds of weight 6, like the others; their hits are secondary (no on-hit perks, nothing
loops). Now 15 of the 29 perks and relics past the staples acted in the world (`unit.variety`
keeps it at a third at least); the five rule-bending relics above made it 20 of 34.

### Choosing: reroll, banish, families first

Under the cards, **Reroll** deals three other cards and **Banish** (then tap a card) removes that
perk for the rest of the run, another card taking its place. A run starts with
`base_rerolls` / `base_banishes` (1 each, `DungeonConfig` > Perk choices), plus the shrine's Loaded
Dice and Exile; every boss slain gives `rerolls_per_boss` more. Offers lean toward the families you
have started: a perk weighs `1 + family_bias` times more for each started, not yet awake family
it belongs to (`ContentDB.pick_perks`).

The perk cards show each family's count ("Frost 1/3") and shine "Wakes Inferno!" on the card that
would complete one. An awake family gets a banner and a framed icon at the head of the HUD's perk row.
