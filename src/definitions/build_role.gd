class_name BuildRole
extends RefCounted
## What a perk, a relic or an affix is for (decision 0012, docs/design/builds.md "Roles"): like
## Slay the Spire's cards, every one has a purpose. A **staple** is a solid everyday pick, good in
## any build (plain numbers: Strength, Precision, Fortune, the War Banner, of the Bear...); a
## **build-around** changes how you play and asks for its family (burning, freezing, chains,
## echoes, life drain), so it always belongs to one. UNSET only until the resource is filled:
## a unit check refuses it (`unit.roles`).

enum Role { UNSET, STAPLE, BUILD_AROUND }
