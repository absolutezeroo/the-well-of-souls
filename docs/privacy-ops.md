# Privacy: what Clayton does (consent, policy, Talo, Play Console, deletions)

The game's privacy rules and how to run them. What the player sees is in
[design/interface.md](design/interface.md#privacy-and-credits); how the online parts are built is in
[online.md](online.md). The decisions below come from a legal research report (23 October 2026,
sources: CNIL, GDPR, LIL, EDPB, Google Play policies, Talo's terms, DPA and code). **It is not
legal advice.** Where the report was unsure, the safer choice was taken and is marked
**(safer choice)**.

## The rules in the game

| | Online leaderboards | Gameplay statistics |
|---|---|---|
| What | random device id, pseudonym, Dawn Knell scores and a short run summary (public) | a summary of each run, boss fights, perk choices, purchases, pacts (`data/online/telemetry.tres`); the player's shares of the world counters (`data/online/world_stats.tres`) |
| When | only after the player answers **Publish my scores** (`PseudonymDialog`) or turns it on in Options | only after the age question (16 or older) and **Accept** (`ConsentDialog`) |
| Legal basis | the service the player asks for (GDPR 6(1)(b); LIL art. 82 exemption: a feature expressly requested) | consent (GDPR 6(1)(a) and LIL art. 82) |
| Default | off: **no Talo call at all**, not even reading a board, until chosen | off |
| Turned off | Options > Privacy > Publish my scores online | Options > Privacy > Gameplay statistics (withdrawal at once, what waited is dropped) |
| Kept on Talo | until deleted, or 24 months after last seen (Talo's purge, below) | 13 months (Talo's event retention, below) |

- **Age.** Only the statistics ask it: "Under 16" / "16 or older", neutral, nothing pre-chosen.
  Only that yes/no is stored (`user://privacy.json`), never an age. Under 16: the statistics are
  never offered (16 everywhere rather than 15 for France only: **safer choice**, the highest age
  any EU country uses). The leaderboards don't depend on age (not consent-based).
- **The consent question** comes on the title screen the first time it shows (0.8 s after, never
  over a run), with plain words, Accept and Decline the same size and look, and the keys and
  gamepad starting on **Privacy policy**, not on Accept. Closing it declines. A refusal (or
  closing) is kept 183 days (6 months) before it is asked again (`PrivacyDef.reask_days`). The
  report suggested asking after the first run ends (the CNIL prefers questions in context); the
  game asks at the first launch as you asked: both are lawful, and on the title it never
  interrupts a run.
- **Proof of consent.** Each answer is logged on the device with its time, the consent version and
  the policy version (`Privacy.history`, the last 20).
- **New purposes or a new processor**: raise `consent_version` in `data/online/privacy.tres`;
  every player who accepted is asked again and sends nothing until they answer. Change the policy
  (`policy_version`, `policy_date`, the sections, docs/privacy.html) in the same commit.
- **Nothing private in Talo's player props.** Talo's game API shows every player's props to anyone
  reading a board (the key ships in the game). The game only sets `name` (the public pseudonym),
  never sends `META_` props (Talo copies those into the player's props), and puts the run summary
  only in events.
- **The name tags** ("Clayton#4821", [online.md](online.md#names-and-tags)): four digits worked
  out on the device from the player's random id, which Talo already shows on every entry
  (`playerAlias.identifier`). Nothing new is collected or sent for them, except in a **signed**
  feedback message, whose `name` prop now carries the tag (the player ticks "Sign with my
  pseudonym", which shows it). No change to the policy nor to `consent_version` (24 October 2026).
- **Debug runs, tests** send nothing.
- **The world counters** (the Well's Toll, [online.md](online.md#world-counters-the-wells-toll)):
  each run's share is sent with the player's alias, and Talo keeps the player's own total per
  counter and a snapshot of each update. That is per-player gameplay data like the statistics, not
  something the player asked for by publishing scores, so it is sent **only with the statistics'
  consent** (16 or older, accepted) **(safer choice)**: the leaderboards' basis (the service
  requested) doesn't stretch to it, and the CNIL's exemption for audience measurement needs data
  that is anonymous from the start. Reading the world's sums (no player data sent) needs either
  feature turned on, so a player who chose neither makes no call. It was added under consent
  version **2** (policy 1.1): players who accepted version 1 are asked again. The player's totals
  go with the player (deletion, the 730-day purge); the world's sums are anonymous and stay.

- **The remote settings** ([online.md](online.md#remote-settings-talo-game-config)): reading Talo's
  game config is a request like any other, so Talo sees the device's IP address. Decision (24
  October 2026): the game reads it **only once the player turned an online feature on** (published
  scores or accepted statistics), like the world counters' read, so a player who chose neither
  still makes no call at all; the read carries **no player id** (no alias header: Talo's
  `GET /v1/game-config` needs none), stores nothing on Talo's side, and only allow-listed values
  are kept on the device (`user://remote_config.json`, nothing personal). Basis: legitimate
  interest (GDPR 6(1)(f): keeping the game fair and working without an update); no device
  storage is read for it, so LIL art. 82 doesn't apply. Not consent-based, so **no new consent
  version**; the policy says it (version **1.2**, in-game section "Game settings from the server",
  docs/privacy.html section 2). If the read ever had to carry the player's alias (per-player
  config), that would need its own basis: ask again.
- **Player feedback** ([online.md](online.md#player-feedback)): a message the player writes and
  sends from **Send feedback**, with the game's details unless unticked and the pseudonym only if
  ticked, linked to the device's random id (made then if there was none). **No consent question
  and no consent version raised** (decided 24 October 2026, from the report's reasoning on the
  leaderboards): each message is the player's own explicit act, for that message only, nothing is
  sent before **Send**, and the form says in plain words what goes, where, and links the policy.
  That is the service the player asks for (GDPR 6(1)(b)), and storing/reading the random id for
  it is strictly necessary to a feature expressly requested (LIL art. 82 exemption, the CNIL's
  "fonctionnalité demandée expressément"), like publishing scores. `consent_version` stays **2**:
  it guards what is collected *on consent* (the statistics), and nothing new is collected on that
  basis. The policy says it (version **1.3**, 24 October 2026: a "Feedback" section in the game's
  short policy and section 5 of `docs/privacy.html`, both languages; "Changes" now says the game
  asks again for what needs consent). Not age-gated (not consent-based; the game is 13+). Talo
  keeps the messages until the player is deleted (a request, or the 730-day purge: they cascade);
  archiving one in the dashboard only hides it. The feedback categories are **anonymised**
  (online.md): the dashboard never shows who sent a message unless it is signed. **(safer
  choice)**: the details are on by default but plainly listed and one tap to untick; if you would
  rather have them off by default, it is `_info.set_pressed_no_signal(true)` in `FeedbackDialog.open()`.
- **Policy 1.4 (24 October 2026): clarifications only, `consent_version` stays 2.** Two wordings
  made exact, with nothing new collected and no new use: (1) the statistics' run summary and the
  world counters' share are sent "at the end of each run, **or when it is left or the app is
  closed**" (they were already: a run left for the title or a closed app sends its summary,
  marked `quit`, and again at its real end if resumed), in the policy (both languages), its
  in-game section and the consent question itself; (2) the feedback's "Include game info" is
  listed field by field as `FeedbackInfo` sends it (version and build type, OS and its version,
  device, screen and window, input device and gamepad family, language; in a run depth, act,
  place, biome, difficulty, ascension, daily, oath, time, level and the build: weapon, armor,
  families, relics, perks, skills; on desktop the log's last lines). Decision: the same data, for
  the same purposes, to the same processor, on the same basis, so by the rule below it is a
  **policy version** change (1.3 to 1.4), not a consent version: players who accepted under 1.3
  are not asked again (their answer is logged with policy 1.3; new answers with 1.4). Had any of
  it been a new kind of data or a new use on consent, `consent_version` would go to 3.
- **Policy 1.5 (25 October 2026): play sessions and presence, `consent_version` 3.** The game now
  keeps Talo's live connection open while it runs (online.md "Sessions and presence"), so Talo
  records each play session's start and end and shows the player online: what fills the
  dashboard's sessions, average duration and online players. It is new data (when and how long
  the game is played), collected by itself on consent, so by the rule below **consent version 3**:
  players who accepted version 2 are asked again and send nothing until they answer. Under the
  statistics' consent only (16 or older, accepted), never otherwise; closed in the background, so
  nothing runs there. The consent question has a line for it, the in-game policy's statistics
  section and `docs/privacy.html` section 4 (both languages, with a retention row: sessions go
  with the player, deletion or the 730-day purge) say it. Same processor (Talo), same id.
- **Withdrawal during a request (audit fixes, 25 October 2026):** presence closes immediately
  on a privacy change and checks consent before every status send and between the live ticket
  and token requests. Score publication and world-counter requests recheck their permission
  after identification and before each follow-up request. Forgetting the device invalidates
  unfinished identification in both the session and the REST backend, so a late response cannot
  restore the old alias. A request already sent cannot be recalled; no later request is started
  on the withdrawn permission. These enforce the existing purposes; no new data or consent version.
- **Accounts and the online save (25 October 2026, policy 1.5, no consent version):** an
  account is made only when the player asks, for the service they ask for (their progress on
  another device): GDPR 6(1)(b), and keeping its session (and, if they tick "Stay signed in",
  its password) on the device is strictly necessary to it (LIL art. 82 exemption), so **no
  consent question and `consent_version` stays 3**. What Talo keeps: the name (findable through
  the game API's player search: the form refuses an `@` and says never your real name), the
  password (bcrypt), the email only if given (only for the reset code, sent by Talo), the
  profile as a game save, and Talo's own auth log (sign-ins with IP and user agent). A separate
  Talo player: nothing links it to the device's id. **Deletion in the game** (Options > Privacy >
  Account > Delete the account: its saves, then its auth and alias), which is what Google Play
  requires of an app with accounts; the Play Console also asks for a **web link** explaining how
  to delete an account: the policy's section 11 (Your rights) says it (in the game, or by email
  with the account's name). An emailed request: delete the account player in the dashboard
  (Players, search the name). Not age-gated (contract basis; the game is 13+). Retention: until
  deleted, or the 730-day purge of inactive players.
- **The rule for a new purpose**, made explicit: a new purpose that runs **on consent** (or by
  itself in the background) raises `consent_version`; a new feature that only sends when the
  player explicitly asks for it, each time, and says what it sends, only changes the policy
  (`policy_version`, its date, the sections, `docs/privacy.html`).

## The placeholders to fill (before publishing a build with a key)

They live in **one data file**, `data/online/privacy.tres`, and the same ones in
`docs/privacy.html`:

| Placeholder | What |
|---|---|
| `[CONTROLLER_NAME]` | your legal name (or your registered business name, if you have one) |
| `[CONTACT_EMAIL]` | a privacy address (deletion requests go there; the in-game button writes to it) |
| `[POLICY_URL]` | where `docs/privacy.html` is published (e.g. GitHub Pages); the game links to it |

Fill all three at once: `python3 tools/privacy/fill_policy.py --name "..." --email "..." --url "..."`
(then `python3 tools/privacy/fill_policy.py --check` says "filled"). Until then the game shows the
placeholders as they are, the in-game "Read the full policy online" button is hidden, and "Delete
my online data" shows the address placeholder instead of opening an email. Then publish
`docs/privacy.html` at that URL, and put the URL in the Play Console, on itch.io and on Steam.

## Talo dashboard settings

The game's key needs these scopes (already set): Players read/write, Leaderboards read/write,
**Events write** (the statistics), **Game Stats read/write** (the world counters), **Game Feedback
write** (player feedback), and **to add (25 October 2026): Game Saves read/write** (the online
save) and **Player Presence write** (the custom status). Then, on [dashboard.trytalo.com](https://dashboard.trytalo.com):

0. **Feedback > Categories**: create `bug`, `idea` and `other`, **Anonymised** on (online.md,
   "The categories"). Until they exist, messages wait on the players' devices (Talo answers 404).
   Archive a message once handled; it is deleted with its player.
0. **Stats**: the nine world counters exist (online.md lists them). Nothing to set: a player's
   own totals go when the player is deleted or purged.
1. **Event retention: 13 months.** Per event name (`run_end`, `boss`, `perk_offered`,
   `perk_picked`, `perk_banished`, `purchase`, `pact`), set the retention to **395 days**. In
   Talo's code this is the "event retention" setting (1 to 36,500 days per event name, purged by
   a daily task). The events appear in the dashboard after the first ones arrive; set it then.
2. **Purge inactive players: 730 days.** In the game's settings, turn on **purge live players**
   (and dev players, if you want test data gone too) with **730 days**. It is off by default
   (default 90 days when turned on). Deleting a player also deletes its aliases, leaderboard
   entries, events and stats.
3. Display name prop key = `name`, profanity filter on (already in [online.md](online.md)).
4. **Data exports** (Services > Export, to read the statistics: online.md "Reading the
   statistics"): the ZIP holds every event with the player's ids (the device id). Keep it on your
   own computer, never in git (`.gitignore` ignores `export-*.zip`), and delete it once the page
   is made. The page `tools/stats/build_dashboard.py` makes holds only totals, no player id.

The exact menu labels could not be checked from here (the dashboard needs a login, and its docs
page was unreachable): look in the game's **Settings** for "Data retention" / "Purge players", and
in **Events** for each event's retention. Check that both exist on the hosted service (the report
read them in Talo's open-source code at commit `be23fc7`).

## Google Play Console: Data safety form

Answers from the report (check them again against the build you publish):

- Does your app collect or share any of the required user data types? **Yes.**
- Is all of the user data collected by your app encrypted in transit? **Yes** (HTTPS to
  `api.trytalo.com`).
- Do you provide a way for users to request that their data is deleted? **Yes** (in-game button
  that prepares an email, and the address in the privacy policy).
- Account creation: **Yes, optional** (username and password, made in the app). Account deletion:
  in the app (Options > Privacy > Account > Delete the account) and a **web link** to the
  policy's "Your rights" section (how to delete it, in the game or by email).
- Shared: **No** for every type (Talo processes on your behalf: a service provider, not sharing).

| Data type | Collected | Purposes | Optional | Ephemeral |
|---|---|---|---|---|
| Personal info > **Name** (the pseudonym: Google's "name" includes nicknames) | Yes | App functionality | Optional | No |
| **Device or other IDs** (the random install id) | Yes | App functionality, Analytics | Optional | No |
| App activity > **Other actions** (gameplay: scores, run summaries, builds, deaths, perks...) | Yes | App functionality, Analytics | Optional | No |
| App activity > **App interactions** (the input device type; play sessions: when the game is open, their length, online presence and where in the game) | Yes | Analytics | Optional | No |
| Personal info > **Email address** (an account's recovery email, if given) | Yes | Account management | Optional | No |
| Personal info > **User IDs** (an account's name) | Yes | Account management, App functionality | Optional | No |
| App activity > **Other actions** (the profile as the account's online save) | Yes | App functionality | Optional | No |
| App info and performance > **Other app performance data** (game version, OS name, screen size; with feedback also the OS version and device model) | Yes | Analytics, App functionality | Optional | No |
| App activity > **Other user-generated content** (a feedback message's words) | Yes | App functionality | Optional | No |
| App info and performance > **Diagnostics** (the last lines of the game's log, sent with feedback if ticked; Android keeps no log file by default, so in practice desktop only) | Yes | App functionality | Optional | No |

Also: **Target audience** 13-15, 16-17 and 18+ (never under 13: keeps the game out of the
Families policy; keep the store art from looking aimed at small children), **Ads: No**,
**Privacy policy URL**: the `[POLICY_URL]`. No permission is asked for and nothing runs in the
background, so no "prominent disclosure" is required beyond the consent question.

## A deletion request

A player uses **Options > Privacy > Delete my online data** (or writes to you). The email holds:

```
Online ID (alias identifier): <32 hex characters>
Talo player ID: <uuid, if the game knew it>
Pseudonym: <name>
```

Within **one month** (GDPR art. 12(3)):

1. On the dashboard, **Players**: search for the online ID (the alias identifier), the player ID
   or the pseudonym (`name` prop). Open the player and **delete** it (admin users only). That
   deletes the player, its aliases, its leaderboard entries, its events, stats and sessions; Talo
   keeps only an anonymous "deleted player" row.
2. Answer the player that it is done. Keep the emails 1 year after closing (proof of handling),
   then delete them.
3. If nothing matches, say so (GDPR art. 11(2)) and ask for the ID shown in Options > Privacy.

The game itself already stopped sending, and made a new random ID only if the player turns a
feature on again. (Talo's game API has no self-delete for anonymous players and the admin key must
never ship in the game: a one-click deletion would need a small server holding that key.)

Hiding a pseudonym only (a removal request about a name): Leaderboards > the board > the entry >
hide.

## The email to Talo about its US sub-processors

Send to **data@trytalo.com** (the DPA names it for sub-processor questions), and keep the answer
with your records; then update the policy's section 7 (both languages) if needed.

> **Subject:** DPA question: transfer mechanism for Sentry (US) and player data in error reports
>
> Hello,
>
> I use Talo for the game "Le Puits des Âmes" (online leaderboards and gameplay events, players in
> the EU). I am the controller and Talo is my processor under your Data Processing Addendum
> (version of 5 September 2026).
>
> Your sub-processor list names Sentry (Functional Software Inc., United States) for error
> reporting. To complete my privacy notice and my records of processing, could you tell me:
>
> 1. Which transfer mechanism covers personal data processed by Sentry in the United States (EU
>    Standard Contractual Clauses, the EU-US Data Privacy Framework, or another)?
> 2. Whether player data (player and alias identifiers, props, event props, IP addresses) can
>    appear in error reports sent to Sentry, and if so, whether it is scrubbed or minimised before
>    sending.
> 3. Whether the hosted service offers per-event data retention and the purge of inactive players
>    (as in the open-source backend), so I can set 13 months for events and 730 days for players.
>
> Thank you,
> [CONTROLLER_NAME]
> [CONTACT_EMAIL]

## Records (one page, keep it with your files)

A short register of processing (GDPR art. 30; the exemption for small organisations is doubtful for
continuous analytics, **safer choice**): the two processings above (purpose, data, basis,
retention, recipient Talo and its sub-processors, transfers, security: TLS, minimal data), the
date each setting was made in the dashboard, and Talo's answer to the email above.

## Still open (from the report)

- UK players: a UK representative (UK GDPR art. 27) may be needed for a non-UK controller that
  monitors UK users; low priority for a free hobby game, not researched in depth.
- The EU "Digital Omnibus" may change the re-ask delay (4 or 6 months; 6 satisfies both) or add an
  exemption for anonymous first-party statistics. Nothing adopted on 23 October 2026.
- Check what Talo's leaderboard responses really contain in a release build (the policy says the
  technical ID is readable by anyone querying a board).
