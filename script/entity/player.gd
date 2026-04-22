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
var abilities: Array = []  ## Array[AbilityCardData] 已装备的被动能力
var buffer_charges: int = 0  ## buffer 能力免伤次数

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _shield_icon: TextureRect
var _shield_label: Label

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
	buff_container.buffs_changed.connect(_update_shield_display)
	_create_shield_ui()

func take_damage(amount: int) -> void:
	if buffer_charges > 0:
		buffer_charges -= 1
		return
	var remaining: int = buff_container.apply_shield_damage(amount)
	hp = maxi(hp - remaining, 0)
	health_changed.emit(hp, max_hp)

func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	health_changed.emit(hp, max_hp)

func heal_boss_reward() -> void:
	var lost := max_hp - hp
	heal(int(lost * 0.8))

func add_ability(ability: AbilityCardData) -> void:
	abilities.append(ability)
	match ability.id:
		&"defragment":
			buff_container.add_buff(&"focus", 1, -1)
		&"capacitor":
			var managers := get_tree().get_nodes_in_group(&"orb_manager")
			if managers.size() > 0:
				managers[0].max_slots += 2
		&"machine_learning":
			var engines := get_tree().get_nodes_in_group(&"card_engine")
			if engines.size() > 0:
				engines[0].draw_per_turn += 1
		&"biased_cognition":
			buff_container.add_buff(&"focus", 4, -1)
			buff_container.add_buff(&"biased_cognition", 4, -1)
		&"bulk_up":
			var managers := get_tree().get_nodes_in_group(&"orb_manager")
			if managers.size() > 0:
				managers[0].max_slots = maxi(managers[0].max_slots - 1, 1)
			buff_container.add_buff(&"strength", 2, -1)
			buff_container.add_buff(&"dexterity", 2, -1)
	print("[Ability] 装备 %s" % ability.ability_name)

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

func _create_shield_ui() -> void:
	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	container.position = Vector2(-24, 4)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_shield_icon = TextureRect.new()
	_shield_icon.texture = load("res://sprite/block_icon.png")
	_shield_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_shield_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_icon.visible = false
	container.add_child(_shield_icon)

	_shield_label = Label.new()
	_shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shield_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shield_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_label.visible = false
	_shield_label.add_theme_font_size_override("font_size", 10)
	_shield_label.add_theme_color_override("font_color", Color.WHITE)
	_shield_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_shield_label.add_theme_constant_override("outline_size", 1)
	container.add_child(_shield_label)

	add_child(container)

func _update_shield_display() -> void:
	var shield_amount: int = buff_container.get_buff_stacks(&"shield")
	if shield_amount > 0:
		_shield_icon.visible = true
		_shield_label.visible = true
		_shield_label.text = str(shield_amount)
	else:
		_shield_icon.visible = false
		_shield_label.visible = false
