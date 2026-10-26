class_name CampaignSupplyDef
extends Resource
## A fixed refuge stock entry. Purchases have a durable personal claim; neither death nor
## resting rerolls/refills it. Item behaviour stays in ItemDef/PlayerPack.

@export var id: String
@export var item: ItemDef
@export var price := 0
