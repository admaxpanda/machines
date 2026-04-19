extends CanvasLayer

## 手牌 UI：右侧竖向显示当前手牌封面和能量

@export var card_engine_path: NodePath

var _card_engine: Node
var _card_scene: PackedScene

func _ready() -> void:
	_card_scene = preload("res://scene/ui/card_slot.tscn")
	_card_engine = get_node(card_engine_path)
	if _card_engine:
		_card_engine.hand_changed.connect(_on_hand_changed)
		_card_engine.energy_changed.connect(_on_energy_changed)

func _on_hand_changed() -> void:
	var container: VBoxContainer = $HandContainer
	for child in container.get_children():
		child.queue_free()
	for card: AttackCardData in _card_engine.hand:
		var slot := _card_scene.instantiate()
		container.add_child(slot)
		slot.setup(card)

func _on_energy_changed(new_energy: int) -> void:
	$EnergyLabel.text = "Energy: %d" % new_energy
