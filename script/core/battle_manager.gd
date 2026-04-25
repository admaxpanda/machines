extends Node

# 战斗管理器（状态机）
# IDLE → RUNNING → REWARD → RUNNING → ... → ENDED
#                  ↘ FAILED

enum State { IDLE, RUNNING, REWARD, FAILED, ENDED }

signal battle_started
signal battle_ended
signal state_changed(state_name: String)
signal level_started(scene_idx: int, level_idx: int)

var _state: State = State.IDLE
var _enemies_node: Node2D
var _enemy_configs: Dictionary = {}    ## StringName -> Dictionary
var _levels: Array = []                ## LevelData 数组
var _current_level_index: int = -1     ## 当前关卡索引
var _alive_enemies: int = 0            ## 当前关卡存活敌人数
var _ground_layer: TileMapLayer         ## ground TileMapLayer 引用
var _ground_cells: Array[Vector2i] = [] ## ground 格子坐标缓存
var _waves_running: int = 0            ## 还在生成中的波次数
var _reward_manager: Node              ## RewardManager 引用
var _card_engine: Node                 ## CardEngine 引用

## 开始整场战斗
func start_battle(enemies_node: Node2D, starting_level_index: int = 0) -> void:
	_enemies_node = enemies_node
	_ground_layer = enemies_node.get_parent().get_node("ground") as TileMapLayer
	if _ground_layer:
		_ground_cells = _ground_layer.get_used_cells()
	add_to_group(&"battle_manager")
	_load_enemy_configs()
	_levels = _load_all_levels()
	if _levels.is_empty():
		return
	if _reward_manager:
		var player := get_tree().get_first_node_in_group(&"player") as CharacterBody2D
		if player:
			_reward_manager.on_battle_started(player)
	battle_started.emit()
	_start_level(starting_level_index)

## 启动指定关卡
func _start_level(index: int) -> void:
	_current_level_index = index
	_state = State.RUNNING
	_alive_enemies = 0
	_reset_player_state()
	_clear_glass_barriers()
	_clear_lightning_rod_barriers()
	_channel_starting_orb()
	var level: LevelData = _levels[index]
	_waves_running = level.waves.size()
	level_started.emit(level.scene_index + 1, level.level_index + 1)
	state_changed.emit("战斗")
	for wave in level.waves:
		_run_wave.call_deferred(wave)

## 外部调用：当前关卡所有敌人被消灭
func on_level_cleared() -> void:
	if _state != State.RUNNING:
		return
	_clear_orbs()
	_reset_card_engines()
	var _ocl_player := get_tree().get_first_node_in_group(&"player") as CharacterBody2D
	if _ocl_player and _ocl_player.has_method("cancel_invincibility"):
		_ocl_player.cancel_invincibility()
	_state = State.REWARD
	state_changed.emit("奖励")
	if _card_engine:
		_card_engine.stop_turns()
	if _reward_manager:
		_reward_manager.start_rewards(_card_engine)

## 外部调用：玩家死亡
func fail_battle() -> void:
	_state = State.FAILED

## 外部调用：奖励选完，进入下一关
func advance_to_next_level() -> void:
	if _state != State.REWARD:
		return
	var next := _current_level_index + 1
	if next < _levels.size():
		if _card_engine:
			_card_engine.run_turns()
		_start_level(next)
	else:
		_state = State.ENDED
		state_changed.emit("结束")
		battle_ended.emit()

## 奖励完成后回调
func _on_rewards_completed() -> void:
	advance_to_next_level()

## 单条波次协程：等待 start_time → 按间隔生成 count 个敌人
func _run_wave(wave: WaveData) -> void:
	await get_tree().create_timer(wave.start_time, false).timeout
	for i in wave.count:
		if _state == State.FAILED:
			_waves_running -= 1
			return
		_spawn_enemy(wave.enemy_id, wave.type)
		if i < wave.count - 1:
			await get_tree().create_timer(wave.spawn_interval, false).timeout
	_waves_running -= 1
	_check_level_cleared()

