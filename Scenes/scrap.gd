class_name Scrap extends RigidBody2D
## One piece of scrap. Worth `value` when the player collects it.

@export var value := 1
@export_group("Magnet")
@export var magnet_enabled := true # turn magnet on or off
@export var magnet_range := 90.0    # how close the player must be to start the pull
@export var magnet_speed := 350.0   # top speed while being pulled in
@export var magnet_accel := 1500.0  # how quickly it speeds up
@export var collect_range := 14.0   # how close coxunts as "picked up"
@export var pickup_delay := 0.6     # seconds after spawning before it can be pulled

var _player: PhysicsBody2D
var _age := 0.0
var _attracted := false

func _ready() -> void:
	modulate = _color_for_value()
	# This tells the scrap to ignore the player's body.
	_player = get_tree().get_first_node_in_group(&"Player") as PhysicsBody2D
	if _player:
		add_collision_exception_with(_player)

func _color_for_value():
	if value == 25:
		return Color.GOLD
	elif value == 10:
		return Color.GREEN
	return Color.WHITE

func _physics_process(delta: float) -> void:
	_age += delta
	# If the scrap has existed for less time than the pickup delay, do not collect
	# or if the player does not exist.
	if not is_instance_valid(_player) or _age < pickup_delay:
		return

	var to_player := _player.global_position - global_position #vector
	var distance := to_player.length() #scalar of to_player

	if distance <= collect_range:
		_collect()
		return
	
	# If magnet is toggled off, attraction does not occur
	if not magnet_enabled:
		_attracted = false
		gravity_scale = 1.0
		return

	# Once the pull starts it never stops, so scrap doesn't drop back down.
	if distance <= magnet_range:
		_attracted = true

	if _attracted:
		gravity_scale = 0.0
		# Shrinks arrow to length 1, keeping only direction
		var target_velocity := to_player.normalized() * magnet_speed
		# Changes the scrap's actual speed
		# Moves the current velocity toward the target by at most the amount in the second parameter
		linear_velocity = linear_velocity.move_toward(target_velocity, magnet_accel * delta)
		#With magnet_accel at 1500 and delta about 1/60 of a second, 
		#That’s 25 per frame. So the scrap speeds up by 25 each frame until it reaches 350
		# which takes about a quarter of a second.
		# Values are “per second”, and you want “per frame”, so you multiply 1500 per second × 0.0167 seconds per frame = 25 per frame

func _collect() -> void:
	RunManager.add_scrap(value)
	queue_free()
