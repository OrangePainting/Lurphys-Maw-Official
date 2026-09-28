extends Node

var max_health: float = 100
var current_health: float = 100

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func change_health(delta_change: float) -> void:
	current_health = clamp(current_health + delta_change, 0, max_health)

func get_health() -> float:
	return current_health

func get_max_health() -> float:
	return max_health

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
