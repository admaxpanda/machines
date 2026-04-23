extends CardEngine

## 攻击卡引擎：自动打出循环

var turn_duration: float = 1.0     ## 回合总时长（秒）
var play_interval: float = 0.1     ## 打牌间隔（秒）
var _running: bool = false
var turn_progress: float = 0.0     ## 当前回合进度 0~1
var skill_card_engine: Node        ## SkillCardEngine 引用
var _feral_remaining: int = 0      ## 本回合剩余 feral 回手次数
var _echo_remaining: int = 0       ## 本回合剩余 echo_form 双倍次数
var pending_energy: int = 0        ## 等离子等被动暂存的能量，下回合生效
var _attacks_played_this_turn: int = 0

func _ready() -> void:
	add_to_group(&"card_engine")
	energy_per_turn = 3
	hand_limit = 10
	draw_per_turn = 5

## 开始回合：获得能量，抽牌，同步触发技能回合
func start_turn() -> void:
	if source and "drill_count" in source:
		source.drill_count = _attacks_played_this_turn
	_attacks_played_this_turn = 0
	energy = energy_per_turn + pending_energy
	pending_energy = 0
	energy_changed.emit(energy)
	_feral_remaining = _count_ability(&"feral")
	_echo_remaining = _count_ability(&"echo_form")
	draw_cards(draw_per_turn)
	if skill_card_engine:
		skill_card_engine.start_turn()
	_check_abilities()
	_check_fusion()
	_check_glass_channel()
	_check_chaos()
	_check_extra_draw()
	_check_extra_attack_energy()

## 额外抽牌：回合开始时额外抽攻击牌
func _check_extra_draw() -> void:
	if not source:
		return
	var bc := _get_player_buff_container()
	if not bc or not bc.has_buff(&"extra_draw"):
		return
	var extra: int = bc.get_buff_stacks(&"extra_draw")
	if extra > 0:
		draw_cards(extra)

## 额外攻击能量：回合开始时获得额外攻击能量
func _check_extra_attack_energy() -> void:
	if not source:
		return
	var bc := _get_player_buff_container()
	if not bc or not bc.has_buff(&"extra_attack_energy"):
		return
	var extra: int = bc.get_buff_stacks(&"extra_attack_energy")
	if extra > 0:
		energy += extra
		energy_changed.emit(energy)

## 混沌：回合开始时获得随机充能球
func _check_chaos() -> void:
	if not source:
		return
	var bc := _get_player_buff_container()
	if not bc or not bc.has_buff(&"chaos"):
		return
	var stacks: int = bc.get_buff_stacks(&"chaos")
	var managers := get_tree().get_nodes_in_group(&"orb_manager")
	if managers.size() > 0:
		var orb_types: Array[StringName] = [&"lightning", &"frost", &"dark", &"glass", &"plasma"]
		for i in stacks:
			managers[0].channel_orb(orb_types[randi() % orb_types.size()])

## 聚变：回合开始时获得plasma充能球
func _check_fusion() -> void:
	if not source:
		return
	var bc := _get_player_buff_container()
	if not bc or not bc.has_buff(&"fusion"):
		return
	var stacks: int = bc.get_buff_stacks(&"fusion")
	var managers := get_tree().get_nodes_in_group(&"orb_manager")
	if managers.size() > 0:
		for i in stacks:
			managers[0].channel_orb(&"plasma")

## 玻璃充能：回合开始时获得glass充能球
func _check_glass_channel() -> void:
	if not source:
		return
	var bc := _get_player_buff_container()
	if not bc or not bc.has_buff(&"glass_channel"):
		return
	var stacks: int = bc.get_buff_stacks(&"glass_channel")
	var managers := get_tree().get_nodes_in_group(&"orb_manager")
	if managers.size() > 0:
		for i in stacks:
			managers[0].channel_orb(&"glass")

## 自动打出一张牌
func _play_card(card: CardData) -> void:
	super._play_card(card)
	_attacks_played_this_turn += 1

func auto_play() -> bool:
	if hand.is_empty():
		return false
	var card: CardData = hand[0]
	if card.cost > energy or card.unplayable:
		return false
	_play_card(card)
	return true

## 回合结束：弃掉手牌剩余
func end_turn() -> void:
	while not hand.is_empty():
		var card: CardData = hand.pop_back()
		if card.ethereal:
			exhaust_pile.append(card)
		else:
			discard_pile.append(card)
	hand_changed.emit()

## 启动回合循环
func run_turns() -> void:
	_running = true
	while _running:
		start_turn()
		var elapsed := 0.0
		turn_progress = 0.0
		while elapsed < turn_duration:
			await get_tree().create_timer(play_interval).timeout
			elapsed += play_interval
			turn_progress = clampf(elapsed / turn_duration, 0.0, 1.0)
			if not hand.is_empty():
				auto_play()
		end_turn()
		await _trigger_hailstorm()
		await _trigger_consuming_shadow()
		await _trigger_orb_passives()
		_tick_buffs()

