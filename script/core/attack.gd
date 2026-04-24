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
		"piercing_projectile":
			_piercing_projectile(node, source, context)
		"boomerang":
			_boomerang(node, source, context)
		"beam_detect":
			_beam_detect(node, source, context)
		"ring_detect":
			_ring_detect(node, source, context)
		"multi_release":
			_multi_release(node, source, context)
		"multi_release_claw":
			_multi_release_claw(node, source, context)
		"multi_release_drill":
			_multi_release_drill(node, source, context)
		"fall":
			_fall(node, source, context)
		"deal_damage":
			var dd_target: Node2D = target
			if node.get("self_target", false):
				dd_target = context.get("source") as Node2D
			if dd_target and dd_target.has_method("take_damage"):
				var dmg: int = int(node.get("value", 0))
				dd_target.take_damage(dmg)
				_show_damage_number(dd_target, dmg)
		"knockback":
			print("[Attack] knockback target=%s source=%s" % [target, source])
		"draw_attack_cards":
			var _da_engines := source.get_tree().get_nodes_in_group(&"card_engine")
			for _da_eng in _da_engines:
				_da_eng.draw_cards(int(node.get("value", 1)))
				break
		"draw_skill_cards":
			var _ds_engines := source.get_tree().get_nodes_in_group(&"skill_card_engine")
			for _ds_eng in _ds_engines:
				_ds_eng.draw_cards(int(node.get("value", 1)))
				break
		"gain_attack_energy":
			var _engines := source.get_tree().get_nodes_in_group(&"card_engine")
			for _eng in _engines:
				_eng.energy += int(node.get("value", 0))
				_eng.energy_changed.emit(_eng.energy)
				break
		"gain_skill_energy":
			var _s_engines := source.get_tree().get_nodes_in_group(&"skill_card_engine")
			for _s_eng in _s_engines:
				_s_eng.energy += int(node.get("value", 0))
				_s_eng.energy_changed.emit(_s_eng.energy)
				break
		"play_attack_from_draw":
			var _pa_engines := source.get_tree().get_nodes_in_group(&"card_engine")
			for _pa_eng in _pa_engines:
				if _pa_eng.draw_pile.is_empty():
					print("[Uproar] 抽牌堆为空，无法打出")
					break
				var _pa_card: CardData = _pa_eng.draw_pile.pop_back()
				print("[Uproar] 从抽牌堆打出: %s" % _pa_card.id)
				_show_card_preview(source, _pa_card)
				var _pa_ctx := {"source": source, "card_engine": _pa_eng}
				CardResolver.play(_pa_card, _pa_ctx)
				if _pa_card.exhaust:
					_pa_eng.exhaust_pile.append(_pa_card)
				else:
					_pa_eng.discard_pile.append(_pa_card)
				break
		"apply_buff":
			var buff_target: Node2D = target
			if node.get("self_target", false):
				buff_target = context.get("source") as Node2D
			if buff_target:
				var stacks: int = int(node.get("value", 1))
				var duration: int = int(node.get("duration", 1))
				for child in buff_target.get_children():
					if child.is_in_group(&"buff_container"):
						child.add_buff(StringName(node.get("name", "")), stacks, duration)
						break
		"evoke_all_orbs":
			var eao_player: Node2D = context.get("source") as Node2D
			if eao_player:
				var eao_managers := eao_player.get_tree().get_nodes_in_group(&"orb_manager")
				if eao_managers.size() > 0:
					var eao_mgr = eao_managers[0]
					while not eao_mgr.slots.is_empty():
						eao_mgr.evoke_first()
		"spawn_glass_barrier":
			var sgb_pos := _resolve_position(node.get("origin", "player"), source, context)
			var sgb_barrier := StaticBody2D.new()
			var sgb_script: GDScript = load("res://script/entity/glass_barrier.gd")
			sgb_barrier.set_script(sgb_script)
			sgb_barrier.global_position = sgb_pos
			source.get_tree().current_scene.add_child(sgb_barrier)
		"spawn_lightning_rod_barrier":
			var slrb_pos := _resolve_position(node.get("origin", "player"), source, context)
			var slrb_barrier := StaticBody2D.new()
			var slrb_script: GDScript = load("res://script/entity/lightning_rod_barrier.gd")
			slrb_barrier.set_script(slrb_script)
			slrb_barrier.global_position = slrb_pos
			source.get_tree().current_scene.add_child(slrb_barrier)
		"spawn_moving_barrier":
			_spawn_moving_barrier(node, source, context)
		"evoke_last_orb":
			var evk_count: int = int(node.get("count", 1))
			var evk_player: Node2D = context.get("source") as Node2D
			if evk_player:
				var evk_managers := evk_player.get_tree().get_nodes_in_group(&"orb_manager")
				if evk_managers.size() > 0:
					for evk_i in evk_count:
						evk_managers[0].evoke_last()
		"channel_orb":
			var orb_id: StringName = StringName(node.get("orb_id", ""))
			var player: Node2D = context.get("source")
			if player:
				var managers := player.get_tree().get_nodes_in_group(&"orb_manager")
				if managers.size() > 0:
					managers[0].channel_orb(orb_id)
			if orb_id == &"lightning" and "lightning_channeled" in player:
				player.lightning_channeled += 1
		"show_golden_number":
			var sgn_val := _resolve_dynamic(node.get("value", 0), source, context)
			var sgn_label := Label.new()
			sgn_label.text = str(sgn_val)
			sgn_label.add_theme_font_size_override("font_size", 24)
			sgn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sgn_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
			sgn_label.add_theme_color_override("font_outline_color", Color.BLACK)
			sgn_label.add_theme_constant_override("outline_size", 3)
			sgn_label.global_position = source.global_position + Vector2(randf_range(-8, 8), -24)
			sgn_label.z_index = 100
			sgn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			source.get_tree().current_scene.add_child(sgn_label)
			var sgn_tween := source.get_tree().create_tween()
			sgn_tween.set_parallel(true)
			sgn_tween.tween_property(sgn_label, "position:y", sgn_label.position.y - 40, 1.0)
			sgn_tween.tween_property(sgn_label, "modulate:a", 0.0, 1.0)
			sgn_tween.chain().tween_callback(sgn_label.queue_free)
		"trigger_dark_passives":
			var tdp_player: Node2D = context.get("source") as Node2D
			if tdp_player:
				var tdp_managers := tdp_player.get_tree().get_nodes_in_group(&"orb_manager")
				if tdp_managers.size() > 0:
					var tdp_mgr = tdp_managers[0]
					for tdp_i in tdp_mgr.slots.size():
						if tdp_i < tdp_mgr.slots.size() and tdp_mgr.slots[tdp_i].data.id == &"dark":
							var tdp_pos: Vector2 = tdp_mgr._visuals[tdp_i].global_position if tdp_i < tdp_mgr._visuals.size() else Vector2.ZERO
							tdp_mgr._play_passive_visual(tdp_i)
							tdp_mgr._trigger_passive(tdp_mgr.slots[tdp_i], tdp_pos)
					tdp_mgr._refresh_labels()
		"extra_ability_reward":
			var ear_player: Node2D = context.get("source") as Node2D
			if ear_player and "extra_ability_rewards" in ear_player:
				ear_player.extra_ability_rewards += 1
		"signal_boost":
			var sb_player: Node2D = context.get("source") as Node2D
			if sb_player and "signal_boost_stacks" in sb_player:
				sb_player.signal_boost_stacks += 1
		"double_skill_energy":
			var dse_player: Node2D = context.get("source") as Node2D
			if dse_player:
				var dse_engines := dse_player.get_tree().get_nodes_in_group(&"skill_card_engine")
				if dse_engines.size() > 0:
					dse_engines[0].energy *= 2
					dse_engines[0].energy_changed.emit(dse_engines[0].energy)
		"genetic_shield":
			var gs_player: Node2D = context.get("source") as Node2D
			if gs_player and "genetic_algorithm_uses" in gs_player:
				var gs_amount: int = 1 + 4 * gs_player.genetic_algorithm_uses
				gs_player.genetic_algorithm_uses += 1
				for gs_child in gs_player.get_children():
					if gs_child.is_in_group(&"buff_container"):
						gs_child.add_buff(&"shield", gs_amount, -1)
						break
		"add_card_to_draw_pile":
			var acdp_id: StringName = StringName(node.get("card_id", ""))
			var acdp_pool: String = str(node.get("pool", "status"))
			var acdp_engine = context.get("card_engine")
			var acdp_engine_str: String = str(node.get("engine", ""))
			if acdp_engine_str == "attack":
				var acdp_engines := source.get_tree().get_nodes_in_group(&"card_engine")
				if acdp_engines.size() > 0:
					acdp_engine = acdp_engines[0]
			elif acdp_engine_str == "skill":
				var acdp_engines := source.get_tree().get_nodes_in_group(&"skill_card_engine")
				if acdp_engines.size() > 0:
					acdp_engine = acdp_engines[0]
			if acdp_engine and acdp_id != &"":
				var acdp_db: Dictionary
				match acdp_pool:
					"status": acdp_db = CardLoader.load_status_cards()
					"skill": acdp_db = CardLoader.load_skill_cards()
					"attack": acdp_db = CardLoader.load_attack_cards()
					_: acdp_db = {}
				if acdp_db.has(acdp_id):
					var acdp_card: CardData = acdp_db[acdp_id]
					acdp_card.temporary = true
					var acdp_dest: String = str(node.get("destination", "draw"))
					if acdp_dest == "discard":
						acdp_engine.discard_pile.append(acdp_card)
					else:
						acdp_engine.draw_pile.append(acdp_card)
		"focus_per_unique_orb":
			var fpuo_per: int = int(node.get("value", 1))
			var fpuo_duration: int = int(node.get("duration", 1))
			var fpuo_player: Node2D = context.get("source") as Node2D
			if fpuo_player:
				var fpuo_managers := fpuo_player.get_tree().get_nodes_in_group(&"orb_manager")
				if fpuo_managers.size() > 0:
					var fpuo_mgr = fpuo_managers[0]
					var fpuo_unique: Dictionary = {}
					for fpuo_slot in fpuo_mgr.slots:
						fpuo_unique[fpuo_slot.data.id] = true
					var fpuo_amount: int = fpuo_unique.size() * fpuo_per
					if fpuo_amount > 0:
						for fpuo_child in fpuo_player.get_children():
							if fpuo_child.is_in_group(&"buff_container"):
								fpuo_child.add_buff(&"focus", fpuo_amount, fpuo_duration)
								break
		"grant_invincible":
			var gi_player: Node2D = context.get("source") as Node2D
			if gi_player and gi_player.has_method("start_invincibility"):
				gi_player.start_invincibility(float(node.get("duration", 1.0)))
		"dash":
			var d_player: Node2D = context.get("source") as Node2D
			if d_player and d_player.has_method("perform_dash"):
				d_player.perform_dash(float(node.get("distance", 100.0)), float(node.get("duration", 0.1)))

