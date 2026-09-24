extends Node3D

var world: MoldContext
@onready var camera: Camera3D = $Camera3D
@onready var interface: CanvasLayer = $Interface

var labels: Array[Dictionary] = []


func _ready() -> void:
	var settings := MoldWorldSettings.new()
	settings.lod_mode = MoldWorldSettings.LodMode.CONTINUOUS
	settings.lod_transition_width = 0.15
	world = MoldRuntime.for_node(self, settings)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.5
	camera.position = Vector3(0.0, 0.0, 20.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	_create_labels()
	_update_labels()


func _process(_delta: float) -> void:
	_update_labels()


func _exit_tree() -> void:
	world = null


func _create_labels() -> void:
	_add_label("LESS-EQUAL DEPTH", Vector3(-4.6, 3.3, 0.0))
	_add_label("GREATER DEPTH", Vector3(0.0, 3.3, 0.0))
	_add_label("ALWAYS DEPTH", Vector3(4.6, 3.3, 0.0))
	_add_label("DEPTH WRITE OFF / ON", Vector3(-4.6, -1.15, 0.0))
	_add_label("STENCIL WRITE + READ", Vector3(0.0, -1.15, 0.0))
	_add_label("DEPTH-FAIL WRITE", Vector3(4.6, -1.15, 0.0))


func _add_label(text: String, anchor: Vector3) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(230.0, 28.0)
	label.add_theme_color_override("font_color", Color(0.92, 0.93, 0.94))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.025, 0.025, 0.95))
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_constant_override("outline_size", 3)
	interface.add_child(label)
	labels.append({"label": label, "anchor": anchor})


func _update_labels() -> void:
	for item in labels:
		var screen := camera.unproject_position(item.anchor)
		item.label.position = screen - Vector2(item.label.custom_minimum_size.x * 0.5, 14.0)
