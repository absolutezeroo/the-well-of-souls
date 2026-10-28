# 0013: Runs that differ by how they are played

**Status**: accepted, 2026-10-28 (decided by Claude on the owner's delegation).

**Context**: the players' first complaint about roguelikes whose runs feel alike is perks that
"just add stats" and weapons that "play exactly the same" (research "Ce qui manque au
roguelike"); the Well had stat-heavy perks, plain boss relics, no weapon goal and oaths that
were numbers only.

**Decision**:
- **Behaviour perks**: past the four staples, at least a third of the perks and relics make
  something happen in the world (a trail, a split shot, a leap, a burst, a ring of ice...), each a
  new `Passive`, in a family.
- **Relics that bend a rule**: one card of every warden's relics is a relic that changes a rule
  with a price (`PerkDef.twist`); never offered elsewhere (level ups, pacts, trials, gifts, the
  daily relic). A relic's own price never deals the last blow and is a tick (no free
  invulnerability).
- **Weapon evolutions**: a weapon whose sockets all hold runes of one family, worn while that
  family is awake, is tempered at a forge into its evolved form (the runes melt; rarity, affixes,
  item level kept); no new art (the weapon's own icon and sheets). The codex shows the ones made.
- **Starting kits are oaths opened by feats** (`ContentDB.kits`, `OathDef.unlocked_by`): a
  weapon, a twist and a price, sworn at the Well's Edge like the tree's oaths; one oath a run;
  the very first run is never sworn (decision 0010).

**Consequences**: agents add perks and relics with a behaviour where they can, keep twists to
wardens' choices, add an evolution per weapon as data (`WeaponDef.evolved_from`,
`evolution_family`, `carried`), and add kits as oaths with a feat. Checks: `unit.variety` (the
behaviour share, one twist per warden's choice and none elsewhere, the evolutions' data and rule,
the kits' data), `game.behaviour_perks`, `game.twist_relics`, `game.evolutions`, `game.kits`.
