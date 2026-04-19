extends CharacterBody2D

@export var speed: float = 200.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()

	if velocity.length() > 1.0:
		if _sprite.animation != &"moving":
			_sprite.play(&"moving")
	else:
		if _sprite.animation != &"idle":
			_sprite.play(&"idle")

	if velocity.x < -1.0:
		_sprite.flip_h = true
	elif velocity.x > 1.0:
		_sprite.flip_h = false
