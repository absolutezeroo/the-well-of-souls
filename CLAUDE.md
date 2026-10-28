@AGENTS.md

## Claude Code

- Visual or design work (art, assets, village layout, UI screens, effects): when done, have the
  read-only `art-reviewer` subagent (.claude/agents/) check it against docs/art-bible.md before
  calling it done, and attach the captures of `tools/design/capture.py`.
- Balance work ("too strong", "too weak", a balance pass, after adding content): delegate to the
  `game-balancer` subagent (.claude/agents/). It measures with tools/balance and records the pass.
- Skills in .claude/skills/: `add-content` (new monsters, items, perks, biomes...), `translate`
  (French texts and the glossary), `lore` (story, dialogue, fragments and
  names in the Well's canon and voice) and `vfx` (making or fixing a visual effect coherently: an
  element's kit, pixel art on its ramp, the grid rules, screenshots and review).
- Every task updates the roadmap (`godoban_boards/puits_roadmap.json`, AGENTS.md "The roadmap"):
  cards moved, new todos added. Brief subagents to do it, and check it when merging their work.
- The `game` and `tutorial` suites print a lot: when you only need the verdict, filter the output
  (`... 2>&1 | grep -E 'FAIL|ERROR|checks'`). `python3 tools/run_tests.py` prints only the
  verdict (failures with their test, checks, the slowest tests); its per-process logs, for the
  engine errors, are in the folder it names. Agents testing at the same time: use it (or
  `--test=`), it gives each process its own user folder.
