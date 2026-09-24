extends Node3D

const CYAN := Color(0.13, 0.83, 0.93)
const TEAL := Color(0.08, 0.72, 0.65)
const BLUE := Color(0.15, 0.39, 0.92)
const CORAL := Color(0.98, 0.44, 0.52)
const PEARL := Color(0.96, 0.91, 0.78)
const GOLD := Color(1.0, 0.72, 0.08)

const WORLD_POSITION := Vector3(-2.5, -2.65, 0.0)
const OBJECT_POSITION := Vector3(2.5, -2.65, 0.0)

var world: MoldContext
@onready var camera: Camera3D = $Camera3D
@onready var interface: CanvasLayer = $Interface
@onready var world_gradient: MoldNode3D = $GradientExamples/World
@onready var object_gradient: MoldNode3D = $GradientExamples/Object

var labels: Array[Dictionary] = []
var time := 0.0


func _ready() -> void:
	var settings := MoldWorldSettings.new()
	settings.lod_mode = MoldWorldSettings.LodMode.CONTINUOUS
	settings.lod_transition_width = 0.15
	world = MoldRuntime.for_node(self, settings)
	_create_labels()
	_update_labels()


func _process(delta: float) -> void:
	time += delta
	var tilt := Quaternion(Vector3.RIGHT, -0.34) * Quaternion(Vector3.UP, 0.42)
	var rotation := Quaternion(Vector3.BACK, time * 0.72) * tilt
	world_gradient.quaternion = rotation
	object_gradient.quaternion = rotation
	_update_labels()


func _exit_tree() -> void:
	world = null


func _create_labels() -> void:
	_add_label("RADIAL · CENTER", Vector3(-4.5, 3.0, 0.0))
	_add_label("RADIAL · BOUNDS", Vector3(-1.5, 3.0, 0.0))
	_add_label("DUAL ANGULAR", Vector3(1.5, 3.0, 0.0))
	_add_label("3D DIRECTIONAL", Vector3(4.5, 3.0, 0.0))
	_add_label("LINEAR RGB · OBJECT", Vector3(-2.5, 0.62, 0.0))
	_add_label("OKLAB · OBJECT", Vector3(2.5, 0.62, 0.0))
	_add_label("WORLD SPACE", WORLD_POSITION + Vector3.UP * 1.25)
	_add_label("OBJECT SPACE", OBJECT_POSITION + Vector3.UP * 1.25)


func _add_label(text: String, anchor: Vector3) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(330.0, 28.0)
	label.add_theme_color_override("font_color", Color(0.86, 0.91, 0.94))
	label.add_theme_color_override("font_outline_color", Color(0.004, 0.018, 0.035, 0.96))
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_constant_override("outline_size", 4)
	interface.add_child(label)
	labels.append({"label": label, "anchor": anchor})


func _update_labels() -> void:
	for item in labels:
		var screen := camera.unproject_position(item.anchor)
		item.label.position = screen - Vector2(item.label.custom_minimum_size.x * 0.5, 15.0)
