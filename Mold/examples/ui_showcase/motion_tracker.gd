extends Node3D

## A retained bottom-left Mold motion tracker for spatial awareness.
##
## The radar is intentionally information-light: range and spatial structure are
## persistent, while contacts become prominent only when their movement makes
## them detectable. Allies, enemies, vehicles, and elevation states are encoded
## with stable color, size, shape, and opacity rather than explanatory panels.

const CANVAS_HEIGHT := 9.0
const RADAR_RADIUS := 1.18
const SENSOR_RANGE_METERS := 25.0

const PLATE := Color(0.008, 0.055, 0.075, 0.78)
const FRAME := Color(0.25, 0.91, 1.0, 0.66)
const FRAME_SOFT := Color(0.28, 0.78, 0.91, 0.20)
const GRID := Color(0.34, 0.78, 0.86, 0.12)
const GRID_STRONG := Color(0.44, 0.88, 0.94, 0.22)
const ALLY := Color(1.0, 0.82, 0.16, 0.96)
const ENEMY := Color(1.0, 0.22, 0.20, 0.98)
const VEHICLE := Color(0.78, 0.86, 0.88, 0.88)
const NAV := Color(0.90, 0.98, 1.0, 0.92)
const COPY := Color(0.75, 0.88, 0.92, 0.86)
const COPY_MUTED := Color(0.42, 0.65, 0.72, 0.70)

@onready var camera: Camera3D = get_parent().get_node("Camera3D")
@onready var interface: CanvasLayer = get_parent().get_node("Interface")

var world: MoldRuntimeInstance
var handles: Array[MoldHandle] = []
var radar_items: Array[Dictionary] = []
var radar_labels: Array[Dictionary] = []
var contacts: Array[Dictionary] = []

var threat_ring: MoldHandle
var nav_marker: MoldHandle
var player_marker: MoldHandle
var range_label: Label
var sector_label: Label

var elapsed := 0.0
var heading := 0.0


func _ready() -> void:
	set_process(false)
	_initialize.call_deferred()


func _initialize() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CANVAS_HEIGHT
	camera.position = Vector3(0.0, 0.0, 10.0)

	var settings := MoldWorldSettings.new()
	settings.capacity = 128
	settings.lod_mode = MoldWorldSettings.LodMode.MANUAL
	settings.retained_unused_mesh_count = 24
	world = MoldRuntime.create_instance(self, settings)

	_build_radar()
	_build_contacts()
	_build_copy()
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()
	_update_radar(0.0)
	set_process(true)


func _process(delta: float) -> void:
	elapsed += delta
	_update_heading(delta)
	_update_radar(delta)


func _exit_tree() -> void:
	for handle in handles:
		if handle and handle.is_valid:
			handle.release()
	handles.clear()
	contacts.clear()
	radar_items.clear()
	if world:
		world.dispose()
	world = null


