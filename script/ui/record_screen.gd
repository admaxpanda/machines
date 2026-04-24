extends CanvasLayer

@onready var title_label: Label = $Panel/VBox/TitleRow/TitleLabel
@onready var stats_label: Label = $Panel/VBox/StatsLabel
@onready var btn_prev: Button = $Panel/VBox/TitleRow/BtnPrev
@onready var btn_next: Button = $Panel/VBox/TitleRow/BtnNext
@onready var btn_return: Button = $Panel/VBox/BtnReturn
@onready var no_record_label: Label = $Panel/VBox/NoRecordLabel
@onready var card_columns: HBoxContainer = $Panel/VBox/CardColumns
@onready var attack_title: Label = $Panel/VBox/CardColumns/AttackColumn/AttackTitle
@onready var attack_cards: VBoxContainer = $Panel/VBox/CardColumns/AttackColumn/AttackScroll/AttackCards
@onready var skill_title: Label = $Panel/VBox/CardColumns/SkillColumn/SkillTitle
@onready var skill_cards: VBoxContainer = $Panel/VBox/CardColumns/SkillColumn/SkillScroll/SkillCards
@onready var ability_title: Label = $Panel/VBox/CardColumns/AbilityColumn/AbilityTitle
@onready var ability_cards: VBoxContainer = $Panel/VBox/CardColumns/AbilityColumn/AbilityScroll/AbilityCards

var _history: Array = []
var _current_index: int = 0

func _ready() -> void:
	visible = false
	btn_prev.pressed.connect(_on_prev)
	btn_next.pressed.connect(_on_next)
	btn_return.pressed.connect(_on_return)

func open() -> void:
	btn_return.text = Locale.get_text("RECORD_RETURN")
	_history = SaveManager.get_history()
	if _history.is_empty():
		_show_empty()
	else:
		_current_index = _history.size() - 1
		_show_record(_current_index)
	visible = true

func _show_empty() -> void:
	title_label.text = ""
	title_label.remove_theme_color_override("font_color")
	stats_label.visible = false
	card_columns.visible = false
	no_record_label.text = Locale.get_text("RECORD_NO_RECORDS")
	no_record_label.visible = true
	btn_prev.visible = false
	btn_next.visible = false

func _show_record(index: int) -> void:
	no_record_label.visible = false
	stats_label.visible = true
	card_columns.visible = true
	btn_prev.visible = true
	btn_next.visible = true

	var record: Dictionary = _history[index]
	var result: String = record.get("result", "defeat")
	var timestamp: String = str(record.get("timestamp", "")).replace("T", " ")

	if result == "victory":
		title_label.text = Locale.get_text("RESULT_VICTORY") + " - " + timestamp
		title_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		stats_label.text = Locale.get_text("RESULT_VICTORY_MSG") % [_format_time(int(record.get("play_time_ms", 0))), int(record.get("kill_count", 0))]
	else:
		title_label.text = Locale.get_text("RESULT_DEFEAT") + " - " + timestamp
		title_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
		stats_label.text = Locale.get_text("RESULT_DEFEAT_MSG") % [_format_time(int(record.get("play_time_ms", 0))), int(record.get("kill_count", 0))]

	attack_title.text = Locale.get_text("RESULT_ATTACK_TITLE")
	skill_title.text = Locale.get_text("RESULT_SKILL_TITLE")
	ability_title.text = Locale.get_text("RESULT_ABILITY_TITLE")

	var attack_ids: Array = []
	for id in record.get("attack_cards", []):
		attack_ids.append(id)
	var skill_ids: Array = []
	for id in record.get("skill_cards", []):
		skill_ids.append(id)
	var ability_ids: Array = []
	for id in record.get("ability_cards", []):
		ability_ids.append(id)

	var attack_db := CardLoader.load_attack_cards()
	var skill_db := CardLoader.load_skill_cards()
	var attacks := SaveManager.rebuild_card_deck(attack_ids, attack_db)
	var skills := SaveManager.rebuild_card_deck(skill_ids, skill_db)
	var abilities := SaveManager.rebuild_abilities(ability_ids)

	_fill_cards(attacks, skills, abilities)

	btn_prev.disabled = (index <= 0)
	btn_next.disabled = (index >= _history.size() - 1)

func _fill_cards(attacks: Array, skills: Array, abilities: Array) -> void:
	for child in attack_cards.get_children():
		attack_cards.remove_child(child)
		child.queue_free()
	for child in skill_cards.get_children():
		skill_cards.remove_child(child)
		child.queue_free()
	for child in ability_cards.get_children():
		ability_cards.remove_child(child)
		child.queue_free()

	for card in attacks:
		attack_cards.add_child(_make_card_entry(card.cover, Locale.get_text(card.card_name)))
	for card in skills:
		skill_cards.add_child(_make_card_entry(card.cover, Locale.get_text(card.card_name)))
	for ability in abilities:
		var icon_path: String = ability.icon if "icon" in ability else ""
		ability_cards.add_child(_make_card_entry(icon_path, Locale.get_text(ability.ability_name)))

func _make_card_entry(icon_path: String, card_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var tex := TextureRect.new()
		tex.texture = load(icon_path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(24, 24)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tex)
	var label := Label.new()
	label.text = card_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row

func _format_time(ms: int) -> String:
	var total_sec := ms / 1000
	var minutes := total_sec / 60
	var seconds := total_sec % 60
	return "%d:%02d" % [minutes, seconds]

func _on_prev() -> void:
	if _current_index > 0:
		_current_index -= 1
		_show_record(_current_index)

func _on_next() -> void:
	if _current_index < _history.size() - 1:
		_current_index += 1
		_show_record(_current_index)

func _on_return() -> void:
	visible = false
