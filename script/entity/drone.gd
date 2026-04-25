extends Node2D

## 无人机实体：惯性追踪玩家，触发时播放视觉反馈

const FOLLOW_ACCEL := 8.0
const DAMPING := 3.0
const BEHIND_OFFSET := -22.0
const Y_OFFSET_RANGE := 12.0

var _velocity := Vector2.ZERO
var _y_offset := 0.0
var _behind_current: float = BEHIND_OFFSET
var _sprite: AnimatedSprite2D


func _ready() -> void:
	top_level = true
	z_index = 0
	_y_offset = randf_range(-Y_OFFSET_RANGE, Y_OFFSET_RANGE)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = load("res://sprite/drone.tres")
	_sprite.play(&"idle")
	add_child(_sprite)
	var player := _get_player()
	if player:
		global_position = player.global_position


func _process(delta: float) -> void:
	var player := _get_player()
	if not player:
		return
	var _sign: float = -1.0 if player._sprite.flip_h else 1.0
	var _moving: bool = player.velocity.length() > 10.0
	var offset_target: float = _sign * abs(BEHIND_OFFSET) * (1.0 if _moving else -1.0)
	_behind_current = move_toward(_behind_current, offset_target, 100.0 * delta)
	var target := player.global_position + Vector2(_behind_current, _y_offset)
	var to_target := target - global_position
	_velocity += to_target * FOLLOW_ACCEL * delta
	_velocity *= maxf(0.0, 1.0 - DAMPING * delta)
	global_position += _velocity * delta
	# 朝向跟随无人机自身速度
	if _velocity.x > 30.0:
		_sprite.flip_h = false
	elif _velocity.x < -30.0:
		_sprite.flip_h = true
	# 动画切换
	if _velocity.length() > 20.0:
		if _sprite.animation != &"moving":
			_sprite.play(&"moving")
	else:
		if _sprite.animation != &"idle":
			_sprite.play(&"idle")


func play_trigger_visual() -> void:
	if not _sprite or not is_instance_valid(_sprite):
		return
	var copy := AnimatedSprite2D.new()
	copy.sprite_frames = _sprite.sprite_frames
	copy.play(_sprite.animation)
	copy.flip_h = _sprite.flip_h
	copy.global_position = global_position
	copy.scale = Vector2(_sprite.scale)
	copy.modulate.a = 1.0
	copy.z_index = 0
	copy.top_level = true
	add_child(copy)
	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(copy, "scale", copy.scale * 1.5, 0.2)
	tween.tween_property(copy, "modulate:a", 0.5, 0.2)
	tween.chain().tween_callback(copy.queue_free)


func _get_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		return players[0] as CharacterBody2D
	return null
