extends Control

@onready var health_bar = %HealthBar

@export var health: float = 100
@export var player: Node #TODO: change. Need a global so UI can know how much health the player has.
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	health_bar.max_value = health
	health_bar.value = health


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	health_bar.value = player.getHealth() #TODO: change once global health is set up or another method is decided
