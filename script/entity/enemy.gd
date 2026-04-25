extends CharacterBody2D

# 通用敌人脚本 — 通过 init() JSON 数据驱动 AI 行为和能力

signal died(enemy: CharacterBody2D)

# --- 基础属性 ---
var hp: int = 10
var max_hp: int = 10
var speed: float = 80.0
var damage: int = 5
var xp_value: int = 1
var enemy_type: StringName = &"normal"
var wave_type: StringName = &"normal"
var _player: CharacterBody2D

# --- 血条 ---
var _hp_bar_fg: ColorRect
var _bar_width: float
var _damage_cooldown: float = 0.0
const BAR_HEIGHT: float = 2.0
const BAR_OFFSET: float = 6.0
const DAMAGE_COOLDOWN: float = 1.0

# --- AI 系统 ---
var _ai_type: String = "chase"
var _ai_params: Dictionary = {}
var _charge_state: String = "preparing"
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_timer: float = 0.0
var _charge_progress: float = 0.0
var _charge_target_pos: Vector2 = Vector2.ZERO
var _charge_line: Node2D = null
var _orbit_angle: float = 0.0


# --- 能力系统 ---
var _abilities: Array = []
var _ability_cooldowns: Array = []
var _casting: bool = false
var _cast_timer: float = 0.0
var _cast_ability: Dictionary = {}
var _shooting := false

# --- 爪牙系统 ---
var _is_minion: bool = false
var _summoner: Node2D = null
var _no_xp_drop: bool = false

# --- 被动系统 ---
var _passive: String = ""
var _passive_stacks: int = 0
var _damage_cap: int = -1
var _on_hit_inject: Dictionary = {}
var _on_hit_effect: String = ""
var _on_hit_value: int = 0
var _on_death_spawn: Dictionary = {}
var _personal_hive: bool = false

# --- 伤害池 (boss) ---
var _damage_pool_max: float = 0.0
var _damage_pool: float = 0.0
var _damage_pool_recover_time: float = 0.0

# --- 光环状态 ---
var _tender_aura_active: bool = false
var _tender_aura_params: Dictionary = {}
var _smoggy_applied: bool = false

# --- 墨宝 AI 状态 ---
var _inklet_spray_cd: float = 0.0
var _inklet_spray_cd_max: float = 10.0
var _inklet_spray_range: float = 250.0
var _inklet_approach_timer: float = 0.0
var _inklet_approach_timeout: float = 4.0
var _inklet_firing: bool = false
var _inklet_aiming: bool = false
var _inklet_aim_timer: float = 0.0
var _inklet_aim_duration: float = 0.6
var _inklet_aim_indicator: Node2D = null

# --- Slippery 视觉 ---
var _slippery_icon: Texture2D = null
var _slippery_label: Label = null

# --- 状态 ---
var _dead := false
var _knockback_vel := Vector2.ZERO
var _stun_timer: float = 0.0
var _fusing := false
var _fuse_timer: float = 0.0
var _fuse_total: float = 0.5
var _flash_timer: float = 0.0
var _flash_on := false
var _self_destruct_config: Dictionary = {}

# --- Buff ---
var buff_container: Node

## 由 battle_manager 调用，传入 JSON 中该敌人的数据
func init(data: Dictionary) -> void:
	hp = int(data.get("hp", 10))
	max_hp = hp
	speed = float(data.get("speed", 80))
	damage = int(data.get("damage", 5))
	xp_value = int(data.get("xp_value", 1))
	enemy_type = StringName(data.get("type", "normal"))
	_ai_type = str(data.get("ai", "chase"))
	_ai_params = data.get("ai_params", {})
	_abilities = data.get("abilities", [])
	_is_minion = bool(data.get("is_minion", false))
	_no_xp_drop = bool(data.get("no_xp_drop", false))
	_passive = str(data.get("passive", ""))
	_passive_stacks = int(data.get("passive_stacks", 0))
	_damage_cap = int(data.get("damage_cap", -1))
	_on_hit_inject = data.get("on_hit_inject", {})
	_on_hit_effect = str(data.get("on_hit_effect", ""))
	_on_hit_value = int(data.get("on_hit_value", 0))
	_on_death_spawn = data.get("on_death_spawn", {})
	_personal_hive = bool(data.get("personal_hive", false))
	_damage_pool_max = float(data.get("damage_pool", 0.0))
	_damage_pool = _damage_pool_max
	_damage_pool_recover_time = float(data.get("damage_pool_recover_time", 0.0))
	# 墨宝 AI 参数
	if _ai_type == "inklet":
		for ab in _abilities:
			if str(ab.get("type", "")) == "ink_spray":
				_inklet_spray_cd_max = float(ab.get("cooldown", 10.0))
				_inklet_spray_range = float(ab.get("range", 250.0))
				_inklet_aim_duration = float(ab.get("aim_time", 0.6))
		_inklet_approach_timeout = float(_ai_params.get("approach_timeout", 4.0))
	# 能力冷却初始化为 0（即立即可以使用）
	_ability_cooldowns.clear()
	for ab in _abilities:
		_ability_cooldowns.append(0.0)
	# 技能型被动立即生效
	for ab in _abilities:
		if str(ab.get("type", "")) == "tender_aura":
			_tender_aura_params = ab

