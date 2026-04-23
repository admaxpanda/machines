class_name CardEngine
extends Node

## 卡牌引擎基类：卡池管理 + 能量 + 出牌

signal energy_changed(new_energy: int)
signal hand_changed()

var draw_pile: Array = []          ## Array[CardData] 抽牌堆
var hand: Array = []               ## Array[CardData] 手牌
var discard_pile: Array = []       ## Array[CardData] 弃牌堆
var exhaust_pile: Array = []       ## Array[CardData] 消耗堆
var source: Node2D                  ## 玩家引用

var energy: int = 0                ## 当前能量
var energy_per_turn: int = 3       ## 每回合获得能量
var hand_limit: int = 10           ## 手牌上限
var draw_per_turn: int = 5         ## 每回合抽牌数

## 添加卡牌到弃牌堆（奖励系统用）
func add_card(card: CardData) -> void:
	discard_pile.append(card)

## 关卡结束归位：所有牌回到抽牌堆，能量清零
func reset_for_new_battle() -> void:
	draw_pile.append_array(hand)
	draw_pile.append_array(discard_pile)
	draw_pile.append_array(exhaust_pile)
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	draw_pile = draw_pile.filter(func(c: CardData) -> bool: return not c.temporary)
	energy = 0
	energy_changed.emit(energy)
	hand_changed.emit()
	draw_pile.shuffle()

## 初始化：传入卡组，洗牌放入抽牌堆
func initialize(deck: Array) -> void:
	draw_pile = deck.duplicate()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	energy = 0
	draw_pile.shuffle()

## 抽牌：从抽牌堆取牌到手牌，抽牌堆空则先洗入弃牌堆
func draw_cards(count: int) -> void:
	for i in count:
		if hand.size() >= hand_limit:
			break
		if draw_pile.is_empty():
			_shuffle_discard_into_draw()
			if draw_pile.is_empty():
				break
		hand.append(draw_pile.pop_back())
	hand_changed.emit()

## 弃牌堆洗入抽牌堆
func _shuffle_discard_into_draw() -> void:
	draw_pile = discard_pile.duplicate()
	discard_pile.clear()
	draw_pile.shuffle()

## 执行一张卡牌：扣能量 → 移手牌 → 执行链 → 弃牌/消耗 → 子程序检查
func _play_card(card: CardData) -> void:
	energy -= card.cost
	energy_changed.emit(energy)
	hand.erase(card)
	if card.exhaust:
		exhaust_pile.append(card)
	elif _should_return_to_hand(card):
		hand.append(card)
	else:
		discard_pile.append(card)
	hand_changed.emit()
	var context := {
		"source": source,
		"card_engine": self,
	}
	var extra := _get_extra_plays(card)
	CardResolver.play(card, context)
	for i in extra:
		CardResolver.play(card, context)
	_check_subroutine(card, context)

## 子程序：20% 概率再次触发卡牌效果 + 退还 1 能量 + 无人机视觉
func _check_subroutine(card: CardData, context: Dictionary) -> void:
	if not source or not "abilities" in source:
		return
	var has_sub := false
	for a in source.abilities:
		if a.id == &"subroutine":
			has_sub = true
			break
	if not has_sub:
		return
	if randf() >= 0.20:
		return
	CardResolver.play(card, context)
	energy += 1
	energy_changed.emit(energy)
	var managers := get_tree().get_nodes_in_group(&"drone_manager")
	if managers.size() > 0:
		managers[0].play_all_trigger_visuals()

## 子类可 override：返回 true 则卡牌回到手牌末尾而非弃牌堆
func _should_return_to_hand(_card: CardData) -> bool:
	return false

## 子类可 override：返回额外执行次数（echo_form）
func _get_extra_plays(_card: CardData) -> int:
	return 0
