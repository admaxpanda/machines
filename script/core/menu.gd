extends Control

@onready var background: TextureRect = $Background
@onready var title_image: TextureRect = $LeftPanel/Margin/VBox/TitleImage
@onready var btn_load: Button = $LeftPanel/Margin/VBox/BtnLoad
@onready var btn_standard: Button = $LeftPanel/Margin/VBox/BtnStandard
@onready var btn_custom: Button = $LeftPanel/Margin/VBox/BtnCustom
@onready var lang_button: TextureButton = $LangButton

var _current_lang: String = "zh"

const PATH_BG := "res://sprite/background.png"
const PATH_TITLE := "res://sprite/title_%s.png"
const PATH_BTN_LANG := "res://sprite/changelanguage.png"

func _ready() -> void:
	Locale.set_lang(_current_lang)
	_apply_visuals()
	btn_load.pressed.connect(_on_load_game)
	btn_standard.pressed.connect(_on_standard_deck)
	btn_custom.pressed.connect(_on_custom_deck)
	lang_button.pressed.connect(_on_toggle_lang)

func _on_load_game() -> void:
	pass

func _on_standard_deck() -> void:
	GameMode.mode = GameMode.Mode.STANDARD
	get_tree().change_scene_to_file("res://scene/main.tscn")

func _on_custom_deck() -> void:
	GameMode.mode = GameMode.Mode.DRAFT
	get_tree().change_scene_to_file("res://scene/main.tscn")

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
		lang_button.texture_normal = load(PATH_BTN_LANG)