func _ready() -> void:
	add_to_group(&"enemy")
	_create_health_bar()
	buff_container = Node.new()
	var script: GDScript = load("res://script/core/buff/buff_container.gd")
	buff_container.set_script(script)
	buff_container.add_to_group(&"buff_container")
	add_child(buff_container)
	var players := get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		_player = players[0] as CharacterBody2D
		if _player and _player.has_signal(&"hp_lost") and _on_hit_effect != "":
			_player.hp_lost.connect(_on_player_hp_lost)
	# slippery 图标显示
	if _passive == "slippery" and _passive_stacks > 0:
		_create_slippery_visual()
	# smoggy: boss 存活期间给玩家施加 debuff
	for ab in _abilities:
		if str(ab.get("type", "")) == "smoggy":
			_apply_smoggy()
			break
	# self_destruct: 记录配置
	for ab in _abilities:
		if str(ab.get("type", "")) == "self_destruct":
			_self_destruct_config = ab

func take_damage(amount: int) -> void:
	if _dead:
		return
	# 伤害上限
	if _damage_cap > 0:
		amount = mini(amount, _damage_cap)
	# slippery：确定性闪避，消耗1层
	if _passive == "slippery" and _passive_stacks > 0:
		_passive_stacks -= 1
		_update_slippery_visual()
		return
	# 伤害池 (boss)
	if _damage_pool_max > 0.0:
		_damage_pool -= float(amount)
		if _damage_pool <= 0.0:
			# 伤害池耗尽，溢出伤害扣除 HP
			hp += int(_damage_pool)
			_damage_pool = 0.0
		_update_health_bar()
		if hp <= 0:
			_die()
		return
	# personal_hive：受击时往玩家攻击抽牌堆注入 DAZED
	if _personal_hive:
		_inject_card_to_player(&"dazed", &"attack", &"draw")
	var remaining: int = buff_container.apply_shield_damage(amount)
	hp -= remaining
	_update_health_bar()
	if hp <= 0:
		_die()


func _start_fuse() -> void:
	_fusing = true
	_fuse_timer = 0.0
	_flash_timer = 0.0

func _explode() -> void:
	_dead = true
	var radius := float(_self_destruct_config.get("radius", 80.0))
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	# 播放爆炸动画
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"explode"):
		sprite.play(&"explode")
		var anim_len := sprite.sprite_frames.get_frame_count(&"explode") / sprite.sprite_frames.get_animation_speed(&"explode")
		# 暂停移动，等动画播完
		set_physics_process(false)
		# AoE 伤害
		_do_aoe_damage(global_position, radius, damage)
		# 不掉落，不生成
		_remove_tender_aura()
		_remove_smoggy()
		died.emit(self)
		get_tree().create_timer(anim_len, false).timeout.connect(queue_free)
	else:
		_do_aoe_damage(global_position, radius, damage)
		_remove_tender_aura()
		_remove_smoggy()
		died.emit(self)
		queue_free()

func _die() -> void:
	if not _self_destruct_config.is_empty():
		_explode()
		return
	_dead = true
	# 移除光环效果
	_remove_tender_aura()
	_remove_smoggy()
	# 死亡生成怪物
	_handle_on_death_spawn()
	# 掉落
	if not _no_xp_drop:
		_spawn_xp_gem()
	died.emit(self)
	queue_free()

