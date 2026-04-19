class_name CardLoader
extends RefCounted

## 卡牌加载器：从 JSON 读取卡牌数据并构建卡组

## 加载所有攻击卡数据，返回 { StringName: AttackCardData } 字典
static func load_attack_cards() -> Dictionary:
	var file := FileAccess.open("res://data/card/attack_cards.json", FileAccess.READ)
	if not file:
		return {}
	var text := _strip_comments(file.get_as_text())
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var cards: Dictionary = {}
	for card_dict in json.data.get("cards", []):
		var card := AttackCardData.from_dict(card_dict)
		if card.id != &"":
			cards[card.id] = card
	return cards

## 根据卡组 JSON 构建攻击卡组实例数组
static func build_attack_deck() -> Array:
	var card_db := load_attack_cards()
	if card_db.is_empty():
		return []
	var file := FileAccess.open("res://data/card/deck.json", FileAccess.READ)
	if not file:
		return []
	var text := _strip_comments(file.get_as_text())
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return []
	var deck: Array = []
	for entry in json.data.get("attack_deck", []):
		var card_id: StringName = StringName(entry.get("card_id", ""))
		if card_db.has(card_id):
			deck.append(card_db[card_id])
	return deck

static func _strip_comments(raw: String) -> String:
	var lines := raw.split("\n")
	var clean: PackedStringArray = []
	for line in lines:
		if not line.strip_edges().begins_with("#"):
			clean.append(line)
	return "\n".join(clean)
