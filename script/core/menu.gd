extends Control

@onready var background: TextureRect = $Background
@onready var title_image: TextureRect = $LeftPanel/Margin/VBox/TitleImage
@onready var btn_load: Button = $LeftPanel/Margin/VBox/BtnLoad
@onready var btn_standard: Button = $LeftPanel/Margin/VBox/BtnStandard
@onready var btn_custom: Button = $LeftPanel/Margin/VBox/BtnCustom
@onready var lang_button: Button = $LangButton
@onready var settings_button: Button = $SettingsButton
@onready var record_button: Button = $RecordButton
@onready var record_screen: CanvasLayer = $RecordScreen
@onready var settings: Control = $Settings
@onready var save_dialog: Control = $SaveDialog
@onready var save_dialog_label: Label = $SaveDialog/Panel/VBox/MessageLabel
@onready var save_dialog_cancel: Button = $SaveDialog/Panel/VBox/ButtonBox/BtnCancel
@onready var save_dialog_confirm: Button = $SaveDialog/Panel/VBox/ButtonBox/BtnConfirm

var _current_lang: String = "zh"

const PATH_BG := "res://sprite/background.png"
const PATH_TITLE := "res://sprite/title_%s.png"
const PATH_BTN_LANG := "res://sprite/changelanguage.png"

var _pending_mode: int = -1

func _ready() -> void:
	Locale.set_lang(_current_lang)
	_apply_visuals()
	btn_load.pressed.connect(_on_load_game)
	btn_standard.pressed.connect(_on_standard_deck)
	btn_custom.pressed.connect(_on_custom_deck)
	lang_button.pressed.connect(_on_toggle_lang)
	settings_button.pressed.connect(_on_settings)
	record_button.pressed.connect(_on_record)
	save_dialog_cancel.pressed.connect(_on_save_dialog_cancel)
	save_dialog_confirm.pressed.connect(_on_save_dialog_confirm)
	_update_load_button()

func _update_load_button() -> void:
	btn_load.disabled = not SaveManager.has_save()
	record_button.disabled = SaveManager.get_history().is_empty()

func _on_load_game() -> void:
	var data: Dictionary = SaveManager.load_game()
	if data.is_empty():
		return

	GameMode.mode = int(data.get("game_mode", 0)) as GameMode.Mode
	GameMode.starting_level_index = int(data.get("level_index", 0))

	var attack_db := CardLoader.load_attack_cards()
	var skill_db := CardLoader.load_skill_cards()
	GameMode.loaded_attack_cards = SaveManager.rebuild_card_deck(
		data.get("attack_cards", []), attack_db)
	GameMode.loaded_skill_cards = SaveManager.rebuild_card_deck(
		data.get("skill_cards", []), skill_db)
	GameMode.loaded_abilities = SaveManager.rebuild_abilities(
		data.get("ability_cards", []))

	GameMode.kill_count = int(data.get("kill_count", 0))
	GameMode.elapsed_ms = int(data.get("elapsed_ms", 0))
	GameMode.start_time = Time.get_ticks_msec() - GameMode.elapsed_ms

	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://scene/main.tscn")

func _on_standard_deck() -> void:
	if SaveManager.has_save():
		_pending_mode = GameMode.Mode.STANDARD
		_show_save_dialog()
		return
	GameMode.mode = GameMode.Mode.STANDARD
	GameMode.clear_load_state()
	get_tree().change_scene_to_file("res://scene/main.tscn")

func _on_custom_deck() -> void:
	if SaveManager.has_save():
		_pending_mode = GameMode.Mode.DRAFT
		_show_save_dialog()
		return
	GameMode.mode = GameMode.Mode.DRAFT
	GameMode.clear_load_state()
	get_tree().change_scene_to_file("res://scene/main.tscn")

func _on_settings() -> void:
	settings.open(_current_lang)

func _on_record() -> void:
	record_screen.open()

func _on_toggle_lang() -> void:
	_current_lang = "en" if _current_lang == "zh" else "zh"
	Locale.set_lang(_current_lang)
	_apply_visuals()

func _apply_visuals() -> void:
	var lang := _current_lang
	if ResourceLoader.exists(PATH_BG):
		background.texture = load(PATH_BG)
	if ResourceLoader.exists(PATH_TITLE % lang):
		title_image.texture = load(PATH_TITLE % lang)
	btn_load.text = Locale.get_text("MENU_LOAD_GAME")
	btn_standard.text = Locale.get_text("MENU_STANDARD_DECK")
	btn_custom.text = Locale.get_text("MENU_DRAFT")
	if ResourceLoader.exists(PATH_BTN_LANG):
		lang_button.icon = load(PATH_BTN_LANG)

func _show_save_dialog() -> void:
	save_dialog_label.text = Locale.get_text("SAVE_CONFLICT_MESSAGE")
	save_dialog_cancel.text = Locale.get_text("SAVE_CONFLICT_CANCEL")
	save_dialog_confirm.text = Locale.get_text("SAVE_CONFLICT_CONFIRM")
	save_dialog.visible = true

func _on_save_dialog_cancel() -> void:
	save_dialog.visible = false
	_pending_mode = -1

func _on_save_dialog_confirm() -> void:
	var mode := _pending_mode
	save_dialog.visible = false
	_pending_mode = -1
	SaveManager.delete_save()
	GameMode.mode = mode as GameMode.Mode
	GameMode.clear_load_state()
	_update_load_button()
	get_tree().change_scene_to_file("res://scene/main.tscn")
