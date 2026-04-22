extends CanvasLayer

## 手牌 UI：右侧竖向显示当前手牌封面 + 能量 + 回合进度条

@export var card_engine_path: NodePath

const BAR_W := 6.0
const BAR_H := 200.0

var _card_engine: Node
var _card_scene: PackedScene
var _turn_bar_fg: ColorRect

func _ready() -> void:
	_card_scene = preload("res://scene/ui/card_slot.tscn")
	_card_engine = get_node(card_engine_path)
	if _card_engine:
		_card_engine.hand_changed.connect(_on_hand_changed)
		_card_engine.energy_changed.connect(_on_energy_changed)
	_build_turn_bar()

func _process(_delta: float) -> void:
	if _card_engine and _card_engine.get("turn_progress") != null:
		var p: float = _card_engine.turn_progress
		if _turn_bar_fg:
			_turn_bar_fg.size.y = BAR_H * p

func _build_turn_bar() -> void:
	var bar_container := Control.new()
	bar_container.anchor_left = 1.0
	bar_container.anchor_right = 1.0
	bar_container.anchor_top = 0.5
	bar_container.anchor_bottom = 0.5
	bar_container.offset_left = -4.0
	bar_container.offset_right = BAR_W - 4.0
	bar_container.offset_top = -BAR_H / 2.0
	bar_container.offset_bottom = BAR_H / 2.0
	bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_container)

	var bg := ColorRect.new()
	bg.color = Color(0.25, 0.25, 0.25)
	bg.size = Vector2(BAR_W, BAR_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(bg)

	_turn_bar_fg = ColorRect.new()
	_turn_bar_fg.color = Color(0.9, 0.3, 0.3)
	_turn_bar_fg.size = Vector2(BAR_W, BAR_H)
	_turn_bar_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(_turn_bar_fg)

func _on_hand_changed() -> void:
	var container: VBoxContainer = $HandContainer
	for child in container.get_children():
		child.queue_free()
	for card: CardData in _card_engine.hand:
		var slot := _card_scene.instantiate()
		container.add_child(slot)
		slot.setup(card)

func _on_energy_changed(new_energy: int) -> void:
	$EnergyLabel.text = "Energy: %d" % new_energy
