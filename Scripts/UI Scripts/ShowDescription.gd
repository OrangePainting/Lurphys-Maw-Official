extends Node

@export var brief_description: Control
@export var detailed_description: Control

var pressed_before = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if brief_description: #check for null
		brief_description.hide()
	else:
		print_debug("invalid brief description, please attach something")
	
	if detailed_description:
		detailed_description.hide()
	else:
		print_debug("invalid detailed description, please attach something")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_mouse_entered() -> void:
	if brief_description:
		brief_description.show()
	else:
		print_debug("invalid brief description, please attach something")


func _on_mouse_exited() -> void:
	if brief_description:
		brief_description.hide()
	else:
		print_debug("invalid brief description, please attach something")




func _on_pressed() -> void:
	if pressed_before:
		if detailed_description and brief_description:
			detailed_description.hide()
			brief_description.show()
		else:
			print_debug("invalid description, please attach something")
	else:
		if detailed_description and brief_description:
			brief_description.hide()
			detailed_description.show()
		else:
			print_debug("invalid description, please attach something")
			
	pressed_before = !pressed_before
	
