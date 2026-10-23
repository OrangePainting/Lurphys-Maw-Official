extends Control

@onready var health_bar = %HealthBar
@onready var pause_menu = $PauseMenu/MenuHolder
@onready var stats_menu = $StatsMenu/StatsHolder

var paused = false;

@export var health: float = 100
@export var player: Node #TODO: change. Need a global so UI can know how much health the player has.
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	health_bar.max_value = health
	health_bar.value = health
	pause_menu.hide()
	stats_menu.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#health_bar.value = player.getHealth() #TODO: change once global health is set up or another method is decided
	if Input.is_action_just_pressed("Pause"):
		pauseMenu()
		
func pauseMenu() -> void:
	if paused:
		paused = false
		pause_menu.hide()
		Engine.time_scale = 1
	
	else:
		paused = true
		pause_menu.show()
		Engine.time_scale = 0	
	
func _on_resume_pressed() -> void:
	pause_menu.hide()
	Engine.time_scale = 1
	paused = false


func _on_stats_pressed() -> void:
	pause_menu.hide()
	stats_menu.show()


func _on_main_menu_pressed() -> void:
	pass #TODO: make a main menu to go to


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_stats_return_pressed() -> void:
	stats_menu.hide()
	pause_menu.show()
