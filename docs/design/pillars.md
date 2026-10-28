# Pillars: what makes it a good game

The rules every new feature or piece of content is measured against, beyond its own page. The
sourced principles come from the owner's research report (Hades, Dead Cells, Enter the Gungeon,
Binding of Isaac, Slay the Spire, Celeste, Nintendo, the Game Accessibility Guidelines, Xbox and
Android guidance); the numbers marked *(start)* have no published source and are starting values
to tune by playing on the S23. Changing a number of the **fairness contract** is the owner's
decision ([decisions/](../decisions/README.md)).

## Learning by playing

- A new mechanic is **introduced** where the player can't really fail, **developed**, then
  **twisted** deeper down (Nintendo's kishōtenketsu): three placements by depth.
- Hints are one line, once per profile, never in a combat pause, with the active device's glyph
  (`Prompts.pick()`), and can be read again in the codex.
- First run *(start)*: a fight within 30 s of launching, a perk choice within 3 min, a moment of
  story at the first death (the Vigil-Keeper). The first room has no damage until the hero has
  moved and attacked; the first monster is slow, clearly telegraphed, dead in 2-3 hits.

## Pacing

- A mobile session is 5-6 minutes (median, GameAnalytics 2025): **one floor is one session**
  *(start: 3-6 min)*, saved at its start and when the app goes to the background.
- Each floor builds up, peaks (an elite, an arena, an event) and releases (a reward, the shop, a
  shrine); a calm room before every boss. At most 2-3 fights in a row without a breather.
- From the death screen, going down again never forces a walk through Kagari.

## The fairness contract

- A hit after a clear warning is fair; difficulty comes from several **clear** warnings at once,
  never from confusion. Every attack that hurts has a wind-up on at least two channels (pose,
  colour or ground mark, sound) and a way out; nothing hurts on the frame it appears; threats off
  screen get an edge marker.
- *(start, owner's decision)* A wind-up never goes under 0.4 s (0.6-1.0 s for heavy and boss
  attacks), whatever the difficulty or ascension; on Keeper an ordinary hit takes at most 15-20 %
  of max Health, a boss hit 25-30 %, all simultaneous telegraphed attacks together 50 %.
- Each ascension level adds exactly one readable modifier that keeps this contract.
- Help without judgement: like Hades' God Mode (20 % damage resistance, +2 % per death) and
  Celeste's Assist Mode, an easier way is offered plainly, never mocked.
- Luck is engineered: bad-luck protection on rarity, critical resources guaranteed (a heal before
  a boss), draws without repeats in a run, honest odds when shown.

## Builds and choices

- Every perk, relic and affix has a **purpose** (Slay the Spire): a solid everyday pick or
  something to build around, and links to at least one existing synergy. It differs from its
  neighbours in kind, not only in size.
- Offers of 3, with a limited reroll or "skip for a small reward"; at most 3-4 affixes per item.
- Strong combinations are fine when rare and hard to assemble; a dominant strategy found in play
  is fixed carefully (Dead Cells' first fix went too far).
- Balance with data (docs/balance.md); heavy players skew averages.

## Accessibility (required)

The Game Accessibility Guidelines' **Basic** level is required: remappable controls, large
targets, readable font and contrast, never colour or sound alone, separate volumes, subtitles,
no flicker, saved settings, a wide choice of difficulty. Also: an alternative to held buttons, no
required simultaneous presses, autosave, difficulty changeable in a run. Screen shake (0-100 %),
Screen flashes and Vibrations are options every effect respects.

How the interface holds it (numbers and checks: [interface.md "One skin"](interface.md#one-skin-binding)):
touch targets of 96 units for the fight's buttons and 64 for everything else, 16 apart, out of
the joystick's zone, at both buttons sizes (Normal, Large); everything in the screen's safe
area; **Large text** (reading text a whole font step bigger, on by default on a phone, where the
panels were measured to hold it) and a **text speed** (slow to at once); words laid out before
they are typed; text in dark insets at 4.5:1 or more, disabled buttons at 3:1; rarity and rune
families with a shape as well as a colour; a pressed state on press; nothing to read swells,
shakes or blinks.

## Performance on the phone

- 60 fps on the S23, judged on the worst frames (P99), not the average: Android counts a session
  as slow when more than 25 % of frames take over 50 ms, measured after a minute of play.
- No per-frame allocations in hot paths, redraw on change, shared textures so 2D batches
  ([performance.md](../performance.md)); projectiles, numbers and effects pooled; at most one heavy
  instantiation per frame; *(start)* launch to title under 5 s, a floor change under 2 s.
- Android may kill the app in the background without warning: state is saved when it stops.

## Story

- Like Hades: the story moves on with each death, characters react to small facts of the run,
  the narrator (the Vigil-Keeper) says only what the player can't know otherwise, everything is
  skippable. *(start)* Each return to Kagari unlocks at most one new main line; in-run lines are
  one short line without pausing the fight; hub conversations 3-5 exchanges.
- The voice is the Well's ([lexicon.md](../lexicon.md), [lore.md](../lore.md)).

## Definition of done for content

Content is done when it is: **fair** (telegraphed, avoidable, in the damage budget);
**teachable** (introduced, developed, twisted; a hint if not obvious); **balanced** (its role and
synergies declared, measured); **accessible** (no colour or sound alone, shake/flash/vibration
options respected, playable by touch, gamepad and keyboard); **fast** on the S23 (no hitch on
first use); **safe** in the background; **translated** in English and French in the Well's voice;
**acknowledged** by an NPC when it is a landmark (a boss, a biome, a curse); and **seen**: a run on
PC and one on the phone, in Pilgrim and in Martyr, by the owner.
