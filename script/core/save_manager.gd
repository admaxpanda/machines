extends Node

const _SAVE_PATH := "user://save_game.json"
const _HISTORY_PATH := "user://game_history.json"

static func has_save() -> bool:
	return FileAccess.file_exists(_SAVE_PATH)

func save_game(level_index: int, attack_cards: Array, skill_cards: Array, ability_ids: Array, game_mode: int) -> void:
	var attack_ids: Array = []
	for card in attack_cards:
		if card and card.id != &"":
			attack_ids.append(String(card.id))
	var skill_ids: Array = []
	for card in skill_cards:
		if card and card.id != &"":
			skill_ids.append(String(card.id))
	var ability_str_ids: Array = []
	for id in ability_ids:
		ability_str_ids.append(String(id))

	var data := {
		"level_index": level_index,
		"game_mode": game_mode,
		"attack_cards": attack_ids,
		"skill_cards": skill_ids,
		"ability_cards": ability_str_ids,
		"kill_count": GameMode.kill_count,
		"elapsed_ms": GameMode.get_play_time_ms(),
	}
	var file := FileAccess.open(_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> Dictionary:
	if not FileAccess.file_exists(_SAVE_PATH):
		return {}
	var file := FileAccess.open(_SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()
	return json.data as Dictionary

func delete_save() -> void:
	if FileAccess.file_exists(_SAVE_PATH):
		DirAccess.remove_absolute(_SAVE_PATH)

func save_game_record(result: String, level_index: int, kill_count: int, play_time_ms: int, attack_cards: Array, skill_cards: Array, ability_ids: Array, game_mode: int) -> void:
	var attack_ids: Array = []
	for card in attack_cards:
		if card and card.id != &"":
			attack_ids.append(String(card.id))
	var skill_ids: Array = []
	for card in skill_cards:
		if card and card.id != &"":
			skill_ids.append(String(card.id))
	var ability_str_ids: Array = []
	for id in ability_ids:
		ability_str_ids.append(String(id))

	var record := {
		"result": result,
		"game_mode": game_mode,
		"level_index": level_index,
		"kill_count": kill_count,
		"play_time_ms": play_time_ms,
		"attack_cards": attack_ids,
		"skill_cards": skill_ids,
		"ability_cards": ability_str_ids,
		"timestamp": Time.get_datetime_string_from_system(),
	}

	var history: Array = _load_history()
	history.append(record)
	var file := FileAccess.open(_HISTORY_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(history))
		file.close()

func _load_history() -> Array:
	if not FileAccess.file_exists(_HISTORY_PATH):
		return []
	var file := FileAccess.open(_HISTORY_PATH, FileAccess.READ)
	if not file:
		return []
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return []
	file.close()
	if json.data is Array:
		return json.data
	return []

static func get_history() -> Array:
	if not FileAccess.file_exists(_HISTORY_PATH):
		return []
	var file := FileAccess.open(_HISTORY_PATH, FileAccess.READ)
	if not file:
		return []
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return []
	file.close()
	if json.data is Array:
		return json.data
	return []

static func rebuild_card_deck(card_ids: Array, card_db: Dictionary) -> Array:
	var deck: Array = []
	for id_str in card_ids:
		var id: StringName = StringName(id_str)
		if card_db.has(id):
			deck.append(card_db[id])
	return deck

static func rebuild_abilities(ability_ids: Array) -> Array:
	var ability_db := CardLoader.load_ability_cards()
	var abilities: Array = []
	for id_str in ability_ids:
		var id: StringName = StringName(id_str)
		if ability_db.has(id):
			abilities.append(ability_db[id])
	return abilities
