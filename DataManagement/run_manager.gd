extends Node

var currentLevel : Level
var root : Root
var run : RunData

func _ready() -> void:
	LimboConsole.add_eval_input("RunManager", self)
	run = RunData.new()

func load_next_level():
	currentLevel = currentLevel.nextLevel
	root.load_scene.call_deferred(load("res://Scenes/LurphyLevel.tscn"))
