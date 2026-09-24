extends Node3D

## A deterministic, code-built, 38-second release reel for Mold.
##
## The scene deliberately keeps its direction, set dressing, animation curves, and
## minimal capture overlay in one sample-local script. Retained geometry is
## prepared before the clock starts; the immediate solar system is rebuilt each
## frame; the stress grid lives in its own runtime so its statistics remain truthful.

const FPS := 60.0
const SHOW_DURATION := 38.0
const CAPTURE_FRAME_COUNT := 2280
const STAGE_GAP := 160.0
const PERF_DEFAULT_COUNT := 160000
const PERF_ANIMATED_LIMIT := 20000
const PERF_BUILD_CHUNK := 5000
const PERF_LAYER_MASK := 1 << 1
const GROUND_ROTATION := Quaternion(Vector3.RIGHT, -PI * 0.5)

const INK := Color("080817")
const INK_SOFT := Color("151332")
const CREAM := Color("fff3c4")
const LEMON := Color("ffe044")
const CORAL := Color("ff6b72")
const PINK := Color("ff62c7")
const VIOLET := Color("825cff")
const CYAN := Color("54e8ff")
const MINT := Color("67f5b5")
const BLUE := Color("4285ff")

enum Chapter {
	LOGO_INTRO,
	SOLAR_SYSTEM,
	ONE_SHAPE,
	EVERY_FORM,
	COLOR_STYLES,
	LINES,
	PERFORMANCE,
	FINALE,
}

const CHAPTER_STARTS: Array[float] = [0.0, 5.0, 9.0, 13.0, 17.0, 21.0, 25.0, 29.0]
# The four-second chapters still evaluate their complete original timing
# envelopes so every formation and reveal resolves before the next cut.
const CHAPTER_CONTENT_DURATIONS: Array[float] = [5.0, 7.0, 4.0, 6.0, 6.0, 6.0, 6.0, 9.0]
const CHAPTER_STAGES: Array[int] = [9, 5, 0, 1, 2, 3, 8, 9]
const CHAPTER_CAMERA_SIZES: Array[float] = [11.5, 12.0, 10.4, 15.0, 12.4, 11.2, 0.22, 11.5]

@onready var camera: Camera3D = $Camera3D

var world: MoldRuntimeInstance
var performance_world: MoldRuntimeInstance
var all_handles: Array[MoldHandle] = []

var catalog_handles: Array[Dictionary] = []
var style_handles: Array[Dictionary] = []
var stroke_handles: Array[Dictionary] = []
var stroke_other_handles: Array[Dictionary] = []
var author_handles: Array[Dictionary] = []
var city_handles: Array[Dictionary] = []
var city_route_points: Array[Vector3] = []
var city_route_segment_lengths := PackedFloat32Array()
var city_route_total_length := 0.0
var city_cars: Array[Dictionary] = []
var hex_handles: Array[Dictionary] = []
var hex_units: Array[Dictionary] = []
var wind_handles: Array[MoldHandle] = []
var wind_base_starts := PackedVector3Array()
var wind_base_ends := PackedVector3Array()
var wind_starts := PackedVector3Array()
var wind_ends := PackedVector3Array()
var finale_handles: Array[Dictionary] = []
var logo_primitives: Array[Dictionary] = []
var hero: MoldHandle
var wipe: MoldHandle
var polyline_handle: MoldHandle
var author_node: MoldNode3D
var author_shapes: Array[MoldShapeResource] = []
var author_style: MoldStyleResource
var hero_shapes: Array[MoldShape] = []

var performance_animated_handles: Array[MoldHandle] = []
var performance_base_positions := PackedVector3Array()
var performance_animated_positions := PackedVector3Array()
var performance_animated_indices: Dictionary = {}
var performance_shapes: Array[MoldShape] = []
var performance_styles: Array[MoldStyle] = []
var performance_static_state: MoldRenderState
var performance_animated_state: MoldRenderState
var performance_count := PERF_DEFAULT_COUNT
var performance_columns := 1
var performance_rows := 1
var performance_built := 0
var performance_width := 0.0
var performance_depth := 0.0
var performance_frame_size := 0.0
var performance_closeup_focus := Vector3.ZERO

var stars: Array[Dictionary] = []
var planets: Array[Dictionary] = []

var interface: CanvasLayer
var shade: ColorRect
var opening_card: Label
var tagline: Label

var show_time := 0.0
var current_chapter := -1
var paused := false
var no_loop := false
var capture_mode := false
var capture_frame := 0
var fixed_start_time := -1.0
var smoke_test := false
var smoke_frames := 0
var ready_to_play := false
var hero_shape_index := -1
var author_beat := -1


func _enter_tree() -> void:
	_parse_arguments()


func _ready() -> void:
	camera.cull_mask &= ~PERF_LAYER_MASK
	var settings := MoldWorldSettings.new()
	settings.capacity = 12000
	settings.retained_unused_mesh_count = 96
	settings.culling_bounds_padding = 0.35
	settings.lod_mode = MoldWorldSettings.LodMode.CONTINUOUS
	settings.lod_transition_width = 0.15
	world = MoldRuntime.create_instance(self, settings)

	var performance_settings := MoldWorldSettings.new()
	performance_settings.capacity = maxi(performance_count, 1)
	performance_settings.retained_unused_mesh_count = 8
	performance_settings.culling_bounds_padding = 0.35
	performance_settings.culling_mode = MoldWorldSettings.CullingMode.NONE
	performance_settings.lod_mode = MoldWorldSettings.LodMode.CONTINUOUS
	performance_settings.lod_transition_width = 0.15
	performance_world = MoldRuntime.create_instance(self, performance_settings)

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.05
	camera.far = 1200.0
	_create_interface()
	_build_presentation()
	_prepare_performance_layout()
	# Finish construction before the renderer sees the first batch. Incremental
	# frame building repeatedly uploaded every already-created instance.
	while not ready_to_play:
		_build_performance_chunk()


func _process(delta: float) -> void:
	if not ready_to_play:
		_build_performance_chunk()
		return

	if capture_mode:
		if fixed_start_time >= 0.0:
			show_time = fixed_start_time
		else:
			if capture_frame >= CAPTURE_FRAME_COUNT:
				get_tree().quit()
				return
			show_time = capture_frame / FPS
			capture_frame += 1
	elif not paused:
		show_time += delta

	if show_time >= SHOW_DURATION:
		if no_loop or capture_mode:
			show_time = SHOW_DURATION - 0.001
			_evaluate_showcase()
			get_tree().quit()
			return
		show_time = fposmod(show_time, SHOW_DURATION)
		_reset_discrete_state()

	_evaluate_showcase()
	if smoke_test:
		smoke_frames += 1
		if smoke_frames >= 6:
			print("MOLD_SHOWCASE_SMOKE_OK port=gdscript")
			get_tree().quit()


func _exit_tree() -> void:
	for handle in all_handles:
		if handle and handle.is_valid:
			handle.release()
	all_handles.clear()
	performance_animated_handles.clear()
	if performance_world:
		performance_world.dispose()
	if world:
		world.dispose()
	performance_world = null
	world = null


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			paused = not paused
		KEY_R:
			show_time = 0.0
			capture_frame = 0
			_reset_discrete_state()
		KEY_LEFT:
			show_time = CHAPTER_STARTS[maxi(0, _chapter_at(show_time) - 1)] + 0.02
			_reset_discrete_state()
		KEY_RIGHT:
			show_time = CHAPTER_STARTS[mini(CHAPTER_STARTS.size() - 1, _chapter_at(show_time) + 1)] + 0.02
			_reset_discrete_state()
		_:
			return
	get_viewport().set_input_as_handled()


func _build_presentation() -> void:
	_create_intro()
	_create_catalog()
	_create_styles()
	_create_strokes()
	_create_solar_data()
	_create_finale()
	_create_wipe()


func _create_intro() -> void:
	var anchor := _stage_anchor(CHAPTER_STAGES[Chapter.ONE_SHAPE])
	_add_floor(anchor, Vector3(9.0, 0.24, 9.0), INK_SOFT, VIOLET)
	_retain(world.create_transformed(
		MoldShape.cylinder(1.7, 0.34, 0.2, MoldShape.Detail.MEDIUM),
		anchor + Vector3.UP * 0.17, Quaternion.IDENTITY, Vector3.ONE,
		MoldStyle.dual_gradient(Color("2d2362"), VIOLET, 0.18)))
	hero_shapes = [
		MoldShape.sphere(0.88, MoldShape.Detail.HIGH),
		MoldShape.cuboid(Vector3.ONE * 1.35, 0.34, MoldShape.Detail.MEDIUM),
		MoldShape.torus(0.75, 0.27, 0.0, TAU, MoldShape.Detail.MEDIUM),
		MoldShape.capsule(0.5, 1.7, MoldShape.Detail.MEDIUM),
		MoldShape.regular_prism(6, 0.76, 1.35, 0.24, MoldShape.Detail.MEDIUM),
		MoldShape.cone(0.8, 1.5, MoldShape.Detail.MEDIUM),
	]
	hero = _retain(world.create_transformed(
		hero_shapes[0], anchor + Vector3.UP * 1.55,
		Quaternion.IDENTITY, Vector3.ONE,
		MoldStyle.dual_gradient(PINK, CREAM, Vector3(0.4, 1.0, 0.2), MoldStyle.GradientSpace.WORLD,
			MoldStyle.BlendMode.OPAQUE, MoldStyle.ColorInterpolation.OKLAB, 0.3)))
	world.prewarm(hero_shapes)


