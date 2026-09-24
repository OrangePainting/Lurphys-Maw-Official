extends Node3D

## A retained top-center navigation compass for landmarks and objectives.
##
## The frame and center index stay fixed while the heading tape, cardinal type,
## and world-space landmarks move beneath them. Marker contrast and scale encode
## distance and importance, leaving the active objective legible at a glance.

const CANVAS_HEIGHT := 9.0
const BAR_HALF_WIDTH := 2.55
const VIEW_HALF_ANGLE := deg_to_rad(72.0)
const TICK_STEP_DEGREES := 15

const PLATE := Color(0.012, 0.014, 0.018, 0.46)
const FRAME := Color(0.79, 0.80, 0.76, 0.30)
const FRAME_SOFT := Color(0.72, 0.73, 0.69, 0.07)
const IVORY := Color(0.91, 0.91, 0.85, 0.94)
const IVORY_MUTED := Color(0.72, 0.73, 0.69, 0.62)
const QUEST := Color(0.96, 0.89, 0.66, 0.98)

@onready var camera: Camera3D = get_parent().get_node("Camera3D")
@onready var interface: CanvasLayer = get_parent().get_node("Interface")

var world: MoldRuntimeInstance
var handles: Array[MoldHandle] = []
var fixed_items: Array[Dictionary] = []
var tape_ticks: Array[Dictionary] = []
var cardinal_labels: Array[Dictionary] = []
var landmark_items: Array[Dictionary] = []

var elapsed := 0.0
var heading := deg_to_rad(355.0)


func _ready() -> void:
	set_process(false)
	_initialize.call_deferred()


func _initialize() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CANVAS_HEIGHT
	camera.position = Vector3(0.0, 0.0, 10.0)

	var settings := MoldWorldSettings.new()
	settings.capacity = 96
	settings.lod_mode = MoldWorldSettings.LodMode.MANUAL
	settings.retained_unused_mesh_count = 24
	world = MoldRuntime.create_instance(self, settings)

	_build_frame()
	_build_heading_tape()
	_build_landmarks()
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()
	_update_compass()
	set_process(true)


func _process(delta: float) -> void:
	elapsed += delta
	heading = fposmod(
		deg_to_rad(355.0) + sin(elapsed * 0.22) * deg_to_rad(46.0)
		+ sin(elapsed * 0.57) * deg_to_rad(7.0), TAU)
	_update_compass()


func _exit_tree() -> void:
	for handle in handles:
		if handle and handle.is_valid:
			handle.release()
	handles.clear()
	tape_ticks.clear()
	cardinal_labels.clear()
	landmark_items.clear()
	if world:
		world.dispose()
	world = null


func _build_frame() -> void:
	# A dark, narrow shelf protects the pale symbols from bright scenery without
	# reading as a conventional panel.
	_add_fixed(MoldShape.rectangle(Vector2(5.62, 0.66), 0.10),
		MoldStyle.transparent(PLATE), Vector3(0.0, 0.0, 0.0), -30)
	_add_fixed(MoldShape.rectangle_rim(Vector2(5.62, 0.66), 0.012, 0.10),
		MoldStyle.transparent(FRAME_SOFT), Vector3.ZERO, -20)
	_add_fixed(MoldShape.line_2d(Vector3(-BAR_HALF_WIDTH, -0.02, 0.0),
		Vector3(BAR_HALF_WIDTH, -0.02, 0.0), 0.009),
		MoldStyle.transparent(FRAME), Vector3.ZERO, -5)

	# The fixed center index is the only immovable bright element. It makes the
	# moving tape readable even when no landmark is centered.
	_add_fixed(MoldShape.regular_polygon_rim(3, 0.066, 0.018, 0.01),
		MoldStyle.transparent(IVORY), Vector3(0.0, 0.30, 0.0), 35,
		Quaternion(Vector3.BACK, PI))
	_add_fixed(MoldShape.rectangle(Vector2(0.016, 0.075), 0.5),
		MoldStyle.transparent(IVORY_MUTED), Vector3(0.0, 0.22, 0.0), 25)


func _build_heading_tape() -> void:
	for degrees in range(0, 360, TICK_STEP_DEGREES):
		var major := degrees % 90 == 0
		var ordinal := degrees % 45 == 0
		var tick := world.create(
			MoldShape.rectangle(Vector2(0.014 if not major else 0.020,
				0.105 if major else 0.070 if ordinal else 0.045), 0.5),
			MoldStyle.transparent(IVORY_MUTED), _ui_state(5))
		handles.append(tick)
		tape_ticks.append({"handle": tick, "angle": deg_to_rad(float(degrees))})

	for entry in [
		{"text": "N", "angle": 0.0},
		{"text": "E", "angle": PI * 0.5},
		{"text": "S", "angle": PI},
		{"text": "W", "angle": PI * 1.5},
	]:
		var label := _make_label(entry.text, 15, IVORY)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(38.0, 26.0)
		cardinal_labels.append({
			"label": label,
			"angle": entry.angle,
			"size": label.size,
		})


