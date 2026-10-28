# Contributing

## Setup

Godot **4.7** (standard build). On a fresh clone, open the project once in the editor or run
`godot --headless --import`, so `.godot/` (the import cache, never committed) exists before the
tests run. Python 3 (standard library only) runs the translation script.

## Before each commit

1. **Tests pass.** `godot --headless --fixed-fps 60 res://tests/run_tests.tscn -- --only=unit,title`
   after every change; the full run (no `--only`) before finishing a feature. Look at the output too:
   a new `ERROR:` or `SCRIPT ERROR:` line is a bug even when every check passes
   ([docs/testing.md](docs/testing.md)).
2. **Translations are complete.** `python3 tools/i18n/extract.py --check` passes
   ([docs/translating.md](docs/translating.md)).
3. **The change is tested.** A fixed rule or a new mechanic comes with a check. Never weaken or skip a
   check to get a green run.
4. **Docs follow.** The page of `docs/design/` describing what changed is updated in the same commit,
   with the data texts that state a number (perk, rune and affix descriptions). Balance changes get an
   entry in [docs/balance-log.md](docs/balance-log.md).
5. **Design rules hold.** `python3 tools/design/check.py` (also run by `python3 tools/run_tests.py`;
   its palette check needs Pillow) and [docs/art-bible.md](docs/art-bible.md): one art source, one UI
   skin, whole scales, no ground tint, every asset in `REUSE.toml`.
6. **Seen in the game.** For anything visual or about feel, play it (the debug panel takes you there):
   passing tests don't prove it looks or feels right. Captures: `python3 tools/design/capture.py`.

## Commits

- Small and focused. The first line says what changed for the game ("Bosses: the shockwave hits as
  hard as their blows"), the body says why, with before/after numbers for balance changes.
- Never commit `.godot/`, `locale/*.translation`, builds, or signing keys (`.gitignore` covers them).
- Move or rename resources only in the editor's FileSystem dock: references are paths
  ([docs/conventions.md](docs/conventions.md#files-and-paths)).

## Releases

Raise `version/name` and `version/code` in both presets of `export_presets.cfg` (and the version line
of the README), then build as in [docs/android.md](docs/android.md).
