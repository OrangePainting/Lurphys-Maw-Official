class_name Player extends CharacterBody2D


@onready var movement := %MoveComponent
@onready var dash := %DashComponent
@onready var direction := %DirectionComponent
@onready var animation := %AnimationComponent
@onready var strafe := %StrafeComponent

var last_move_direction := Vector2.RIGHT

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("hi")
	dash.dash_queued.connect(on_dash_queued)
	dash.dash_started.connect(on_dash_started)
	
	# testing strafing
	#call_deferred("test_strafe")

# for real strafe code, loop through nodes in Strafe group, and find nearest
func test_strafe() -> void:
	print(get_tree().get_first_node_in_group("StrafeTarget"))
	if get_tree().get_first_node_in_group("StrafeTarget"):
		set_strafe_target(get_tree().get_first_node_in_group("StrafeTarget"))


func _physics_process(delta: float) -> void:
	print("hi")
	var input_direction := Input.get_vector("SwimLeft", "SwimRight", "SwimUp", "SwimDown")
	
	if input_direction != Vector2.ZERO:
		last_move_direction = input_direction
	
	if Input.is_action_just_pressed("Dash"):
		dash.attempt_dash(input_direction, last_move_direction)
	dash.physics_process(delta)
	
	velocity = dash.resolve_velocity(movement, input_direction, velocity, delta)
	move_and_slide()
	
	var is_strafing : bool = strafe.has_target()
	var dash_facing = dash.get_facing_dir_override()
	var is_dash_facing = (dash_facing != Vector2.ZERO)
	
	# get dashing direction override if dashing or about to, otherwise it stays as Vector2.ZERO
	var facing : Vector2
	if is_dash_facing:
		facing = dash_facing
	elif is_strafing:
		facing = strafe.get_facing_dir(global_position)
	else:
		facing = input_direction if input_direction != Vector2.ZERO else last_move_direction
	
	direction.update(facing, is_strafing and not is_dash_facing, animation)
	animation.update_state(velocity.length(), is_strafing)


func play_hurt() -> void: animation.play_animation(&"hurt")

func get_dash_charge_progress() -> float: return dash.get_charge_progress()

func set_strafe_target(target: Node2D) -> void: strafe.set_target(target)

func remove_strafe_target() -> void: strafe.remove_target()


func on_dash_queued(_direction: Vector2) -> void:
	animation.play_animation(&"dash")


func on_dash_started(_direction: Vector2) -> void:
	FxManager.spawn_bubbles(position)
