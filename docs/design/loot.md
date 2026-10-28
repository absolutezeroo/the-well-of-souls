# Loot, the belt, the merchant and the forge

## Loot, gold and the merchant

- **Item level**: every weapon and armor is as strong as the floor it was found or bought on
  (`ItemLevelRules`, `data/items/item_levels.tres`), and it never grows after that. A floor-2
  katana is better than a floor-1 one; to get stronger you have to loot. Each level above 1 adds
  2 damage per second to a weapon (the same for a quick rapier and a slow hammer: the slow one
  gets more per hit), 1.5 Health to a body armor and 1 to a helm. Monsters and bosses grow at the
  same pace (+32% / +33% Health per floor, `dungeon_config.tres` > Difficulty), so a hero who
  keeps his first sword falls behind. Rarity and affixes come on top. The level shows on the slot
  ("Lv 7"), first on the item card, and first in the comparison with what you wear ("+3 item
  levels, +5 damage"). The merchant sells at the floor's level; a forge keeps the weapon's level.
- **Rarity**: found equipment can come out **Magic** (blue, 1 affix), **Rare** (yellow, 2) or
  **Epic** (purple, 3), with more damage and bonuses (`ItemRarity`). Affixes (`data/affixes/`,
  `ItemAffixDef`) add stats ("Sharp", "of the Bear"...) or set enemies on fire, poison or slow
  them ("Burning", "Venomous", "Frozen"). Some act like a perk while worn (`ItemAffixDef.passives`,
  joined to the hero's `PerkSet` by `set_gear()`; their `description` shows on the item):
  **Vampiric** (heal on kill), **Shocking** (every 4th hit chains lightning), **of Embers**
  (burning enemies explode), **Shattering** (+25% on slowed enemies), **of Echoes** (skills may be
  ready again at once), **of Thorns**. Every affix has a **role** (builds.md "Roles"): the plain
  numbers are staples; the themed ones are build-arounds and name their element's family
  (`ItemAffixDef.family`, as a rune does): Burning and of Embers Inferno, Frozen and Shattering
  Frost, Thundering (`shocking`) Storm, Vampiric Blood, of Echoes Arcane. A tag: an affix wakes no
  family.
- **Bad-luck protection** (decision 0012): after `pity_after` (20) pieces of equipment found in a
  row without a Rare or better, each further one weighs Rare and Epic `pity_growth` (x1) more
  (21st x2, 22nd x3...) until one comes, which ends the streak (`RunLuck.rare_drought`, saved with
  the run; `LootRoller.pity_scale()`). Counted: what monsters, chests, crates and encounters drop
  while the floor is played; not the merchant's stock nor the items a floor's seed lays. On the
  first floor the longest streak goes from about 230 finds to under 40; the share of Rare finds
  over a run barely moves deeper down (+8% of them around floor 5, +3% around floor 9). Odds told
  elsewhere (an encounter's) are the plain ones.
- **Rarity you can see** (`RarityLookDef`, `data/items/rarity_looks.tres`; docs/vfx.md section
  10): each rarity keeps the signs of the one below and adds one. On the floor, Common lies
  plain; Magic has a blue rim and a glint running over it; Rare a gold rim, a gold ring under it
  and a pulse running out, and a small light; Epic a purple rim, an aura on the floor, motes
  rising, a halo, a light and a short pillar of light seen across the room. In the bag, the shop,
  the forge and the loot board the slot's frame is the rarity's color and Epic icons have a
  sheen sweeping over them. Worn, the hero's armor takes a trim of its rarity's color on its hem
  (a tunic's hem, a helm's brim) and his weapon on its outline, Epic pieces a glint sweeping
  across; an armor's affix with an effect shows too (of Echoes glitters arcane on the trim, of
  Thorns turns the hem into steel points), on him and on his portrait in the bag. Fewer effects keeps the rims, glints, ring, aura and pillar, and drops the motes, the
  halo and the moving glints.
- **What a weapon carries shows** (`ItemLook`): a weapon with an element of its own, a rune or an
  affix that burns, chills, poisons, chains lightning or drinks blood licks with that element
  along its rim and throws its motes (embers rising, ice chips falling, venom sinking, sparks,
  drops of blood), in hand and on the hero's back; the hero's swing is drawn in it (a katana with
  an Ember Rune swings fire), and so are his shots: a bow's arrows fly in it, a staff's or wand's
  own shot carries a rune's element on its back (an Ember Spark Wand's sparks trail flames), and
  the weapon's skills shoot in its runes and affixes too (Volley's arrows ride an Ember Rune's
  flames, Ice Shards carry them), only the look: a hit lands in the element when the rune's own
  rule acts on it. A rune in a socket is a small gem of its element on the slot.
  `LootRoller` makes rolled copies; the plain .tres is the Common version. Chances grow with depth
  (`dungeon_config.tres` > Loot) and with the source: elites, chests and bosses drop better.
