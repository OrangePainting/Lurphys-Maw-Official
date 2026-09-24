# DirectionComponent designed for player, so it may not work as well for other entities
class_name DirectionComponent extends Node

@onready var sprite: Node2D = %Sprite
@onready var collision_shape := %CollisionShape2D

var facing_angle := 0.0

func _ready() -> void: facing_angle = sprite.rotation

func get_facing_dir() -> Vector2:
	return Vector2(sin(facing_angle), cos(facing_angle)).normalized()


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