func _create_catalog() -> void:
	var anchor := _stage_anchor(CHAPTER_STAGES[Chapter.EVERY_FORM])
	_add_floor(anchor, Vector3(21.0, 0.22, 12.0), Color("080d24"), Color("243d82"))
	var shapes: Array[MoldShape] = [
		MoldShape.rectangle(Vector2(1.25, 0.92), 0.3), MoldShape.rectangle_rim(Vector2(1.25, 0.92), 0.14, 0.28),
		MoldShape.disc(0.68, 0.2, PI * 1.7), MoldShape.ring(0.68, 0.15, 0.2, PI * 1.7, MoldDash.corner(12)),
		MoldShape.regular_polygon(5, 0.72, 0.18), MoldShape.regular_polygon_rim(6, 0.72, 0.14, 0.24, MoldDash.edge(6)),
		MoldShape.cuboid(Vector3(1.15, 1.05, 1.15), 0.3, MoldShape.Detail.MEDIUM),
		MoldShape.cylinder(0.62, 1.18, 0.3, MoldShape.Detail.MEDIUM), MoldShape.regular_prism(6, 0.66, 1.2, 0.24, MoldShape.Detail.MEDIUM),
		MoldShape.cone(0.68, 1.3, MoldShape.Detail.MEDIUM), MoldShape.sphere(0.68, MoldShape.Detail.MEDIUM),
		MoldShape.hemisphere(0.72, true, MoldShape.Detail.MEDIUM), MoldShape.capsule(0.46, 1.45, MoldShape.Detail.MEDIUM),
		MoldShape.torus(0.56, 0.25, 0.35, PI * 1.7, MoldShape.Detail.MEDIUM),
	]
	world.prewarm(shapes)
	var shape_count := shapes.size()
	for index in shape_count:
		var column := index % 7
		var row := index / 7
		var position := anchor + Vector3((column - 3) * 2.2, 0.9, (row - 0.5) * 3.2)
		var shape := shapes[index]
		var rotation := GROUND_ROTATION if shape.is_2d else Quaternion(Vector3.UP, deg_to_rad(index * 21.0))
		var style := _gradient_style(index)
		var handle := _retain(world.create_transformed(shape, position, rotation, Vector3.ONE, style))
		catalog_handles.append({
			"handle": handle, "home": position, "rotation": rotation, "index": index,
			"phase": index * 0.37,
		})


func _create_styles() -> void:
	var anchor := _stage_anchor(CHAPTER_STAGES[Chapter.COLOR_STYLES])
	var floor_handle := _add_floor(anchor, Vector3(14.0, 0.2, 10.0), Color("29102f"), PINK)
	style_handles.append({"handle": floor_handle, "position": anchor + Vector3.DOWN * 0.1,
		"rotation": Quaternion.IDENTITY, "scale": Vector3.ONE, "phase": 0.0, "index": -1})
	var styles: Array[MoldStyle] = [
		MoldStyle.opaque(LEMON), MoldStyle.transparent(Color(1.0, 0.35, 0.68, 0.66)),
		MoldStyle.additive(Color(0.25, 0.9, 1.0, 0.72)), MoldStyle.color_dodge(Color(0.4, 0.45, 1.0, 0.58)),
		MoldStyle.screen(Color(1.0, 0.35, 0.75, 0.68)), MoldStyle.lighten(Color(1.0, 0.82, 0.25, 0.72)),
		MoldStyle.linear_burn(Color(0.35, 0.12, 0.72, 0.85)), MoldStyle.color_burn(Color(0.92, 0.3, 0.55, 0.66)),
		MoldStyle.multiplicative(Color(0.24, 0.8, 0.92, 0.72)), MoldStyle.darken(Color(0.05, 0.03, 0.18, 0.95)),
		MoldStyle.subtractive(Color(0.82, 0.35, 0.2, 0.78)), MoldStyle.dither(Color(1.0, 0.9, 0.2, 0.58)),
		MoldStyle.dual_radial(PINK, CYAN, MoldStyle.BlendMode.OPAQUE,
			MoldStyle.ColorInterpolation.OKLAB, 0.5),
	]
	var style_count := styles.size()
	for index in style_count:
		var angle := TAU * index / style_count
		var radius := 4.5 if index < 8 else 2.55
		var position := anchor + Vector3(cos(angle) * radius, 0.82 + (index % 3) * 0.22, sin(angle) * radius)
		var shape := MoldShape.disc(0.76).with_billboard() if index == style_count - 1 else \
			MoldShape.regular_prism(6, 0.72, 1.15, 0.3, MoldShape.Detail.MEDIUM)
		var rotation := Quaternion.IDENTITY if index == style_count - 1 else Quaternion(Vector3.UP, -angle)
		var handle := _retain(world.create_transformed(
			shape, position, rotation, Vector3.ONE, styles[index]))
		style_handles.append({"handle": handle, "position": position, "rotation": rotation,
			"scale": Vector3.ONE, "phase": angle, "index": index})
		var backing_position := Vector3(position.x, 0.06, position.z)
		var backing := _retain(world.create_transformed(
			MoldShape.cylinder(0.9, 0.12, 0.22, MoldShape.Detail.MEDIUM), backing_position,
			Quaternion.IDENTITY, Vector3.ONE,
			MoldStyle.dual_gradient(Color("413f68"), Color("aaa6ce"), 0.05)))
		style_handles.append({"handle": backing, "position": backing_position,
			"rotation": Quaternion.IDENTITY, "scale": Vector3.ONE, "phase": 0.0,
			"index": index + 100})


func _create_strokes() -> void:
	var anchor := _stage_anchor(CHAPTER_STAGES[Chapter.LINES])
	var floor_handle := _add_floor(anchor, Vector3(14.5, 0.2, 10.0), Color("06121c"), Color("153a4b"))
	stroke_other_handles.append({"handle": floor_handle, "position": anchor + Vector3.DOWN * 0.1,
		"rotation": Quaternion.IDENTITY, "scale": Vector3.ONE})
	var line_starts: Array[Vector3] = [Vector3(-5.0, 0.0, -2.45), Vector3(-5.0, 0.0, -0.95),
		Vector3(-5.0, 0.0, 0.55)]
	var line_ends: Array[Vector3] = [Vector3(5.0, 0.0, -2.45), Vector3(5.0, 0.0, -0.95),
		Vector3(5.0, 0.0, 0.55)]
	var line_shapes: Array[MoldShape] = [
		MoldShape.line_2d(line_starts[0], line_ends[0], 0.34, MoldShape.BillboardMode.FACE_CAMERA),
		MoldShape.line_3d(line_starts[1], line_ends[1], 0.38, 0.4),
		MoldShape.line_3d(line_starts[2], line_ends[2], 0.42, 0.0, MoldShape.Detail.MEDIUM),
	]
	var line_shape_count := line_shapes.size()
	for index in line_shape_count:
		var total := 11 + index * 4
		var line_state: MoldRenderState = null
		if index == 0:
			line_state = MoldRenderState.new(1, 0, MoldRenderState.DepthTest.LESS_EQUAL,
				MoldRenderState.DepthWrite.AUTO, MoldRenderState.StencilFlags.DISABLED,
				MoldRenderState.StencilCompare.ALWAYS, 0, MoldRenderState.FaceCull.DISABLED)
		var handle := _retain(world.create_transformed(line_shapes[index], anchor + Vector3.UP * 0.9,
			Quaternion.IDENTITY, Vector3.ONE, _gradient_style(index + 1), line_state))
		stroke_handles.append({
			"handle": handle, "index": index, "position": anchor + Vector3.UP * 0.9,
			"rotation": Quaternion.IDENTITY, "scale": Vector3.ONE, "dash_total": total,
		})

	var stroke_polyline_base_points: Array[Vector2] = [Vector2(-5.0, -3.75), Vector2(-3.2, -3.05),
		Vector2(-1.2, -3.7), Vector2(0.8, -2.95), Vector2(2.9, -3.65), Vector2(5.0, -3.0)]
	var stroke_polyline_colors: Array[Color] = [PINK, CORAL, LEMON, MINT, CYAN, VIOLET]
	var stroke_polyline_widths := PackedFloat32Array([0.82, 1.25, 0.92, 1.42, 1.08, 0.82])
	var points: Array[MoldPolylinePoint] = []
	var stroke_point_count := stroke_polyline_base_points.size()
	for index in stroke_point_count:
		var point := stroke_polyline_base_points[index]
		points.append(MoldPolylinePoint.new(Vector3(point.x, point.y, 0.0),
			stroke_polyline_colors[index], stroke_polyline_widths[index]))
	var polyline := MoldPolyline.new(points, 0.44, false, MoldPolyline.Join.ROUND, MoldPolyline.Cap.ROUND, 4.0, 12)
	polyline_handle = _retain(world.create_polyline_transformed(polyline, anchor + Vector3.UP * 0.92,
		Quaternion(Vector3.RIGHT, -PI * 0.5), Vector3.ONE, MoldStyle.opaque(Color.WHITE)))


