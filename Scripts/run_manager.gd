extends Node

var currentLevel : Level
var root : Root
var run : RunData

func load_next_level():
	currentLevel = currentLevel.nextLevel
	root.load_scene.call_deferred(load("res://Scenes/LurphyLevel.tscn"))
