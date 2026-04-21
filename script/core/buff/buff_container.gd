extends Node

## Buff 容器：管理实体上的所有 Buff/Debuff

signal buffs_changed()

var _buffs: Array = []          ## Array[BuffInstance]
var _buff_defs: Dictionary = {} ## StringName -> BuffData

func _ready() -> void:
	_register_buffs()

func _register_buffs() -> void:
	_define(&"shield", "护盾", BuffData.DurationType.TURNS, "shield")
	_define(&"focus", "集中", BuffData.DurationType.TURNS, "extend")
	_define(&"strength", "力量", BuffData.DurationType.PERMANENT, "intensity")
	_define(&"dexterity", "敏捷", BuffData.DurationType.PERMANENT, "intensity")
	_define(&"vulnerable", "易伤", BuffData.DurationType.TURNS, "extend")
	_define(&"weak", "虚弱", BuffData.DurationType.TURNS, "extend")

func _define(id: StringName, name: String, dur: int, stack: String) -> void:
	var d := BuffData.new()
	d.id = id
	d.buff_name = name
	d.duration_type = dur
	d.stacking = stack
	_buff_defs[id] = d

## 添加或叠加 buff
func add_buff(id: StringName, stacks: int, duration: int) -> void:
	var def: BuffData = _buff_defs.get(id)
	if not def:
		print("[Buff] 未知 buff: %s" % id)
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
			"shield":
				existing.stacks += stacks
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

## 获取 buff 数值
func get_buff_stacks(id: StringName) -> int:
	var b: BuffInstance = _find(id)
	return b.stacks if b else 0

## 是否有某个 buff
func has_buff(id: StringName) -> bool:
	return _find(id) != null

## 回合结束 tick：倒计时，护盾到期清零
func tick_turn() -> void:
	var to_remove: Array[int] = []
	for i in _buffs.size():
		var b: BuffInstance = _buffs[i]
		if b.data.duration_type == BuffData.DurationType.PERMANENT:
			continue
		b.turns_remaining -= 1
		if b.data.stacking == "shield" and b.turns_remaining <= 0:
			b.stacks = 0
		if b.turns_remaining <= 0:
			to_remove.append(i)
	for idx in to_remove:
		print("[Buff] %s 过期" % _buffs[idx].data.buff_name)
		_buffs.remove_at(idx)
	if to_remove.size() > 0:
		buffs_changed.emit()

## 护盾扣减，返回溢出伤害
func apply_shield_damage(amount: int) -> int:
	var shield: BuffInstance = _find(&"shield")
	if not shield or shield.stacks <= 0:
		return amount
	var absorbed := mini(shield.stacks, amount)
	shield.stacks -= absorbed
	print("[Buff] 护盾吸收 %d，剩余 %d" % [absorbed, shield.stacks])
	buffs_changed.emit()
	return amount - absorbed

func _find(id: StringName) -> BuffInstance:
	for b in _buffs:
		if b.data.id == id:
			return b
	return null
