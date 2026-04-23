extends CanvasLayer

## HUD：左上角关卡信息 + 血条 + 经验条 + 底部技能栏

@export var player_path: NodePath
@export var battle_manager_path: NodePath

const BAR_WIDTH := 120.0
const HP_BAR_H := 8.0
const XP_BAR_H := 6.0
const MARGIN := 10.0
const BG_COLOR := Color(0.25, 0.25, 0.25)
const HP_COLOR := Color(0.85, 0.15, 0.15)
const XP_COLOR := Color(0.2, 0.85, 0.3)

const CARD_W := 120.0
const CARD_H := 90.0
const CARD_GAP := 4.0
const COST_FONT_SIZE := 10
const KEY_FONT_SIZE := 8

var _player: CharacterBody2D
var _battle_manager: Node
var _hp_fg: ColorRect
var _xp_fg: ColorRect
var _hp_label: Label
var _level_label: Label
var _phase_label: Label
var _skill_energy_label: Label
var _skill_progress_fg: ColorRect

var _buff_panel: VBoxContainer
var _skill_card_engine: Node
var _skill_slots: Array = []      ## Array[Control]
var _skill_bar: HBoxContainer

func set_skill_engine(value: Node) -> void:
	_skill_card_engine = value
	if _skill_card_engine:
		_skill_card_engine.hand_changed.connect(_on_skill_hand_changed)
		_skill_card_engine.energy_changed.connect(_on_skill_energy_changed)
		if _skill_card_engine.has_signal("turn_progress_changed"):
			_skill_card_engine.turn_progress_changed.connect(_on_skill_turn_progress)
		_refresh_skill_bar()

func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	if _player:
		_player.health_changed.connect(_on_health_changed)
		_player.xp_changed.connect(_on_xp_changed)
		_player.leveled_up.connect(_on_level_up)
		if _player.buff_container:
			_player.buff_container.buffs_changed.connect(_refresh_buffs)
	_battle_manager = get_node_or_null(battle_manager_path)
	if _battle_manager:
		_battle_manager.state_changed.connect(_on_state_changed)
		_battle_manager.level_started.connect(_on_level_started)
	_build_ui()
	_refresh_all()

func _process(_delta: float) -> void:
	if not _skill_card_engine:
		return
	for i in 5:
		if Input.is_action_just_pressed("skill_%d" % (i + 1)):
			_skill_card_engine.play_at(i)

func _build_ui() -> void:
	_build_top_left()
	_build_buff_panel()
	_build_skill_bar()

func _build_top_left() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.offset_left = MARGIN
	root.offset_top = MARGIN
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	root.add_child(vbox)

	_phase_label = _make_label()
	_phase_label.text = "场景- 关卡- —"
	vbox.add_child(_phase_label)

	_hp_label = _make_label()
	vbox.add_child(_hp_label)

	var hp_bar := _make_bar_holder(HP_BAR_H)
	vbox.add_child(hp_bar)

	var hp_bg := _make_bg(HP_BAR_H)
	hp_bar.add_child(hp_bg)
	_hp_fg = _make_fg(HP_COLOR, HP_BAR_H)
	hp_bar.add_child(_hp_fg)

	_level_label = _make_label()
	vbox.add_child(_level_label)

	var xp_bar := _make_bar_holder(XP_BAR_H)
	vbox.add_child(xp_bar)

	var xp_bg := _make_bg(XP_BAR_H)
	xp_bar.add_child(xp_bg)
	_xp_fg = _make_fg(XP_COLOR, XP_BAR_H)
	xp_bar.add_child(_xp_fg)

func _build_buff_panel() -> void:
	_buff_panel = VBoxContainer.new()
	_buff_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_buff_panel.offset_left = 10.0
	_buff_panel.offset_top = 110.0
	_buff_panel.add_theme_constant_override("separation", 2)
	_buff_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_buff_panel)

func _refresh_buffs() -> void:
	if not _buff_panel or not _player or not _player.buff_container:
		return
	for child in _buff_panel.get_children():
		child.queue_free()
	var buffs: Array = _player.buff_container._buffs
	# 合并同 id 的 buff，求和 stacks
	var merged: Dictionary = {}
	for b in buffs:
		var id: StringName = b.data.id
		if not merged.has(id):
			merged[id] = { "name": b.data.buff_name, "stacks": 0 }
		merged[id]["stacks"] += b.stacks
	for id in merged:
		var info = merged[id]
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 1)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = "%s %d" % [info["name"], info["stacks"]]
		_buff_panel.add_child(label)

