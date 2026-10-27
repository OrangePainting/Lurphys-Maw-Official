extends Control

@onready var health_bar = %HealthBar
@onready var pause_menu = $PauseMenu/MenuHolder
@onready var stats_menu = $StatsMenu/StatsHolder 
@onready var itemButtons = { #dictionary of items
	1: $"Items/Item 1",
	2: $"Items/Item 2",
	3: $"Items/Item 3",
	4: $"Items/Item 4"
}
@onready var weaponButton = $WeaponContainer/Weapon

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
	health_bar.value = player.get_health() #TODO: change once global health is set up or another method is decided
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

#sets the item the player holds. Needs all components. Call as integration of the relic system
func setItem(itemNumber : int, sprite : Texture2D, brief_desc : String, image_desc: Texture2D) -> void:
	var item = itemButtons[itemNumber]
	item.texture_normal = sprite
	item.setBriefDescription(brief_desc)
	item.setDetailedDescription(image_desc)

func getItem(itemNumber : int) -> Texture2D:
	return itemButtons[itemNumber].texture_normal

func setWeapon(sprite : Texture2D) -> void:
	weaponButton.texture_normal = sprite

func getWeapon() -> Texture2D:
	return weaponButton.texture_normal

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
