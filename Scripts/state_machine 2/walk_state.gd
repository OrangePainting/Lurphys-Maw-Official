extends NodeState

@export var character_body_2d : CharacterBody2D
@export var animated_sprite_2d : AnimatedSprite2D
@export var speed : float = 150.0
@export var attack_range: float = 80.0
@export var attack_state_name: String = "meleeattack"

var player : CharacterBody2D
var max_speed : float

func on_process(delta: float):
	pass

func enter():
	player = get_tree().get_first_node_in_group("Player") as CharacterBody2D
	max_speed = speed + 10.0
	if animated_sprite_2d:
		animated_sprite_2d.play("walk")

func on_physics_process(delta: float):
	if not character_body_2d or not player:
		return

	var current_pos = character_body_2d.global_position
	var player_pos = player.global_position
	var distance = current_pos.distance_to(player_pos)
	var direction = current_pos.direction_to(player_pos)

	var attack_node = state_machine.node_states.get(attack_state_name.to_lower())
	
	var transition_to_attack: bool = false
	
	if attack_node and attack_node.has_method("should_trigger_attack"):
		transition_to_attack = attack_node.should_trigger_attack(distance)
	else:
		transition_to_attack = distance <= attack_range
	
	if transition_to_attack:
		state_machine.transition_to(attack_state_name)
		return

	if direction.x != 0:
		animated_sprite_2d.flip_h = direction.x < 0

	if animated_sprite_2d.animation != "walk":
		animated_sprite_2d.play("walk")

	var target_velocity = direction * speed
	character_body_2d.velocity = character_body_2d.velocity.move_toward(target_velocity, max_speed * delta)
	character_body_2d.move_and_slide()

func exit():
	pass
