class_name CardData
extends Resource

## 卡牌数据（攻击卡和技能卡共用）

var id: StringName = &""            ## 卡牌id
var card_name: String = ""          ## 名称 locale key
var description: String = ""        ## 描述 locale key
var cost: int = 1                   ## 能量消耗
var chain: Dictionary = {}          ## 效果链（嵌套结构）
var cover: String = ""              ## 封面图片路径
var exhaust: bool = false           ## 消耗：打出后进入消耗堆
var innate: bool = false            ## 固有：初始时一定在手牌中
var ethereal: bool = false          ## 虚无：回合结束未打出则消耗
var unplayable: bool = false        ## 无法被打出
var temporary: bool = false         ## 战斗中临时生成，关卡结束清除

## 从 JSON 字典解析
static func from_dict(data: Dictionary) -> CardData:
	var card := CardData.new()
	card.id = StringName(data.get("id", ""))
	card.card_name = str(data.get("name", ""))
	card.description = str(data.get("description", ""))
	card.cost = int(data.get("cost", 1))
	card.chain = data.get("chain", {})
	card.cover = str(data.get("cover", ""))
	card.exhaust = bool(data.get("exhaust", false))
	card.innate = bool(data.get("innate", false))
	card.ethereal = bool(data.get("ethereal", false))
	card.unplayable = bool(data.get("unplayable", false))
	return card