## Lightning rod barrier trigger check
static func _check_lightning_rods(source: Node2D, spawn_pos: Vector2, on_detect: Array) -> void:
	var lr_damage := 0
	for lr_fx in on_detect:
		if lr_fx.get("type") == "deal_damage":
			lr_damage = int(lr_fx.get("value", 0))
			break
	if lr_damage <= 0:
		return
	var lr_rods := source.get_tree().get_nodes_in_group(&"lightning_rod_barrier")
	for lr_rod in lr_rods:
		if is_instance_valid(lr_rod) and lr_rod.global_position.distance_to(spawn_pos) <= 150.0:
			lr_rod.on_lightning_hit(lr_damage)

## 显示被 play_attack_from_draw 打出的牌预览
static func _show_card_preview(source: Node2D, card: CardData) -> void:
	if card.cover == "":
		return
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	source.get_tree().current_scene.add_child(canvas)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var _cw := 120.0
	var _ch := 90.0
	var vp := source.get_viewport().get_visible_rect().size
	var _bar_half := (5.0 * _cw + 4.0 * 4.0) / 2.0
	var _x := vp.x - _cw - 4.0 - _cw
	var _y := vp.y / 2.0 - _ch / 2.0
	print("[Preview] pos=(%.0f, %.0f) cover=%s" % [_x, _y, card.cover])
	var tex := TextureRect.new()
	tex.texture = load(card.cover)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.size = Vector2(_cw, _ch)
	tex.position = Vector2(_x, _y)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tex)
	source.get_tree().create_timer(0.5, false).timeout.connect(func() -> void: canvas.queue_free())

