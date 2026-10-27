# Le Puits des Âmes · The Well of Souls

*Under the village of Kagari lies an old well. One night without a moon, it woke up and took the
villagers' souls. Only the ninja keeping watch at the shrine was spared. Take the lantern, go down,
bring the souls back.*

A real-time action roguelike for phones and desktop, made with Godot 4.7 (GDScript, Compatibility
renderer). It plays with touch controls, keyboard or gamepad, in English and French.

- **Runs** of 4 acts, 3 floors each, the last one a boss with three phases. Procedural floors in
  nine biomes, lit tile by tile by torches and lanterns, with traps, holes, quicksand, ambushes,
  trapped chests, curses and floor events, and two ways down to choose from.
- **No classes**: what you hold and what you learn decides how you play. Weapons bring two skills,
  tomes teach a spell, and each level up offers 1 perk out of 3. Collect 3 perks of a family
  (Inferno, Frost, Blood, Storm, Arcane) and it wakes a new way to fight. Gear has rarity, affixes,
  item levels and rune sockets.
- **Monsters** telegraph their attacks and come as Elites, Fell, Legendaries or rare Celestials.
- **Between runs**, souls buy the Tree of Souls, then come oaths, Nightmare and ten ascension
  levels. There are also a daily run with its online leaderboard (Talo, under a pseudonym; the
  rest of the game is offline), daily and weekly quests, a bestiary with challenges,
  achievements and a speedrun timer.

Version 0.2.0 (`export_presets.cfg`), in testing on Android.

## Quick start

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. Open `project.godot` in it, then press Play (F5). The game starts on the title screen.
3. In a debug build, the **DBG** button (or F1) opens the debug panel: jump to any floor, cheats
   (god mode, invisible, damage, no AI), a gallery of every biome and monster ([docs/testing.md](docs/testing.md#debug-tools)).

Tests run headless from the project root:

```
godot --headless --import                                                         # once, on a fresh clone
godot --headless --fixed-fps 60 res://tests/run_tests.tscn -- --only=unit,title   # fast, about 1.5 min
python3 tools/run_tests.py                                                        # everything, in parallel (3 to 4 min on 2 CPUs)
godot --headless --fixed-fps 60 res://tests/run_tests.tscn                        # everything in one process (about 5 min)
```

The exit code is the number of failed checks. Building the Android app: [docs/android.md](docs/android.md).

## Project layout

```
assets/    Art, audio, fonts, shaders, the UI theme
data/      Every piece of content and every tuning number, as .tres resources (no code)
src/       The game's code: definitions/ (the classes behind data/), entities/, world/, ui/...
tests/     The headless test runner and its suites
tools/     Balance measurements (balance/) and translation scripts (i18n/); not exported
locale/    strings.csv: every player text, English and French
docs/      Everything else (below)
```

`data/` says *what* exists, `src/definitions/` says *what a thing can have*, and the rest of
`src/` says *how it behaves*. Adding a monster, a perk or a biome is a data change.

## Documentation

| Read | To |
|---|---|
| [docs/architecture.md](docs/architecture.md) | find your way in the code: the full layout, how the systems fit, the autoloads |
| [docs/conventions.md](docs/conventions.md) | write code that fits: typing, naming, data-driven rules, texts, moving files |
| [docs/adding-content.md](docs/adding-content.md) | add monsters, items, perks, biomes, bosses... |
| [docs/testing.md](docs/testing.md) | run and write tests, use the debug panel |
| [docs/translating.md](docs/translating.md) | how languages work, keeping the French complete, the glossary |
| [docs/lexicon.md](docs/lexicon.md) | name things and write lore in the game's dark-fantasy voice |
| [docs/balance.md](docs/balance.md) | measure the balance with the tools; past passes in [balance-log.md](docs/balance-log.md) |
| [docs/android.md](docs/android.md) | build, sign and publish the Android app |
| [docs/design/](docs/design/README.md) | what every system does for the player, and why |
| [CONTRIBUTING.md](CONTRIBUTING.md) | the checklist before a commit |
| [AGENTS.md](AGENTS.md) | instructions for AI coding agents (also read by Claude Code through `CLAUDE.md`) |

## Credits

- Art, sound effects and music: **[Ninja Adventure](https://pixel-boy.itch.io/ninja-adventure-asset-pack)**
  by Pixel-boy and AAA, CC0 (`assets/LICENSE_NinjaAdventure.txt`).
- Font: **Pixel Operator** (Pixel Operator 8) by Jayvee
  Enaguas, CC0 (`assets/fonts/PixelOperator_LICENSE.txt`); the prompt glyphs (✕ ○ □ △, arrows) added
  in its style.
- Impact and footstep sounds: Kenney **Impact Sounds**, CC0 ([kenney.nl](https://kenney.nl)).
- Bag and forge skin (`assets/ui/rpg/`): Kenney **Pixel UI Pack** and **Fantasy UI Borders**, CC0
  (licenses next to them). The dark insets and slots were redrawn in the same palette.
- The ambience sounds are filtered versions of those sounds, and the heartbeat is synthesized. The
  weapon attack sheets were composed from the pack's weapon sprites to match the hero's attack
  frames.


## Project direction

Le Puits des Âmes remains the action roguelike. F5 and exports open the title, then the usual
descent: runs, procedural floors, perk choices, souls/shrine, death and restart, daily runs and
records. The RPG experiment is archived for a future **separate project**, not another mode
in this repository. See [the archive reference](docs/rpg-archive.md). Existing run/profile saves
and the optional online/privacy settings remain unchanged; campaign files are left untouched.

### Kagari entre les descentes

Depuis le titre, **Entrer dans Kagari** ouvre une petite place jouable. Approche la Veilleuse
pour sa première quête, puis le puits pour descendre ou reprendre une partie. Le village
garde les maisons réveillées, les lanternes restaurées et les statues des héros devenus
Gardiens. Le bouton **Quêtes**, le tableau près du puits et le journal du menu pause
permettent de suivre les demandes. Les habitants réveillés suivent des horaires avec un cycle
jour/nuit de 16 minutes de jeu actif. Au nord du puits, entre dans le **Temple de la Dernière
Flamme** : son sanctuaire donne accès aux compétences et améliorations permanentes. Les
intérieurs des maisons attendent encore un pack résidentiel.
Voir [le village](docs/design/village.md). Le jeu reste un roguelike.

Après le réveil de Ren, Sayo propose **Le Dernier Verset**. Les habitants ont leurs propres
questions, réagissent aux retours des voisins et reprennent leurs activités au fil de la journée une fois
réveillés ; leurs brèves répliques de proximité n'interrompent pas le déplacement.

Pour modifier les décors, portes et routines de Kagari dans Godot :
[guide visuel du village](docs/modifier-village.md), scène `tools/village/layout.tscn`.
