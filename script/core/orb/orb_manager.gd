extends Node2D

## 充能球管理器：充能/激发/被动触发 + 扇形视觉

signal orb_channeled(orb_id: StringName)
signal orb_evoked(orb_id: StringName)
signal orbs_changed()

var slots: Array = []              ## Array[OrbSlot]
var max_slots: int = 3
var _orb_db: Dictionary = {}
var _visuals: Array[AnimatedSprite2D] = []
var _damage_labels: Array[Label] = []
var _sprite_frames: SpriteFrames

const ARC_RADIUS: float = 22.0
const ARC_CENTER := Vector2(0, -22.0)
const ANIM_DURATION: float = 0.25
const PASSIVE_INTERVAL: float = 0.2

func _ready() -> void:
	_load_orb_db()
	_sprite_frames = load("res://sprite/orbs.tres")

func _load_orb_db() -> void:
	var file := FileAccess.open("res://data/orb/orbs.json", FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	for d in json.data.get("orbs", []):
		var orb: OrbData = OrbData.from_dict(d)
		if orb.id != &"":
			_orb_db[orb.id] = orb

## --- 布局 ---

func _get_orb_position(index: int, total: int) -> Vector2:
	var spread := deg_to_rad(120.0 + maxf(max_slots - 3, 0) * 10.0)
	var t: float = 0.5
	if total > 1:
		t = float(index) / float(total - 1)
	var angle := -PI / 2.0 + spread * (0.5 - t)
	return Vector2(cos(angle), sin(angle)) * ARC_RADIUS + ARC_CENTER

## 清空所有球位
func clear_all() -> void:
	for sprite in _visuals:
		if is_instance_valid(sprite):
			sprite.queue_free()
	slots.clear()
	_visuals.clear()
	_damage_labels.clear()
	orbs_changed.emit()
	print("[Orb] 清空所有球位")

## 充能/激发 ---

func channel_orb(orb_id: StringName) -> void:
	if slots.size() >= max_slots:
		var ejected_slot: OrbSlot = slots.pop_front()
		var ejected_sprite: AnimatedSprite2D = _visuals.pop_front()
		_damage_labels.pop_front()
		var ejected_pos := ejected_sprite.global_position
		_evoke_slot(ejected_slot, ejected_pos)
		_animate_ejection(ejected_sprite)
	var data: OrbData = _orb_db.get(orb_id)
	if not data:
		push_warning("[OrbManager] 未知球 id: %s" % orb_id)
		return
	slots.append(OrbSlot.new(data))
	var sprite := _create_visual(data)
	_visuals.append(sprite)
	_animate_all()
	print("[Orb] channel %s (槽位 %d/%d)" % [data.orb_name, slots.size(), max_slots])
	_refresh_labels()
	orb_channeled.emit(orb_id)
	orbs_changed.emit()

func evoke_first() -> void:
	if slots.is_empty():
		return
	var slot: OrbSlot = slots.pop_front()
	var sprite: AnimatedSprite2D = _visuals.pop_front()
	_damage_labels.pop_front()
	var pos := sprite.global_position
	_evoke_slot(slot, pos)
	_animate_ejection(sprite)

func evoke_last() -> void:
	if slots.is_empty():
		return
	var slot: OrbSlot = slots.pop_back()
	var sprite: AnimatedSprite2D = _visuals.pop_back()
	_damage_labels.pop_back()
	var pos := sprite.global_position
	_evoke_slot(slot, pos)
	_animate_exit(sprite)

## --- 被动触发（异步，每个球间隔 PASSIVE_INTERVAL 秒）---

func trigger_all_passives() -> void:
	var count := slots.size()
	for i in range(count):
		if i >= slots.size() or i >= _visuals.size():
			break
		_play_passive_visual(i)
		var orb_pos := _visuals[i].global_position
		_trigger_passive(slots[i], orb_pos)
		await get_tree().create_timer(PASSIVE_INTERVAL, false).timeout
	_refresh_labels()

## --- 被动视觉效果：球副本放大淡出 ---

func _play_passive_visual(index: int) -> void:
	if index >= _visuals.size():
		return
	var original: AnimatedSprite2D = _visuals[index]
	var copy := AnimatedSprite2D.new()
	copy.sprite_frames = original.sprite_frames
	copy.play(original.animation)
	copy.position = original.position
	copy.scale = Vector2(original.scale)
	copy.modulate.a = 1.0
	add_child(copy)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(copy, "scale", copy.scale * 1.5, PASSIVE_INTERVAL)
	tween.tween_property(copy, "modulate:a", 0.5, PASSIVE_INTERVAL)
	tween.chain().tween_callback(copy.queue_free)

## --- 通用被动执行 ---

func _trigger_passive(slot: OrbSlot, orb_pos: Vector2 = Vector2.ZERO) -> void:
	var data: OrbData = slot.data
	var focus := _get_focus()

	if not data.passive_accumulate.is_empty():
		var base: int = int(data.passive_accumulate.get("base", 0))
		slot.accumulated += base + data.passive_focus_bonus * focus
		print("[Orb] %s passive: accumulated %d" % [data.orb_name, int(slot.accumulated)])
		return

	if not data.passive_shield.is_empty():
		var amount: int = int(data.passive_shield.get("amount", 0)) + data.passive_focus_bonus * focus
		var duration: int = int(data.passive_shield.get("duration", 1))
		var bc := _get_player_buff_container()
		if bc:
			bc.add_buff(&"shield", amount, duration)
			_show_shield_visual()
		print("[Orb] %s passive: %d shield" % [data.orb_name, amount])
		return

	if data.passive_energy > 0:
		_add_pending_energy(data.passive_energy)
		print("[Orb] %s passive: +%d energy (pending)" % [data.orb_name, data.passive_energy])
		return

	if not data.passive_chain.is_empty():
		var chain := data.passive_chain.duplicate(true)
		if data.passive_glass_damage:
			var damage := slot.glass_damage + data.passive_focus_bonus * focus
			_inject_damage(chain, damage)
			slot.glass_damage = maxi(slot.glass_damage - 1, 0)
			# spinner: 额外发射次数
			if chain.get("type") == &"multi_release":
				var extra := _count_player_ability(&"spinner")
				if extra > 0:
					chain["count"] = int(chain.get("count", 1)) + extra
			print("[Orb] %s passive: glass %d dmg" % [data.orb_name, damage])
		else:
			_apply_focus_to_chain(chain, data.passive_focus_bonus * focus)
		var player := _get_player()
		if player:
			Attack.execute(chain, player, {"source": player, "parent_position": orb_pos})
		return

	print("[Orb] %s passive: no effect" % data.orb_name)

## --- 通用激发执行 ---

func _evoke_slot(slot: OrbSlot, orb_pos: Vector2 = Vector2.ZERO) -> void:
	var data: OrbData = slot.data
	var focus := _get_focus()

	if not data.evoke_shield.is_empty():
		var amount: int = int(data.evoke_shield.get("amount", 0)) + data.evoke_focus_bonus * focus
		var duration: int = int(data.evoke_shield.get("duration", 1))
		var bc := _get_player_buff_container()
		if bc:
			bc.add_buff(&"shield", amount, duration)
			_show_shield_visual()
		print("[Orb] %s evoke: %d shield" % [data.orb_name, amount])

	if data.evoke_energy > 0:
		_add_energy(data.evoke_energy)
		print("[Orb] %s evoke: +%d energy" % [data.orb_name, data.evoke_energy])

	if not data.evoke_chain.is_empty():
		var chain := data.evoke_chain.duplicate(true)
		var player := _get_player()
		if not player:
			return
		if data.id == &"dark":
			_apply_accumulated_damage(chain, slot)
		elif data.passive_glass_damage:
			var damage := (slot.glass_damage + data.evoke_focus_bonus * focus) * data.evoke_damage_multiplier
			_inject_damage(chain, damage)
			print("[Orb] %s evoke: glass ×%d dmg" % [data.orb_name, damage])
		else:
			_apply_focus_to_chain(chain, data.evoke_focus_bonus * focus)
		# thunder: lightning evoke extra times
		if chain.get("type") == &"multi_release":
			var thunder_count := _count_player_ability(&"thunder")
			if thunder_count > 0:
				chain["count"] = int(chain.get("count", 1)) + thunder_count
		Attack.execute(chain, player, {"source": player, "parent_position": orb_pos})

	print("[Orb] evoke %s: %s" % [data.orb_name, data.evoke_desc])
	orb_evoked.emit(data.id)
	orbs_changed.emit()

## --- 伤害注入 ---

## 将指定伤害注入 chain 中第一个 deal_damage（支持 multi_release 子链）
func _inject_damage(chain: Dictionary, damage: int) -> void:
	var sub_chains: Array = chain.get("chains", [])
	if not sub_chains.is_empty():
		for sub in sub_chains:
			_set_chain_damage(sub, damage)
	else:
		_set_chain_damage(chain, damage)

func _set_chain_damage(chain: Dictionary, damage: int) -> void:
	var on_detect: Array = chain.get("on_detect", [])
	for effect in on_detect:
		if effect.get("type") == "deal_damage":
			effect["value"] = damage
			return

func _apply_focus_to_chain(chain: Dictionary, bonus: int) -> void:
	if bonus == 0:
		return
	var on_detect: Array = chain.get("on_detect", [])
	for effect in on_detect:
		if effect.get("type") == "deal_damage":
			effect["value"] = int(effect.get("value", 0)) + bonus
			return

func _apply_accumulated_damage(chain: Dictionary, slot: OrbSlot) -> void:
	var damage := int(slot.accumulated)
	slot.accumulated = 0.0
	var on_detect: Array = chain.get("on_detect", [])
	for effect in on_detect:
		if effect.get("type") == "deal_damage":
			effect["value"] = damage
			return

## --- 能量 ---

func _add_energy(amount: int) -> void:
	var engines := get_tree().get_nodes_in_group(&"card_engine")
	if engines.size() > 0:
		engines[0].energy += amount
		engines[0].energy_changed.emit(engines[0].energy)
	var skill_engines := get_tree().get_nodes_in_group(&"skill_card_engine")
	if skill_engines.size() > 0:
		skill_engines[0].energy += amount
		skill_engines[0].energy_changed.emit(skill_engines[0].energy)

func _add_pending_energy(amount: int) -> void:
	var engines := get_tree().get_nodes_in_group(&"card_engine")
	if engines.size() > 0 and "pending_energy" in engines[0]:
		engines[0].pending_energy += amount

## --- 护盾视觉（block.tres 动画，~50%透明度）---

func _show_shield_visual() -> void:
	var player := _get_player()
	if not player:
		return
	var sprite := AnimatedSprite2D.new()
	var frames: SpriteFrames = load("res://sprite/block.tres")
	if frames and frames.has_animation(&"block"):
		sprite.sprite_frames = frames
		sprite.play(&"block")
	sprite.modulate.a = 0.5
	player.add_child(sprite)
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.tween_callback(sprite.queue_free)

## --- 工具函数 ---

func _get_player() -> Node2D:
	return get_parent() as Node2D

func _get_focus() -> int:
	var bc := _get_player_buff_container()
	if bc:
		return bc.get_buff_stacks(&"focus")
	return 0

func _get_player_buff_container() -> Node:
	var player := _get_player()
	if not player:
		return null
	for child in player.get_children():
		if child.is_in_group(&"buff_container"):
			return child
	return null

func _count_player_ability(ability_id: StringName) -> int:
	var player := _get_player()
	if not player or not "abilities" in player:
		return 0
	var count := 0
	for a in player.abilities:
		if a.id == ability_id:
			count += 1
	return count

## --- 视觉节点管理 ---

func _create_visual(data: OrbData) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	if _sprite_frames:
		sprite.sprite_frames = _sprite_frames
		var anim_name := String(data.id)
		if _sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)
	add_child(sprite)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 8)
	label.position = Vector2(-6, 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.add_child(label)
	_damage_labels.append(label)

	return sprite

func _refresh_labels() -> void:
	for i in slots.size():
		if i >= _damage_labels.size():
			break
		var label: Label = _damage_labels[i]
		var data: OrbData = slots[i].data
		var text := ""
		match data.id:
			&"lightning":
				var base_dmg: int = 0
				var on_detect: Array = data.passive_chain.get("on_detect", [])
				if not on_detect.is_empty():
					base_dmg = int(on_detect[0].get("value", 0))
				text = str(base_dmg + data.passive_focus_bonus * _get_focus())
			&"frost":
				var frost_amt: int = int(data.passive_shield.get("amount", 0))
				text = str(frost_amt + data.passive_focus_bonus * _get_focus())
			&"dark":
				text = str(int(slots[i].accumulated))
			&"glass":
				text = str(slots[i].glass_damage)
		label.text = text
		label.visible = text != ""

func _animate_all() -> void:
	for i in _visuals.size():
		var target := _get_orb_position(i, _visuals.size())
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(_visuals[i], "position", target, ANIM_DURATION)

func _animate_ejection(sprite: AnimatedSprite2D) -> void:
	var exit_pos := sprite.position + Vector2(30, -10)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position", exit_pos, ANIM_DURATION)
	tween.tween_property(sprite, "modulate:a", 0.0, ANIM_DURATION)
	tween.chain().tween_callback(sprite.queue_free)

func _animate_exit(sprite: AnimatedSprite2D) -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, ANIM_DURATION)
	tween.tween_callback(sprite.queue_free)