func apply_knockback(direction: Vector2, force: float) -> void:
	_knockback_vel = direction.normalized() * force

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not _player or not is_instance_valid(_player):
		return
	# 眩晕
	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity = _knockback_vel
		_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		# 面朝移动方向
		var sprite := $AnimatedSprite2D as AnimatedSprite2D
		if sprite and velocity.x != 0.0:
			sprite.flip_h = velocity.x > 0.0
		return
	# 施法中不移动
	if _casting:
		_cast_timer -= delta
		if _cast_timer <= 0.0:
			_execute_ability(_cast_ability)
			_casting = false
			_cast_ability = {}
		return
	# 更新能力冷却
	_update_abilities(delta)
	# 更新被动检测
	_check_passives()
	# 墨宝瞄准更新
	if _ai_type == "inklet":
		_update_inklet_aim(delta)
	# 伤害池恢复
	if _damage_pool_max > 0.0 and _damage_pool_recover_time > 0.0 and _damage_pool < _damage_pool_max:
		_damage_pool = minf(_damage_pool + _damage_pool_max / _damage_pool_recover_time * delta, _damage_pool_max)
	# 碰撞伤害
	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
	# 自爆引信
	if _fusing:
		_fuse_timer += delta
		var sprite := $AnimatedSprite2D as AnimatedSprite2D
		var progress := _fuse_timer / _fuse_total
		var interval := 0.15 * (1.0 - progress * 0.8)
		_flash_timer += delta
		if _flash_timer >= interval:
			_flash_timer = 0.0
			_flash_on = not _flash_on
			if sprite:
				sprite.modulate = Color(8, 8, 8) if _flash_on else Color.WHITE
		if _fuse_timer >= _fuse_total:
			_explode()
			return
		velocity = Vector2.ZERO
		move_and_slide()
		return

		# AI 移动（射击中不移动，朝向由射击控制）
		var _sprite := $AnimatedSprite2D as AnimatedSprite2D
		if _shooting:
			velocity = Vector2.ZERO
			move_and_slide()
			return
		var ai_vel := _ai_get_velocity(delta)
		if buff_container and buff_container.has_buff(&"slow"):
			ai_vel *= 0.5
		velocity = ai_vel + _knockback_vel
		_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, 600.0 * delta)
		# 面朝移动方向 + 动画切换（射击类敌人不参与）
		var has_shoot := false
		for ab in _abilities:
			if str(ab.get("type", "")) == "shoot":
				has_shoot = true
				break
		if not has_shoot:
			if _sprite:
				if velocity.x != 0.0:
					_sprite.flip_h = velocity.x > 0.0
				var has_anim := _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"moving")
				if has_anim:
					var moving := velocity.length_squared() > 1.0
					if moving and _sprite.animation != &"moving":
						_sprite.play(&"moving")
					elif not moving and _sprite.animation != &"idle":
						_sprite.play(&"idle")
	move_and_slide()
	# 碰撞伤害检测
	if _damage_cooldown <= 0.0:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			if col.get_collider() == _player:
				if not _self_destruct_config.is_empty():
					if not _fusing:
						_start_fuse()
				else:
					_player.take_damage(damage, self)
					_on_hit_player()
				_damage_cooldown = DAMAGE_COOLDOWN
				break

# --- AI 调度器 ---

func _ai_get_velocity(delta: float) -> Vector2:
	match _ai_type:
		"chase":
			return _ai_chase()
		"kite":
			return _ai_kite()
		"charge":
			return _ai_charge(delta)
		"stationary":
			return Vector2.ZERO
		"flee":
			return _ai_flee()
		"orbit":
			return _ai_orbit(delta)
		"inklet":
			return _ai_inklet(delta)
	return _ai_chase()

func _ai_chase() -> Vector2:
	return (_player.global_position - global_position).normalized() * speed

func _ai_kite() -> Vector2:
	var dist := global_position.distance_to(_player.global_position)
	var preferred := float(_ai_params.get("preferred_distance", 0.0))
	if preferred <= 0.0:
		for ab in _abilities:
			if str(ab.get("type", "")) == "shoot":
				preferred = float(ab.get("range", 150.0))
				break
	if preferred <= 0.0:
		preferred = 150.0
	var dir := (_player.global_position - global_position).normalized()
	if dist < preferred - 30.0:
		return -dir * speed
	elif dist > preferred + 30.0:
		return dir * speed
	return Vector2(-dir.y, dir.x) * speed * 0.5

