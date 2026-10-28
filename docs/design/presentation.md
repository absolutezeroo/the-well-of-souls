# Look, sound and feel

## Game feel

- **Weight of a blow**: every hit you land pushes the camera a few pixels along the blow, a shot
  recoils it back, a hit taken knocks it away (`GameCamera.kick`, `Events.camera_kick`, springing
  back in real time, apart from the shake; both follow the Screen shake option). A killing blow
  stops the world a moment longer; killing an elite or better slows it down for a beat
  (`HitStop.slow`).
- **What monsters are made of** (`ImpactMaterialDef`, `data/materials/`: flesh, bone, slime,
  armor, spirit, plant; `MonsterDef.material`): a hit sounds like it (a punch in flesh, a dry knock
  on bone, a squelch, a clang on armor, a chime on spirits, played over the monster's cry), its
  sparks take its color, and when it dies it flings **chips** of itself that land and stay for the
  whole floor (`SplatLayer.add_debris`): bone shards, slime drops, bits of armor. Broken crates and
  barrels leave their splinters too. Sounds: Kenney "Impact Sounds" (CC0).
- **VFX** (the style guide, its rules and every element's kit: [docs/vfx.md](../vfx.md)): every
  effect speaks its **element** (`VfxElementDef`, `data/vfx/elements/`: a ramp of 3-5 colors, a
  particle shape, a direction of motion, a kit of sheets), on the art's 2-unit pixel grid, never
  stretched or freely turned, fading by dithering. Frost is faceted ice shards drawn in 16
  directions, cracking impacts, novas of crystals growing then shattering, rime on chilled
  bodies; fire licks up, poison bubbles and sinks. Storm is violet-white lightning: ball-lightning
  sparks, crackles on the ground, Thunder's bolt from the sky, chain lightning forking from body
  to body, all flickering (strike, off, strike again). Holy is light from above: Smite's column,
  rings of thin shafts, Holy Shield's ring rising into a halo, and the holy sigil drawn by every
  heal, buff, learned skill and level up (in the heal's own color when it isn't holy). Shadow
  shots (Sorcerer, Octopus ink, Shaman hex) are dark knots with a burning rim that collapse
  inward; Shadow Step bursts into shadow and leaves smoke. Arcane is a diamond glint with motes
  orbiting it. Hand-drawn sprite-sheet effects
  (slashes, claws, explosions, smoke, "!" emote when a monster spots you) plus
  pixel particles for hits, dust and sparkles
  (`src/vfx/particles/*.tscn`, edit them in the inspector; `pixel_particles.gdshader` keeps them
  whole art pixels on the grid, their fades dithered), dash afterimages (dithered, in the dash's
  element; plain rushes like a beast's Charge also kick up dust), animated projectiles,
  squash on hit, popping damage numbers, red vignette when hurt or low on HP.
- **Atmosphere** (`AmbienceDef` > Atmosphere, one per biome and curse): the whole picture takes
  the biome's colors (`screen.gdshader`: shadows and highlights graded toward two tints,
  saturation, contrast), bright things **bloom** (a flat rim of light one art pixel wide around
  them, never a blur), the air **trembles** with heat in the ruins and the desert (rows of pixels
  sliding by whole pixels). Glowing effects (fire, frost, holy, storm, arcane, poison, spirit)
  keep most of their own colors under the biome's grading (the emissive mask), so frost stays
  cyan in the warm ruins. Over the floor, in
  world space (`AtmosphereLayer`, `atmosphere.gdshader`, dithered on the art's grid): **shafts of
  light** falling from cracks above (garden, temple, library, cave, desert), **leaf shadows**
  drifting in the garden, **mist** creeping over the crypt and the flooded caverns, **water light**
  dancing on the floor of the flooded caverns.
- **Attack effects** (shaders, all on the art's pixel grid, quantized in world space so a
  diagonal blow has the same pixels as a straight one): a melee swing draws a crescent at the
  weapon's reach and arc (`SwingVfx`, `swing.gdshader`), the way the body faces (melee blows are
  struck in four directions like the sprites: builds.md, "Blows in four directions"), in steel (the `physical` ramp: a
  near-white cutting edge, greys behind, thinning out in dithered pixels) or in the weapon's
  element; a monster's carries a red warning rim. A thrust draws a streak. Slash skills and heavy
  monster blows are `SlashDef`s (`data/vfx/slashes/`): Cleave's double crescent, Whirlwind's and
  Lash's spins, Flurry's stabs ending on a cross, Iaido Dash's razor line, Piercing Thrust's
  lunge, the cyclops' clubs and the tengu's blade. Claws and bites keep their sheets (a weapon
  shows its arc or its sheet, never both: `WeaponDef.shows_arc()`). Hits flash for two frames
  and throw the blow's element's bits away from it (`ImpactVfx`: ice chips falling, embers
  rising; a plain blow throws short streaks), plus the bits of what the monster is made of
  (blood drops, bone chips, slime, sparks off armor, spirit motes, leaf chips); a crit also cuts
  a cross over the target. Blasts ripple the picture (`ShockwaveVfx`, a stamp of the screen pass).
  Monster warnings (`TelegraphView`, `telegraph.gdshader`): zone, cone, line or the lanes of a
  fan or ring of shots (so the gaps read), with crawling hazard stripes and a solid rim, filling
  up from the monster as the attack comes, flashing just before it lands; every monster shot
  and dash now warns (lanes, line). Shots leave a glowing streak.
- **Light, space and screen** (docs/vfx.md, "Shaders"): glowing cores have a stepped **halo**
  (two flat bands of added light in their element's darker steps, sparser on bright floors):
  fire's heart in braziers and campfires, magic shots, Smite's column foot, Thunder's strike, a
  glint on some Frost Nova crystals. Space bends in one screen pass: **heat** trembles above
  fires and rings of flame, a **cold shimmer** catches facets of the picture through a Frost Nova,
  shadow and arcane shots **pull** rings of the picture toward them, blasts send a **shockwave**.
  Braziers' and campfires' flames have **tongues** climbing through them, a poison cloud lies on
  the ground as **one pool of gas** (Spore Cloud, a Venomous burst): it wells out to the edge of
  the area it hits, a glowing rim exactly there, low wisps churning with the floor showing
  between them and bubbles popping, then sinks away (gas, not bushes), Smite's column
  **shimmers**, Thunder **flashes** the whole screen for one frame (at most 3 a second; Options >
  Screen flashes turns it off). The holy sigil, arcane glyphs and the pact's circle **draw
  themselves** stroke by stroke and burn out. Fewer effects drops the halos' outer band, the
  heat, cold and pull (shockwaves stay) and the bloom.
- **Layers** (docs/vfx.md, 2b): flat effects (sigils, rings, telegraphs, crackles, mist at the
  feet, elite auras) lie under every body; upright ones (ice crystals, rays and columns of
  light, bolts, smoke, dust) sort with the bodies by their base, so the hero stands among a
  Frost Nova's crystals and a crystal hides a monster behind it; shots, hits, blades and bursts
  are over everyone.
- **Shots and blasts**: magic shots (fireballs, bolts, spells) are their element's shot (the
  frost shard, drawn in 16 directions; round orbs are never turned), light the dark in its
  color, leave a trail of its bits and land in its language (`Vfx.pop`: the element's impact
  sheet, or a burst in its ramp); a shot at the end of its range breaks up instead of vanishing.
  Plain things (shurikens, arrows, feathers, coins: `projectile_glow` / `ProjectileEffect.glow`
  0) just fly: arrows, kunai, the thrown spear and the Crimson Tengu's crimson feathers are drawn
  in 16 directions (`data/vfx/sheets/`), shurikens and coins spin as they are. Explosions are their element's blast sheet at 2x (fire: a white-hot ball whose
  tongues lick out and up into dark smoke and embers; earth: the ground cracking open, chunks
  thrown up, a dust cloud rolling low, cracks that stay a moment), ringed by its pieces when
  wider than the sheet (flame licks, rock spikes), or a burst drawn by a shader in its ramp
  (`BlastVfx`) for the elements without one; a ripple and a mark on the floor (a scorch for
  fire). A boss's stomp is the ground bursting, whatever the boss is made of, and a trapped
  chest bursts apart in grit and dust (crates and barrels break the same way); powder kegs and
  bombs are fire.
- **Little details**: fights leave **splats** on the floor (`SplatLayer`, `World.add_splat`): blood,
  green slime, purple ink, bone dust, in each monster's `splat_color` (blood is the blood
  element's dark red; spirits and flames leave none), fading after a while. A glob of venom leaves
  a small puddle where it bursts, a wound a stain (`VfxElementDef.impact_mark`). What drinks blood
  shows it: a vampiric elite's hits, the Leech Rune, Vampirism and the Vampiric affix, Bloodlust's
  kills draw a few drops out of the victim into the drinker (`BloodDrainVfx`); Executioner's
  finishing blows and Bloodrage's wounded blows land in blood. **Plants sway** in a breeze and **bend** away from whoever walks
  through them (`DecorRuleDef.sway`, `SceneKey.sway`). Shallow water **glints** (`GroundLayerDef.shimmer`).
  Braziers and candles **burn** (`PropDef.flame`; a brazier with the fire kit's flames, like
  campfires and flame vents). The HP bars keep a pale **trail** of what a hit
  cost, then drain it; they glow when healed. Each biome has its **air**: fireflies in the garden,
  sand gusts in the desert, mist over the flooded caverns, dust in the library and the tomb.
  Gameplay code spawns them in one line through `Vfx` (`Vfx.hit(...)`, `Vfx.explosion(...)`).
- **Statuses on the body** (`StatusFx`, one per actor; looks in `data/vfx/status_looks/`,
  `StatusLookDef`, each in its element's ramp, on the body's pixel grid): a **burning** body
  throws small flames and embers and catches fire in a burst with a crackle; a **poisoned** one
  splashes as the venom takes, then bubbles (bubbles that swell and pop) and leaks a murky haze
  that sinks at its feet; a **wailed** one (a spirit's slow) flickers with small pale flames; a **chilled** one grows rime on its edges
  (it breaks into falling chips when the chill ends), sheds ice chips and breathes cold mist at
  its feet, with a burst of shards when it takes hold. Only frost and the cold show as frost:
  sand, ink, spores and quicksand slow without it, a wail with its own pale flicker (`OnHitStatus.slow_element`). The body
  itself is painted by the rig's shader in the status's element (`BodyLook`, docs/vfx.md
  section 9): heat crawling up the lower rim of a burning body, rime creeping in from the edges
  of a chilled one as the chill lasts (a hard chill freezes it over, a glint sweeping across), a
  green wave rising up a poisoned one on each tick, a pale flicker and a see-through rim on a
  wailed one; a storm hit crackles over the body for a frame or two. The particles are the
  accent. With **Fewer effects** the shader leaves the statuses alone and the body takes a steady
  45% tint of the status's color instead. Their ticks show in the status's color. Drawn by hand
  over the body, 24 bits at most each, and asleep when nothing is on it.
- **Deaths by element** (`DeathLookDef`, `data/vfx/deaths/`, one per element): a monster goes the
  way the blow that killed it was made (a burn's last tick counts): fire burns it to ash from the
  feet up, frost freezes it then shatters it into pieces of its own art, poison and water melt
  it into a puddle, storm and arcane flash it and scatter it in sparks, holy lifts it away as
  light, shadow sucks it into a dark point, spirit thins it into rising wisps, earth crumbles
  it; a plain blow or blood dissolves it pixel by pixel with its chunks, as before.
- **Elites** wear a rim of their rank's color around the body (one art pixel, a second dithered
  on the beat), on top of their aura at the feet.
- **SFX**: the `Sfx` autoload plays every sound. Weapons have attack and hit sounds, monsters hurt
  and death sounds, skills and consumables a use sound; everything else comes from
  `data/audio/sound_bank.tres`. Each sound is an `AudioStreamRandomizer` listing its variations.
  Every place has its own music: see [Music](#music).
  - **Buses** (`default_bus_layout.tres`), one per slider in Options:

    | Slider | Bus | What plays there | Call |
    |---|---|---|---|
    | General | Master | everything (a limiter at -1 dB on it) | |
    | Music | Music | the floor's or the boss's music | `Sfx.play_music` |
    | Interface | UI | menus, buttons, jingles (level up, stairs, a boss slain, game over, the knell, a curse's card) | `Sfx.play_ui` |
    | Combat | Combat | the fight: weapons, hits and what monsters are made of, cries, skills, spells, potions and bombs, shots, explosions, statuses, traps going off, deaths | `Sfx.play_at` |
    | Ambience | World + Ambience | the place: footsteps, distant sounds, doors and gates, chests opening, gold and pickups, crates breaking, crumbling floors, quicksand, fires, the forge, falls; the background loop and the heartbeat (Ambience) | `Sfx.play_world` |

    Combat and World send to the SFX bus, which holds the room's reverb (set per floor by the
    ambience), then to Master. A trap is a fight sound (it hurts you), a chest or a door is the
    place's. A unit check (`tests/suites/sound_tests.gd`) holds every scene's player and every bank
    sound to its bus.
  - **The mix** (`SoundMixDef`, `data/audio/sound_mix.tres`): busy fights used to clip (two dozen
    hot sounds at once, the Master peaking near +10 dB) and some sounds were shrill. Now: each bus
    sits a little under its slider (Combat -3 dB, Interface -2, World -1, Music -4: the fights lost about 10 dB of loudness when they stopped clipping, so the music comes down with them), a hard limiter on Master
    (ceiling -1 dB), a soft compressor on Combat, a high-shelf cut over 6.5 kHz on Combat (-6 dB)
    and Interface (-3 dB); random pitch goes up 6% at most (pitched up, sounds turn shrill);
    16 combat voices, 8 world, 6 interface; the same sound at most 3 at once and twice within
    40 ms, the repeat 5 dB quieter (a swing through a pack: a couple of hits, not ten); past 6
    combat voices each new one a bit quieter (down to -6 dB); when the pool is full a nearer sound
    replaces the farthest. Fight sounds fade with distance faster than the place's. `trims` lowers
    sounds that came in too loud or too bright (hits, the player's hurt, roars, slashes, spikes,
    arrows, gates, the forge, the knell...); what monsters are made of sits 7 to 10 dB under the
    cry (`ImpactMaterialDef.volume_db`), and the deepest reverbs are drier (wet 0.2, the limbo 0.3).
- **The Threshold** (a second life's trial, see builds.md; `ThresholdDef` > Place and Look,
  `data/threshold/`): on the killing blow the floor freezes, a **knell** tolls (a bell made for the
  game, `assets/audio/sfx/world/knell.ogg`) and the picture drains to cold grey-blue at once; the
  hero's body fades and sinks while a pale soul, a wisp in the spirit's ramp, is dragged down out
  of it (`Threshold.SinkingSoul`),
  then a night-blue veil falls. Under it the limbo: an oval of pale stone in thick mist (its own
  `DungeonTheme`, light ramp from night blue to pale blue, `LightingDef` ambient 10), ghost wisps,
  drifting fog and low mist, a strong cold grading with little saturation and a slow pulsing
  vignette (`limbo_ambience.tres`), whispers and spirit sighs in a long reverb, its own music (Dream).
  Spectres rise out of a hollow ring of pale flames (the spirit element): the act's monsters blended 60% toward pale blue
  (`ActorRig.pallor`, under the hit flash) and a little see-through. Won, the bell again and a
  pale veil, and the hero is back with the feather's golden burst; lost, the bell and a dark veil.
- **Hit stop**: a few frames of freeze on impacts (`HitStop.freeze(seconds)`).
- **Light**: in steps, tile by tile (see [Lights](#lights)): the hero's torch, room lanterns, braziers,
  campfires, glowing shots and explosions light up each floor's own darkness.
- **Shaders**: everything stays on the art's pixel grid. The rig shader flashes actors when hit,
  paints their statuses and an elite's rim, and takes monsters away in the element that killed
  them (computed in the sprite's own texels); light falls off in flat steps, tile by tile
  (`LightField`); a full-screen shader (`ScreenFx` in `game.tscn`) adds a dithered vignette,
  a bit of contrast and saturation, and splits the colors by whole pixels when the hero takes a big hit.
- **Ambience** (`AmbienceDef`, `data/dungeon/ambience/`, set on each floor theme): footsteps that sound
  like the floor (dull in the caves, echoing in the crypt, crunchy in the ruins) and footprints that
  fade, a looping background (wind, storm), random distant sounds around the hero (drops, whispers,
  chains, roars), the SFX bus reverb of the place, floating particles (dust, ghost wisps, embers) and
  drifting pixel fog. Played by `Ambience` (`src/world/ambience.tscn`): the loop on the Ambience bus,
  footsteps and distant sounds on the World bus (both under the Ambience slider).
  Big monsters and bosses shake the ground when they walk. Under 30% HP a heartbeat plays and the
  music gets muffled (a low-pass filter on the Music bus, lifted when the game is left). The screen fades to black on the stairs.

## Feel limits

Binding caps and invariants for any new attack, monster, skill or effect (sources: Celeste's
released code, Dead Cells and Sakurai on hitstop, Riot's VFX guide, Xbox and WCAG guidelines;
the summary is in the owner's research report linked from [the art bible](../art-bible.md)). The
project's own values already follow them: a hit freezes 0.035 s (a crit 0.07), the hero hurt
0.08, an elite's death 0.08 then a slow, a boss's death 0.25.

| What | Limit |
|---|---|
| Hitstop | 1 to 6 frames (≤ 0.1 s) for hits; longer only for a boss's death or phase change. One freeze per attack, not per target; in a crowd take the largest, never the sum |
| Freeze and slow | Never a freeze during a slow |
| Screen shake | Through `Events.screen_shake`/`GameCamera` only (the Screen shake option, 0 respected); trauma capped at 1; along the cause; whole art pixels; never rotation |
| Input | Read on the first frame; attack, dodge and skill presses buffered 0.1-0.15 s, the buffer keeps counting through hitstop, consumed when used; the dodge cancels an attack's recovery |
| Telegraph | Every attack that hurts has a wind-up on at least two channels (pose, colour or ground mark, sound), its ground mark equal to the real area, and a way out ([pillars.md](pillars.md)) |
| Flashes | At most 3 per second over a large area, and behind the Screen flashes option |
| Haptics | Rare, short and crisp, only for important events (hurt, crit, boss), behind the Vibrations option; nothing on ordinary hits in a crowd |
| Readability | Threats are the most salient layer; the hero's effects lower and more transparent; ground effects under bodies unless they are threats; damage numbers merge in a crowd |
| Pixels | Effects on the 2-unit grid, pre-drawn directions, element ramps ([vfx.md](../vfx.md)) |

Checklist for new combat content: telegraph; hit feedback (flash, knockback or a sign of super
armour, particles, sound); hitstop within the caps; death feedback that stays (body, decal,
debris); sound with pitch variation; haptics only if important; a busy-screen capture where
threats stay readable; Screen shake 0 and Screen flashes off respected; no stacking (no freeze in
a slow, trauma capped, hitstop never eats input).

## Music

The sound used to be the big gap: four tracks for every place, one boss theme for every warden.
Now each place has its own (all from Ninja Adventure, CC0, `assets/audio/music/CREDITS.txt`), and
the music says where the hero is: Kagari's sleep on the shrine, the throat's roots and water, the
Ossuary's graves, the Pyre Temple's rite, Solhar's dust, and a fight of its own for each act.

- **Where it lives** (data, never code): a floor's track in its biome's `DungeonTheme.music`; a
  warden's in its `BossDef.music`, else its act's `ActDef.boss_music` (each act fights to its
  own), else `SoundBank.boss_music`; the Deeps' in `AbyssDef.music`, the Threshold's in
  `ThresholdDef.music`; a true ending's in `EndingDef.music`; the bed under a warden's story in
  its `CinematicDef.music` (or the music lowered by `duck_db`); the screens' (the shrine, its
  bell, a run won, a run lost) in `SoundBank` > Music. `Soundtrack` reads them all
  (`Soundtrack.places()`: every place and its track, which the tests check: none silent, each
  act's wardens on their own, the final fight's two forms different, every file looped and used).
- **How it plays** (`Sfx.play_music`, numbers in `SoundMixDef` > Music): two players take turns,
  so a new track fades in (1.2 s) while the old one fades out (0.9 s): a crossfade, never a gap.
  The same track asked again goes on where it is: two floors of a biome, or a floor's music
  coming back after its warden's, never restart it. A warden slain: its music fades, the
  victory sting plays alone, the floor's music comes back 2.2 s later (`sting_gap`). A run lost:
  the floor falls silent, the game-over sting, then the end screen's music. Under a warden's
  full story a quiet bed (Story, 4 dB down); under the short one the floor's music 6 dB down;
  the fight's music starts as the scene ends.
- **The final fight**: Tôma fights to his own theme; when he falls the music dies (silence while
  the Maw rises out of the tar, only its roar), then the Maw's theme begins once it fights. When
  its mask crumbles the bottom's own music (Kagari's, the title's) comes back under the choice.
- **Levels**: every track was loudness-matched when added (a plain gain toward -19 LUFS, never
  past a -1.5 dB true peak: the pack's tracks ranged from -12 to -26 LUFS, a 14 dB jump between
  floors) and re-encoded as Vorbis quality 1 (about 60 kbps, 11 MB for the 26 tracks); the
  player sits at -8 dB (`music_volume_db`) on the Music bus (-4). Every track loops whole (the
  pack cuts them on the bar; `loop=true` in its `.import`).

Chosen without hearing them: the pack's names, then each track measured (loudness, brightness,
how busy and percussive, its key, its shape over time). To listen to and swap freely: change the
`.tres`, nothing else.

| Place | Track (`assets/audio/music/`) | Why |
|---|---|---|
| Title screen, the shrine | Lost Village (`lost_village`), then the bell (`knell`, -14 dB, 1.4 s in) | Kagari asleep: the pack's sparsest piece (no beat, long decays, B minor); the shrine's bell tolls once for the souls coming home |
| Act I, Weeping Grotto | The Cave (`cave`) | the throat's dark rock: bass-heavy B minor (kept) |
| Act I, Pale Garden | Dark Forest (`dark_forest`) | Kagari's roots hanging in the dark; the longest loop (2.5 min) for the act's most common floors |
| Act I, Drowned Caverns | Aquatic (`aquatic`) | the spring's water come down: sparse, watery A minor |
| Act I wardens (Bloated King, Mire Matron) | Fight (`boss`) | the old boss theme, the lightest fight of the pack, for the first wardens |
| Act II, Catacombs | Crypt (`crypt`) | Kagari's dead (kept) |
| Act II, Hushed Archive | Mystical (`mystical`) | a dark, slowly swelling piece (the darkest timbre after Curse): the first ruin of an older kingdom |
| Act II wardens (Gorr, Azure Wyrm) | Dark Castle (`dark_castle`) | steady gothic drive for the Ossuary's guardians |
| Mother of Tears | Lament (`lament`) | the mourners' own song: she fights to a lament |
| Nameless Charnel (hidden) | Melancholia (`melancholia`) | quiet plucked grief: a knight who gave his name |
| Nameless Effigy | Curse (`curse`) | opens on tolls every two seconds, then sinks into the darkest pad of the pack: the seal |
| Act III, Godless Temple | Temple (`temple`) | Solhar's temple, F# minor |
| Act III, Cinder Ruins | Dungeon (`dungeon`) | the burnt lower town: heavy, low D minor (kept) |
| Act III wardens (Tengu, Ember Ronin, Jade Wyrm) | End Theme (`end_theme`) | the densest, most regular pulse of the dark tracks: the pyres' rite |
| Act IV, Buried City | Ruins (`ruins`) | Solhar's ruins; it ebbs over its loop (-20 to -32 dB): a city dying out |
| Act IV, Sun Tomb | Manor (`manor`) | regal, very low and heavy: the dead king's halls |
| Act IV wardens (Gilded Hoarder) | Final Area (`final_area`) | hammering stabs in F minor: the last act |
| Dead Sun | Revelation (`revelation`) | the brightest and loudest piece, in G major: the false sun's hymn, and what the sun really is |
| The Deeps | Tension (`tension`) | a dense, unrelenting pulse: the Maw's gut |
| The Threshold | Dream (`dream`) | the dead waiting: a sparse, dreamlike D minor |
| Bottom of the Well (the floor) | Lost Village (`lost_village`) | the title's: Kagari, what Tôma lost, waiting under everything; it comes back when the mask crumbles |
| Master Tôma | End Theme 2 (`end_theme_2`) | steady, solemn and low, never shouting: a teacher's calm |
| The Maw | Fight (2025) (`fight_ii`) | the fastest, densest track of the pack, kept for the very last fight |
| The Nameless Keeper | Fight (2025) (`fight_ii`) | the Maw's: when he waits, his is the very last fight |
| Ending: ring the bell | Credit Theme (`credit_theme`) | the only up-tempo major piece kept: Kagari wakes |
| Ending: take his place | Lost Village (`lost_village`) | the music doesn't move: he stays, and loses the village |
| A run won (first ending) | Ascension (`ascension`) | gentle and rising: the souls going home |
| A run lost | Sad Theme (`sad_theme`) | quiet, after the game-over sting |
| A warden's full story | Story (Short) (`story`) | a storytelling bed, 4 dB down |
| The merchant, the forge, the keepers | the floor's | no change: they are rooms of the floor |

- **Ambience beds** (`AmbienceDef.bed`, on the Ambience bus under the music): the cave's, the
  crypt's and the ruins' as before, and four new loops from the pack's Ambient sounds, made
  seamless (the end crossfades into the start) and matched to the old ones: the Pale Garden a
  low warm wind (`breath`: the Maw's breath rising through the roots), the Drowned Caverns a
  river (`water`), the Buried City the desert wind (`wind`), the bottom of the Well a slow far
  surf filtered dark (`tar`: the pool heaving).
- **Feedback for the recent actions**: dropping from the bag (a thud at the hero's feet,
  `drop`), breaking gear down (an anvil's clank before the coins, `dismantle`), taking gear off
  (the equip sound), a fragment found for the first time (a short discovery jingle,
  `fragment_found`, instead of the panel's opening), the Maw's bite (a low bone crunch,
  `WeakPointTrait.bite_sound`), a pool of gas welling up (bubbling, `VfxElementDef.pool_sound`
  on poison). The speakers' voices were evened out (`SpeakerDef.voice_db`: Brann's and the
  Wanderer's were 9 to 12 dB quieter than the Vigil-Keeper's).

## Lights

Light comes in levels, from 0 (pitch dark) to 15 (full light), like in block games: a lantern of
level 13 lights its tile 13, the next tiles 12, then 11... (`LightField`, `src/world/lighting/`).
It spreads around corners but walls stop it; cliff faces catch it, and the mist on the plateau
above glows near the lamps, fading twice as fast (see Mist over the walls). Each level is one flat band of color, and the color changes as the light fades
(warm by the flame, dusky further out, cold in the dark).

- **Lights** are `LightSource` nodes (`color`, `level`): lanterns and furniture (`PropDef.light_level`),
  campfires and oases (`HeatSourceDef.light_level`), the hero's torch (level 12), glowing shots and
  flashes (`relative`: counted above the floor's own light, so they show even in daylight).
- **Each theme** has its `LightingDef` (`data/dungeon/lighting/`): `ambient_level` (the light away
  from any lamp: 5 in the crypt, 9 in the desert) and `ramp`, the color of each level. Difficulty,
  curses and events (darkness, the Blood Moon) lower the floor's light and tint it, less and less
  near the lamps.
- **How**: lights that stay put are spread once per floor on the CPU, half a tile per cell, all at
  once, brightest first. Moving ones (up to 24 near the hero) are added every frame by a shader
  (`light_cells.gdshader`, walls checked along the way) into a small viewport, one pixel per cell,
  stretched over the floor and multiplied with it: no light ever gets brighter than the art, so
  bright floors (the desert) never burn white. Sparks, slashes, floating text and the ambient
  particles are drawn above it (z 4 and up) and shine on their own; effects on the floor or
  standing on it are under it and a glowing one brings its own light (`VfxLayer.light_up`; a
  monster's warning a red one).

## Animations

Animations are **frame by frame**, like in Zelda-style RPGs: every character has a drawing for each
direction (down, up, left, right) and each pose, and the weapon is drawn *in the hand* for each
attack frame. Nothing is rotated or moved by code, so the weapon never floats or goes through the body.

Every actor (player and monsters) has a **rig**: `src/entities/rig/actor_rig.tscn`.

```
Rig                  at the actor's feet
└── Visual           body shader (flash.gdshader: flash, statuses, rim, deaths), scaled 2x (units = art pixels)
    └── Squash       squash & stretch on hits
        ├── Body       AnimatedSprite2D: the character (SpriteFrames from the data)
        ├── BodyArmor  AnimatedSprite2D: worn body armor, same animation and frame as Body
        ├── Helmet     AnimatedSprite2D: worn helmet, same animation and frame as Body
        ├── Weapon     AnimatedSprite2D: the weapon in hand, same animation and frame as Body
        ├── WeaponBack Sprite2D: the hero's weapon at rest (added in code, hero only)
        └── WeaponAura the motes of the elements his weapon carries, right after the weapon shown
```

The animations live in `SpriteFrames` resources in `data/visuals/`, named `<pose>_<direction>`:

| Animation | When |
|---|---|
| `idle_*`, `walk_*` | standing, moving |
| `attack_*` | attacking (sped up to fit the weapon's attack speed) |
| `dash_*` | rolling |
| `hit_*` | taking a hit |
| `dead` | dying |
| `cast`, `intro` | bosses: telegraphed skill, waking up |
| `windup` | a monster's own wind-up (Tôma drawing his katana), fitted to the telegraph; a skill may play it instead of `cast` (`SkillDef.cast_animation`) |
| `open` | a pose held (`ActorRig.hold_pose()`: the Maw's jaw held open, its `attack` played to open it and backwards to close it) |

A missing animation falls back to a simpler one (`attack_left` > `attack`), and creatures with no
attack pose lunge instead. Monsters freeze in their attack pose and shake during their wind-up
(or play their `windup`), so you can see the strike coming.

**Bosses of several forms** (the bottom of the Well: monsters.md): a form whose body stays
(`BossDef.body_stays`) plays its `dead` animation to the end in its own colors instead of
bursting and dissolving; when the next form rises, the screen darkens a moment (the Game's fade at
55%), the ground shakes, the new form comes up out of the floor fading in, and the fallen body is
drawn into it. A boss too big for the view (`BossDef.camera_lean`: the Maw, 256 pixels tall)
makes the camera lean toward its middle (`GameCamera.lean_toward()`, at most 170 pixels, easing
in and out) so it and the hero both stay on a phone's screen (a cinematic stops the lean and
frames its subject itself; the fight leans again after). Once risen, the new form is met like any
warden (its cinematic, below), then fights. What the forms say is their chronicle's, as for every
warden (Boss stories, below).

**Weapons**: each `WeaponDef` has `attack_frames` (a SpriteFrames with `attack_down/up/left/right`).
The sheets in `assets/weapons/attack/` are 64x64 cells, one column per direction, one row per frame,
drawn so the handle sits in the hero's hand on that frame. The weapon is drawn behind the body when
facing up. `attack_fx` is the slash effect played in front of the actor.

**The weapon at rest**: between attacks the hero carries his weapon (`WeaponDef.back_sprite`,
`back_kind`, `back_offset`; art in `assets/weapons/back/`, redrawn at the in-hand size by
`tools/vfx/back_weapons.py`). Blades, axes, hammers, the lance, bows and staffs are slung across
his back on the diagonal: behind him facing down, left and right (the hilt or the head peeks over
his shoulder), in front of him facing up (we see his back), mirrored as he turns; the Ember Tome,
shurikens and the whip hang at his hip. It bobs with the body's frames, hides while the weapon is
in his hand (the attack frames) and when he dies. Monsters carry nothing. The rules and the draw
order: docs/vfx.md section 10.

**Armor (paper doll)**: what you wear shows on the hero. Each `ArmorDef` has `wear_frames`, a layer
with the same animations as the hero, and a `wear_color`. The layers copy the body's animation and
frame every frame, so they can't drift. The layer sheets (`assets/characters/hero/wear/`) are grayscale
and were made from the hero's own frames (hood and outfit pixels), so one style serves many armors:

| Style (`data/visuals/wear/`) | Slot | Used by |
|---|---|---|
| hood | head | Leather Cap |
| helm | head | Iron Helm |
| tunic | body | Leather Armor, Shadow Cloak |
| mail | body | Chain Mail |
| plate | body | Plate Armor |

A new armor = pick a style and a color in the inspector. Found armor above Common shows its
rarity worn: a trim of the rarity's color on its hem (the tunic's hem, the helm's brim), and a
glint sweeping across an Epic piece (docs/vfx.md section 10).

To tweak an animation, open a file in `data/visuals/` and use the SpriteFrames panel
(add frames, change the speed, toggle loop). The actor scripts never touch animations directly:
they call `rig.play_attack()`, `rig.play_hurt()`, etc.

## Boss stories

Every warden has a story (`BossDef.chronicle`, `BossChronicleDef`), told a chapter at a time as if
it had lived: who it was, its life before the Well, how it fell, the keeper who bound it, what it
knows of the Maw. The canon is docs/lore.md (section 5b for each warden); the data and how to add
one are in [adding-content.md](../adding-content.md#the-story-chronicles-fragments-conditions-deeds-cinematics).

- **The meeting.** When the hero walks into an arena, the exits close and, before the warden
  wakes, a short cinematic plays over the frozen world (the game is paused: nothing moves, nothing
  hurts; `BossMeeting`, `CinematicDirector`): two black bars slide in and the HUD steps aside, the
  camera eases to the warden, it plays its waking animation if it has one (the Tengu), its name and
  title appear in the top bar (Fonts.TITLE, then BODY), then in the bottom bar the chapter's
  title (with "New"), its own words in quotes under it if it carries a memory of the hero (pale
  blue), then the chapter's lines (the title between the words and the lines read as its name
  cutting the dialogue in two), typed letter by letter in the bottom bar, which grows to hold them (Fonts.BODY, at most 1000 UI pixels wide); the
  camera comes back and the fight begins (the boss music, the bar; no banner: its name was said).
  Steps and timings are data (`data/story/cinematics/boss_full.tres`): about 8 to 15 seconds.
- **Never annoying.** The first meeting tells the first chapter. A meeting after a chapter opened
  tells that one (one per meeting, in order), marked **New** beside its title. Otherwise the short
  version (`boss_short.tres`): its name and one line it remembers (its words, or a line of a chapter
  already told, another each time), faded in, about two seconds, no camera move. A tap (a key, a
  gamepad button) writes everything out at once; the next one ends it, the camera back and the bars
  out in a moment (taps in its first third of a second are ignored: a thumb leaving the joystick).
  Never twice on the same floor of a run: a run picked up again mid-fight starts the fight at once
  (`RunState.met_floors`, saved; the bottom of the Well has its own key though it keeps the last
  act's depth, and a form risen from a fallen one its own: "12f", "12f/the_maw").
- **Bosses of several forms** (the bottom of the Well): the first form's meeting plays when the
  hero walks in, with its waking (Tôma draws his blade in the scene); a form rising from the fallen
  one (`BossDef.next_boss`) is met once its rise is over, the same cinematic (the Maw has no waking
  animation: the bars, the camera on it, its name, its words or a chapter), then it fights.
- **Last words** (`BossChronicleDef.last_words`, `WakingLine`s like its waking words): the last
  open one is said as the warden falls, in quotes on its banner (a sentence too wide at
  Fonts.HUGE, past the HUD's columns, comes at TITLE across the screen, on two lines if need
  be: `Hud.show_banner()`) and in the log, a moment after its
  fall (a deed done by that very fall counts: Tôma, slain by a hero who never rolled, "You stood.
  That much, at least, I taught you."). With Boss stories off, nothing (as its waking words).
- **Option**: Boss stories, Full / Short / Off (Settings, Story section): Off is the banner as
  before; the codex keeps every chapter whatever the option.
- **What opens a chapter** (`ChronicleChapter`): the warden's deaths (0, 1, 2, 4 and 6 in ours, its
  bestiary count), the story's progress (docs/lore.md section 7: the deepest floor reached, a run
  won, the Nameless Effigy slain), its **fragments** found, and a **deed**: something precise done
  as it fell, chosen to mean something for it (the Ember Ronin slain with a Katana, the Gilded
  Hoarder by a run that bought nothing, the Azure Wyrm finished by fire, the Mother of Tears
  without a single wound, the Jade Wyrm on Martyr, Tôma slain without a roll, the Maw by a run it
  never bit...: `DeedCondition`). The keeper is never named before the Effigy is slain and a run
  is won, or before the hero meets him at the bottom of the Well (`data/story/conditions/
  keeper_named.tres`, an `AnyCondition`); after, each warden names him as it wakes, and his
  journal's pages may be found.
- **Fragments** (`FragmentDef`): pages, bone tablets, sealed letters, the keeper's journal, lying on
  the floors of an act before its warden (the one drawn for this run; the hidden floor's on Act
  II's floors once it was met; Tôma's and the Maw's on the last act's once the bottom is open,
  Tôma's after the reveal, the Maw's once it was met): at most one a floor, a 35% chance, not during the first run, never
  one already found while that warden has others to find (`FragmentPlacer`, its own random numbers,
  on free ground). On the floor: its 16x16 picture drawn at 2x, bobbing a pixel, glowing in its
  element (spirit for Kagari's papers, frost for the bone tablets, fire for the singed pages, holy
  for Solhar's letters, water for the journal) so it reads on every floor: a rim of the element's
  light round the picture (on dark stone), a ring on the floor in its color outlined by its dark
  edge, breathing by a pixel (on light grass and sand), a glow halo, three motes rising, a small
  light. Interact (**Read**) opens it in a panel over the paused game (`FragmentPanel`: its
  title on the ribbon, who wrote it and where, its lines, "A new page for its chronicle: ..."); a
  tap anywhere closes it. Found for good (Profile), read again in the codex.

## The Vigil-Keeper and the keepers (dialogue)

Who speaks to the hero outside the fights: **the Vigil-Keeper** (*la Veilleuse*, the blind
priestess of the bell, docs/lore.md section 6) on the end screen and at the shrine, and the
keepers met on the floors (**the Old Wanderer**, **Brann**, **the Grinning Spirit**). One system
for all of them, the boss stories' own pieces reused (conditions, the Narrative service); no
speaker is special in the code. How to add a speaker, a line, an advice or a condition:
[adding-content.md](../adding-content.md#dialogue-speakers-lines-advice).

- **Data** (`data/story/dialogue/`): a `SpeakerDef` (name, title, face, body, the color of its
  name, its voice: a short sound as a line begins, how fast its words are typed: the Vigil-Keeper
  slowly, 32 letters a second) and `DialogueDef`s, each a pool of `DialogueLineDef`s: one to three
  pages of at most two sentences, gated by `ProgressCondition`s, a `priority` (the highest open
  line is said: something precise before something general, something new before a line said
  before), `once` or a `cooldown_runs`, and `remembered` (kept in the codex). Where a dialogue is
  said: `NarrativeDef` (Dialogue: `death_dialogues`, `victory_dialogues`, `shrine_dialogues`,
  `shrine_speaker`; `dialogues` lists them all), `ShopDef.dialogue`, `ForgeDef.dialogue`,
  `EncounterDef.dialogue`.
- **Picking** (`Dialogues`, `src/game/story/dialogues.gd`): the open lines that may be said again,
  the highest priority, then one never said, then the one said longest ago, then any. Said, a line
  is kept (`Narrative.tell_line()`: `Profile.lines_told`, the run it was said in, and
  `lines_order`, saved; older saves load with nothing said). Each opening of a dialogue is counted
  (`talk:<dialogue id>` in the Profile's stats), which a `StatCondition` reads: the keepers tell
  their past a meeting at a time.
- **What is known of a run** (`RunFacts`, `src/game/story/run_facts.gd`): read by the Game the
  moment the hero falls (`RunFacts.of_death()`), or as the run is won (`of_victory()`): what killed
  him (the monster, a boss, an elite, one fighting from afar), how (`Actor.death_cause`, from the
  hit's `HitInfo.cause`: a monster's blow, a boss's shockwave, a trap, a fall, a burn's or a
  poison's last tick, the cold or the heat of a cursed floor, quicksand, a blast, the blood altar,
  giving up), where (act, floor, its biome, the Deeps, the hidden floor, the bottom, the Threshold
  lost), his level, how long, the potions he still carried, his armor, the run's marks (a potion
  drunk, a roll, bought, cursed...). It is the `subject` of the run's conditions
  (`RunCondition` subclasses: `KillerCondition`, `CauseCondition`, `PlaceCondition`,
  `RunMarkCondition`, `LevelCondition`, `GearCondition`, `OutcomeCondition`,
  `DeathStreakCondition` (the last runs, from the history), `DeathCountCondition` (deaths to the
  same monster, `Profile.deaths_by`)), never met without it, and it fills the lines' codes
  (`{killer}`, `{floor}`, `{act}`, `{biome}`, `{place}`, `{level}`, `{time}`, `{kills}`, `{curse}`,
  `{weapon}`, `{boss}`; `{killer}` only where a name stands alone, at a sentence's start or after a
  colon: French bosses carry their article). Story conditions read the Profile and ignore it;
  `NotCondition` and `EndingCondition` were added for her.
- **The end screen**: after a death, the Vigil-Keeper **tells this death** in one or two lines
  (`vigil_tale`), then gives **one piece of advice** (`vigil_advice`, in gold), in a `DialogueBox`
  under the title that types them one after the other without waiting; a tap, Enter or A writes
  everything out, and the buttons answer at any time. The tale is the most precise one open (the
  Maw, Tôma once named, the Threshold lost, the Deeps, giving up, a warden's shockwave, the same
  warden again, a cause, an elite, a shot from afar, an early death, any monster, nothing known);
  her first-ever tale welcomes the hero back once. The advice is ranked: the warden's own moves
  (each true to its skills: monsters.md), its shockwave, the cause (traps warn, roll over holes,
  stay by the campfires...), early deaths again and again (offer souls to the Tree, or go down as
  a Pilgrim, on Keeper or Martyr, before any win), potions left, no roll, no armor, behind in
  levels, killed from afar, an elite, the same warden three times (its page in the codex), and the
  master's lessons when nothing more precise is open; most wait a run or two before being said
  again. A victory has her lines too (`vigil_victory`: the first one, the lamps put out by hand;
  each ending). With nothing for her to say, the story's death line, as before.
- **At the shrine** (the title screen): she stands right of the Well (`ShrineKeeper`: Ninja
  Adventure's old woman, CC0, recolored: silver hair, the shrine's white robe over a bell-rope red;
  her two idle frames at x4, her name under her), a speech bubble over her head while she has a
  line she never said. A tap, or the focus and Enter / A, opens her words over the screen
  (`DialogueScreen`: a `DialogueBox` low in the middle, a page at a time; a tap anywhere, Enter or
  A goes on, Back closes it, the last page closes it): one line an opening, her progression first
  (docs/lore.md section 7: the moonless night, the Ossuary and the girl's voice, the pages, the
  Pyre Temple's sun, the fresh wax, the lamps put out by hand after the first victory, the seal cut
  by a blade of the hero's school, her breaking once the keeper is named, the endings), then her
  everyday words. **The shrine's lamps**: seven lamps in niches over the Well
  (`TitleBackdrop`), put out on the moonless night; they burn again as souls are offered to the
  Tree of Souls (the share of its levels bought).
- **The keepers**: the merchant's and the smith's panels open on a line of theirs where their
  greeting was (in quotes, their own voice: the Wanderer's dry bargaining ending on a hint,
  Brann's curt metal, the Spirit's giggling rhymes and dice in place of the encounter's
  description, in its color); new lines come with meetings and progress, one a meeting, each once; with nothing new,
  their greetings as before.
- **Remembered**: the codex's **Voices** tab (*Paroles*) lists, by speaker (face, name, title),
  every line they said that is kept, and how many are still to hear; lines made of one run's facts
  (the tales) are not kept.
- **The reveal**: any line naming Tôma waits for `keeper_named` (tested in both languages, like
  the chronicles); before it, she speaks of "ton maître" / "your master" and refuses to believe.

## Pixel art

The art is 16x16 pixel art drawn at 2x in the world, with nearest filtering (Project Settings >
Rendering > Textures > Default Texture Filter). Effects and shaders stay on the art's pixel grid:
the rules (whole-pixel sizes, 16 directions at most, dithering instead of alpha, one ramp per
element) are in [docs/vfx.md](../vfx.md), the tools in `tools/vfx/`.
