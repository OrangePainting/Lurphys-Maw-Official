class_name Trident extends Weapon

@export var dash_damage := 18.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func equip(new_holder: Node2D) -> void:
	super(new_holder)
	(holder as Player).dash_started.connect(on_dash_started)

func unequip() -> void:
	(holder as Player).dash_started.connect(on_dash_started)

func on_dash_started(direction: Vector2) -> void:
	start_attack((holder as Player).dash_duration)
