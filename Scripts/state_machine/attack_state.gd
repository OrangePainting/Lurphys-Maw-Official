extends NodeState

@export var character_body_2d : CharacterBody2D
@export var animated_sprite_2d : AnimatedSprite2D
@export var speed : float = 150.0
@export var attack_range: float = 80.0

var player : CharacterBody2D
var max_speed : float

func on_process(delta: float):
	pass

func on_physics_process(delta: float):
	var current_pos = character_body_2d.global_position
	var player_pos = player.global_position
	var distance = current_pos.distance_to(player_pos)
	var direction = current_pos.direction_to(player_pos)
	
	if direction.x != 0:
		animated_sprite_2d.flip_h = direction.x < 0
	
	if distance <= attack_range:
		character_body_2d.velocity = character_body_2d.velocity.move_toward(Vector2.ZERO, speed * delta)
		if animated_sprite_2d.animation != "attack":
			animated_sprite_2d.play("attack")
	else:
		if animated_sprite_2d.animation != "walk":
			animated_sprite_2d.play("walk")
			
		var target_velocity = direction * speed
		character_body_2d.velocity = character_body_2d.velocity.move_toward(target_velocity, max_speed * delta)
	
	character_body_2d.move_and_slide()

func enter():
	player = get_tree().get_first_node_in_group("Player") as CharacterBody2D
	max_speed = speed + 20.0

func exit():
	pass
