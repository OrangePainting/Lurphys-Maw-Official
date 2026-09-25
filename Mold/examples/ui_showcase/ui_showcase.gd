extends Node3D

## A camera-fixed, retained Mold HUD showcasing four expressive instruments.
##
## Mold owns the gauge plate, rings, ticks, dividers, and boost feedback. Native
## Godot labels remain responsible for text shaping and accessibility. All HUD
## geometry is created once; only color and the two progress-arc descriptors are
## mutated while the simulated car accelerates.

const CANVAS_HEIGHT := 9.0
const GAUGE_RADIUS := 1.12
const TACH_START := deg_to_rad(220.0)
const TACH_END := deg_to_rad(-40.0)
const TACH_SPAN := TACH_START - TACH_END
const TICK_COUNT := 41
const MAX_SPEED := 280.0
const SPEED_TOPS: Array[float] = [0.0, 52.0, 88.0, 128.0, 172.0, 224.0, MAX_SPEED]

const INK := Color(0.018, 0.028, 0.045, 0.78)
const INK_EDGE := Color(0.50, 0.65, 0.76, 0.20)
const TRACK := Color(0.72, 0.80, 0.86, 0.16)
const TRACK_STRONG := Color(0.76, 0.84, 0.90, 0.30)
const WHITE := Color(0.94, 0.97, 0.98, 0.98)
const WHITE_MUTED := Color(0.72, 0.79, 0.84, 0.72)
const CYAN := Color(0.18, 0.82, 1.0, 0.95)
const CYAN_DIM := Color(0.12, 0.52, 0.68, 0.24)
const AMBER := Color(1.0, 0.74, 0.14, 1.0)
const REDLINE := Color(1.0, 0.22, 0.28, 0.92)

@onready var camera: Camera3D = $Camera3D
@onready var interface: CanvasLayer = $Interface
@onready var scene_viewport: SubViewport = $SceneViewport
@onready var background_plane: MeshInstance3D = $BackgroundPlane
@onready var showcase_block: CharacterBody3D = $SceneViewport/ThirdPersonShowcaseWorld/ThirdPersonBlock

var world: MoldRuntimeInstance
var handles: Array[MoldHandle] = []
var gauge_items: Array[Dictionary] = []
var gauge_labels: Array[Dictionary] = []
var tach_ticks: Array[MoldHandle] = []

var boost_track: MoldHandle
var boost_fill: MoldHandle
var boost_ready_ring: MoldHandle
var gear_plate: MoldHandle

var speed_label: Label
var gear_label: Label
var boost_label: Label
var title_label: Label

var elapsed := 0.0
var speed := 96.0
var boost := 0.62
var rpm_normalized := 0.45
var gear := 3
var smoke_test := false
var smoke_frames := 0
var initial_block_position := Vector3.ZERO


func _enter_tree() -> void:
	var args := OS.get_cmdline_user_args()
	smoke_test = "--smoke-test" in args


func _ready() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CANVAS_HEIGHT
	camera.position = Vector3(0.0, 0.0, 10.0)
	_build_background_plane()
	initial_block_position = showcase_block.global_position

	var settings := MoldWorldSettings.new()
	settings.capacity = 128
	settings.lod_mode = MoldWorldSettings.LodMode.MANUAL
	settings.retained_unused_mesh_count = 24
	world = MoldRuntime.create_instance(self, settings)

	_build_speedometer()
	_build_copy()
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()
	_update_hud()


func _process(delta: float) -> void:
	elapsed += delta
	_update_simulation(delta)
	_update_hud()

	if smoke_test:
		smoke_frames += 1
		if smoke_frames >= 12:
			for component_path in ["MotionTracker", "NavigationCompass", "WeaponWheel"]:
				var component := get_node_or_null(component_path)
				if component == null or component.get_script() == null or component.get("world") == null:
					push_error("UI showcase component failed to initialize: %s" % component_path)
					get_tree().quit(1)
					return
			if showcase_block.global_position.distance_to(initial_block_position) < 0.01:
				push_error("Third-person showcase block did not move during smoke test.")
				get_tree().quit(1)
				return
			print("MOLD_UI_SHOWCASE_SMOKE_OK port=gdscript")
			get_tree().quit()


func _exit_tree() -> void:
	for handle in handles:
		if handle and handle.is_valid:
			handle.release()
	handles.clear()
	tach_ticks.clear()
	gauge_items.clear()
	if world:
		world.dispose()
	world = null


