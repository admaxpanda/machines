class_name CardLoader
extends RefCounted

## 卡牌加载器：从 JSON 读取卡牌数据并构建卡组

## 加载所有攻击卡数据，返回 { StringName: CardData } 字典
static func load_attack_cards() -> Dictionary:
	return _load_cards_from("res://data/card/attack_cards.json")

## 加载所有技能卡数据，返回 { StringName: CardData } 字典
static func load_skill_cards() -> Dictionary:
	return _load_cards_from("res://data/card/skill_cards.json")

## 加载所有状态卡数据
static func load_status_cards() -> Dictionary:
	return _load_cards_from("res://data/card/status_cards.json")

## 根据卡组 JSON 构建攻击卡组实例数组
static func build_attack_deck() -> Array:
	return _build_deck(load_attack_cards(), "attack_deck")

## 根据卡组 JSON 构建技能卡组实例数组
static func build_skill_deck() -> Array:
	return _build_deck(load_skill_cards(), "skill_deck")

static func _load_cards_from(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text := _strip_comments(file.get_as_text())
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var cards: Dictionary = {}
	for card_dict in json.data.get("cards", []):
		var card := CardData.from_dict(card_dict)
		if card.id != &"":
			cards[card.id] = card
	return cards

static func _build_deck(card_db: Dictionary, deck_key: String) -> Array:
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
	for entry in json.data.get(deck_key, []):
		var card_id: StringName = StringName(entry.get("card_id", ""))
		if card_db.has(card_id):
			deck.append(card_db[card_id])
	return deck

## 加载所有能力卡数据，返回 { StringName: AbilityCardData } 字典
static func load_ability_cards() -> Dictionary:
	var file := FileAccess.open("res://data/card/ability_cards.json", FileAccess.READ)
	if not file:
		return {}
	var text := _strip_comments(file.get_as_text())
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var abilities: Dictionary = {}
	for d in json.data.get("abilities", []):
		var a := AbilityCardData.from_dict(d)
		if a.id != &"":
			abilities[a.id] = a
	return abilities

static func _strip_comments(raw: String) -> String:
	var lines := raw.split("\n")
	var clean: PackedStringArray = []
	for line in lines:
		if not line.strip_edges().begins_with("#"):
			clean.append(line)
	return "\n".join(clean)
