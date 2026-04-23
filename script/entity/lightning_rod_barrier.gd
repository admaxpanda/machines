extends StaticBody2D

## 引雷针障碍：检测范围内的雷电效果并反射伤害
## 不会被自身触发的电击再次触发

const DETECTION_RADIUS := 150.0
const BARRIER_RADIUS := 10.0
const LIFETIME := 30.0

var _elapsed: float = 0.0
var _triggered: bool = false


func _ready() -> void:
	add_to_group(&"lightning_rod_barrier")
	top_level = true
	collision_layer = 8
	collision_mask = 0

	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = load("res://sprite/lightning_rod.tres")
	sprite.play()
	add_child(sprite)

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BARRIER_RADIUS
	col.shape = circle
	add_child(col)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()


## 被雷电效果触发时调用
func on_lightning_hit(damage: int) -> void:
	if _triggered:
		return
	_triggered = true

	var space_state := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = DETECTION_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = global_transform
	var results := space_state.intersect_shape(query)

	var enemies: Array[Node2D] = []
	for result in results:
		var body: Node2D = result.get("collider")
		if body and body.is_in_group(&"enemy"):
			enemies.append(body)

	if not enemies.is_empty():
		var target: Node2D = enemies[randi() % enemies.size()]
		target.take_damage(damage)
		Attack._show_damage_number(target, damage)

		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = load("res://sprite/lightning_attack.tres")
		anim.global_position = target.global_position
		anim.play()
		get_tree().current_scene.add_child(anim)

		var tween := get_tree().create_tween()
		tween.tween_property(anim, "modulate:a", 0.0, 0.3)
		tween.tween_callback(anim.queue_free)

	_triggered = false
