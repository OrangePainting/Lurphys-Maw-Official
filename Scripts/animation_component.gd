# animation component for player, so it may not work well for other entities
class_name AnimationComponent extends Node

@onready var sprite := %Sprite

var current_state := &"idle"
var must_finish_state = false

func setup(player_sprite: AnimatedSprite2D) -> void:
	sprite = player_sprite
	sprite.animation_finished.connect(on_sprite_animation_finished)


func update_state(speed: float) -> void:
	if must_finish_state: return
	
	var next_state = &"idle"
	if speed > 5.0:
		next_state = &"rush"
	current_state = next_state
	sprite.play(current_state)


func play_animation(animation: String) -> void:
	current_state = animation
	must_finish_state = true
	sprite.play(current_state)


func on_sprite_animation_finished() -> void:
	if current_state == &"dash" or current_state == &"hurt":
		must_finish_state = false
		current_state = &"idle"
