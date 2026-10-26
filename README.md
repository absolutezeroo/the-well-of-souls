# Le Puits des Âmes · The Well of Souls

*Under the village of Kagari lies an old well. One night without a moon, it woke up and took the
villagers' souls. Only the ninja keeping watch at the shrine was spared. Take the lantern, go down,
bring the souls back.*

A persistent solo action RPG for phones and desktop, made with Godot 4.7 (typed GDScript,
Compatibility renderer), with touch, keyboard/mouse and gamepad controls in English and French.

- **A lasting character**: equipment, inventory, gold, XP, learned skills and chosen talents
  survive death. The hero returns to the safe refuge; no new run or shrine grind is required.
- **Fixed places**: the Vigil Refuge, Lower Passage and two underground combat destinations.
  Enemies, wounds, loot, opened chests, unique guardians and discovered maps stay as saved.
- **Explicit rest** renews defeated common enemies while preserving unique objectives/rewards.
  Requests from the Vigil-Keeper, journal, permanent talents and limited refuge supplies form
  the first playable campaign loop.
- **Separate local campaign saves** with atomic checkpoints and explicit recovery. No account
  is required. The former run/profile files are preserved and are never silently imported.

The RPG is an initial four-place campaign, not a finished large open world. See
[the current gameplay contract](docs/rpg-classic.md) and [remaining roadmap](docs/rpg-roadmap.md).
The former roguelike scenes and their regression tests remain as compatibility/reference code;
they are outside the normal player flow. Their procedural acts, daily races, ascensions and
meta-progression are not active campaign features.

Version 0.2.0 (`export_presets.cfg`), in testing on Android.

## Quick start

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. Open `project.godot` in it, then press Play (F5). The game opens the campaign title. Begin an adventure or resume the saved character.
3. Speak to the Vigil-Keeper at the refuge, explore through the stairs, and use Pause for the
   journal, talents, supplies and saves. Legacy developer scenes remain documented in
   [testing.md](docs/testing.md#debug-tools).

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
| [docs/rpg-roadmap.md](docs/rpg-roadmap.md) | track the remaining open-world campaign and multiplayer work |
| [docs/rpg-classic.md](docs/rpg-classic.md) | play and extend the current persistent RPG |
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
