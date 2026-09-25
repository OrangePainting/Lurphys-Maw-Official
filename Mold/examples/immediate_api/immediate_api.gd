@tool
extends MoldImmediateDrawer3D

enum ImmediateSubmissionMode { DRAWER_COMPONENT, PURE_IMMEDIATE }

const COMET_ORBIT := 3.7
const COMET_ECCENTRICITY := 0.53
const COMET_INCLINATION := -0.18
const COMET_LONGITUDE := 2.18
const DEFAULT_CAMERA_YAW := 0.68
const DEFAULT_CAMERA_PITCH := 0.58
const DEFAULT_CAMERA_DISTANCE := 15.5
const SUN_POSITION := Vector3.ZERO

var world: MoldRuntimeInstance
@onready var submission_selector: OptionButton = $Interface/SubmissionSelector
@onready var speed_slider: HSlider = $Interface/SpeedSlider
@onready var speed_value: Label = $Interface/SpeedValue
@onready var camera: Camera3D = $Camera3D

var simulation_time := 0.0
var planets: Array[Dictionary] = [
	{"orbit": 0.82, "eccentricity": 0.206, "inclination": 0.122, "longitude": 0.84, "radius": 0.065, "speed": 2.40, "phase": 0.20, "spin": 1.1, "shadow": Color.BLACK, "light": Color("c8bdb0")},
	{"orbit": 1.20, "eccentricity": 0.007, "inclination": 0.059, "longitude": 1.34, "radius": 0.13, "speed": 1.75, "phase": 1.60, "spin": -0.35, "shadow": Color.BLACK, "light": Color("f0cf91")},
	{"orbit": 1.62, "eccentricity": 0.017, "inclination": 0.0, "longitude": -0.19, "radius": 0.145, "speed": 1.35, "phase": 3.00, "spin": 1.8, "shadow": Color.BLACK, "light": Color("58b9ff")},
	{"orbit": 2.02, "eccentricity": 0.093, "inclination": 0.032, "longitude": 0.87, "radius": 0.095, "speed": 1.08, "phase": 4.40, "spin": 1.5, "shadow": Color.BLACK, "light": Color("e77b50")},
	{"orbit": 2.86, "eccentricity": 0.049, "inclination": 0.023, "longitude": 1.75, "radius": 0.32, "speed": 0.62, "phase": 5.10, "spin": 2.4, "shadow": Color.BLACK, "light": Color("e7c89f")},
	{"orbit": 3.58, "eccentricity": 0.057, "inclination": 0.043, "longitude": 1.98, "radius": 0.27, "speed": 0.46, "phase": 0.90, "spin": 2.1, "shadow": Color.BLACK, "light": Color("f1d58e")},
	{"orbit": 4.27, "eccentricity": 0.046, "inclination": 0.013, "longitude": 1.29, "radius": 0.19, "speed": 0.34, "phase": 2.40, "spin": -1.4, "shadow": Color.BLACK, "light": Color("a6e9e8")},
	{"orbit": 4.92, "eccentricity": 0.011, "inclination": 0.031, "longitude": 2.30, "radius": 0.18, "speed": 0.27, "phase": 3.80, "spin": 1.6, "shadow": Color.BLACK, "light": Color("668dff")},
]
var moons: Array[Dictionary] = [
	{"planet": 2, "orbit": 0.30, "radius": 0.040, "speed": 4.80, "phase": 0.3, "inclination": 0.09, "longitude": 0.42, "shadow": Color.BLACK, "light": Color("e2e5e8")},
	{"planet": 4, "orbit": 0.43, "radius": 0.029, "speed": 3.90, "phase": 1.2, "inclination": 0.03, "longitude": 1.14, "shadow": Color.BLACK, "light": Color("f0b36b")},
	{"planet": 4, "orbit": 0.53, "radius": 0.025, "speed": 3.05, "phase": 3.1, "inclination": -0.04, "longitude": 2.42, "shadow": Color.BLACK, "light": Color("c9d7e1")},
	{"planet": 5, "orbit": 0.61, "radius": 0.038, "speed": 2.15, "phase": 2.2, "inclination": 0.08, "longitude": 0.78, "shadow": Color.BLACK, "light": Color("e0b96d")},
	{"planet": 7, "orbit": 0.31, "radius": 0.025, "speed": -2.75, "phase": 4.2, "inclination": -0.12, "longitude": 2.82, "shadow": Color.BLACK, "light": Color("b8c9e8")},
]
var asteroids: Array[Dictionary] = []
var stars: Array[Dictionary] = []
var planet_positions: Array[Vector3] = []
var background_state: MoldRenderState
var guide_state: MoldRenderState
var overlay_state: MoldRenderState
var camera_focus := Vector3.ZERO
var target_focus := Vector3.ZERO
var camera_yaw := DEFAULT_CAMERA_YAW
var target_yaw := DEFAULT_CAMERA_YAW
var camera_pitch := DEFAULT_CAMERA_PITCH
var target_pitch := DEFAULT_CAMERA_PITCH
var camera_distance := DEFAULT_CAMERA_DISTANCE
var target_distance := DEFAULT_CAMERA_DISTANCE
var orbit_dragging := false
var pan_dragging := false
var touch_dragging := false

