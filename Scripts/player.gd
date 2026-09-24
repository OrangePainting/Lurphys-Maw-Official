class_name Player extends CharacterBody2D

@export_group("Movement Properties")
@export var move_speed := 300.0
@export var acceleration := 300.0
@export var friction := 1200.0

@export_group("Dash Properties", "dash")
@export var dash_distance := 75.0
@export var dash_duration := 0.15 # sec
@export var dash_delay := 0.25 # sec
@export var dash_cooldown := 2.5 # sec
@export var dash_max_charges := 1 # later don't make this an export variable, as this could be an upgrade

@onready var sprite := %Sprite
@onready var collision_shape := %CollisionShape2D

@onready var movement := %MoveComponent
@onready var dash := %DashComponent
@onready var direction := %DirectionComponent
@onready var animation := %AnimationComponent

var last_move_direction := Vector2.RIGHT

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	movement.setup(move_speed, acceleration, friction)
	
	dash.setup(dash_distance, dash_duration, dash_delay, dash_cooldown, dash_max_charges)
	dash.dash_queued.connect(on_dash_queued)
	dash.dash_started.connect(on_dash_started)
	
	direction.setup(sprite, collision_shape, sprite.rotation)
	
	animation.setup(sprite)


func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector("SwimLeft", "SwimRight", "SwimUp", "SwimDown")
	
	if input_direction != Vector2.ZERO:
		last_move_direction = input_direction
	
	if Input.is_action_just_pressed("Dash"):
		dash.attempt_dash(input_direction, last_move_direction)
	
	dash.physics_process(delta)
	
	if dash.is_dashing: velocity = dash.get_velocity()
	elif dash.is_queued: velocity = movement.decelerate(velocity, delta)
	else: velocity = movement.process(input_direction, velocity, delta)
	
	move_and_slide()
	
	var facing_direction: Vector2
	if dash.is_dashing: facing_direction = dash.direction
	elif dash.is_queued: facing_direction = dash.dash_direction
	else: facing_direction = input_direction
	
	if facing_direction == Vector2.ZERO:
		facing_direction = last_move_direction
	direction.update(facing_direction)
	
	animation.update_state(velocity.length())


func play_hurt() -> void: animation.play_animation(&"hurt")

func get_dash_charge_progress() -> float: return dash.get_charge_progress()

func on_dash_queued(_direction: Vector2) -> void:
	animation.play_animation(&"dash")

func on_dash_started(_direction: Vector2) -> void:
	FxManager.spawn_bubbles(position)
