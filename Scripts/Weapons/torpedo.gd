class_name Torpedo extends Projectile

# area of effect radius
@export var explosion: PackedScene


func on_hit(body: Node2D) -> void:
	var e := explosion.instantiate() as Explosion
	var pos = global_position
	get_tree().current_scene.add_child.call_deferred(e)
	e.damage = damage
	e.weapon_shooting_this = weapon_shooting_this
	e.set_deferred("global_position", pos)
	queue_free()
	