@export var submission_mode: ImmediateSubmissionMode = ImmediateSubmissionMode.DRAWER_COMPONENT:
	set(value):
		if submission_mode == value: return
		submission_mode = value
		_apply_submission_mode()
		request_redraw()
@export_range(0.0, 60.0, 0.1) var drawer_preview_time := 0.0:
	set(value):
		var next := clampf(value, 0.0, 60.0)
		if is_equal_approx(drawer_preview_time, next): return
		drawer_preview_time = next
		request_redraw()


func _ready() -> void:
	background_state = MoldRenderState.new(1, -30, MoldRenderState.DepthTest.LESS_EQUAL, MoldRenderState.DepthWrite.DISABLED)
	guide_state = MoldRenderState.new(1, -20, MoldRenderState.DepthTest.LESS_EQUAL, MoldRenderState.DepthWrite.DISABLED)
	overlay_state = MoldRenderState.new(1, 20, MoldRenderState.DepthTest.LESS_EQUAL, MoldRenderState.DepthWrite.DISABLED)
	if not Engine.is_editor_hint():
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 44.0
		camera.near = 0.1
		camera.far = 80.0
		_update_camera_transform()
	asteroids = _build_asteroids(176)
	stars = _build_stars(420)
	planet_positions.resize(planets.size())
	submission_selector.clear()
	submission_selector.add_item("DRAWER COMPONENT", ImmediateSubmissionMode.DRAWER_COMPONENT)
	submission_selector.add_item("PURE IMMEDIATE", ImmediateSubmissionMode.PURE_IMMEDIATE)
	submission_selector.selected = submission_mode
	submission_selector.item_selected.connect(_on_submission_selected)
	speed_value.text = "0× — 4×"
	_apply_submission_mode()
	request_redraw()


func _exit_tree() -> void:
	if is_instance_valid(submission_selector) and submission_selector.item_selected.is_connected(_on_submission_selected):
		submission_selector.item_selected.disconnect(_on_submission_selected)
	_dispose_direct_world()
	super._exit_tree()


func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	_animate_camera(delta)
	var speed := float(speed_slider.value)
	simulation_time += delta * speed
	if submission_mode != ImmediateSubmissionMode.PURE_IMMEDIATE: return
	_ensure_direct_world()
	world.draw(func(draw: MoldImmediate) -> void: _draw_solar_system(draw))


func draw_molds(draw: MoldImmediate, _camera: Camera3D) -> void:
	_draw_solar_system(draw)


func is_drawer_enabled() -> bool:
	return submission_mode == ImmediateSubmissionMode.DRAWER_COMPONENT