func _build_speedometer() -> void:
	# The circular plate is deliberately quiet; the moving information sits on
	# its perimeter and leaves the large speed value unobstructed.
	_add_gauge(MoldShape.disc(1.34), MoldStyle.transparent(INK), Vector3.ZERO, -30)
	_add_gauge(MoldShape.ring(1.34, 0.018), MoldStyle.transparent(INK_EDGE), Vector3.ZERO, -20)
	_add_gauge(MoldShape.ring(1.18, 0.018), MoldStyle.transparent(TRACK_STRONG), Vector3.ZERO, -10)
	_add_gauge(MoldShape.ring(0.73, 0.012), MoldStyle.transparent(INK_EDGE), Vector3.ZERO, -10)

	# Forty-one retained ticks provide a readable RPM range without a needle.
	# Major ticks are longer; the final six establish the redline before it is active.
	for index in TICK_COUNT:
		var ratio := float(index) / float(TICK_COUNT - 1)
		var angle := lerpf(TACH_START, TACH_END, ratio)
		var major := index % 5 == 0
		var tick_length := 0.16 if major else 0.09
		var radius := GAUGE_RADIUS - tick_length * 0.5
		var local := Vector3(cos(angle) * radius, sin(angle) * radius, 0.0)
		var base_color := REDLINE * Color(1, 1, 1, 0.28) if index >= TICK_COUNT - 6 else TRACK
		var tick := _add_gauge(
			MoldShape.rectangle(Vector2(0.026 if major else 0.016, tick_length), 0.5),
			MoldStyle.transparent(base_color), local, 20,
			Quaternion(Vector3.BACK, angle)
		)
		tach_ticks.append(tick)

	# A compact secondary gauge carries nitrous state without competing with speed.
	# Nitro is a separate satellite instrument. Its center and radius leave a
	# deliberate gap from the tachometer plate, so neither silhouette muddies the
	# other when both are bright.
	var boost_center := Vector3(-1.86, -0.18, 0.0)
	boost_track = _add_gauge(
		MoldShape.ring(0.42, 0.055, deg_to_rad(104.0), deg_to_rad(164.0)),
		MoldStyle.transparent(CYAN_DIM), boost_center, 4)
	boost_fill = _add_gauge(
		MoldShape.ring(0.42, 0.055, deg_to_rad(104.0), deg_to_rad(100.0)),
		MoldStyle.additive(CYAN), boost_center, 12)
	boost_ready_ring = _add_gauge(
		MoldShape.ring(0.51, 0.022, deg_to_rad(96.0), deg_to_rad(180.0),
			MoldDash.new(8, 16, 0.52, 0.0, MoldDash.Type.ROUNDED, 0.75)),
		MoldStyle.additive(Color(AMBER.r, AMBER.g, AMBER.b, 0.0)), boost_center, 14)

	# Gear is a small bounded status; all other numeric hierarchy belongs to speed.
	gear_plate = _add_gauge(
		MoldShape.rectangle_rim(Vector2(0.34, 0.28), 0.018, 0.06),
		MoldStyle.transparent(TRACK_STRONG), Vector3(0.0, -0.55, 0.0), 10)

	# A few low-contrast lines keep the empty screen intentional without turning
	# the showcase into a dashboard.
	_add_fixed(MoldShape.line_2d(Vector3(-7.5, 2.7, 0), Vector3(-4.7, 2.7, 0), 0.015),
		MoldStyle.transparent(Color(0.25, 0.78, 1.0, 0.14)), Vector3.ZERO, -50)
	_add_fixed(MoldShape.line_2d(Vector3(-7.5, 2.55, 0), Vector3(-6.2, 2.55, 0), 0.008),
		MoldStyle.transparent(Color(0.75, 0.84, 0.9, 0.10)), Vector3.ZERO, -50)


func _build_copy() -> void:
	speed_label = _add_gauge_label("096", Vector3(0.0, 0.08, 0.0), Vector2(190, 72), 54, WHITE)
	gear_label = _add_gauge_label("3", Vector3(0.0, -0.55, 0.0), Vector2(34, 30), 16, WHITE)
	boost_label = _add_gauge_label("N2O", Vector3(-1.86, -0.72, 0.0), Vector2(54, 24), 12, CYAN)
	_add_gauge_label("KM/H", Vector3(0.0, 0.55, 0.0), Vector2(90, 22), 11, WHITE_MUTED)

	for index in 8:
		var ratio := float(index) / 7.0
		var angle := lerpf(TACH_START, TACH_END, ratio)
		var local := Vector3(cos(angle) * 0.88, sin(angle) * 0.88, 0.0)
		_add_gauge_label(str(index + 1), local, Vector2(24, 20), 10,
			Color(1.0, 0.42, 0.46, 0.72) if index >= 6 else WHITE_MUTED)

	title_label = _make_label("MOLD / UI SHOWCASE", 20, Color(0.88, 0.94, 0.97, 0.92), HORIZONTAL_ALIGNMENT_LEFT)


