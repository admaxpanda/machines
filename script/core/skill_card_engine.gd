extends CardEngine

## 技能卡引擎：手动按键打出，独立能量和卡池

signal turn_progress_changed(current: int, total: int)

var _turn_counter: int = 0
var draw_every_n_turns: int = 1

func _ready() -> void:
	add_to_group(&"skill_card_engine")
	energy_per_turn = 1
	hand_limit = 5
	draw_per_turn = 1

## 初始化：固有卡先入手牌
func initialize(deck: Array) -> void:
	var innate_cards: Array = []
	var remaining: Array = []
	for card in deck:
		if card.innate:
			innate_cards.append(card)
		else:
			remaining.append(card)
	draw_pile = remaining
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	energy = 0
	for card in innate_cards:
		if hand.size() < hand_limit:
			hand.append(card)
	draw_pile.shuffle()
	hand_changed.emit()

## 每攻击回合开始时调用，每 N 回合抽牌+获能
func start_turn() -> void:
	_turn_counter += 1
	turn_progress_changed.emit(_turn_counter, draw_every_n_turns)
	if _turn_counter >= draw_every_n_turns:
		_turn_counter = 0
		energy += energy_per_turn
		energy_changed.emit(energy)
		draw_cards(draw_per_turn)

## 按键 1-5 手动打出
func play_at(index: int) -> void:
	if index < 0 or index >= hand.size():
		return
	var card: CardData = hand[index]
	if card.cost > energy or card.unplayable:
		return
	_play_card(card)

## 技能卡打出后触发 storm 能力
func _play_card(card: CardData) -> void:
	super._play_card(card)
	_check_storm()

func _check_storm() -> void:
	if not source or not "abilities" in source:
		return
	for a in source.abilities:
		if a.id == &"storm":
			var managers := get_tree().get_nodes_in_group(&"orb_manager")
			if managers.size() > 0:
				managers[0].channel_orb(&"lightning")
			return

## 关卡结束归位：重置进度计数器
func reset_for_new_battle() -> void:
	super.reset_for_new_battle()
	# 固有卡重新入手牌
	var innate_remaining: Array = []
	var other: Array = []
	for card in draw_pile:
		if card.innate:
			innate_remaining.append(card)
		else:
			other.append(card)
	for card in innate_remaining:
		if hand.size() < hand_limit:
			hand.append(card)
	draw_pile = other
	hand_changed.emit()
	_turn_counter = 0
	turn_progress_changed.emit(0, draw_every_n_turns)
