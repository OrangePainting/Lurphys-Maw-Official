class_name Torpedo extends Projectile

# area of effect radius
@export var explosion: PackedScene


func on_hit(body: Node2D) -> void:
	var e := explosion.instantiate() as Explosion
	add_child.call_deferred(e)
	e.damage = damage
	e.weapon_shooting_this = weapon_shooting_this
	e.global_position = global_position
	queue_free()
	
