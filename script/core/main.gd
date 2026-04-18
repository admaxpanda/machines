extends Node2D

@onready var battle_manager: Node = $BattleManager
@onready var player: Node2D = $Player
@onready var enemies_node: Node2D = $Enemies

func _ready() -> void:
	player.add_to_group(&"player")
	battle_manager.start_battle(enemies_node)
