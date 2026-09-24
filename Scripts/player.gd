class_name Player extends CharacterBody2D


@onready var movement := %MoveComponent
@onready var dash := %DashComponent
@onready var direction := %DirectionComponent
@onready var animation := %AnimationComponent

var last_move_direction := Vector2.RIGHT

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	dash.dash_queued.connect(on_dash_queued)
	dash.dash_started.connect(on_dash_started)

func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector("SwimLeft", "SwimRight", "SwimUp", "SwimDown")
	
	if input_direction != Vector2.ZERO:
		last_move_direction = input_direction
	
	if Input.is_action_just_pressed("Dash"):
		dash.attempt_dash(input_direction, last_move_direction)
	dash.physics_process(delta)
	
	velocity = dash.resolve_velocity(movement, input_direction, velocity, delta)
	
	move_and_slide()
	
	direction.update(dash.resolve_facing_direction(input_direction, last_move_direction))
	animation.update_state(velocity.length())


func play_hurt() -> void: animation.play_animation(&"hurt")

func get_dash_charge_progress() -> float: return dash.get_charge_progress()

func on_dash_queued(_direction: Vector2) -> void:
	animation.play_animation(&"dash")

func on_dash_started(_direction: Vector2) -> void:
	FxManager.spawn_bubbles(position)
