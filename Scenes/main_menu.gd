extends Control
@onready var Start_Button = $"Menu Container/Start"
@onready var Quit_Button = $"Menu Container/Quit"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_start_pressed() -> void:
	RunManager.root.load_scene(load("res://Scenes/LurphyLevel.tscn")) #needs updating is jank MVP solution