func _ai_charge(delta: float) -> Vector2:
	var max_dist := float(_ai_params.get("charge_distance", 150.0))
	var charge_spd := float(_ai_params.get("charge_speed", 400.0))
	var windup_time := float(_ai_params.get("windup_time", 1.5))
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	match _charge_state:
		"preparing":
			# 蓄力：停在原地，跟踪玩家
			if _player and is_instance_valid(_player):
				var to_player := _player.global_position - global_position
				if to_player.x != 0.0 and sprite:
					sprite.flip_h = to_player.x > 0.0
				_charge_dir = to_player.normalized()
			_charge_progress = minf(_charge_progress + max_dist / windup_time * delta, max_dist)
			# 画/更新蓄力线
			_update_charge_line()
			if sprite and sprite.animation != &"preparing":
				sprite.play(&"preparing")
			if _charge_progress >= max_dist:
				# 锁定目标位置
				_charge_target_pos = global_position + _charge_dir * max_dist
				_charge_state = "charging"
				if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"attacking"):
					sprite.play(&"attacking")
			return Vector2.ZERO
		"charging":
			# 冲刺到目标点
			var to_target := _charge_target_pos - global_position
			if to_target.length() <= charge_spd * delta:
				global_position = _charge_target_pos
				_charge_state = "preparing"
				_charge_progress = 0.0
				_clear_charge_line()
				if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"preparing"):
					sprite.play(&"preparing")
				return Vector2.ZERO
			return to_target.normalized() * charge_spd
	return Vector2.ZERO

func _update_charge_line() -> void:
	var line_end := global_position + _charge_dir * _charge_progress
	if not _charge_line:
		_charge_line = Line2D.new()
		_charge_line.width = 16.0
		_charge_line.default_color = Color(1.0, 0.2, 0.2, 0.3)
		_charge_line.z_index = 0
		_player.get_parent().add_child(_charge_line)
		_player.get_parent().move_child(_charge_line, _player.get_index())
	_charge_line.clear_points()
	_charge_line.add_point(global_position)
	_charge_line.add_point(line_end)

func _clear_charge_line() -> void:
	if _charge_line:
		_charge_line.queue_free()
		_charge_line = null

func _ai_flee() -> Vector2:
	return -(_player.global_position - global_position).normalized() * speed

func _ai_orbit(delta: float) -> Vector2:
	var orbit_dist := float(_ai_params.get("orbit_distance", 120.0))
	var orbit_spd := float(_ai_params.get("orbit_speed", 3.0))
	_orbit_angle += orbit_spd * delta
	var target_pos := _player.global_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * orbit_dist
	var dir := (target_pos - global_position)
	if dir.length() > 5.0:
		return dir.normalized() * speed
	return Vector2.ZERO


func _ai_inklet(delta: float) -> Vector2:
	if _inklet_aiming:
		return Vector2.ZERO
	var dist := global_position.distance_to(_player.global_position)
	# 喷墨在冷却中 → 追逐玩家
	if _inklet_spray_cd > 0.0:
		_inklet_spray_cd -= delta
		_inklet_approach_timer = 0.0
		return _ai_chase()
	# 喷墨就绪 → 接近到射程内
	if dist > _inklet_spray_range:
		_inklet_approach_timer += delta
		if _inklet_approach_timer >= _inklet_approach_timeout:
			_start_ink_aim()
			_inklet_approach_timer = 0.0
			return Vector2.ZERO
		return _ai_chase()
	# 在射程内 → 开火
	_start_ink_aim()
	return Vector2.ZERO

