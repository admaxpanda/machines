extends Node2D

## 测试脚本：左键高速脱离，右键增加球位

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		var player: Node2D = get_tree().get_first_node_in_group(&"player")
		if player:
			var context := {
				"source": player,
				"card_engine": null,
			}
			var chain := {
				"type": "multi_release",
				"count": 2,
				"interval": 0,
				"chains": [
					{ "type": "grant_invincible", "duration": 1.0 },
					{ "type": "add_card_to_draw_pile", "card_id": "dazed", "pool": "status", "engine": "attack" }
				]
			}
			Attack.execute(chain, player, context)
		return
	if event.is_action_pressed("right_click"):
		var managers := get_tree().get_nodes_in_group(&"orb_manager")
		if managers.size() > 0:
			managers[0].max_slots += 1
			print("[Test] 球位 +1，当前 %d" % managers[0].max_slots)
		return
