extends Node2D
class_name LurphyLevel

@onready var player := %Player

@export var exitZone : Area2D
@export var exitZoneCS : CollisionPolygon2D
@export var levelMan : LevelManager
@export var camera : Camera2D
var levelRes : Level

func _ready() -> void:
	levelRes = RunManager.currentLevel
	levelMan.update_level_to_levelres(levelRes)
	levelMan.lurphyLevel = self
	camera.limit_right = levelMan.levelDimensions.x
	camera.limit_bottom = levelMan.levelDimensions.y
	camera.make_current()
	camera.reset_smoothing.call_deferred()


func _on_exit_zone_body_entered(body: Node2D) -> void:
	if body is Player:
		RunManager.load_next_level()