## --- 伤害飘字 ---

static func _show_damage_number(target: Node2D, dmg: int) -> void:
	var label := Label.new()
	label.text = str(dmg)
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.global_position = target.global_position + Vector2(randf_range(-8, 8), -12)
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.get_tree().current_scene.add_child(label)
	var tween := target.get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 30, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)

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
		"moving_barrier":
			var mb = context.get("moving_barrier")
			if mb and is_instance_valid(mb):
				return mb.global_position
			return source.global_position
		"mouse":
			return source.get_global_mouse_position()
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

## 解析动态变量引用：{"var": "xxx"} 或 {"var": "xxx", "add": N}
static func _resolve_dynamic(val: Variant, source: Node2D, context: Dictionary) -> int:
	if val is Dictionary and val.has("var"):
		var var_name: String = val["var"]
		var player: Node2D = context.get("source") as Node2D
		var result: int = 0
		match var_name:
			"drill_count":
				if player and "drill_count" in player:
					result = int(player.drill_count)
			"orb_count":
				if player:
					var managers := player.get_tree().get_nodes_in_group(&"orb_manager")
					if managers.size() > 0 and "slots" in managers[0]:
						result = int(managers[0].slots.size())
			_:
				if player and var_name in player:
					result = int(player.get(var_name))
		if val.has("add"):
			result += int(val["add"])
		return result
	return int(val)

