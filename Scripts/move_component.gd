class_name MovementComponent extends Node

@export_group("Properties")
@export var speed := 300.0
@export var acceleration := 300.0
@export var friction := 1200.0

func setup(player_speed: float, player_acceleration: float,
	 player_friction: float) -> void:
	
	speed = player_speed
	acceleration = player_acceleration
	friction = player_friction


func process(input_direction: Vector2, 
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
