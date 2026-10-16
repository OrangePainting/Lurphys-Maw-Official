extends Node

var currentLevel : Level
var root : Root

signal scrap_changed(total: int)

var scrap := 0

func load_next_level():
	currentLevel = currentLevel.nextLevel
	root.load_scene.call_deferred(load("res://Scenes/LurphyLevel.tscn"))

func add_scrap(amount: int) -> void:
	scrap += amount
	scrap_changed.emit(scrap)
	print("Scrap total: ", scrap) # temporary, delete once the HUD shows it

func spend_scrap(amount: int) -> bool:
	if amount > scrap:
		return false
	scrap -= amount
	scrap_changed.emit(scrap)
	return true
