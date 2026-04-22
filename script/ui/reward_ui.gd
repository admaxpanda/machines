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

const OVERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.6)
const PANEL_COLOR := Color(0.1, 0.1, 0.15, 0.95)
const REWARD_IMG_SIZE := Vector2(240.0, 180.0)

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
	_panel.offset_left = -420
	_panel.offset_top = -200
	_panel.offset_right = 420
	_panel.offset_bottom = 200
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
		_cards_container.remove_child(child)
		child.queue_free()

	for card in cards:
		_cards_container.add_child(_make_reward_slot(
			load(card.cover) if card.cover != "" else null,
			Locale.get_text(card.card_name),
			Locale.get_text(card.description),
			_on_card_clicked.bind(card)
		))

	visible = true

func show_ability_choices(choices: Array) -> void:
	_is_card_mode = false
	_title_label.text = "选择一个能力"
	_ability_label.visible = false
	_cards_container.visible = true

	for child in _cards_container.get_children():
		_cards_container.remove_child(child)
		child.queue_free()

	for ability in choices:
		_cards_container.add_child(_make_reward_slot(
			load(ability.icon) if ability.icon != "" else null,
			Locale.get_text(ability.ability_name),
			Locale.get_text(ability.description),
			_on_ability_clicked.bind(ability)
		))

	visible = true

## 统一的奖励卡槽：上方全尺寸图片 + 下方名称/描述，整体居中
func _make_reward_slot(tex: Texture2D, title: String, desc: String, callback: Callable) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(REWARD_IMG_SIZE.x + 20.0, REWARD_IMG_SIZE.y + 80.0)

	# 底层 Button：只负责 hover 高亮 + 点击
	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(callback)
	slot.add_child(btn)

	# 上层 CenterContainer：图片+文本，点击穿透到底层 Button
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	if tex:
		var img := TextureRect.new()
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = REWARD_IMG_SIZE
		img.size = REWARD_IMG_SIZE
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(img)

	var name_label := Label.new()
	name_label.text = title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	if desc != "":
		var desc_label := Label.new()
		desc_label.text = desc
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.add_theme_font_size_override("font_size", 9)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size.x = REWARD_IMG_SIZE.x
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(desc_label)

	return slot

func dismiss() -> void:
	visible = false

func _on_card_clicked(card) -> void:
	if _reward_manager:
		_reward_manager.on_card_selected(card)

func _on_ability_clicked(ability) -> void:
	if _reward_manager:
		_reward_manager.on_ability_selected(ability)

func _on_skip_pressed() -> void:
	if not _reward_manager:
		return
	if _is_card_mode:
		_reward_manager.on_card_skipped()
	else:
		_reward_manager.on_ability_skipped()
