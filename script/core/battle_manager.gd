extends Node

# 战斗管理器
# 开始战斗 → 加载全部关卡 → 逐关推进（生成敌人→关卡结束→奖励→下一关）→ 战斗结束

signal battle_started

var _enemies_node: Node2D
var _enemy_configs: Dictionary = {}    ## StringName -> Dictionary
var _active_coroutines: int = 0        ## 当前正在运行的波次协程数量
var _failed: bool = false              ## 战斗失败标志

## 开始整场战斗：初始化 + 加载全部关卡 + 逐关推进
func start_battle(enemies_node: Node2D) -> void:
	_enemies_node = enemies_node
	_load_enemy_configs()
	var levels := _load_all_levels()
	if levels.is_empty():
		return
	battle_started.emit()
	_failed = false
	for level in levels:
		await _run_level(level)
		if _failed:
			break
		# TODO: 奖励系统

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

## 战斗失败，终止当前战斗流程
func fail_battle() -> void:
	_failed = true

## 运行单个关卡：启动所有波次协程，等待全部完成
func _run_level(level: LevelData) -> void:
	_active_coroutines = level.waves.size()
	for wave in level.waves:
		_run_wave.call_deferred(wave)
	while _active_coroutines > 0 and not _failed:
		await get_tree().process_frame

## 单条波次的协程：等待 start_time → 按间隔生成 count 个敌人
func _run_wave(wave: WaveData) -> void:
	await get_tree().create_timer(wave.start_time).timeout
	for i in wave.count:
		_spawn_enemy(wave.enemy_id)
		if i < wave.count - 1:
			await get_tree().create_timer(wave.spawn_interval).timeout
	_active_coroutines -= 1

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
	# 在玩家周围随机位置生成
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player:
		var angle := randf() * TAU
		var distance := randf() * 100.0 + 100.0
		enemy.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * distance
