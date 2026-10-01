class_name Player extends CharacterBody2D

#region Signals
signal dash_queued(direction: Vector2)
signal dash_started(direction: Vector2)
signal dash_ended()
signal player_hurt()
#endregion

#region Exports
@export_group("Movement")
@export var speed := 300.0
@export var acceleration := 300.0
@export var friction := 1500.0
 
@export_group("Dash")
@export var dash_distance := 150.0
@export var dash_duration := 0.25 # sec
@export var dash_delay := 0.25 # sec
@export var dash_cooldown := 2.5 # sec
@export var dash_max_charges := 3 # later don't make this an export variable, as this could be an upgrade
@export_group("")
#endregion

#region References
@onready var sprite: AnimatedSprite2D = %Sprite
@onready var collision_shape: CollisionShape2D = %CollisionShape2D
#endregion

#region BaseState
var last_move_direction := Vector2.RIGHT
#endregion

#region PlayerFuncs
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	facing_angle = sprite.rotation
	dash_charges = dash_max_charges
	
	# testing strafing
	#call_deferred("test_strafe")

func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector("SwimLeft", "SwimRight", "SwimUp", "SwimDown")
	
	if input_direction != Vector2.ZERO: last_move_direction = input_direction
	
	if Input.is_action_just_pressed("Dash"):
		attempt_dash(input_direction, last_move_direction)
	update_dash(delta)
	
	# determines final velocity given input direction, dashing, & current velocity
	velocity = resolve_velocity(input_direction, velocity, delta)
	move_and_slide()
	
	var is_strafing : bool = has_strafe_target()
	var dash_facing := get_dash_facing_override()
	var is_dash_facing := (dash_facing != Vector2.ZERO)
	
	# get dashing direction override if dashing or about to, otherwise it stays as Vector2.ZERO
	var facing : Vector2
	if is_dash_facing:
		facing = dash_facing
	elif is_strafing:
		facing = get_strafe_facing_dir()
	else:
		facing = input_direction if input_direction != Vector2.ZERO else last_move_direction
	
	update_direction(facing, is_strafing and not is_dash_facing)
	update_animation_state(velocity.length(), is_strafing)
#endregion

#region Movement
func calculate_move_velocity(input_direction: Vector2,
	current_velocity: Vector2, delta: float) -> Vector2:
	
	if input_direction != Vector2.ZERO:
		current_velocity = current_velocity.move_toward(input_direction * speed, acceleration * delta)
		if current_velocity.dot(input_direction) < 0:
			current_velocity = input_direction * speed / 2.0
		return current_velocity
	return decelerate(current_velocity, delta)
 
 
func decelerate(current_velocity: Vector2, delta: float) -> Vector2:
	current_velocity = current_velocity.move_toward(Vector2.ZERO, friction * delta)
	return current_velocity
#endregion

#region Dash
var is_dashing := false
var is_dash_queued := false
var active_dash_direction := Vector2.RIGHT # direction during dash
var queued_dash_direction := Vector2.RIGHT # direction when dash was pressed
var dash_charges : int
 
var dash_timer := 0.0
var dash_delay_timer := 0.0
var dash_recharge_timer := 0.0
 
func is_dash_active() -> bool: return is_dashing or is_dash_queued
 
 
func attempt_dash(input_direction: Vector2, previous_direction: Vector2) -> bool:
	if dash_charges <= 0 or is_dash_active(): return false
	if dash_charges >= dash_max_charges: dash_recharge_timer = dash_cooldown
	
	dash_charges -= 1
	
	if input_direction != Vector2.ZERO:
		queued_dash_direction = input_direction.normalized()
	else:
		queued_dash_direction = previous_direction.normalized()
	
	is_dash_queued = true
	dash_delay_timer = dash_delay
	dash_queued.emit(queued_dash_direction)
	return true
 
 
func update_dash(delta: float) -> void:
	update_dash_recharge(delta)
	
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			dash_ended.emit()
	elif is_dash_queued:
		dash_delay_timer -= delta
		if dash_delay_timer <= 0.0: start_dash()
 
 
func get_dash_velocity() -> Vector2:
	return active_dash_direction * (dash_distance / dash_duration)
 
 
func get_dash_facing_override() -> Vector2:
	if is_dashing: return active_dash_direction
	elif is_dash_queued: return queued_dash_direction
	else: return Vector2.ZERO
 
 
func get_dash_charge_progress() -> float:
	if dash_charges >= dash_max_charges: return 1.0
	else: return clamp(1.0 - (dash_recharge_timer / dash_cooldown), 0.0, 1.0)
 
 
