extends Node
# autoload

const Bubbles = preload("uid://es4fchmn1rku")

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	pass

func spawn_bubbles(position: Vector2) -> void:
	var b = Bubbles.instantiate()
	add_child(b)
	b.position = position
