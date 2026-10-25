# Agent guide: Le Puits des Âmes

Real-time action roguelike in Godot 4.7, GDScript (statically typed), Compatibility renderer,
for Android and desktop. Humans start at README.md; the reference is in docs/. Read the docs page
for a system before changing it.

## Commands (from the repo root)

- Godot: `godot`, or a downloaded `Godot_v4.7-stable_linux.x86_64` (how to get it: docs/testing.md).
  If `.godot/` is missing, run `godot --headless --import` first.
- Fast tests, after every change to src/, data/ or tests/ (about 1.5 min):
  `godot --headless --fixed-fps 60 res://tests/run_tests.tscn -- --only=unit,title`
- Full tests before calling a feature done (suites unit, title, game, tutorial), in parallel, one
  process per CPU, each with its own user folder (3 to 4 min on 2 CPUs):
  `python3 tools/run_tests.py` (or in one process, about 5 min:
  `godot --headless --fixed-fps 60 res://tests/run_tests.tscn`)
- One test, again: `... -- --test=game.pacts --seed=N` (the seed is printed first; `--list`
  names the tests, `--timings` times them; docs/testing.md "Fast").
- `tools/run_tests.py` fails on failed checks and unexpected engine `ERROR:` / `SCRIPT ERROR:`
  lines; only the documented shutdown leak diagnostics are exempt. Direct Godot runs still need
  their output inspected (docs/testing.md). Failures print as `FAIL: ...`.
- Translations: `python3 tools/i18n/extract.py` after adding texts, then fill the French in
  `locale/strings.csv`; `python3 tools/i18n/extract.py --check` must pass.
- Save references: after content changes run `python3 tools/saves/build_catalog.py`;
  `python3 tools/saves/build_catalog.py --check` must pass. Keep historical aliases.
- Balance: the `balance` suite is opt-in and slow, and some of its checks fail on purpose
  (`FAIL (KNOWN ...)`). The measuring tools are described in docs/balance.md.

## Code rules (what you would not guess)

- Godot 4 APIs only (`await`, `@export`, `@onready`, typed arrays, `signal.emit()`), never Godot 3.
- Type everything; `class_name` for reusable types; tabs; `##` doc comment on each class and on
  non-obvious members, plain English, explaining why. Match the surrounding code.
- Data-driven: content and tuning numbers live in `data/**/*.tres`, never hard-coded in scripts.
  New content = a resource plus its registration (usually `data/content_db.tres` or an act); see
  docs/adding-content.md. New behaviour = a new `Effect`, `Passive`, `MonsterTrait` or `HazardDef`
  subclass rather than another branch in `Actor`, `Monster` or `World`.
- Ask `FloorRules` for a floor's numbers; never multiply difficulty x depth x event x curse yourself.
- UI listens to `Events` and signals and never drives gameplay. Touch controls only press input
  actions. A text naming a control has a touch version and a keys/gamepad one (`Prompts.pick()`,
  `{action}` codes); a new window built on `RpgWindow`/`RpgDialog` works with keys by itself
  (MenuNav, design/interface.md "Devices").
- Every player-facing text goes through `tr()`, as a whole sentence with `%d` or `{name}` codes,
  never glued pieces. Data texts stay English and are translated where shown. Say Health, Damage,
  Armor (never HP, ATK, DEF).
- Names, lore and flavor lines speak in the Well's dark-fantasy voice (docs/lexicon.md); rules and
  numbers stay plain.
- Ids kept the first names when the names changed: difficulty `easy`/`normal`/`hard` is shown as
  Pilgrim/Keeper/Martyr, rank `epic`/`shiny` as Fell/Celestial, perk `multishot` as Hydra's Quiver.
  Code, data and tool options use the id; texts and docs use the `display_name`. Never rename an id
  (saves, records and data refer to it).

## Files

- Resources reference each other by `res://` path (no `uid=`). Don't move or rename files unless asked.
  If you must, update every reference, and move a script's `.gd.uid` with it.
