extends Area2D

## 通用投射物：直线飞行，每帧直接物理查询检测命中

signal hit(enemy: Node2D, hit_pos: Vector2)

var speed: float = 200.0
var max_range: float = 400.0
var direction: Vector2 = Vector2.RIGHT
var _traveled: float = 0.0
var _hit_enemies: Array[Node2D] = []
var _shape: CircleShape2D

func _physics_process(delta: float) -> void:
	var velocity := direction * speed * delta
	global_position += velocity
	_traveled += velocity.length()
	if _traveled >= max_range:
		queue_free()
		return
	if not _shape:
		return
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = global_transform
	var results := space_state.intersect_shape(query)
	for result in results:
		var body: Node2D = result.get("collider")
		if body and body.is_in_group(&"enemy") and body not in _hit_enemies:
			_hit_enemies.append(body)
			hit.emit(body, body.global_position)
			queue_free()
			return