func start_dash() -> void:
	is_dash_queued = false
	is_dashing = true
	active_dash_direction = queued_dash_direction
	dash_timer = dash_duration
	dash_started.emit(active_dash_direction)
 
 
func update_dash_recharge(delta: float) -> void:
	if dash_charges >= dash_max_charges: return
	dash_recharge_timer -= delta
	if dash_recharge_timer <= 0.0:
		dash_charges += 1
		if dash_charges < dash_max_charges: dash_recharge_timer = dash_cooldown
		else: dash_recharge_timer = 0
 
 
func resolve_velocity(input_direction: Vector2,
	current_velocity: Vector2, delta: float) -> Vector2:
	
	if is_dashing: return get_dash_velocity()
	elif is_dash_queued: return decelerate(current_velocity, delta)
	else: return calculate_move_velocity(input_direction, current_velocity, delta)
 

func resolve_facing_direction(input_direction: Vector2,
	prev_direction: Vector2) -> Vector2:
	
	var facing_direction := input_direction
	if is_dashing: facing_direction = active_dash_direction
	elif is_dash_queued: facing_direction = queued_dash_direction
	
	if facing_direction == Vector2.ZERO: return prev_direction
	else: return facing_direction
#endregion

#region Direction
# designed for player, so it may not work as well for other entities
var facing_angle := 0.0
 
func get_facing_dir() -> Vector2:
	return Vector2(cos(facing_angle), sin(facing_angle)).normalized()
 
 
func update_direction(dir: Vector2, is_strafing: bool) -> void:
	if dir == Vector2.ZERO: return
	if is_strafing:
		#facing_angle = 3 * PI / 2
		sprite.flip_h = dir.x < 0.0
	else:
		sprite.flip_h = cos(facing_angle) < 0.0
	facing_angle = dir.angle()
	
	if sprite.flip_h:
		sprite.rotation = atan2(-sin(facing_angle), abs(cos(facing_angle)))
	else:
		sprite.rotation = atan2(sin(facing_angle), abs(cos(facing_angle)))
	
	if collision_shape:
		collision_shape.rotation = sprite.rotation + PI / 2
		if current_anim_state == &"idle":
			collision_shape.rotation += PI / 2
#endregion

#region Animation
# for player, so it may not work well for other entities
var current_anim_state := &"idle"
var must_finish_anim := false
 
func update_animation_state(move_speed: float, force_idle: bool = false) -> void:
	if must_finish_anim: return
	
	if force_idle or move_speed < 5.0: current_anim_state = &"idle"
	else: current_anim_state = &"rush"
	
	sprite.play(current_anim_state)
 
 
func play_animation(anim: StringName) -> void:
	current_anim_state = anim
	must_finish_anim = true
	sprite.play(current_anim_state)
 
 
func _on_sprite_animation_finished() -> void:
	if current_anim_state == &"dash" or current_anim_state == &"hurt":
		must_finish_anim = false
		current_anim_state = &"idle"
#endregion

#region Strafe
var strafe_target: Node2D = null
 
func has_strafe_target() -> bool: return strafe_target != null
 
func set_strafe_target(target: Node2D) -> void: strafe_target = target
 
func remove_strafe_target() -> void: strafe_target = null
 
func get_strafe_facing_dir() -> Vector2:
	if not has_strafe_target(): return Vector2.ZERO
	if sign(strafe_target.global_position.x - global_position.x) < 0.0:
		return Vector2.LEFT
	else: 
		return Vector2.RIGHT

# for real strafe code, loop through nodes in Strafe group and find nearest
func test_strafe() -> void:
	strafe_target = get_tree().get_first_node_in_group("StrafeTarget")
	if strafe_target: set_strafe_target(strafe_target)

#endregion

#region Health
var max_health: float = 100
var current_health: float = 100
 
func change_health(delta_change: float) -> void:
	current_health = clamp(current_health + delta_change, 0, max_health)
 
func check_die() -> void: if current_health <= 0: pass # TODO: implement die mechanic here
 
## damage should be a positive health (calculation is current_health - damage)
func hurt(damage: float) -> void:
	if damage > 0: play_hurt()
	change_health(-damage) # it's -damage since damage > 0, calculated as current_health - damage
	# TODO: determine if a postive damage (i.e. healing) should be allowed
 
func play_hurt() -> void:
	player_hurt.emit()
	play_animation(&"hurt") # TODO: Add visual fx for this?
#endregion

#region Signal Handlers
func on_dash_queued(_direction: Vector2) -> void: play_animation(&"dash")
 
func on_dash_started(_direction: Vector2) -> void: FxManager.spawn_bubbles(position)
#endregion