func _draw_solar_system(draw: MoldImmediate) -> void:
	# Keep scopes small so every drawing group starts clean. One big scope
	# would only reset the state after we are already done drawing.
	_draw_stars(draw)
	_draw_orbit_guides(draw)
	_draw_asteroid_belt(draw)
	_draw_sun(draw)
	var planet_count := planets.size()
	for index in planet_count:
		var planet := planets[index]
		var position := _orbit_position(planet.orbit, planet.eccentricity, planet.inclination, planet.longitude, _animation_time() * planet.speed + planet.phase)
		planet_positions[index] = position
		_draw_planet(draw, index, planet, position)
	_draw_moons(draw)
	_draw_comet(draw)


func _animation_time() -> float:
	return drawer_preview_time if Engine.is_editor_hint() else simulation_time


func _on_submission_selected(index: int) -> void:
	submission_mode = index


func _apply_submission_mode() -> void:
	if Engine.is_editor_hint() or not is_inside_tree(): return
	if submission_mode == ImmediateSubmissionMode.PURE_IMMEDIATE:
		_ensure_direct_world()
	else:
		_dispose_direct_world()


func _ensure_direct_world() -> void:
	if world: return
	var settings := MoldWorldSettings.new()
	settings.capacity = 4096
	settings.retained_unused_mesh_count = 32
	settings.lod_mode = MoldWorldSettings.LodMode.CONTINUOUS
	settings.lod_transition_width = 0.15
	world = MoldRuntime.create_instance(self, settings)


func _dispose_direct_world() -> void:
	if world: world.dispose()
	world = null


func _draw_stars(draw: MoldImmediate) -> void:
	draw.with_state(func() -> void:
		draw.render_state = background_state
		for star in stars:
			var pulse: float = 0.86 + 0.14 * sin(_animation_time() * 0.55 + star.phase)
			var color: Color = star.color
			color.a = star.brightness * pulse
			draw.style = MoldStyle.additive(color)
			var shape := MoldShape.regular_polygon(4, star.radius, 0.18) if star.pointed else MoldShape.disc(star.radius)
			draw.shape(shape.with_billboard(), star.position, Quaternion.IDENTITY, Vector3.ONE * (0.88 + pulse * 0.18))
	)


func _draw_orbit_guides(draw: MoldImmediate) -> void:
	draw.with_state(func() -> void:
		draw.render_state = guide_state
		draw.style = MoldStyle.transparent(Color(0.28, 0.48, 0.66, 0.16))
		for planet in planets:
			_draw_orbit_ellipse(draw, planet.orbit, planet.eccentricity, planet.inclination, planet.longitude, 0.0045)
		draw.style = MoldStyle.transparent(Color(0.58, 0.54, 0.46, 0.10))
		_draw_orbit_ellipse(draw, 2.31, 0.035, -0.045, 0.35, 0.004)
		_draw_orbit_ellipse(draw, 2.62, 0.035, 0.045, 1.78, 0.004)
		draw.dash = MoldDash.new(96, 96, 0.74, _animation_time() * 0.025, MoldDash.Type.ROUNDED, 0.65)
		draw.style = MoldStyle.transparent(Color(0.56, 0.72, 0.88, 0.22))
		_draw_orbit_ellipse(draw, COMET_ORBIT, COMET_ECCENTRICITY, COMET_INCLINATION, COMET_LONGITUDE, 0.005)
	)


