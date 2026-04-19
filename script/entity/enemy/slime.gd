extends CharacterBody2D

# 史莱姆 — 追踪玩家，碰撞造成伤害
# 数值通过 init() 从 enemies.json 注入

var hp: int = 10
var speed: float = 80.0
var damage: int = 5
var xp_value: int = 1
var _player: CharacterBody2D

# 由 battle_manager 调用，传入 JSON 中该敌人的数据
func init(data: Dictionary) -> void:
	hp = int(data.get("hp", 10))
	speed = float(data.get("speed", 80))
	damage = int(data.get("damage", 5))
	xp_value = int(data.get("xp_value", 1))

func _ready() -> void:
	add_to_group(&"enemy")
	var players := get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		_player = players[0] as CharacterBody2D

func _physics_process(_delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var direction := (_player.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()
