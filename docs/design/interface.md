# Interface

## Controls

Every scrolling list (codex, shrine, bag, shop) scrolls by dragging a finger over it, from
anywhere in it, cards and buttons included, with a bit of momentum (`TouchScroll`, added to each
`ScrollContainer` by the `TouchScrolling` autoload, or at once by `TouchScroll.attach()`: one
helper a list whichever comes first); a drag never presses a button, a tap does.
A drag that starts on a slider or a scroll bar stays the slider's, however far the finger wanders
up or down (a control can ask the same with the group `TouchScroll.KEEPS_DRAG`), and a list behind
the menu on top (the title's, under the Options) takes no drag.


| Action | Touch | Keyboard and mouse | Gamepad (Xbox names) |
|---|---|---|---|
| Move | Drag on the left side | WASD / arrows | Left stick |
| Attack (auto-aim): tap; hold to charge, let go to unleash | Big red button | Space / J, left click | X |
| Roll (skill 1), weapon skills 2-3, spell 4 | Round buttons around it (96 units across) | 1 2 3 4 or K L O P; roll: right click too | A B Y RB |
| Belt (potions, bombs, scrolls) | The 3 smaller buttons in the bottom row, left of the roll | Q / H, 5, 6 | LB, D-pad left, D-pad right |
| Use what you stand by (trade, forge, drink...), or take loot left on the ground | The Interact button (shows only then) | E / F | RT |
| Open the waiting perk choices | The perk button (shows only then) | C | LT |
| Whole floor's map | Tap the minimap | M | D-pad up |
| Bag | Bag button | I / Tab | View (Back) |
| Pause (or close what is open) | II button / phone back button | Escape | Menu (Start) |
| In a menu: move / accept / back | Tap | Arrows or WASD / Enter or Space / Escape | D-pad or left stick / A / B |
| In a menu with tabs: previous / next tab | Tap a tab | Q / E | LB / RB |
| In the bag: equip or use / dismantle / drop the item | The item card's buttons | Enter or Space (right click) / X or Delete / G | A / X / Y |
| In the bag: scroll a long item card | Drag it | Mouse wheel | Right stick |
| Fullscreen or a window | - | F11, Alt+Enter | - |

A keyboard's letters are named as the player's keyboard prints them (`Prompts.key_word()`: the key
in W's place reads Z on a French keyboard); the bindings are the input map's (project.godot, with
the player's own over it: the Controls page, below), and
what the player is told about them is `data/ui/input_prompts.tres` (see Devices below). B never
pauses in a fight (it is a skill): only Escape, Start and the phone's back button do. The other
way round, the press that closes a menu stays the menu's: B closing the pause menu, the forge or
the bag casts no skill as the fight resumes (the hero reads no new press on the first frame after
a pause, `PlayerControls._presses_muted`).

**Attack: tap or hold.** A tap (or a press) is one basic attack at once, aimed at the closest
enemy; a press of the attack, the roll or a skill that can't go yet (the weapon still swinging,
a cooldown about to end) waits for it 0.12 s (`PlayerDef.input_buffer`, real seconds: a hit stop
neither eats nor stretches it), the newest press taking the place of an older one, so quick taps
are never lost and never fire late. Holding no longer repeats the attack: past 0.22 s it charges the weapon's charged attack
(builds.md, "Charged attacks"), shown at the hero's feet and as twelve steps lighting up around
the attack button's rim (its thumb may hide the hero), in the element the weapon carries; full,
they beat. Letting go full unleashes it; a roll cancels it. **Without holding** (Options >
Gameplay > Charge without holding, `Settings.tap_to_charge`, decision 0011): two attacks within
0.3 s (`PlayerDef.double_tap_window`) start the charge, which fills with the button up (as does a
held charge let go early), and the next attack unleashes it once it is full; holding still works.

## Devices: touch, keyboard and mouse, gamepad

(A text field, the leaderboards' pseudonym, keeps every key while it has the focus but the up and
down arrows: MenuNav doesn't take Q, E, WASD or left and right from it. On a phone the system's
keyboard opens; with a gamepad alone the name can only be kept.)

The game plays the same with a finger, a keyboard and mouse or a gamepad, and changes what it
shows to the device in hand.

- **Which device** (`InputDevice`, autoload): the last real input decides. A screen touch is touch
  (not the touches the mouse emulates); a key, a mouse button or the mouse moved more than a few
  screen pixels is keyboard and mouse; a gamepad button, or a stick or trigger pushed past the dead
  zone (`InputPromptsDef.stick_deadzone`, 0.5: a drifting stick never takes over) is that gamepad.
  The gamepad's family comes from its name (`PadGlyphsDef.name_hints`: Xbox, PlayStation,
  Nintendo, any other): its buttons' names and colors. Unplugging the gamepad in use goes back to
  the keyboard (touch on a phone). At start: touch on a phone, the keyboard on a computer.
  `InputDevice.changed` tells the HUD, the prompts and the menus.
- **The HUD** (`Hud._apply_device()`): on touch, the joystick and the round buttons as always. On
  keys or a gamepad they are put away for the **action bar** (`ActionBar`), low in the middle: one
  slot per round button (attack, the four skills, the three belt slots), each with its key or
  button under it, its cooldown (shade falling a pixel row at a time), its charge (twelve steps on
  its lower edge) and its count; it mirrors the touch buttons (the HUD keeps those up to date shown
  or not), so both always say the same. Beside it, while something is in reach, Interact's prompt:
  its key, the thing's picture and what it does ("[E] Trade"); Interact also takes loot left on the
  ground. The bag, pause, map and perk buttons show their key on their top edge. The first touch
  brings the touch controls back. The tutorial's ring points at the bar's slot instead of the round
  button (`Hud.hint_target()`), at nothing for the joystick.
- **The mouse in a fight** (`MouseControls`): a click the HUD doesn't take (not on a button, the map,
  a hint) holds its action down: the left button attacks (auto-aim as always: the closest enemy),
  the right one rolls (`ActionPromptDef.mouse`). Never from a touch screen's own mouse events.
- **Prompts** (`Prompts`, `PromptGlyph`): a key or button is shown as a little cap in pixel art on
  the 2-unit grid of a BODY letter's pixels, its word at `Fonts.BODY`: a key (its face over a darker
  lower edge), a round face button rimmed in its color (the font has PlayStation's ✕ ○ □ △ and the
  arrows, `tools/i18n/add_glyphs.py`), a shoulder or trigger, a stick, a little mouse with its
  button lit. In a sentence it is "[E]". Every instruction that says "tap" or names a control has
  two versions, each a whole sentence translated as such: one for touch, one for keys and
  gamepads with `{action}` codes (`HintDef.button_text`, `DeviceText` in the loading tips, and in
  code `Prompts.pick("Tap to skip", "Press {ui_accept} to skip")`); the codes are filled with the
  device's key ("Press [Enter] to skip", "Press [✕] to skip"). Others are worded for every device
  ("Choose a slot to see what it does."). A hint on screen changes its words when the device does.