func _start_ink_aim() -> void:
	_inklet_aiming = true
	_inklet_aim_timer = _inklet_aim_duration
	var target_pos := _player.global_position
	# 从能力配置读取 aoe 半径
	var aoe_radius := 20.0
	for ab in _abilities:
		if str(ab.get("type", "")) == "ink_spray":
			aoe_radius = float(ab.get("aoe_radius", 20.0))
			break
	# 创建瞄准指示器
	_inklet_aim_indicator = Node2D.new()
	var sprite := AnimatedSprite2D.new()
	var frames: SpriteFrames = load("res://sprite/enemy/aimming.tres")
	sprite.sprite_frames = frames
	sprite.animation = &"default"
	sprite.autoplay = &"default"
	# 动态读取帧大小
	var frame_w := 32.0
	var frame_h := 32.0
	if frames and frames.get_frame_count(&"default") > 0:
		var tex: Texture2D = frames.get_frame_texture(&"default", 0)
		if tex:
			frame_w = float(tex.get_width())
			frame_h = float(tex.get_height())
	# 视觉直径 = aoe半径 × 2 × 2（两倍覆盖+空白补偿）
	var visual_diameter := aoe_radius * 4.0
	# offset 居中：在纹理坐标系内偏移半帧（不受 scale 影响）
	#sprite.offset = Vector2(-frame_w / 2.0, -frame_h / 2.0)
	sprite.scale = Vector2(visual_diameter / frame_w, visual_diameter / frame_h)
	_inklet_aim_indicator.add_child(sprite)
	_inklet_aim_indicator.global_position = target_pos
	_player.get_parent().add_child(_inklet_aim_indicator)
	_player.get_parent().move_child(_inklet_aim_indicator, _player.get_index())


func _update_inklet_aim(delta: float) -> void:
	if not _inklet_aiming:
		return
	_inklet_aim_timer -= delta
	if _inklet_aim_timer <= 0.0:
		_inklet_aiming = false
		# 发射抛物线墨汁
		var target_pos := _inklet_aim_indicator.global_position if is_instance_valid(_inklet_aim_indicator) else _player.global_position
		if is_instance_valid(_inklet_aim_indicator):
			_inklet_aim_indicator.queue_free()
			_inklet_aim_indicator = null
		var ink_data: Dictionary = {}
		for ab in _abilities:
			if str(ab.get("type", "")) == "ink_spray":
				ink_data = ab
				break
		_fire_ink_spray(target_pos, ink_data)
		_inklet_spray_cd = _inklet_spray_cd_max

func _fire_ink_spray(target_pos: Vector2, ab: Dictionary) -> void:
	var dmg := int(ab.get("damage", 8))
	var peak_height := float(ab.get("peak_height", 100.0))
	var flight_time := float(ab.get("flight_time", 1.0))
	var aoe_radius := float(ab.get("aoe_radius", 20.0))
	var proj_script: GDScript = load("res://script/entity/enemy/ink_projectile.gd")
	var proj := Node2D.new()
	proj.set_script(proj_script)
	proj.setup(global_position, target_pos, peak_height, flight_time, dmg, aoe_radius)
	get_tree().current_scene.add_child(proj)

func _update_abilities(delta: float) -> void:
	for i in _abilities.size():
		var ab: Dictionary = _abilities[i]
		var ab_type: String = str(ab.get("type", ""))
		# 跳过被动型能力
		if ab_type in ["self_destruct", "smoggy", "tender_aura", "ink_spray"]:
			continue
		_ability_cooldowns[i] -= delta
		if _ability_cooldowns[i] <= 0.0:
			_execute_ability(ab)
			_ability_cooldowns[i] = float(ab.get("cooldown", 3.0))
			break

func _execute_ability(ab: Dictionary) -> void:
	match ab.get("type", ""):
		"fall_attack":
			_ability_fall_attack(ab)
		"shoot":
			_ability_shoot(ab)
		"spawn_minion":
			_ability_spawn_minion(ab)
		"projectile_spawn":
			_ability_projectile_spawn(ab)

func _ability_fall_attack(ab: Dictionary) -> void:
	if not _player:
		return
	var dmg := int(ab.get("damage", 8))
	var radius := float(ab.get("radius", 50.0))
	var target_pos := _player.global_position
	# 红色圆圈指示
	var indicator := Node2D.new()
	var circle_pts := PackedVector2Array()
	for j in 20:
		var a := TAU * float(j) / 20.0
		circle_pts.append(Vector2(cos(a), sin(a)) * radius)
	var poly := Polygon2D.new()
	poly.color = Color(1.0, 0.2, 0.2, 0.3)
	poly.polygon = circle_pts
	indicator.add_child(poly)
	indicator.global_position = target_pos
	get_tree().current_scene.add_child(indicator)
	# 延时后造成伤害
	get_tree().create_timer(1.0, false).timeout.connect(func() -> void:
		if not is_instance_valid(indicator):
			return
		indicator.queue_free()
		_do_aoe_damage(target_pos, radius, dmg)
	)