func _draw_asteroid_belt(draw: MoldImmediate) -> void:
	for asteroid in asteroids:
		var position := _orbit_position(asteroid.orbit, asteroid.eccentricity, asteroid.inclination, asteroid.longitude, _animation_time() * asteroid.speed + asteroid.phase)
		draw.with_state(func() -> void:
			draw.position = position
			draw.rotation = Quaternion.from_euler(Vector3(asteroid.phase, _animation_time() * asteroid.spin + asteroid.phase, asteroid.longitude * 0.72))
			draw.scale = Vector3(1.35, 0.72, 1.0)
			draw.style = MoldStyle.dual_gradient(asteroid.shadow, asteroid.light, _direction_to_sun(position), MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.OPAQUE, MoldStyle.ColorInterpolation.OKLAB)
			draw.shape(MoldShape.regular_prism(asteroid.sides, asteroid.radius, asteroid.radius * 1.2, 0.22, MoldShape.Detail.MINIMAL))
		)


func _draw_sun(draw: MoldImmediate) -> void:
	var pulse := 1.0 + sin(_animation_time() * 1.7) * 0.025
	draw.with_state(func() -> void:
		draw.render_state = background_state
		draw.style = MoldStyle.dual_radial(Color(1.0, 0.72, 0.18, 0.42), Color(1.0, 0.18, 0.03, 0.0), MoldStyle.BlendMode.ADDITIVE, MoldStyle.ColorInterpolation.OKLAB, 1.8)
		draw.shape(MoldShape.disc(0.82).with_billboard(), Vector3.ZERO, Quaternion.IDENTITY, Vector3.ONE * pulse)
		draw.style = MoldStyle.additive(Color(1.0, 0.45, 0.08, 0.55))
		for flare in 3:
			draw.rotation = Quaternion.from_euler(Vector3(flare * 0.65, _animation_time() * (0.24 + flare * 0.07) + flare * 1.97, flare * 0.89))
			draw.shape(MoldShape.torus(0.51 + flare * 0.035, 0.018, 0.0, 0.72, MoldShape.Detail.LOW))
	)
	draw.with_state(func() -> void:
		draw.style = MoldStyle.dual_gradient(Color("ff8a20"), Color("fffce0"), Vector3.UP, MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.OPAQUE, MoldStyle.ColorInterpolation.OKLAB, 1.35)
		draw.shape(MoldShape.sphere(0.44, MoldShape.Detail.HIGH), Vector3.ZERO, Quaternion.IDENTITY, Vector3.ONE * pulse)
	)


func _draw_planet(draw: MoldImmediate, index: int, planet: Dictionary, position: Vector3) -> void:
	var light_direction := _direction_to_sun(position)
	_draw_planet_rings(draw, index, position, light_direction)
	draw.with_state(func() -> void:
		draw.position = position
		draw.rotation = Quaternion(Vector3.UP, _animation_time() * planet.spin)
		draw.style = MoldStyle.dual_gradient(planet.shadow, planet.light, light_direction, MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.OPAQUE, MoldStyle.ColorInterpolation.OKLAB, 0.08 if index == 2 else 0.02)
		draw.shape(MoldShape.sphere(planet.radius, MoldShape.Detail.HIGH))
	)
	_draw_planet_details(draw, index, planet, position, light_direction)


func _draw_planet_rings(draw: MoldImmediate, index: int, position: Vector3, light_direction: Vector3) -> void:
	if index != 5 and index != 6: return
	draw.with_state(func() -> void:
		draw.position = position
		var axial_tilt := deg_to_rad(26.7 if index == 5 else 82.2)
		draw.rotation = Quaternion(Vector3.UP, planets[index].longitude) * Quaternion(Vector3.RIGHT, PI * 0.5 + axial_tilt)
		draw.style = MoldStyle.dual_gradient(Color("57483b") if index == 5 else Color("315c68"), Color("f0d79d") if index == 5 else Color("9ad8dc"), light_direction, MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.OPAQUE, MoldStyle.ColorInterpolation.OKLAB)
		if index == 5:
			draw.shape(MoldShape.ring(0.48, 0.085))
			draw.style = MoldStyle.dual_gradient(Color("6a5847"), Color("fff0c2"), light_direction, MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.OPAQUE, MoldStyle.ColorInterpolation.OKLAB)
			draw.shape(MoldShape.ring(0.36, 0.045))
		else:
			draw.shape(MoldShape.ring(0.28, 0.018))
	)