func _create_authoring() -> void:
	var anchor := _stage_anchor(4)
	_add_floor(anchor, Vector3(13.0, 0.2, 10.0), Color("15112e"), Color("3d2670"))
	author_shapes = [
		_author_shape_resource(MoldShape.Kind.CUBOID, Vector3(2.3, 2.3, 2.3), 0.5, 1.0, 0.1, 0.36),
		_author_shape_resource(MoldShape.Kind.SPHERE, Vector3.ONE, 1.28),
		_author_shape_resource(MoldShape.Kind.REGULAR_PRISM, Vector3.ONE, 1.25, 2.4, 0.1, 0.34, 6),
		_author_shape_resource(MoldShape.Kind.TORUS, Vector3.ONE, 1.2, 1.0, 0.38),
	]
	author_style = MoldStyleResource.new()
	author_style.color = VIOLET
	author_style.secondary_color = PINK
	author_style.color_mode = MoldStyle.ColorMode.DUAL_GRADIENT
	author_style.color_interpolation = MoldStyle.ColorInterpolation.OKLAB
	author_style.gradient_space = MoldStyle.GradientSpace.OBJECT
	author_style.gradient_direction = Vector3(0.3, 1.0, 0.2)
	author_style.emission_strength = 0.2
	author_node = MoldNode3D.new()
	author_node.name = "LiveAuthoredMold"
	author_node.shape = author_shapes[0]
	author_node.style = author_style
	author_node.position = anchor + Vector3.UP * 1.7
	add_child(author_node)
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var axis_colors: Array[Color] = [CORAL, MINT, CYAN]
	var axis_count := axes.size()
	for index in axis_count:
		var start := Vector3.UP * 1.7
		var end := start + axes[index] * 3.5
		var axis := _retain(world.create_transformed(
			MoldShape.line_3d(start, end, 0.12, 0.0, MoldShape.Detail.MEDIUM),
			anchor, Quaternion.IDENTITY, Vector3.ONE, MoldStyle.additive(axis_colors[index])))
		author_handles.append({"handle": axis, "position": anchor,
			"index": index + 1, "phase": index * 0.3})
		_retain(world.create_transformed(
			MoldShape.sphere(0.22, MoldShape.Detail.MEDIUM),
			anchor + end, Quaternion.IDENTITY, Vector3.ONE, MoldStyle.opaque(axis_colors[index])))
	for index in 8:
		var angle := TAU * index / 8.0
		var position := anchor + Vector3(cos(angle) * 4.0,
			0.55 + (index % 2) * 2.9, sin(angle) * 3.1)
		var knob := _retain(world.create_transformed(
			MoldShape.sphere(0.25, MoldShape.Detail.MEDIUM), position,
			Quaternion.IDENTITY, Vector3.ONE,
			MoldStyle.opaque(CREAM if index % 2 == 0 else LEMON)))
		author_handles.append({"handle": knob, "position": position,
			"index": index + 10, "phase": angle})


func _create_solar_data() -> void:
	planets = [
		{"orbit": 0.95, "radius": 0.09, "speed": 2.25, "phase": 0.2, "inclination": 0.08, "low": Color("30251f"), "high": Color("d2bd9e"), "ringed": false},
		{"orbit": 1.42, "radius": 0.15, "speed": 1.62, "phase": 1.4, "inclination": -0.04, "low": Color("442b1e"), "high": Color("f0b96e"), "ringed": false},
		{"orbit": 2.0, "radius": 0.18, "speed": 1.25, "phase": 2.8, "inclination": 0.03, "low": Color("123c67"), "high": Color("58b9ff"), "ringed": false},
		{"orbit": 2.62, "radius": 0.13, "speed": 0.94, "phase": 4.1, "inclination": -0.07, "low": Color("5b2920"), "high": Color("e77b50"), "ringed": false},
		{"orbit": 3.42, "radius": 0.34, "speed": 0.58, "phase": 5.0, "inclination": 0.04, "low": Color("66452d"), "high": Color("e7c89f"), "ringed": false},
		{"orbit": 4.25, "radius": 0.28, "speed": 0.42, "phase": 0.8, "inclination": -0.03, "low": Color("5d4b2d"), "high": Color("f1d58e"), "ringed": true},
		{"orbit": 5.0, "radius": 0.2, "speed": 0.31, "phase": 2.2, "inclination": 0.02, "low": Color("315c68"), "high": Color("a6e9e8"), "ringed": true},
	]
	for index in 120:
		var angle := _hash01_pair(index, 17) * TAU
		var b := _hash01_pair(index, 29) * 2.0 - 1.0
		var radius := 5.6 + _hash01_pair(index, 43) * 2.4
		var horizontal := sqrt(maxf(0.0, 1.0 - b * b))
		var star_color := CREAM if index % 4 == 0 else (CYAN if index % 4 == 1 else (Color("b7c9ff") if index % 4 == 2 else Color("ffd6a3")))
		stars.append({
			"position": Vector3(cos(angle) * horizontal * radius, b * radius * 0.62,
				sin(angle) * horizontal * radius),
			"radius": 0.025 + _hash01_pair(index, 61) * 0.035,
			"phase": _hash01_pair(index, 73) * TAU,
			"brightness": 0.38 + _hash01_pair(index, 89) * 0.55,
			"color": star_color, "pointed": index % 11 == 0,
		})


func _create_mini_city() -> void:
	var anchor := _stage_anchor(6)
	var floor_handle := _add_floor(anchor, Vector3(16.0, 0.32, 11.0), Color("e9eff5"), Color("b9dbe7"))
	city_handles.append({"handle": floor_handle, "position": anchor + Vector3.DOWN * 0.16,
		"rotation": Quaternion.IDENTITY, "scale": Vector3.ONE, "index": -1, "phase": 0.0})
	# One authored route drives the visible road and every vehicle. Buildings sit
	# inside the rounded loop, leaving a guaranteed clear lane around the blocks.
	var corner_centers: Array[Vector2] = [
		Vector2(5.25, -3.25), Vector2(5.25, 3.25),
		Vector2(-5.25, 3.25), Vector2(-5.25, -3.25),
	]
	var corner_start_angles: Array[float] = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for corner in 4:
		for step in 5:
			var angle := corner_start_angles[corner] + step * (PI * 0.5 / 4.0)
			var point := corner_centers[corner] + Vector2(cos(angle), sin(angle)) * 1.1
			city_route_points.append(Vector3(point.x, 0.0, point.y))
	var route_point_count := city_route_points.size()
	city_route_segment_lengths.resize(route_point_count)
	var road_points: Array[MoldPolylinePoint] = []
	for index in route_point_count:
		var point := city_route_points[index]
		var next := city_route_points[(index + 1) % route_point_count]
		var length := point.distance_to(next)
		city_route_segment_lengths[index] = length
		city_route_total_length += length
		road_points.append(MoldPolylinePoint.new(Vector3(point.x, -point.z, 0.0), Color.WHITE))
	var canonical_base := _retain(world.create_polyline_transformed(
		MoldPolyline.new(road_points, 1.68, true, MoldPolyline.Join.ROUND,
			MoldPolyline.Cap.BUTT, 4.0, 10), anchor + Vector3.UP * 0.18,
		GROUND_ROTATION, Vector3.ONE, MoldStyle.opaque(Color("35536a"))))
	city_handles.append({"handle": canonical_base, "position": anchor + Vector3.UP * 0.18,
		"rotation": GROUND_ROTATION, "scale": Vector3.ONE, "index": 0, "phase": 0.0})
	var canonical_surface := _retain(world.create_polyline_transformed(
		MoldPolyline.new(road_points, 1.38, true, MoldPolyline.Join.ROUND,
			MoldPolyline.Cap.BUTT, 4.0, 10), anchor + Vector3.UP * 0.205,
		GROUND_ROTATION, Vector3.ONE, MoldStyle.opaque(Color("e7f1ed"))))
	city_handles.append({"handle": canonical_surface, "position": anchor + Vector3.UP * 0.205,
		"rotation": GROUND_ROTATION, "scale": Vector3.ONE, "index": 1, "phase": 0.0})
	for marker in 40:
		var pose := _sample_city_route(marker * city_route_total_length / 40.0, 0.0)
		var position: Vector3 = pose.position
		position.y = 0.245
		var tangent: Vector3 = pose.tangent
		var rotation := Quaternion(Vector3.UP, atan2(-tangent.z, tangent.x))
		var marker_scale := Vector3(0.34, 0.025, 0.065)
		var dash := _retain(world.create_transformed(
			MoldShape.cuboid(Vector3.ONE, 0.28, MoldShape.Detail.MEDIUM), position,
			rotation, marker_scale, MoldStyle.opaque(Color("f4ca55"))))
		city_handles.append({"handle": dash, "position": position, "rotation": rotation,
			"scale": marker_scale, "index": 200 + marker, "phase": marker * 0.12})
	var city_lows: Array[Color] = [Color("413e7a"), Color("2a718b"), Color("9b3f70"), Color("f38c4b")]
	var city_highs: Array[Color] = [Color("6c93c3"), Color("53b7d2"), Color("f36784"), Color("ffc15b")]
	var building_sites: Array[Vector2] = [
		Vector2(-3.65, -1.8), Vector2(-2.05, -1.7), Vector2(-0.35, -1.85),
		Vector2(1.45, -1.72), Vector2(3.35, -1.82), Vector2(-3.35, 1.7),
		Vector2(-1.55, 1.78), Vector2(0.25, 1.68), Vector2(2.05, 1.82), Vector2(3.65, 1.62),
	]
	var building_count := building_sites.size()
	for index in building_count:
		var site := building_sites[index]
		var height := 0.9 + _hash01_pair(roundi(site.x * 10.0), roundi(site.y * 10.0)) * 2.15
		var position := anchor + Vector3(site.x, 0.22 + height * 0.5, site.y)
		var body := _retain(world.create_transformed(
			MoldShape.cuboid(Vector3(1.05, height, 1.05), 0.24, MoldShape.Detail.MEDIUM),
			position, Quaternion.IDENTITY, Vector3.ONE,
			MoldStyle.dual_gradient(city_lows[index % 4], city_highs[index % 4], 0.25)))
		city_handles.append({"handle": body, "position": position,
			"rotation": Quaternion.IDENTITY, "scale": Vector3.ONE,
			"index": 20 + index, "phase": index * 0.23})
	for index in 8:
		var car_color := CORAL if index % 2 == 0 else BLUE
		var body := _retain(world.create_transformed(
			MoldShape.cuboid(Vector3(0.68, 0.2, 0.34), 0.42, MoldShape.Detail.MEDIUM),
			anchor, Quaternion.IDENTITY, Vector3.ONE,
			MoldStyle.dual_gradient(Color("34344c"), car_color, 0.12)))
		var roof := _retain(world.create_transformed(
			MoldShape.cuboid(Vector3(0.3, 0.14, 0.27), 0.5, MoldShape.Detail.MEDIUM),
			anchor, Quaternion.IDENTITY, Vector3.ONE, MoldStyle.opaque(Color("dceef7"))))
		var direction := -1.0 if index % 3 == 0 else 1.0
		city_cars.append({"body": body, "roof": roof,
			"speed": direction * (2.45 + (index % 3) * 0.2),
			"phase": index / 8.0, "lane_offset": direction * 0.22})
	for index in 4:
		var pulse_position := anchor + city_route_points[index * 5] + Vector3.UP * 0.31
		var pulse := _retain(world.create_transformed(MoldShape.ring(0.5, 0.055),
			pulse_position, GROUND_ROTATION, Vector3.ONE,
			MoldStyle.additive(Color(CYAN.r, CYAN.g, CYAN.b, 0.66))))
		city_handles.append({"handle": pulse, "position": pulse_position,
			"rotation": GROUND_ROTATION, "scale": Vector3.ONE,
			"index": 80 + index, "phase": index * 1.4})


