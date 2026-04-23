extends Area2D

## 回旋镖投射物：飞向目标方向到达最大距离后返回
## 去程和回程各对每个敌人触发一次 on_detect

signal boomerang_hit(enemy: Node2D)

var speed: float = 300.0
var max_length: float = 200.0
var total_time: float = 1.0
var direction: Vector2 = Vector2.RIGHT
var animation: String = ""

var _elapsed: float = 0.0
var _start_pos: Vector2
var _outward: bool = true
var _outward_hits: Array[Node2D] = []
var _return_hits: Array[Node2D] = []
var _shape: CircleShape2D


func _ready() -> void:
	_start_pos = global_position

	_shape = CircleShape2D.new()
	_shape.radius = 8.0
	var col := CollisionShape2D.new()
	col.shape = _shape
	add_child(col)

	if animation != "":
		var sprite := AnimatedSprite2D.new()
		var frames: SpriteFrames = load(animation)
		if frames:
			sprite.sprite_frames = frames
			sprite.play()
		add_child(sprite)

	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var half_time := total_time / 2.0

	if _elapsed >= total_time:
		queue_free()
		return

	if _elapsed < half_time:
		# 去程
		if not _outward:
			_outward = true
		var t := _elapsed / half_time
		global_position = _start_pos + direction * max_length * t
	else:
		# 回程
		if _outward:
			_outward = false
		var t := (_elapsed - half_time) / half_time
		global_position = _start_pos + direction * max_length * (1.0 - t)

	rotation = direction.angle() if _outward else (direction * -1.0).angle()

	# 碰撞检测
	if not _shape:
		return
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = global_transform
	var results := space_state.intersect_shape(query)
	var hit_list: Array[Node2D] = _outward_hits if _outward else _return_hits
	for result in results:
		var body: Node2D = result.get("collider")
		if body and body.is_in_group(&"enemy") and body not in hit_list:
			hit_list.append(body)
			boomerang_hit.emit(body)
