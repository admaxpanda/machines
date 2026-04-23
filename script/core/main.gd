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

	# 语言已由菜单场景设置

	# 技能卡引擎（代码创建）
	var sce_script: GDScript = load("res://script/core/skill_card_engine.gd")
	skill_card_engine = Node.new()
	skill_card_engine.set_script(sce_script)
	add_child(skill_card_engine)

	attack_card_engine.skill_card_engine = skill_card_engine

	# 奖励系统连线
	reward_manager._reward_ui = reward_ui
	reward_ui._reward_manager = reward_manager
	battle_manager._reward_manager = reward_manager
	battle_manager._card_engine = attack_card_engine
	reward_manager.rewards_completed.connect(battle_manager._on_rewards_completed)

	# HUD 技能栏连线
	hud.set_skill_engine(skill_card_engine)

	# Draft 模式：先选卡再开战
	if GameMode.mode == GameMode.Mode.DRAFT:
		var draft_manager := Node.new()
		draft_manager.set_script(load("res://script/core/draft_manager.gd"))
		add_child(draft_manager)
		reward_ui._draft_manager = draft_manager
		draft_manager.draft_completed.connect(_on_draft_completed)
		draft_manager.start_draft(reward_ui, 10)
	else:
		_init_standard_decks()
		_start_battle()

func _init_standard_decks() -> void:
	var attack_deck := CardLoader.build_attack_deck()
	attack_card_engine.source = player
	attack_card_engine.initialize(attack_deck)
	var skill_deck := CardLoader.build_skill_deck()
	skill_card_engine.source = player
	skill_card_engine.initialize(skill_deck)
	attack_card_engine.run_turns()

func _on_draft_completed(attack_cards: Array, skill_cards: Array) -> void:
	attack_card_engine.source = player
	attack_card_engine.initialize(attack_cards)
	skill_card_engine.source = player
	skill_card_engine.initialize(skill_cards)
	attack_card_engine.run_turns()
	_start_battle()

func _start_battle() -> void:
	battle_manager.start_battle(enemies_node)
