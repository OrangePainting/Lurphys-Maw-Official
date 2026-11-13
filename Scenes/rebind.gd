extends Control

@onready var actions = [
	&"SwimUp",
	&"SwimDown",
	&"SwimLeft",
	&"SwimRight",
	&"Dash",
	&"Rush",
	&"AttackPrimary",
	&"AttackSecondary",
	&"Active 1",
	&"Active 2",
	&"Active 3",
	&"Active 4"
]

var cur_action: String = ""
var inputting: bool = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
