class_name Scrap extends RigidBody2D
## One piece of scrap. Worth `value` when the player collects it.

@export var value := 1


func _ready() -> void:
	# The player shares a collision layer with the level walls, so scrap would
	# block the player. This tells the scrap to ignore the player's body.
	var player := get_tree().get_first_node_in_group(&"Player") as PhysicsBody2D
	if player:
		add_collision_exception_with(player)
