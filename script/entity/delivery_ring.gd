extends Area2D

## 扩展圆环：从 min_radius 扩展到 max_radius，可从 origin 移向 target
## 对每个碰撞到的敌人仅触发一次

signal ring_hit(enemy: Node2D)

var min_radius: float = 0.0
var max_radius: float = 100.0
var duration: float = 0.5
var line_width: float = 3.0
var ring_color: Color = Color.WHITE
var target_position: Vector2 = Vector2.ZERO

var _elapsed: float = 0.0
var _start_pos: Vector2
var _circle: CircleShape2D
var _ring_visual: Line2D
var _hit_enemies: Array[Node2D] = []


func _ready() -> void:
	_start_pos = global_position
	_circle = CircleShape2D.new()
	_circle.radius = min_radius
	var col := CollisionShape2D.new()
	col.shape = _circle
	add_child(col)

	_ring_visual = Line2D.new()
	_ring_visual.width = line_width
	_ring_visual.default_color = ring_color
	add_child(_ring_visual)
	_draw_ring()

	get_tree().create_timer(duration).timeout.connect(queue_free)


func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / duration, 0.0, 1.0)
	_circle.radius = lerpf(min_radius, max_radius, t)
	global_position = _start_pos.lerp(target_position, t)
	_draw_ring()

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _circle
	query.transform = global_transform
	var results := space_state.intersect_shape(query)
	for result in results:
		var body: Node2D = result.get("collider")
		if body and body.is_in_group(&"enemy") and body not in _hit_enemies:
			_hit_enemies.append(body)
			ring_hit.emit(body)


func _draw_ring() -> void:
	var points := PackedVector2Array()
	var segments := 36
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * _circle.radius)
	points.append(points[0])
	_ring_visual.points = points
