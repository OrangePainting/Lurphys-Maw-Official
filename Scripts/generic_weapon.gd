class_name Weapon extends Node2D

@onready var hitbox = %Hitbox

@export var attack_duration := 0.5
@export var attack_cooldown := 0.5
@export var offset_from_player := Vector2.ZERO

var enabled: bool
var attack_timer: Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide()
	enabled = false
	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.set_one_shot(true)
	attack_timer.set_wait_time(attack_duration + attack_cooldown)
	attack_timer.timeout.connect(on_attack_timer_timeout)

# After the cooldown is finished, we can allow the player to attack again
func on_attack_timer_timeout() -> void:
	enabled = false
	hide()

# Begins an attack, and returns true if succeeded, false if failed (ex: was on cooldown)
func attack() -> bool:
	if enabled: return false
	
	show()
	enabled = true
	attack_timer.set_wait_time(attack_duration + attack_cooldown) # do i need to do this every time?
	attack_timer.start()
	return true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
