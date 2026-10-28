# Acts, monsters and bosses

## Acts and their monsters

A run is **4 acts of 3 floors** (`data/dungeon/acts/`, listed in `dungeon_config.tres`). Each act has
its biomes, its own monsters and a boss on its last floor. Beating the last boss **wins the run**
the first time; once the profile has won a run, the last act's boss leads down to **the Bottom
of the Well** instead (below, and dungeon.md), whose last form wins it. You can then keep going in
endless mode (the acts loop, monsters keep getting stronger with depth).

| Act | Floors | Monsters | Boss |
|---|---|---|---|
| I. The Well's Maw | 1-3 | Gnawer, Gloom Bat, Slime, Blood Spider, Deathcap, Viper, Acid Larva, Burrower, Giant Slime, Shell Guard, Thief Racoon | Bloated King |
| II. Ossuary of Kagari | 4-6 | Skeleton, Hexer, Lost Soul, Flying Skull, Watcher, Ghost Lantern, Night Owl, Frost Skull, Thief Racoon, Brood Mother | Gorr the One-Eyed |
| III. The Pyre Temple | 7-9 | Pyre Acolyte, Cyclops, Flame Spirit, Lizardman, Horned Beast, Drakeling, Kappa, Ink Octopus, Sapper, Brood Mother, Shell Guard | Crimson Tengu |
| IV. Kingdom of Dust | 10-12 | Dune Behemoth, Gold Racoon, Crimson Viper, Ash Lizard, Bone Lizard, Stone Mole, Sapper | Gilded Hoarder |

Monsters grow with depth (`DungeonConfig` > Difficulty: +32% Health and +1 attack a floor), and
an act can add its own threat on top, on every difficulty (`ActDef.monster_hp`,
`monster_damage`; not its bosses, which are tuned one by one): **Act II's monsters have +8%
Health and deal +8% damage, Act III's +10% and +10%**; acts I and IV keep the depth's numbers.
Without it floors 4-8 were a flat stretch between a gentle Act I and Act IV (docs/balance-log.md,
"Keeper's curve").

**Supports** fight from behind, kill them first: the **Moss Heart** (act I) and the **Ember
Heart** (act III) mend their hurt allies, the **Soul Moth** (act II) and the **Gilded Moth**
(act IV) wrap them in wards that soak up your blows, the **Sand Drummer** (act IV) beats a war
drum (allies hit harder, run faster); each shoots its own element (the Moss Heart poisoning
spores, the Soul Moth a pale wisp, the Gilded Moth a golden mote, the Sand Drummer a clod of
sand that slows; only the Ember Heart and the Ghost Lantern throw burning ghost flames); the
**Pyre Acolyte** now mends its allies too
(`AllyEffect`: heal, buff or ward the allies around; `SkillDef.ai_ally_need`: only when an ally
needs it). A beam of light shows who is helped; the Soul Moth's wards are spirit (each warded ally
flares in a hollow ring, the ward is a flickering shell with pale flames licking off it), and the
moth throws soul flames that slow (not fire). Venom is one look everywhere: the Deathcap's spore
clouds, the Acid Larva's and Bone Lizard's spit, the Viper's, Crimson Viper's and Brood Mother's
fangs, the Giant Frog's Poison Spit and the Jade Wyrm's Venom Spit, Toxic Bloom and Venom Fang
are globs of venom, gas and pale fangs (docs/vfx.md). Claws (the spiders, racoons, moles, the
owl) rake in blood; ghosts touch with spectral claws, blink in pale flames, wail in rings of
wisps and are called out of hollow rings; Burrowers and Stone Moles **burrow** (their own skill,
a puff of earth) rather than blink like ghosts.

Monsters are data (`MonsterDef`): stats, a weapon (its `on_hit` status poisons, burns or slows),
skills (telegraphed casts: spore clouds, dives, charges, ink rings...), and **traits**
(`MonsterDef.traits`, `src/definitions/monster_traits/`): small resources that hook into the
monster (on spawn, every frame, steering, attacking, taking a hit, hurting the hero, dying, drawing).
Every monster of a kind shares the trait; per-monster values live in `Monster.trait_state()`.
What a monster draws besides its body (warnings, elite aura and name, health bar, trait drawings)
is `MonsterOverlay`.

- **DeathBurstTrait**: bursts after a short warning (a flame spirit explodes, a frost skull
  bursts into a ring of ice crystals that slows everything around: `element`, docs/vfx.md).
- **DeathSpawnTrait**: monsters come out when it dies (a giant slime splits in two).
- **GuardTrait** (Shell Guard): the shell, the silver arc in front of it, blocks most of the damage
  and push of blows from the front. It turns slowly: roll behind it. Burns, poison and blasts
  go around the shell.
