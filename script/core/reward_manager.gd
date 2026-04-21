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
	_phase = Phase.CARD_REWARD
	_show_card_reward()

## 从全池抽 3 张卡展示
func _show_card_reward() -> void:
	var card_db := CardLoader.load_attack_cards()
	var pool: Array = card_db.values()
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
	_reward_ui.show_ability_reward()

## 玩家跳过能力卡
func on_ability_skipped() -> void:
	_pending_ability_rewards -= 1
	_reward_ui.dismiss()
	_show_next_ability_reward()

## 所有奖励完成
func _finish_rewards() -> void:
	_phase = Phase.DONE
	rewards_completed.emit()
