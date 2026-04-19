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
		"deal_damage":
			print("[Attack] deal_damage value=%d target=%s" % [int(node.get("value", 0)), target])
			#if target and target.has_method("take_damage"):
			#	target.take_damage(int(node.get("value", 0)))
		"knockback":
			print("[Attack] knockback target=%s source=%s" % [target, source])
			#_knockback(target, source)
		"draw_cards":
			print("[Attack] draw_cards value=%d" % int(node.get("value", 0)))
			#var engine = context.get("card_engine")
			#if engine:
			#	engine.draw_cards(int(node.get("value", 0)))
		"gain_energy":
			print("[Attack] gain_energy value=%d" % int(node.get("value", 0)))
			#var engine = context.get("card_engine")
			#if engine:
			#	engine.energy += int(node.get("value", 0))
		"apply_debuff":
			print("[Attack] apply_debuff name=%s duration=%d" % [node.get("name", ""), int(node.get("duration", 1))])
		"channel_orb":
			print("[Attack] channel_orb orb_id=%s" % str(node.get("orb_id", "")))

## 解析位置常量为世界坐标
static func _resolve_position(pos_ref: String, source: Node2D, context: Dictionary) -> Vector2:
	match pos_ref:
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
	return source.global_position

## 根据 origin + target + offset 计算生成位置和方向
static func _resolve_spawn(node: Dictionary, source: Node2D, context: Dictionary) -> Dictionary:
	var origin_pos := _resolve_position(str(node.get("origin", "player")), source, context)
	var target_pos := _resolve_position(str(node.get("target", "enemy")), source, context)
	var offset: float = float(node.get("offset", 0.0))
	var direction := Vector2.RIGHT
	if target_pos.distance_to(origin_pos) > 0.001:
		direction = (target_pos - origin_pos).normalized()
	var spawn_pos := origin_pos + direction * offset
	return { "position": spawn_pos, "direction": direction }

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

static func _knockback(target: Node2D, source: Node2D) -> void:
	if not target or not source:
		return
	var dir := (target.global_position - source.global_position).normalized()
	target.global_position += dir * 20.0
