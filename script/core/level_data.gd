class_name LevelData
extends Resource

## 关卡数据
## 从 levels.json 中解析得到，包含该关卡所有波次信息

var id: StringName = &""        ## 唯一标识，如 "scene1_level1"
var scene_index: int = 0        ## 场景编号，0-2 对应三个大场景
var level_index: int = 0        ## 关卡编号，0-4 对应场景内 5 关
var waves: Array = []           ## WaveData 数组

## 从 JSON 字典解析为一个 LevelData 实例
static func from_dict(data: Dictionary) -> LevelData:
	var ld := LevelData.new()
	ld.id = StringName(data.get("id", ""))
	ld.scene_index = int(data.get("scene_index", 0))
	ld.level_index = int(data.get("level_index", 0))
	for wave_data in data.get("waves", []):
		var wave: WaveData = WaveData.new()
		wave.enemy_id = StringName(wave_data.get("enemy_id", ""))
		wave.start_time = float(wave_data.get("start_time", 0.0))
		wave.count = int(wave_data.get("count", 5))
		wave.spawn_interval = float(wave_data.get("spawn_interval", 2.0))
		wave.type = StringName(wave_data.get("type", "normal"))
		ld.waves.append(wave)
	return ld
