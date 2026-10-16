class_name ScrapSpawner extends RefCounted
## Anything that should drop scrap (enemy death, breakable crate, level setup)
## calls: ScrapSpawner.spawn(parent_node, position, amount)

const SCRAP_SCENE := preload("res://Scenes/scrap.tscn")


## Drops `amount` pieces of scrap at `position`, each worth `value_each`.
## `position` is in `parent`'s coordinates, so use a parent at (0, 0), such as
## the level root, if you pass a world position.
static func spawn(parent: Node, position: Vector2, amount: int, value_each := 1) -> void:
	for i in amount:
		var scrap: Scrap = SCRAP_SCENE.instantiate()
		scrap.value = value_each
		scrap.position = position
		# Small random pop upward and sideways so pieces spread out.
		scrap.linear_velocity = Vector2(randf_range(-120.0, 120.0), randf_range(-200.0, -80.0))
		# Deferred so it is safe to call from inside a physics callback.
		parent.add_child.call_deferred(scrap)
