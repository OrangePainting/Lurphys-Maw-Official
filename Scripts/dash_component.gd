class_name DashComponent extends Node

signal dash_queued(direction: Vector2)
signal dash_started(direction: Vector2)
signal dash_ended()

@export_group("Properties")
@export var distance := 75.0
@export var duration := 0.15 # sec
@export var delay := 0.25 # sec
@export var cooldown := 2.5 # sec
@export var max_charges := 1 # later don't make this an export variable, as this could be an upgrade

var is_dashing := false
var is_queued := false
var direction := Vector2.RIGHT
var dash_direction := Vector2.RIGHT
var charges : int

var dash_timer := 0.0
var delay_timer := 0.0
var recharge_timer := 0.0

func is_active() -> bool: return is_dashing or is_queued
func _ready() -> void: charges = max_charges


func attempt_dash(input_direction: Vector2, previous_direction: Vector2) -> bool:
	if charges <= 0 or is_active(): return false
	if charges >= max_charges: recharge_timer = cooldown
	
	charges -= 1
	
	if input_direction != Vector2.ZERO:
		dash_direction = input_direction.normalized()
	else:
		dash_direction = previous_direction.normalized()
	
	is_queued = true
	delay_timer = delay
	dash_queued.emit(dash_direction)
	return true


func physics_process(delta: float) -> void:
	update_recharge(delta)
	
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			dash_ended.emit()
	elif is_queued:
		delay_timer -= delta
		if delay_timer <= 0.0: start_dash()

# distance / time = speed, speed * direction = velocity
func get_velocity() -> Vector2: return direction * (distance / duration)

func get_facing_dir_override() -> Vector2:
	if is_dashing or is_queued: return direction
	else: return Vector2.ZERO

func get_charge_progress() -> float:
	if charges >= max_charges: return 1.0
	else: return clamp(1.0 - (recharge_timer / cooldown), 0.0, 1.0)


func start_dash() -> void:
	is_queued = false
	is_dashing = true
	direction = dash_direction
	dash_timer = duration
	dash_started.emit(direction)


func update_recharge(delta: float) -> void:
	if charges >= max_charges: return
	recharge_timer -= delta
	if recharge_timer <= 0.0:
		charges += 1
		if charges < max_charges: recharge_timer = cooldown
		else: recharge_timer = 0


func resolve_velocity(movement: MovementComponent, input_direction: Vector2,
	current_velocity: Vector2, delta: float) -> Vector2:
	
	if is_dashing: return get_velocity()
	elif is_queued: return movement.decelerate(current_velocity, delta)
	else: return movement.process(input_direction, current_velocity, delta)

func resolve_facing_direction(input_direction: Vector2,
	prev_direction: Vector2) -> Vector2:
	
	var facing_direction := input_direction
	if is_dashing: facing_direction = direction
	elif is_queued: facing_direction = dash_direction
	
	if facing_direction == Vector2.ZERO: return prev_direction
	else: return facing_direction
