class_name Projectile extends Area2D

@export var speed := 100.0
@export var lifespan := 5.0

var direction := Vector2.RIGHT
var damage := 10.0
# The thing shooting the projectile
var weapon_shooting_this: Node2D

# sorry for the poor naming, I'll fix it later if it becomes a problem (i don't see it being a problem, more being annoying if anything)
func setup(direction_: Vector2, damage_: float, coming_from: Node2D, start_pos: Vector2) -> void:
	direction = direction_
	damage = damage_
	weapon_shooting_this = coming_from
	global_position = start_pos


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifespan -= delta
	if lifespan < 0.0: queue_free()


func _on_body_entered(body: Node2D) -> void:
	#if body == weapon_shooting_this or (body is Player): return
	if body == weapon_shooting_this: return
	on_hit(body)


func on_hit(body: Node2D) -> void:
	if body.has_method("take_damage"): body.take_damage(damage)
	queue_free()
