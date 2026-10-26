class_name VillageEvidence
extends Node2D
## Quest evidence in a real dungeon room. The lantern keeps it even when a descent ends.

var quest: VillageQuestDef
var spot := Interactable.new()


func _ready() -> void:
	spot.verb = "Recover" # i18n
	spot.icon = quest.evidence_icon
	spot.used.connect(_recover)
	add_child(spot)
	var sprite := Sprite2D.new()
	sprite.texture = quest.evidence_icon
	sprite.scale = Vector2(2, 2)
	sprite.position.y = -12
	add_child(sprite)
	var light := LightSource.new()
	light.color = Palette.GOLD
	light.level = 7
	add_child(light)


func _recover(_by: Player) -> void:
	if not spot.enabled:
		return
	spot.enabled = false
	if VillageProgress.discover(quest):
		Events.log_message(tr(quest.evidence_text), Palette.GOLD)
		queue_free()
	else:
		spot.enabled = VillageProgress.stage(quest) == VillageProgress.Step.ACCEPTED
		Events.log_message(tr("Could not save village progress. Try again."), Palette.DANGER)


func _draw() -> void:
	PixelDraw.ring(self, Vector2.ZERO, 16.0, Palette.GOLD, 1, 1.0, 0.5)