- **Keyboard layouts**: keys picked for their place (moving, attack, skills, belt) are bound by
  `physical_keycode`, so WASD is Z Q S D on a French keyboard and the caps say so; keys named after
  what they do (M the map, I the bag, E or F interact, C the perks) are bound by their letter
  (`keycode`), wherever the layout puts it. A cap shows a sign as itself ("," not "Comma":
  `InputPromptsDef.key_words`).
- **Menus with keys and a gamepad** (`MenuNav`, autoload): every window built on `RpgWindow` or
  `RpgDialog`, and the title screen, is a menu (the group "menu"). The one on top holds the focus:
  opening, its first button outside its header gets it (or the one it names: the codex its tab, the
  perk choice its first card, even while the cards wait out their first moments); when what covered
  it closes, or its focused button goes away (a list rebuilt), the focus comes back to the one it
  was on. Directions (arrows, WASD, D-pad, left stick: one move a push) go to the nearest button
  that way in that menu only, wrapping at its edges; a slider takes left and right; a list follows
  the focus (`ScrollContainer.follow_focus`), and a box with nothing to focus scrolls. Q / E and LB /
  RB switch tabs (buttons in the group "menu_tabs": the codex, the options, the bag). Enter, Space or A press;
  Escape or B go back (the screens' own Back: `GameMenus.back()`, `TitleScreen.back()`); Escape on
  the bare title quits nothing. The buttons Back stands for show its key: a window's Close beside
  it, a dialog's Resume, Later, Leave and Close inside on the left (`PromptGlyph.badge()`; on touch
  nothing, the phone's layout unchanged). A gold pixel frame (corner brackets, breathing by a pixel) shows
  around the focused button while keys or a gamepad drive (`InputDevice.navigating`), never on
  touch or after the mouse moved; the mouse hovers and clicks as always. The frame stays inside
  the boxes that clip its button (a list's scroll, a column), give or take its own width: a
  button scrolled out of its column has none (`MenuNav.frame_area()`). A codex page opened with
  keys starts at the top of its columns (`MonsterPage.scroll_to_top()`: its first button was
  focused before the columns were laid out, and the column used to scroll it just out of sight). Buttons are focusable
  again everywhere but the HUD, where nothing keeps the focus (Space attacks). The debug panel too
  (an `RpgWindow`, its tabs on Q / E and LB / RB).
- **Someone speaking** (`DialogueBox`, `src/ui/dialogue/`; presentation.md, "The Vigil-Keeper
  and the keepers"): a face, a name, words typed letter by letter. A tap or a click on it, Enter,
  Space or a gamepad's A write the page out, then go on; a touch and the click the screen makes of
  it count once (`TapGate`, below). Paged (the shrine's `DialogueScreen`, a menu of its own: the
  box holds the focus, a tap anywhere goes on, Back closes it, the focus comes back to her), the
  "more" sign is a bobbing gold arrow on touch, the accept key's cap on keys and pads. Stacked (the
  end screen) it types everything by itself and never holds the buttons: accept is its own only
  while it writes. The Vigil-Keeper on the title screen is a button like the others (the arrows
  reach her; Enter or A on her opens her words).
- **"Tap or press to continue"** (`TapGate`, `src/ui/common/tap_gate.gd`): the one way every
  screen that waits for a press reads it: the act and curse cards, a fragment of the past, a
  cinematic, the story, someone speaking and a tutorial hint's board (its keys are its OK button's). A press is a touch, a mouse click (never the wheel:
  scrolling over a card skips nothing), a key (not its repeat) or a gamepad button (the story and
  someone speaking take only accept: Enter, Space, A; the story attack too). One finger is one
  press: the phone sends the touch and a click made of it (the project emulates both ways), the
  first is taken and its twin a few frames later swallowed, the finger's release too, even after
  the screen closed itself, so the tap that closes a fragment never reaches the attack button
  under it. A grace after opening (the fragment's quarter of a second, the curse card's sigil)
  keeps the thumb that opened it from closing it (`TapTests`).
- **The Controls page** (Options > Controls): what does what on the device in use: each
  control of `input_prompts.tres` with every key and mouse button (caps), the gamepad's buttons in
  its family's names, or how it is done by touch. Picking up another device turns the page.
- **The player's own keys** (`KeyBindings`, `Settings.bindings`): on keys and gamepads the
  fight's controls (`ActionPromptDef.remappable`: Attack, the four skills, the three belt slots,
  Use, the perks, the bag, the map) are buttons on the Controls page. Pressed, the page waits
  ("Press the new key for Attack"); the next key, gamepad button or trigger becomes the control's
  first (the one every prompt shows), Escape (Start on a pad) or a click gives up. One key does
  one control: a key that was another control's first swaps with it (Roll given 2: the weapon
  skill takes 1), another control's second key (J for Attack) is taken from it. The keys of moving,
  Pause and Fullscreen (`InputPromptsDef.reserved_actions`) are refused ("That one is kept for:
  Move"), so the hero can always move and the game always pause; the menus' own keys (Enter,
  Escape, Q / E for tabs, the bag's X and G) never change. A key is taken by its place, like the
  game's own. Default keys / Default buttons put back that device's, the other's kept. Saved in
  `settings.cfg` (section `bindings`: the changed controls' whole lists, "k:74" a key, "b:2" a
  button, "a:5:1" a trigger) and laid over project.godot's input map at start
  (`KeyBindings.apply()`). Moving stays on WASD / the arrows and the left stick.

## Screens: windows, sizes, scale

- **Windows** (computers): resizable; **Fullscreen** in Options > Graphics, or F11 / Alt+Enter
  anywhere (`Settings.fullscreen`, saved). The keys do only that, in any menu: `Settings`'
  WindowKeys node stays the root's last child, so it reads them before any menu's `_input` (Godot
  goes from the last node up) and the bag never takes Alt+Enter for Enter, nor a card F11 for a skip.
- **Scale** (`PixelGrid`): the UI is laid out at 1280x720 and the canvas grows with the screen's
  shape (`canvas_items`, expand). Its scale is rounded down to a step of 0.5 (x1 from 720 to 1079
  lines, x1.5 at 1080, x2 at 1440, x3 at 2160), where BODY letters keep whole pixels, and the canvas
  takes the rest (1366x768 lays out at 1366x768, 21:9 at 1720x720, 16:10 at 1280x800). A screen too
  small for x1 (1024x768) keeps its own scale (x0.8: letters a little uneven). The world's cameras
  keep their framing whatever the interface's scale, made whole: their zoom draws every art pixel
  on a whole number of screen pixels, the designed framing rounded down to the wider view
  ([decision 0007](../decisions/0007-whole-pixels-on-screen.md); `PixelGrid.camera_zoom()`,
  `GameCamera`, `VillageWalker`).
- **Typing on a phone** (`SoftKeyboard`, every `LineEdit` / `TextEdit`: the feedback form, the
  pseudonym): Godot's Android activity is `adjustResize`, so the phone's keyboard shrinks the
  game's window to the strip above it (2340x1080 to about 2340x480 held sideways). Read as a new
  screen, that scaled the UI down to x0.67 and squeezed the dialog into the strip: the words typed
  were a few pixels tall. Now a resize while a field has the focus on a device with a virtual
  keyboard (same width, at least 8% shorter than the window without the keyboard; or, the phone
  turned upright with the keyboard up, that window turned a quarter and 8% shorter:
  `SoftKeyboard.is_keyboard_resize()`) keeps the scale of before (`PixelGrid.settled_size()`), and a
  **typing bar** fills the strip over everything (layer 126, the rest of the game dimmed almost
  black): the field's name (`TITLE_META`, else the dialog's title), its hint (`HINT_META`, else
  its placeholder: the pseudonym's rules, the feedback kind's question), its length and limit
  (`MAX_META`, else a LineEdit's `max_length`), the words as typed with the caret at BODY size (a
  long message shows its last lines), and **OK**, which puts the keyboard away. The field keeps
  the focus all along (the keyboard types into it, the bar mirrors it) and the bar's backdrop
  takes the taps, so nothing under it closes the keyboard. The keyboard closed by the phone (its
  back button), the bar goes and the dialog is back as it was. A keyboard drawn over the game
  (no resize) gets the bar above its height (`DisplayServer.virtual_keyboard_get_height()`). A
  computer has no virtual keyboard: nothing changes there. Checked with a fake keyboard
  (`SoftKeyboard.fake_height`, `SoftKeyboardTests`).
