extends Node2D

@onready var battle_manager: Node = $BattleManager
@onready var player: Node2D = $Player
@onready var enemies_node: Node2D = $Enemies
@onready var card_engine: Node = $CardEngine
@onready var reward_manager: Node = $RewardManager
@onready var reward_ui: CanvasLayer = $RewardUI

func _ready() -> void:
	player.add_to_group(&"player")

	# 卡牌引擎
	var deck := CardLoader.build_attack_deck()
	card_engine.source = player
	card_engine.initialize(deck)
	card_engine.run_turns()

	# 奖励系统连线
	reward_manager._reward_ui = reward_ui
	reward_ui._reward_manager = reward_manager
	battle_manager._reward_manager = reward_manager
	battle_manager._card_engine = card_engine
	reward_manager.rewards_completed.connect(battle_manager._on_rewards_completed)

	# 战斗
	battle_manager.start_battle(enemies_node)
