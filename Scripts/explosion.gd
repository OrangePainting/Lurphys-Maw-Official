class_name Explosion extends Area2D

@export var damage := 25.0
# The projectile that has this explosion
var weapon_shooting_this: Node2D

func _on_body_entered(body: Node2D) -> void:
	if body != weapon_shooting_this:
		if body.has_method("take_damage"):
			body.take_damage(damage)


func _on_animated_sprite_2d_animation_finished() -> void:
	queue_free()


func _on_active_timer_timeout() -> void:
	set_deferred("monitoring", false)