- **Interface size** (Options > Graphics): Big (the largest step that fits), Medium, Small: one or two
  steps smaller, never under x1, for more room on a big monitor; the floor's framing stays
  (`Settings.ui_size`, saved).
- **The safe area** (`SafeArea`, `src/ui/common/safe_area.gd`): a phone's camera hole, notch or
  rounded corners hide nothing. `DisplayServer.get_display_safe_area()`, in the canvas's units
  (screen pixels / `PixelGrid.ui_scale()`, rounded up to even units), moves in the edges of the
  HUD (everything but its full-screen tints and the Threshold's and the Deeps' overlays), the
  village's HUD, every `RpgWindow`'s board and title (the dim behind still covers the screen) and
  the touch joystick's zone. On a computer the window is the safe area. Tests simulate a cutout
  (`SafeArea.simulate()`, `PcTests._test_safe_area()`).
- The layouts are checked at 1280x720, 1366x768, 1920x1080, 2560x1440, 1280x800, 3440x1440,
  1024x768 and the phones' 2340x1080 and 1540x720: nothing out of the screen, no HUD control over
  another, on touch and on keys (`PcTests`). French runs 20-30% longer: in French, at 1280x720,
  1540x720, 2340x1080 and 2548x1296, every in-run panel is checked with its longest words
  (`PcTests._test_french_panels()`: the bag, the merchant saying why it can't sell, the forge
  taking out the longest rune's name or with no room for it, the four encounters, the pause, the
  options, the codex's tabs and every monster's page, the longest fragment, the ending's choice,
  the longest perks). Long words wrap; letters never go under `Fonts.SMALL`.

## Nothing opens by itself

Walking up to someone or something never opens a window, and a level up never does either: the
player decides when the fight stops.

- **Interact** (input action `interact`): standing by the merchant, the forge, an encounter or a
  pact door's stele, a round button fades in (0.12 s) above the spell, left of the skills' arc
  (`InteractButton`, 88 units across: left enough that the lines under the map never cover it), with the thing's picture and what
  tapping does on a plaque under it: **Trade** (the merchant), **Forge** (the smith), the
  encounter's own word (`EncounterDef.verb`: **Drink** at the spring, **Offer** at the blood
  altar, **Talk** to the grinning spirit, **Kneel** before the statue), **Read the pact** (a pact
  door, until it is sworn), **Read** (a fragment of the past lying on the floor: it opens in a
  panel over the paused game, a tap closes it; presentation.md, Boss stories). A soft gold ring lies at the thing's feet while the button is its.
  Tapping (or E / F, the right trigger) opens its window; walking out of reach hides the button.
  Closing the window leaves the button there: tap again to come back. Spent things (a used
  encounter, a sworn pact) offer nothing.
  How it works: a thing adds an `Interactable` child (`src/entities/interactable.gd`: its verb,
  icon, color, reach, `enabled`, signal `used`); the Game's `Interactor` gives the button to the
  nearest usable one in reach each physics frame (`focus_changed`, read by the HUD) and uses it
  when the action goes down (`Game.interact()` does the same). Anything can join without other
  code changing (an item on the ground could, later). Chests and stairs keep working by walking
  on them: they open no window.
- **The perk button** (input action `offers`): see [builds.md](builds.md#perks-and-relics). Left
  of the minimap, under the pause button: a glowing golden star, "Perks" under it and how many
  choices wait on a red badge; a ring of gold bursts out of it when one more comes (its words
  stay still). Hidden while none waits.
- Both are put away during the trial of the Threshold.

## Privacy and credits

The rules and their reasons: [../privacy-ops.md](../privacy-ops.md). On screen:

- **The Well's account** (`AccountDialog`, Options > Privacy > Account, with a server in the
  build): signed out, what an account is for and what it sends, then **Sign in** or **Create an
  account** (name, password, optional email, "Stay signed in on this device") and **Forgot your
  password?** (a code by email, then a new password). Signed in: the name, the recovery email,
  the online save's state, **Sync now**, **Change password**, **Sign out**, **Delete the account**
  (the password asked). Refusals in plain words under the form; it fits 1280x720 to 2548x1296 in
  French. **Two paths in the Well** (`CloudConflictDialog`, over the title or the account
  window): this device's progress and the online one side by side, **Keep this device's** or
  **Take the online one**, no Back out.

- **The statistics' questions** (`ConsentDialog`, over the title screen the first time it shows,
  and from the Options' switch): first **Before you go down**, "How old are you?" with **Under 16**
  and **16 or older** (only that answer is kept); under 16 it closes and is never asked again by
  itself. Then **Echoes of the Well** (the title in the Well's voice), "Gameplay statistics
  (optional)" and what is sent, to whom, for how long, in plain words (and that the runs also add
  to the Well's Toll, the world counters: only all players' sums are shown); a **Privacy policy**
  button; **Decline** and **Accept** side by side, the same size and look. Keys and gamepads start
  on the policy's button, never on Accept; Back (or closing) declines. Declined, it comes back
  after six months; accepted, never (until what is collected changes).
- **Options > Privacy** (its own tab): with a server in the build, **Leaderboards** on the left
  (the name, **Change**; **Publish my scores online**) and **Your data** on the right
  (**Gameplay statistics**: turning it on asks the questions, off at once; **Your online ID**: the
  random id, "none yet" before anything is on; **Delete my online data** (`DeleteDataDialog`: what it does, Cancel / Delete; then an email to the privacy
  address with the id, everything online off, the id forgotten, and the address and id shown in
  case no email opened). Always, under the leaderboards: **Policy and credits**, with **Privacy
  policy** and **Credits**.
- **The privacy policy** (`PrivacyPolicyPanel`, an `InfoPanel`): the short policy's sections from
  `data/online/privacy.tres`, translated, the contact filled in, and **Read the full policy
  online** once its address is set. A page that scrolls with touch, the wheel, keys or a gamepad.
- **The remote settings on the title** (`RemoteConfig`, docs/online.md "Remote settings"): a
  running event's plaque under Credits (its name in gold, then in small type the souls bonus,
  the floor event made more likely, the time left: "Encore 2 jours"), and the message of the day
  in gold in the tagline's place (at most two lines: the left column has no room for more on a
  phone once Resume shows). Both hidden when there are none, and before any online choice.
