class_name Interactable extends Area2D

signal interacted

@export var display_name := "Station"
@export var prompt_text := "Interact"
@export var color := Color(0.3, 0.8, 0.9, 0.5)

@onready var _visual: ColorRect = $Visual
@onready var _name_label: Label = $NameLabel
@onready var _prompt_label: Label = $PromptLabel

var _player_in_range := false


func _ready() -> void:
	_visual.color = color
	_name_label.text = display_name
	_prompt_label.text = "[E] " + prompt_text
	_prompt_label.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed(&"Interact"):
		get_viewport().set_input_as_handled() #marks the key as pressed so other scripts dont react to it
		interacted.emit() #fires the signal	
		


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"Player"):
		_player_in_range = true
		_prompt_label.show()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"Player"):
		_player_in_range = false
		_prompt_label.hide()
