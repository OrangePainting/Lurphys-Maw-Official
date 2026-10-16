class_name EnemyBase
extends CharacterBody2D

@export_group("Enemy Stats")
@export var max_health: int = 100

var current_health: int

signal health_changed(new_health, max_health)
signal died

func _ready():
	current_health = max_health

func take_damage(amount: int):
	current_health -= amount
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		die()

func die():
	died.emit()
	queue_free()
