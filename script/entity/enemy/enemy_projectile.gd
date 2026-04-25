extends Area2D

## 敌人投射物：直线飞行，命中玩家造成伤害

var speed: float = 250.0
var max_range: float = 400.0
var direction: Vector2 = Vector2.RIGHT
var damage: int = 6
var _traveled: float = 0.0
var _visual_golden: bool = false

func _ready() -> void:
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	col.shape = circle
	add_child(col)
	rotation = direction.angle()
	# 视觉
	if _visual_golden:
		var rect := ColorRect.new()
		rect.size = Vector2(6, 6)
		rect.position = Vector2(-3, -3)
		rect.color = Color(1.0, 0.85, 0.2)
		add_child(rect)
	else:
		var poly := Polygon2D.new()
		var pts := PackedVector2Array()
		for j in 8:
			var a := TAU * float(j) / 8.0
			pts.append(Vector2(cos(a), sin(a)) * 4.0)
		poly.polygon = pts
		poly.color = Color(1.0, 0.6, 0.2)
		add_child(poly)

func _physics_process(delta: float) -> void:
	var movement := direction * speed * delta
	global_position += movement
	_traveled += movement.length()
	if _traveled >= max_range:
		queue_free()
		return
	# 检测碰撞玩家
	for body in get_overlapping_bodies():
		if body.is_in_group(&"player") and body.has_method("take_damage"):
			body.take_damage(damage)
			queue_free()
			return