## 根据 enemy_id 查找配置，实例化敌人
func _spawn_enemy(enemy_id: StringName, wave_type: StringName = &"normal") -> void:
	var cfg: Dictionary = _enemy_configs.get(enemy_id, {})
	if cfg.is_empty():
		return
	var scene_path: String = cfg.get("scene", "")
	var scene: PackedScene = load(scene_path) as PackedScene
	if not scene:
		return
	var enemy := scene.instantiate()
	enemy.init(cfg)
	enemy.wave_type = wave_type
	enemy.died.connect(_on_enemy_died)
	_enemies_node.add_child(enemy)
	_alive_enemies += 1
	enemy.global_position = _pick_spawn_position()
	# HP 膨胀：每关 +10%
	if _current_level_index > 0:
		var scale := 1.0 + 0.1 * float(_current_level_index)
		enemy.hp = int(float(enemy.hp) * scale)
		enemy.max_hp = enemy.hp

## 从 ground 格子中随机选一个远离玩家的位置
func _pick_spawn_position() -> Vector2:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if _ground_cells.is_empty() or not player:
		var angle := randf() * TAU
		return player.global_position + Vector2(cos(angle), sin(angle)) * 150.0 if player else Vector2.ZERO
	var tile_size := _ground_layer.tile_set.tile_size
	var min_dist_sq := 100.0 * 100.0
	for _attempt in range(20):
		var cell: Vector2i = _ground_cells[randi() % _ground_cells.size()]
		var world_pos := Vector2(cell.x * tile_size.x + tile_size.x / 2, cell.y * tile_size.y + tile_size.y / 2)
		if (world_pos - player.global_position).length_squared() >= min_dist_sq:
			return world_pos
	var fallback: Vector2i = _ground_cells[randi() % _ground_cells.size()]
	return Vector2(fallback.x * tile_size.x + tile_size.x / 2, fallback.y * tile_size.y + tile_size.y / 2)

## 敌人死亡回调
func _on_enemy_died(enemy: CharacterBody2D) -> void:
	_alive_enemies -= 1
	GameMode.kill_count += 1
	_trigger_consuming_shadow_kill()
	if enemy.wave_type == &"boss":
		_cleanup_minions(enemy)
		var player := get_tree().get_first_node_in_group(&"player") as CharacterBody2D
		if player and player.has_method("heal_boss_reward"):
			player.heal_boss_reward()
		if _alive_enemies <= 0 and _waves_running <= 0:
			_collect_gems_then_clear.call_deferred()
		return
	_check_level_cleared()

## Boss 死亡时清理其爪牙
func _cleanup_minions(summoner: Node2D) -> void:
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		if is_instance_valid(enemy) and enemy._is_minion and enemy._summoner == summoner:
			enemy._dead = true
			enemy.queue_free()
			_alive_enemies -= 1

## 在指定位置生成敌人（供 slime 能力调用）
func spawn_enemy_at(enemy_id: StringName, pos: Vector2, summoner: Node2D = null) -> void:
	var cfg: Dictionary = _enemy_configs.get(enemy_id, {})
	if cfg.is_empty():
		return
	var scene_path: String = cfg.get("scene", "")
	var scene: PackedScene = load(scene_path) as PackedScene
	if not scene:
		return
	var enemy := scene.instantiate()
	enemy.init(cfg)
	enemy.wave_type = &"normal"
	if summoner:
		enemy._is_minion = true
		enemy._summoner = summoner
		enemy._no_xp_drop = true
	enemy.died.connect(_on_enemy_died)
	_enemies_node.add_child(enemy)
	_alive_enemies += 1
	enemy.global_position = pos
	# HP 膨胀
	if _current_level_index > 0:
		var scale := 1.0 + 0.1 * float(_current_level_index)
		enemy.hp = int(float(enemy.hp) * scale)
		enemy.max_hp = enemy.hp

## 吞噬暗影：击杀敌人时触发所有黑暗充能球被动
func _trigger_consuming_shadow_kill() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if not player or not "abilities" in player:
		return
	var has_shadow := false
	for a in player.abilities:
		if a.id == &"consuming_shadow":
			has_shadow = true
			break
	if not has_shadow:
		return
	var managers := get_tree().get_nodes_in_group(&"orb_manager")
	if managers.is_empty():
		return
	var orb_mgr = managers[0]
	for i in orb_mgr.slots.size():
		if i >= orb_mgr.slots.size():
			break
		if orb_mgr.slots[i].data.id == &"dark":
			orb_mgr._trigger_passive(orb_mgr.slots[i], orb_mgr._visuals[i].global_position if i < orb_mgr._visuals.size() else Vector2.ZERO)
	orb_mgr._refresh_labels()