## --- 触发器 ---

## 多次释放：按间隔依次执行 chains 数组中的链，不足则循环
static func _multi_release(node: Dictionary, source: Node2D, context: Dictionary) -> void:
	var count: int = _resolve_dynamic(node.get("count", 1), source, context)
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
			source.get_tree().create_timer(delay, false).timeout.connect(
				func() -> void: _execute_node(chain, source, null, context)
			)

## 爪击多次释放：按 claw_times 次数执行，未命中则中断
static func _multi_release_claw(node: Dictionary, source: Node2D, context: Dictionary) -> void:
	var player: Node2D = context.get("source") as Node2D
	if not player or not "claw_times" in player:
		return
	var count: int = player.claw_times
	var interval: float = float(node.get("interval", 0.1))
	var chains: Array = node.get("chains", [])
	if chains.is_empty():
		return
	var state := { "total_hits": 0, "interrupted": false }
	for i in count:
		var chain: Dictionary = chains[i % chains.size()].duplicate(true)
		var delay := interval * float(i)
		if delay <= 0.0:
			if state.interrupted:
				break
			_claw_step(chain, source, context, state)
		else:
			source.get_tree().create_timer(delay, false).timeout.connect(
				func() -> void:
					if state.interrupted or not is_instance_valid(source):
						return
					_claw_step(chain, source, context, state)
			)
	var total_time := interval * float(max(count - 1, 0)) + 0.05
	source.get_tree().create_timer(total_time, false).timeout.connect(
		func() -> void:
			if state.total_hits > 0 and is_instance_valid(player):
				player.claw_times += 1
	)

static func _claw_step(chain: Dictionary, source: Node2D, context: Dictionary, state: Dictionary) -> void:
	var hit_report: Array = []
	var claw_context := context.duplicate()
	claw_context["hit_report"] = hit_report
	_execute_node(chain, source, null, claw_context)
	var hits: int = hit_report[0] if hit_report.size() > 0 else 0
	if hits == 0:
		state.interrupted = true
	else:
		state.total_hits += hits



