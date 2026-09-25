extends CharacterBody3D

## Autonomous third-person locomotion over a looping route.
##
## This keeps the controller behavior real—gravity, steering, acceleration,
## collision, and a body-relative follow camera—while requiring no player input.

const ROUTE: Array[Vector3] = [
	Vector3(0.0, 0.0, -12.0),
	Vector3(7.0, 0.0, -22.0),
	Vector3(-6.0, 0.0, -34.0),
	Vector3(5.0, 0.0, -46.0),
	Vector3(0.0, 0.0, -58.0),
	Vector3(-7.0, 0.0, -44.0),
	Vector3(6.0, 0.0, -30.0),
	Vector3(-5.0, 0.0, -17.0),
]

@onready var visual: Node3D = $Visual
@onready var camera_rig: Node3D = $CameraRig

var route_index := 0
var current_speed := 0.0
var distance_travelled := 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _physics_process(delta: float) -> void:
	var target := ROUTE[route_index]
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() < 1.5:
		route_index = (route_index + 1) % ROUTE.size()
		target = ROUTE[route_index]
		to_target = target - global_position
		to_target.y = 0.0

	var desired_direction := to_target.normalized()
	var forward := -global_basis.z
	var turn_error := forward.signed_angle_to(desired_direction, Vector3.UP)
	var turn_step := clampf(turn_error, -delta * 1.65, delta * 1.65)
	rotate_y(turn_step)

	var target_speed := 5.6 + sin(distance_travelled * 0.075) * 1.1
	current_speed = move_toward(current_speed, target_speed, delta * 3.4)
	forward = -global_basis.z
	velocity.x = forward.x * current_speed
	velocity.z = forward.z * current_speed
	if is_on_floor():
		velocity.y = -0.25
	else:
		velocity.y -= gravity * delta
	move_and_slide()

	distance_travelled += Vector2(velocity.x, velocity.z).length() * delta
	visual.rotation.z = lerpf(visual.rotation.z, -turn_step * 4.2, delta * 7.0)
	visual.position.y = sin(distance_travelled * 2.2) * 0.025
	camera_rig.position.y = 1.45 + sin(distance_travelled * 0.32) * 0.055