## 清空所有充能球
func _clear_orbs() -> void:
	var managers := get_tree().get_nodes_in_group(&"orb_manager")
	if managers.size() > 0:
		managers[0].clear_all()

## 清除所有玻璃障碍
func _clear_glass_barriers() -> void:
	for gb in get_tree().get_nodes_in_group(&"glass_barrier"):
		gb.queue_free()

## 清除所有引雷针障碍
func _clear_lightning_rod_barriers() -> void:
	for lrb in get_tree().get_nodes_in_group(&"lightning_rod_barrier"):
		lrb.queue_free()

## 重置 buffer 免伤次数
func _reset_buffer_charges(player: CharacterBody2D) -> void:
	var count := 0
	for a in player.abilities:
		if a.id == &"buffer":
			count += 1
	player.buffer_charges = count

## 关卡开始时重置玩家状态：清空 buff → 重置球槽 → 重新施加能力效果
func _reset_player_state() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as CharacterBody2D
	if not player or not "abilities" in player:
		return

	# 保存 biased_cognition 剩余层数（跨关卡衰减后）
	var biased_stacks: int = 0
	if player.buff_container and player.buff_container.has_buff(&"biased_cognition"):
		biased_stacks = player.buff_container.get_buff_stacks(&"biased_cognition")

	# 清空所有 buff
	if player.buff_container:
		player.buff_container.clear_all()

	# 重置球槽为基础值，再根据能力调整
	var orb_managers := get_tree().get_nodes_in_group(&"orb_manager")
	var orb_mgr = orb_managers[0] if orb_managers.size() > 0 else null
	if orb_mgr:
		orb_mgr.max_slots = 3
		for a in player.abilities:
			match a.id:
				&"capacitor":
					orb_mgr.max_slots += 2
				&"bulk_up":
					orb_mgr.max_slots = maxi(orb_mgr.max_slots - 1, 1)

	# 重新施加永久能力 buff
	for a in player.abilities:
		match a.id:
			&"defragment":
				player.buff_container.add_buff(&"focus", 1, -1)
			&"bulk_up":
				player.buff_container.add_buff(&"strength", 2, -1)
				player.buff_container.add_buff(&"dexterity", 2, -1)
			&"biased_cognition":
				if biased_stacks > 0:
					player.buff_container.add_buff(&"focus", biased_stacks, -1)
					player.buff_container.add_buff(&"biased_cognition", biased_stacks, -1)

	# 重置 buffer 免伤次数
	_reset_buffer_charges(player)
	player.claw_times = 1
	player.lightning_channeled = 0
	if player.has_method("cancel_invincibility"):
		player.cancel_invincibility()

## 重置卡牌引擎：所有牌归位，能量清零
func _reset_card_engines() -> void:
	if _card_engine:
		_card_engine.reset_for_new_battle()
	var skill_engines := get_tree().get_nodes_in_group(&"skill_card_engine")
	if skill_engines.size() > 0:
		skill_engines[0].reset_for_new_battle()

## 关卡开始时自动获得一个电充能球
func _channel_starting_orb() -> void:
	var managers := get_tree().get_nodes_in_group(&"orb_manager")
	if managers.size() > 0:
		managers[0].channel_orb(&"lightning")

## 检查关卡是否通关：所有敌人死亡且所有波次生成完毕
func _check_level_cleared() -> void:
	if _state != State.RUNNING:
		return
	if _alive_enemies <= 0 and _waves_running <= 0:
		_collect_gems_then_clear.call_deferred()

## 等待所有宝石飞向玩家并收集完毕后再进入奖励
func _collect_gems_then_clear() -> void:
	var gems := get_tree().get_nodes_in_group(&"gem")
	for gem in gems:
		if is_instance_valid(gem) and gem.has_method("force_attract"):
			gem.force_attract()
	while get_tree().get_nodes_in_group(&"gem").size() > 0:
		await get_tree().create_timer(0.05, false).timeout
	on_level_cleared()

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
