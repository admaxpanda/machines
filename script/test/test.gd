extends Node2D

## 测试脚本：左键发射寒流，右键发射打击

var _strike: AttackCardData
var _cold_snap: AttackCardData

func _ready() -> void:
	var cards := _load_attack_cards()
	for card in cards:
		if card.id == &"strike":
			_strike = card
		elif card.id == &"cold_snap":
			_cold_snap = card

func _input(event: InputEvent) -> void:
	var card: AttackCardData = null
	if event.is_action_pressed("left_click"):
		card = _cold_snap
	elif event.is_action_pressed("right_click"):
		card = _strike
	if not card:
		return
	var player: Node2D = get_tree().get_first_node_in_group(&"player")
	if not player:
		return
	var context := {
		"source": player,
		"card_engine": null,
		"target_position": get_global_mouse_position(),
	}
	CardResolver.play(card, context)

func _load_attack_cards() -> Array:
	var file := FileAccess.open("res://data/card/attack_cards.json", FileAccess.READ)
	if not file:
		return []
	var text := _strip_comments(file.get_as_text())
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return []
	var cards: Array = []
	for card_dict in json.data.get("cards", []):
		cards.append(AttackCardData.from_dict(card_dict))
	return cards

func _strip_comments(raw: String) -> String:
	var lines := raw.split("\n")
	var clean: PackedStringArray = []
	for line in lines:
		if not line.strip_edges().begins_with("#"):
			clean.append(line)
	return "\n".join(clean)
