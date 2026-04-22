class_name OrbSlot
extends RefCounted

## 充能球运行时实例

var data: OrbData
var accumulated: float = 6.0   ## Dark 球累积伤害
var glass_damage: int = 4      ## Glass 球当前伤害值

func _init(orb_data: OrbData) -> void:
	data = orb_data
