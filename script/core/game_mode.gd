class_name GameMode
extends RefCounted

enum Mode { STANDARD, DRAFT }

static var mode: Mode = Mode.STANDARD

## 加载存档时设置的跨场景数据
static var starting_level_index: int = -1
static var loaded_attack_cards: Array = []
static var loaded_skill_cards: Array = []
static var loaded_abilities: Array = []

## 统计数据
static var kill_count: int = 0
static var start_time: int = 0
static var elapsed_ms: int = 0
static var _pause_start: int = 0
static var _paused_ms: int = 0

static func start_run() -> void:
	start_time = Time.get_ticks_msec()
	kill_count = 0
	elapsed_ms = 0
	_paused_ms = 0

static func pause() -> void:
	_pause_start = Time.get_ticks_msec()

static func resume() -> void:
	if _pause_start > 0:
		_paused_ms += Time.get_ticks_msec() - _pause_start
		_pause_start = 0

static func get_play_time_ms() -> int:
	return Time.get_ticks_msec() - start_time - _paused_ms

static func clear_load_state() -> void:
	starting_level_index = -1
	loaded_attack_cards.clear()
	loaded_skill_cards.clear()
	loaded_abilities.clear()