func _ability_shoot(ab: Dictionary) -> void:
	if not _player:
		return
	var dmg := int(ab.get("damage", 6))
	var spd := float(ab.get("speed", 250.0))
	var rng := float(ab.get("range", 400.0))
	var burst_count := int(ab.get("burst_count", 1))
	var burst_interval := float(ab.get("burst_interval", 0.1))
	var spread_deg := float(ab.get("spread_angle", 0.0))
	# 超出射程不开火
	if global_position.distance_to(_player.global_position) > rng:
		return
	var base_dir := (_player.global_position - global_position).normalized()
	var base_angle := base_dir.angle()
	var sprite := $AnimatedSprite2D as AnimatedSprite2D
	_shooting = true
	# 朝向：默认向左，玩家在右边则翻转
	if sprite and base_dir.x > 0.0:
		sprite.flip_h = true
	elif sprite:
		sprite.flip_h = false
	# 播放攻击动画，速度适配连发总时间
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"moving"):
		var total_time := float(burst_count) * burst_interval
		var frame_count := sprite.sprite_frames.get_frame_count(&"moving")
		if total_time > 0.0 and frame_count > 0:
			sprite.sprite_frames.set_animation_speed(&"moving", float(frame_count) / total_time)
		sprite.play(&"moving")
	for i in burst_count:
		var angle_offset := 0.0
		if spread_deg > 0.0:
			angle_offset = deg_to_rad(randf_range(-spread_deg, spread_deg))
		var dir := Vector2.from_angle(base_angle + angle_offset)
		var proj := Area2D.new()
		var proj_script: GDScript = load("res://script/entity/enemy/enemy_projectile.gd")
		proj.set_script(proj_script)
		proj.speed = spd
		proj.max_range = float(ab.get("bullet_range", rng))
		proj.direction = dir
		proj.damage = dmg
		proj.global_position = global_position
		proj._visual_golden = true
		get_tree().current_scene.add_child(proj)
		if i < burst_count - 1:
			await get_tree().create_timer(burst_interval, false).timeout
	# 恢复普通动画
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"normal"):
		sprite.sprite_frames.set_animation_speed(&"moving", 5.0)
		sprite.play(&"normal")
	_shooting = false

func _ability_spawn_minion(ab: Dictionary) -> void:
	var minion_id: StringName = StringName(ab.get("minion_id", ""))
	var count := int(ab.get("count", 1))
	var managers := get_tree().get_nodes_in_group(&"battle_manager")
	if managers.is_empty():
		return
	var bm = managers[0]
	for i in count:
		var offset := Vector2(randf_range(-50, 50), randf_range(-50, 50))
		bm.spawn_enemy_at(minion_id, global_position + offset, self)

func _ability_projectile_spawn(ab: Dictionary) -> void:
	if not _player:
		return
	var dmg := int(ab.get("damage", 10))
	var radius := float(ab.get("radius", 60.0))
	var spawn_id: StringName = StringName(ab.get("spawn_id", ""))
	var spawn_count := int(ab.get("spawn_count", 1))
	var target_pos := _player.global_position
	# 先落地伤害
	_do_aoe_damage(target_pos, radius, dmg)
	# 再生成怪物
	if spawn_id != &"":
		var managers := get_tree().get_nodes_in_group(&"battle_manager")
		if not managers.is_empty():
			var bm = managers[0]
			for i in spawn_count:
				var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
				bm.spawn_enemy_at(spawn_id, target_pos + offset, self)

# --- 被动检测 ---

func _check_passives() -> void:
	for ab in _abilities:
		match ab.get("type", ""):
			"tender_aura":
				_update_tender_aura(ab)

func _update_tender_aura(ab: Dictionary) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var aura_radius := float(ab.get("radius", 150.0))
	var dist := global_position.distance_to(_player.global_position)
	if dist <= aura_radius:
		if not _tender_aura_active:
			_tender_aura_active = true
			var str_reduce := int(ab.get("strength_reduction", 1))
			var dex_reduce := int(ab.get("dexterity_reduction", 1))
			for child in _player.get_children():
				if child.is_in_group(&"buff_container"):
					if str_reduce != 0:
						child.add_buff(&"strength", -str_reduce, -1)
					if dex_reduce != 0:
						child.add_buff(&"dexterity", -dex_reduce, -1)
					child.add_buff(&"tender_aura", 1, -1)
					break
	else:
		if _tender_aura_active:
			_remove_tender_aura()

