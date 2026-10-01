extends Node
class_name Root

@export var startingScene : PackedScene
@export var startingLevel : Level
var currentScene

func _ready() -> void:
	RunManager.root = self
	RunManager.currentLevel = startingLevel
	load_scene(startingScene)

func load_scene(scene : PackedScene):
	unload_children()
	add_child(scene.instantiate())

func unload_children():
	for i in get_children():
		remove_child(i)
		i.queue_free()