## 螺旋钻击多次释放：按上回合攻击牌次数执行，伤害为次数+4
static func _multi_release_drill(node: Dictionary, source: Node2D, context: Dictionary) -> void:
	var count: int = _resolve_dynamic(node.get("count", 0), source, context)
	if count <= 0:
		return
	var damage_per_hit: int = _resolve_dynamic(node.get("damage_formula", 0), source, context)
	var interval: float = float(node.get("interval", 0.05))
	var chains: Array = node.get("chains", [])
	if chains.is_empty():
		return
	for i in count:
		var chain: Dictionary = chains[i % chains.size()].duplicate(true)
		_inject_drill_damage(chain, damage_per_hit)
		var delay := interval * float(i)
		if delay <= 0.0:
			_execute_node(chain, source, null, context)
		else:
			source.get_tree().create_timer(delay, false).timeout.connect(
				func() -> void: _execute_node(chain, source, null, context)
			)

static func _inject_drill_damage(node: Dictionary, dmg: int) -> void:
	if node.get("type", "") == "deal_damage":
		node["value"] = dmg
	for key in node:
		var val = node[key]
		if val is Dictionary:
			_inject_drill_damage(val, dmg)
		elif val is Array:
			for item in val:
				if item is Dictionary:
					_inject_drill_damage(item, dmg)

## 范围检测触发器：circle / rect
static func _aoe_detect(node: Dictionary, source: Node2D, context: Dictionary) -> void:
	if not source:
		return
	var spawn := _resolve_spawn(node, source, context)
	var spawn_pos: Vector2 = spawn["position"]
	var direction: Vector2 = spawn["direction"]
	var anchor_offset: float = float(node.get("anchor_offset", 0.0))
	if anchor_offset != 0.0:
		spawn_pos += direction * anchor_offset
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

	if node.has("rotation"):
		area.rotation = float(node.get("rotation"))
	else:
		area.rotation = direction.angle()
	area.add_child(col)

	var anim_path: String = str(node.get("animation", ""))
	if anim_path != "":
		var sprite := AnimatedSprite2D.new()
		var frames: SpriteFrames = load(anim_path)
		if frames:
			sprite.sprite_frames = frames
			var anim_name: String = str(node.get("animation_name", ""))
			if anim_name != "" and frames.has_animation(StringName(anim_name)):
				sprite.play(StringName(anim_name))
			else:
				sprite.play()
		area.add_child(sprite)
	else:
		var aoe_radius: float = float(node.get("radius", 30.0))
		var circle_pts := PackedVector2Array()
		for j in 20:
			var a := TAU * float(j) / 20.0
			circle_pts.append(Vector2(cos(a), sin(a)) * aoe_radius)
		var poly := Polygon2D.new()
		poly.color = Color(1.0, 1.0, 1.0, 0.35)
		poly.polygon = circle_pts
		area.add_child(poly)

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

	if context.has("hit_report"):
		context["hit_report"].append(hit_enemies.size())

	var _kill_count := 0
	for _ke in hit_enemies:
		if is_instance_valid(_ke) and "hp" in _ke and _ke.hp <= 0:
			_kill_count += 1
	var on_kill: Array = node.get("on_kill", [])
	if not on_kill.is_empty() and _kill_count > 0:
		for _okl_effect in on_kill:
			_execute_node(_okl_effect, source, null, context)

	var on_detect_once: Array = node.get("on_detect_once", [])
	if not on_detect_once.is_empty() and hit_enemies.size() > 0:
		for effect in on_detect_once:
			_execute_node(effect, source, null, context)

	# Lightning rod trigger check
	if node.get("element", "") == "lightning":
		_check_lightning_rods(source, spawn_pos, on_detect)

	source.get_tree().create_timer(lifetime, false).timeout.connect(area.queue_free)