func _create_hex_kingdom() -> void:
	var anchor := _stage_anchor(7)
	var floor_handle := _add_floor(anchor, Vector3(18.0, 0.3, 13.0), Color("0b0d1c"), Color("302c3f"))
	hex_handles.append({"handle": floor_handle, "position": anchor + Vector3.DOWN * 0.15,
		"rotation": Quaternion.IDENTITY, "scale": Vector3.ONE, "index": -1, "phase": 0.0})
	var lows: Array[Color] = [Color("4d7443"), Color("276379"), Color("875240"), Color("686273")]
	var highs: Array[Color] = [Color("8eae59"), Color("53b7b4"), Color("c78353"), Color("aaa0a5")]
	var tile_index := 0
	for q in range(-3, 4):
		var r_min := maxi(-3, -q - 3)
		var r_max := mini(3, -q + 3)
		for r in range(r_min, r_max + 1):
			var x := 1.25 * 1.5 * q
			var z := 1.25 * sqrt(3.0) * (r + q * 0.5)
			var height := 0.34 + _hash01_pair(q + 17, r - 23) * 0.58
			var position := anchor + Vector3(x, height * 0.5, z)
			var palette := (absi(q * 3 + r * 5) + tile_index) % lows.size()
			var rotation := Quaternion(Vector3.UP, PI)
			var tile := _retain(world.create_transformed(
				MoldShape.regular_prism(6, 1.18, height, 0.12, MoldShape.Detail.MEDIUM),
				position, rotation, Vector3.ONE,
				MoldStyle.dual_gradient(lows[palette], highs[palette], 0.22)))
			hex_handles.append({"handle": tile, "position": position, "rotation": rotation,
				"scale": Vector3.ONE, "index": tile_index, "phase": tile_index * 0.11})
			tile_index += 1
	var keep_position := anchor + Vector3.UP * 1.3
	var keep_body := _retain(world.create_transformed(
		MoldShape.cuboid(Vector3(1.9, 2.4, 1.9), 0.18, MoldShape.Detail.MEDIUM),
		keep_position, Quaternion.IDENTITY, Vector3.ONE,
		MoldStyle.dual_gradient(Color("8c3f35"), Color("f6ddb0"), 0.52)))
	hex_handles.append({"handle": keep_body, "position": keep_position,
		"rotation": Quaternion.IDENTITY, "scale": Vector3.ONE, "index": 100, "phase": 0.0})
	for tower in 4:
		var offset := Vector3(-1.0 if tower % 2 == 0 else 1.0, 0.0,
			-1.0 if tower < 2 else 1.0)
		var position := anchor + offset + Vector3.UP * 1.15
		var body := _retain(world.create_transformed(
			MoldShape.cylinder(0.34, 2.1, 0.2, MoldShape.Detail.MEDIUM), position,
			Quaternion.IDENTITY, Vector3.ONE,
			MoldStyle.dual_gradient(Color("8c3f35"), Color("e17b4f"), 0.45)))
		hex_handles.append({"handle": body, "position": position,
			"rotation": Quaternion.IDENTITY, "scale": Vector3.ONE,
			"index": 110 + tower, "phase": 0.0})
		var roof_position := position + Vector3.UP * 1.45
		var roof := _retain(world.create_transformed(
			MoldShape.cone(0.5, 0.9, MoldShape.Detail.MEDIUM), roof_position,
			Quaternion.IDENTITY, Vector3.ONE,
			MoldStyle.dual_gradient(Color("284862"), Color("59a4aa"), 0.65)))
		hex_handles.append({"handle": roof, "position": roof_position,
			"rotation": Quaternion.IDENTITY, "scale": Vector3.ONE,
			"index": 120 + tower, "phase": 0.0})
	for index in 4:
		var color := CYAN if index < 2 else CORAL
		var body := _retain(world.create_transformed(
			MoldShape.capsule(0.18, 0.72, MoldShape.Detail.MEDIUM), anchor,
			Quaternion.IDENTITY, Vector3.ONE,
			MoldStyle.dual_gradient(Color("17162b"), color, 0.32)))
		var pennant := _retain(world.create_transformed(
			MoldShape.regular_polygon(3, 0.22).with_billboard(), anchor,
			Quaternion.IDENTITY, Vector3.ONE,
			MoldStyle.additive(Color(color.r, color.g, color.b, 0.85))))
		hex_units.append({"body": body, "pennant": pennant, "center": anchor,
			"radius": 3.1 + index * 0.48, "speed": 0.43 + index * 0.04,
			"phase": index * 1.5})
	wind_handles.resize(18)
	wind_base_starts.resize(18)
	wind_base_ends.resize(18)
	wind_starts.resize(18)
	wind_ends.resize(18)
	for index in 18:
		var row := index % 6
		var lane := index / 6
		var start := anchor + Vector3(-6.5 + row * 2.25, 2.3 + lane * 0.42,
			-4.8 + lane * 4.8)
		var end := start + Vector3(1.1, 0.08, 0.2)
		var line := _retain(world.create_transformed(
			MoldShape.line_2d(start, end, 0.045, MoldShape.BillboardMode.FACE_CAMERA)
				.with_dash(MoldDash.new(3, 5, 0.38, index * 0.17,
					MoldDash.Type.CHEVRON, 0.7)), Vector3.ZERO,
			Quaternion.IDENTITY, Vector3.ONE,
			MoldStyle.additive(Color(CYAN.r, CYAN.g, CYAN.b, 0.42))))
		wind_handles[index] = line
		wind_base_starts[index] = start
		wind_base_ends[index] = end


func _create_finale() -> void:
	var strokes: Array[Array] = [
		[
			Vector2(-4.6, -0.55), Vector2(-4.5, 0.25), Vector2(-4.18, 1.25),
			Vector2(-3.9, 1.58), Vector2(-3.7, 0.58), Vector2(-3.52, -0.5),
			Vector2(-3.25, 0.42), Vector2(-2.98, 1.18), Vector2(-2.75, 0.34),
			Vector2(-2.62, -0.42), Vector2(-2.35, -0.08),
		],
		[
			Vector2(-2.4, -0.08), Vector2(-2.12, 0.36), Vector2(-1.62, 0.46),
			Vector2(-1.28, 0.12), Vector2(-1.36, -0.38), Vector2(-1.86, -0.56),
			Vector2(-2.24, -0.25), Vector2(-2.08, 0.2), Vector2(-1.56, 0.28),
			Vector2(-1.05, -0.1),
		],
		[
			Vector2(-1.08, -0.1), Vector2(-0.72, 0.15), Vector2(-0.48, 0.86),
			Vector2(-0.3, 1.6), Vector2(-0.06, 1.86), Vector2(0.13, 1.52),
			Vector2(0.02, 0.92), Vector2(-0.22, 0.18), Vector2(-0.2, -0.4),
			Vector2(0.18, -0.1),
		],
		[
			Vector2(0.16, -0.1), Vector2(0.5, 0.32), Vector2(0.98, 0.44),
			Vector2(1.34, 0.14), Vector2(1.28, -0.34), Vector2(0.82, -0.54),
			Vector2(0.44, -0.28), Vector2(0.5, 0.14), Vector2(0.94, 0.36),
			Vector2(1.36, 0.16), Vector2(1.58, -0.08), Vector2(1.66, 0.62),
			Vector2(1.82, 1.5), Vector2(2.05, 1.82), Vector2(2.2, 1.48),
			Vector2(2.04, 0.72), Vector2(1.76, -0.14), Vector2(1.84, -0.46),
			Vector2(2.2, -0.18), Vector2(2.58, -0.02),
		],
	]
	var starts := PackedFloat32Array([0.55, 1.5, 2.25, 2.95])
	var durations := PackedFloat32Array([0.95, 0.75, 0.7, 1.05])
	var colors: Array[Array] = [
		[PINK, CORAL], [CORAL, LEMON], [LEMON, MINT], [MINT, CYAN],
	]
	var stroke_count := strokes.size()
	for stroke_index in stroke_count:
		var points: Array[MoldPolylinePoint] = []
		var source := _smooth_logo_stroke(strokes[stroke_index], 6)
		for source_point in source:
			points.append(MoldPolylinePoint.new(Vector3(source_point.x + 1.0, source_point.y, 0.0), Color.WHITE))
		var path := MoldPolyline.new(points, 0.14, false, MoldPolyline.Join.ROUND,
			MoldPolyline.Cap.ROUND, 4.0, 14)
		var style := MoldStyle.dual_gradient(colors[stroke_index][0], colors[stroke_index][1], Vector3.RIGHT,
			MoldStyle.GradientSpace.OBJECT, MoldStyle.BlendMode.OPAQUE,
			MoldStyle.ColorInterpolation.OKLAB, 0.72)
		var state := MoldRenderState.new(1, 100 + stroke_index, MoldRenderState.DepthTest.ALWAYS,
			MoldRenderState.DepthWrite.DISABLED, MoldRenderState.StencilFlags.DISABLED,
			MoldRenderState.StencilCompare.ALWAYS, 0, MoldRenderState.FaceCull.DISABLED)
		var position := _stage_anchor(CHAPTER_STAGES[Chapter.FINALE]) + Vector3(0.0, -0.35, 0.0)
		var handle := _retain(world.create_polyline_transformed(path, position,
			Quaternion.IDENTITY, Vector3.ONE * 1.45, style, state))
		finale_handles.append({
			"handle": handle, "write_start": starts[stroke_index],
			"write_duration": durations[stroke_index],
			"position": position, "rotation": Quaternion.IDENTITY,
			"scale": Vector3.ONE * 1.45,
		})
	_create_logo_primitive_ring(CHAPTER_STAGES[Chapter.FINALE])


