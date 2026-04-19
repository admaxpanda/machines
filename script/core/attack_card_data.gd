class_name AttackCardData
extends Resource

## 攻击卡数据

var id: StringName = &""            ## 卡牌id
var card_name: String = ""          ## 显示名称
var cost: int = 1                   ## 能量消耗
var chain: Dictionary = {}          ## 效果链（嵌套结构）
var exhaust: bool = false           ## 打出后是否消耗

## 从 JSON 字典解析
static func from_dict(data: Dictionary) -> AttackCardData:
	var card := AttackCardData.new()
	card.id = StringName(data.get("id", ""))
	card.card_name = str(data.get("name", ""))
	card.cost = int(data.get("cost", 1))
	card.chain = data.get("chain", {})
	card.exhaust = bool(data.get("exhaust", false))
	return card