- **ThiefTrait** (Thief Racoon): each hit takes some of your gold, then it runs away. Slay it to
  get the gold back, with interest.
- **Brood Mother**: keeps her distance and lays red spiders (a `SummonEffect` skill). Kill her first.
- **WeakPointTrait** (the Maw): only its weak point can be hurt, and only while it opens. Closed,
  every blow glances off whole (no damage, no status, no streak toward the shockwave: a clang off
  its mask, sparks, "No effect") and it uses its skills; every `closed_times` seconds (shorter in
  each phase) it opens (`open_animation`, then `open_pose` held) for `open_times` seconds, its
  skills put away: hits land, it draws the hero toward its mouth (`pull_speed`, a third of his
  pace) and bites him if he comes too close (a warning circle, then the bite, thrown back). It
  can be rooted (never walks), carry its own light (`glow_level`, brighter open) and stand in a
  pool drawn on the ground under it. Hooks it added to `MonsterTrait`: `deflects()` (a hit turned
  away before anything happens) and `can_cast()`.
- **Sapper**: keeps away and lobs bombs that blow up where they land (a projectile skill with an
  `explosion_radius`).
- The **Pyre Acolyte** heals the monsters around it.

How every monster looks: it spots the hero within its reach (`detect_radius`, further while it
chases) when nothing on the world's layer is between them. The line of sight is looked at again
every 0.1 s, or as soon as either of them moved 4 px (`MonsterSteering.can_see`): a monster may notice the
hero, or lose him behind a wall, a few frames late, never more. Monsters **don't collide with
each other** (walls, water and the hero stop them; decided with Clayton, 25 October 2026: a crowd's
heaviest cost, and a roguelike's packs flow better): a pack spreads around the hero by stepping
away from the monsters it overlaps while walking (`MonsterSteering.keep_spacing`) and, standing
(waiting, striking), by easing out of a heap at up to 60 % of its speed (`stand_apart`), both asked
of the nearby cells only (docs/performance.md). Idle and chase think every second frame, each
monster on its own beat (`StateMachine.THINK_EVERY`); a strike's wind-up, a cast and bosses every
frame.

### Warnings: the fairness contract in play

Every attack that hurts warns ([decision 0008](../decisions/0008-fairness-contract.md),
[pillars.md](pillars.md) "The fairness contract"), on three channels: the pose (a wind-up or cast
animation), the red mark on the ground and a short **warning sound** (`Sfx.play_warning()`,
`SoundBank.telegraph`: two of the game's own sounds made into one cue, at most one every 0.1 s and
two at once, so a pack winding up together is not a din). The numbers live in
`data/combat/combat_rules.tres` (`CombatRulesDef`, "Fairness contract") and are applied in one place
per mechanism, **after** the difficulty's, an ascension's and the boss phases' multipliers:

| What | At least | Where it is asked |
|---|---|---|
| A monster's blow, a cast that hurts (an instant one too: Volley now winds up 0.5 s) | 0.4 s | `Monster.get_attack_windup()`, `Monster.skill_cast_time()` (`SkillDef.monster_cast_time()`) |
| A boss's blow, cast, bite (the Maw), strike on the ground | 0.5 s | the same, `Monster.windup_for()`, `GroundStrike.create()` |
| A warned pulse (Vengeful, Unstable), a maw's bite | the monster's floor | `Monster.windup_for()` |
| A shockwave, a burst after death, a bomb's or a barrel's fuse, a trapped chest | 0.4 s | `Combat.shockwave()`, `Combat.delayed_blast()`, `Prop`, `Chest` (`CombatRulesDef.blast_warning()`) |
| A trap's click (spikes, an arrow plate) | 0.4 s | `TrapDef.warning_seconds()` |

The mark covers the real area and lasts until the hit: a shot's lane is drawn as far as it flies
and as wide as the shot (`TelegraphView.show_shots()`; a ranged monster's shot too), a ring of
shots (Hailstorm, Toxic Bloom, Sandstorm) by its lanes, not a small circle; a blast's mark
(`FuseMark`) fills up for its whole fuse and follows a boss that moves. The bestiary's preview
plays the same wind-up. An awake monster winding up off screen, or an enemy shot flying in from
off screen, gets an arrow at the screen's edge (`ThreatMarkers`, the HUD). `unit.fairness` walks
every MonsterDef and BossDef x difficulty (Nightmare at its last ascension too) x phase.

## Monster ranks: Elite, Fell, Legendary, Celestial

Any monster can come at a rank (`MonsterRankDef`, `data/monster_ranks/`; `DungeonConfig.elite_rank`
and `rare_ranks`, rarest first, each with its own chance from its depth, times the difficulty):

| Rank | Affixes | Health (depth 1 / 5 / 11) | Damage | Look | Rewards |
|---|---|---|---|---|---|
| **Elite** | 1 ("Vampiric Skeleton") | x2.5 / x3.7 / x5.5 | x1.15 | a ring of the affix's color | x3 XP, better loot, 1 extra drop |
| **Fell** (from depth 3) | 2, listed over its name | - / x6.3 / x9 | x1.2 | two purple rings | x6 XP, 2 extra drops, x8 gold |
| **Legendary** (from depth 5) | 3 | - / x8.5 / x11.5 | x1.3 | golden rings and a crown of rays | x10 XP, 3 extra drops of high quality, x15 gold |
| **Celestial** (1 in 400, any depth) | none | x3.3 / x3.9 / x4.8 | x1 | other colors (hue shift), a gleam sweeping its body, sparkles | x8 XP, 3 extra drops, x25 gold; joins the bestiary's Celestial collection |

Every rank also shows a rim of its color around the body (`BodyLook.outline`) and its name over
the monster. Its body is wider (`radius_multiplier`: x1.125 Elite, x1.175 Fell, x1.225
Legendary, x1.075 Celestial: collision, reach, shadow, aura), but its art is never enlarged:
pack art stays at scale 2 ([decision 0007](../decisions/0007-whole-pixels-on-screen.md); the
ranks were drawn x1.15 to x1.45 before, pixels of two sizes side by side).

A rank's Health grows with depth (`hp_multiplier` + `hp_multiplier_per_depth` per floor): the
hero's power grows faster than the monsters' own depth scaling, so a deeper Elite needs more
Health to stay a short duel. Its affixes' Health on top (Ironclad x1.3, Bursting x0.85...).
Ranked bosses use `boss_hp_multiplier` and keep their own damage.

Bosses roll the rare ranks too (`boss_chance`): a **Legendary Bloated King (Swift, Vampiric,
Ironclad)** has its affixes' perks, more HP, better loot and one more relic to choose; a Celestial boss
other colors and one more relic. The boss bar shows the rank's color and the affixes. The debug
panel spawns any rank and can make the next boss one.

### Composable affixes

An `EliteAffixDef` may grant its legacy `perk`, an ordered list of `MonsterTrait` resources, or
both. `MonsterTraits` composes native behaviours first, then each accepted affix's behaviours
in saved order. The same resource activates once per monster, with separate state from
`monster.trait_state()`. Hooks (damage, attacks, skills, movement, hits, death and drawing) use
that cached list; shared `MonsterDef`, affix and trait resources are never changed. Ranking
applies once per monster lifetime, so a repeated application cannot multiply stats/rewards.

Eligibility lives in data: inherited minimum depth and spawn weight, optional maximum depth,
boss permission, required/excluded monster tags, excluded species ids and excluded affix ids.
Affix exclusions are symmetric even when declared on one side. Both random selection and
manual/restored application check eligibility; the rank's affix count is the limit. Random
selection retains the bounded retry loop; if no compatible choice remains it gives fewer
affixes, never an incompatible combination. Existing affixes still grant their original perks.

**Pestilent / Pestilentiel** (`data/elites/pestilent.tres`), from floor 4, weight 5 (ordinary
affixes 10), no bosses, x0.9 Health on top of its rank: poison on a direct hit (2 damage per
second for 4 s), then a toxic burst after death (52 px, 0.8 s warning, dungeon-scaled damage 4
and the same poison). A green affix aura and the existing poison nova use the original sprite.
It cannot combine with Venomous or Bursting; down a hole it releases nothing. Its two modules
are `OnHitStatusTrait` and `DeathBurstTrait`. Secondary hits/ticks never trigger the status
payload again. Poison is refreshed, not stacked, by the existing StatusSet rules.

Saved later monsters keep affix ids, rank, definition and Health share; resuming reconstructs
the same modules and fresh temporary state, as other short-lived combat state already does.
The expanded weighted pool changes floors from depth three: `FLOOR_FORMAT` is 3 so an older
saved floor is rebuilt under the existing stamp rule, with the hero and run retained. Recorded
floor fingerprints for the five affected cases were updated intentionally; all other cases agree.

Four more affixes reuse these pieces and the existing sprite/effect library. Each has weight 5,
never applies to bosses, and uses the normal rank's affix limit (one for an Elite, the existing
higher limits for Fell/Legendary). No rank or original affix numbers were changed.

| Affix | First floor | Behaviour | Rank Health factor | Incompatible affixes |
|---|---:|---|---:|---|
| Glacial / Glacial | 3 | Direct hits slow 25% for 2 s. Death: radius 52, warning 0.8 s, dungeon damage 3 and the same slow. Nothing after a fall. | x0.9 | Pestilent, Bursting, Unstable |
| Frenzied / Frénétique | 3 | Walks 30% faster at or below 50% Health. Healing above the threshold removes it immediately; attack speed is unchanged. | x1 | Swift |
| Vengeful / Vengeur | 4 | After 3 direct hostile damaging hits, warns 0.9 s then strikes radius 48 for dungeon damage 6, push 180. Six seconds after the warning ends before counting hits again. | x0.9 | Thorned, Unstable |
| Unstable / Instable | 5 | Every 5 seconds of engagement, warns 0.9 s then strikes radius 48 for dungeon damage 6, push 180. | x0.9 | Bursting, Pestilent, Glacial, Vengeful |

Vengeful and Unstable share `WarnedPulseTrait`: per-owner timers, hit count and one pending
`GroundStrike`. Warnings are placed at the monster's position and stay there when it moves;
the existing red ground telegraph precedes the spirit/fire nova. Warning time is multiplied by
`get_telegraph_scale()` as for other monster attacks, never under the floor (`Monster.windup_for()`). A live hostile target within 180 px and
in sight is needed to begin a pulse. Dormancy and absence of a target pause the periodic clock;
sleeping monsters retain the game's existing sleep policy. Secondary hits/ticks, fully absorbed
hits and lethal blows never charge a riposte; hits during cooldown are discarded. A pending
pulse cancels on death, falling, a freed/detached source or leaving the floor. Fresh temporary
counters on resume deliberately give a new full periodic interval and no hidden pending strike.

Glacial needs no new behaviour script: it combines `OnHitStatusTrait` and `DeathBurstTrait`.
Frenzied uses `FrenzyTrait`'s walking-speed multiplier, derived from current Health without
editing stats or allocating frame buffs. An existing fire pop announces entry into frenzy;
its attacks do not gain fire damage. The original **Vampiric / Vampirique** remains on
`LifestealPassive`: 60% of direct damage after Armor and wards, fractional healing accumulated,
no healing from secondary hits or ticks. It was already present and was not duplicated.

## Bosses

The last floor of each act is a start room and one big arena. The boss sleeps
in the middle; walking in closes the exits with spikes and wakes it up (boss music, health bar
with its portrait). A `BossDef` is a `MonsterDef` plus:

- **phases**: three per boss, full life, two thirds (`hp_ratio` 0.66) and one third (0.33). Each
  phase adds stats, swaps in new attack patterns, shortens the wind-up (never under a boss's
  0.5 s: see "Warnings" above) and the cooldowns
  (`cooldown_multiplier`) and tints the boss; the last one uses fierce versions of its skills
  (`<skill>_fierce`: a second wave, rings shifted into the gaps of the first, more summons).
  Entering a phase, the boss **roars**: untouchable for a moment (`phase_roar_time`) and a
  shockwave throws the hero off. Notches on the boss bar show where the next phases start;
- **no face-tanking**: hit it too many times in a row (`shockwave_after_hits`, fewer in later
  phases) and it answers with the same shockwave (`Combat.shockwave`), which hits as hard as its
  blows (`shockwave_power`, a share of its power): roll through the red ring (its whole area,
  filling up until it lands, following the boss) or stop hitting;
- **cast skills**: rings of projectiles, ground quakes (red circle), summons (`SummonEffect`), dashes;
  every warning tells the truth (unit-checked on every boss, numbers in
  `data/balance/targets.tres`): a dive or leap warns at least 0.45 s in the boss' last phase on
  Keeper and hits a band its body could cross (at most 8 px wider each side), never slowing; a
  circle's later blows (the fierce Quake's wider second ring, the fierce Flame Arc's second
  burst) land inside the circle it drew;