func _create_logo_primitive_ring(stage: int) -> void:
	var shapes: Array[MoldShape] = [
		MoldShape.rectangle(Vector2(1.05, 0.78), 0.25),
		MoldShape.rectangle_rim(Vector2(1.05, 0.78), 0.13, 0.22),
		MoldShape.disc(0.56),
		MoldShape.ring(0.56, 0.14),
		MoldShape.regular_polygon(5, 0.6, 0.16),
		MoldShape.regular_polygon_rim(6, 0.6, 0.13, 0.18),
		MoldShape.cuboid(Vector3(0.9, 0.9, 0.9), 0.24, MoldShape.Detail.MEDIUM),
		MoldShape.cylinder(0.48, 0.94, 0.22, MoldShape.Detail.MEDIUM),
		MoldShape.regular_prism(6, 0.5, 0.96, 0.2, MoldShape.Detail.MEDIUM),
		MoldShape.cone(0.52, 1.04, MoldShape.Detail.MEDIUM),
		MoldShape.sphere(0.54, MoldShape.Detail.MEDIUM),
		MoldShape.hemisphere(0.57, true, MoldShape.Detail.MEDIUM),
		MoldShape.capsule(0.36, 1.16, MoldShape.Detail.MEDIUM),
		MoldShape.torus(0.46, 0.2, 0.0, TAU, MoldShape.Detail.MEDIUM),
	]
	world.prewarm(shapes)
	for index in shapes.size():
		var angle := TAU * index / shapes.size() + PI * 0.5
		var handle := _retain(world.create_transformed(
			shapes[index], _stage_anchor(stage) + _logo_primitive_position(angle, index * 0.73, 0.0),
			Quaternion.IDENTITY, Vector3.ONE * 0.001, _logo_gradient_style(index)))
		logo_primitives.append({
			"handle": handle, "is_2d": shapes[index].is_2d, "angle": angle,
			"phase": index * 0.73, "speed": 0.38 + index * 0.057,
		})


func _create_wipe() -> void:
	wipe = _retain(world.create(
		MoldShape.ring(1.0, 0.075).with_billboard(),
		MoldStyle.additive(Color(CYAN.r, CYAN.g, CYAN.b, 0.72)),
		MoldRenderState.new(1, 200, MoldRenderState.DepthTest.ALWAYS, MoldRenderState.DepthWrite.DISABLED)))
	wipe.set_visible(false)
	wipe.set_scale(Vector3.ONE * 0.001)


func _add_floor(anchor: Vector3, size: Vector3, lower: Color, upper: Color) -> MoldHandle:
	var floor_handle := _retain(world.create_transformed(
		MoldShape.cuboid(size, 0.24, MoldShape.Detail.MEDIUM), anchor + Vector3.DOWN * size.y * 0.5,
		Quaternion.IDENTITY, Vector3.ONE,
		MoldStyle.dual_gradient(lower, upper, Vector3.UP, MoldStyle.GradientSpace.WORLD,
			MoldStyle.BlendMode.OPAQUE, MoldStyle.ColorInterpolation.OKLAB, 0.18)))
	return floor_handle


func _prepare_performance_layout() -> void:
	const target_aspect := 16.0 / 9.0
	const spacing := 0.24
	performance_columns = maxi(1, ceili(sqrt(performance_count * target_aspect)))
	performance_rows = maxi(1, ceili(float(performance_count) / performance_columns))
	performance_width = maxf(spacing, (performance_columns - 1) * spacing)
	performance_depth = maxf(spacing, (performance_rows - 1) * spacing)
	# Camera3D.size is the full view height. The margin also covers the
	# small yaw used by the low-angle performance composition.
	performance_frame_size = maxf(performance_depth, performance_width / target_aspect) * 1.16
	var animated_count := mini(performance_count, PERF_ANIMATED_LIMIT)
	for index in animated_count:
		performance_animated_indices[int(float(index) * performance_count / animated_count)] = true
	performance_base_positions.resize(animated_count)
	performance_animated_positions.resize(performance_base_positions.size())
	performance_shapes = [
		MoldShape.cuboid(Vector3(0.15, 0.15, 0.15), 0.12, MoldShape.Detail.MEDIUM),
		MoldShape.sphere(0.092, MoldShape.Detail.MEDIUM),
		MoldShape.regular_prism(6, 0.094, 0.18, 0.0, MoldShape.Detail.MEDIUM),
		MoldShape.capsule(0.06, 0.21, MoldShape.Detail.MEDIUM),
	]
	performance_styles = [
		MoldStyle.dual_gradient(Color("244d70"), Color("5ca7ba"), 0.04),
		MoldStyle.dual_gradient(Color("573d70"), Color("9a6fa8"), 0.04),
		MoldStyle.dual_gradient(Color("75613b"), Color("c0a362"), 0.04),
		MoldStyle.dual_gradient(Color("315f55"), Color("69a484"), 0.04),
	]
	performance_static_state = MoldRenderState.new(PERF_LAYER_MASK, 0)
	performance_animated_state = MoldRenderState.new(PERF_LAYER_MASK, 1)
	performance_world.prewarm(performance_shapes)


func _build_performance_chunk() -> void:
	var remaining := performance_count - performance_built
	var amount := mini(PERF_BUILD_CHUNK, remaining)
	var anchor := _stage_anchor(CHAPTER_STAGES[Chapter.PERFORMANCE])
	var spacing := 0.24
	var horizontal_extent := performance_width * 0.5
	var vertical_extent := performance_depth * 0.5
	var focus_column := floori((performance_columns - 1) * 0.5)
	var focus_row := floori((performance_rows - 1) * 0.5)
	performance_closeup_focus = anchor + Vector3(
		focus_column * spacing - horizontal_extent, 0.2,
		focus_row * spacing - vertical_extent)
	for offset in amount:
		var index := performance_built + offset
		var column := index % performance_columns
		var row := index / performance_columns
		var position := anchor + Vector3(column * spacing - horizontal_extent, 0.2, row * spacing - vertical_extent)
		var variant := ((column / 24) * 3 + (row / 24) * 5) & 3
		var animate_this := performance_animated_indices.has(index)
		var handle := performance_world.create_transformed(performance_shapes[variant], position,
			Quaternion.IDENTITY, Vector3.ONE, performance_styles[variant],
			performance_animated_state if animate_this else performance_static_state)
		if animate_this:
			var slot := performance_animated_handles.size()
			performance_animated_handles.append(handle)
			performance_base_positions[slot] = position
			performance_animated_positions[slot] = position
	performance_built += amount
	if performance_built >= performance_count:
		ready_to_play = true
		shade.color = Color(INK.r, INK.g, INK.b, 0.0)
		show_time = fixed_start_time if fixed_start_time >= 0.0 else 0.0
		capture_frame = 1 if capture_mode and fixed_start_time < 0.0 else int(round(show_time * FPS))
		_reset_discrete_state()
		_evaluate_showcase()


func _evaluate_showcase() -> void:
	var chapter := _chapter_at(show_time)
	if chapter != current_chapter:
		current_chapter = chapter
		if chapter == Chapter.PERFORMANCE: camera.cull_mask |= PERF_LAYER_MASK
		else: camera.cull_mask &= ~PERF_LAYER_MASK
	var chapter_start := CHAPTER_STARTS[chapter]
	var chapter_end := CHAPTER_STARTS[chapter + 1] if chapter + 1 < CHAPTER_STARTS.size() else SHOW_DURATION
	var local := show_time - chapter_start
	var duration := chapter_end - chapter_start
	var content_duration := CHAPTER_CONTENT_DURATIONS[chapter]
	var content_local := content_duration if duration <= 0.0 else local * content_duration / duration

	_update_camera(chapter, content_local, content_duration)
	if chapter == Chapter.SOLAR_SYSTEM:
		world.draw(func(draw: MoldImmediate) -> void: _draw_solar_system(draw, content_local))
	else:
		# Replacing the immediate frame is required; otherwise the last solar frame persists.
		world.draw(func(_draw: MoldImmediate) -> void: pass)

	match chapter:
		Chapter.LOGO_INTRO: _animate_logo(content_local, true)
		Chapter.SOLAR_SYSTEM: pass
		Chapter.ONE_SHAPE: _animate_intro(content_local)
		Chapter.EVERY_FORM: _animate_catalog(content_local)
		Chapter.COLOR_STYLES: _animate_styles(content_local)
		Chapter.LINES: _animate_strokes(content_local)
		Chapter.PERFORMANCE: _animate_performance(content_local)
		Chapter.FINALE: _animate_logo(content_local, false)
	_update_wipe(chapter, local, duration)

	_update_interface(chapter)


