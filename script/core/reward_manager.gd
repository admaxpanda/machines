extends Node

## 奖励管理器：卡牌奖励（三选一）→ 能力奖励 ×N → rewards_completed

signal rewards_completed

enum Phase { IDLE, CARD_REWARD, ABILITY_REWARD, DONE }

var _phase: Phase = Phase.IDLE
var _pending_ability_rewards: int = 0
var _player_level_at_start: int = 1
var _player: CharacterBody2D
var _card_engine: Node
var _reward_ui: CanvasLayer

## 战斗开始时记录玩家等级
func on_battle_started(player: CharacterBody2D) -> void:
	_player = player
	_player_level_at_start = player.level

## 关卡清除后开始奖励流程
func start_rewards(card_engine: Node) -> void:
	_card_engine = card_engine
	_pending_ability_rewards = _player.level - _player_level_at_start
	_player_level_at_start = _player.level
	# creative_ai: 每关额外获得一个能力卡奖励
	if _player and "abilities" in _player:
		for a in _player.abilities:
			if a.id == &"creative_ai":
				_pending_ability_rewards += 1
				break
	_phase = Phase.CARD_REWARD
	_show_card_reward()

## 从全池抽 3 张卡展示
func _show_card_reward() -> void:
	var card_db := CardLoader.load_attack_cards()
	var pool: Array = []
	for id in card_db:
		if id != &"strike":
			pool.append(card_db[id])
	pool.shuffle()
	var choices := pool.slice(0, mini(3, pool.size()))
	_reward_ui.show_card_choices(choices)

## 玩家选择了一张卡
func on_card_selected(card) -> void:
	_card_engine.add_card(card)
	_reward_ui.dismiss()
	_proceed_to_ability_rewards()

## 玩家跳过卡牌
func on_card_skipped() -> void:
	_reward_ui.dismiss()
	_proceed_to_ability_rewards()

## 进入能力奖励阶段
func _proceed_to_ability_rewards() -> void:
	_phase = Phase.ABILITY_REWARD
	_show_next_ability_reward()

## 展示下一张能力卡奖励
func _show_next_ability_reward() -> void:
	if _pending_ability_rewards <= 0:
		_finish_rewards()
		return
	var ability_db := CardLoader.load_ability_cards()
	var equipped_ids: Dictionary = {}
	if _player:
		for a in _player.abilities:
			equipped_ids[a.id] = true
	var pool: Array = []
	for id in ability_db:
		if not equipped_ids.has(id):
			pool.append(ability_db[id])
	pool.shuffle()
	var choices := pool.slice(0, mini(3, pool.size()))
	if choices.is_empty():
		_pending_ability_rewards -= 1
		_show_next_ability_reward()
		return
	_reward_ui.show_ability_choices(choices)

## 玩家跳过能力卡
func on_ability_skipped() -> void:
	_pending_ability_rewards -= 1
	_reward_ui.dismiss()
	_show_next_ability_reward()

## 玩家选择了一张能力卡
func on_ability_selected(ability: AbilityCardData) -> void:
	if _player and _player.has_method("add_ability"):
		_player.add_ability(ability)
	_pending_ability_rewards -= 1
	_reward_ui.dismiss()
	_show_next_ability_reward()

## 所有奖励完成
func _finish_rewards() -> void:
	_tick_biased_cognition()
	_phase = Phase.DONE
	rewards_completed.emit()

## 偏差认知：每场战斗结束减少1集中
func _tick_biased_cognition() -> void:
	if not _player:
		return
	var bc = _player.buff_container
	if not bc or not bc.has_buff(&"biased_cognition"):
		return
	var stacks: int = bc.get_buff_stacks(&"biased_cognition")
	if stacks <= 0:
		return
	bc.remove_buff(&"biased_cognition")
	bc.remove_buff(&"focus")
	var remaining := stacks - 1
	if remaining > 0:
		bc.add_buff(&"biased_cognition", remaining, -1)
		bc.add_buff(&"focus", remaining, -1)
	print("[Ability] 偏差认知: 集中 -1 (剩余 %d)" % remaining)
