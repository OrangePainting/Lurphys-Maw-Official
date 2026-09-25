extends CharacterBody2D

@export_group("Movement Properties")
@export var base_speed: float = 300.0
@export var rush_speed_modifier = 100.0
@export var turn_speed: float = 12.0
@export var base_acceleration: float = 300.0
@export var base_friction: float = 1200.0

@export_group("Dash Properties", "dash")
@export var dash_velocity: float = 75.0
@export var dash_duration: float = 0.15 # sec
@export var dash_cooldown: float = 1.0 # sec

@onready var sprite := %Sprite
@onready var collision_shape := %CollisionShape2D

var facing_angle: float = 0.0
var last_move_direction: Vector2 = Vector2.RIGHT

var is_rushing: bool = false
var state_must_play: bool = false
var current_animation: StringName = &"idle"

var acceleration: float = base_acceleration
var friction: float = base_friction
var move_speed: float = 300.0
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.RIGHT
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0

func _ready() -> void:
	facing_angle = sprite.rotation

func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector("SwimLeft", "SwimRight", "SwimUp", "SwimDown")
	
	if input_direction != Vector2.ZERO: last_move_direction = input_direction
	
	if dash_cooldown_timer > 0.0: dash_cooldown_timer -= delta
	
	if Input.is_action_just_pressed("Dash"):
		if not is_dashing and dash_cooldown_timer <= 0.0:
			start_dash(input_direction)
	
	if Input.is_action_pressed("Rush"):
		is_rushing = true
	else :
		is_rushing = false
	
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0: is_dashing = false
	elif input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	update_movement_animation()
	
	move_and_slide()
	
	var mousePosRelToDiver = get_global_mouse_position().x - global_position.x
	var target_angle = (get_global_mouse_position() - global_position).angle()
	
	if input_direction == Vector2.ZERO:
		if mousePosRelToDiver < 0:
			## to the left
			facing_angle = lerp_angle(facing_angle, target_angle - PI/2, turn_speed * delta)
		else:
			## to the right
			facing_angle = lerp_angle(facing_angle, target_angle - PI/2 , turn_speed * delta)
		if facing_angle < PI:
			sprite.scale = Vector2(-2,2)
		else:
			sprite.scale = Vector2(2,2)
	else:
		if mousePosRelToDiver < 0:
			sprite.scale = Vector2(2,-2)
		else:
			sprite.scale = Vector2(2,2)
		facing_angle = lerp_angle(facing_angle, target_angle, turn_speed * delta)
	facing_angle = fposmod(facing_angle, TAU)
	
	
	sprite.rotation = facing_angle
	if is_rushing:
		move_speed = base_speed + rush_speed_modifier
	else:
		move_speed = base_speed
	rotate_collision_shape()



func rotate_collision_shape() -> void:
	collision_shape.rotation = sprite.rotation + PI / 2

func start_dash(input_direction: Vector2) -> void:
	play_dash()
	await get_tree().create_timer(.5).timeout
	FxManager.spawn_bubbles(position + Vector2(5,5))
	dash_direction = (input_direction)
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	velocity = dash_direction * dash_velocity

func get_dash_cooldown_state() -> float:
	return clamp(dash_cooldown_timer / dash_cooldown, 0.0, 1.0)

func update_movement_animation() -> void:
	if state_must_play: return # 1 time animation must play  first
	
	var next_animation: StringName = &"idle"
	if velocity.length() > 5.0: next_animation = &"rush" if is_rushing else &"swim"
	
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