## 光束触发器：梯形区域碰撞检测
static func _beam_detect(node: Dictionary, source: Node2D, context: Dictionary) -> void:
	if not source:
		return
	var origin_pos := _resolve_position(node.get("origin", "player"), source, context)
	var target_pos := _resolve_position(node.get("target", "enemy"), source, context)
	var beam_length: float = float(node.get("length", 100.0))
	var width: float = float(node.get("width", 10.0))
	var hit_width: float = float(node.get("hit_width", width))
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

	var hit_half := hit_width / 2.0
	var hit_half_tail := hit_width * tail_coeff / 2.0
	var hp0 := origin_pos + perp * hit_half
	var hp1 := origin_pos - perp * hit_half
	var hp2 := end_pos - perp * hit_half_tail
	var hp3 := end_pos + perp * hit_half_tail

	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([hp0 - origin_pos, hp1 - origin_pos, hp2 - origin_pos, hp3 - origin_pos])

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
	# 玻璃障碍折射
	for result in results:
		var gb_body: Node2D = result.get("collider")
		if gb_body and gb_body.is_in_group(&"glass_barrier") and gb_body.has_method("on_beam_hit"):
			gb_body.on_beam_hit(source)

	var poly := Polygon2D.new()
	var beam_color_hex: String = str(node.get("color", "#FFFFFF"))
	poly.color = Color(beam_color_hex)
	poly.polygon = PackedVector2Array([p0, p1, p2, p3])
	poly.global_position = Vector2.ZERO
	source.get_tree().current_scene.add_child(poly)

	var tween := source.get_tree().create_tween()
	tween.tween_property(poly, "modulate:a", min_opacity, lifetime)
	tween.tween_callback(poly.queue_free)
	tween.tween_callback(area.queue_free)




## 贯穿投射物触发器：穿过敌人不消失
static func _piercing_projectile(node: Dictionary, source: Node2D, context: Dictionary) -> void:
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
	var script: GDScript = load("res://script/entity/delivery_piercing_projectile.gd")
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

## 回旋镖触发器：飞出后返回，去程和回程各触发一次
static func _boomerang(node: Dictionary, source: Node2D, context: Dictionary) -> void:
	if not source:
		return
	var spawn := _resolve_spawn(node, source, context)
	var spawn_pos: Vector2 = spawn["position"]
	var direction: Vector2 = spawn["direction"]
	var on_detect: Array = node.get("on_detect", [])
	var area := Area2D.new()
	var boom_script: GDScript = load("res://script/entity/delivery_boomerang.gd")
	area.set_script(boom_script)
	area.speed = float(node.get("speed", 300.0))
	area.max_length = float(node.get("length", 200.0))
	area.total_time = float(node.get("time", 1.0))
	area.direction = direction
	area.animation = str(node.get("animation", ""))
	area.global_position = spawn_pos
	for effect in on_detect:
		area.boomerang_hit.connect(func(hit_target: Node2D):
			_execute_node(effect, source, hit_target, context)
		)
	source.get_tree().current_scene.add_child(area)


## 移动玻璃障碍触发器：从 origin 移向 target，存入 context 供后续光束定位
static func _spawn_moving_barrier(node: Dictionary, source: Node2D, context: Dictionary) -> void:
	if not source:
		return
	var origin_pos := _resolve_position(node.get("origin", "player"), source, context)
	var target_pos := _resolve_position(node.get("target", "enemy"), source, context)
	var move_time: float = float(node.get("time", 0.8))
	var barrier := StaticBody2D.new()
	var barrier_script: GDScript = load("res://script/entity/glass_barrier.gd")
	barrier.set_script(barrier_script)
	barrier.global_position = origin_pos
	source.get_tree().current_scene.add_child(barrier)
	var tween := source.get_tree().create_tween()
	tween.tween_property(barrier, "global_position", target_pos, move_time)
	context["moving_barrier"] = barrier

