extends CharacterBody2D

# 史莱姆 — 追踪玩家，碰撞造成伤害
# 数值通过 init() 从 enemies.json 注入

signal died(enemy: CharacterBody2D)

var hp: int = 10
var max_hp: int = 10
var speed: float = 80.0
var damage: int = 5
var xp_value: int = 1
var enemy_type: StringName = &"normal"
var wave_type: StringName = &"normal"
var _player: CharacterBody2D
var _hp_bar_fg: ColorRect
var _bar_width: float
var _damage_cooldown: float = 0.0
const BAR_HEIGHT: float = 2.0
const BAR_OFFSET: float = 6.0
const DAMAGE_COOLDOWN: float = 1.0

## 由 battle_manager 调用，传入 JSON 中该敌人的数据
func init(data: Dictionary) -> void:
	hp = int(data.get("hp", 10))
	max_hp = hp
	speed = float(data.get("speed", 80))
	damage = int(data.get("damage", 5))
	xp_value = int(data.get("xp_value", 1))
	enemy_type = StringName(data.get("type", "normal"))

var buff_container: Node

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

var _dead := false

func take_damage(amount: int) -> void:
	if _dead:
		return
	var remaining: int = buff_container.apply_shield_damage(amount)
	hp -= remaining
	_update_health_bar()
	if hp <= 0:
		_dead = true
		_spawn_xp_gem()
		died.emit(self)
		queue_free()

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

func _physics_process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
	var direction := (_player.global_position - global_position).normalized()
	var spd := speed
	if buff_container and buff_container.has_buff(&"slow"):
		spd *= 0.5
	velocity = direction * spd
	move_and_slide()
	if _damage_cooldown <= 0.0:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			if col.get_collider() == _player:
				_player.take_damage(damage)
				_damage_cooldown = DAMAGE_COOLDOWN
				break

## 血条：灰色背景 + 红色前景，宽度≈碰撞盒直径，位于碰撞盒上方
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
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_bar_fg.size.x = _bar_width * ratio