func _build_skill_bar() -> void:
	_skill_bar = HBoxContainer.new()
	_skill_bar.anchor_left = 0.5
	_skill_bar.anchor_right = 0.5
	_skill_bar.anchor_top = 1.0
	_skill_bar.anchor_bottom = 1.0
	var bw := 5.0 * CARD_W + 4.0 * CARD_GAP
	_skill_bar.offset_left = -bw / 2.0
	_skill_bar.offset_right = bw / 2.0
	_skill_bar.offset_top = -CARD_H
	_skill_bar.offset_bottom = 0.0
	_skill_bar.add_theme_constant_override("separation", int(CARD_GAP))
	_skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skill_bar)

	_skill_energy_label = Label.new()
	_skill_energy_label.add_theme_font_size_override("font_size", 12)
	_skill_energy_label.text = "E:0"
	_skill_energy_label.visible = false
	_skill_energy_label.anchor_left = 0.5
	_skill_energy_label.anchor_right = 0.5
	_skill_energy_label.anchor_top = 1.0
	_skill_energy_label.anchor_bottom = 1.0
	_skill_energy_label.offset_left = -bw / 2.0
	_skill_energy_label.offset_right = bw / 2.0
	_skill_energy_label.offset_top = -CARD_H - 26
	_skill_energy_label.offset_bottom = -CARD_H - 8
	add_child(_skill_energy_label)

	# 技能卡回合进度条
	var prog_h := 4.0
	var prog_container := Control.new()
	prog_container.anchor_left = 0.5
	prog_container.anchor_right = 0.5
	prog_container.anchor_top = 1.0
	prog_container.anchor_bottom = 1.0
	prog_container.offset_left = -bw / 2.0
	prog_container.offset_right = bw / 2.0
	prog_container.offset_top = -CARD_H - prog_h
	prog_container.offset_bottom = -CARD_H
	prog_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prog_container)

	var prog_bg := ColorRect.new()
	prog_bg.color = BG_COLOR
	prog_bg.size = Vector2(bw, prog_h)
	prog_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prog_container.add_child(prog_bg)

	_skill_progress_fg = ColorRect.new()
	_skill_progress_fg.color = Color(0.3, 0.6, 0.9)
	_skill_progress_fg.size = Vector2(0.0, prog_h)
	_skill_progress_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prog_container.add_child(_skill_progress_fg)

	for i in 5:
		var slot := _make_skill_slot(i)
		_skill_slots.append(slot)
		_skill_bar.add_child(slot)

func _make_skill_slot(index: int) -> TextureRect:
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(CARD_W, CARD_H)
	tex.size = Vector2(CARD_W, CARD_H)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.name = "Slot%d" % index

	# 费用（左上角）
	var cost_label := Label.new()
	cost_label.add_theme_font_size_override("font_size", COST_FONT_SIZE)
	cost_label.position = Vector2(4, 2)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.name = "Cost"
	tex.add_child(cost_label)

	# 按键编号（底部居中）
	var key_label := Label.new()
	key_label.add_theme_font_size_override("font_size", KEY_FONT_SIZE)
	key_label.text = str(index + 1)
	key_label.position = Vector2(CARD_W / 2 - 4, CARD_H - 14)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.add_child(key_label)

	return tex

## 更新技能栏显示
func _refresh_skill_bar() -> void:
	if not _skill_card_engine:
		return
	var energy: int = _skill_card_engine.energy
	_skill_energy_label.text = "E:%d" % energy
	_skill_energy_label.visible = true


	for i in 5:
		var slot: TextureRect = _skill_slots[i]
		var cost: Label = slot.get_node("Cost")
		if i < _skill_card_engine.hand.size():
			var card: CardData = _skill_card_engine.hand[i]
			if card.cover != "":
				slot.texture = load(card.cover)
			cost.text = str(card.cost)
		else:
			slot.texture = null
			cost.text = ""

func _on_skill_hand_changed() -> void:
	_refresh_skill_bar()

func _on_skill_energy_changed(new_energy: int) -> void:
	_skill_energy_label.text = "E:%d" % new_energy

func _on_skill_turn_progress(current: int, total: int) -> void:
	if _skill_progress_fg:
		var bw := 5.0 * CARD_W + 4.0 * CARD_GAP
		_skill_progress_fg.size.x = bw * clampf(float(current) / float(total), 0.0, 1.0)

func _make_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 12)
	return l

func _make_bar_holder(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(BAR_WIDTH, h)
	c.size = Vector2(BAR_WIDTH, h)
	return c

func _make_bg(h: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = BG_COLOR
	r.size = Vector2(BAR_WIDTH, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _make_fg(color: Color, h: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.size = Vector2(BAR_WIDTH, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _refresh_all() -> void:
	if _player:
		_on_health_changed(_player.hp, _player.max_hp)
		_on_xp_changed(_player.xp, _player.xp_to_next)

func _on_state_changed(state_name: String) -> void:
	if _phase_label:
		var info := _phase_label.text.split(" — ")
		_phase_label.text = "%s — %s" % [info[0], state_name]

func _on_level_started(scene_idx: int, level_idx: int) -> void:
	if _phase_label:
		_phase_label.text = "场景%d 关卡%d — 战斗" % [scene_idx, level_idx]

func _on_health_changed(current: int, maximum: int) -> void:
	if _hp_label:
		_hp_label.text = "HP %d/%d" % [current, maximum]
	if _hp_fg:
		_hp_fg.size.x = BAR_WIDTH * clampf(float(current) / float(maximum), 0.0, 1.0)

func _on_xp_changed(_current_xp: int, _xp_to_next: int) -> void:
	_update_xp_display()

func _on_level_up(_new_level: int) -> void:
	_update_xp_display()

func _update_xp_display() -> void:
	if not _player:
		return
	if _level_label:
		_level_label.text = "LV %d  %d/%d" % [_player.level, _player.xp, _player.xp_to_next]
	if _xp_fg:
		_xp_fg.size.x = BAR_WIDTH * clampf(float(_player.xp) / float(_player.xp_to_next), 0.0, 1.0)
