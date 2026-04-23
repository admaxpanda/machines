extends Node2D

## 无人机管理器：生成/销毁/触发视觉

var _drones: Array[Node2D] = []


func _ready() -> void:
	add_to_group(&"drone_manager")


func spawn_drone() -> void:
	var drone := Node2D.new()
	var script: GDScript = load("res://script/entity/drone.gd")
	drone.set_script(script)
	_drones.append(drone)
	add_child(drone)
	print("[Drone] 生成无人机 (共 %d 架)" % _drones.size())


func play_all_trigger_visuals() -> void:
	for drone in _drones:
		if is_instance_valid(drone) and drone.has_method("play_trigger_visual"):
			drone.play_trigger_visual()


func clear_all() -> void:
	for drone in _drones:
		if is_instance_valid(drone):
			drone.queue_free()
	_drones.clear()