func _remove_tender_aura() -> void:
	if not _tender_aura_active:
		return
	_tender_aura_active = false
	if not _player or not is_instance_valid(_player):
		return
	var str_reduce := int(_tender_aura_params.get("strength_reduction", 1))
	var dex_reduce := int(_tender_aura_params.get("dexterity_reduction", 1))
	for child in _player.get_children():
		if child.is_in_group(&"buff_container"):
			if str_reduce != 0:
				child.add_buff(&"strength", str_reduce, -1)
			if dex_reduce != 0:
				child.add_buff(&"dexterity", dex_reduce, -1)
			child.remove_buff(&"tender_aura")
			break

# --- smoggy ---

func _apply_smoggy() -> void:
	if not _player or not is_instance_valid(_player):
		return
	_smoggy_applied = true
	for child in _player.get_children():
		if child.is_in_group(&"buff_container"):
			child.add_buff(&"smoggy", 1, -1)
			break

func _remove_smoggy() -> void:
	if not _smoggy_applied:
		return
	_smoggy_applied = false
	if not _player or not is_instance_valid(_player):
		return
	for child in _player.get_children():
		if child.is_in_group(&"buff_container"):
			child.remove_buff(&"smoggy")
			break

# --- 碰撞命中效果 ---

func _on_hit_player() -> void:
	# 注入卡牌
	if not _on_hit_inject.is_empty():
		var card_id: StringName = StringName(_on_hit_inject.get("card_id", ""))
		var engine_type: String = str(_on_hit_inject.get("engine", "attack"))
		var dest: String = str(_on_hit_inject.get("destination", "discard"))
		_inject_card_to_player(card_id, engine_type, dest)

func _on_player_hp_lost(_amount: int, source: Node2D) -> void:
	# 玩家HP实际减少时触发（仅来源是自己时处理）
	if source != self or _on_hit_effect != "reduce_max_hp" or _on_hit_value <= 0:
		return
	if _player and "max_hp" in _player:
		_player.max_hp = maxi(_player.max_hp - _on_hit_value, 1)
		_player.hp = mini(_player.hp, _player.max_hp)
		_player.health_changed.emit(_player.hp, _player.max_hp)
		_spawn_biting_effect()

func _spawn_biting_effect() -> void:
	var mid_pos := (global_position + _player.global_position) / 2.0
	var anim := AnimatedSprite2D.new()
	var frames: SpriteFrames = load("res://sprite/enemy/biting.tres")
	anim.sprite_frames = frames
	anim.animation = &"default"
	anim.autoplay = &"default"
	# 朝向与怪物同向
	if velocity.x > 0.0:
		anim.flip_h = true
	anim.global_position = mid_pos
	_player.get_parent().add_child(anim)
	var top_idx := maxi(self.get_index(), _player.get_index())
	anim.get_parent().move_child(anim, top_idx + 1)
	# 播完后消失
	var duration := 1.0
	get_tree().create_timer(duration, false).timeout.connect(anim.queue_free)

func _inject_card_to_player(card_id: StringName, engine_type: String, dest: String) -> void:
	if card_id == &"" or not _player:
		return
	var engines: Array
	if engine_type == "attack":
		engines = _player.get_tree().get_nodes_in_group(&"card_engine")
	elif engine_type == "skill":
		engines = _player.get_tree().get_nodes_in_group(&"skill_card_engine")
	if engines.is_empty():
		return
	var engine = engines[0]
	var db: Dictionary = CardLoader.load_status_cards()
	if not db.has(card_id):
		return
	var card: CardData = db[card_id]
	card.temporary = true
	if dest == "discard":
		engine.discard_pile.append(card)
	else:
		engine.draw_pile.append(card)
	_spawn_inject_text(card_id)


func _spawn_inject_text(card_id: StringName) -> void:
	var text := ""
	var color := Color.YELLOW
	match card_id:
		&"infection":
			text = "感染"
			color = Color(0.85, 0.75, 0.2)
		_:
			text = String(card_id)
	if text == "":
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.global_position = _player.global_position + Vector2(randf_range(-8, 8), -20)
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().current_scene.add_child(label)
	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 30, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(label.queue_free)

# --- 死亡生成 ---