func _draw_planet_details(draw: MoldImmediate, index: int, planet: Dictionary, position: Vector3, light_direction: Vector3) -> void:
	draw.with_state(func() -> void:
		draw.position = position
		draw.render_state = overlay_state
		if index == 1 or index == 2 or index == 7:
			var atmosphere := Color(1.0, 0.76, 0.36, 0.34) if index == 1 else Color(0.35, 0.72, 1.0, 0.56) if index == 2 else Color(0.28, 0.50, 1.0, 0.30)
			var transparent_atmosphere := atmosphere
			transparent_atmosphere.a = 0.0
			draw.style = MoldStyle.dual_gradient(transparent_atmosphere, atmosphere, light_direction, MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.ADDITIVE, MoldStyle.ColorInterpolation.OKLAB)
			draw.shape(MoldShape.sphere(planet.radius + (0.018 if index == 2 else 0.013), MoldShape.Detail.HIGH))
		if index == 2:
			draw.rotation = Quaternion(Vector3.BACK, deg_to_rad(-23.4)) * Quaternion(Vector3.UP, _animation_time() * planet.spin)
			draw.style = MoldStyle.dual_gradient(Color.BLACK, Color("76b85a"), light_direction, MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.OPAQUE, MoldStyle.ColorInterpolation.OKLAB)
			draw.shape(MoldShape.sphere(0.038, MoldShape.Detail.MINIMAL), Vector3(-0.065, 0.035, -0.105), Quaternion.IDENTITY, Vector3(1.35, 0.62, 0.28))
			draw.shape(MoldShape.sphere(0.030, MoldShape.Detail.MINIMAL), Vector3(0.074, -0.048, 0.105), Quaternion.IDENTITY, Vector3(1.15, 0.72, 0.26))
		if index == 4:
			draw.rotation = Quaternion(Vector3.BACK, deg_to_rad(-3.1))
			draw.style = MoldStyle.transparent(Color(0.48, 0.23, 0.13, 0.48))
			draw.shape(MoldShape.torus(0.292, 0.022, 0.0, TAU, MoldShape.Detail.LOW), Vector3(0.0, -0.075, 0.0))
			draw.shape(MoldShape.torus(0.316, 0.020, 0.0, TAU, MoldShape.Detail.LOW), Vector3(0.0, 0.012, 0.0))
			draw.style = MoldStyle.transparent(Color(1.0, 0.88, 0.66, 0.38))
			draw.shape(MoldShape.torus(0.275, 0.018, 0.0, TAU, MoldShape.Detail.LOW), Vector3(0.0, 0.095, 0.0))
	)


func _draw_moons(draw: MoldImmediate) -> void:
	for moon in moons:
		var parent := planet_positions[moon.planet]
		var angle: float = _animation_time() * moon.speed + moon.phase
		var plane := _orbit_plane(moon.inclination, moon.longitude)
		var offset := plane * Vector3(cos(angle) * moon.orbit, sin(angle) * moon.orbit * 0.72, 0.0)
		var position := parent + offset
		draw.with_state(func() -> void:
			draw.position = parent
			draw.rotation = plane
			draw.scale = Vector3(moon.orbit, moon.orbit * 0.72, 1.0)
			draw.style = MoldStyle.transparent(Color(0.58, 0.68, 0.78, 0.13))
			draw.shape(MoldShape.ring(1.0, 0.006))
		)
		draw.with_state(func() -> void:
			draw.position = position
			draw.style = MoldStyle.dual_gradient(moon.shadow, moon.light, _direction_to_sun(position), MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.OPAQUE, MoldStyle.ColorInterpolation.OKLAB)
			draw.shape(MoldShape.sphere(moon.radius, MoldShape.Detail.MINIMAL))
		)


