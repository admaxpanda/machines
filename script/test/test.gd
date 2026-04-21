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

var _orb_ids: Array[StringName] = [&"lightning", &"frost", &"dark", &"glass", &"plasma"]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		var managers := get_tree().get_nodes_in_group(&"orb_manager")
		if managers.size() > 0:
			var random_id: StringName = _orb_ids[randi() % _orb_ids.size()]
			managers[0].channel_orb(random_id)
		return
	var card: AttackCardData = null
	if event.is_action_pressed("right_click"):
		var managers := get_tree().get_nodes_in_group(&"orb_manager")
		if managers.size() > 0:
			managers[0].max_slots += 1
			print("[Test] 球位 +1，当前 %d" % managers[0].max_slots)
		return
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
