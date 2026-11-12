extends Control

@onready var health_bar = %HealthBar
@onready var pause_menu = $PauseMenu/MenuHolder
@onready var stats_menu = $StatsMenu/StatsHolder 
@onready var settings_menu = $PauseMenu/SettingsMenu
@onready var dash_charges_label = %DashChargesLabel
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
@export var default_texture: Texture2D
@export var stat_texts: Array[RichTextLabel] = [] #add stats into this array

@export_group("Exit Marker")
@export var marker_radius := 70.0
@export var marker_hide_distance := 200.0

@onready var exit_marker: Node2D = $"Exit Marker"
var exit_pos := Vector2.ZERO
var has_exit := false

func _ready() -> void:
	health_bar.max_value = health
	health_bar.value = health
	pause_menu.hide()
	stats_menu.hide()
	settings_menu.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	update_exit_marker()
	health_bar.value = player.get_health() #TODO: change once global health is set up or another method is decided
	dash_charges_label.text = "Dash Charges: %d" % player.dash_charges
	if Input.is_action_just_pressed("Pause"):
		pauseMenu()
	#TODO: update for better placement of script/less hard coded
	if Input.is_action_just_pressed("Active 1"):
		use_Item(1, true) #hard coded destroyed, when relics fully implemented please update
	if Input.is_action_just_pressed("Active 2"):
		use_Item(2, true)
	if Input.is_action_just_pressed("Active 3"):
		use_Item(3, true)
	if Input.is_action_just_pressed("Active 4"):
		use_Item(4, true)
		
func pauseMenu() -> void:
	if paused:
		paused = false
		pause_menu.hide()
		stats_menu.hide()
		settings_menu.hide()
		Engine.time_scale = 1
	
	else:
		paused = true
		pause_menu.show()
		Engine.time_scale = 0

func update_exit_marker() -> void:
	if not has_exit or (exit_pos - player.global_position).length() < marker_hide_distance:
		exit_marker.hide()
		return
	
	var vec_to_exit: Vector2 = exit_pos - player.global_position
	var dir := vec_to_exit.normalized()
	var player_screen = get_viewport().get_canvas_transform() * player.global_position
	exit_marker.global_position = player_screen + dir * marker_radius
	exit_marker.rotation = dir.angle()
	exit_marker.show()

func set_exit(exit_position: Vector2) -> void:
	exit_pos = exit_position
	has_exit = true

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
	Engine.time_scale = 1
	RunManager.root.load_scene(load("res://Scenes/main_menu.tscn"))

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_stats_return_pressed() -> void:
	stats_menu.hide()
	pause_menu.show()

func get_stat(stat_num: int) -> String: #call for the counting number, not index
	if stat_num >= stat_texts.size():
		return "Index out of bounds, try again"
	else:
		return stat_texts[stat_num-1].text
		
func set_stat(stat_num: int, new_stat: String) -> String: #returns confirmation that it succeeded
	if stat_num >= stat_texts.size():
		return "Index out of bounds, try again"
	else:
		stat_texts[stat_num-1].text = new_stat
		return "Updated stats"

func get_stat_texts_size() -> int: #returns the size variable, not the max index
	return stat_texts.size()

func set_stat_texts_size(new_size: int) -> void:
	stat_texts.resize(new_size)
	
func use_Item(item_num: int, destroyed: bool)->void: #update based on ui design decisions on what to do when an item is used
	if destroyed:
		setItem(item_num, default_texture, "", default_texture)


func _on_settings_pressed() -> void:
	pause_menu.hide()
	settings_menu.show()
