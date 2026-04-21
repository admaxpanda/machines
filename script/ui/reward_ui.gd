extends CanvasLayer

## 奖励界面：卡牌三选一 / 能力卡占位

var _reward_manager: Node
var _overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _cards_container: HBoxContainer
var _ability_label: Label
var _skip_button: Button
var _is_card_mode: bool = true

const CARD_SIZE := Vector2(64, 64)
const OVERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.6)
const PANEL_COLOR := Color(0.1, 0.1, 0.15, 0.95)

func _ready() -> void:
	_build_ui()
	visible = false

func _build_ui() -> void:
	# 全屏遮罩
	_overlay = ColorRect.new()
	_overlay.color = OVERLAY_COLOR
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# 居中面板
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -200
	_panel.offset_top = -150
	_panel.offset_right = 200
	_panel.offset_bottom = 150
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_COLOR
	panel_style.border_color = Color(0.4, 0.4, 0.5)
	panel_style.border_width_bottom = 2
	panel_style.border_width_top = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(vbox)

	# 标题
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title_label)

	# 卡牌容器
	_cards_container = HBoxContainer.new()
	_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_container.add_theme_constant_override("separation", 20)
	vbox.add_child(_cards_container)

	# 能力卡占位文字
	_ability_label = Label.new()
	_ability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ability_label.add_theme_font_size_override("font_size", 14)
	_ability_label.text = "能力卡奖励"
	_ability_label.visible = false
	vbox.add_child(_ability_label)

	# 跳过按钮
	_skip_button = Button.new()
	_skip_button.text = "跳过"
	_skip_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_skip_button)
	_skip_button.pressed.connect(_on_skip_pressed)

func show_card_choices(cards: Array) -> void:
	_is_card_mode = true
	_title_label.text = "选择一张卡牌"
	_ability_label.visible = false
	_cards_container.visible = true

	for child in _cards_container.get_children():
		child.queue_free()

	for card in cards:
		var btn := Button.new()
		btn.custom_minimum_size = CARD_SIZE
		btn.tooltip_text = card.card_name
		var tex: Texture2D = load(card.cover) if card.cover != "" else null
		if tex:
			var icon := TextureRect.new()
			icon.texture = tex
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_SCALE
			icon.size = CARD_SIZE
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(icon)
		else:
			btn.text = card.card_name
		btn.pressed.connect(_on_card_clicked.bind(card))
		_cards_container.add_child(btn)

	visible = true

func show_ability_reward() -> void:
	_is_card_mode = false
	_title_label.text = "能力奖励"
	_cards_container.visible = false
	_ability_label.visible = true
	visible = true

func dismiss() -> void:
	visible = false

func _on_card_clicked(card) -> void:
	if _reward_manager:
		_reward_manager.on_card_selected(card)

func _on_skip_pressed() -> void:
	if not _reward_manager:
		return
	if _is_card_mode:
		_reward_manager.on_card_skipped()
	else:
		_reward_manager.on_ability_skipped()