func _animate_intro(local: float) -> void:
	var shape_count := hero_shapes.size()
	var beat := mini(shape_count - 1, floori(local / 0.64))
	if beat != hero_shape_index:
		hero_shape_index = beat
		hero.set_shape(hero_shapes[beat])
	var within := maxf(0.0, local - beat * 0.64) / 0.64
	var pop := _out_back(_saturate(within * 2.25))
	hero.set_transform(
		_stage_anchor(CHAPTER_STAGES[Chapter.ONE_SHAPE]) + Vector3.UP * (1.55 + sin(local * 3.2) * 0.12),
		Quaternion.from_euler(Vector3(
			deg_to_rad(local * 31.0), deg_to_rad(local * 48.0), deg_to_rad(local * 17.0))),
		Vector3.ONE * maxf(0.001, pop))


func _animate_catalog(local: float) -> void:
	var anchor := _stage_anchor(CHAPTER_STAGES[Chapter.EVERY_FORM])
	var formation := clampi(floori(local / 2.0), 0, 2)
	var beat := fposmod(local, 2.0) / 2.0
	var transition := _out_back(_saturate(beat * 2.2))
	var actor_count := catalog_handles.size()
	for index in actor_count:
		var item: Dictionary = catalog_handles[index]
		var angle := TAU * index / actor_count + local * 0.18
		var orbit := anchor + Vector3(
			cos(angle) * (3.2 + (index % 2) * 1.8),
			0.85 + sin(angle * 2.0) * 0.75,
			sin(angle) * 3.8)
		var line := anchor + Vector3(
			(index - 6.5) * 1.05,
			0.75 + absf(index - 6.5) * 0.13,
			sin(index * 1.8 + local * 1.2) * 1.5)
		var from: Vector3
		var target: Vector3
		match formation:
			0:
				from = item.home
				target = item.home
			1:
				from = item.home
				target = orbit
			_:
				from = orbit
				target = line
		var position := from + (target - from) * transition
		var rotation: Quaternion = item.rotation * Quaternion.from_euler(Vector3(
			deg_to_rad(local * 18.0),
			deg_to_rad(local * (28.0 + index)),
			deg_to_rad(local * 9.0)))
		var pop := _out_back(_saturate((local - index * 0.055) * 2.5))
		item.handle.set_transform(position, rotation, Vector3.ONE * maxf(0.001, pop))


func _animate_styles(local: float) -> void:
	for item in style_handles:
		var index: int = item.index
		var delay := 0.0 if index < 0 else (index * 0.045 if index < 100 else (index - 100) * 0.025)
		var entrance := _out_back(_segment(local, delay, 0.72), 1.8)
		var wave := sin(show_time * 2.0 + item.phase) * 0.11 if index >= 0 and index < 100 else 0.0
		var position: Vector3 = item.position + Vector3.UP * wave
		var rotation: Quaternion = item.rotation
		if index >= 0 and index < 100:
			rotation = Quaternion(Vector3.UP, show_time * (0.25 if index % 2 == 0 else -0.22)) * item.rotation
		item.handle.set_transform(position, rotation, item.scale * maxf(0.001, entrance))


func _animate_strokes(local: float) -> void:
	var anchor := _stage_anchor(CHAPTER_STAGES[Chapter.LINES])
	var motion_in := _out_back(_segment(local, 0.55, 0.8), 1.7)
	var line_count := stroke_handles.size()
	for index in line_count:
		var item: Dictionary = stroke_handles[index]
		var z := -2.45 + index * 1.5
		var grow := _out_back(_segment(local, index * 0.1, 0.9), 1.72)
		var wave := sin(local * (2.05 + index * 0.17) + index * 0.9)
		var row_lift := (3 - index) * 0.42
		var start := Vector3(-5.0, row_lift - wave * 0.18 * motion_in,
			z + cos(local * 1.7 + index) * 0.12 * motion_in)
		var end := Vector3(_mixf(-4.4, 5.0, grow),
			row_lift + wave * (0.38 + index * 0.055) * motion_in,
			z - sin(local * 1.45 + index) * 0.18 * motion_in)
		item.handle.set_line_positions(start, end)
		if local < 1.3:
			item.handle.set_dash(MoldDash.new())
		else:
			var dash_count := 11 + index * 4
			item.handle.set_dash(MoldDash.new(dash_count, dash_count,
				0.34 + index * 0.055,
				(local - 1.3) * (2.1 if index % 2 == 0 else -1.75),
				MoldDash.Type.CHEVRON if index == 0 else MoldDash.Type.NORMAL,
				0.78 if index == 0 else 0.0))
	var ribbon_reveal := _out_back(_segment(local, 0.18, 1.08), 1.82)
	var ribbon_position := anchor + Vector3.UP * (0.92 + sin(local * 2.0) * 0.06)
	var ribbon_rotation := Quaternion(Vector3.UP, sin(local * 0.85) * 0.055) * GROUND_ROTATION
	polyline_handle.set_transform(ribbon_position, ribbon_rotation,
		Vector3(maxf(0.001, ribbon_reveal), 1.0, 1.0))
	for item in stroke_other_handles:
		var pop := _out_back(_segment(local, 0.0, 0.72), 1.65)
		item.handle.set_transform(item.position, item.rotation,
			item.scale * maxf(0.001, pop))


func _animate_authoring(local: float) -> void:
	var beat := mini(3, floori(local / 1.5))
	if beat != author_beat:
		author_beat = beat
		author_node.shape = author_shapes[beat]
	var beat_local := maxf(0.0, local - beat * 1.5)
	var pulse := _out_back(_saturate(beat_local * 2.0))
	author_node.position = _stage_anchor(4) + Vector3.UP * 1.7
	author_node.quaternion = Quaternion.from_euler(Vector3(
		deg_to_rad(local * 27.0), deg_to_rad(local * 43.0), deg_to_rad(local * 11.0)))
	author_node.scale = Vector3.ONE * maxf(0.001, pulse)
	var anchor := _stage_anchor(4)
	var actor_count := author_handles.size()
	for index in actor_count:
		var item: Dictionary = author_handles[index]
		if item.index < 10:
			continue
		var angle: float = item.phase + local * (0.55 + (item.index % 2) * 0.18)
		var position := Vector3(
			anchor.x + cos(angle) * 4.0,
			item.position.y + sin(local * 2.0 + item.phase) * 0.2,
			anchor.z + sin(angle) * 3.1)
		item.handle.set_position(position)


func _draw_solar_system(draw: MoldImmediate, local: float) -> void:
	var time := show_time
	var reveal := _out_back(_segment(local, 0.0, 0.85), 1.8)
	var anchor := _stage_anchor(CHAPTER_STAGES[Chapter.SOLAR_SYSTEM])
	draw.with_state(func() -> void:
		draw.render_state = MoldRenderState.new(1, -30, MoldRenderState.DepthTest.LESS_EQUAL, MoldRenderState.DepthWrite.DISABLED)
		for star in stars:
			var pulse: float = 0.82 + sin(time * 1.2 + star.phase) * 0.18
			var color: Color = star.color
			draw.style = MoldStyle.additive(Color(color.r, color.g, color.b,
				star.brightness * pulse * reveal))
			var shape := MoldShape.regular_polygon(4, star.radius, 0.2).with_billboard() \
				if star.pointed else MoldShape.disc(star.radius).with_billboard()
			draw.shape(shape, anchor + star.position, Quaternion.IDENTITY,
				Vector3.ONE * maxf(0.001, reveal * pulse))
	)
	draw.with_state(func() -> void:
		draw.render_state = MoldRenderState.new(1, -20, MoldRenderState.DepthTest.LESS_EQUAL, MoldRenderState.DepthWrite.DISABLED)
		draw.style = MoldStyle.transparent(Color(0.32, 0.58, 0.82, 0.22 * reveal))
		var planet_count := planets.size()
		for index in planet_count:
			var planet: Dictionary = planets[index]
			draw.dash = MoldDash.new(80, 96, 0.72, time * 0.06,
				MoldDash.Type.ROUNDED, 0.55) if index == planet_count - 1 else MoldDash.new()
			draw.shape(MoldShape.ring(planet.orbit, 0.009), anchor, GROUND_ROTATION,
				Vector3.ONE * maxf(0.001, reveal))
	)
	var sun_pulse := 1.0 + sin(time * 2.0) * 0.035
	draw.with_state(func() -> void:
		draw.render_state = MoldRenderState.new(1, -10, MoldRenderState.DepthTest.LESS_EQUAL, MoldRenderState.DepthWrite.DISABLED)
		draw.style = MoldStyle.dual_radial(Color(1.0, 0.72, 0.18, 0.55),
			Color(1.0, 0.18, 0.03, 0.0), MoldStyle.BlendMode.ADDITIVE,
			MoldStyle.ColorInterpolation.OKLAB, 1.8)
		draw.shape(MoldShape.disc(0.92).with_billboard(), anchor, Quaternion.IDENTITY,
			Vector3.ONE * sun_pulse * maxf(0.001, reveal))
		draw.style = MoldStyle.dual_gradient(Color("ff6a18"), Color("fff9d0"), Vector3.UP,
			MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.OPAQUE,
			MoldStyle.ColorInterpolation.OKLAB, 1.2)
		draw.shape(MoldShape.sphere(0.48, MoldShape.Detail.HIGH), anchor, Quaternion.IDENTITY,
			Vector3.ONE * sun_pulse * maxf(0.001, reveal))
	)
	var body_count := planets.size()
	for index in body_count:
		var planet: Dictionary = planets[index]
		var angle: float = time * planet.speed + planet.phase
		var position := anchor + Vector3(cos(angle) * planet.orbit,
			sin(angle * 0.7) * planet.inclination,
			sin(angle) * planet.orbit)
		var light_direction := (anchor - position).normalized()
		draw.with_state(func() -> void:
			draw.style = MoldStyle.dual_gradient(planet.low, planet.high, light_direction,
				MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.OPAQUE,
				MoldStyle.ColorInterpolation.OKLAB, 0.12 if index == 2 else 0.025)
			draw.shape(MoldShape.sphere(planet.radius, MoldShape.Detail.HIGH), position,
				Quaternion(Vector3.UP, time * (0.7 + index * 0.13)),
				Vector3.ONE * maxf(0.001, reveal))
			if planet.ringed:
				draw.style = MoldStyle.transparent(Color(CREAM.r, CREAM.g, CREAM.b, 0.62))
				draw.shape(MoldShape.ring(planet.radius * 1.75, planet.radius * 0.28),
					position, Quaternion(Vector3.RIGHT, PI * 0.5 + planet.inclination * 2.0),
					Vector3.ONE * maxf(0.001, reveal))
		)
		if index == 2 or index == 4:
			var moon_angle := -time * (1.8 + index * 0.1) + index
			var moon_position: Vector3 = position + Vector3(cos(moon_angle), 0.06,
				sin(moon_angle)) * (planet.radius * 2.2)
			draw.with_state(func() -> void:
				draw.style = MoldStyle.dual_gradient(Color("45495a"), Color("e7e9ef"),
					light_direction, MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.OPAQUE,
					MoldStyle.ColorInterpolation.OKLAB)
				draw.shape(MoldShape.sphere(planet.radius * 0.22, MoldShape.Detail.MEDIUM),
					moon_position, Quaternion.IDENTITY, Vector3.ONE * maxf(0.001, reveal))
			)


