extends Node2D

@onready var battle_manager: Node = $BattleManager
@onready var player: Node2D = $Player
@onready var enemies_node: Node2D = $Enemies
@onready var attack_card_engine: Node = $AttackCardEngine
@onready var reward_manager: Node = $RewardManager
@onready var reward_ui: CanvasLayer = $RewardUI
@onready var hud: CanvasLayer = $HUD

var skill_card_engine: Node

func _ready() -> void:
	player.add_to_group(&"player")

	Locale.set_lang("zh")

	# 技能卡引擎（代码创建）
	var sce_script: GDScript = load("res://script/core/skill_card_engine.gd")
	skill_card_engine = Node.new()
	skill_card_engine.set_script(sce_script)
	add_child(skill_card_engine)

	attack_card_engine.skill_card_engine = skill_card_engine

	# 攻击卡
	var attack_deck := CardLoader.build_attack_deck()
	attack_card_engine.source = player
	attack_card_engine.initialize(attack_deck)

	# 技能卡
	var skill_deck := CardLoader.build_skill_deck()
	skill_card_engine.source = player
	skill_card_engine.initialize(skill_deck)

	attack_card_engine.run_turns()

	# 奖励系统连线
	reward_manager._reward_ui = reward_ui
	reward_ui._reward_manager = reward_manager
	battle_manager._reward_manager = reward_manager
	battle_manager._card_engine = attack_card_engine
	reward_manager.rewards_completed.connect(battle_manager._on_rewards_completed)

	# HUD 技能栏连线
	hud.set_skill_engine(skill_card_engine)

	# 战斗
	battle_manager.start_battle(enemies_node)
