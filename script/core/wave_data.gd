class_name WaveData
extends Resource

## 波次数据定义.
## 每条波次从 start_time 开始，按 spawn_interval 间隔生成 count 个敌人.
## 多条波次可同时运行（并行）.

var enemy_id: StringName = &""       ## 敌人id，引用敌人场景
var start_time: float = 0.0         ## 战斗开始后多少秒启动这条波次
var count: int = 5                  ## 这条波次总共生成多少个敌人
var spawn_interval: float = 0.5     ## 每次生成之间的间隔秒数
var type: StringName = &"normal"    ## 波次类型：normal / elite / boss
