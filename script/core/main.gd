extends Node2D

@onready var battle_manager: Node = $BattleManager
@onready var player: Node2D = $Player
@onready var enemies_node: Node2D = $Enemies
@onready var card_engine: Node = $CardEngine

func _ready() -> void:
	player.add_to_group(&"player")
	var deck := CardLoader.build_attack_deck()
	card_engine.source = player
	card_engine.initialize(deck)
	card_engine.run_turns()
	battle_manager.start_battle(enemies_node)
