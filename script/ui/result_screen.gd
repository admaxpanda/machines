extends CanvasLayer

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var stats_label: Label = $Panel/VBox/StatsLabel
@onready var btn_return: Button = $Panel/VBox/BtnReturn
@onready var attack_title: Label = $Panel/VBox/CardColumns/AttackColumn/AttackTitle
@onready var attack_cards: VBoxContainer = $Panel/VBox/CardColumns/AttackColumn/AttackScroll/AttackCards
@onready var skill_title: Label = $Panel/VBox/CardColumns/SkillColumn/SkillTitle
@onready var skill_cards: VBoxContainer = $Panel/VBox/CardColumns/SkillColumn/SkillScroll/SkillCards
@onready var ability_title: Label = $Panel/VBox/CardColumns/AbilityColumn/AbilityTitle
@onready var ability_cards: VBoxContainer = $Panel/VBox/CardColumns/AbilityColumn/AbilityScroll/AbilityCards

var _game_ended: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"result_screen")
	visible = false
	btn_return.pressed.connect(_on_return)

func show_victory(kill_count: int, play_time_ms: int, attacks: Array, skills: Array, abilities: Array) -> void:
	title_label.text = Locale.get_text("RESULT_VICTORY")
	title_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	stats_label.text = Locale.get_text("RESULT_VICTORY_MSG") % [_format_time(play_time_ms), kill_count]
	_fill_cards(attacks, skills, abilities)
	btn_return.text = Locale.get_text("RESULT_RETURN_MENU")
	_game_ended = true
	get_tree().paused = true
	visible = true

func show_defeat(kill_count: int, play_time_ms: int, attacks: Array, skills: Array, abilities: Array) -> void:
	title_label.text = Locale.get_text("RESULT_DEFEAT")
	title_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	stats_label.text = Locale.get_text("RESULT_DEFEAT_MSG") % [_format_time(play_time_ms), kill_count]
	_fill_cards(attacks, skills, abilities)
	btn_return.text = Locale.get_text("RESULT_RETURN_MENU")
	_game_ended = true
	get_tree().paused = true
	visible = true

func _fill_cards(attacks: Array, skills: Array, abilities: Array) -> void:
	attack_title.text = Locale.get_text("RESULT_ATTACK_TITLE")
	skill_title.text = Locale.get_text("RESULT_SKILL_TITLE")
	ability_title.text = Locale.get_text("RESULT_ABILITY_TITLE")

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

func _on_return() -> void:
	SaveManager.delete_save()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/menu.tscn")
