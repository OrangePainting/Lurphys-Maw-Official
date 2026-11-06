extends Node
class_name EnemyManager

func spawn_enemy(enemy : PackedScene, pos : Vector2):
	var newEnemy : EnemyBase = enemy.instantiate()
	newEnemy.global_position = pos
	add_child(newEnemy)
