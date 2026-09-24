class_name MovementComponent extends Node

var speed: float = 300.0
var acceleration: float = 300.0
var friction: float = 1200.0

func setup(player_speed: float, player_acceleration: float,
	 player_friction: float) -> void:
	
	speed = player_speed
	acceleration = player_acceleration
	friction = player_friction


# Called every frame. 'delta' is the elapsed time since the previous frame.
func process(input_direction: Vector2, 
	current_velocity: Vector2, delta: float) -> Vector2:
	
	if input_direction != Vector2.ZERO:
		current_velocity = current_velocity.move_toward(input_direction * speed, acceleration * delta)
		return current_velocity
	return decelerate(current_velocity, delta)


func decelerate(current_velocity: Vector2, delta: float) -> Vector2:
	current_velocity = current_velocity.move_toward(Vector2.ZERO, friction * delta)
	return current_velocity
