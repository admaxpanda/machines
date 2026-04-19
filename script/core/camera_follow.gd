extends Camera2D

## 相机跟随：平滑追踪目标，产生轻微滞后感

@export var follow_speed: float = 6.0
@export var target_path: NodePath

var _target: Node2D

func _ready() -> void:
	if target_path:
		_target = get_node(target_path)

func _physics_process(delta: float) -> void:
	if not _target:
		return
	global_position = global_position.lerp(_target.global_position, follow_speed * delta)
