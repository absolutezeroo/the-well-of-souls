class_name RegionItemDef
extends Resource
## A one-time authored pickup. Its local id stays stable when its art or resource path changes.

@export var id: String
@export var cell: Vector2i
@export var item: ItemDef
