class_name AbilityCardData
extends Resource

## 被动能力卡数据

var id: StringName = &""
var ability_name: String = ""
var rarity: String = "common"          ## common / uncommon / rare
var description: String = ""
var icon: String = ""                  ## 图标路径

static func from_dict(data: Dictionary) -> AbilityCardData:
	var a := AbilityCardData.new()
	a.id = StringName(data.get("id", ""))
	a.ability_name = str(data.get("name", ""))
	a.rarity = str(data.get("rarity", "common"))
	a.description = str(data.get("description", ""))
	a.icon = str(data.get("icon", ""))
	return a
