extends Node2D

## 抛物线墨汁投射物
## 3轴→2D投影: ScreenX = X, ScreenY = Y - Z, Z = Vz*t - 0.5*g*t²

var damage: int = 8
var hit_radius: float = 20.0
var _time: float = 0.0
var _total_time: float = 1.0
var _vx: float = 0.0
var _vy: float = 0.0
var _vz: float = 0.0
var _gravity: float = 0.0
var _start_x: float = 0.0
var _start_y: float = 0.0

func setup(start_pos: Vector2, target_pos: Vector2, peak_height: float, flight_time: float, dmg: int, radius: float) -> void:
	global_position = start_pos
	damage = dmg
	hit_radius = radius
	_total_time = flight_time
	_time = 0.0
	_start_x = start_pos.x
	_start_y = start_pos.y
	var dx := target_pos.x - start_pos.x
	var dy := target_pos.y - start_pos.y
	_vx = dx / flight_time
	_vy = dy / flight_time
	_gravity = 8.0 * peak_height / (flight_time * flight_time)
	_vz = 4.0 * peak_height / flight_time

func _ready() -> void:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for j in 10:
		var a := TAU * float(j) / 10.0
		pts.append(Vector2(cos(a), sin(a)) * 6.0)
	poly.polygon = pts
	poly.color = Color(0.1, 0.1, 0.1)
	add_child(poly)

func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= _total_time:
		_land()
		queue_free()
		return
	var sx := _start_x + _vx * _time
	var sy := _start_y + _vy * _time
	var z := _vz * _time - 0.5 * _gravity * _time * _time
	global_position = Vector2(sx, sy - z)

func _land() -> void:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = hit_radius
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	var results := space_state.intersect_shape(query)
	for result in results:
		var body: Node2D = result.get("collider")
		if body and body.is_in_group(&"player") and body.has_method("take_damage"):
			body.take_damage(damage)
	# 落地水花
	var splash := Node2D.new()
	var pts := PackedVector2Array()
	for j in 12:
		var a := TAU * float(j) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * hit_radius)
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = Color(0.1, 0.1, 0.1, 0.5)
	splash.add_child(poly)
	splash.global_position = global_position
	get_tree().current_scene.add_child(splash)
	var tween := splash.create_tween()
	tween.tween_property(poly, "modulate:a", 0.0, 0.4)
	tween.tween_callback(splash.queue_free)