## 扩展圆环触发器：从 origin 向 target 移动，半径从 min_radius 扩展到 max_radius
static func _ring_detect(node: Dictionary, source: Node2D, context: Dictionary) -> void:
	if not source:
		return
	var origin_pos := _resolve_position(node.get("origin", "player"), source, context)
	var target_pos := _resolve_position(node.get("target", "player"), source, context)
	var min_r: float = float(node.get("min_radius", 0.0))
	var max_r: float = float(node.get("max_radius", 100.0))
	var time: float = float(node.get("time", 0.5))
	var lw: float = float(node.get("line_width", 3.0))
	var color_hex: String = str(node.get("color", "#FFFFFF"))
	var on_detect: Array = node.get("on_detect", [])
	var ring := Area2D.new()
	var ring_script: GDScript = load("res://script/entity/delivery_ring.gd")
	ring.set_script(ring_script)
	ring.min_radius = min_r
	ring.max_radius = max_r
	ring.duration = time
	ring.line_width = lw
	ring.ring_color = Color(color_hex)
	ring.target_position = target_pos
	ring.global_position = origin_pos
	for effect in on_detect:
		ring.ring_hit.connect(func(hit_target: Node2D):
			_execute_node(effect, source, hit_target, context)
		)
	source.get_tree().current_scene.add_child(ring)

## 坠落触发器：从天空投下投射物，落地后触发效果
static func _fall(node: Dictionary, source: Node2D, context: Dictionary) -> void:
	if not source:
		return
	var target_pos := _resolve_position(node.get("target", "random_enemy"), source, context)
	var max_offset_x: int = int(node.get("max_offset_x", 0))
	var start_height: float = float(node.get("start_height_h", 120.0))
	var fall_time: float = float(node.get("t", 0.4))
	var on_land: Array = node.get("on_land", [])

	var rand_offset := randf_range(-float(max_offset_x), float(max_offset_x))
	var start_pos := target_pos + Vector2(rand_offset, -start_height)
	var fall_dir := (target_pos - start_pos)
	# 视觉节点
	var visual := Node2D.new()
	var anim_path: String = str(node.get("animation", ""))
	if anim_path != "":
		var sprite := AnimatedSprite2D.new()
		var frames: SpriteFrames = load(anim_path)
		if frames:
			sprite.sprite_frames = frames
			var anim_name: String = str(node.get("fall_animation", ""))
			if anim_name == "" and frames.has_animation(&"falling"):
				anim_name = "falling"
			if anim_name != "" and frames.has_animation(StringName(anim_name)):
				frames.set_animation_loop(StringName(anim_name), true)
				sprite.play(StringName(anim_name))
			else:
				sprite.play()
		visual.add_child(sprite)

	# 素材默认朝下(0,1)，计算旋转使朝向对齐下落方向
	if fall_dir.length() > 0.001:
		visual.rotation = fall_dir.angle() - PI / 2.0

	visual.global_position = start_pos
	visual.z_index = 50
	source.get_tree().current_scene.add_child(visual)

	# 移动动画
	var tween := source.get_tree().create_tween()
	tween.tween_property(visual, "global_position", target_pos, fall_time)
	tween.tween_callback(func() -> void:
		visual.queue_free()
		# 落地时缩放反馈
		_show_land_impact(target_pos, source)
		var land_context := context.duplicate()
		land_context["parent_position"] = target_pos
		for effect in on_land:
			_execute_node(effect, source, null, land_context)
	)

## 坠落落地视觉反馈
static func _show_land_impact(pos: Vector2, source: Node2D) -> void:
	var circle := Node2D.new()
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for j in 12:
		var a := TAU * float(j) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * 15.0)
	poly.polygon = pts
	poly.color = Color(1.0, 1.0, 1.0, 0.5)
	circle.add_child(poly)
	circle.global_position = pos
	source.get_tree().current_scene.add_child(circle)
	var tween := source.get_tree().create_tween()
	tween.tween_property(poly, "modulate:a", 0.0, 0.2)
	tween.tween_callback(circle.queue_free)

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
			var anim_name: String = str(node.get("animation_name", ""))
			if anim_name != "" and frames.has_animation(StringName(anim_name)):
				sprite.play(StringName(anim_name))
			else:
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