func _animate_city(local: float) -> void:
	for item in city_handles:
		var index: int = item.index
		var delay := minf(0.9, index * 0.018)
		var pop := _out_back(_segment(local, delay, 0.68), 1.8)
		var pulse := 1.0 + sin(show_time * 3.0 + item.phase) * 0.22 \
			if index >= 80 and index < 100 else 1.0
		item.handle.set_transform(item.position, item.rotation,
			item.scale * maxf(0.001, pop * pulse))
	var car_count := city_cars.size()
	for index in car_count:
		var car: Dictionary = city_cars[index]
		var entrance := _out_back(_segment(local, 0.3 + index * 0.045, 0.72), 1.9)
		var distance: float = car.phase * city_route_total_length + local * car.speed
		var pose := _sample_city_route(distance, car.lane_offset)
		var position: Vector3 = pose.position
		var tangent: Vector3 = pose.tangent
		if car.speed < 0.0:
			tangent = -tangent
		position.y = 0.39
		var rotation := Quaternion(Vector3.UP, atan2(-tangent.z, tangent.x))
		var scale := Vector3.ONE * maxf(0.001, entrance)
		car.body.set_transform(position, rotation, scale)
		car.roof.set_transform(position + Vector3.UP * 0.17, rotation, scale)


func _sample_city_route(distance: float, lane_offset := 0.0) -> Dictionary:
	var remaining := fposmod(distance, city_route_total_length)
	var route_count := city_route_points.size()
	for index in route_count:
		var segment_length := city_route_segment_lengths[index]
		if remaining > segment_length and index < route_count - 1:
			remaining -= segment_length
			continue
		var start := city_route_points[index]
		var end := city_route_points[(index + 1) % route_count]
		var tangent := (end - start).normalized()
		var progress := clampf(remaining / segment_length, 0.0, 1.0) if segment_length > 0.0001 else 0.0
		var lateral := Vector3(-tangent.z, 0.0, tangent.x)
		return {"position": _stage_anchor(6) + start
			+ (end - start) * progress + lateral * lane_offset, "tangent": tangent}
	return {"position": _stage_anchor(6) + city_route_points[0],
		"tangent": Vector3.RIGHT}


func _animate_hex(local: float) -> void:
	for item in hex_handles:
		var index: int = item.index
		var delay := minf(1.0, index * 0.012)
		var pop := _out_back(_segment(local, delay, 0.72), 1.75)
		item.handle.set_transform(item.position, item.rotation,
			item.scale * maxf(0.001, pop))
	var unit_entrance := _out_back(_segment(local, 0.4, 0.72), 1.9)
	for unit in hex_units:
		var angle: float = show_time * unit.speed + unit.phase
		var stride := sin(show_time * 7.0 + unit.phase)
		var position: Vector3 = unit.center + Vector3(cos(angle) * unit.radius,
			0.72 + absf(stride) * 0.08, sin(angle) * unit.radius * 0.72)
		var rotation := Quaternion(Vector3.UP, -angle + PI * 0.5)
		var scale := Vector3(1.0 - absf(stride) * 0.04,
			1.0 + absf(stride) * 0.05, 1.0) * maxf(0.001, unit_entrance)
		unit.body.set_transform(position, rotation, scale)
		unit.pennant.set_transform(position + Vector3.UP * 0.58,
			Quaternion.IDENTITY, Vector3.ONE * maxf(0.001, unit_entrance))
	var wind_count := wind_handles.size()
	for index in wind_count:
		var drift := fposmod(show_time * 0.7 + index * 0.13, 1.0)
		var offset := Vector3(drift * 0.75 - 0.38,
			sin(show_time * 2.1 + index) * 0.05, 0.0)
		wind_starts[index] = wind_base_starts[index] + offset
		wind_ends[index] = wind_base_ends[index] + offset
	world.update_line_positions_bulk(wind_handles, wind_starts, wind_ends)


func _animate_performance(_local: float) -> void:
	var count := performance_animated_handles.size()
	for index in count:
		var position := performance_base_positions[index]
		position.y += sin(show_time * 2.1 + index * 0.031) * 0.12
		performance_animated_positions[index] = position
	performance_world.update_positions_bulk(performance_animated_handles, performance_animated_positions)


func _animate_logo(local: float, write_out: bool) -> void:
	for item in finale_handles:
		var write_start: float = item.write_start
		var write_duration: float = item.write_duration
		var reveal := _in_out_cubic(_segment(local, write_start, write_duration)) if write_out else 1.0
		item.handle.set_visible(not write_out or reveal > 0.0)

	for index in logo_primitives.size():
		var primitive: Dictionary = logo_primitives[index]
		var position := _stage_anchor(CHAPTER_STAGES[Chapter.FINALE]) + _logo_primitive_position(
			primitive.angle, primitive.phase, local)
		var rotation: Quaternion
		if primitive.is_2d:
			rotation = Quaternion(Vector3.BACK,
				local * primitive.speed + deg_to_rad(index * 17.0))
		else:
			rotation = (
				Quaternion(Vector3.RIGHT,
					local * primitive.speed * 0.62 + deg_to_rad(index * 13.0))
				* Quaternion(Vector3.UP,
					local * primitive.speed + deg_to_rad(index * 29.0))
				* Quaternion(Vector3.BACK, local * primitive.speed * 0.37)
			)
		var entrance := _out_back(clampf((local - index * 0.055) / 0.7, 0.0, 1.0))
		var pulse := 1.0 + sin(local * 1.6 + primitive.phase) * 0.045
		primitive.handle.set_transform(position, rotation,
			Vector3.ONE * maxf(0.001, entrance * pulse))


static func _logo_primitive_position(angle: float, phase: float, time: float) -> Vector3:
	var drift := sin(time * 0.42 + phase) * 0.13
	return Vector3(
		cos(angle + drift * 0.08) * 6.35,
		sin(angle) * 4.65 + sin(time * 1.15 + phase) * 0.22 + 0.25,
		-0.8 - sin(angle * 3.0 + time * 0.7 + phase) * 1.35)


func _update_camera(chapter: int, local: float, duration: float) -> void:
	var stage := CHAPTER_STAGES[chapter]
	var performance_progress := _segment(local, 0.0, duration) if stage == 8 else 1.0
	var focus := _stage_anchor(stage) + Vector3.UP * _camera_focus_height(stage)
	if stage == 8:
		focus = performance_closeup_focus
	if stage == 9:
		camera.position = focus + Vector3.BACK * 16.0
		camera.look_at(focus, Vector3.UP)
		camera.size = CHAPTER_CAMERA_SIZES[chapter]
		return
	var yaw := 0.18 if stage == 8 else 0.72 + sin(show_time * 0.17 + stage * 0.43) * 0.045
	var pitch := 0.32 if stage == 8 else 0.58
	var distance := 100.0 if stage == 8 else 19.0
	var horizontal := cos(pitch)
	var direction := Vector3(sin(yaw) * horizontal, sin(pitch), cos(yaw) * horizontal)
	var settle := _out_expo(_segment(local, 0.0, 0.7))
	var arc := Vector3(0.0, (1.0 - settle) * 2.2, (1.0 - settle) * 1.4)
	camera.position = focus + direction * distance + arc
	camera.look_at(focus, Vector3.UP)
	var target_size := CHAPTER_CAMERA_SIZES[chapter]
	if stage == 8:
		var full_view_size := maxf(16.0, performance_frame_size)
		target_size = _mixf(0.22, full_view_size, performance_progress)
	var camera_entry := _out_expo(_segment(local, 0.0, 0.55))
	var entry_overscan := 0.0 if stage == 8 else 1.3
	camera.size = target_size + (1.0 - camera_entry) * entry_overscan


