class_name ProjectileWeapon extends Weapon

@export var projectile: PackedScene
@export var dist_from_player := 50.0

func on_attack_start() -> void:
	var p := projectile.instantiate() as Projectile
	var pos = global_position + aim_direction * dist_from_player
	get_tree().current_scene.add_child(p)
	p.set_deferred("global_position", pos)  # so that it doesn't hit the player as it spawns
	p.setup(aim_direction, damage, holder)
