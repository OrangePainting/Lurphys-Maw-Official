class_name Player extends CharacterBody2D


@onready var movement := %MoveComponent
@onready var dash := %DashComponent
@onready var direction := %DirectionComponent
@onready var animation := %AnimationComponent
@onready var strafe := %StrafeComponent

var last_move_direction := Vector2.RIGHT


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	dash.dash_queued.connect(on_dash_queued)
	dash.dash_started.connect(on_dash_started)
	
	# testing strafing
	call_deferred("test_strafe")

# for real strafe code, loop through nodes in Strafe group, and find nearest
func test_strafe() -> void:
	print(get_tree().get_first_node_in_group("Strafe"))
	if get_tree().get_first_node_in_group("Strafe"):
		set_strafe_target(get_tree().get_first_node_in_group("Strafe"))


func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector("SwimLeft", "SwimRight", "SwimUp", "SwimDown")
	
	if input_direction != Vector2.ZERO:
		last_move_direction = input_direction
	
	if Input.is_action_just_pressed("Dash"):
		dash.attempt_dash(input_direction, last_move_direction)
	dash.physics_process(delta)
	
	velocity = dash.resolve_velocity(movement, input_direction, velocity, delta)
	move_and_slide()
	
	var is_strafing : bool = strafe.has_target() and not dash.is_active()
	
	# get dashing direction override if dashing or about to, otherwise it stays as Vector2.ZERO
	var facing : Vector2 = dash.get_facing_dir_override()
	if facing == Vector2.ZERO:
		if is_strafing:
			facing = strafe.get_facing_dir(global_position)
		else:
			if input_direction != Vector2.ZERO: facing = input_direction
			else: facing = last_move_direction

	direction.update(facing, is_strafing)
	animation.update_state(velocity.length(), is_strafing)


func play_hurt() -> void: animation.play_animation(&"hurt")

func get_dash_charge_progress() -> float: return dash.get_charge_progress()

func set_strafe_target(target: Node2D) -> void: strafe.set_target(target)

func remove_strafe_target() -> void: strafe.remove_target()


func on_dash_queued(_direction: Vector2) -> void:
	animation.play_animation(&"dash")


func on_dash_started(_direction: Vector2) -> void:
	FxManager.spawn_bubbles(position)
