class_name Trident extends Weapon

@export var dash_damage := 18.0


func equip(new_holder: Node2D) -> void:
	super(new_holder)
	(holder as Player).dash_started.connect(on_dash_started)

func unequip() -> void:
	(holder as Player).dash_started.connect(on_dash_started)

func on_dash_started(direction: Vector2) -> void:
	start_attack((holder as Player).dash_duration)
