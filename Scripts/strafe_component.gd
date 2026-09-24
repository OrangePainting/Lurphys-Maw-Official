class_name StrafeComponent extends Node

@export var turn_coefficient := 12.0 # how fast turning toward the target

var target: Node2D = null

func has_target() -> bool: return target != null

func set_target(new_target: Node2D) -> void: target = new_target

func remove_target() -> void: target = null

func get_facing_dir(from_pos: Vector2, cur_facing_direction: Vector2,
	delta: float) -> Vector2:
	
	if not has_target(): return Vector2.ZERO
	
	var target_direction := (target.global_position - from_pos).normalized()
	if cur_facing_direction == Vector2.ZERO:
		return target_direction
	
	var weight: float = clamp(turn_coefficient * delta, 0.0, 1.0)
	return cur_facing_direction.slerp(target_direction, weight).normalized()
