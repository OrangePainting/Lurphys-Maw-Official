class_name StrafeComponent extends Node

var target: Node2D = null

func has_target() -> bool: return target != null

func set_target(new_target: Node2D) -> void: target = new_target

func remove_target() -> void: target = null

func get_facing_dir(from_pos: Vector2) -> Vector2:
	if not has_target(): return Vector2.ZERO
	print(sign(target.global_position.x - from_pos.x))
	return Vector2.LEFT if sign(target.global_position.x - from_pos.x) == -1 else Vector2.RIGHT
