class_name CardResolver
extends RefCounted

## 卡牌结算器：负责寻找目标位置，将卡牌转交给效果系统执行

static func play(card: AttackCardData, context: Dictionary) -> void:
	var source: Node2D = context.get("source")
	if not source:
		return
	if card.chain.is_empty():
		return
	if not context.has("target_position"):
		var pos := _find_nearest_enemy_position(source)
		if pos != Vector2.ZERO or true:
			context["target_position"] = pos
	Attack.execute(card.chain, source, context)

static func _find_nearest_enemy_position(source: Node2D) -> Vector2:
	var enemies := source.get_tree().get_nodes_in_group(&"enemy")
	var nearest: Node2D = null
	var min_dist: float = INF
	for e in enemies:
		if not e is Node2D:
			continue
		var dist := source.global_position.distance_to(e.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = e
	return nearest.global_position if nearest else source.global_position
