extends Control

@onready var guide_image: TextureRect = $Panel/VBox/GuideImage
@onready var sfx_label: Label = $Panel/VBox/sfxBoxContainer/SfxLabel
@onready var sfx_slider: HSlider = $Panel/VBox/sfxBoxContainer/SfxSlider
@onready var music_label: Label = $Panel/VBox/musicBoxContainer/MusicLabel
@onready var music_slider: HSlider = $Panel/VBox/musicBoxContainer/MusicSlider
@onready var back_button: Button = $Panel/VBox/BackButton

const PATH_GUIDE := "res://sprite/guide_%s.png"

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	music_slider.value_changed.connect(_on_music_changed)

func open(lang: String) -> void:
	sfx_slider.value = AudioSettings.sfx_volume
	music_slider.value = AudioSettings.music_volume
	if ResourceLoader.exists(PATH_GUIDE % lang):
		guide_image.texture = load(PATH_GUIDE % lang)
	else:
		guide_image.texture = null
	sfx_label.text = Locale.get_text("SETTINGS_SFX")
	music_label.text = Locale.get_text("SETTINGS_MUSIC")
	back_button.text = Locale.get_text("SETTINGS_BACK")
	visible = true

func _on_back() -> void:
	visible = false

func _on_sfx_changed(value: float) -> void:
	AudioSettings.sfx_volume = int(value)
	AudioSettings.apply()
	AudioSettings.save()

func _on_music_changed(value: float) -> void:
	AudioSettings.music_volume = int(value)
	AudioSettings.apply()
	AudioSettings.save()
