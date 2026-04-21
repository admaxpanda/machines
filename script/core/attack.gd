class_name Attack
extends RefCounted

## 攻击系统：执行嵌套效果链，代码生成节点

## 从 chain 数据开始执行攻击
static func execute(chain: Dictionary, source: Node2D, context: Dictionary) -> void:
	_execute_node(chain, source, context.get("target_enemy"), context)

## 递归执行链中的一个节点
static func _execute_node(node: Dictionary, source: Node2D, target: Node2D, context: Dictionary) -> void:
	match node.get("type", ""):
		"aoe_detect":
			_aoe_detect(node, source, context)
		"spawn_projectile":
			_spawn_projectile(node, source, context)
		"beam_detect":
			_beam_detect(node, source, context)
		"multi_release":
			_multi_release(node, source, context)
		"deal_damage":
			if target and target.has_method("take_damage"):
				target.take_damage(int(node.get("value", 0)))
		"knockback":
			print("[Attack] knockback target=%s source=%s" % [target, source])
		"draw_cards":
			print("[Attack] draw_cards value=%d" % int(node.get("value", 0)))
		"gain_energy":
			print("[Attack] gain_energy value=%d" % int(node.get("value", 0)))
		"apply_debuff":
			if target:
				var stacks: int = int(node.get("value", 1))
				var duration: int = int(node.get("duration", 1))
				for child in target.get_children():
					if child.is_in_group(&"buff_container"):
						child.add_buff(StringName(node.get("name", "")), stacks, duration)
						break
		"channel_orb":
			var orb_id: StringName = StringName(node.get("orb_id", ""))
			var player: Node2D = context.get("source")
			if player:
				var managers := player.get_tree().get_nodes_in_group(&"orb_manager")
				if managers.size() > 0:
					managers[0].channel_orb(orb_id)

## --- 位置解析 ---

static func _resolve_position(pos_ref: Variant, source: Node2D, context: Dictionary) -> Vector2:
	# Dictionary: {"random": [1,2,3,4]} 随机象限方向
	if pos_ref is Dictionary:
		var quadrants: Array = pos_ref.get("random", [])
		if not quadrants.is_empty():
			var base: Vector2 = context.get("parent_position", source.global_position)
			return _random_quadrant_pos(base, quadrants)
	# 字符串目标
	var ref: String = str(pos_ref)
	match ref:
		"player":
			var player: Node2D = context.get("source")
			return player.global_position if player else Vector2.ZERO
		"enemy":
			var pos = context.get("target_position")
			return pos if pos else source.global_position
		"parent":
			var pos = context.get("parent_position")
			if pos:
				return pos
			return source.global_position
		"random_enemy":
			var enemies := source.get_tree().get_nodes_in_group(&"enemy")
			if enemies.is_empty():
				return source.global_position
			return (enemies[randi() % enemies.size()] as Node2D).global_position
		"lowest_hp_enemy":
			var enemies := source.get_tree().get_nodes_in_group(&"enemy")
			if enemies.is_empty():
				return source.global_position
			var lowest: Node2D = null
			var lowest_hp: int = 999999
			for e in enemies:
				if "hp" in e and e.hp < lowest_hp:
					lowest_hp = e.hp
					lowest = e
			return lowest.global_position if lowest else source.global_position
	return source.global_position

## 根据 quadrants 数组生成随机象限方向的目标点
static func _random_quadrant_pos(base_pos: Vector2, quadrants: Array) -> Vector2:
	var idx := randi() % quadrants.size()
	var quadrant: int = int(quadrants[idx])
	var base_angle: float = float(quadrant - 1) * PI * 0.5
	var angle := base_angle + randf() * PI * 0.5
	return base_pos + Vector2(sin(angle), cos(angle)) * 10000.0

## 根据 origin + target + offset 计算生成位置和方向
static func _resolve_spawn(node: Dictionary, source: Node2D, context: Dictionary) -> Dictionary:
	var origin_pos := _resolve_position(node.get("origin", "player"), source, context)
	var target_pos := _resolve_position(node.get("target", "enemy"), source, context)
	var offset: float = float(node.get("offset", 0.0))
	var direction := Vector2.RIGHT
	if target_pos.distance_to(origin_pos) > 0.001:
		direction = (target_pos - origin_pos).normalized()
	var spawn_pos := origin_pos + direction * offset
	return { "position": spawn_pos, "direction": direction }

## --- 触发器 ---

## 多次释放：按间隔依次执行 chains 数组中的链，不足则循环
static func _multi_release(node: Dictionary, source: Node2D, context: Dictionary) -> void:
	var count: int = int(node.get("count", 1))
	var interval: float = float(node.get("interval", 0.0))
	var chains: Array = node.get("chains", [])
	if chains.is_empty():
		return
	for i in count:
		var chain: Dictionary = chains[i % chains.size()].duplicate(true)
		var delay := interval * float(i)
		if delay <= 0.0:
			_execute_node(chain, source, null, context)
		else:
			source.get_tree().create_timer(delay).timeout.connect(
				func() -> void: _execute_node(chain, source, null, context)
			)