- **Credits** (`CreditsPanel`, from a **Credits** button under Leaderboards on the title screen,
  and from the Options): `data/credits/credits.tres` by section (made by, art, music and sound,
  engine and services), each with its makers, what it is in the game, its license and source,
  what was changed, and a **License** button showing the license file shipped with the game; for
  Godot, the engine's own license and third-party notices, read from the engine. The license
  files are packed into every build (the export presets' `include_filter`).
- **Send feedback** (`FeedbackDialog`, from the pause menu and from **Feedback** beside Credits on
  the title screen; how it is sent: [../online.md](../online.md#player-feedback)): a line in the
  Well's voice; the kind (**Bug**, **Idea**, **Other**: toggle buttons, Bug first) and how many
  characters are written; a text field (a phone opens its keyboard; the field's hint follows the
  kind); a refusal line (too short, too long, wait N seconds, no online service: Send is then
  off); **Include game info** (on; the line under it says what it adds, the run too in a run, or
  that only the words go); **Sign with my pseudonym: <name>#<tag>** (off; only when the player has one);
  a plain line saying where it goes and that it is linked to the device's random ID; **Privacy
  policy**, **Cancel**, **Send**. Sent, the form closes and a note at the top thanks the player in
  the Well's voice ("Thank you. Your words rise out of the Well to those who watch over it."),
  over everything for about 4 s, taking no taps. Keys and gamepads start on the first kind; Back
  closes it, the focus goes back to its button. It fits 1280x720 in French: the form in a dark
  inset, two columns (what is written | the switches and what goes with it), its controls a
  finger's size.
- Back closes the page or dialog on top first (the title's and the Options' `back()`/`close()`).

## On a phone

- **The run is saved** (`RunSave`, `user://run.json`) when a floor begins and whenever the app goes
  to the background (a call, switching apps...). The title screen then offers **Continue**: same
  depth (a fresh floor), the hero exactly as saved (level, stats, gear, bag, perks, spell, the
  perk choices still waiting, the one on screen with its cards). Dying erases it. "Save and quit" in the pause menu does the same on purpose.
  Never during the trial of the Threshold: quit in there, and the run picks up as it was before
  the killing blow.
- **Pause menu** (the II button, Escape, a gamepad's Start, or the phone's back button): resume, options,
  **Difficulty** (lower it for the rest of this run only, never raise it: `RunDifficultyDialog`, a
  button per lower difficulty with its description, and Back; the run is then aided, see
  progression.md "Help without judgement"), bestiary, **Send feedback**, save and quit, give up the
  run (two taps). Coming back to the app, the game waits paused. Three columns in a dark inset,
  each button (340x64) with what it does under it, 16 units and more between them: the eight rows
  (3, 3, 2) and the help line fit a 720-line screen in French, with room for one more.
- **Options** (`Settings` autoload, `user://settings.cfg`), on the title screen and in the pause menu:
  five volumes (**General**, **Music**, **Interface**, **Combat**, **Ambience**: which sounds
  each one sets is in presentation.md, SFX; a slider follows the finger or the mouse smoothly (a
  step of 0.01), applies while dragged (the volume heard at once, the file written when
  it is let go), jumps where its track is tapped, and moves by 5% (shake 10%) a key or a gamepad
  press (`MenuNav.KEY_STEP`); it is 48 units tall, for a finger; letting go plays a sound of what
  it sets: a click, a hit, coins; settings files from before, with one sound volume, give it to Interface,
  Combat and Ambience), screen shake, **buttons size** of the touch controls (Normal or Large: whole
  steps of 1 and 1.25, `Settings.CONTROLS_SIZES`, that keep every button at its minimum and out of
  the joystick's zone on a 1280x720 canvas; a settings file from before, 0.7 to 1.3, takes the
  nearest), **large text** and the **text speed** (Reading, below), **vibrations** (big shakes,
  hits you land, crits; `Settings.vibrate()`; exported Android builds need the Vibrate permission),
  **fixed joystick** (it stays in its corner and starts only when touched there, instead of
  appearing under the thumb), **battery saver** (30 FPS cap, `Engine.max_fps`), **fewer effects**
  (half the particles in `Vfx.burst`; no heat, cold or pull distortion, no bloom, halos' inner
  band only), **screen flashes** (lightning lights the screen for one frame, at most 3 a second;
  off for players sensitive to flashes), **run timer** (on/off), **auto loot** (All / Better only /
  By hand, three buttons, the picked one's rule spelled out under them; see design/loot.md),
  **boss stories** (Full / Short / Off, three buttons the same way: the cinematic before a
  warden's fight, presentation.md "Boss stories"),
  **tutorial hints** (on/off) and **Replay tutorial**, the **Souls' Aid** (*Aide des âmes*: on/off,
  its line saying what it takes away now and that its runs set no records; kept in the Profile, not
  in Settings, like a save file's own setting: progression.md), on a computer **fullscreen**, the
**interface size** (Big / Medium / Small), and the **language** (English / Français,
  see Languages). The window (`OptionsPanel`, built in code on `MenuWindow`) has five tabs, each
  option with a one-line "what it does"; on/off options are big switches, and tapping an
  option's name flips it too; a choice of a few (language, auto loot, boss stories, interface
  size) is a row of buttons under its name, the one in use pressed:
  - **Gameplay** (opens first): Language (first, for a player who can't read the one in use),
    Loot (auto loot), Story (boss stories); Difficulty (the Souls' Aid), In a run (run timer,
    screen shake, vibrations, charge without holding), Reading (large text, text speed: Slow /
    Normal / Fast / At once), Tutorial (hints, Replay tutorial).
  - **Graphics**: Screen (fullscreen on a computer, interface size), Touch controls (buttons
    size: Normal / Large, fixed joystick); Effects and battery (fewer effects, screen flashes,
    battery saver).
  - **Audio**: the five volumes, long sliders in one column.
  - **Controls**: the keys and buttons of the device in use (the Controls page, above).
  - **Privacy**: leaderboards, the player's data, the policy and the credits (Privacy and
    credits, above).

  The tabs are a row under the header (a tap, a click, Q / E, LB / RB: `MenuNav`, group
  `menu_tabs`, wrapping around); their list is `OptionsPanel.Tab` / `TAB_NAMES`, each page built by
  its own `_build_<tab>()`. Each page has one or two columns that scroll on their own: at 720
  lines in French, Gameplay's and Graphics' columns scroll a little. Every control is a finger's
  (switches, choice buttons and sliders 64 units tall) with 16 units between rows
  (`OptionRows.ROW_GAP`); a choice's name sits 4 units over its buttons. Saved keys
  are unchanged (`Settings`, the Leaderboards and Privacy files).
- **Loot left on the ground** (auto loot, or no room in the bag): while the hero stands on it, a
  small board (`LootPrompt`, built by the HUD from `Events.loot_offered` / `loot_left`) shows its
  slot and, in a dark inset, its name in its rarity, its type and the first changes against what
  is worn (green / red), with **Take** (64 units tall); with no room, the button reads "Open the
  bag". On touch it sits above the belt row and the roll, 16 units left of the other round
  buttons (`LootPrompt.place()`, from `Hud.touch_rects()`); where Take would then fall within 16
  units of the joystick's zone (Large buttons on a 1280-wide canvas) it goes to the top middle,
  under the boss bar. With keys, low in the middle over the action bar. Only the button catches
  touches (the joystick's thumb may slide under the board). A full bag also says so in a toast.
- **The trial of the Threshold** (`ThresholdHud`, built by the HUD from the `Threshold`'s signals):
  its name and rule across the screen for three seconds ("The Threshold" / "Slay 8 spectres before
  the knell"), then a panel at the top center with the spectres slain ("Slain 3 / 8") and a big
  countdown in seconds, red in the last ten, pixel brackets flashing round it each second (its
  digits stay still). The minimap, the seal, the boss bar and
  the bag button are put away until the hero is back; a toast says he came back ("You come back
  from the Threshold."), a red banner that the knell has tolled.
- **Minimap** (`Minimap`): rooms are revealed when you walk in, corridors around you; it shows holes,
  the stairs (violet while sealed), unopened chests, a running ambush, a pact door once seen (its
  room outlined during the fight), the boss and, near the end of a seal, the last monsters. Tap it
  for the whole floor. During a pact's fight a line under it (`PactLine`) names the pact and how its
  rule holds ("Untouched", "18 s left").

## Tutorial

No separate tutorial level: the first run teaches as it goes. A small wooden board comes up at the
top of the screen (`HintBox`), its title in gold over **one line** saying what to do, and, when it
is about a control, a gold ring pulses around it with an arrow. The board is as wide as its line,
up to 640 units of text (`HintBox.MAX_TEXT`: every hint fits that in English and French, by touch,
keys and gamepad, `FirstRunTests.run_hints()`; a longer key name wraps); it keeps clear of the
HUD's top corners where the screen allows (centred in the room between the stats and the map's
column, `Hud.top_room()`, on a phone; against the right one at 1280 wide, the Health numbers in
sight). Its line sits in a dark inset and is reading text: with Large text it is TITLE and the
board may grow to that room (at most 880), then wraps. A hint shows **once ever** once read (`Profile.hints_seen`):
a tap or a click (or OK) on it, or what it asks done. One whose time runs out unread comes back on
a later floor, once (`TutorialDef.unread_returns`), the next steps of its chain with it; then it
counts as seen. One at a time, never over a menu or a big banner. A hint about a control says it
in the device's words ("Tap the big button" / "Press [Space]", `HintDef.button_text`). The
codex's **Tips** tab lists the hints seen, to read again, in the device's words.

- **First steps**: move (it stays until you have walked a few tiles), then the sealed stairs; when
  a monster first sees you, attack (tap; until you swing), then roll, then the weapon's two
  skills, then the charged attack (pointing at the attack button until one is unleashed).
- **The first time something happens**: low health (drink a potion from the belt), gear in the bag
  (open the Bag), your first soul, a perk waiting (pointing at the perk button until it is
  tapped), a family bonus, a spell, an elite, a rune, the forge, the merchant, an encounter, a pact
  door (these four say to walk up and tap Interact, and point at its button as soon as it shows:
  a hint's ring follows its control), a chest, an ambush, a boss, the stairs opening, a cursed or
  strange floor, cold and heat, the first trial of the Threshold (pointing at its countdown, once its
  name is gone).
- **Data**: `data/tutorial/tutorial.tres` (`TutorialDef`): the hints (`HintDef`: its cue, the hint
  it comes after, a condition, the title and text, the HUD control it points at, the action that
  ends it or how long it stays, its priority) and the distances and thresholds. The cues, actions
  and conditions are listed in `Tutorial` (`src/game/tutorial.gd`); the controls are the HUD's
  unique names (`Hud.hint_target()`).
- **Options**: "Tutorial hints" turns them off; "Replay tutorial" shows them all again.

## Text

The font is **Pixel Operator 8** by Jayvee Enaguas (CC0, `assets/fonts/PixelOperator8.ttf`, used
through `assets/fonts/pixel_operator.tres`): pixel art on an 8-pixel em (800 units, 100 a pixel),
capitals 7 pixels high (an accented capital too: its accent is drawn inside them), a descender of
1, strokes 1 pixel wide. It is drawn sharp (no antialiasing, hinting, subpixel positioning or
mipmaps), so a letter stays whole only when one of its pixels covers a whole number of screen
pixels; otherwise some rows and columns double and others vanish, and letters look cut. The UI is
laid out at 1280x720 and stretched (`canvas_items`, `PixelGrid`): x1 on a 720-line window, x1.5 on
most phones (1080 lines), x2 on 1440.

- **Sizes** (`Fonts`, `src/core/fonts.gd`), multiples of 16 (2, 4, 6 UI pixels a font pixel: whole
  at x1, x1.5 and x2): **`Fonts.BODY` 16** for everything read (sentences, notes, buttons, names,
  headings in a panel), **`Fonts.TITLE` 32** (the story, a difficulty's or a monster's name, big
  numbers, the Descend and Resume buttons), **`Fonts.HUGE` 48** (the game's name, act and curse
  cards, the Threshold's countdown). A font pixel is as many UI pixels as the old font's was at
  18, 36 and 54, so text keeps its size on screen (capitals a pixel taller, letters a little
  wider).
  **`Fonts.SMALL` 12**, the one size off the grid, only for fine print BODY cannot fit (a slot's
  item level and empty-slot words, the difficulty cards' lists, the oath cards, a perk card's
  level and family bonus and the perk choice's two rules under and over the cards, the Daily
  button's second line, the Tree of Souls' branch lines): nothing under 16 is whole on a phone.
  12 is 1.5 UI pixels a font pixel: 2.25 screen pixels on a phone (one row or column in four a
  pixel thicker), whole at x2, uneven on a 720-line screen (1 and 2 by turns). 8 (one UI pixel)
  would be whole at x1 and x2 but double every other row on a phone, where most players are, and
  is too small to read there. No size in between: hierarchy comes from color (gold headings, dim
  notes), ribbons and boards. The unit, title and game suites hold every scene, the theme and the
  panels built in code to `Fonts.SIZES`; the unit suite checks the theme's font is Pixel Operator
  8 and every size but SMALL is on the 16-grid.
- **Lines**: the font's em holds its capitals with no room above them, so labels stacked one under
  the other would touch. `pixel_operator.tres` adds 4 UI pixels over each line and 2 under it, and
  the theme's Label 2 between wrapped lines: even numbers, so at BODY every line starts on a whole
  font pixel (the baseline doesn't move: text drawn by hand is unchanged).
- **The Regular only.** The pack's Bold was tried on the game's name and the Descend button: it
  stays on the grid, but it is a font pixel wider a letter (titles a seventh wider: a monster's
  name in the codex, the banners wrap sooner) and its accented capitals (Â, É) close into blobs
  at HUGE; the Regular with its one-pixel outline already reads heavy enough.
- **Glyphs the font lacks**: the controls' prompt glyphs (PlayStation's ✕ ○ □ △, the arrows) and
  the narrow no-break space were drawn on its grid in its style by `tools/i18n/add_glyphs.py`
  (docs/translating.md).
- **Outline**: one font pixel (`Fonts.outline_size()`: 6 at SMALL, 8 at BODY, 16 at TITLE, 24 at HUGE), set by
  `UiSkin.label()`, `UiSkin.set_text_style()` and the theme's Label. It is drawn under the letters
  and never eats a stroke. Dark words on the orange buttons have none.
- **Drawn by hand** (`Fonts.draw()`: damage numbers, signs and names over the world, the HUD's
  round buttons, slots, the Tree of Souls): the size is counted in UI units whatever the camera's
  zoom, and the text is put on a whole screen pixel, with the same outline. Damage numbers pop in
  at TITLE for an instant, then settle at BODY (no in-between scale). Text centred in a disc, a
  slot or a bar puts its baseline half a capital under the middle (`Fonts.half_cap()`).
- **Half pixels**: at x1.5 an odd UI position falls between two screen pixels, where every pixel
  samples a letter's texture right on an edge and picks a side by rounding luck. `PixelGrid`
  (autoload) shifts the whole screen a quarter of a pixel, which takes whole and half positions
  off those edges.
- A wrapped line never splits a stat from its number (the HUD's info line uses unbreakable
  spaces).
- **Large text** (Options > Gameplay > Reading, `Settings.large_text`; **on by default on a
  phone**, off on a computer): reading text one whole font step bigger, `Fonts.TITLE` instead of
  `BODY` (`UiSkin.reading_size()`, `reading_label()`): what someone says (`DialogueBox`, the
  village's words), tutorial hints (their board 880 wide), a monster's description and a
  warden's chronicle in the codex, a fragment's lines, an item's details. On the S23 BODY is
  about a third of the size the Xbox guidelines ask of mobile text; 24 would not be whole at
  x1.5, so the next step is 32. Panels holding it scroll (the codex, the item card, the village's
  words, a fragment longer than the screen: a finger on its words then scrolls instead of
  closing it) or page (`DialogueBox`), never shrink it; every one fits 2340x1080, 1540x720 and
  1280x720 in French (`PcTests._test_large_text()`), which is why it is the phone's default.
- **Typing** (`DialogueBox`, the village's words, a cinematic's lines): the words are laid out
  before they are typed (`UiSkin.typed()`: `VC_CHARS_AFTER_SHAPING`), so a word never starts on
  one line and jumps to the next. The pace is the speaker's times the **text speed** (Slow 0.6,
  Normal 1, Fast 1.8, At once: each page written out; `Settings.text_speed`); a tap writes a
  page out at any speed.
- **Dialogue lines**: the shrine's box (`DialogueScreen`, 932 wide: a wooden board around the
  `DialogueBox`'s dark inset) holds at most 60 characters a line in French at BODY (about 58 the
  longest) and 3 lines a page: a longer page goes on to another, cut at a line's end
  (`DialogueBox.split_page()`, `MAX_LINES`); the board follows each page's height.
- **Sentence case** for the interface's words in both languages ("Level up", "Victory achieved",
  "Daily descent", "Tomes & scrolls"); names keep their capitals (docs/lexicon.md: places,
  beings, items, perks, achievements), and the bosses' shouted cries stay in capitals: they are
  flavour, a voice, not interface.

## One skin (binding)

Every window, panel, dialogue box, card and button of the game wears **one skin**, built only
from `src/ui/common/`: the wooden `OrnateBoard` with its gold border (under `RpgWindow` and
`RpgDialog`), the red ribbon for titles, dark insets for lists and text, `UiParts.button()` for
buttons, and the colours of `UiSkin` ([decision 0003](../decisions/0003-one-ui-skin.md)). No other
frame exists: no white or light panel, no `StyleBoxFlat`, no box drawn from another asset.
**Checked**: `tools/design/check.py` fails on a `StyleBoxFlat`/`StyleBoxTexture` built outside
`src/ui/common/` (its list of older files is empty since 28 Oct 2026: rows, slots, notes and
coloured edges come from `UiSkin.band()`, `slot_frame()`, `note_box()`, `draw_edge()`), on an
inline StyleBox in a scene, and on an odd separation, margin or minimum size in the interface's
code. A new frame style or colour token is the owner's decision.

Numbers to hold (sources in [the art bible](../art-bible.md)'s research report):

- **Touch**: combat buttons (attack, dodge, skills) have a touch area of at least **96 x 96**
  units (about 9 mm on the S23; Android asks 48 dp, about 9 mm); anything else tappable at least
  **64 x 64** (`MenuWindow.TOUCH_MIN`: the button factory, `TabRow`, Close, the options' rows,
  slots and tabs hold it); at least **16** units between targets (`MenuWindow.TOUCH_GAP`);
  nothing tappable within 16 units of the stick's zone; everything anchored inside the safe area
  (`SafeArea`, never an absolute x). The HUD's round buttons are laid out in `hud.tscn` for the
  buttons size 1 (attack 144 across, skills 96, belt 64, Interact 88, centres on multiples of 8
  and radii of 4 units) and grown by the size step chosen, never by the Control's scale; checked
  at 2340x1080, 1920x1080 and 1280x720 at every step (`PcTests._test_touch_targets()`, U4) and in
  the pause menu, the options, the bag, the merchant, the forge and a village conversation
  (`_test_menu_targets()`).
- **Text**: never below `Fonts.SMALL`; French is 20-30 % longer and never cut; at most about 60
  characters per line and 3 visible lines in a dialogue; sentence case; text contrast 4.5:1
  (large or disabled 3:1). Measured on the skin's own textures (`PcTests._test_contrast()`):
  TEXT, GOLD, DIM, GOOD and BAD on an inset 4.8 to 12.6:1; a button's words 5.1:1, pressed 5.8,
  disabled 3.6 (UiSkin.DIM, no longer half-transparent dark words); the dark outline every label
  wears 4.3:1 on the wood, the words 16.5:1 on it. **Reading text sits in dark insets, never on
  the bare wood; DIM and BAD never go on the wood** (1.5 to 2.6:1 there; checked on every in-run
  panel in French, `PcTests._dim_on_wood()`); a lone note on the wood is TEXT.
- **Colour is never the only cue** (rarity, danger, affordability get a shape or an icon too):
  in a slot, gear's rarity has its pips (Magic one, Rare two, Epic three, bottom right) and a
  rune its family's sign (a flame, a snowflake, a drop, a bolt, a star; `ItemSlot`); a boss in
  the codex has the word "Boss" with its red name.
- **Feedback**: a pressed state on press (an item slot sinks, the minimap flashes a gold frame),
  the shared UI sounds (the village's conversations too: opening, a choice, Close), open/close
  in at most 0.15 s on whole art pixels (the perk choice rises 12 units on even steps); nothing
  to read shakes or blinks: a number that changes (souls, the seal broken, the Threshold's last
  seconds, gold in the bag) flashes pixel brackets round its still words (`TextCue`), the perk
  button a ring, the temperature bar stays lighter at the extreme instead of blinking.
- **Pixels**: offsets, sizes and margins in steps of 2 units; Control scale 1 or 2; Nearest.
  The skin's pieces (`assets/ui/rpg/`, `assets/ui/wood/`) are 16-pixel art stored at **2 units
  per art pixel**, like the font and the world's art: 2 screen pixels at x1, 3 on a phone (x1.5),
  4 at x2 ([decision 0013](../decisions/0013-ui-skin-two-units.md); until 28 Oct 2026 they were at
  x3, 4.5 screen pixels on a phone, `tools/ui/rescale_skin.py`). Their nine-patch margins count
  whole art pixels (even units: the wood 10, insets and slots 10, the rarity frame and buttons
  6, the ornate border 28 and `OrnateBoard.INSET` 6, the ribbon's ends 32), so two pieces laid
  over each other keep their pixels in step; where a piece stretches, the rows and columns it
  repeats are alike (the ribbon's middle, the plaque's), so nothing is drawn at an uneven size.
  The UI's own pictures follow the cameras' rule (`PixelGrid.art_scale()`): the HUD's round
  buttons and the joystick draw their 32-pixel spheres, slots their icons and the bestiary its
  monsters (a page's look, the attack preview's bodies: `MonsterPage.look_scale_for()`,
  `AttackPreview.whole_body()`), as big as their room allows with each art pixel on a whole
  number of screen pixels, rounded down (the attack's sphere 128 units across on a phone, its
  touch circle still 144). **Checked**:
  `PcTests._test_skin_grid()`, `_test_round_buttons_whole()`, `_test_codex_whole()`.

Before calling a screen done: captures at 2340x1080, 1920x1080 and 1280x720
(`tools/design/capture.py`), in French and English; the same border, ribbon and insets as the
other windows; gamepad only, keyboard only, touch only (focus visible, Back closes).

## Shared pieces (one way to build each)

Every window is built from the same pieces in `src/ui/common/`, so they look and behave alike:

- **The board**: `OrnateBoard`, the wood with its gold ornate border, under both `RpgWindow`
  (full screen) and `RpgDialog` (centred). `RpgWindow`'s header is `header_left`, a spacer,
  `header_right`, Back's key and `close_button`: windows add to its parts, never reach into the
  row by index (`MenuWindow` gives `header_left` the room for a line of text).
- **Tabs**: `TabRow`, for the options, the codex, the bag (its `BagTab`s, 64x64 in two rows of
  three), the debug panel and the leaderboards (the boards and the Toll; the periods are a second
  row, not menu tabs): toggle buttons of one size (112x64 at least), 16 units apart, the one shown
  pressed, a click when another is picked, the tab keys' cap before them, the group `menu_tabs`
  (Q / E, LB / RB).
- **The item card**: `ItemCard`, the bag's and the merchant's: slot, name in its rarity, type,
  details, the comparison with what is worn in green and red lines.
- **Small helpers**: `UiParts.button()` (built on `MenuWindow.button()`, the one button
  factory), `UiParts.stat_rows()` (the bag's stats, the end of a run), `UiParts.bullet()` (a
  dash, then a wrapped line: never "- " glued to a sentence), `ExposedNodes` (a panel's built
  nodes reachable as %Name once it is built), `OptionRows` (the options' rows; `PrivacyPage` and
  `ControlsPage` are pages of their own), `HudEventCard` (the Threshold's and the Deeps' name and
  rule across the screen and their banner).
- **Colors**: `UiSkin` names the interface's colors once: `TEXT`, `GOLD` (= `Palette.GOLD`),
  `DIM`, `GOOD`, `BAD` and the dim `backdrop()` behind windows; no panel keeps its own copy (a
  unit check). Scenes (`.tscn`) still write the gold as its value.
- **"Tap or press to continue"**: `TapGate` (Devices, above).

## Bag, forge and the other in-run screens

The bag, the forge, the shop, encounters, perk choices, the pause menu and the end of a run are drawn in the game's RPG skin (`UiSkin`, `src/ui/common/`): a wooden
board with a gold ornate border (`RpgWindow`), the title on a red ribbon, dark recesses for each
column, scroll bars and sliders in the same pixel art (`assets/theme/main_theme.tres`, pieces in
`assets/ui/scroll/`: a dark groove, a riveted gold bar, a gold fill and a gold knob), and items in square slots (`ItemSlot`): the icon at a whole-pixel scale, a frame in the
item's rarity color (a rune's in its family's), how many, and a weapon's rune sockets as little
stones lit in their runes' colors. The selected slot pulses gold.

- **Bag** (`InventoryPanel`, built in code): the hero, the weapon / head / body slots, the belt and
  the stats on the left (the hero is his own rig, `HeroPortrait`: dressed as his body in the
  world, his weapon slung on his back with its elements, his armor with its rarity's trim and its
  affixes' marks, idling at 4 screen pixels per art pixel, 20x22 art pixels); the bag in the middle, one compartment at a time (its tab), and under it
  **Dismantle the worse (n)** (the tab's worse gear); the picked item's card on the right (name in its rarity,
  type, every line of its details, for gear in the bag how it compares with what is worn, as at
  the merchant: a gold heading, each change in green or red (`ItemCard`, shared with the shop),
  its rune sockets, for gear in the bag "Dismantle value: 12
  gold") with its actions' buttons. Dismantle the worse opens a confirmation (`DismantleWorseDialog`, an `RpgDialog`): how
  many and the gold, their slots, "what you wear, potions, runes, tomes and keys are never
  touched", Dismantle: +n gold / Keep them. Gold won flies as coins to the counter (`GoldBurst`)
  with the coin sound.
  - **Compartments and their tabs** (`Inventory`, `BagCategorySet`,
    `data/items/bag_categories.tres`; `BagTab`): the bag is six compartments, each with its own
    places (loot.md, "Room in the bag"): **Weapons** (Armes), **Armors** (Armures), **Runes**,
    **Tomes & scrolls** (Grimoires & parchemins: the tomes and the Scroll of Fire),
    **Consumables** (Consommables) and **Other** (Divers: keys, and whatever no compartment
    claims; its tab hidden while empty). Two rows of wooden tabs over the grid (64x64, 16 apart), each with its
    pictogram in the middle (`assets/ui/placeholders/`, drawn by `tools/ui/make_placeholders.py`:
    a plain sign, never an item of the game; the empty equipment slots show the same signs, faint),
    how many items it holds when any (a stack counts all of its own; red when the compartment is full) and
    a small gold gem while something new waits in it; under them the open tab's name and its own
    places ("Runes  3 / 16", red when full), between its keys on keys and gamepads ([Q] Weapons
    16 / 16 [E], [LB] ... [RB]). While any compartment is full, the HUD's Bag button wears a small red dot in its top
    right corner (`BagFullMark`), so a full compartment is known before the next loot stays on
    the ground (the pickup's toast says it only once). A compartment holding more than its places (a run saved before,
    a compartment made smaller) keeps it all and says so under it ("More than it has room for:
    make room before anything new goes in."). Tap a tab, or Q / E, LB / RB (`MenuNav`,
    "menu_tabs"). The tab picked stays picked until the run ends (the bag opens on it); a new
    run, Restart included, opens it on the first tab with nothing seen yet.
  - **In a tab**: a 3-column grid of slots 16 units apart (scrolling), one slot per stack with its count ("x3"), the rarest first,
    then weapons, helms, body armors (a rune's family, a consumable's kind), the higher item
    level, then by name; after them the compartment's free places (empty slots). A slot new since the bag
    was last closed (or the item last picked) has the gold gem in its corner; what is worn or on
    the belt is never new.
  - **Actions** (`BagAction`, `src/ui/inventory/actions/`): Equip / Unequip / Learn / Use (not
    for runes and keys), To belt / To bag (consumables), Drop (the bag's items), Dismantle (gear
    in the bag, never what is worn). Each is a button on the card (touch, mouse, the focus), and
    the first, third and fourth also a key on the item itself, no menu in between: Enter or
    Space / a gamepad's A uses it (only on an item's slot: on a button, Enter presses the
    button), X or Delete / X dismantles, G / Y drops; each button shows its key or button over
    its top edge (`PromptGlyph.badge`, nothing on touch). A right click on a slot uses it too. A
    Rare or Epic piece, or one with a rune set, asks a second press before it breaks
    (`DismantleRules.needs_confirm`): the button says "Sure?" and the card "Press [X] again to
    break it: +40 gold" ("Tap again..." on touch); Back (Escape, B) takes the question back
    first, picking another item does too. Commons and Magic pieces go at once, one of a stack
    per press. After one of a stack is used, dropped or dismantled, the rest stays picked; with
    keys, the focus goes on to the slot that took the gone stack's place, so X X X goes through
    a tab of junk. The buttons flow to a second row when they don't fit (French on a 1280-wide
    canvas), and the card's details scroll with the right stick (its cap shows while there is
    more), the mouse wheel or a finger.
  - **Keys and gamepads**: the focus is the pick (moving onto a slot shows its card; on touch and
    with the mouse a tap or click picks). The bag opens on the open tab's first slot; switching
    tabs puts the focus on the new tab's first slot. The empty places can take the focus too
    (nothing to do there), so the arrows never jump out of the grid.
- **Forge** (`ForgePanel`): the smith and what he says; the weapons you can work on as slots, the
  picked one big with its sockets; your runes as a grid. Pick a rune, then "Set it in"; pick a
  set rune, then "Take out (gold)".
- **Shop** (`ShopPanel`, built in code): the merchant and your gold on top; what he sells as slots
  with their price (a padlock on locked ones) and Reroll ("new items for sale, locked ones stay");
  what you carry with what he pays; the picked item's card: its stats in words, how it compares
  with what you wear (`ItemCompare`: "+3 damage", "-12 move speed", in green / red), its price,
  Buy (greyed with the reason: not enough gold, bag full), Lock (what it does, spelled out) or Sell.
- **Encounters** (`EncounterPanel`): one card per choice with its cost and every outcome in plain
  words with its odds ("55%  Heals you fully", `EncounterChoice.chances()`,
  `EncounterOutcome.summary()`), risks in red; Leave ("nothing happens, you can come back").
- **Perk choice**, **pause menu** and **end of a run** use `RpgDialog` (a centred board, no Close):
  the cards on dark wood with Reroll / Banish explained and **Later** (the choice waits behind the
  perk button; Back does the same), coming in softly (the world dims, the board rises 12 units on
  even steps, 0.15 s)
  instead of cutting over the fight; each pause button says what it does, with
  what gold and souls are for; the end screen shows the run's numbers (`RunState.summary_rows()`;
  an aided run says it sets no records), the souls earned and what they buy. After a death, the
  Vigil-Keeper's tale and advice sit under the title in her `DialogueBox` (presentation.md); with
  nothing for her to say, the story's line. A death's buttons: **Descend again** (straight into the
  next descent, as the Well would start it: the difficulty, ascension and oath chosen there, a Dawn
  Knell again as practice; the run that ended recorded and its save erased first; no walk through
  Kagari, `Game.descend_again()`), Return to village, Title screen. A victory keeps Keep going
  (endless), Return to village, Title screen.
- **Keepers' words**: the shop and the forge open on a line of the merchant's or the smith's
  (their dialogue's, else a greeting) in quotes beside their face; the grinning spirit's line
  shows in place of its encounter's description, in its color (the panel keeps its height on a
  720-line screen), and the outcome takes its place when a choice is made.
- **Codex, Voices** (*Paroles*): what each speaker said and is kept, by speaker, and how many
  lines are still to hear. **Tips** (*Conseils*): the tutorial's hints seen, title and line. With
  six tabs the header holds the tabs and Close; the souls sit at the end of the tab's summary line.


## Active product and input ownership

The active F5/export path is TitleScreen → story/Kagari → the Well → new or resumed Game. The
very first Play (a profile with no run and none saved, `Game.first_descent_due()`) goes title →
the privacy questions if still due → the story (skippable) → the Game on floor 1 at Keeper, with
no Kagari, Well or choice before it (decision 0010); the button says **Descend** then, **Enter
Kagari** afterwards. Shrine, daily runs,
perk choices, end of run, records and options keep their normal roles. The standalone RPG
campaign/menu is [archived for a separate project](../rpg-archive.md).

PlayerControls consumes one reused command from its own producer; local input still uses all
existing bindings. Replacing/detaching a producer stops held movement/charging, and closing a
menu still mutes the first press. Old death/descent/fade work checks its session ticket before
showing panels, advancing or tinting a new run. The inventory checks that its previously bound
hero is still valid before disconnecting signals.

## Village interaction

[Kagari](village.md) replaces direct run launch with walking to the central well (but for the
very first descent, which starts from the title: village.md "The first return"). Approach an
inhabitant, shrine or statue and press the normal Interact action; touch uses the existing stick
and ActionButton. Conversations, restoration purchases and memorials use the scrollable Ninja Adventure
VillagePanel and stop walking. The conversation sits low on screen with its portrait, readable
words (typed like the DialogueBox's, a tap writes them out; reading size) and separate choices
64 units tall, 16 apart; the world remains visible. Longer replies and services scroll. New descents explicitly ask before replacing a saved run. Pause and end-of-run
Return to village buttons lead back to the square; the pause path keeps the active save.

The village HUD shows day/time and a **Quests** button. The wooden noticeboard opens the same
journal, also available through **Quest journal** in the dungeon pause menu. Village requests
show status, objective, reward and contact/schedule above the existing real-date bounties.
Reading freezes village time and movement. Nighttime residents can still answer a knock at
their doorway. World tint leaves HUD and modal text unchanged. The temple door leads to a walkable interior with the skills shrine. Houses still await
residential art. A fresh Interact press enters/leaves; opening a modal blocks door crossings.
The camera, HUD place name, lighting and interaction scope follow the current room.
