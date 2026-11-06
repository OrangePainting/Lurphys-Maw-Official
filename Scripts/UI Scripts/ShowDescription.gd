extends Node

@export var brief_description: RichTextLabel
@export var detailed_description: TextureRect #open to change based on what the description will be, it's too hard coded right now

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

func setBriefDescription(new_desc: String) -> void:
	brief_description.text = new_desc

func getBriefDescription() -> String:
	return brief_description.text

func setDetailedDescription(new_desc: TextureRect) -> void: #remember to update if the type of detailed_description changes
	detailed_description = new_desc

func getDetailedDescription() -> TextureRect:
	return detailed_description

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
	
