extends NodeState

@export var character_body_2d: CharacterBody2D
@export var animated_sprite_2d: AnimatedSprite2D
@export var muzzle: Marker2D 

@export_group("Ranged Attack Tuning")
@export var bullet_scene: PackedScene
@export var shoot_range: float = 300.0
@export var shoot_cooldown: float = 2.0

var player: CharacterBody2D
var next_shoot_time: float = 0.0


func should_trigger_attack(distance: float) -> bool:
	return distance <= shoot_range

func enter():
	player = get_tree().get_first_node_in_group("Player") as CharacterBody2D
	if not player or not character_body_2d:
		state_machine.transition_to("walk")
		return
	
	if animated_sprite_2d:
		animated_sprite_2d.play("idle")
		if not animated_sprite_2d.animation_finished.is_connected(_on_animation_finished):
			animated_sprite_2d.animation_finished.connect(_on_animation_finished)

func on_physics_process(delta: float):
	if not character_body_2d or not player:
		return
	
	var distance = character_body_2d.global_position.distance_to(player.global_position)
	
	if distance > shoot_range:
		state_machine.transition_to("walk")
		return
	
	var direction = character_body_2d.global_position.direction_to(player.global_position)
	if direction.x != 0 and animated_sprite_2d:
		var is_facing_left = direction.x < 0
		animated_sprite_2d.flip_h = is_facing_left
		
		if muzzle:
			muzzle.position.x = abs(muzzle.position.x) * (-1 if is_facing_left else 1)
	
	character_body_2d.velocity = character_body_2d.velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	character_body_2d.move_and_slide()
	
	if Time.get_ticks_msec() >= next_shoot_time:
		shoot(direction)
		next_shoot_time = Time.get_ticks_msec() + (shoot_cooldown * 1000.0)

func shoot(direction: Vector2):
	if not bullet_scene:
		push_error("Bullet scene not assigned in RangedAttackState")
		return
	
	if animated_sprite_2d:
		animated_sprite_2d.play("attack")
	
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	
	if muzzle:
		bullet.global_position = muzzle.global_position
	else:
		bullet.global_position = character_body_2d.global_position
	
	if bullet.has_method("fire"):
		bullet.fire(direction)

func exit():
	if animated_sprite_2d and animated_sprite_2d.animation_finished.is_connected(_on_animation_finished):
		animated_sprite_2d.animation_finished.disconnect(_on_animation_finished)

func _on_animation_finished():
	if animated_sprite_2d and animated_sprite_2d.animation == "attack":
		animated_sprite_2d.play("idle")