func _draw_comet(draw: MoldImmediate) -> void:
	var position := _orbit_position(COMET_ORBIT, COMET_ECCENTRICITY, COMET_INCLINATION, COMET_LONGITUDE, _animation_time() * 0.18 + 2.65)
	var away_from_sun := position.normalized() if position.length_squared() > 0.000001 else Vector3.RIGHT
	var side := away_from_sun.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 0.000001 else Vector3.RIGHT
	draw.with_state(func() -> void:
		draw.render_state = overlay_state
		draw.dash = MoldDash.sized(0.065, 0.045, -_animation_time() * 0.055)
		draw.style = MoldStyle.dual_gradient(Color(0.82, 0.94, 1.0, 0.78), Color(0.18, 0.48, 1.0, 0.0), away_from_sun, MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.ADDITIVE, MoldStyle.ColorInterpolation.OKLAB, 0.85)
		for tail in range(-1, 2):
			var spread := tail * 0.025
			var thickness := 0.032 if tail == 0 else 0.018
			draw.shape(MoldShape.line_2d(position + away_from_sun * 0.055 + side * spread, position + away_from_sun * (0.68 + abs(tail) * 0.16) + side * spread * 3.5, thickness, MoldShape.BillboardMode.FACE_CAMERA))
		draw.position = position
		draw.dash = MoldDash.new()
		draw.style = MoldStyle.dual_radial(Color(0.94, 0.99, 1.0, 0.76), Color(0.18, 0.55, 1.0, 0.0), MoldStyle.BlendMode.ADDITIVE, MoldStyle.ColorInterpolation.OKLAB, 1.1)
		draw.shape(MoldShape.disc(0.14).with_billboard())
		draw.style = MoldStyle.dual_gradient(Color.BLACK, Color("e9f3f7"), _direction_to_sun(position), MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.OPAQUE, MoldStyle.ColorInterpolation.OKLAB)
		draw.shape(MoldShape.sphere(0.055, MoldShape.Detail.MINIMAL))
	)


func _draw_orbit_ellipse(draw: MoldImmediate, radius: float, eccentricity: float, inclination: float, longitude: float, thickness: float) -> void:
	var semi_minor := radius * sqrt(1.0 - eccentricity * eccentricity)
	var plane := _orbit_plane(inclination, longitude)
	draw.position = plane * Vector3(-radius * eccentricity, 0.0, 0.0)
	draw.rotation = plane
	draw.scale = Vector3(radius, semi_minor, 1.0)
	draw.shape(MoldShape.ring(1.0, thickness))


func _orbit_position(radius: float, eccentricity: float, inclination: float, longitude: float, mean_anomaly: float) -> Vector3:
	var mean := fposmod(mean_anomaly, TAU)
	var eccentric_anomaly := mean
	for _iteration in 4:
		eccentric_anomaly -= (eccentric_anomaly - eccentricity * sin(eccentric_anomaly) - mean) / (1.0 - eccentricity * cos(eccentric_anomaly))
	var semi_minor := radius * sqrt(1.0 - eccentricity * eccentricity)
	return _orbit_plane(inclination, longitude) * Vector3(radius * (cos(eccentric_anomaly) - eccentricity), semi_minor * sin(eccentric_anomaly), 0.0)


static func _orbit_plane(inclination: float, longitude: float) -> Quaternion:
	return Quaternion(Vector3.UP, longitude) * Quaternion(Vector3.RIGHT, PI * 0.5 + inclination)


