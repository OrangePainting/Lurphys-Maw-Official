extends Node2D
## Click anywhere to drop 5 pieces of scrap at the mouse.

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		ScrapSpawner.spawn(self, get_global_mouse_position(), 5)
