extends Node

# 攻击卡引擎
# 管理牌堆（抽牌堆/手牌/弃牌堆/消耗堆）、能量、自动打出

signal energy_changed(new_energy: int)
signal hand_changed()

var draw_pile: Array = []          ## Array[AttackCardData] 抽牌堆
var hand: Array = []               ## Array[AttackCardData] 手牌
var discard_pile: Array = []       ## Array[AttackCardData] 弃牌堆
var exhaust_pile: Array = []       ## Array[AttackCardData] 消耗堆
var source: Node2D                  ## 玩家引用（攻击出发点）

var energy: int = 0                ## 当前能量
var energy_per_turn: int = 3       ## 每回合获得能量
var hand_limit: int = 10           ## 手牌上限
var draw_per_turn: int = 5         ## 每回合抽牌数
var turn_duration: float = 1.0     ## 回合总时长（秒）
var play_interval: float = 0.1     ## 打牌间隔（秒）
var _running: bool = false         ## 回合循环是否运行中

## 初始化：传入卡组，洗牌放入抽牌堆
func initialize(deck: Array) -> void:
	draw_pile = deck.duplicate()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	energy = 0
	draw_pile.shuffle()

## 开始回合：获得能量，抽牌
func start_turn() -> void:
	energy += energy_per_turn
	energy_changed.emit(energy)
	draw_cards(draw_per_turn)

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

## 自动打出一张牌：能量够则打出，不够则跳过，返回是否实际打出
func auto_play() -> bool:
	if hand.is_empty():
		return false
	var card: AttackCardData = hand[0]
	if card.cost > energy:
		return false
	energy -= card.cost
	energy_changed.emit(energy)
	hand.pop_front()
	if card.exhaust:
		exhaust_pile.append(card)
	else:
		discard_pile.append(card)
	hand_changed.emit()
	var context := {
		"source": source,
		"card_engine": self,
	}
	CardResolver.play(card, context)
	return true

## 回合结束：弃掉手牌剩余
func end_turn() -> void:
	while not hand.is_empty():
		discard_pile.append(hand.pop_back())

## 弃牌堆洗入抽牌堆
func _shuffle_discard_into_draw() -> void:
	draw_pile = discard_pile.duplicate()
	discard_pile.clear()
	draw_pile.shuffle()

## 启动回合循环
func run_turns() -> void:
	_running = true
	while _running:
		start_turn()
		var elapsed := 0.0
		while not hand.is_empty() and elapsed < turn_duration:
			await get_tree().create_timer(play_interval).timeout
			elapsed += play_interval
			if not auto_play():
				break
		end_turn()
		hand_changed.emit()
		var remaining := turn_duration - elapsed
		if remaining > 0.0:
			await get_tree().create_timer(remaining).timeout

## 停止回合循环
func stop_turns() -> void:
	_running = false
