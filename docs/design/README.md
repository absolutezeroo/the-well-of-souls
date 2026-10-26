# Game design

What the game does and why, system by system. Each page names the classes and data files behind
what it describes, so it doubles as a map of the code. The rules of thumb for working on the code
are in [../architecture.md](../architecture.md); how to add content is in
[../adding-content.md](../adding-content.md).

## The loop

1. On the **title screen**, pick a difficulty (and, later, an oath), then go down.
2. A **run** is 4 acts of 3 floors. On each floor: fight through rooms, loot, level up (pick 1 perk
   out of 3), break the stairs' **seal** by slaying most of the floor's monsters, then choose one of
   **two ways down**. The last floor of each act is a **boss** arena; a boss drops a relic choice.
3. Dying or winning ends the run. Gold is lost; **souls** are kept and buy the nodes of the
   **Tree of Souls** at the shrine. Then a new run.

## Pages

| Page | What |
|---|---|
| [dungeon.md](dungeon.md) | Floors, biomes, hazards, sealed stairs, routes, curses, temperature, ambushes, boss arenas, floor events, encounters |
| [monsters.md](monsters.md) | Acts and their monsters, supports, traits, ranks (Elite, Fell, Legendary, Celestial), bosses, dragons |
| [builds.md](builds.md) | Skills and weapons, perks and relics, passives, sustain, families, reroll and banish |
| [loot.md](loot.md) | Item level, rarity and affixes, gold, the merchant, the belt, runes and the forge |
| [progression.md](progression.md) | Difficulty and ascension, the title screen, the daily run and its online leaderboard, the Tree of Souls and oaths, quests, codex, achievements, run timer |
| [interface.md](interface.md) | Controls, phone features (saves, options, minimap), the tutorial, the in-run screens |
| [presentation.md](presentation.md) | Game feel, VFX, shaders, atmosphere, sound, lights, animations and the paper doll |

## Story and identity

Everything is tied to one idea: **souls**. The Well stole the souls of the hero's village; the
monsters down there feed on them; the bosses are its wardens, and the Gilded Hoarder, deep in the
Kingdom of Dust, is the Tyrant who hoards them.

- **The story** (`data/story/story.tres`, `StoryDef`) is told page by page before the first run
  (`StoryScreen`: typed out, tap to go on, Skip), and again from the title screen's Story button.
- **Every act opens with a title card** on black (`ActCard`, `ActDef.lore`): its name and a line of story.
- **Every kill frees a soul**: a little light rises from the body and flies into the hero's lantern
  (`SoulWisp`); bosses free a dozen. The HUD counts the souls of the run, which go to the
  **shrine** at the end: it turns them into permanent upgrades.
- Death and victory screens tell how it ended (`StoryDef.death_lines`, `victory_text`).

The game speaks English and French (see [Languages](../translating.md)): it is **The Well of Souls** in
English, **Le Puits des Âmes** in French (`config/name_localized`, also the app's name on the phone).