func _build_radar() -> void:
	_add_radar(MoldShape.disc(1.30), MoldStyle.transparent(PLATE), Vector3.ZERO, -30)
	_add_radar(MoldShape.ring(1.24, 0.026), MoldStyle.additive(FRAME_SOFT), Vector3.ZERO, -12)
	_add_radar(MoldShape.ring(RADAR_RADIUS, 0.018), MoldStyle.transparent(FRAME), Vector3.ZERO, -8)
	_add_radar(MoldShape.ring(RADAR_RADIUS * 0.5, 0.010),
		MoldStyle.transparent(GRID_STRONG), Vector3.ZERO, -8)

	# Orthogonal and diagonal structure gives range at a glance without becoming
	# a literal street map. Every line terminates inside the circular field.
	for segment in [
		[Vector3(-1.12, 0.0, 0.0), Vector3(-0.12, 0.0, 0.0)],
		[Vector3(0.12, 0.0, 0.0), Vector3(1.12, 0.0, 0.0)],
		[Vector3(0.0, -1.12, 0.0), Vector3(0.0, -0.12, 0.0)],
		[Vector3(0.0, 0.12, 0.0), Vector3(0.0, 1.12, 0.0)],
		[Vector3(-0.78, -0.78, 0.0), Vector3(-0.10, -0.10, 0.0)],
		[Vector3(0.10, 0.10, 0.0), Vector3(0.78, 0.78, 0.0)],
		[Vector3(-0.78, 0.78, 0.0), Vector3(-0.10, 0.10, 0.0)],
		[Vector3(0.10, -0.10, 0.0), Vector3(0.78, -0.78, 0.0)],
	]:
		_add_radar(MoldShape.line_2d(segment[0], segment[1], 0.008),
			MoldStyle.transparent(GRID), Vector3.ZERO, -5)

	# Sparse map contours make this read as a tactical sensor rather than a chart.
	_add_contour([
		Vector3(-0.94, 0.42, 0.0), Vector3(-0.57, 0.37, 0.0),
		Vector3(-0.42, 0.11, 0.0), Vector3(-0.08, 0.03, 0.0),
		Vector3(0.18, -0.31, 0.0), Vector3(0.76, -0.38, 0.0),
	])
	_add_contour([
		Vector3(-0.68, -0.62, 0.0), Vector3(-0.31, -0.48, 0.0),
		Vector3(0.02, -0.60, 0.0), Vector3(0.34, -0.55, 0.0),
		Vector3(0.72, -0.72, 0.0),
	])

	for index in 12:
		var angle := float(index) / 12.0 * TAU
		var local := Vector3(cos(angle), sin(angle), 0.0) * 1.16
		_add_radar(MoldShape.rectangle(Vector2(0.014, 0.09 if index % 3 == 0 else 0.055), 0.5),
			MoldStyle.transparent(GRID_STRONG), local, 3,
			Quaternion(Vector3.BACK, angle - PI * 0.5))

	# Bracketed upper arcs establish the armored-visor visual language.
	_add_radar(MoldShape.ring(1.27, 0.038, deg_to_rad(28.0), deg_to_rad(58.0)),
		MoldStyle.additive(FRAME), Vector3.ZERO, 2)
	_add_radar(MoldShape.ring(1.27, 0.038, deg_to_rad(94.0), deg_to_rad(58.0)),
		MoldStyle.additive(FRAME), Vector3.ZERO, 2)

	threat_ring = _add_radar(MoldShape.ring(1.31, 0.022),
		MoldStyle.additive(Color(ENEMY.r, ENEMY.g, ENEMY.b, 0.0)), Vector3.ZERO, 5)
	player_marker = _add_radar(MoldShape.regular_polygon(3, 0.105, 0.02),
		MoldStyle.additive(ALLY), Vector3.ZERO, 30)
	nav_marker = _add_radar(MoldShape.regular_polygon(3, 0.105, 0.018),
		MoldStyle.transparent(NAV), Vector3(0.82, 0.77, 0.0), 25)


func _build_contacts() -> void:
	_create_contact("ally", 0.47, deg_to_rad(-52.0), 0.12, 0, 0.0)
	_create_contact("ally", 0.76, deg_to_rad(152.0), -0.08, 0, 1.2)
	_create_contact("enemy", 0.82, deg_to_rad(36.0), -0.18, 1, 2.4)
	_create_contact("enemy", 0.39, deg_to_rad(-138.0), 0.05, -1, 4.1)
	_create_contact("vehicle", 0.94, deg_to_rad(103.0), -0.035, 0, 3.3)


func _build_copy() -> void:
	# Keep the sensor field exclusively graphical. Readouts sit beyond the outer
	# ring so contacts never have to compete with typography.
	range_label = _add_radar_label("25m", Vector3(1.58, -0.58, 0.0), Vector2(56, 22), 11, COPY)
	sector_label = _add_radar_label("HYDRO 03", Vector3(0.0, -1.48, 0.0), Vector2(112, 22), 10, COPY_MUTED)
	_add_radar_label("N", Vector3(0.0, 1.48, 0.0), Vector2(24, 20), 10, COPY)


func _create_contact(kind: String, radius: float, angle: float, angular_speed: float,
		elevation: int, phase: float) -> void:
	var shape: MoldShape
	var color := ALLY if kind == "ally" else ENEMY if kind == "enemy" else VEHICLE
	if elevation > 0:
		shape = MoldShape.regular_polygon(3, 0.085 if kind != "vehicle" else 0.12, 0.02)
	elif kind == "vehicle":
		shape = MoldShape.regular_polygon_rim(6, 0.11, 0.035, 0.02)
	else:
		shape = MoldShape.disc(0.065 if elevation == 0 else 0.047)

	var handle := world.create(shape, MoldStyle.additive(color), _ui_state(22))
	handles.append(handle)
	contacts.append({
		"handle": handle,
		"kind": kind,
		"radius": radius,
		"angle": angle,
		"speed": angular_speed,
		"elevation": elevation,
		"phase": phase,
		"color": color,
	})


