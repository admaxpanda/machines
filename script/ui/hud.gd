extends CanvasLayer

## HUD 左上角：关卡信息 + 血条 + 经验条

@export var player_path: NodePath
@export var battle_manager_path: NodePath

const BAR_WIDTH := 120.0
const HP_BAR_H := 8.0
const XP_BAR_H := 6.0
const MARGIN := 10.0
const BG_COLOR := Color(0.25, 0.25, 0.25)
const HP_COLOR := Color(0.85, 0.15, 0.15)
const XP_COLOR := Color(0.2, 0.85, 0.3)

var _player: CharacterBody2D
var _battle_manager: Node
var _hp_fg: ColorRect
var _xp_fg: ColorRect
var _hp_label: Label
var _level_label: Label
var _phase_label: Label

func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	if _player:
		_player.health_changed.connect(_on_health_changed)
		_player.xp_changed.connect(_on_xp_changed)
		_player.leveled_up.connect(_on_level_up)
	_battle_manager = get_node_or_null(battle_manager_path)
	if _battle_manager:
		_battle_manager.state_changed.connect(_on_state_changed)
		_battle_manager.level_started.connect(_on_level_started)
	_build_ui()
	_refresh_all()

func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.offset_left = MARGIN
	root.offset_top = MARGIN
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	root.add_child(vbox)

	# — 关卡信息 —
	_phase_label = _make_label()
	_phase_label.text = "场景- 关卡- —"
	vbox.add_child(_phase_label)

	# — HP —
	_hp_label = _make_label()
	vbox.add_child(_hp_label)

	var hp_bar := _make_bar_holder(HP_BAR_H)
	vbox.add_child(hp_bar)

	var hp_bg := _make_bg(HP_BAR_H)
	hp_bar.add_child(hp_bg)
	_hp_fg = _make_fg(HP_COLOR, HP_BAR_H)
	hp_bar.add_child(_hp_fg)

	# — XP —
	_level_label = _make_label()
	vbox.add_child(_level_label)

	var xp_bar := _make_bar_holder(XP_BAR_H)
	vbox.add_child(xp_bar)

	var xp_bg := _make_bg(XP_BAR_H)
	xp_bar.add_child(xp_bg)
	_xp_fg = _make_fg(XP_COLOR, XP_BAR_H)
	xp_bar.add_child(_xp_fg)

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
