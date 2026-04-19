extends Node

# 战斗管理器（状态机）
# IDLE → RUNNING → REWARD → RUNNING → ... → ENDED
#                  ↘ FAILED

enum State { IDLE, RUNNING, REWARD, FAILED, ENDED }

signal battle_started
signal battle_ended

var _state: State = State.IDLE
var _enemies_node: Node2D
var _enemy_configs: Dictionary = {}    ## StringName -> Dictionary
var _levels: Array = []                ## LevelData 数组
var _current_level_index: int = -1     ## 当前关卡索引

## 开始整场战斗
func start_battle(enemies_node: Node2D) -> void:
	_enemies_node = enemies_node
	_load_enemy_configs()
	_levels = _load_all_levels()
	if _levels.is_empty():
		return
	battle_started.emit()
	_start_level(0)

## 启动指定关卡
func _start_level(index: int) -> void:
	_current_level_index = index
	_state = State.RUNNING
	var level: LevelData = _levels[index]
	for wave in level.waves:
		_run_wave.call_deferred(wave)

## 外部调用：当前关卡所有敌人被消灭
func on_level_cleared() -> void:
	if _state != State.RUNNING:
		return
	_state = State.REWARD

## 外部调用：玩家死亡
func fail_battle() -> void:
	_state = State.FAILED

## 外部调用：奖励选完，进入下一关
func advance_to_next_level() -> void:
	if _state != State.REWARD:
		return
	var next := _current_level_index + 1
	if next < _levels.size():
		_start_level(next)
	else:
		_state = State.ENDED
		battle_ended.emit()

## 单条波次协程：等待 start_time → 按间隔生成 count 个敌人
func _run_wave(wave: WaveData) -> void:
	await get_tree().create_timer(wave.start_time).timeout
	for i in wave.count:
		if _state == State.FAILED:
			return
		_spawn_enemy(wave.enemy_id)
		if i < wave.count - 1:
			await get_tree().create_timer(wave.spawn_interval).timeout

## 根据 enemy_id 查找配置，实例化敌人
func _spawn_enemy(enemy_id: StringName) -> void:
	var cfg: Dictionary = _enemy_configs.get(enemy_id, {})
	if cfg.is_empty():
		return
	var scene_path: String = cfg.get("scene", "")
	var scene: PackedScene = load(scene_path) as PackedScene
	if not scene:
		return
	var enemy := scene.instantiate()
	enemy.init(cfg)
	_enemies_node.add_child(enemy)
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player:
		var angle := randf() * TAU
		var distance := randf() * 100.0 + 100.0
		enemy.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * distance

## 从 enemies.json 加载所有敌人配置
func _load_enemy_configs() -> void:
	var file := FileAccess.open("res://data/enemy/enemies.json", FileAccess.READ)
	if not file:
		push_error("没有读取到怪物配置文件res://data/enemy/enemies.json")
		return
	var text := _strip_comments(file.get_as_text())
	file.close()
	var json := JSON.new()
	json.parse(text)
	for cfg in json.data.get("enemies", []):
		var id: StringName = StringName(cfg.get("id", ""))
		if id != &"":
			_enemy_configs[id] = cfg

## 跳过 # 开头的注释行
func _strip_comments(raw: String) -> String:
	var lines := raw.split("\n")
	var clean: PackedStringArray = []
	for line in lines:
		if not line.strip_edges().begins_with("#"):
			clean.append(line)
	return "\n".join(clean)

## 从 levels.json 加载全部关卡
func _load_all_levels() -> Array:
	var file := FileAccess.open("res://data/level/levels.json", FileAccess.READ)
	if not file:
		return []
	var text := _strip_comments(file.get_as_text())
	file.close()
	var json := JSON.new()
	json.parse(text)
	var levels: Array = []
	for level_dict in json.data.get("levels", []):
		levels.append(LevelData.from_dict(level_dict))
	return levels
