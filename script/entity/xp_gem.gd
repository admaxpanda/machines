extends Area2D

## 经验宝石 — 靠近玩家时被吸引，拾取后增加经验

var xp_value: int = 1
var _player: CharacterBody2D
var _attracted: bool = false
var _speed: float = 150.0

const ATTRACT_RANGE: float = 60.0
const PICKUP_RANGE: float = 8.0
const ACCEL: float = 400.0

func _ready() -> void:
	add_to_group(&"gem")
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	col.shape = circle
	add_child(col)

	var visual := ColorRect.new()
	visual.color = Color(0.2, 0.85, 0.3)
	visual.size = Vector2(4, 4)
	visual.position = Vector2(-2, -2)
	add_child(visual)

	var players := get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		_player = players[0] as CharacterBody2D

func _physics_process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var dist := global_position.distance_to(_player.global_position)
	if _attracted or dist < ATTRACT_RANGE:
		_attracted = true
		_speed += ACCEL * delta
		var dir := (_player.global_position - global_position).normalized()
		global_position += dir * _speed * delta
	if dist < PICKUP_RANGE:
		_player.add_xp(xp_value)
		queue_free()

func force_attract() -> void:
	_attracted = true
