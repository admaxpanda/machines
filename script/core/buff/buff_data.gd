class_name BuffData
extends Resource

## Buff 数据定义

enum DurationType { PERMANENT, TURNS }

var id: StringName = &""
var buff_name: String = ""
var duration_type: DurationType = DurationType.TURNS
var stacking: String = "intensity"   ## "intensity" | "extend" | "shield"