- **relic_choices**: when it dies the spikes go down, the stairs appear and you pick a relic.

| Floor | Boss | Style |
|---|---|---|
| 3 | Bloated King | 360° slams, slime rain, splits into slimes at half HP |
| 6 | Gorr the One-Eyed | heavy club, fire eye beam (a fan of long rays of fire), quake (the ground bursts), calls skeletons, berserk at 20% |
| 9 | Crimson Tengu | fast blade, dashes, feather storms, calls spirits |
| 12 | Gilded Hoarder | crushing leaps, storms of gold coins, calls its thieves (Gold Racoons) when half dead |
| 6 (hidden) | The Nameless Effigy | twin cold blades, dashes, wailing rings, calls the dead; only on the hidden floor |
| bottom (after a first win) | Master Tôma, then the Maw | the hero's own blade and lantern; then a jaw that must open to be hurt |
| bottom (after "take his place") | The Nameless Keeper | your former hero: his weapon, armor, skills and relics, then the lantern; the last fight |

**The Nameless Effigy** / *Le Gisant Sans Nom*, "He Who Does Not Rest" / *Celui qui ne repose
pas* (`data/monsters/bosses/nameless_effigy.tres`): the boss of the hidden floor between Act II
and Act III (dungeon.md, The hidden floor), the stone knight of a nameless tomb, risen. Its look is
the Ember Ronin's sheet recolored in bone and ash with cold blue light
(`assets/characters/bosses/nameless_effigy/`, from the CC0 Ninja Adventure art). Built from
existing attacks: the Ronin's blade (`tengu_blade`) and dash, the Mother of Tears' wailing ring;
at two thirds "THE DEAD ANSWER!" (it calls skeletons too), at one third "IT WILL NOT REST!" (the
fierce dash, ring and call, faster wind-ups and cooldowns). 1500 base Health, 6 Armor, speed 85:
on floor 6 that is 3975 Health on Keeper, between Act II's bosses (2650-3048) and Act III's on
floor 9 (5278-5642). Its challenge: shatter it with a Pickaxe. In the bestiary it comes after the
acts, a "???" card under a "???" heading until it was met.

