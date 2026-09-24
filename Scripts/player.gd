extends CharacterBody2D


@export_group("Movement Properties")
@export var move_speed: float = 300.0
@export var acceleration: float = 300.0
@export var friction: float = 1200.0


@export_group("Dash Properties", "dash")
@export var dash_distance: float = 75.0
@export var dash_duration: float = 0.15 # sec
@export var dash_delay: float = 0.25 # sec
@export var dash_cooldown: float = 2.5 # sec
@export var dash_max_charges: int = 1 # later don't make this an export variable, as this could be an upgrade


@onready var sprite := %Sprite
@onready var collision_shape := %CollisionShape2D


var facing_angle: float = 0.0
var last_move_direction: Vector2 = Vector2.RIGHT


var is_rushing: bool = false
var state_must_play: bool = false
var current_animation: StringName = &"idle"


var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.RIGHT
var dash_timer: float = 0.0


var is_dash_queued: bool = false
var dash_delay_timer: float = 0.0
var queued_dash_direction: Vector2 = Vector2.RIGHT

var dash_charges: int
var dash_recharge_timer: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	facing_angle = sprite.rotation
	dash_charges = dash_max_charges


func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector("SwimLeft", "SwimRight", "SwimUp", "SwimDown")
	
	if input_direction != Vector2.ZERO:
		last_move_direction = input_direction
	
	update_dash_recharge(delta)
	
	if Input.is_action_just_pressed("Dash") and dash_charges > 0 and \
		not is_dashing and not is_dash_queued:
			queue_dash(input_direction)
	
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
	
	elif is_dash_queued:
		dash_delay_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		if dash_delay_timer <= 0.0:
			start_dash(queued_dash_direction)
		
	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	move_and_slide()
	
	var facing_direction := dash_direction if is_dashing else (queued_dash_direction if is_dash_queued else input_direction)
	if facing_direction == Vector2.ZERO:
		facing_direction = last_move_direction
	
	update_facing_direction(facing_direction)
	
	update_movement_animation()
	rotate_collision_shape()


func update_facing_direction(direction: Vector2):
	facing_angle = direction.angle()
	
	sprite.flip_h = (cos(facing_angle) < 0.0)
	sprite.rotation = atan2(sin(facing_angle) * (-1.0 if sprite.flip_h else 1.0), abs(cos(facing_angle)))


func rotate_collision_shape() -> void:
	collision_shape.rotation = sprite.rotation + PI / 2

func update_dash_recharge(delta: float) -> void:
	if dash_charges >= dash_max_charges: return
	
	dash_recharge_timer -= delta
	if dash_recharge_timer <= 0.0:
		dash_charges += 1
		dash_recharge_timer = dash_cooldown if dash_charges < dash_max_charges else 0.0


func queue_dash(input_direction: Vector2) -> void:
	if dash_charges >= dash_max_charges:
		dash_recharge_timer = dash_cooldown
	dash_charges -= 1
	
	queued_dash_direction = (input_direction if input_direction != Vector2.ZERO else last_move_direction).normalized()
	is_dash_queued = true
	dash_delay_timer = dash_delay
	play_dash()


func start_dash(direction: Vector2) -> void:
	is_dash_queued = false
	dash_direction = direction
	is_dashing = true
	dash_timer = dash_duration
	velocity = dash_direction * (dash_distance / dash_duration)
	FxManager.spawn_bubbles(position)


func get_dash_charge_progress() -> float:
	if dash_charges >= dash_max_charges:
		return 1.0
	else:
		return clamp(1.0 - (dash_recharge_timer / dash_cooldown), 0.0, 1.0)


func update_movement_animation() -> void:
	if state_must_play: return # 1 time animation must play  first
	
	var next_animation: StringName = &"idle"
	if velocity.length() > 5.0:
		next_animation = &"rush" if is_rushing else &"swim"
	
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