func _update_heading(_delta: float) -> void:
	heading = sin(elapsed * 0.32) * 0.48 + sin(elapsed * 0.11) * 0.22


func _update_radar(_delta: float) -> void:
	var center := _radar_center()
	var nearest_enemy := 2.0
	for item in contacts:
		var radius: float = item.radius + sin(elapsed * 0.45 + item.phase) * 0.035
		var angle: float = item.angle + elapsed * item.speed - heading
		var local := Vector3(sin(angle), cos(angle), 0.0) * radius
		var handle := item.handle as MoldHandle
		handle.set_position(center + local)

		var moving_signal := 0.62 + 0.38 * sin(elapsed * 2.1 + item.phase)
		var alpha := 0.30 + 0.70 * clampf(moving_signal, 0.0, 1.0)
		if item.elevation < 0:
			alpha *= 0.38
		var base: Color = item.color
		handle.set_color(Color(base.r, base.g, base.b, alpha * base.a))
		if item.elevation > 0:
			handle.set_rotation(Quaternion(Vector3.BACK, -angle))
		if item.kind == "enemy":
			nearest_enemy = minf(nearest_enemy, radius)

	var threat := smoothstep(0.68, 0.25, nearest_enemy)
	threat_ring.set_color(Color(ENEMY.r, ENEMY.g, ENEMY.b,
		threat * (0.11 + 0.07 * sin(elapsed * 7.0))))
	player_marker.set_rotation(Quaternion(Vector3.BACK, -heading))
	var nav_angle := deg_to_rad(43.0) - heading
	nav_marker.set_position(center + Vector3(sin(nav_angle), cos(nav_angle), 0.0) * 1.12)
	nav_marker.set_rotation(Quaternion(Vector3.BACK, -nav_angle))


func _add_contour(points: Array[Vector3]) -> void:
	var vertices: Array[MoldPolylinePoint] = []
	for point in points:
		vertices.append(MoldPolylinePoint.new(point, GRID_STRONG))
	var path := MoldPolyline.new(vertices, 0.010, false,
		MoldPolyline.Join.ROUND, MoldPolyline.Cap.ROUND, 4.0, 8)
	var handle := world.create_polyline(path, MoldStyle.transparent(GRID_STRONG), _ui_state(-3))
	handle.set_position(_radar_center())
	handles.append(handle)
	radar_items.append({"handle": handle, "local": Vector3.ZERO})


func _add_radar(shape: MoldShape, style: MoldStyle, local_position: Vector3,
		order: int, rotation: Quaternion = Quaternion.IDENTITY) -> MoldHandle:
	var handle := world.create(shape, style, _ui_state(order))
	handle.set_transform(_radar_center() + local_position, rotation, Vector3.ONE)
	handles.append(handle)
	radar_items.append({"handle": handle, "local": local_position})
	return handle


func _ui_state(order: int) -> MoldRenderState:
	return MoldRenderState.new(
		1, order, MoldRenderState.DepthTest.ALWAYS,
		MoldRenderState.DepthWrite.DISABLED,
		MoldRenderState.StencilFlags.DISABLED,
		MoldRenderState.StencilCompare.ALWAYS, 0,
		MoldRenderState.FaceCull.DISABLED)


func _radar_center() -> Vector3:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var half_width := CANVAS_HEIGHT * aspect * 0.5
	return Vector3(-half_width + 1.55, -CANVAS_HEIGHT * 0.5 + 1.82, 0.0)


func _layout_hud() -> void:
	var center := _radar_center()
	for item in radar_items:
		(item.handle as MoldHandle).set_position(center + item.local)
	for item in radar_labels:
		var label := item.label as Label
		var screen := camera.unproject_position(center + item.local)
		label.position = screen - item.size * 0.5
	_update_radar(0.0)


func _add_radar_label(text: String, local: Vector3, size: Vector2,
		font_size: int, color: Color) -> Label:
	var label := _make_label(text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = size
	radar_labels.append({"label": label, "local": local, "size": size})
	return label


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", font_size)
	interface.add_child(label)
	return label