## 停止回合循环
func stop_turns() -> void:
	_running = false

## 冰雹风暴：回合结束时检测冰霜球，释放冰雹
func _trigger_hailstorm() -> void:
	var hail_count := _count_ability(&"hailstorm")
	if hail_count <= 0:
		return
	var managers := get_tree().get_nodes_in_group(&"orb_manager")
	if managers.is_empty():
		return
	var orb_mgr = managers[0]
	var has_frost := false
	for slot in orb_mgr.slots:
		if slot.data.id == &"frost":
			has_frost = true
			break
	if not has_frost:
		return
	var player := source
	if not player:
		return
	for i in hail_count:
		var chain := {
			"type": "fall",
			"t": 0.35,
			"max_offset_x": 30,
			"start_height_h": 120,
			"target": "random_enemy",
			"animation": "res://sprite/hailstorm.tres",
			"on_land": [{
				"type": "aoe_detect",
				"shape": "circle",
				"radius": 25,
				"origin": "parent",
				"target": "player",
				"offset": 0,
				"rotation": 0,
				"animation": "res://sprite/hailstorm_hit.tres",
				"lifetime": 0.3,
				"on_detect": [{ "type": "deal_damage", "value": 6 }]
			}]
		}
		Attack.execute(chain, player, {"source": player})
		await get_tree().create_timer(0.1).timeout

## 吞噬暗影：回合结束时激发最左侧充能球
func _trigger_consuming_shadow() -> void:
	var shadow_count := _count_ability(&"consuming_shadow")
	if shadow_count <= 0:
		return
	var managers := get_tree().get_nodes_in_group(&"orb_manager")
	if managers.is_empty():
		return
	var orb_mgr = managers[0]
	for i in shadow_count:
		if orb_mgr.slots.is_empty():
			break
		orb_mgr.evoke_first()
		await get_tree().create_timer(0.1).timeout

## 触发所有充能球被动
func _trigger_orb_passives() -> void:
	var managers := get_tree().get_nodes_in_group(&"orb_manager")
	if managers.size() > 0:
		await managers[0].trigger_all_passives()

## 回合结束 tick 所有 buff
func _tick_buffs() -> void:
	for bc in get_tree().get_nodes_in_group(&"buff_container"):
		bc.tick_turn()

## 回合开始时检查能力效果
func _check_abilities() -> void:
	var player := source
	if not player or not "abilities" in player:
		return
	var managers := get_tree().get_nodes_in_group(&"orb_manager")
	var orb_mgr = managers[0] if managers.size() > 0 else null
	for a in player.abilities:
		match a.id:
			&"spinner":
				if orb_mgr:
					orb_mgr.channel_orb(&"glass")
			&"loop":
				if orb_mgr and orb_mgr.slots.size() > 0:
					var last_idx: int = orb_mgr.slots.size() - 1
					if last_idx < orb_mgr._visuals.size():
						orb_mgr._play_passive_visual(last_idx)
					var last_pos: Vector2 = orb_mgr._visuals[last_idx].global_position if last_idx < orb_mgr._visuals.size() else Vector2.ZERO
					orb_mgr._trigger_passive(orb_mgr.slots[last_idx], last_pos)
					orb_mgr._refresh_labels()
			&"coolant":
				if orb_mgr and orb_mgr.slots.size() > 0:
					var unique_types: Dictionary = {}
					for slot in orb_mgr.slots:
						unique_types[slot.data.id] = true
					var shield_amount: int = unique_types.size() * 2
					if shield_amount > 0:
						var bc := _get_player_buff_container()
						if bc:
							bc.add_buff(&"shield", shield_amount, 1)
			&"hailstorm":
				if orb_mgr:
					orb_mgr.channel_orb(&"frost")
			&"storm":
				if orb_mgr:
					orb_mgr.channel_orb(&"lightning")
			&"consuming_shadow":
				if orb_mgr:
					orb_mgr.channel_orb(&"dark")

## feral: 每回合前 N 张 0 费卡回到手牌末尾（N = 装备数）
func _should_return_to_hand(card: CardData) -> bool:
	if _feral_remaining <= 0 or card.cost != 0:
		return false
	_feral_remaining -= 1
	return true

## echo_form: 每回合前 N 张攻击牌额外执行一次（N = 装备数）
func _get_extra_plays(_card: CardData) -> int:
	if _echo_remaining <= 0:
		return 0
	_echo_remaining -= 1
	return 1

## 统计玩家已装备某能力的数量
func _count_ability(ability_id: StringName) -> int:
	var player := source
	if not player or not "abilities" in player:
		return 0
	var count := 0
	for a in player.abilities:
		if a.id == ability_id:
			count += 1
	return count

func _get_player_buff_container() -> Node:
	if not source:
		return null
	for child in source.get_children():
		if child.is_in_group(&"buff_container"):
			return child
	return null