## 范围检测触发器：circle / rect
static func _aoe_detect(node: Dictionary, source: Node2D, context: Dictionary) -> void:
	if not source:
		return
	var spawn := _resolve_spawn(node, source, context)
	var spawn_pos: Vector2 = spawn["position"]
	var direction: Vector2 = spawn["direction"]
	var shape_type: String = str(node.get("shape", "circle"))
	var lifetime: float = float(node.get("lifetime", 0.2))
	var on_detect: Array = node.get("on_detect", [])

	var area := Area2D.new()
	var col := CollisionShape2D.new()

	match shape_type:
		"rect":
			var rect_shape := RectangleShape2D.new()
			rect_shape.size = Vector2(float(node.get("width", 60.0)), float(node.get("height", 20.0)))
			col.shape = rect_shape
		_:
			var circle := CircleShape2D.new()
			circle.radius = float(node.get("radius", 30.0))
			col.shape = circle

	area.rotation = direction.angle()
	area.add_child(col)

	var anim_path: String = str(node.get("animation", ""))
	if anim_path != "":
		var sprite := AnimatedSprite2D.new()
		var frames: SpriteFrames = load(anim_path)
		if frames:
			sprite.sprite_frames = frames
			sprite.play()
		area.add_child(sprite)

	area.global_position = spawn_pos
	source.get_tree().current_scene.add_child(area)

	var space_state := source.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = col.shape
	query.transform = area.global_transform
	var results := space_state.intersect_shape(query)
	var hit_enemies: Array[Node2D] = []
	for result in results:
		var body: Node2D = result.get("collider")
		if body and body.is_in_group(&"enemy") and body not in hit_enemies:
			hit_enemies.append(body)
			for effect in on_detect:
				_execute_node(effect, source, body, context)

	source.get_tree().create_timer(lifetime).timeout.connect(area.queue_free)

## 光束触发器：梯形区域碰撞检测
static func _beam_detect(node: Dictionary, source: Node2D, context: Dictionary) -> void:
	if not source:
		return
	var origin_pos := _resolve_position(node.get("origin", "player"), source, context)
	var target_pos := _resolve_position(node.get("target", "enemy"), source, context)
	var beam_length: float = float(node.get("length", 100.0))
	var width: float = float(node.get("width", 10.0))
	var tail_coeff: float = float(node.get("tail_width_coeff", 1.0))
	var lifetime: float = float(node.get("lifetime", 0.3))
	var min_opacity: float = float(node.get("min_opacity", 0.0))
	var on_detect: Array = node.get("on_detect", [])

	var direction := Vector2.RIGHT
	if target_pos.distance_to(origin_pos) > 0.001:
		direction = (target_pos - origin_pos).normalized()
	var end_pos := origin_pos + direction * beam_length

	var perp := Vector2(-direction.y, direction.x)
	var half_w := width / 2.0
	var half_tail := width * tail_coeff / 2.0

	var p0 := origin_pos + perp * half_w
	var p1 := origin_pos - perp * half_w
	var p2 := end_pos - perp * half_tail
	var p3 := end_pos + perp * half_tail

	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([p0 - origin_pos, p1 - origin_pos, p2 - origin_pos, p3 - origin_pos])

	var area := Area2D.new()
	var col := CollisionShape2D.new()
	col.shape = shape
	area.add_child(col)
	area.global_position = origin_pos
	source.get_tree().current_scene.add_child(area)

	var space_state := source.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = area.global_transform
	var results := space_state.intersect_shape(query)
	var hit_enemies: Array[Node2D] = []
	for result in results:
		var body: Node2D = result.get("collider")
		if body and body.is_in_group(&"enemy") and body not in hit_enemies:
			hit_enemies.append(body)
			for effect in on_detect:
				_execute_node(effect, source, body, context)

	var poly := Polygon2D.new()
	poly.color = Color.WHITE
	poly.polygon = PackedVector2Array([p0, p1, p2, p3])
	poly.global_position = Vector2.ZERO
	source.get_tree().current_scene.add_child(poly)

	var tween := source.get_tree().create_tween()
	tween.tween_property(poly, "modulate:a", min_opacity, lifetime)
	tween.tween_callback(poly.queue_free)
	tween.tween_callback(area.queue_free)

## 投射物触发器
static func _spawn_projectile(node: Dictionary, source: Node2D, context: Dictionary) -> void:
	if not source:
		return
	var spawn := _resolve_spawn(node, source, context)
	var spawn_pos: Vector2 = spawn["position"]
	var direction: Vector2 = spawn["direction"]
	var speed: float = float(node.get("speed", 200.0))
	var max_range: float = float(node.get("max_range", 200.0))
	var on_hit: Array = node.get("on_hit", [])

	var area := Area2D.new()
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = float(node.get("radius", 5.0))
	col.shape = circle
	area.add_child(col)
	area.rotation = direction.angle()

	var anim_path: String = str(node.get("animation", ""))
	if anim_path != "":
		var sprite := AnimatedSprite2D.new()
		var frames: SpriteFrames = load(anim_path)
		if frames:
			sprite.sprite_frames = frames
			sprite.play()
		area.add_child(sprite)

	var script: GDScript = load("res://script/entity/delivery_projectile.gd")
	area.set_script(script)
	area.speed = speed
	area.max_range = max_range
	area.direction = direction
	area._shape = circle

	for effect in on_hit:
		area.hit.connect(func(hit_target: Node2D, hit_pos: Vector2):
			var sub_context := context.duplicate()
			sub_context["target_enemy"] = hit_target
			sub_context["parent_position"] = hit_pos
			_execute_node(effect, source, hit_target, sub_context)
		)

	area.global_position = spawn_pos
	source.get_tree().current_scene.add_child(area)
