extends StaticBody2D

## 玻璃障碍：独立实体，仅与光束射击互动
## 被光束击中后反射四道玻璃光束（固定4伤害），随后销毁

const REFLECT_COUNT := 4
const BEAM_LENGTH := 200.0
const BEAM_WIDTH := 6.0
const BEAM_LIFETIME := 0.3
const BEAM_DAMAGE := 4
const BARRIER_RADIUS := 10.0

var lifetime: float = 30.0
var _elapsed: float = 0.0
var _hit: bool = false


func _ready() -> void:
	add_to_group(&"glass_barrier")
	top_level = true
	# 物理层4，不与玩家/敌人碰撞
	collision_layer = 8
	collision_mask = 0

	# 视觉：glass_barrier.tres 动画
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = load("res://sprite/glass_barrier.tres")
	sprite.play()
	add_child(sprite)

	# 碰撞
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BARRIER_RADIUS
	col.shape = circle
	add_child(col)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()


## 被光束击中时调用
func on_beam_hit(source: Node2D) -> void:
	if _hit:
		return
	_hit = true
	for i in REFLECT_COUNT:
		var angle := randf() * TAU
		_fire_glass_beam(source, angle)
	_hit = false


func _fire_glass_beam(source: Node2D, angle: float) -> void:
	var direction := Vector2(cos(angle), sin(angle))
	var end_pos := global_position + direction * BEAM_LENGTH
	var perp := Vector2(-direction.y, direction.x)
	var half_w := BEAM_WIDTH / 2.0

	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([
		perp * half_w,
		-perp * half_w,
		direction * BEAM_LENGTH - perp * half_w,
		direction * BEAM_LENGTH + perp * half_w,
	])

	var area := Area2D.new()
	var col := CollisionShape2D.new()
	col.shape = shape
	area.add_child(col)
	area.global_position = global_position
	get_tree().current_scene.add_child(area)

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = area.global_transform
	query.collision_mask = 0xFFFFFFFF
	var results := space_state.intersect_shape(query)
	var hit_enemies: Array[Node2D] = []
	for result in results:
		var body: Node2D = result.get("collider")
		if body and body.is_in_group(&"enemy") and body not in hit_enemies:
			hit_enemies.append(body)
			body.take_damage(BEAM_DAMAGE)
			Attack._show_damage_number(body, BEAM_DAMAGE)


	var p0 := global_position + perp * half_w
	var p1 := global_position - perp * half_w
	var p2 := end_pos - perp * half_w
	var p3 := end_pos + perp * half_w
	var poly := Polygon2D.new()
	poly.color = Color(0.7, 0.9, 1.0, 0.8)
	poly.polygon = PackedVector2Array([p0, p1, p2, p3])
	get_tree().current_scene.add_child(poly)

	var tween := get_tree().create_tween()
	tween.tween_property(poly, "modulate:a", 0.0, BEAM_LIFETIME)
	tween.tween_callback(poly.queue_free)
	tween.tween_callback(area.queue_free)
