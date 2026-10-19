class_name Weapon extends Node2D

signal attack_begun
signal attack_ended

enum State {FREE, ACTIVE, COOLDOWN}

@onready var hitbox = %Hitbox

@export var weapon_name := "Weapon"
@export var damage := 10.0
@export var attack_duration := 0.1
@export var attack_cooldown := 0.15
@export var offset_from_player := Vector2(30, 0)
@export var two_handed := false # uses up secondary as well (for anchor, cuz it acts like a greatsword)

var state: State = State.FREE
var holder: Node2D
var aim_direction := Vector2.RIGHT
var timer: = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide()
	if hitbox:
		hitbox.monitoring = false
		# remember to connect signal, when making new weapon


func equip(new_holder: Node2D) -> void:
	holder = new_holder
	position = offset_from_player

func unequip() -> void: holder = null

func is_active() -> bool: return state == State.ACTIVE	

func prevent_damage(amount: float) -> bool: return false # shield overrides this


# Begins attack, returns true if succeeded, false if failed (ex: was on cooldown)
func attack(direction: Vector2) -> bool:
	if state != State.FREE: return false
	
	aim_direction = direction
	start_attack(attack_duration)
	return true


func start_attack(direction: float) -> void:
	state = State.ACTIVE
	timer = attack_duration
	show()
	hitbox.set_deferred("monitoring", true)
	on_attack_start()
	attack_begun.emit()


func end_active() -> void:
	state = State.COOLDOWN
	timer = attack_cooldown
	hide()
	hitbox.set_deferred("monitoring", false)
	on_attack_end()
	attack_ended.emit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if state == State.FREE: return
	timer -= delta
	if timer > 0.0: return # if timer is done, then do below stuff
	if state == State.ACTIVE: end_active()
	else: state = State.FREE

# These funcs below are for the actual weapons, and are filled out for them

func on_attack_start() -> void:
	pass # Replace with function body.

func on_attack_end() -> void:
	pass # Replace with function body.

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body == holder: return # we can change this later if we don't want the player to be immune
	if body.has_method("take_damage"): body.take_damage(damage)
	