- Edit `.tres` / `.tscn` by hand carefully: keep `[ext_resource]` ids and paths consistent.
- Never edit `.godot/` or `locale/*.translation` (generated). Commit `.uid` and `.import` files.
- Never touch players' saves or settings; tests use empty paths. Don't change
  `config/custom_user_dir_name`.
- Never commit signing keys (`*.keystore`, `*.jks`) or their passwords.

## Done means

- Tests pass and the output has no new engine errors; `extract.py --check` passes.
- No GDScript warnings: run `python3 tools/lint/gd_warnings.py` (exit 0; fixes: docs/conventions.md,
  "No GDScript warnings").
- A rule fix or new mechanic has a check (`check(condition, "the rule")`) in tests/suites/.
  Never weaken or skip a check.
- The docs/design/ page about the change is updated in the same commit, along with the data texts
  that state a changed number. Balance changes get an entry in docs/balance-log.md.
- Headless tests don't show what the game looks or feels like: say what you could not check.
- Commit messages: what changed for the game on the first line, why in the body.
- **The roadmap is updated in the same commit** (see "The roadmap" below): the cards you worked
  on moved (In Progress, Review, Done), a card added for every new todo, bug or idea found on
  the way. Never end a task with the roadmap stale.

## The roadmap (Godoban board)

The project's todos live in `godoban_boards/puits_roadmap.json`, a Godoban board (the editor
plugin's tab; `godoban_boards/boards.json` is its registry). It is the one list of what is
planned, in progress and done: read it before starting, and keep it true.

- **Before work:** find the card(s) for the task and set `"status"` to `"in_progress"` (no card:
  add one). Statuses: `backlog`, `todo`, `in_progress`, `review` (done, waiting for the user to
  play-test or approve), `done`.
- **After work:** move the cards; add cards for everything left open, found broken, deferred or
  proposed (bugs, follow-ups, "not verified" items, ideas the user hasn't approved: epic "Idées de
  contenu", status `backlog`). Remove nothing: done cards stay in `done`.
- **Card format:** the board is in French (it is for the user). `id` = `"task_<next_id>"`, then
  increment the board's `next_id`; `epic_id` from the board's `epics` (add an epic the same way
  with `"epic_<next_id>"` if none fits); `priority` `low`/`medium`/`high`/`critical`; `tags` from
  the board's `tags` list (add new ones there too); `created_at`/`updated_at` Unix seconds,
  `updated_at` refreshed on every change; `due_date` null unless the user gives one. Keep the
  JSON pretty-printed (2 spaces, UTF-8, not ASCII-escaped): it is diffed in git.
- **The editor holds the board in memory** and saves it on every change: edit the JSON with the
  Godot editor closed, or tell the user to restart it, or your edit may be overwritten.

## Where to look

| Need | Page |
|---|---|
| Layout, how systems fit, autoloads | docs/architecture.md |
| Code rules in full | docs/conventions.md |
| Adding content | docs/adding-content.md |
| Tests, debug panel | docs/testing.md |
| Languages, French glossary | docs/translating.md |
| Naming, lore, the game's voice | docs/lexicon.md |
| The story's canon: the antagonist, places, characters, what is revealed when | docs/lore.md |
| Visual effects: the pixel grid, elements and their kits, reviewing an effect | docs/vfx.md |
| Performance: no per-frame allocations in hot paths, redraw on change, the benchmark probe | docs/performance.md |
| Balance tools / past passes | docs/balance.md / docs/balance-log.md |
| Android and Windows builds | docs/android.md |
| Online leaderboards and gameplay statistics (Talo): the access key, the dashboard, the anti-cheat | docs/online.md |
| Privacy: consent, the policy and its placeholders, Talo retention, Play Data safety, deletions | docs/privacy-ops.md |
| What each system does | docs/design/ (dungeon, monsters, builds, loot, progression, interface, presentation) |
