extends Node3D

const INK := Color(0.018, 0.012, 0.075)
const NAVY := Color(0.035, 0.035, 0.16)

var world: MoldContext
@onready var camera: Camera3D = $Camera3D
@onready var interface: CanvasLayer = $Interface

var spinners: Array[Dictionary] = []
var labels: Array[Dictionary] = []


func _ready() -> void:
	var settings := MoldWorldSettings.new()
	settings.lod_mode = MoldWorldSettings.LodMode.CONTINUOUS
	settings.lod_transition_width = 0.15
	world = MoldRuntime.for_node(self, settings)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 27.0
	camera.position = Vector3(18.0, 21.0, 18.0)
	camera.look_at(Vector3(0.5, 0.4, -0.5), Vector3.UP)
	_setup_animation()
	_create_labels()
	_update_labels()


func _process(_delta: float) -> void:
	var time := Time.get_ticks_msec() * 0.001
	for spinner in spinners:
		spinner.node.quaternion = Quaternion(Vector3.UP, spinner.phase + time * spinner.speed)
	_update_labels()


func _exit_tree() -> void:
	world = null


func _setup_animation() -> void:
	for index in range(10, 21):
		var node := get_node("ShapeCatalog/Shape%02d" % index) as MoldNode3D
		spinners.append({"node": node, "phase": 0.22 + index * 0.17,
			"speed": 0.16 if index % 2 == 0 else -0.13})
	for index in range(13):
		var node := get_node("BlendCatalog/Sample%02d" % index) as MoldNode3D
		spinners.append({"node": node, "phase": index * 0.31,
			"speed": 0.2 if index % 2 == 0 else -0.17})


func _create_labels() -> void:
	var names := [
		"Billboard Rect", "Rounded Rect", "Dash Normal", "Dash Rounded", "Disc",
		"Dash Chevron", "Polygon", "Rounded Polygon", "Dash Poly", "Dash Round Poly",
		"Cuboid", "Rounded Box", "Cylinder", "Rounded Cylinder", "Regular Prism",
		"Rounded Prism", "Cone", "Sphere", "Hemisphere", "Capsule", "Torus",
	]
	for index in names.size():
		var column := index % 5
		var row := index / 5
		var ground := _iso_position(-12.0 + column * 4.0, -6.0 + row * 4.0, 0.0)
		_add_world_label(names[index], ground + Vector3.UP * (0.18 if index < 10 else 1.25),
			Color(0.72, 1.0, 1.0))

	var blend_names := [
		"Opaque", "Transparent", "Additive", "Color Dodge", "Screen", "Lighten",
		"Linear Burn", "Color Burn", "Multiplicative", "Darken", "Subtractive",
		"Dither", "Dual Gradient",
	]
	for index in blend_names.size():
		var column := index % 3
		var row := index / 3
		var ground := _iso_position(8.0 + column * 4.0, -6.0 + row * 3.4, 0.0)
		_add_world_label(blend_names[index], ground + Vector3.UP * 1.28, Color(1.0, 0.94, 0.34))

	var columns := [-8.0, 0.0, 8.0]
	var section_labels := ["DEPTH ALWAYS", "DEPTH GREATER", "STENCIL MASK"]
	for index in columns.size():
		var center := _iso_position(columns[index], 11.0, 0.0) + Vector3.UP * 1.05
		_add_world_label(section_labels[index], center + Vector3.UP * 1.35, Color(0.45, 1.0, 0.7))


func _add_world_label(text: String, anchor: Vector3, color: Color) -> void:
	var label := Label.new()
	label.text = text.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.008, 0.004, 0.035, 0.95))
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_constant_override("outline_size", 3)
	label.custom_minimum_size = Vector2(106.0, 20.0)
	interface.add_child(label)
	labels.append({"label": label, "anchor": anchor})


func _update_labels() -> void:
	for item in labels:
		var screen := camera.unproject_position(item.anchor)
		item.label.position = screen - Vector2(item.label.custom_minimum_size.x * 0.5, 11.0)


static func _iso_position(screen_horizontal: float, screen_vertical: float, y: float) -> Vector3:
	return Vector3((screen_horizontal + screen_vertical) * 0.5, y, (screen_vertical - screen_horizontal) * 0.5)
