extends Node2D

@onready var battle_manager: Node = $BattleManager
@onready var player: Node2D = $Player
@onready var enemies_node: Node2D = $Enemies
@onready var attack_card_engine: Node = $AttackCardEngine
@onready var reward_manager: Node = $RewardManager
@onready var reward_ui: CanvasLayer = $RewardUI
@onready var hud: CanvasLayer = $HUD
@onready var result_screen: CanvasLayer = $ResultScreen

var skill_card_engine: Node
var _stats_loaded: bool = false

func _ready() -> void:
	player.add_to_group(&"player")

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

	# 结算信号
	battle_manager.battle_ended.connect(_on_victory)
	player.player_died.connect(_on_defeat)

	# HUD 技能栏连线
	hud.set_skill_engine(skill_card_engine)

	# 根据模式初始化卡组并开始战斗
	if GameMode.loaded_attack_cards.size() > 0 or GameMode.loaded_skill_cards.size() > 0:
		_stats_loaded = true
		_init_loaded_decks()
		_apply_loaded_abilities()
		var start_idx := GameMode.starting_level_index
		GameMode.clear_load_state()
		_start_battle_at(start_idx)
	elif GameMode.mode == GameMode.Mode.DRAFT:
		GameMode.start_run()
		var draft_manager := Node.new()
		draft_manager.set_script(load("res://script/core/draft_manager.gd"))
		add_child(draft_manager)
		reward_ui._draft_manager = draft_manager
		draft_manager.draft_completed.connect(_on_draft_completed)
		draft_manager.start_draft(reward_ui, 10)
	else:
		GameMode.start_run()
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

func _init_loaded_decks() -> void:
	attack_card_engine.source = player
	attack_card_engine.initialize(GameMode.loaded_attack_cards)
	skill_card_engine.source = player
	skill_card_engine.initialize(GameMode.loaded_skill_cards)
	attack_card_engine.run_turns()

func _apply_loaded_abilities() -> void:
	for ability in GameMode.loaded_abilities:
		player.add_ability(ability)

func _on_draft_completed(attack_cards: Array, skill_cards: Array) -> void:
	attack_card_engine.source = player
	attack_card_engine.initialize(attack_cards)
	skill_card_engine.source = player
	skill_card_engine.initialize(skill_cards)
	attack_card_engine.run_turns()
	_start_battle()

func _start_battle() -> void:
	battle_manager.start_battle(enemies_node)

func _start_battle_at(level_index: int) -> void:
	battle_manager.start_battle(enemies_node, level_index)

func _collect_all_cards() -> Dictionary:
	var attack_cards: Array = []
	var engines := get_tree().get_nodes_in_group(&"card_engine")
	if engines.size() > 0:
		var ae = engines[0]
		var all: Array = ae.draw_pile + ae.hand + ae.discard_pile + ae.exhaust_pile
		for c in all:
			if not c.temporary:
				attack_cards.append(c)

	var skill_cards: Array = []
	var skill_engines := get_tree().get_nodes_in_group(&"skill_card_engine")
	if skill_engines.size() > 0:
		var se = skill_engines[0]
		var all: Array = se.draw_pile + se.hand + se.discard_pile + se.exhaust_pile
		for c in all:
			if not c.temporary:
				skill_cards.append(c)

	var abilities: Array = []
	if "abilities" in player:
		abilities = player.abilities

	return {"attack": attack_cards, "skill": skill_cards, "ability": abilities}

func _on_victory() -> void:
	attack_card_engine.stop_turns()
	var cards := _collect_all_cards()
	var level_index: int = 0
	var bms := get_tree().get_nodes_in_group(&"battle_manager")
	if bms.size() > 0 and "_current_level_index" in bms[0]:
		level_index = bms[0]._current_level_index
	var ability_ids: Array = []
	for a in cards.ability:
		ability_ids.append(a.id)
	SaveManager.save_game_record("victory", level_index, GameMode.kill_count, GameMode.get_play_time_ms(), cards.attack, cards.skill, ability_ids, GameMode.mode)
	SaveManager.delete_save()
	result_screen.show_victory(GameMode.kill_count, GameMode.get_play_time_ms(), cards.attack, cards.skill, cards.ability)

func _on_defeat() -> void:
	attack_card_engine.stop_turns()
	var cards := _collect_all_cards()
	var level_index: int = 0
	var bms := get_tree().get_nodes_in_group(&"battle_manager")
	if bms.size() > 0 and "_current_level_index" in bms[0]:
		level_index = bms[0]._current_level_index
	var ability_ids: Array = []
	for a in cards.ability:
		ability_ids.append(a.id)
	SaveManager.save_game_record("defeat", level_index, GameMode.kill_count, GameMode.get_play_time_ms(), cards.attack, cards.skill, ability_ids, GameMode.mode)
	SaveManager.delete_save()
	result_screen.show_defeat(GameMode.kill_count, GameMode.get_play_time_ms(), cards.attack, cards.skill, cards.ability)
