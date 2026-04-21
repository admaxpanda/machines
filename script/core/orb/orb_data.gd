class_name OrbData
extends Resource

## 充能球数据

var id: StringName = &""
var orb_name: String = ""
var passive_desc: String = ""
var evoke_desc: String = ""

# 被动
var passive_chain: Dictionary = {}        ## 攻击链（同 attack_cards.json 格式）
var passive_focus_bonus: int = 0
var passive_shield: Dictionary = {}       ## {"amount": N, "duration": N}
var passive_accumulate: Dictionary = {}   ## {"base": N}
var passive_energy: int = 0
var passive_glass_damage: bool = false    ## 使用 slot.glass_damage 作为基础伤害，被动后 -1

# 激发
var evoke_chain: Dictionary = {}
var evoke_focus_bonus: int = 0
var evoke_shield: Dictionary = {}
var evoke_energy: int = 0
var evoke_damage_multiplier: int = 1

static func from_dict(d: Dictionary) -> OrbData:
	var o := OrbData.new()
	o.id = StringName(d.get("id", ""))
	o.orb_name = str(d.get("name", ""))
	o.passive_desc = str(d.get("passive_desc", ""))
	o.evoke_desc = str(d.get("evoke_desc", ""))
	o.passive_chain = d.get("passive_chain", {})
	o.passive_focus_bonus = int(d.get("passive_focus_bonus", 0))
	o.passive_shield = d.get("passive_shield", {})
	o.passive_accumulate = d.get("passive_accumulate", {})
	o.passive_energy = int(d.get("passive_energy", 0))
	o.passive_glass_damage = bool(d.get("passive_glass_damage", false))
	o.evoke_chain = d.get("evoke_chain", {})
	o.evoke_focus_bonus = int(d.get("evoke_focus_bonus", 0))
	o.evoke_shield = d.get("evoke_shield", {})
	o.evoke_energy = int(d.get("evoke_energy", 0))
	o.evoke_damage_multiplier = int(d.get("evoke_damage_multiplier", 1))
	return o