- **Gold** drops from monsters (always from elites and bosses), chests and sometimes crates, and
  flies to you. It lasts one run. Potions and other consumables you already carry plenty of
  (4 of the same, `consumable_carry_cap`) drop as gold instead: no bag full of potions.
- **The merchant** (`data/shop/merchant.tres`, `Merchant`, `ShopPanel`) waits in a quiet room on
  some floors: stand by him and tap Interact (**Trade**) to buy equipment (better than average), potions and sometimes a
  tome, or to sell what you carry. Every item has a `value`; the price grows with rarity and depth.
  **Reroll** buys a new stock (`ShopDef.reroll_cost`, +`reroll_cost_growth` each time at the same
  merchant). **Lock** keeps an entry through rerolls; if you don't buy it, it waits at the next
  merchant at the same price (`World.kept_stock`, kept in saved runs).

## Room in the bag

The bag (`Inventory`) is split into **compartments**, one per kind of thing, each with its own
places (`BagCategoryDef.capacity` in `data/items/bag_categories.tres`): **Weapons** 16,
**Armors** 16, **Runes** 16, **Tomes & scrolls** 16 (the tomes and the Scroll of Fire),
**Consumables** 16 and **Other** 8 (keys, and anything no other compartment claims). Which one an
item goes to is its class (a weapon is a `WeaponDef`, an armor an `ArmorDef`...) or, for a few,
its id. A compartment fills on its own: sixteen weapons never stop a rune from coming in. "Is
there room?" is always asked of the item's compartment (`Inventory.can_add()`, through
`PlayerPack.can_store()`), wherever an item enters the bag: walking over loot and auto loot, the
Take button of loot left on the ground, the merchant's Buy, a rune taken out at the forge (and
a weapon of a stack getting a rune: it needs a place of its own among the weapons), equipping
one of a stack or unequipping (the worn piece goes back to its compartment), moving a consumable
from the belt, a shrine upgrade's starting items. Rewards from chests, bosses, secret rooms, the
Threshold and the Deeps are loot on the ground: the same rule. Runes of a kind stack, so the
runes' sixteen places hold every kind there is with room to spare.

- **More places**: `PlayerDef.bag_bonus` adds places to every compartment
  (`Inventory.extra_places`); an upgrade can add to every compartment the same way, or to one by
  its id (`Inventory.extra_by_category`). None does today: the hero has the compartments' own
  places.
- **Saved runs**: the bag is saved as one list, as before, and each item goes back to its
  compartment; a save from the single 16-place bag fits (it held 16 places in all). A
  compartment holding more than its places after loading (one made smaller) keeps everything,
  says so in the bag, and takes nothing new until the player makes room.

Three things keep the compartments from getting in the way.

- **Stacks**: identical items share one place and one slot ("x3"), potions and runes as before,
  and now rolled gear too. Two drops are identical when their `ItemDef.stack_key()` is: the same
  .tres for plain items; for rolled equipment the same base item, rarity, item level, affixes (in
  order: they make the name) and set runes, which is exactly what a saved run keeps of it
  (`LootRoller.to_data`), so stacks come back after Continue. The tab's counter ("Weapons
  5 / 16") and "full" count places, not items: a full compartment still takes one more of a
  stack. Equipping,
  dropping, selling or dismantling takes one from the stack; equipping one of a stack checks
  there is a place for what was worn (it frees none). A weapon with a rune set leaves its stack.
- **Dismantle** (`DismantleRules`, `data/items/dismantle.tres`): any piece of gear in the bag
  breaks down into gold, anywhere: the item card's Dismantle, or X (keyboard X or Delete, a
  gamepad's X) on the item in the bag. Common and Magic pieces go at once; Rare and Epic ones
  (`confirm_rarity`) and any piece with a rune set ask a second press (the button says "Sure?",
  the card "Press [X] again to break it: +40 gold"). One press breaks one of a stack.
  Gold = value x rarity (`ItemRarity.VALUE`) x `gold_share` (0.15) x (1 + `gold_per_level` (0.2)
  per item level above 1), plus 0.15 of the value of the runes set in it (they break with it).
  That is 40% of what the merchant pays for it on its own floor (`sell_ratio` 0.25 of prices
  x1.5, +20% a floor), and less deeper: carrying gear to him stays worth it, and dismantling is
  never a way to make gold. Never what is worn, potions, runes, tomes or keys.