func _handle_on_death_spawn() -> void:
	if _on_death_spawn.is_empty():
		return
	var spawn_id: StringName = StringName(_on_death_spawn.get("id", ""))
	var spawn_count := int(_on_death_spawn.get("count", 1))
	if spawn_id == &"":
		return
	var managers := get_tree().get_nodes_in_group(&"battle_manager")
	if managers.is_empty():
		return
	var bm = managers[0]
	for i in spawn_count:
		var offset := Vector2(randf_range(-40, 40), randf_range(-40, 40))
		bm.spawn_enemy_at(spawn_id, global_position + offset, null)

# --- 范围伤害 ---

func _do_aoe_damage(center: Vector2, radius: float, dmg: int) -> void:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	var results := space_state.intersect_shape(query)
	for result in results:
		var body: Node2D = result.get("collider")
		if body and body.is_in_group(&"player") and body.has_method("take_damage"):
			body.take_damage(dmg)
	# 视觉反馈
	var circle := Node2D.new()
	var pts := PackedVector2Array()
	for j in 16:
		var a := TAU * float(j) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = Color(1.0, 0.4, 0.2, 0.4)
	circle.add_child(poly)
	circle.global_position = center
	get_tree().current_scene.add_child(circle)
	var tween := circle.create_tween()
	tween.tween_property(poly, "modulate:a", 0.0, 0.3)
	tween.tween_callback(circle.queue_free)

# --- 掉落 ---

func _spawn_xp_gem() -> void:
	var gem := Area2D.new()
	var script: GDScript = load("res://script/entity/xp_gem.gd")
	gem.set_script(script)
	gem.xp_value = xp_value
	gem.global_position = global_position
	get_tree().current_scene.add_child(gem)
	if randf() < 0.01:
		_spawn_heal_gem()

func _spawn_heal_gem() -> void:
	var gem := Area2D.new()
	var script: GDScript = load("res://script/entity/heal_gem.gd")
	gem.set_script(script)
	gem.global_position = global_position + Vector2(randf() * 6.0 - 3.0, randf() * 6.0 - 3.0)
	get_tree().current_scene.add_child(gem)


func _create_slippery_visual() -> void:
	var tex: Texture2D = load("res://sprite/enemy/slippery.png")
	if not tex:
		return
	_slippery_icon = tex
	var col_shape: CollisionShape2D = $CollisionShape2D
	var radius := 10.0
	if col_shape and col_shape.shape:
		radius = col_shape.shape.radius
	var container := Control.new()
	container.position = Vector2(-8.0, -(radius + 20.0))
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = tex
	icon.size = Vector2(16.0, 16.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(icon)
	_slippery_label = Label.new()
	_slippery_label.text = str(_passive_stacks)
	_slippery_label.position = Vector2(18.0, 0.0)
	_slippery_label.add_theme_font_size_override(&"font_size", 10)
	_slippery_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_slippery_label)
	add_child(container)

func _update_slippery_visual() -> void:
	if _slippery_label:
		_slippery_label.text = str(_passive_stacks)
	if _passive_stacks <= 0:
		# 找到并移除 slippery 图标的父 Control
		for child in get_children():
			if child is Control and child.get_child_count() >= 1:
				var first = child.get_child(0)
				if first is TextureRect and first.texture == _slippery_icon:
					child.queue_free()
					break

# --- 血条 ---

func _create_health_bar() -> void:
	var col_shape: CollisionShape2D = $CollisionShape2D
	var radius := 10.0
	if col_shape and col_shape.shape:
		radius = col_shape.shape.radius
	_bar_width = radius * 2.0
	var container := Control.new()
	container.position = Vector2(-_bar_width / 2.0, -(radius + BAR_OFFSET))
	container.size = Vector2(_bar_width, BAR_HEIGHT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color(0.25, 0.25, 0.25)
	bg.size = Vector2(_bar_width, BAR_HEIGHT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)
	_hp_bar_fg = ColorRect.new()
	_hp_bar_fg.color = Color(0.85, 0.15, 0.15)
	_hp_bar_fg.size = Vector2(_bar_width, BAR_HEIGHT)
	_hp_bar_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_hp_bar_fg)
	add_child(container)

func _update_health_bar() -> void:
	if not _hp_bar_fg:
		return
	if _damage_pool_max > 0.0:
		# boss 伤害池显示：红=HP, 蓝=伤害池
		var hp_ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
		_hp_bar_fg.size.x = _bar_width * hp_ratio
	else:
		var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
		_hp_bar_fg.size.x = _bar_width * ratio
