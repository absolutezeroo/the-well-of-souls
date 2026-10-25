# Online leaderboards and gameplay statistics (Talo)

The game's two online features, both on [Talo](https://trytalo.com), an open-source game backend,
and both off until the player turns them on: the **leaderboards** and the **gameplay statistics**
(Talo's events). What the player sees is in
[design/progression.md](design/progression.md#online-leaderboards) and
[design/interface.md](design/interface.md#privacy-and-credits); the privacy rules, the dashboard's
retention settings, the Play Console form and deletion requests are in
[privacy-ops.md](privacy-ops.md); this page is how they are built, how to set them up and what
they protect against.

**The rule: no Talo call at all before the player's choice.** Until the player answers "Publish my
scores" (or turns it on in Options) and/or accepts the statistics, or sends a message from **Send
feedback** (below), the game makes no request, not even to read a board or the remote settings,
and makes no id. The tests check it (`LeaderboardTests`, `PrivacyTests`:
the fake server counts its calls).

## How it is built

- **REST, not the Talo plugin.** The game talks to Talo's HTTP API with `HTTPRequest`
  (`TaloBackend`, `src/online/talo_backend.gd`): a few endpoints (identify a player, set its name,
  add an entry, list entries, send events, add to a game stat and read them, send a feedback
  message). The official Godot addon (MIT, `TaloDev/godot`) was read and left
  out: about 7,700 lines for 14 services we don't use, an autoload that takes over quitting
  (`set_auto_accept_quit(false)`), opens a websocket at start, writes a `settings.cfg` into
  `res://` on first run (read-only in an export), prints `push_error`s on every failed request
  (noise in the tests and on a phone without network) and keeps its own replay queue. Ours is
  about 330 lines for every endpoint the game uses (each service around it, 200 to 500), works the
  same on Android and Windows (Godot's own TLS and CA list), and fails quietly (a body that isn't
  JSON, a captive portal's page, is read as nothing without an engine error).
- **`OnlineSession`** (autoload, `src/autoload/online_session.gd`): what every online service
  shares, below in [The shared session](#the-shared-session): the backend, the device's player,
  the consent gates, the clock.
- **`Leaderboards`** (autoload, `src/autoload/leaderboards.gd`): listens for `Events.run_ended`
  (a `RunSummary` made by `RunRecords.report_end()` when the Game gives the souls: a death, or a
  win), queues the scores the boards take, sends them, retries every `retry_seconds` while there
  is no network (and when the app comes back to the front), and reads the boards for the page
  (`load_board()`). UI asks it; it never asks the UI.
- **Backends** (`BoardBackend`, `src/online/board_backend.gd`): the base class is the offline one
  (every call answers UNAVAILABLE); `TaloBackend` is Talo; the tests use `FakeBoardBackend`
  (`tests/support/`), a server in memory that acts like Talo's boards. A new service (Google Play
  Games, Steam) would be another subclass.
- **Boards are data**: `LeaderboardDef` resources in `data/leaderboards/boards/`, listed in
  `data/leaderboards/leaderboards.tres` (`LeaderboardsConfig`, with the page's sizes, the retry
  delay, the pseudonym's rules and refused words, and the limits of a plausible run). A board has
  its id, its name and rule (translated), its Talo internal name, what it ranks (`Score`), which
  way, its period (daily, weekly, all time), which runs it takes (the daily run's official attempt
  or normal runs), a difficulty and ascension filter, `submits` (scores are sent to it) and `shown`
  (a tab on the page). Adding a board: a file there, its line in `leaderboards.tres`, the same
  board in the dashboard (below).
- **Its own file**: `user://leaderboards.json` (version 3) holds the pseudonym, "Publish my scores
  online" (off until chosen; a file from before, version 1, is asked again) and the queue. The
  device's random id (shown in Options > Privacy, for a deletion request) and the Talo player id
  it became are the session's, in `user://online.json` (until version 2 they were in
  `leaderboards.json`: the session takes them from there once). Never the player's save or the
  Profile.
- **Periods.** Each daily (weekly) entry carries its day (week) as a prop, `day` = the UTC day
  number of `DailyRun.today()` (`week` = `QuestBoard.week_index()`); the page asks Talo for one
  day's entries (`propKey=day&propValue=<day>`, archived ones with `withDeleted=1` for
  yesterday). The board itself refreshes daily, so "one entry per player" means one per day.
  A score that could not be sent before its day ended is dropped: sent the next day, Talo would
  count it on the new day.

## Names and tags

On the boards a name is **the pseudonym and a tag**, Discord-style: "Clayton#4821". The tag
stops anyone from taking someone else's name: two players may both be "Clayton", but each has
their own four digits, and nobody can type them (decided by Clayton, 24 October 2026).

- **What the tag is**: `PlayerName.tag_of(identifier)`, four digits (0000 to 9999) from the
  SHA-256 of a fixed salt (`PlayerName.TAG_SALT`) and the player's **online id**, the alias
  identifier Talo keeps for the player (the device's random id, `OnlineSession.device_id`). Not
  Godot's `hash()`, which an engine version may change; never change the salt or `TAG_DIGITS`
  (every player's tag would change). The same device keeps the same tag for good (across restarts
  and versions; a "Delete my online data" makes a new id, so a new tag). Four digits of a hash
  can't give the id back, and the id is already public in Talo's answers (`playerAlias.identifier`
  on every entry): the tag leaks nothing new. The raw id is never shown on a board (only in
  Options > Privacy, for a deletion request).
- **Where it lives**: nowhere on the server. It is **worked out where a name is shown**, from each
  entry's alias identifier (`BoardBackend.Entry.identifier`, read by `TaloBackend._entry()`;
  `Entry.tag()`, `Entry.shown_name()`), so entries sent before the tags get one too, and a tag can
  never be forged by typing it: the player prop `name` and each entry's `name` prop stay the bare
  pseudonym, and the dashboard's **Display name prop key** stays `name` (the dashboard shows names
  without tags: fine). An entry with no identifier (none seen from Talo) takes its tag from its
  alias id instead.
- **The player's own tag** (`Leaderboards.tag()`, `tagged_name()`) uses the same function on the
  device's id, the one Talo has as the alias identifier, so it matches the tag on the player's
  entries. Before the player chose to publish, the question already shows it: the id the device
  will take is drawn in memory (`OnlineSession.preview_device()`), never written nor sent, and
  `device()` adopts it when a feature is turned on, so the tag shown before the choice is the one
  kept.
- **No `#` in a name**: `PlayerName.problem()` refuses it (`Problem.TAG_SIGN`, "No # in a name:
  the game adds your number after it."); a name read from the server has its `#` taken out
  (`PlayerName.readable()`) before its own tag is added, so an old or forged "Clayton#4821" shows
  "Clayton4821#0377".
- **Shown**: every row of a board and the player's place (the narrow column's rows on two lines,
  the name and tag alone on the first, so the longest name and its tag, 16 + 5 characters, read
  whole: LeaderboardTests at 2340x1080, 2548x1296 and 1280x720, English and French), the page's
  "You appear as Clayton#4821", the question (under the field), Options > Privacy, the deletion
  request's e-mail and the feedback's signature (its `name` prop carries the tag: the feedback is
  anonymised, the tag says which Clayton wrote, only when the player signs). **Not** on the
  Nameless Keeper's boss bar or codex: he is the player's own former hero, shown only on this
  device, so his title is the name alone (design/monsters.md).
- **The default name** is now "Soul" (`LeaderboardsConfig.default_name`), "Soul#4821" with its
  tag; before the tags it was "Soul" and four digits of Godot's hash of the id (a player who kept
  that name keeps it).
- **Collisions**: 10,000 tags, so two players under one name may, rarely, share a tag too (one
  chance in 10,000 per pair of same-named players). Not a security: a moderation case for the
  dashboard, like any name.

## The shared session

Six autoloads talk to Talo or keep an online choice: `Leaderboards`, `Privacy`, `Telemetry`,
`WorldStats`, `RemoteConfig`, `Feedback`. What they share is written once:

- **`OnlineSession`** (autoload, listed first of them in `project.godot`): the backend (`TaloBackend`
  with a key, the offline `BoardBackend` without), the device's random id and its Talo player
  (`user://online.json`), and `identity()`: **one identify at a time for every service** (a
  service asking while one is on its way waits for that answer). A refused identify (a bad key, a
  captive portal's page instead of Talo's answer) is answered again without a call for
  `refused_identity_seconds`, and every service treats it as "no network": its queue waits and it
  tries again later. The **consent gates** live here and nowhere else: `scores_allowed()` (published,
  not switched off), `scores_published()`, `statistics_allowed(debug_builds)` (the statistics'
  consent, a server, the kill switch, and for the world counters a release build), and
  `online_chosen()` (either feature on: what reads the server without the player's data). Also the
  one **clock** (`now()`, `fake_now` for the tests) and `release_mode` (what only a release build
  does; the tests turn it on to run those paths). Its numbers are data:
  `data/online/online_session.tres` (`OnlineSessionDef`).
- **`PersistedQueue`** (`src/online/persisted_queue.gd`), one per service as a child: its file,
  versioned and written atomically (`SafeFile`), a write that would change nothing skipped (an
  alt-tab writes no file); a missing, damaged or **newer** file read as empty (a downgraded game
  trusts nothing it doesn't know: every choice off, asked again), an older one migrated by the
  service; a bounded list (the oldest dropped); one flush at a time with a token a reset makes
  stale (a flush started before a test's reset never writes over the next test); the retry timer,
  waiting the service's `retry_seconds`, then twice that after each failure in a row, up to
  `max_backoff` times. In a test launch every online file starts with no path, so the player's
  real files are never read or written while the autoloads start.
- **Start-up order.** Godot makes every autoload (their `_init()`) before any `_ready()`. Each
  online service reads its data and its file in `_init()` (`boot()`) and asks no other service
  there; from the first `_ready()` on, any may ask any other, whatever their order. What needs
  another service at start-up (WorldStats dropping a killed run's share that the consent no
  longer allows) is in `settle()`, from `_ready()`. (Before this, WorldStats asked RemoteConfig's
  kill switch before RemoteConfig had read its data: a script error at every launch of a release
  build with the statistics accepted, and the share of a run killed in the background lost.)
- **RemoteConfig at start-up** checks a stored curse or event id for its form only; the content
  (`content_db.tres`, the whole game's data) is loaded at the first safe point that needs it, not
  while the splash shows.
- **Files and versions**: `online.json` 1, `leaderboards.json` 3 (2: the id moved out; 1: asked
  again), `privacy.json`, `telemetry.json`, `world_stats.json`, `remote_config.json`,
  `feedback.json` 1. Each version is read: a newer file is not trusted, an older one migrated.
- **The tests** reset the whole layer with `OnlineSession.use_all_for_tests(fake)` (every service's
  `use_for_tests()`: no file, no timer, no flush in flight); a suite's `Leaderboards.use_for_tests(fake)`
  puts the session on its fake server.

## The boards in Clayton's Talo game

Already created (23 October 2026), all with **unique entries** (one per player), no unique-by-props:

| Internal name | Sort | Refresh | Sent to | Shown |
|---|---|---|---|---|
| `daily-challenge` | descending | daily | yes (the Dawn Knell's official attempt) | yes |
| `depth-easy`, `depth-normal`, `depth-hard` | descending | never | not yet (`submits = false`) | no |
| `fastest-win-easy`, `fastest-win-normal`, `fastest-win-hard` | ascending (milliseconds) | never | not yet | no |
| `ascension` | descending | never | not yet | no |
| `vigil` | descending | never | not yet (La Veille isn't in the game) | no |

Turning one on is data: `submits = true` (then `shown = true` once it has entries) in its file.
Never rename an internal name: the data and the dashboard must keep matching.

**Midnight.** Talo empties a daily board at its server's midnight (its `archive-leaderboard-entries`
task at 00:00, `isToday()` in the server's time zone; Talo's own tests run in UTC and the cloud
service is expected to be UTC, but that can't be checked from the game). The game doesn't depend
on it to show a day (it filters by the `day` prop). If Talo's midnight were not UTC, a score sent
between the two midnights could replace the previous day's entry of the same player instead of
making a new one.

## Setting it up (what Clayton does)

What is left: **only the key file**. For reference, the whole setup:

1. **Game**: on [dashboard.trytalo.com](https://dashboard.trytalo.com), create the game (done).
2. **Access key**: *API keys* > create a key with only these scopes: **Players: read and write**
   (`read:players` to identify the device's player, `write:players` to set its name),
   **Leaderboards: read and write** (`read:leaderboards`, `write:leaderboards`), **Events: write**
   (`write:events`, the gameplay statistics), **Game Stats: read and write** (the world counters),
   **Game Feedback: write** (the players' messages) and **Game Config: read** (the remote
   settings). Nothing else (done).
3. **Display name** (recommended): *Game settings* > **Display name prop key** = `name`. The
   pseudonym is a player prop called `name`: with this set, a renamed player shows the new name on
   every entry. Without it the game falls back on the name copied into each entry.
4. **Profanity**: if *Game settings* offers it, turn on Talo's profanity filter for props (the
   server's own check, after the game's: `blockPropsProfanity` in Talo's code).
5. **A new board** (later): *Leaderboards* > create one with the internal name of its
   `LeaderboardDef` (`talo_name`), the sort mode matching `higher_first` (descending when true),
   **Unique entries** on, **Unique by props** off, refresh **daily** for a daily board, **weekly**
   for a weekly one, **never** for all time. Then `submits = true` in its file.
6. **The key in the game**: copy `online/talo.cfg.example` to `online/talo.cfg` and paste the key
   as `access_key`. Git ignores this file (`.gitignore`): **never commit it**. The export presets
   pack it into the builds (`include_filter="online/talo.cfg"`). In a CI, write the file from a
   secret before exporting, e.g. `printf '[talo]\naccess_key="%s"\n' "$TALO_ACCESS_KEY" >
   online/talo.cfg`. On a computer the environment variable `TALO_ACCESS_KEY` also works at run
   time, without the file. No key (or an empty one): the game is offline, the page says the
   leaderboards are unavailable, nothing fails.

The key ships inside the game, like every client key: anyone can dig it out of an APK. Its scopes
are what limits the harm (no deleting, no reading saves), which is why it has only the scopes
listed in step 2.

Builds from the editor (debug builds) send `X-Talo-Dev-Build: 1`: their players and entries are
**development data**, kept apart (orange) in the dashboard and hidden from release builds; debug
builds see them (`X-Talo-Include-Dev-Data: 1`).

## What it protects against (honestly)

- **In the game**: no score from a debug run (`DebugCheats.debug_run`), a practice attempt, the
  tests, or a player who turned "Show me in the leaderboards" off. Before a run is queued,
  `RunSummary.check()` refuses what no real run does: a score that isn't what its numbers make
  (`DailyRun.score()`), floors cleared faster than `min_seconds_per_floor`, more kills or gold
  than floors hold, more bosses than floors, a win without its time.
- **On the server**: one entry per player and day (unique entries: only a better score replaces
  it), and every entry carries the run in short as props (`v` the game's version, `day`, `seed`,
  `diff`, `asc`, `depth`, `kills`, `bosses`, `gold`, `won`, `time`, `weapon`, `relic`, `name`), to
  read in the dashboard. A suspicious entry is **hidden or deleted by hand** there (Leaderboards >
  the board > the entry); a cheater's player can be deleted.
- **Not more.** The client can be modified and the key extracted: anyone determined can post any
  score. Talo's request signing (`X-Talo-Signature`) would make it harder; it is not used.

## Gameplay statistics (Talo events)

With the player's consent only (`Privacy.analytics_allowed()`: 16 or older, accepted, for the
current consent version), each run that ends sends what it was, to balance the game and find its
bugs. Built so that the game never depends on it:

- **`RunTelemetry`** (`src/online/run_telemetry.gd`) follows one run from `Events.run_started`
  (the Game emits it once the hero is made): it listens to the hero's signals (skills, potions and
  the heal they gave, charged blows, gold, dismantling, dropping) and the Events bus
  (`actor_damaged` and `hit_dodged`, emitted by `Actor.take_hit()`; boss fights, perk choices,
  purchases, pacts, secrets, the Deeps and the Threshold), counts in memory, and at the end makes
  the `run_end` event's props (`summary()`). Damage is sorted by element (`HitInfo.element`) and
  source (`HitInfo.via`: the acting skill, perk, rune or item when the hit was made, a shot's when
  it was fired; else status, trap, fall..., the weapon or a monster).
- **`Telemetry`** (autoload, `src/autoload/telemetry.gd`) makes a tracker per run; at
  `Events.run_ended` it queues the run's events (if consented, never for a debug run), keeps only
  the fields the catalog lists, and sends them in batches through the session's server
  (`OnlineSession.identity()`, `BoardBackend.send_events()`: `POST /v1/events` with the
  `X-Talo-Alias` header; the same device id, so one player on Talo). Queue in
  `user://telemetry.json` (at most `max_queue` events, the oldest dropped), retried every
  `retry_seconds` without network, sent at a run's end and when the app goes to the background.
  Refusing or withdrawing drops what waited. Debug builds' events are dev data
  (`X-Talo-Dev-Build: 1`), like the leaderboards'.
- **The catalog is data**: `data/online/telemetry.tres` (`TelemetryDef`, `TelemetryEventDef`): each
  event, on or off, its purpose and its fields (`skill.*` stands for each skill's). A field not
  listed is dropped before it is queued; turning one off is data.
- **Talo's limits**: a prop key at most 128 characters, a value at most 512
  (`MAX_KEY_LENGTH`/`MAX_VALUE_LENGTH` in the backend's `src/entities/prop.ts`); `sanitize()`
  keeps every event inside (a long list loses its last items at a comma) and caps the props
  (`max_props`). Never a `META_` prop: Talo copies those into the player's props, which its API
  shows to anyone reading a board.
- **A run left for the title** (pause > Save and quit, or the window closed: `Events.run_left`,
  for good) sends its `run_end` at once, `result` "abandoned" (or "victory" after a win, in the
  endless floors) and `quit` 1, with the build and every count so far, and the events waiting for
  it (boss fights, perks...). **The app put in the background** (Android's pause, a lost focus)
  writes the same end as a draft in `user://telemetry.json`: dropped when the app comes back,
  queued at the next launch if the app was killed there (`Telemetry.draft`).
- **A resumed run counts from its start**: the tracker's counts go into the run's save
  (`Events.run_saving` -> `RunState.telemetry` -> `run.json`, local only) each time it is saved,
  and come back with it (`RunTelemetry.from_data()`), with the same `run` id; `resumed` counts the
  resumes; `partial` 1 marks a run resumed from a save made before the counts were kept (they
  start at the resume). Nothing leaves the device without consent: the save is local.
- **Reading it in the dashboard (no double count)**: a run left then resumed sends a `run_end` at
  each quit and one at its end, all with the same `run` id, each covering everything since the
  run's start. Count runs as distinct `run` ids and keep each id's **latest** `run_end` (highest
  timestamp): its numbers are the whole run's. `quit` 1 on that latest one means the run was
  never finished (or not yet). A run is won if **any** of its `run_end`s says `victory`: a hero
  who won and then died in the endless floors ends on `result` death. Never sum `run_end` events of one id. The other events (`boss`,
  `perk_*`, `purchase`, `pact`) are sent once each, with whichever `run_end` follows them.
  Sending at every quit, rather than only when the save is thrown away, keeps the runs of players
  who never come back (or uninstall), and needs nothing kept on the device after the run.

| Event | When | Fields |
|---|---|---|
| `run_end` | a death or a win (again at the real end after the endless floors); a run left for the title or the app closed (`result` abandoned, `quit` 1; again at its real end if resumed) | version, run id, resumes (`resumed`), counts missing before a resume (`partial`), left without ending (`quit`), OS, screen, input device(s), difficulty, ascension, daily/official, oath, depth, result, cause, killer, death floor, time, level, kills, bosses; the build (weapon id, rarity, element, runes, affixes; head, body, armor runes; awakened families, relics, perks with levels, skills); per skill uses and damage; potions drunk (in a boss fight, the average Health ratio when drunk, per potion), consumables left; rolls, hits dodged by rolling, dodge rate, hits taken; damage dealt and taken in total, by element and by source; biggest hit, crits, charged blows; time per floor; secrets, trap hits, falls into the Deeps (escaped), Threshold trials (won); gold earned and spent, souls, items dismantled and dropped |
| `boss` | a boss fight ends | boss, time, damage taken, hits taken, last phase, outcome (won, died, left, next_form), potions |
| `perk_offered` / `perk_picked` / `perk_banished` | a choice dealt (or rerolled) / taken / a banish | the perks, the perk (and its level) |
| `purchase` | bought from the merchant | item, rarity, price |
| `pact` | a pact ends | pact, outcome (kept, broken) |

Every event also carries `v` (the game's version), `run` (a random id per run) and `depth`.

## Reading the statistics (tools/stats)

Talo's dashboard charts one event at a time; the questions that matter (which weapon wins, which
boss blocks, do players drink too late) need the runs put together. `tools/stats/` is a dev tool
(Python 3, standard library only, nothing in the game) that reads a **data export** and makes one
self-contained HTML page, in French, readable on a phone:

```
python3 tools/stats/build_dashboard.py ~/Downloads/export-<game>-<date>.zip -o stats.html
python3 tools/stats/build_dashboard.py exports/ --since 2026-11-01 --json stats.json -o stats.html
python3 tools/stats/build_dashboard.py prod.zip --include-dev --dev-export with_dev.zip -o stats.html
python3 -m unittest discover tools/stats      # its tests
```

- **How the events leave Talo.** Only through the dashboard's export: Talo's admin API (the
  admin key we used for the world counters) has routes for players, leaderboards, game stats,
  live config and channels, and **none that reads events or starts an export** (checked in
  TaloDev/backend: `src/routes/admin/*`, `AdminAPIKeyScope`); the export route
  (`POST /games/:id/data-exports`) takes a logged-in dashboard user, an admin with a confirmed
  email, and the ZIP is **mailed** (attached, or a download link). The game's own key can only
  write events. So the export is a step done by hand (below), and the tool reads its ZIP.
- **The export's format** (backend `dataExportProcessor.ts`): `events-1.csv` (then `-2`... per
  100,000 rows) with `id, name, playerAlias.id, playerAlias.service, playerAlias.identifier,
  playerAlias.player.id, createdAt, updatedAt` and a `props.<key>` column per prop key the game
  ever sent. **No dev column**: the export holds dev data or not depending on the dashboard's
  "Dev data" switch when it is made. To look at dev runs, make a second export with dev data on
  and pass it as `--dev-export` (its events missing from the normal one are the dev ones), or name
  the dev devices with `--dev-player <device id>` (Options > Privacy shows it).
- **Talo's export bug.** A cell is filled with the first prop whose key the column name *ends
  with*, so `props.skills` held the run's `kills` (the game sends its props sorted, `kills`
  first), and a `boss` row shows its boss under `props.potions_boss`. The game now sends the
  skills held as **`skill_ids`**, and a check (privacy_tests) keeps it so: no field of an event
  ends another one, and a real key ending another (`src_out.weapon`, `weapon`) must sort before
  it. The tool keeps only each event's catalog fields (`data/online/telemetry.tres`, plus the
  old `skills` of older exports: `talo_export.LEGACY_FIELDS`), drops a cell equal to a shorter
  key's value, and, for an old run whose `skills` was lost, rebuilds them from
  `skill.<id>.uses`/`.dmg` (the skills used, not those held).
- **What the tool counts**: runs as distinct `run` ids with their latest `run_end` (above),
  abandoned runs apart (never in a win rate), events sent twice counted once (same name, player,
  time and props). Every rate shows its sample and a 95% Wilson interval; rows under
  `--min-sample` finished runs (default 10) are grey and never ranked above the others; build
  combinations need `--min-combo` runs (5). The build is the one the run *ended* with
  (survivorship: deep runs gather more perks and relics).
- **The page**: overview (runs, players, win rate, abandons), difficulty and ascension, depth
  reached and the death rate of each floor (boss floors marked), deaths by cause, killer and act,
  the bosses (fights, win rate, time, damage and hits taken, potions, phase reached at death),
  weapons, their rarity and element, head, body and both, runes, skills (results and use),
  perks and relics (offered, picked, pick rate, banished, results), awakened families, oaths,
  pacts, the best combinations (weapon + a skill, + armor, + a relic, + every skill), potions
  (drunk per run, in boss fights, the Health when drunk, left unused at death), the roll (rolls a
  minute, dodge rate, win rate by dodge rate, by act), damage by element and source, time per
  floor, the economy (gold, purchases, souls), devices. Filters (version, difficulty, dev data)
  are computed beforehand for every combination and embedded; the page needs no network, works
  light and dark, and holds no player id (it can be shared; the export can't).
- **`--json`** writes the same numbers for scripts (the `game-balancer`: docs/balance.md).
- **Tests**: `tools/stats/test_stats.py` on `fixtures/edge_events.csv` (quoting, the export bug,
  a resumed run, a boss's next form, a batch sent twice) and on a synthetic export made by
  `fixtures/make_fixture.py` (fixed seed, the catalog's events, written the way Talo writes them:
  props must come back as sent). `python3 tools/stats/fixtures/make_fixture.py demo.zip` makes
  one to try the page.

### Sortir les données de Talo (à faire par Clayton)

1. Sur [dashboard.trytalo.com](https://dashboard.trytalo.com), choisir le jeu, puis le menu
   **Services** > **Export** (« Export your data »; adresse directe `dashboard.trytalo.com/exports`).
   Il faut être administrateur du jeu, avec une adresse email confirmée.
2. En haut de la page, l'interrupteur **Dev data** : le laisser **désactivé** (« not enabled »)
   pour n'avoir que les vrais joueurs.
3. Sous *Create data export*, cocher **Events** (c'est tout ce que l'outil lit; *Players* et
   *Player aliases* ne servent pas). Cliquer **Create**.
4. Talo envoie un email quand l'export est prêt (un ZIP en pièce jointe, ou un lien de
   téléchargement). Le nombre d'exports par mois dépend de l'offre Talo.
5. Garder le ZIP **hors du dépôt** (il contient les identifiants des appareils : jamais dans git),
   puis lancer :
   `python3 tools/stats/build_dashboard.py chemin/vers/export-....zip -o stats.html`
   et ouvrir `stats.html` (sur l'ordinateur ou le téléphone). Le ZIP peut être supprimé ensuite.
6. Pour voir aussi ses propres parties de test : refaire un export avec **Dev data** activé et
   ajouter `--include-dev --dev-export chemin/vers/export_dev.zip` (la page aura un interrupteur
   « Données dev »).

## World counters (the Well's Toll)

Numbers every player adds to, kept by Talo as **global game stats** (`/v1/game-stats`): the
world's total, and each player's own share. Shown on the title screen (a line at the bottom that
turns every `title_line_seconds`, from `title_min_count`) and on the Leaderboards page's last tab,
**The Well's Toll** / *Le Tribut du Puits* (every counter, the world's number, the player's share).

- **`WorldStats`** (autoload, `src/autoload/world_stats.gd`) listens to the Events bus during a
  run and counts in `pending`: `monster_killed` (not a summoned one), `boss_defeated`,
  `depth_changed` (deeper than the run's deepest so far: a resumed floor isn't counted again), the
  hero's `consumable_used` (a healing potion), a death at `run_ended`, a new Dawn Knell at
  `run_started` (not a resumed one), `ending_chosen` (emitted by the Game when the ending is picked,
  after `run_ended`) and `souls_offered` (`Profile.buy()`, at the shrine). At `run_ended` (and
  `ending_chosen`, `souls_offered`) the counts join the queue, each **capped to its counter's max
  change**, and go.
- **A run left without ending** (`Events.run_left`, the gameplay statistics' rules): quit to the
  title or the app closed, what it counted so far goes at once; put in the background, it waits
  as a `draft` in the file, dropped when the app comes back, queued at the next launch if the app
  was killed there. Each run has a key; its counts so far go into its save
  (`Events.run_saving`: `RunState.world_stats`) and what of it was queued stays in the file per key
  (`sent`, the last `KEPT_RUNS`). A resumed run takes its counts back and only queues what goes
  past what was sent (resumed from a save older than what was sent, it counts nothing twice);
  counts its save had that never went (the app gone without a word) go at its end.
- **One update per counter**, never one call per kill: `PUT /v1/game-stats/{internalName}`
  `{change}` with the `X-Talo-Alias` header (the leaderboards' player). A share past the max
  change goes in parts. Queue in `user://world_stats.json` (`queue`, `mine`: the player's
  share, `sent`, `draft`), tried again every `retry_seconds` without network, at a run's end
  and when the app comes back. A counter the server refuses (unknown, past its max change) is
  dropped.
- **Reading**: `GET /v1/game-stats` (every stat with its `globalValue`, no player needed) at most
  every `refresh_seconds` (300), kept in memory only (offline, nothing shows); with the statistics'
  consent also `GET /v1/game-stats/player-stats` (the player's own totals; the server caches it 30
  s, so the larger of it and what was sent is shown). Numbers by language: `NumberText.of()`
  ("1,284,302", "1 284 302" with a narrow no-break space, which the font has).
- **Consent** (privacy-ops.md): sending needs the **gameplay statistics' consent**
  (`Privacy.analytics_allowed()`); reading the world's numbers needs either online feature turned
  on (published scores or the statistics). Before any choice: no call at all.
- **Never from a debug build.** Talo's PUT adds the change to the stat's global value whatever
  `X-Talo-Dev-Build` says (`stat.incrementGlobalValue()` in `src/routes/api/game-stat/put.ts`; only
  the dashboard's view recalculates without dev players): an editor run would show in every
  player's numbers. `WorldStats.debug_builds_send` is off (the tests turn it on for their fake
  server, or run the release path itself with `OnlineSession.release_mode`). Never from a debug run (`DebugCheats.debug_run`, `RunSummary.debug`), nor the tests.
- **The counters are data**: `data/online/world_stats.tres` (`WorldStatsDef`, `WorldStatDef`):
  Talo's internal name, the name on the page and the title line (`{count}`), what feeds it
  (`Feed`), the ending for an ENDING feed, `max_change`, on or off.

### The counters in Clayton's Talo game

Created on 23 October 2026 with the admin API (`POST /admin/v1/game-stats`, scope `write:stats`):
all **global**, default 0, **min value 0**, no max value, **no time between updates** (0).

| Internal name | Talo id | Max change | Fed by | Shown as (EN / FR) |
|---|---|---|---|---|
| `demons-slain` | 5220 | 5000 | KILLS | Demons slain in the Well / Démons abattus dans le Puits |
| `wardens-laid-to-rest` | 5221 | 200 | BOSSES | Wardens laid to rest / Gardiens rendus au repos |
| `souls-claimed` | 5222 | 50 | DEATHS | Souls claimed by the Well / Âmes réclamées par le Puits |
| `floors-descended` | 5223 | 2000 | FLOORS | Floors descended / Étages descendus |
| `potions-drunk` | 5224 | 1000 | POTIONS | Potions drunk in the deep / Potions bues dans les profondeurs |
| `last-knells-rung` | 5225 | 50 | ENDING `ring_the_bell` | Last Knells rung / Derniers Glas sonnés |
| `nameless-keepers` | 5226 | 50 | ENDING `take_his_place` | Nameless Keepers before the seal / Gardiens Sans Nom devant le sceau |
| `dawn-knells-answered` | 5227 | 50 | DAILY_RUNS | Dawn Knells answered / Glas de l'Aube entendus |
| `souls-offered` | 5228 | 1000000 | SOULS_OFFERED | Souls offered to the Tree / Âmes offertes à l'Arbre |

**Adding a counter**: a `WorldStatDef` in `world_stats.tres` (its texts translated: `extract.py`
reads `display_name` and `title_line`), then the same stat in the dashboard (*Stats* > create, or
the admin API): the same internal name, **Global** on, default 0, min value 0, max change at
least the def's `max_change`, time between updates 0. A new kind of event to count is a new
`Feed` and its listener in `WorldStats`. Never rename an internal name. The game's key needs
**Game Stats: read and write** (`read:gameStats`, `write:gameStats`; already on it).

Smoke test (23 October 2026, `_tool/world_stats_smoke.gd`, dev data): a test player
`world-stats-smoke-test`, a PUT of change 0 on `demons-slain` (0: a dev build's change would count
in the world's value), the list read back (every counter at 0), the player's own totals read, an
unknown stat and a change past the max refused (400).

## Remote settings (Talo game config)

A few values the game takes from Talo's **game config** (the game's live config: key/value
texts), so a balance hotfix, a weekend event, the Dawn Knell's omen, a message of the day or a
kill switch needs no update. **The game's own data stays the default**: no network, no key, no
online choice, no value or a bad one, and the game is exactly as its data makes it.

- **`RemoteConfig`** (autoload, `src/autoload/remote_config.gd`) reads `GET /v1/game-config`
  (`TaloBackend.fetch_config()`, the key's `read:gameConfig` scope) a few seconds after the start,
  when an online choice is made, and on the title screen when the last read is older than
  `refresh_seconds` (900; Talo itself caches the config 10 minutes). The read carries **no
  player** (no `X-Talo-Alias`), and like the world counters it is made only once the player turned
  an online feature on (published scores or accepted statistics): before that, no call at all.
- **The allow-list is data**: `data/online/remote_config.tres` (`RemoteConfigDef`, one
  `RemoteKeyDef` per key: its Talo key, its kind, its bounds, the hook it acts on, its purpose). A
  key not listed, a value of the wrong form, **out of its bounds** (ignored, never clamped: a typo
  of 15 for 1.5 must not become 2), an id that isn't one of the game's curses or floor events, a
  text too long: ignored, listed in `RemoteConfig.ignored` (the debug panel) and printed in debug
  builds. An empty value means "unset". Nothing from the server is ever a path, a resource or
  code: each key reaches one fixed hook (`RemoteKeyDef.Hook`) the game reads.
- **Safe points**: what is read goes into `latest`; the game uses `active`, copied from it only at
  the **title screen** (`RemoteConfig.at_title()`) and when a **run starts or is resumed**
  (`RemoteTuning.run_starting()` from `Game._begin_run()`), never in the middle of a run. A run's
  values are then fixed in its `RemoteTuning` (`RunState.tuning`) and **saved with it**: a run
  resumed after a change keeps the values it began with. The kill switches are the exception
  (below).
- **How a value reaches the game**: the multipliers go onto the run's own copy of its
  `DifficultyDef` (`RemoteTuning.apply_to()`, like an ascension level: `monster_hp` and `boss_hp`,
  `monster_damage`, `souls`), so `FloorRules` and `RunState.souls()` scale with them where they
  read the difficulty; nothing multiplies them by hand. The omen and an event's boosted floor
  event are read by `FloorRoute.offer()` and `World.build_floor()` from the run's tuning.
  (The game's classes ask through `RemoteTuning`'s static hooks, which the autoload fills: naming
  the autoload from `World` or `RunState` makes a load cycle that breaks the World's subclasses.)
- **The Dawn Knell takes the omen and nothing else.** A daily run is one race for everyone that
  UTC day, compared on one board: a player in Tokyo and one in Paris must meet the same monsters
  and floors whatever the hour they play. So in a Dawn Knell **no remote value applies** (no
  `enemy_*` multiplier, no `souls_multiplier`, no event's souls bonus or boosted floor event):
  only its day's omen (`daily_omen` + `daily_omen_date`), which is keyed by the UTC day itself
  and thus the same for all. `RemoteConfig.tuning()` returns the omen alone for a daily, and
  `RunState.create()` keeps only the omen of a daily's tuning (`RemoteTuning.daily_only()`), a
  resumed one and an older save too. The daily's day, seeds, weapon, relic, omen and board key all
  come from `DailyRun.today()`, the UTC day of the Unix time: no time zone enters. The Dawn
  Knell's card says so while an event runs. **Set an omen before its day starts** (00:00 UTC):
  a Dawn Knell begun before the game read it has none, and keeps none (its values are fixed at
  its start).
- **The version gate**: `min_version` / `max_version` make the whole config apply to those game
  versions only (`application/config/version`, compared part by part: 0.10.0 after 0.9.2). Outside
  them, every key is ignored, the kill switches too. Empty: every version.
- **The cache**: the last good read (the allow-list's keys only) in `user://remote_config.json`;
  it applies from the next start, offline too. Nothing personal is in it.

### The keys

| Key | Kind, bounds | What it does (default: the game unchanged) |
|---|---|---|
| `enemy_health_easy`, `_normal`, `_hard`, `_nightmare` | number 0.5 to 2 (1) | multiplies every monster's and boss's Health in runs of that difficulty (not the Dawn Knell) |
| `enemy_damage_easy`, `_normal`, `_hard`, `_nightmare` | number 0.5 to 2 (1) | multiplies everything that hurts the hero (monsters, traps, the cold) in runs of that difficulty (not the Dawn Knell) |
| `souls_multiplier` | number 0.5 to 3 (1) | multiplies the souls every run gives (not the Dawn Knell, like the multipliers above) |
| `daily_omen` | a curse or floor event id (`frostbound`, `ashen_breath`, `lanternless`, `blood_moon`, `darkness`, `haunted`, `market_day`, `swarm`, `treasure_vault`) | the Dawn Knell of the day `daily_omen_date` names puts it on **every normal floor** (not the first, not the wardens'; both ways down). Told in the Dawn Knell's card and in the log |
| `daily_omen_date` | date, `2026-10-31` (UTC) | the day the omen is for; any other day is untouched (no date: no omen) |
| `event_name_en`, `event_name_fr` | text, 40 characters | the event's name on the title screen (English is the fallback); no name: no event |
| `event_ends` | date (`2026-10-26`: the end of that UTC day) or moment (`2026-10-26T22:00:00Z`) | when the event ends; no end: no event |
| `event_souls` | number 1 to 3 (1) | the event's souls bonus (runs started during it, not the Dawn Knell; on top of `souls_multiplier`) |
| `event_floor_event` | a floor event id | made more likely among the floor events during the event (not in the Dawn Knell) |
| `event_floor_weight` | number 1 to 10 (1) | how much more likely (multiplies its spawn weight) |
| `motd_en`, `motd_fr` | text, 120 characters | a message of the day on the title screen, in the tagline's place (English is the fallback) |
| `scores_off` | true / false | **kill switch**: no score queued or sent (applies at once, mid-run too) |
| `statistics_off` | true / false | **kill switch**: no gameplay statistics nor world counters counted, queued or sent (applies at once) |
| `min_version`, `max_version` | version, `0.3.0` | the game versions the config is for |

**In Clayton's Talo game** the 23 keys were created on 24 October 2026 with the admin API
(`PATCH /admin/v1/game-config`, scope `write:gameConfig`) with neutral values: numbers `1`, flags
`false`, the rest empty. The game then behaves exactly as without them.

### Changing a value (the dashboard)

On [dashboard.trytalo.com](https://dashboard.trytalo.com): the game > **Game config** (Talo calls
it the live config) > edit the key's value > save. The game reads it within about 10 minutes (Talo's
cache) the next time it starts or shows the title, and applies it at the title or the next run's
start. Give values exactly in the forms above (a decimal point, not a comma: `1.25`). Check it took:
the debug panel's **Remote** tab in an editor build (it lists what was ignored and why). To go
back, put the neutral value back (`1`, `false`, empty).

### Running a weekend event

1. Set `event_name_en` and `event_name_fr` (in the Well's voice: "Night of Souls" / "La Nuit des
   Âmes"), `event_ends` (Sunday's date: the end of that UTC day), `event_souls` (`1.5` = +50%),
   and if you want `event_floor_event` (`blood_moon`) with `event_floor_weight` (`4`).
2. Optionally `motd_en` / `motd_fr` to say it on the title.
3. The title shows the event's plaque under Credits (its name, the bonus, the floor event, the
   time left, told again every `title_refresh_seconds`, 30, while the title stays open; it
   leaves once the end has passed); every run **started** before the end gets it (a run keeps it
   to its end), except the Dawn Knell, which no event touches.
4. Nothing to undo: past `event_ends` it stops by itself. Empty the name afterwards to tidy up.

To start it at a set time, Talo can **schedule** a config change (the dashboard's scheduled changes,
or `POST /admin/v1/game-config/scheduled-changes` with `{changes: [{key, value, applyAt}]}`); set
the name that way and the event begins when the name appears.
## Player feedback

**Send feedback** (the pause menu's button, and **Feedback** beside Credits on the title screen;
what the player sees: [design/interface.md](design/interface.md#privacy-and-credits)) sends a bug
report, an idea or anything else to Talo's **game feedback**, where Clayton reads it in the
dashboard.

- **`Feedback`** (autoload, `src/autoload/feedback.gd`): `submit()` checks the message (at least
  `min_length`, at most `max_length` characters, trimmed), the delay since the last one
  (`min_seconds_between`, kept in the file so a restart doesn't reset it) and that the build has a
  key; then queues it and sends it: `POST /v1/game-feedback/categories/{internalName}`
  `{comment, props}` with the `X-Talo-Alias` header (`BoardBackend.send_feedback()`), as the
  device's player (`OnlineSession.identity()`: the leaderboards' random id, made then if there was
  none, which publishes nothing). Queue in `user://feedback.json` (at most `max_queue`, the oldest
  dropped), tried again every `retry_seconds` without network, when the app comes back and at the
  next launch. A message the server refuses for good (400: a prop) is dropped; a **404** (its
  category not made yet in the dashboard) is kept waiting like no network, so messages sent
  before the categories exist are not lost. Debug builds' messages are **dev data**
  (`X-Talo-Dev-Build: 1`, shown apart in the dashboard). The tests never reach the network.
- **What goes**: the words, and Talo's category. Only if **Include game info** stays ticked (on by
  default; `FeedbackDialog` adds `FeedbackInfo`): `v` the version, `build` (debug or release),
  `os`, `os_version`, `device` (the model name; "GenericDevice" on a computer), `screen`, `window`,
  `input` (touch, keyboard, gamepad) and `pad` (the gamepad's family), `lang`; in a run `depth`,
  `act`, `place` (the act's English name), `biome`, `diff`, `asc`, `daily`, `oath`, `time` (s),
  `level` and the build as the statistics write it (`weapon`, `weapon_rarity`, `weapon_element`,
  `weapon_runes`, `weapon_affixes`, `head`, `body`, `armor_runes`, `sets`, `relics`, `perks`,
  `skill_ids`: `RunTelemetry.build_of()`); `log.01`... `log.20`, the last lines of Godot's log file
  where the platform keeps one (desktop builds; Android doesn't by default), each cut at 300
  characters, with the player's home folder and the game's data folder replaced by `~`
  (`FeedbackInfo.scrub()`). Only if **Sign with my pseudonym** is ticked (off; offered only when
  the player has one): `name`. Every value inside Talo's 512 characters.
- **The data**: `data/online/feedback.tres` (`FeedbackDef`): the categories (`FeedbackCategoryDef`:
  id, Talo internal name, button, the field's hint), `min_length` 5, `max_length` 1000 (Talo takes
  5000), `min_seconds_between` 60, `max_queue` 10, `retry_seconds` 120, `log_lines` 20.

### The categories in Clayton's Talo game (to create)

Talo's admin API has no route for feedback categories (its admin routes are game channels, game
config, game stats, leaderboards and players: `src/config/admin-api-routes.ts`), so they are made
by hand in the dashboard, **Feedback > Categories > Create**:

| Internal name | Name | Description | Anonymised |
|---|---|---|---|
| `bug` | Bug | Something broken or wrong in the game | **on** |
| `idea` | Idea | A suggestion | **on** |
| `other` | Other | Anything else | **on** |

**Anonymised on**: the dashboard (and its API) then never shows which player sent a message
(`GameFeedback.toJSON()` hides the alias of an anonymised category); a signed message carries the
pseudonym in its `name` prop. Talo still links the message to the player internally, so deleting
the player (a deletion request, the 730-day purge) deletes its messages too. Never rename an
internal name. The key already has **Game Feedback: write** (`write:gameFeedback`); reading the
categories from the game would need `read:gameFeedback` (not needed).

**Reading it**: dashboard > **Feedback**: every message with its category, comment, date and props
(the game info, the log lines), filtered by category, searched by words in the comment or a prop,
or by one prop exactly (`prop:v=0.3.0`, `prop:os=Android`). Dev builds' messages only show with
the dashboard's dev data turned on. Archive a message once dealt with (it disappears from the list; it is
a soft delete: it goes for good with its player).

Smoke test (24 October 2026, `_tool/feedback_smoke.gd`, dev data): a test player
`feedback-smoke-test` identified (alias 661019), then `POST /v1/game-feedback/categories/bug`
answered **404 "Feedback category not found"**: the key, its scope and the alias are accepted, the
categories don't exist yet. Once they are made, run it again (or send one from an editor build) to
see a message arrive; that player can then be deleted.

## Sessions and presence (Talo's live connection)

What fills the dashboard's **Total sessions**, **Average session duration** and **Online
players**: Talo counts a session only while a player is identified on its **WebSocket**, not
through the REST calls (verified in its code: `v1.players.identify` on the socket starts the
session and sets the presence online; the socket closing ends the session, with its length, and
sets it offline). So, with the statistics' consent only (`OnlineSession.statistics_allowed()`:
the consent, a server, the remote kill switch `statistics_off`), the game keeps one live
connection open while it runs:

- **`Presence`** (autoload, `src/autoload/presence.gd`) looks every `check_seconds` whether a
  connection should be open (`wanted()`). If so: the player identified
  (`OnlineSession.identity()`), then `BoardBackend.live_access()` asks a one-use **ticket**
  (`POST /v1/socket-tickets`, valid five minutes; it carries the dev build flag, so a debug
  build's sessions are dev data) and a fresh **socket token** for the player
  (`POST /v1/players/socket-token`, valid an hour; scope Players write). It opens
  `wss://api.trytalo.com/?ticket=...`; on the server's `v1.connected` it sends
  `{"req":"v1.players.identify","data":{"playerAliasId":..,"socketToken":..}}`; on
  `v1.players.identify.success` the session runs (`Presence.is_live()`, `went_live`). Nothing
  else goes on it; the server's pings are answered by `WebSocketPeer.poll()` every frame.
- **The app in the background** (`NOTIFICATION_APPLICATION_PAUSED`, a phone) or **closing**: the
  connection is closed, so Talo ends the session there (a phone killed in the background ends it
  anyway: Talo drops a connection that stops answering its 30-second pings). Back
  (`NOTIFICATION_APPLICATION_RESUMED`): a new session at once. A desktop window losing the focus
  keeps its session (alt-tab is not leaving).
- **Failures**: a connection lost after it was live is opened again after `retry_seconds`; one
  that never got live (no network, a refused token, `connect_timeout` passed) waits
  `retry_seconds`, doubled per failure up to `OnlineSessionDef.max_backoff` times. The consent
  taken back or the kill switch: closed at the next look; the online data deleted
  (`OnlineSession.forget()`, signal `identity_forgotten`): closed at once.
- **`LiveLink`** (`src/online/live_link.gd`) is the WebSocket itself (`WebSocketPeer`, 256 KiB
  buffers like Talo's plugin); `BoardBackend.open_live()` makes it, the offline backend asks no
  ticket. The numbers are data: `data/online/presence.tres` (`PresenceDef`: `enabled`,
  `check_seconds` 2, `retry_seconds` 30, `connect_timeout` 20).
- **The custom status** (Talo's `customStatus`, shown with the player online in the dashboard's
  player page): where the player is, from `PresenceDef`'s plain English words (the dashboard's,
  never shown in the game): "In the menus" (at launch, a run over or left for good), "Floor 7"
  (`Events.floor_entered`), "Dawn Knell, floor 3" (a daily run). `PUT /v1/players/presence`
  with `{customStatus}` alone, only while live, when it changes, at most every
  `status_min_seconds` (5; a quicker change waits and only the last goes), again for each new
  session. Needs the key's scope **Player presence write**; refused (403), the status is not
  asked again until it changes. `send_status` off: none sent.

Smoke test (25 October 2026, a throwaway scene, dev data): the dev player `smoke-presence-dev`
(alias 666909) identified, ticket and token taken, `v1.connected` then
`v1.players.identify.success` answered, the connection closed cleanly. The numbers show in the
dashboard with dev data turned on; from a release build they count as live data.

## Accounts and the online save (Talo player auth and game saves)

An optional account so the profile follows the player from a phone to a PC. Only when the player
asks: **Options > Privacy > Account** (`AccountDialog`); nothing is sent before.

- **`Account`** (autoload, `src/autoload/account.gd`): register (a name, a password, an optional
  recovery email), sign in, sign out, "Forgot your password?" (Talo emails a 6-digit code, then
  `reset_password`), change the password, delete the account. Talo's routes under
  `/v1/players/auth/*` (`TaloBackend.account_*`). The name: 3 to 24 letters, digits and `- _ .`,
  never an email (`@` refused: Talo's player search finds alias identifiers). Talo's reasons
  (`errorCode`: `IDENTIFIER_TAKEN`, `EMAIL_TAKEN`, `INVALID_CREDENTIALS`,
  `PASSWORD_RESET_CODE_INVALID`, `NEW_PASSWORD_MATCHES_CURRENT_PASSWORD`, `INVALID_SESSION`...)
  become `Account.Result`s with their words (`explain()`). Data: `data/online/account.tres`
  (`AccountDef`).
- **The account is its own Talo player** (service `talo`), not the device's: the leaderboards, the
  statistics, the world counters, the feedback and the presence stay on the device's player. Talo
  can't merge a player with auth into another, nor migrate a device alias to `talo`; keeping them
  apart also keeps the account out of the public boards. (Idea, not done: scores tied to the
  account.)
- **One session per account** (Talo's rule, read in its code: each sign-in makes a new
  `sessionKey`, so the other device's token is refused with `INVALID_SESSION`; refresh tokens are
  tied to it too). The game asks for no refresh token: the session token lasts until the next
  sign-in elsewhere or a sign-out. Decided with Clayton (25 October 2026): **"Stay signed in on
  this device"**, off by default: on, the password is kept in `user://account.json` and the game
  signs in again by itself when another device took the session (`Account.session_refused()`);
  off, it signs out and says so ("You signed in on another device"). A kept password that no
  longer works is forgotten.
- **Deleting the account**: the password checked by signing in with it (a wrong one deletes
  nothing), then every game save deleted, then `DELETE /v1/players/auth` (Talo deletes the auth
  and the alias; the player row, empty, goes with the 730-day purge). The profile on the device
  stays. In the game, so Google Play's account-deletion rule is met in the app; the policy says
  how to ask by email too.
- **`CloudSave`** (autoload, `src/autoload/cloud_save.gd`): one Talo game save named `profile`
  per account, content `{rev, saved_at, platform, version, profile}` where `profile` is
  `Profile.to_data()` (souls, the Tree, upgrades, records, the bestiary, the codex, achievements,
  quests, looks; never a run in progress nor the settings). Each device keeps `base_rev` (the
  revision it last matched) and `dirty` (`Profile.saved` since) in `user://cloud_save.json`. A
  sync lists the account's saves and: same revision: this device's changes go up as `rev + 1`;
  newer and nothing changed here: it replaces the profile (`Profile.from_data()`, out of a run
  only: in a run it waits, `WAITING`, until `Events.run_closed`/`run_left`); newer and changed here,
  or a first sign-in with two different progressions: **a conflict**, the player chooses
  (`CloudConflictDialog`: runs, souls, deepest floor, victories; the online one with its date and
  system; no Back out). A fresh profile takes the online one without asking; the same profile on
  both sides (compared as this game reads it) is no conflict. When: at sign-in, 3 s after launch,
  `upload_delay` (20 s) after a profile write, when the app goes to the background or comes back,
  Sync now; failures retry with the backoff. Over `max_bytes` (900 kB; Talo's body limit is 1 MB):
  `TOO_BIG`, not sent. Two devices writing the same second: the last one wins (Talo has no
  compare-and-set on saves). An upload owns a deep snapshot and a mutation counter: edits made
  while it waits stay dirty for the next upload. Account changes invalidate in-flight operations
  before their response can touch local state. A downloaded profile is type-checked and written
  successfully before memory or `base_rev` changes; a disk failure leaves both unchanged.
  `run_ended` reports a victory while endless play can continue: only closing the game scene (or
  leaving for good) releases the run guard. Held/debug profiles never upload their temporary gains.
- **Key scopes to add in Talo** (they were missing on 25 October 2026: the smoke test was
  refused with 403): **Game saves read and write**, and **Player presence write** for the custom
  status.

Smoke test (25 October 2026, a throwaway scene, dev data): the dev account `smoke_account_dev`
registered and signed in; a new sign-in made the old token `INVALID_SESSION` (one session per
account, confirmed); the game saves and the presence status answered 403 (the scopes above).

## Privacy

Leaderboards: a random id made on the device, the pseudonym, the scores and their run summary.
Statistics: the events above, linked to the same id; with them, the player's shares of the world
counters (their totals per counter, and Talo's snapshot of each update). The remote settings'
read sends no id (Talo sees the device's IP address, as with any request), only once an online
feature is on. Feedback: only the messages the player sends, with what they left ticked, linked
to the same id. With the statistics' consent too: the play sessions (when each starts and ends)
and the online presence with where the player is (menus or floor), over the live connection
above, linked to the same id. An account (only if the player makes one): its name, its password
(hashed by Talo; on the device too with "Stay signed in"), the email if given, and the profile as
its online save; a separate Talo player. No email, no account, no hardware device id
(the id is random, never `OS.get_unique_id()`), no location. Both are off until chosen and can be
turned off in Options > Privacy, which also shows the id and prepares a deletion request. The
policy is `docs/privacy.html` (FR and EN) and, short, in the game (`data/online/privacy.tres`);
what to do in Talo's dashboard and the Play Console: [privacy-ops.md](privacy-ops.md).

## Tests

`LeaderboardTests` (unit and title suites) run on `FakeBoardBackend`, never the network: nothing
is queued, sent or read before the player chose to publish, the data
is valid, the pseudonym filter, the tags (a fixed id's tag worked out outside the game, the same
name on two devices with two tags, one device's tag before the choice, after it and across a
restart, an entry from before the tags or without an identifier, a typed "#" refused and taken
out, the longest name and tag fitting every row and the question in English and French on three
screens), an official daily attempt is queued once with its score and props,
practice and debug runs and impossible runs are not, the queue and the device id survive a
restart, the queue empties when the network is back (and a past day's score is dropped), opting
out sends nothing, no key means offline; the page's unavailable, offline (Retry) and filled
states. The test runner gives the autoload an offline backend and no file before any suite runs.
`PrivacyTests` (unit, title, and the game suite's run) check the consent rules (off by default,
the age, six months after a refusal on a fake clock, a newer consent version), that nothing is
queued or sent without consent or from a debug run, what a run's end sends and its sizes, a run
quit to the title (one `run_end` abandoned with its stats) then resumed (its end covers both
parts, same id, nothing sent twice), the background draft (dropped on return, queued at the next
launch), the queue's bound, deleting one's data, the files, and the questions, Options > Privacy, the policy
and the credits on screen.
`WorldStatsTests` (unit and title suites, `FakeBoardBackend`'s game stats): the data (unique
internal names, translated names and lines, the endings), numbers per language, nothing counted,
sent or read without a choice or in a debug run or build, published scores read the world without
counting the player, one update per counter at a run's end and the cap, the queue offline (and in
the file) sent once when the network is back, endings and offerings, withdrawing and deleting,
reads cached and hidden offline; the title's line (French, grouped, turning, hidden before a
choice) and the Toll page (filled, offline with Try again, no choice).
`RemoteConfigTests` (unit and title suites, `FakeBoardBackend.config`): the allow-list's data,
the game's own values offline, before a choice and without a key, out-of-bounds values, unknown
keys and ids ignored (not clamped), values applied only at safe points, a run keeping its values
(saved, resumed after a change), `FloorRules` scaling with them, the version gate, both kill
switches (applied mid-run, lifted), the omen on that day's Dawn Knell only (every way down, the
rest of the offer unchanged), an event (its bonus, its boosted floor event, its end), the file;
the title's event plaque and message of the day in French, the English fallback, nothing before a
choice. The real config was read on 24 October 2026 with the game key (`GET /v1/game-config`, 23
keys, all neutral; through `TaloBackend.fetch_config()` too: 13 valid values, the empty ones unset,
nothing ignored).
`FeedbackTests` (unit and title suites, `FakeBoardBackend`'s feedback): the data, nothing taken
without an online service (Send off, the form says why), the queue kept offline and in its file
and sent once when the network is back, a refused message dropped, the game info only when ticked
(the run's when given), the pseudonym only when ticked, the delay, the length limits (the form stops
typing at the limit), the device's id made without publishing anything, deleting one's data, the
log's folders hidden; the title's button, the form in French at 2340x1080, 2548x1296 and 1280x720,
the thank-you note (French, fading by itself), and the pause menu's button reached with a
gamepad's D-pad, A to open, B to close. The pc tests check the form fits every screen in French.
`OnlineSessionTests` (unit, `FakeBoardBackend`): the file helper (versions, migration, skipped
writes, the bound, the latch, the backoff), one identify for four services at once, a refused
identity tried again by every service, a reset stopping every flush and timer, the device's id
taken from a version 2 leaderboards file, the remote settings' ids checked only when first needed,
the release-only paths, and the **start-up of the seven online autoloads in a release build** in
14 orders (each one first, each one last, others not made yet) for every mix of consent, key and
kill switch. `TaloContractTests` (unit, a transport in memory under `TaloBackend._send()`): the
status rule, non-JSON bodies, identify's parsing, the feedback's 404, the stats' and config's
lists, a line's name, the live session's ticket, token and WebSocket address, the headers, the
period's query, the key's file.
`PresenceTests` (unit, `FakeBoardBackend` and `FakeLiveLink`, a Talo socket in memory): no
connection without consent; a session started with the ticket's address, the player's id and
token sent on `v1.connected`, one connection while it lasts; ended in the background and a new
one on return; a lost connection opened again only after the wait; a server that never opens
backing off, then live; closed when the consent is taken back, the data deleted or the kill
switch read. (Presence reads no file and asks no other service before its first `_process()`,
so it has no part in the start-up orders.)
A real call to Talo can only be checked by hand (a probe under `_tool/`, with the key): done on
23 October 2026 (an identify and a `run_end` event as dev data).
