extends Node

## Draft 模式：10 次强制选卡，替代 deck.json 起始卡组

signal draft_completed(attack_cards: Array, skill_cards: Array)

var _remaining: int = 0
var _total: int = 0
var _attack_cards: Array = []
var _skill_cards: Array = []
var _reward_ui: CanvasLayer
var _card_pool: Array = []
var _attack_db: Dictionary = {}

func start_draft(reward_ui: CanvasLayer, rounds: int = 10) -> void:
	_reward_ui = reward_ui
	_total = rounds
	_remaining = rounds
	_attack_cards.clear()
	_skill_cards.clear()
	_attack_db = CardLoader.load_attack_cards()
	_build_pool()
	_show_next()

func _build_pool() -> void:
	var excluded: Dictionary = {&"strike": true, &"defend": true, &"zap": true, &"dualcast": true}
	var skill_db := CardLoader.load_skill_cards()
	_card_pool.clear()
	for id in _attack_db:
		if not excluded.has(id):
			_card_pool.append(_attack_db[id])
	for id in skill_db:
		if not excluded.has(id):
			_card_pool.append(skill_db[id])

func _show_next() -> void:
	if _remaining <= 0:
		_reward_ui.visible = false
		draft_completed.emit(_attack_cards, _skill_cards)
		return
	_card_pool.shuffle()
	var choices := _card_pool.slice(0, mini(3, _card_pool.size()))
	var done := _total - _remaining + 1
	_reward_ui.show_draft_choices(choices, done, _total)

func on_card_selected(card) -> void:
	if _attack_db.has(card.id):
		_attack_cards.append(card)
	else:
		_skill_cards.append(card)
	_remaining -= 1
	_show_next()
