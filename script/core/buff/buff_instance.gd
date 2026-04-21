class_name BuffInstance
extends RefCounted

## Buff 运行时实例

var data: BuffData
var stacks: int = 0          ## 数值（力量+3、护盾10等）
var turns_remaining: int = 0 ## 剩余回合（-1=永久）

func _init(buff_data: BuffData, amount: int, duration: int) -> void:
	data = buff_data
	stacks = amount
	turns_remaining = duration
