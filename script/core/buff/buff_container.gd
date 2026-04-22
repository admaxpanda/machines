extends Node

## Buff 容器：管理实体上的所有 Buff/Debuff

signal buffs_changed()

var _buffs: Array = []          ## Array[BuffInstance]
var _buff_defs: Dictionary = {} ## StringName -> BuffData

func _ready() -> void:
	_load_buff_db()

func _load_buff_db() -> void:
	var file := FileAccess.open("res://data/buff/buffs.json", FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	for d in json.data.get("buffs", []):
		var def := BuffData.new()
		def.id = StringName(d.get("id", ""))
		def.buff_name = str(d.get("name", ""))
		var dur_str: String = str(d.get("duration_type", "turns"))
		def.duration_type = BuffData.DurationType.PERMANENT if dur_str == "permanent" else BuffData.DurationType.TURNS
		def.stacking = str(d.get("stacking", "intensity"))
		if def.id != &"":
			_buff_defs[def.id] = def

## 添加或叠加 buff
func add_buff(id: StringName, stacks: int, duration: int) -> void:
	var def: BuffData = _buff_defs.get(id)
	if not def:
		print("[Buff] 未知 buff: %s" % id)
		return
	if def.stacking == "shield":
		_buffs.append(BuffInstance.new(def, stacks, duration))
		print("[Buff] +护盾 %d (%d回合)" % [stacks, duration])
		buffs_changed.emit()
		return
	var existing: BuffInstance = _find(id)
	if existing:
		match def.stacking:
			"extend":
				existing.turns_remaining += duration
			"intensity":
				existing.stacks += stacks
				if duration > 0:
					existing.turns_remaining = duration
	else:
		_buffs.append(BuffInstance.new(def, stacks, duration))
	print("[Buff] +%s %d (%d回合)" % [def.buff_name, stacks, duration])
	buffs_changed.emit()

## 移除 buff
func remove_buff(id: StringName) -> void:
	for i in _buffs.size():
		if _buffs[i].data.id == id:
			_buffs.remove_at(i)
			buffs_changed.emit()
			return

## 清空所有 buff
func clear_all() -> void:
	_buffs.clear()
	buffs_changed.emit()

## 获取 buff 数值（护盾为所有实例总和）
func get_buff_stacks(id: StringName) -> int:
	var def: BuffData = _buff_defs.get(id)
	if def and def.stacking == "shield":
		var total := 0
		for b in _buffs:
			if b.data.id == id:
				total += b.stacks
		return total
	var b: BuffInstance = _find(id)
	return b.stacks if b else 0

## 是否有某个 buff
func has_buff(id: StringName) -> bool:
	return _find(id) != null

## 回合结束 tick：倒计时，每个护盾独立
func tick_turn() -> void:
	var to_remove: Array[int] = []
	for i in _buffs.size():
		var b: BuffInstance = _buffs[i]
		if b.data.duration_type == BuffData.DurationType.PERMANENT:
			continue
		b.turns_remaining -= 1
		if b.turns_remaining <= 0:
			to_remove.append(i)
	if to_remove.is_empty():
		return
	for idx in range(to_remove.size() - 1, -1, -1):
		var b: BuffInstance = _buffs[to_remove[idx]]
		if b.data.stacking == "shield":
			print("[Buff] 护盾 %d 过期（剩余 %d）" % [to_remove[idx], b.stacks])
		else:
			print("[Buff] %s 过期" % b.data.buff_name)
		_buffs.remove_at(to_remove[idx])
	buffs_changed.emit()

## 护盾扣减：最早过期优先消耗，永久最后，返回溢出伤害
func apply_shield_damage(amount: int) -> int:
	var shields: Array[BuffInstance] = []
	for b in _buffs:
		if b.data.id == &"shield" and b.stacks > 0:
			shields.append(b)
	if shields.is_empty():
		return amount
	shields.sort_custom(func(a: BuffInstance, b: BuffInstance) -> bool:
		if a.data.duration_type == BuffData.DurationType.PERMANENT:
			return false
		if b.data.duration_type == BuffData.DurationType.PERMANENT:
			return true
		return a.turns_remaining < b.turns_remaining
	)
	var remaining := amount
	for s in shields:
		if remaining <= 0:
			break
		var absorbed := mini(s.stacks, remaining)
		s.stacks -= absorbed
		remaining -= absorbed
		print("[Buff] 护盾吸收 %d，剩余 %d（%d回合）" % [absorbed, s.stacks, s.turns_remaining])
	_buffs = _buffs.filter(func(b: BuffInstance) -> bool: return b.data.id != &"shield" or b.stacks > 0)
	buffs_changed.emit()
	return remaining

func _find(id: StringName) -> BuffInstance:
	for b in _buffs:
		if b.data.id == id:
			return b
	return null
