extends NodeState

@export var character_body_2d : CharacterBody2D
@export var animated_sprite_2d : AnimatedSprite2D

@export_group("Attack Ranges & Cooldown")
@export var dash_range: float = 150.0
@export var melee_range: float = 70.0
@export var dash_cooldown: float = 5.0

@export_group("Dash Tuning")
@export var dash_speed: float = 450.0
@export var windup_time: float = 0.35
@export var dash_duration: float = 0.25
@export var recovery_time: float = 0.4

@export_group("Regular Attack Tuning")
@export var regular_attack_duration: float = 0.7

enum AttackType { DASH, REGULAR }
enum DashPhase { WINDUP, DASHING, RECOVERY }

var player : CharacterBody2D
var current_attack_type : AttackType
var current_dash_phase : DashPhase
var phase_timer : float = 0.0
var dash_direction : Vector2 = Vector2.ZERO
var next_dash_time : float = 0.0

func on_process(delta: float):
	pass

func can_dash() -> bool:
	return Time.get_ticks_msec() >= next_dash_time

func should_trigger_attack(distance: float) -> bool:
	var melee_available = distance <= melee_range
	var dash_available = can_dash() and distance <= dash_range and distance > melee_range
	return dash_available or melee_available

func enter():
	player = get_tree().get_first_node_in_group("Player") as CharacterBody2D
	if not player or not character_body_2d:
		state_machine.transition_to("walk")
		return
	
	var distance = character_body_2d.global_position.distance_to(player.global_position)
	
	if distance <= melee_range :
		start_regular_attack()
	elif can_dash() and distance <= dash_range:
		start_dash_attack()
	else:
		state_machine.transition_to("walk")

func start_dash_attack():
	current_attack_type = AttackType.DASH
	current_dash_phase = DashPhase.WINDUP
	phase_timer = windup_time
	
	next_dash_time = Time.get_ticks_msec() + (dash_cooldown * 1000.0)
	
	dash_direction = character_body_2d.global_position.direction_to(player.global_position)
	if dash_direction.x != 0 and animated_sprite_2d:
		animated_sprite_2d.flip_h = dash_direction.x < 0
	
	if animated_sprite_2d:
		animated_sprite_2d.play("idle")

func start_regular_attack():
	current_attack_type = AttackType.REGULAR
	phase_timer = regular_attack_duration
	
	var dir = character_body_2d.global_position.direction_to(player.global_position)
	if dir.x != 0 and animated_sprite_2d:
		animated_sprite_2d.flip_h = dir.x < 0
	
	if animated_sprite_2d:
		animated_sprite_2d.play("attack")

func on_physics_process(delta: float):
	if not character_body_2d or not player:
		return
	
	phase_timer -= delta

	if current_attack_type == AttackType.DASH:
		process_dash(delta)
	else:
		process_regular_attack(delta)

func process_dash(delta: float):
	match current_dash_phase:
		DashPhase.WINDUP:
			character_body_2d.velocity = character_body_2d.velocity.move_toward(Vector2.ZERO, 300 * delta)
			character_body_2d.move_and_slide()
			
			var current_dir = character_body_2d.global_position.direction_to(player.global_position)
			if current_dir.x != 0  and animated_sprite_2d:
				animated_sprite_2d.flip_h = current_dir.x < 0
			
			if phase_timer <= 0.0:
				dash_direction = character_body_2d.global_position.direction_to(player.global_position)
				current_dash_phase = DashPhase.DASHING
				phase_timer = dash_duration
				
				if animated_sprite_2d:
					animated_sprite_2d.play("walk")
		DashPhase.DASHING:
			character_body_2d.velocity = dash_direction * dash_speed
			character_body_2d.move_and_slide()
			
			if phase_timer <= 0.0:
				current_dash_phase = DashPhase.RECOVERY
				phase_timer = recovery_time
				
				if animated_sprite_2d:
					animated_sprite_2d.play("idle")
		DashPhase.RECOVERY:
			character_body_2d.velocity = character_body_2d.velocity.move_toward(Vector2.ZERO, 600 * delta)
			character_body_2d.move_and_slide()
			
			if phase_timer <= 0.0:
				state_machine.transition_to("walk")

func process_regular_attack(delta: float):
	character_body_2d.velocity = character_body_2d.velocity.move_toward(Vector2.ZERO, 400 * delta)
	character_body_2d.move_and_slide()
	
	if phase_timer <= 0.0:
		state_machine.transition_to("walk")

func exit():
	pass
