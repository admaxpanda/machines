extends CharacterBody2D

@export var speed: float = 200.0

signal health_changed(current: int, maximum: int)
signal xp_changed(current_xp: int, xp_to_next: int)
signal leveled_up(new_level: int)

var hp: int = 60
var max_hp: int = 75
var xp: int = 0
var level: int = 1
var xp_to_next: int = 5
var buff_container: Node   ## BuffContainer 引用

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	var orb_manager := Node2D.new()
	var orb_script: GDScript = load("res://script/core/orb/orb_manager.gd")
	orb_manager.set_script(orb_script)
	orb_manager.add_to_group(&"orb_manager")
	add_child(orb_manager)

	buff_container = Node.new()
	var buff_script: GDScript = load("res://script/core/buff/buff_container.gd")
	buff_container.set_script(buff_script)
	buff_container.add_to_group(&"buff_container")
	add_child(buff_container)

func take_damage(amount: int) -> void:
	var remaining: int = buff_container.apply_shield_damage(amount)
	hp = maxi(hp - remaining, 0)
	health_changed.emit(hp, max_hp)

func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	health_changed.emit(hp, max_hp)

func heal_boss_reward() -> void:
	var lost := max_hp - hp
	heal(int(lost * 0.8))

func add_xp(amount: int) -> void:
	xp += amount
	xp_changed.emit(xp, xp_to_next)
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = level * 5
		leveled_up.emit(level)
		xp_changed.emit(xp, xp_to_next)

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