func _update_simulation(delta: float) -> void:
	var target := 122.0 + sin(elapsed * 0.72) * 76.0 + sin(elapsed * 1.83) * 18.0
	speed = move_toward(speed, clampf(target, 18.0, 238.0), delta * 48.0)
	boost = clampf(0.58 + sin(elapsed * 0.46) * 0.48, 0.04, 1.0)

	gear = _gear_for_speed(speed)
	var lower_speed := SPEED_TOPS[maxi(0, gear - 1)] * (0.74 if gear > 1 else 0.0)
	var upper_speed := SPEED_TOPS[gear]
	rpm_normalized = clampf(remap(speed, lower_speed, upper_speed, 0.27, 1.0), 0.18, 1.0)


func _update_hud() -> void:
	speed_label.text = "%03d" % roundi(speed)
	gear_label.text = str(gear)
	var active_ticks := roundi(rpm_normalized * float(TICK_COUNT))
	var boost_ready := boost > 0.92

	for index in tach_ticks.size():
		var tick := tach_ticks[index]
		if index < active_ticks:
			if index >= TICK_COUNT - 6:
				tick.set_color(REDLINE)
			elif boost_ready:
				tick.set_color(AMBER)
			else:
				tick.set_color(WHITE)
		else:
			tick.set_color(Color(REDLINE.r, REDLINE.g, REDLINE.b, 0.24)
				if index >= TICK_COUNT - 6 else TRACK)

	var boost_span := maxf(deg_to_rad(1.0), deg_to_rad(164.0) * boost)
	boost_fill.set_shape(MoldShape.ring(0.42, 0.055, deg_to_rad(104.0), boost_span))
	boost_fill.set_color(AMBER if boost_ready else CYAN)
	boost_label.text = "READY" if boost_ready else "N2O"
	boost_label.add_theme_color_override("font_color", AMBER if boost_ready else CYAN)
	boost_ready_ring.set_color(Color(AMBER.r, AMBER.g, AMBER.b,
		0.42 + sin(elapsed * 6.0) * 0.22 if boost_ready else 0.0))


func _gear_for_speed(value: float) -> int:
	for index in range(1, SPEED_TOPS.size()):
		if value <= SPEED_TOPS[index]:
			return index
	return SPEED_TOPS.size() - 1


func _build_background_plane() -> void:
	var quad := QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = scene_viewport.get_texture()
	quad.material = material
	background_plane.mesh = quad


func _add_gauge(shape: MoldShape, style: MoldStyle, local_position: Vector3,
		order: int, rotation: Quaternion = Quaternion.IDENTITY) -> MoldHandle:
	var handle := world.create(shape, style, _ui_state(order))
	handle.set_transform(_gauge_center() + local_position, rotation, Vector3.ONE)
	handles.append(handle)
	gauge_items.append({"handle": handle, "local": local_position})
	return handle


func _add_fixed(shape: MoldShape, style: MoldStyle, position: Vector3, order: int) -> MoldHandle:
	var handle := world.create(shape, style, _ui_state(order))
	handle.set_position(position)
	handles.append(handle)
	return handle


func _ui_state(order: int) -> MoldRenderState:
	return MoldRenderState.new(
		1, order, MoldRenderState.DepthTest.ALWAYS,
		MoldRenderState.DepthWrite.DISABLED,
		MoldRenderState.StencilFlags.DISABLED,
		MoldRenderState.StencilCompare.ALWAYS, 0,
		MoldRenderState.FaceCull.DISABLED)


func _gauge_center() -> Vector3:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var half_width := CANVAS_HEIGHT * aspect * 0.5
	return Vector3(half_width - 1.55, -CANVAS_HEIGHT * 0.5 + 1.50, 0.0)


func _layout_hud() -> void:
	var center := _gauge_center()
	for item in gauge_items:
		(item.handle as MoldHandle).set_position(center + item.local)

	for item in gauge_labels:
		var label := item.label as Label
		var screen := camera.unproject_position(center + item.local)
		label.position = screen - item.size * 0.5

	var viewport_size := get_viewport().get_visible_rect().size
	var pixel_size := Vector2i(maxi(1, roundi(viewport_size.x)), maxi(1, roundi(viewport_size.y)))
	scene_viewport.size = pixel_size
	var background_quad := background_plane.mesh as QuadMesh
	background_quad.size = Vector2(CANVAS_HEIGHT * viewport_size.x / maxf(viewport_size.y, 1.0), CANVAS_HEIGHT)
	title_label.position = Vector2(42.0, 38.0)
	title_label.size = Vector2(360.0, 28.0)


func _add_gauge_label(text: String, local: Vector3, size: Vector2,
		font_size: int, color: Color) -> Label:
	var label := _make_label(text, font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.size = size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gauge_labels.append({"label": label, "local": local, "size": size})
	return label


func _make_label(text: String, font_size: int, color: Color,
		alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.88))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", font_size)
	interface.add_child(label)
	return label