func _build_landmarks() -> void:
	# These are intentionally abstract silhouettes rather than copied game icons.
	# Their shape remains stable while distance only changes scale and contrast.
	_create_landmark("quest", deg_to_rad(31.0), 120.0,
		MoldShape.regular_polygon_rim(4, 0.135, 0.034, 0.01), QUEST,
		Quaternion(Vector3.BACK, PI * 0.25))
	_create_landmark("keep", deg_to_rad(-49.0), 205.0,
		MoldShape.regular_polygon_rim(6, 0.120, 0.030, 0.015), IVORY_MUTED)
	_create_landmark("camp", deg_to_rad(78.0), 92.0,
		MoldShape.regular_polygon_rim(3, 0.125, 0.030, 0.01), IVORY_MUTED)
	_create_landmark("cave", deg_to_rad(-106.0), 480.0,
		MoldShape.ring(0.120, 0.030, 0.0, PI), IVORY_MUTED,
		Quaternion(Vector3.BACK, PI))


func _create_landmark(kind: String, angle: float, distance: float,
		shape: MoldShape, color: Color,
		rotation: Quaternion = Quaternion.IDENTITY) -> void:
	var handle := world.create(shape, MoldStyle.transparent(color), _ui_state(20))
	handles.append(handle)
	landmark_items.append({
		"handle": handle,
		"kind": kind,
		"angle": angle,
		"distance": distance,
		"color": color,
		"rotation": rotation,
	})


func _update_compass() -> void:
	if not world:
		return
	var center := _compass_center()

	for item in tape_ticks:
		var delta := wrapf(float(item.angle) - heading, -PI, PI)
		var visible := absf(delta) <= VIEW_HALF_ANGLE
		var handle := item.handle as MoldHandle
		handle.set_visible(visible)
		if visible:
			var x := delta / VIEW_HALF_ANGLE * BAR_HALF_WIDTH
			var edge_fade := smoothstep(1.0, 0.72, absf(delta) / VIEW_HALF_ANGLE)
			handle.set_position(center + Vector3(x, -0.02, 0.0))
			handle.set_color(Color(IVORY_MUTED.r, IVORY_MUTED.g, IVORY_MUTED.b,
				IVORY_MUTED.a * edge_fade))

	for item in cardinal_labels:
		var delta := wrapf(float(item.angle) - heading, -PI, PI)
		var visible := absf(delta) <= VIEW_HALF_ANGLE
		var label := item.label as Label
		label.visible = visible
		if visible:
			var x := delta / VIEW_HALF_ANGLE * BAR_HALF_WIDTH
			var screen := camera.unproject_position(center + Vector3(x, 0.13, 0.0))
			label.position = screen - item.size * 0.5
			var edge_fade := smoothstep(1.0, 0.68, absf(delta) / VIEW_HALF_ANGLE)
			label.add_theme_color_override("font_color", Color(IVORY.r, IVORY.g, IVORY.b,
				IVORY.a * edge_fade))

	for item in landmark_items:
		var delta := wrapf(float(item.angle) - heading, -PI, PI)
		var visible := absf(delta) <= VIEW_HALF_ANGLE
		var handle := item.handle as MoldHandle
		handle.set_visible(visible)
		if visible:
			var x := delta / VIEW_HALF_ANGLE * BAR_HALF_WIDTH
			var angular_fade := smoothstep(1.0, 0.62, absf(delta) / VIEW_HALF_ANGLE)
			var distance_strength := remap(clampf(float(item.distance), 80.0, 520.0),
				80.0, 520.0, 1.0, 0.30)
			if item.kind == "quest":
				distance_strength = maxf(distance_strength, 0.78)
			var pulse := 1.0 + sin(elapsed * 2.6) * 0.05 if item.kind == "quest" else 1.0
			var scale := (0.76 + distance_strength * 0.30) * pulse
			var base: Color = item.color
			handle.set_transform(center + Vector3(x, -0.255, 0.0), item.rotation,
				Vector3.ONE * scale)
			handle.set_color(Color(base.r, base.g, base.b,
				base.a * angular_fade * distance_strength))


func _add_fixed(shape: MoldShape, style: MoldStyle, local_position: Vector3,
		order: int, rotation: Quaternion = Quaternion.IDENTITY) -> MoldHandle:
	var handle := world.create(shape, style, _ui_state(order))
	handle.set_transform(_compass_center() + local_position, rotation, Vector3.ONE)
	handles.append(handle)
	fixed_items.append({"handle": handle, "local": local_position})
	return handle


func _ui_state(order: int) -> MoldRenderState:
	return MoldRenderState.new(
		1, order, MoldRenderState.DepthTest.ALWAYS,
		MoldRenderState.DepthWrite.DISABLED,
		MoldRenderState.StencilFlags.DISABLED,
		MoldRenderState.StencilCompare.ALWAYS, 0,
		MoldRenderState.FaceCull.DISABLED)


func _compass_center() -> Vector3:
	return Vector3(0.0, CANVAS_HEIGHT * 0.5 - 0.54, 0.0)


func _layout_hud() -> void:
	var center := _compass_center()
	for item in fixed_items:
		(item.handle as MoldHandle).set_position(center + item.local)
	_update_compass()


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", font_size)
	interface.add_child(label)
	return label
