extends CanvasLayer

@onready var settings: Control = $Settings
@onready var overlay: ColorRect = $Overlay
@onready var panel: PanelContainer = $Panel
@onready var btn_resume: Button = $Panel/VBox/BtnResume
@onready var btn_settings: Button = $Panel/VBox/BtnSettings
@onready var btn_give_up: Button = $Panel/VBox/BtnGiveUp
@onready var btn_return: Button = $Panel/VBox/BtnReturn
@onready var give_up_dialog: Control = $GiveUpDialog
@onready var give_up_label: Label = $GiveUpDialog/Panel/VBox/MessageLabel
@onready var give_up_cancel: Button = $GiveUpDialog/Panel/VBox/ButtonBox/BtnCancel
@onready var give_up_confirm: Button = $GiveUpDialog/Panel/VBox/ButtonBox/BtnConfirm

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	btn_resume.pressed.connect(_on_resume)
	btn_settings.pressed.connect(_on_settings)
	btn_give_up.pressed.connect(_on_give_up)
	btn_return.pressed.connect(_on_return)
	give_up_cancel.pressed.connect(_on_give_up_cancel)
	give_up_confirm.pressed.connect(_on_give_up_confirm)

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	var result_screens := get_tree().get_nodes_in_group(&"result_screen")
	if result_screens.size() > 0 and result_screens[0]._game_ended:
		get_viewport().set_input_as_handled()
		return
	if visible:
		_on_resume()
	elif not get_tree().paused:
		_open()
	get_viewport().set_input_as_handled()

func _open() -> void:
	btn_resume.text = Locale.get_text("PAUSE_RESUME")
	btn_settings.text = Locale.get_text("PAUSE_SETTINGS")
	btn_give_up.text = Locale.get_text("PAUSE_GIVE_UP")
	btn_return.text = Locale.get_text("PAUSE_RETURN")
	GameMode.pause()
	get_tree().paused = true
	visible = true

func _on_resume() -> void:
	visible = false
	settings.visible = false
	give_up_dialog.visible = false
	get_tree().paused = false
	GameMode.resume()

func _on_settings() -> void:
	settings.open(Locale.current_lang)

func _on_give_up() -> void:
	give_up_label.text = Locale.get_text("GIVE_UP_MESSAGE")
	give_up_cancel.text = Locale.get_text("GIVE_UP_CANCEL")
	give_up_confirm.text = Locale.get_text("GIVE_UP_CONFIRM")
	give_up_dialog.visible = true

func _on_give_up_cancel() -> void:
	give_up_dialog.visible = false

func _on_give_up_confirm() -> void:
	give_up_dialog.visible = false
	visible = false
	SaveManager.delete_save()
	var bms := get_tree().get_nodes_in_group(&"battle_manager")
	if bms.size() > 0:
		bms[0].fail_battle()
	var player := get_tree().get_first_node_in_group(&"player")
	if player and "player_died" in player:
		player.player_died.emit()

func _on_return() -> void:
	_auto_save()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/menu.tscn")

func _auto_save() -> void:
	var level_index: int = 0
	var bms := get_tree().get_nodes_in_group(&"battle_manager")
	if bms.size() > 0 and "_current_level_index" in bms[0]:
		level_index = bms[0]._current_level_index

	var attack_cards: Array = []
	var engines := get_tree().get_nodes_in_group(&"card_engine")
	if engines.size() > 0:
		var ae = engines[0]
		attack_cards = ae.draw_pile + ae.hand + ae.discard_pile + ae.exhaust_pile
		attack_cards = attack_cards.filter(func(c): return not c.temporary)

	var skill_cards: Array = []
	var skill_engines := get_tree().get_nodes_in_group(&"skill_card_engine")
	if skill_engines.size() > 0:
		var se = skill_engines[0]
		skill_cards = se.draw_pile + se.hand + se.discard_pile + se.exhaust_pile
		skill_cards = skill_cards.filter(func(c): return not c.temporary)

	var ability_ids: Array = []
	var p := get_tree().get_first_node_in_group(&"player")
	if p and "abilities" in p:
		for a in p.abilities:
			ability_ids.append(a.id)

	SaveManager.save_game(level_index, attack_cards, skill_cards, ability_ids, GameMode.mode)