- **Dismantle the worse**: the bag's button breaks down, after a confirmation that shows them and
  the gold, every piece of the tab open (weapons or armors) **worse** than what is worn in its slot (`ItemCompare.is_worse`,
  `PlayerPack.worse_gear()`). Worse means: not a higher item level, not rarer, no rune set, no affix
  (or weapon status) doing something the worn one doesn't (Vampiric, Burning...); and then, if it
  is of a lower level or rarity, not better at its main job (damage per second for a weapon;
  Health, Armor or Damage for an armor), quicker or lighter does not save it; of the same level
  and rarity, not one stat in its favour. Nothing is worse than an empty slot.
- **Auto loot** (Options, `Settings.auto_loot`, `PlayerPack.wants()`): what walking over an item does.
  **All** takes everything (the old way). **Better only** (the default) takes gear only when it is
  not worse than what is worn (the same rule as above), and every potion, rune, tome and key.
  **By hand** takes no gear. Gold always flies to the hero, and the hidden floor's Bone Key is
  always taken. Gear left on the ground shows, while the hero stands on it, on a small board low
  on the screen (`LootPrompt`): its slot, name, how it compares, and **Take**. Better only is the
  default because on a phone stopping to tap every drop mid-fight is a chore, while taking
  everything is what filled the bag with worse gear; what it leaves is still one step away.
- **A full compartment**: an item that has no room stays on the ground; a toast names the
  compartment ("No room left for weapons: ... stays on the ground. Dismantle or drop something in
  the bag.", at most every 4 s; `BagCategoryDef.full_text`), the loot board says the same, its
  button opens the bag; the merchant's Buy reads "No room left for runes: sell something first",
  the forge's "No room left for runes".

## The belt

Potions, bombs and scrolls don't take room in the bag: they go on the **belt** (`Belt`),
3 slots of one kind each, stacking up to 9 (`data/items/belt_rules.tres`, `BeltRules.max_stack`).
Adding and restoring stacks use this same limit. Each slot has its own button on screen, so you choose
what to drink or throw. When the belt is full, the rest goes to the bag; the bag screen moves
consumables between the two ("To belt" / "To bag"). The merchant buys from the belt too.

## Runes and the forge

- **Runes** (`RuneDef`, `data/runes/`, content_db > Runes): stones carved with a glyph of one of
  the five families. Bosses always drop one (`boss_runes`), elites and up often
  (`ranked_rune_chance`, 30%), chests sometimes (`chest_rune_chance`, 20%), plain monsters rarely
  (`rune_chance`, 1%). They are not among the random items: no merchant sells them.
  - Inferno: **Ember** (hits may set enemies on fire), **Pyre** (enemies dying burning explode).
  - Frost: **Rime** (hits chill), **Shatter** (critical hits release a frost shockwave that slows).
  - Blood: **Leech** (your hits heal 10% of their damage), **Fury** (wounded you hit harder, kills heal).
  - Storm: **Spark** (every 3rd hit chains lightning), **Gale** (your roll throws a gust).
  - Arcane: **Echo** (skills may be ready again at once), **Prism** (one more projectile; with Hydra's Quiver, 2 more at most, the volley sharing its damage).
- **Sockets**: every weapon has 1 to 3, by rarity (`ItemRarity.SOCKETS`: Common and Magic 1,
  Rare 2, Epic 3). A rune works like a perk while its weapon is worn (`RuneDef.passives`, through
  `PerkSet.set_gear`); two identical runes count twice. Set runes show on the weapon's details,
  with its empty sockets, and are saved with it.
- **The forge** (`data/forge/smith.tres`, `ForgeDef`, `Forge`, `ForgePanel`): Brann the Smith,
  his anvil and glowing coals, in a quiet room of some floors (`forge_chance` 30%, +15% for each
  floor without one, never on boss floors). Stand by him and tap Interact (**Forge**): pick a weapon (the worn one or one
  in the bag), set runes from the bag into its free sockets for free, or pick a socket and take
  its rune back out, intact, for gold (`removal_price` + `removal_price_per_depth`). A plain
  weapon becomes its own copy the first time a rune goes in. Debug panel: "Forge here", "Every rune".


## Exactly-once ground transfers

ItemPickup refuses reentrant take() calls while PlayerPack is transferring the item. GoldPickup
marks a pile collected before add_gold() emits, so a listener cannot take the same pile again
before queue_free(). Failed item storage still leaves the pickup available. Deferred item/coin
insertion carries its floor generation and discards old-floor nodes after a transition. These
are roguelike correctness guards, independent of the archived campaign experiment.
