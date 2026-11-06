extends Area2D

@export var	speed: float = 400.0
@export var damage: int = 15

var direction: Vector2 = Vector2.ZERO

func fire(fire_direction: Vector2):
	direction = fire_direction.normalized()
	rotation = direction.angle()

func _physics_process(delta: float):
	position += direction * speed * delta

func _on_body_entered(body: Node2D):
	print("Player hit")
	if body.is_in_group("Player") and body.has_method("hurt"):
		body.hurt(damage)
	
	queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()
