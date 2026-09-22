extends CharacterBody2D

@export_group("Base Movement Properties")
@export var base_speed: float = 300.0
@export var rush_speed_modifier: float = 100.0
@export var turn_speed: float = 12.0
@export var base_acceleration: float = 300.0
@export var base_friction: float = 1200.0

@export_group("Dash Properties", "dash")
@export var dash_velocity: float = 75.0
@export var dash_duration: float = 0.15 # sec
@export var dash_cooldown: float = 1.0 # sec
@export var dash_delay: float = 0.5 # sec

@export_group("Strafe Properties", "strafe")
@export var strafe_turn_speed: float = 20.0

# targeting / lock-on system (needs a target)
# potentially, we could add a camera system that shows both
# player and target when they're in the same area
var target: Node2D = null
@onready var sprite := %Sprite
@onready var collision_shape := %CollisionShape2D

var facing_angle: float = 0.0
var last_move_direction: Vector2 = Vector2.RIGHT

var is_rushing: bool = false
var is_strafing: bool = false
var state_must_play: bool = false
var current_animation: StringName = &"idle"

var acceleration: float = base_acceleration
var friction: float = base_friction
var move_speed: float = 300.0

var is_dashing: bool = false
var is_in_dash_startup: bool = false
var dash_direction: Vector2 = Vector2.RIGHT
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	facing_angle = sprite.rotation

func _physics_process(delta: float) -> void:
	# Better readable way to do input collection?
	var input_direction := Input.get_vector("SwimLeft", "SwimRight", "SwimUp", "SwimDown")
	if input_direction != Vector2.ZERO:
		last_move_direction = input_direction
	
	update_dash_timer(delta)
	handle_dash_input(input_direction)
	
	is_rushing = Input.is_action_pressed("Rush")
	if is_rushing:
		move_speed = base_speed + rush_speed_modifier
	else:
		move_speed = base_speed
	
	is_strafing = (target != null and is_instance_valid(target))
	
	update_velocity(input_direction, delta)
	update_movement_animation()
	move_and_slide()
	
	update_facing_angle(input_direction, delta)
	rotate_collision_shape()

func update_facing_angle(input_direction: Vector2, delta: float) -> void:
	var target_angle: float
	var current_turn_speed: float
	
	if is_strafing:
		target_angle = (target.global_position - global_position).angle() - PI / 2
		current_turn_speed = strafe_turn_speed
	elif input_direction != Vector2.ZERO:
		target_angle = input_direction.angle() - PI / 2
		current_turn_speed = turn_speed
	else:
		target_angle = (get_global_mouse_position() - global_position).angle() - PI / 2
		current_turn_speed = turn_speed
	
	var t := 1.0 - exp(-current_turn_speed * delta)
	facing_angle = fposmod(lerp_angle(facing_angle, target_angle, t), TAU)
	
	sprite.rotation = facing_angle + current_sprite_offset()
	sprite.scale = Vector2(2.0 if facing_right() else -2.0, 2.0)

func current_sprite_offset() -> float:
	var deg := 0.0
	match current_animation:
		&"idle": deg = 0.0
		&"swim": deg = 90
		&"rush": deg = 90
		&"dash": deg = 90
		&"hurt": deg = 0
	return deg_to_rad(deg)

func facing_right() -> bool:
	return cos(facing_angle) >= 0.0

func update_dash_timer(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0: is_dashing = false

func handle_dash_input(input_direction: Vector2) -> void:
	if not Input.is_action_just_pressed("Dash"): return
	if is_dashing or is_in_dash_startup or dash_cooldown_timer > 0.0:
		return
	start_dash(input_direction)

func update_velocity(input_direction: Vector2, delta: float) -> void:
	if is_dashing or is_in_dash_startup: return
	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

func rotate_collision_shape() -> void:
	collision_shape.rotation = sprite.rotation + PI / 2

func start_dash(input_direction: Vector2) -> void:
	is_in_dash_startup = true
	play_dash()
	
	var dash_start_direction: Vector2
	if input_direction != Vector2.ZERO:
		dash_start_direction = input_direction
	else:
		dash_start_direction = last_move_direction
	
	await get_tree().create_timer(dash_delay).timeout
	
	FxManager.spawn_bubbles(position)
	dash_direction = dash_start_direction
	is_dashing = true
	is_in_dash_startup = false
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	velocity = dash_direction * dash_velocity

func get_dash_cooldown_state() -> float:
	return clamp(dash_cooldown_timer / dash_cooldown, 0.0, 1.0)

func update_movement_animation() -> void:
	if state_must_play: return # 1 time animation must play  first
	
	var next_animation: StringName = &"idle"
	if velocity.length() > 5.0:
		next_animation = &"rush" if is_rushing else &"swim"
	
	if next_animation != current_animation:
		current_animation = next_animation
	sprite.play(current_animation)


func play_dash() -> void:
	current_animation = &"dash"
	state_must_play = true
	sprite.play(current_animation)

func play_hurt() -> void:
	current_animation = &"hurt"
	state_must_play = true
	sprite.play(current_animation)

func _on_sprite_animation_finished() -> void:
	if current_animation == &"dash" or current_animation == &"hurt":
		state_must_play = false
		current_animation = &"idle" # changed in update movement animation in next frame