static func _direction_to_sun(position: Vector3) -> Vector3:
	var to_sun := SUN_POSITION - position
	return to_sun.normalized() if to_sun.length_squared() > 0.000001 else Vector3.UP


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				orbit_dragging = event.pressed and not event.shift_pressed
				pan_dragging = event.pressed and event.shift_pressed
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				pan_dragging = event.pressed
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed: _zoom_camera(-1.15 * event.factor)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed: _zoom_camera(1.15 * event.factor)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if orbit_dragging: _orbit_camera(event.relative)
		if pan_dragging: _pan_camera(event.relative)
		if orbit_dragging or pan_dragging: get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		touch_dragging = event.pressed
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touch_dragging:
		_orbit_camera(event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_reset_camera()
		get_viewport().set_input_as_handled()


func _orbit_camera(relative: Vector2) -> void:
	target_yaw = wrapf(target_yaw - relative.x * 0.006, -PI, PI)
	target_pitch = clampf(target_pitch + relative.y * 0.006, 0.12, 1.45)


func _pan_camera(relative: Vector2) -> void:
	var scale := target_distance * 0.0011
	target_focus += camera.global_basis.x * (-relative.x * scale) + camera.global_basis.y * (-relative.y * scale)
	if target_focus.length() > 5.5: target_focus = target_focus.normalized() * 5.5


func _zoom_camera(amount: float) -> void:
	target_distance = clampf(target_distance + amount, 6.5, 28.0)


func _reset_camera() -> void:
	target_focus = Vector3.ZERO
	target_yaw = DEFAULT_CAMERA_YAW
	target_pitch = DEFAULT_CAMERA_PITCH
	target_distance = DEFAULT_CAMERA_DISTANCE


func _animate_camera(delta: float) -> void:
	var blend := 1.0 - exp(-delta * 12.0)
	camera_yaw = lerp_angle(camera_yaw, target_yaw, blend)
	camera_pitch = lerpf(camera_pitch, target_pitch, blend)
	camera_distance = lerpf(camera_distance, target_distance, blend)
	camera_focus = camera_focus.lerp(target_focus, blend)
	_update_camera_transform()


func _update_camera_transform() -> void:
	var horizontal := cos(camera_pitch)
	var direction := Vector3(sin(camera_yaw) * horizontal, sin(camera_pitch), cos(camera_yaw) * horizontal)
	camera.position = camera_focus + direction * camera_distance
	camera.look_at(camera_focus, Vector3.UP)


static func _build_asteroids(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in count:
		var tone := _hash_01(index, 8)
		result.append({
			"orbit": lerpf(2.31, 2.62, _hash_01(index, 1)),
			"eccentricity": lerpf(0.01, 0.065, _hash_01(index, 2)),
			"inclination": lerpf(-0.055, 0.055, _hash_01(index, 3)),
			"longitude": _hash_01(index, 10) * TAU,
			"phase": _hash_01(index, 4) * TAU,
			"speed": lerpf(0.70, 0.92, _hash_01(index, 5)),
			"spin": lerpf(-2.4, 2.4, _hash_01(index, 6)),
			"radius": lerpf(0.012, 0.029, _hash_01(index, 7)),
			"sides": 5 + floori(_hash_01(index, 9) * 4.0),
			"shadow": Color.BLACK,
			"light": Color("8a7867").lerp(Color("c0a17e"), tone),
		})
	return result


static func _build_stars(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in count:
		var vertical := lerpf(-1.0, 1.0, _hash_01(index, 1))
		var azimuth := _hash_01(index, 2) * TAU
		var horizontal := sqrt(1.0 - vertical * vertical)
		var distance := lerpf(25.0, 31.0, _hash_01(index, 8))
		result.append({
			"position": Vector3(cos(azimuth) * horizontal, vertical, sin(azimuth) * horizontal) * distance,
			"radius": lerpf(0.025, 0.072, _hash_01(index, 3)),
			"phase": _hash_01(index, 5) * TAU,
			"brightness": lerpf(0.28, 0.82, _hash_01(index, 6)),
			"color": Color("91b8ff").lerp(Color("fff1cd"), _hash_01(index, 4)),
			"pointed": _hash_01(index, 7) > 0.82,
		})
	return result


static func _hash_01(index: int, salt: int) -> float:
	return fposmod(sin(index * 127.1 + salt * 311.7) * 43758.5453, 1.0)