func _update_wipe(chapter: int, local: float, _duration: float) -> void:
	var stage := CHAPTER_STAGES[chapter]
	var logo_chapter := stage == 9
	if logo_chapter or local > 0.72:
		wipe.set_visible(false)
	else:
		wipe.set_visible(true)
		var expand := _out_expo(_segment(local, 0.0, 0.68))
		var alpha := 0.82 * (1.0 - _out_cubic(_segment(local, 0.14, 0.54)))
		wipe.set_position(_stage_anchor(stage) + Vector3.UP * _camera_focus_height(stage))
		wipe.set_scale(Vector3.ONE * _mixf(0.12, 8.5, expand))
		wipe.set_color(Color(CYAN.r, CYAN.g, CYAN.b, alpha))
	var shade_alpha := (1.0 - _out_expo(_segment(local, 0.0, 0.34))) * 0.72 \
		if not logo_chapter and local < 0.34 else 0.0
	shade.color = Color(INK.r, INK.g, INK.b, shade_alpha)


func _create_interface() -> void:
	interface = CanvasLayer.new()
	interface.name = "ShowcaseInterface"
	interface.layer = 20
	add_child(interface)

	shade = ColorRect.new()
	shade.name = "TransitionShade"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = INK
	interface.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	opening_card = Label.new()
	opening_card.name = "OpeningCard"
	opening_card.text = "This video is rendered with Mold"
	opening_card.anchor_left = 0.5
	opening_card.anchor_top = 0.5
	opening_card.anchor_right = 0.5
	opening_card.anchor_bottom = 0.5
	opening_card.offset_left = -450.0
	opening_card.offset_top = -40.0
	opening_card.offset_right = 450.0
	opening_card.offset_bottom = 40.0
	opening_card.pivot_offset = Vector2(450.0, 40.0)
	opening_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opening_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	opening_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opening_card.visible = false
	opening_card.add_theme_color_override("font_color", CREAM)
	opening_card.add_theme_color_override("font_outline_color", INK)
	opening_card.add_theme_font_size_override("font_size", 30)
	opening_card.add_theme_constant_override("outline_size", 7)
	interface.add_child(opening_card)

	tagline = Label.new()
	tagline.name = "FinaleTagline"
	tagline.text = "Geometric Primitive Rendering System"
	tagline.anchor_left = 0.5
	tagline.anchor_top = 0.5
	tagline.anchor_right = 0.5
	tagline.anchor_bottom = 0.5
	tagline.offset_left = -420.0
	tagline.offset_top = 126.0
	tagline.offset_right = 420.0
	tagline.offset_bottom = 182.0
	tagline.pivot_offset = Vector2(420.0, 28.0)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tagline.modulate = Color(1.0, 1.0, 1.0, 0.0)
	tagline.visible = false
	tagline.add_theme_color_override("font_color", CREAM)
	tagline.add_theme_color_override("font_outline_color", INK)
	tagline.add_theme_font_size_override("font_size", 24)
	tagline.add_theme_constant_override("outline_size", 6)
	interface.add_child(tagline)


func _update_interface(chapter: int) -> void:
	var chapter_local := show_time - CHAPTER_STARTS[chapter]
	var opening := chapter == Chapter.SOLAR_SYSTEM and chapter_local < 1.7
	opening_card.visible = opening
	if opening:
		var exit := _in_out_cubic(_saturate((chapter_local - 1.1) / 0.55))
		var pop := _out_back(_saturate(chapter_local / 0.55), 1.45)
		var alpha := 1.0 - exit
		opening_card.modulate = Color(1.0, 1.0, 1.0, alpha)
		opening_card.scale = Vector2.ONE * (0.94 + pop * 0.06)
		shade.color = Color(INK.r, INK.g, INK.b, alpha)
	tagline.visible = false


func _reset_discrete_state() -> void:
	current_chapter = -1
	hero_shape_index = -1
	author_beat = -1


func _parse_arguments() -> void:
	var explicit_count := false
	for argument in OS.get_cmdline_user_args():
		if argument == "--showcase-capture":
			capture_mode = true
			no_loop = true
		elif argument == "--showcase-no-loop":
			no_loop = true
		elif argument == "--showcase-smoke":
			smoke_test = true
		elif argument == "--showcase-clean":
			# Retained for command-line compatibility; the reel is always clean now.
			pass
		elif argument.begins_with("--showcase-count="):
			performance_count = clampi(int(argument.get_slice("=", 1)), 1, PERF_DEFAULT_COUNT)
			explicit_count = true
		elif argument.begins_with("--showcase-time="):
			fixed_start_time = clampf(float(argument.get_slice("=", 1)), 0.0, SHOW_DURATION - 0.001)
			capture_mode = true
			no_loop = true
	if smoke_test and not explicit_count:
		performance_count = 256


func _retain(handle: MoldHandle) -> MoldHandle:
	all_handles.append(handle)
	return handle


static func _chapter_at(time: float) -> int:
	var chapter_count := CHAPTER_STARTS.size()
	for index in range(chapter_count - 1, -1, -1):
		if time >= CHAPTER_STARTS[index]:
			return index
	return 0


static func _stage_anchor(index: int) -> Vector3:
	return Vector3(index * STAGE_GAP, 0.0, 0.0)


static func _gradient_style(index: int) -> MoldStyle:
	return MoldStyle.dual_gradient(_gradient_color(index), _gradient_color(index + 2),
		Vector3(0.4, 1.0, 0.3), MoldStyle.GradientSpace.WORLD,
		MoldStyle.BlendMode.OPAQUE, MoldStyle.ColorInterpolation.OKLAB, 0.12)


static func _logo_gradient_style(index: int) -> MoldStyle:
	return MoldStyle.dual_gradient(_gradient_color(index), _gradient_color(index + 2),
		Vector3(0.4, 1.0, 0.3), MoldStyle.GradientSpace.WORLD,
		MoldStyle.BlendMode.OPAQUE, MoldStyle.ColorInterpolation.OKLAB, 0.18)


static func _gradient_color(index: int) -> Color:
	match index % 7:
		0: return PINK
		1: return CORAL
		2: return LEMON
		3: return MINT
		4: return CYAN
		5: return BLUE
		_: return VIOLET


static func _author_shape_resource(kind, size_3d := Vector3.ONE, radius := 0.5,
		height := 1.0, thickness := 0.1, roundness := 0.0, sides := 6) -> MoldShapeResource:
	var resource := MoldShapeResource.new()
	resource.kind = kind
	resource.size_3d = size_3d
	resource.radius = radius
	resource.height = height
	resource.thickness = thickness
	resource.roundness = roundness
	resource.sides = sides
	resource.start_degrees = 0.0
	resource.span_degrees = 360.0
	resource.detail = MoldShape.Detail.HIGH
	return resource


static func _smooth_logo_stroke(control_points: Array, subdivisions: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var steps := maxi(1, subdivisions)
	var control_point_count := control_points.size()
	for index in range(control_point_count - 1):
		var p0: Vector2 = control_points[maxi(0, index - 1)]
		var p1: Vector2 = control_points[index]
		var p2: Vector2 = control_points[index + 1]
		var p3: Vector2 = control_points[mini(control_point_count - 1, index + 2)]
		for step in steps:
			var t := float(step) / steps
			var t_squared := t * t
			var t_cubed := t_squared * t
			result.append((p1 * 2.0 + (-p0 + p2) * t +
				(p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t_squared +
				(-p0 + p1 * 3.0 - p2 * 3.0 + p3) * t_cubed) * 0.5)
	result.append(control_points[-1])
	return result


static func _saturate(value: float) -> float:
	return clampf(value, 0.0, 1.0)


static func _segment(time: float, start: float, duration: float) -> float:
	return _saturate((time - start) / maxf(0.0001, duration))


static func _mixf(from: float, to: float, amount: float) -> float:
	return from + (to - from) * amount


static func _camera_focus_height(stage: int) -> float:
	match stage:
		0: return 1.0
		4: return 1.2
		5: return 0.2
		6, 7: return 0.75
		8: return 0.1
		9: return 0.3
		_: return 0.65


static func _out_back(value: float, overshoot := 1.70158) -> float:
	var x := _saturate(value) - 1.0
	return 1.0 + (overshoot + 1.0) * x * x * x + overshoot * x * x


static func _out_expo(value: float) -> float:
	var x := _saturate(value)
	return 1.0 if x >= 1.0 else 1.0 - pow(2.0, -10.0 * x)


static func _out_cubic(value: float) -> float:
	var x := 1.0 - _saturate(value)
	return 1.0 - x * x * x


static func _in_out_cubic(value: float) -> float:
	var x := _saturate(value)
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) * 0.5


static func _hash01(value: int) -> float:
	var x := value
	x = ((x >> 16) ^ x) * 0x45d9f3b
	x = ((x >> 16) ^ x) * 0x45d9f3b
	x = (x >> 16) ^ x
	return float(x & 0x00ffffff) / float(0x01000000)


static func _hash01_pair(x: int, y: int) -> float:
	var value := (x * 374761393 + y * 668265263) & 0xffffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0xffffffff
	value = value ^ (value >> 16)
	return float(value & 0x00ffffff) / 16777215.0