## The bottom of the Well: Master Tôma and the Maw

The final fight (dungeon.md, "The bottom of the Well"; the canon in docs/lore.md, section 3).
One arena, two forms (`BossDef.next_boss`): `data/monsters/bosses/master_toma.tres`, then
`the_maw.tres`. Art: PixelLab sheets made for the game (`assets/characters/bosses/master_toma/`,
64x64 cells; `the_maw/`, 128x136: the 128x128 frames padded 4 pixels top and bottom).

**Maître Tôma, le Gardien Parjure / Master Tôma, the Oathbreaker.** Kneels below the arena's
middle (`arena_anchor` 0.5, 0.62); walking in, his meeting plays (presentation.md, "Boss
stories"): he opens his eyes and draws (intro) in the scene, « Tu es venu, mon élève. » / "You
came, my pupil." (his chronicle's first waking words), then a chapter of his story. With Boss
stories off he wakes on screen and waits his waking out (`waits_intro`: 1.3 s, no step, no blow)
before the duel starts. A duelist with
the hero's techniques, every one telegraphed:

| Skill | What | Warning |
|---|---|---|
| Keeper's Step / Pas du Gardien (`toma_dash`) | a dash strike, the hero's iaido cut along it (230 units) | 0.55 s: he draws (`windup`), the line of the dash |
| Severing Arc / Arc Tranchant (`toma_wide_slash`, from two thirds) | a wide cleave in front (96 radius, x1.4) | 1.25 s: he draws and holds his guard, the circle of the cut |
| The Lantern Turned / La Lanterne Retournée (`toma_lantern`) | he raises the unlit lantern, it flares violet: a circle on the ground under the hero fills for 1 s, then a violet flame (shadow) closes on it | the cast (0.8 s), then the circle (1 s) |

His katana (Keeper's Katana: 13, reach 52, a 150° arc) between them, its own wind-up animation.
At two thirds "HE TAKES THE HIGH GUARD" (the wide cut joins); at one third "THE LANTERN BURNS
VIOLET" (the fierce step, cutting twice; three flames in a row). 1300 base Health, 5 Armor, speed
95; shockwave after 8 / 7 / 5 hits as for the others. **No relic** (`relic_choices` 0).
When he falls, his body stays, kneeling (`body_stays`), and he says his last words (his
chronicle's): « Ta garde est juste, mon élève. » / "Your guard is true, my pupil." Then the arena darkens and shakes (`rise_time` 2.6 s: nothing to
do but watch), **the Maw** rises out of a pool of tar at the top of the arena (`arena_anchor`
0.5, 0.24), his body is drawn into its mouth, the Maw is met (its own cinematic, its name, a
chapter or Hana's voice), and the boss bar passes to it. The arena stays shut, no stairs, no relic between the two.

**La Gueule, la Faim du Puits / The Maw, the Well's Hunger.** Rooted, never pushed, lit from
within (the false sun: drawn over the floor's light with a holy halo behind its mask, wider than
the mask and a step up holy's ramp, and its own golden light on the floor, brighter while open:
`lit_from_within`, `halo_element`, `halo_size` 92, `halo_bright`, `glow_level`). Casting, it doesn't glow
red like the others (that dulled its gold to a red-brown): a red rim runs round its silhouette,
a step brighter in the cast's second half, and its skills mark the ground as usual
(`MonsterDef.cast_warning` RIM). Drawn over every actor, it never hides the hero: in front of
its lower body (its tentacles in the tar) he is drawn over it; its halo goes out once its mask has
crumbled; the view leans toward it (`camera_lean` 0.45) so it and the hero both
stay on a phone's screen. Hana's voice wakes with it (its waking words): « Papa... reste. » /
"Papa... stay."
Its jaw is a **WeakPointTrait**: closed 6.5 s (5 s from 60%, 3.8 s from 30%), open 3.6 s (3.2 s
at the end). Open, Tôma is seen standing in its mouth: every hit lands; it draws the hero in (55
a second, he runs 170) and bites him within 72 of its mouth (0.55 s warning, x1.5 its power,
thrown back hard, every 1.3 s at most). No shockwave for hitting it (`shockwave_after_hits` 0):
the bite is the price of standing in its mouth. Closed, its skills:

| Skill | What |
|---|---|
| Tar Lash / Fouet de Goudron | three (fierce: five) circles fill on the ground around the hero, one after the other, and tentacles of tar slam them (earth: the ground bursts) |
| Call the Damned / L'Appel des Damnés | 2 (fierce: 3) of the Deeps' demons crawl out (Horned Carcass, Shade Stalker, Cinder Wraith; 4-5 at most) |
| False Dawn / Fausse Aube (from 60%) | four columns of false sunlight (holy) fall on circles around the hero |
| Dead Sun's Gaze / Regard du Soleil Mort (from 30%) | a fan of seven sun rays (fire), the Dead Sun's echo |

"THE FALSE SUN RISES" at 60%, "THE HUNGER WAKES" at 30%. 1300 base Health, 3 Armor. Its death:
the golden mask cracks and crumbles (its dead animation), "The sun sets." / « Le soleil se
couche. » (its last words), and only Tôma is left, standing, set down on the ground. The run is won, and the hero
chooses an ending (progression.md, "The two endings"). Then its relic, if he keeps going. Its loot,
runes and gold land in front of it, past its jaw and its pool, where the hero can reach them
(`MonsterDef.loot_offset` 0, 104), not on its body.

Both are in the bestiary after the hidden floor's boss, "???" (their floor's heading too) until
met, each with its chronicle (`data/story/chronicles/master_toma.tres`, `the_maw.tres`: docs/lore.md
5b): their deeds are Tôma slain without a single roll (`StandingDeed`) and the Maw slain by a run
it never bit (`MarkDeed` "bitten": a bite that hurts the hero marks the run, `WeakPointTrait.
bite_mark`). Numbers: docs/balance-log.md.

## The Nameless Keeper

**Le Gardien Sans Nom / The Nameless Keeper** (`data/monsters/bosses/nameless_keeper.tres`, a
`NamelessKeeperDef`; `FinaleDef.keeper`). A run that ends in "take his place" (progression.md,
"The two endings") leaves its hero at the bottom of the Well: the profile keeps a **snapshot**
of him (`Profile.keeper`, `KeeperSnapshot`) and the next runs meet him there **instead of Tôma
and the Maw**. His fall is the last fight: no form rises after him, it wins the run, and the
choice of an ending comes again. One waits at a time: taking his place again puts the new hero
there instead; ringing the bell frees him (Tôma and the Maw wait again).

- **The snapshot** (taken as the ending is chosen, `EndingDef.keeper_change` TAKE; versioned,
  by content ids, JSON in the profile): every piece worn (its id, rarity, affixes, runes, item
  level), the skills beyond the roll (his weapon's, a tome's), his perks and relics with their
  levels, his level, Health, power and Armor, the run's difficulty and ascension, the date, the
  pseudonym he played under (if he chose one on the leaderboards). Reading it back skips what the
  game no longer has (a removed weapon: the keeper's katana in its place). A run copies it when
  it begins (`RunState.keeper`, saved with the run: a run never changes course); a Dawn Knell
  never meets him (the same race for everyone).
- **The boss** (`NamelessKeeperDef.build()`, a copy of the template per snapshot):
  - his **weapon** (its rarity, affixes, runes: they work as on the hero, `WornGearTrait`), his
    **armor** worn and shown (`MonsterDef.shows_gear`: his weapon at rest on his back, the
    trims), a ranged weapon kept at range (`ranged_keep_distance` 170) and shot as a boss shoots,
    not as the hero did: its shots fly 320 at most (`ranged_shot_speed`; a hero's arrow flies
    600), 1.2 s apart at least (`ranged_cooldown_min`; a hero's bow fires 0.42 s apart), drawn
    0.75 s (`ranged_attack_windup`; a blade's swing 0.5) (balance-log 2026-10-24, "A ranged
    Keeper");
  - his **blow** weighs `blow_power` 16 before the floor's rules, whatever the weapon (its
    damage plus his attack; +1 per rarity step above Common): Tôma's katana and attack;
  - his **skills**: the hero's (up to 3, the weapon's first) made a boss': a cast with a warning
    by kind (a dive 0.75 s, a circle 0.8 s, shots 0.65 s, anything else 0.5 s, before the phases'
    wind-ups), at 60% of their power (`skill_power` -0.4), the cooldowns x1.6, a dive's band 20 at most and never slowing, a slow 2 s at
    most and two things that slow at most (his weapon counts), heals left out (a boss never
    heals itself); dressed in his weapon's elements; his AI uses each from a range by kind, in
    his data too (`dive_min_range` 50 out to the dive's distance +30, shots from 90 out
    (`shot_min_range`: never a bolt in the hero's face) up to their reach but 360 at most, a
    circle out to its offset and radius +20, anything else from 260 in);
  - his **relics**: of his perks, only those that make sense on him (`kept_perks`: Ignite,
    Burning Thorns, Bloodrage, Echo, Kindling, Hydra's Quiver), 1 level each (`PerkTrait`);
    plain stats (Strength, Vitality) and the hero's own tricks stay with the hero;
  - his **Health**: 2200 base x his level's (2% a level from level 15, 0.8x-1.3x), then the floor
    as any boss (depth 12, the difficulty and ascension: FloorRules): 10237 at the bottom on
    Keeper (Tôma 6019, Tôma + the Maw 12038). Armor 5, speed 100. Measured: docs/balance-log.md.
- **Phases** (three): from full, his weapon's skills; at two thirds "HE KNOWS YOUR STEPS" (all
  his skills, +2 attack, faster wind-ups and cooldowns x0.85, shockwave after 7 hits); at one
  third "THE LANTERN GUTTERS" (the lantern turned too, Tôma's `toma_lantern`: the violet flame
  under the hero; x0.75, +3 attack, shockwave after 5).
- **His look** (`ShadeTrait`): the hero's own frames and armor layers, worn to a shade (the rig's
  pallor 0.7 toward an ash violet, as the Threshold's spectres: face and colors gone, the shape
  left; a pale rim of one art pixel round it, so the dark body reads on the dark floor), a small lantern in his hand (5x7 art pixels, `assets/characters/bosses/
  nameless_keeper/lantern.png`) with a spirit glow and a light of 4. He stands above the arena's
  middle, where the seal is (`arena_anchor` 0.5, 0.42). Portrait: the hero facing down, faceless,
  his lantern lit. In the codex (his page's look, the attack preview) he is drawn the same way
  (`MonsterTrait.dress_look()`: the body shader's pallor and rim, his lantern), not as the hero.
- **His casts** read apart from his blows: the hero's frames have no cast animation (a skill
  would play his attack pose, trembling, like a blow coming), so he holds still in his idle pose
  facing the hero (`NamelessKeeperDef.cast_pose`, a looping pose held for the warning:
  `ActorRig.play_cast`), his lantern raised over his head and its spirit glow swelling in three
  whole steps, the last one bright (`ShadeTrait` "Casting": `cast_lantern_offset` 5,-20,
  `cast_glow_size` 10), with the skill's own warning on the ground. A blow is still his weapon's
  wind-up.
- **Name**: "The Nameless Keeper" / « Le Gardien Sans Nom » on the boss bar, followed by who he
  was (`BossDef.title_on_bar`): the pseudonym, else "Who You Were" / « Celui que tu étais ».
  The pseudonym **without its tag** (the leaderboards' "#4821", docs/online.md "Names and tags"):
  the tag tells players apart on a board others read, and he is the player's own former hero,
  met only on this device; the snapshot keeps the name alone.
  He fights to the Maw's track (Fight, `fight_ii`: the very last fight).
- **Story** (`data/story/chronicles/nameless_keeper.tres`): he says almost nothing. "Stand." as
  he wakes ("Again." once slain), "At last." as he falls; three chapters told before his fights
  (the second names Tôma, so it waits for the keeper's reveal). No fragments and no deed: his past
  is the hero's own run. His page in the codex keeps the **Keepers freed** (`Profile.
  keepers_freed`, the last 20: his weapon, level, the day), under his chronicle. Its basic
  attack and Damage are the Keeper waiting's (his weapon, his blow before the floor's rules), or
  "Your weapon" when none waits, never the template's stand-in katana. After his fall
  the choice speaks of him (`FinaleDef.keeper_choice_lore`, `EndingDef.keeper_hint` /
  `keeper_text`).
- **Rewards**: as the Maw's (320 XP, 3 relic choices when the hero keeps going, 3 rolls of loot,
  30 soul wisps). Never at a rare rank (`BossDef.as_written`: he is the hero as he was, not a
  Legendary kind), so his page has no Celestial (neither have Tôma and the Maw: a fight of two
  forms is never ranked; `Bestiary.can_be_celestial()`). The codex lists him after the Maw. The gameplay statistics' boss event names him
  `nameless_keeper` (the usual boss event, Events.boss_started).

## Dragons

- **Sand Drake** (Act IV): breathes slowing sand, whips up a sandstorm ring.
- **The Wyrms** (`WyrmTrait`, `WyrmBody`): long dragons. The boss is the head; a body of
  segments follows the path the head took, wings flap on its sides, a pointed tail ends it.
  The body burns at a touch (and throws you back); only the head can be hurt. They fly.
  **Azure Wyrm** (Act II, frost: Frost Breath throws fans of ice shards that slow, 40% for 1 s,
  the only thing of hers that slows; Hailstorm bursts ice all around; Glacial Dive throws back
  and leaves a line of crystals that shatter; its Frost Fang strikes with claws of ice) and **Jade Wyrm**
  (Act III, venom: Venom Spit, Coil Rush, Toxic Bloom), with their three phases and fiercer
  forms, and their own bestiary challenge (a Hammer, an Axe).

## The Deeps' demons

They live under every floor, in the Deeps a fall takes the hero to (dungeon.md, "The Deeps"),
and in no act (`AbyssDef.monsters`, `data/monsters/abyss/`; `ContentDB.abyss_monsters()`): they
come in its waves and wait in its rooms, each from its `min_depth`, and scale with the depth and
the difficulty like any monster (`FloorRules`). Art: Ninja Adventure (CC0), sheets the floors
don't use. The bestiary lists them under their own heading after the acts ("The Deeps"), with the
usual hunter ranks and challenges (the hole challenge too: the Deeps have holes).

| Demon (FR / EN) | Art | Health / Armor / Speed | Weapon | How it fights | From |
|---|---|---|---|---|---|
| Démon Écarlate / Scarlet Fiend | DemonRed | 64 / 2 / 78 | Demon Club (13, heavy push) | a slow brute, hard to push (40%), long wind-up | Act I |
| Carcasse Cornue / Horned Carcass | SkeletonDemon | 30 / 1 / 150 | Scimitar (7) | fast, quick blows | Act I |
| Buveur de Sang / Blood Drinker | Vampire | 46 / 1 / 108 | Claws (6, blood) | drinks 60% of the damage it deals (`PerkTrait`: a lifesteal perk, `thirst.tres`) | Act I |
| Œil des Tréfonds / Eye of the Deeps | Eye2 | 34 / 1 / 45 | Evil Eye (6, shots) | floats, keeps away (220), flies over holes | Act I |
| Âme de Braise / Cinder Wraith | Spirit2 | 28 / 0 / 110 | Ghost Flame (5, burns) | flies, keeps away (160), spits embers | Act I |
| Rôdeur d'Ombre / Shade Stalker | NinjaDark | 36 / 1 / 115 | Scimitar (7) | blinks at you (Blink) | Act II (depth 4) |
| Augure Cornu / Horned Augur | DemonGreen | 38 / 0 / 75 | Hex Staff (6, shadow bolts) | keeps away (170), a volley of shadow bolts | Act II (depth 4) |
| Sentinelle de la Brèche / Breach Sentinel | DemonCyclop2 (50x50) | 170 / 4 / 58 | Maul (13) | stands before the Dawn Breach, War Cry, hardly pushed (85%); never in the waves | Act III |

`PerkTrait` (`src/definitions/monster_traits/perk_trait.gd`) is the one new trait: a kind born
with perks, working as they do on the hero or on an elite. XP: 8 to 13 (the Warden 40).


## Deferred offspring ownership

DeathSpawnTrait and trapped chests queue a typed WorldSpawner batch with its floor generation
and a weak target. A replaced floor cancels the whole old batch; a freed target becomes null,
without a captured-node lambda. Existing kind selection/scatter and random order stay the same.
This protects normal runs without adding a region, respawn or campaign system.
