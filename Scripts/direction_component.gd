# DirectionComponent designed for player, so it may not work as well for other entities
class_name DirectionComponent extends Node

var sprite: Node2D
var collision_shape: CollisionShape2D
var facing_angle := 0.0


func setup(player_sprite: Node2D, player_collision_shape: CollisionShape2D,
	player_facing_angle: float) -> void:
	
	sprite = player_sprite
	collision_shape = player_collision_shape
	facing_angle = player_facing_angle


func update(direction: Vector2) -> void:
	if direction == Vector2.ZERO: return
	
	facing_angle = direction.angle()
	sprite.flip_h = cos(facing_angle) < 0.0
	if sprite.flip_h:
		sprite.rotation = atan2(-sin(facing_angle), abs(cos(facing_angle)))
	else:
		sprite.rotation = atan2(sin(facing_angle), abs(cos(facing_angle)))
	
	if collision_shape:
		collision_shape.rotation = sprite.rotation + PI / 2
