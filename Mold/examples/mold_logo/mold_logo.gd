extends Node3D

## The scene used to render the Mold logo. The Release Showcase's cursive
## polyline mark stays fully visible while every primitive floats around it.

const PINK := Color("ff62c7")
const CORAL := Color("ff6b72")
const LEMON := Color("ffe044")
const MINT := Color("67f5b5")
const CYAN := Color("54e8ff")
const BLUE := Color("4285ff")
const VIOLET := Color("825cff")
const PALETTE: Array[Color] = [PINK, CORAL, LEMON, MINT, CYAN, BLUE, VIOLET]

@onready var camera: Camera3D = $Camera3D

var world: MoldRuntimeInstance
var handles: Array[MoldHandle] = []
var primitives: Array[Dictionary] = []
var start_time := 0.0


func _ready() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.5
	camera.near = 0.05
	camera.far = 100.0
	camera.position = Vector3(0.0, 0.3, 16.0)
	camera.look_at(Vector3(0.0, 0.3, 0.0), Vector3.UP)

	var settings := MoldWorldSettings.new()
	settings.capacity = 32
	settings.retained_unused_mesh_count = 24
	settings.lod_mode = MoldWorldSettings.LodMode.CONTINUOUS
	settings.lod_transition_width = 0.15
	world = MoldRuntime.create_instance(self, settings)
	_build_logo()
	_build_primitive_ring()
	start_time = Time.get_ticks_msec() * 0.001


func _process(_delta: float) -> void:
	var time := Time.get_ticks_msec() * 0.001 - start_time
	for index in primitives.size():
		var primitive := primitives[index]
		var position := _primitive_position(primitive.angle, primitive.phase, time)
		var rotation: Quaternion
		if primitive.is_2d:
			rotation = Quaternion(Vector3.BACK, time * primitive.speed + deg_to_rad(index * 17.0))
		else:
			rotation = (
				Quaternion(Vector3.RIGHT, time * primitive.speed * 0.62 + deg_to_rad(index * 13.0))
				* Quaternion(Vector3.UP, time * primitive.speed + deg_to_rad(index * 29.0))
				* Quaternion(Vector3.BACK, time * primitive.speed * 0.37)
			)
		var entrance := _out_back(clampf((time - index * 0.055) / 0.7, 0.0, 1.0))
		var pulse := 1.0 + sin(time * 1.6 + primitive.phase) * 0.045
		primitive.handle.set_transform(position, rotation, Vector3.ONE * maxf(0.001, entrance * pulse))


func _exit_tree() -> void:
	for handle in handles:
		if handle and handle.is_valid:
			handle.release()
	handles.clear()
	primitives.clear()
	if world:
		world.dispose()
	world = null


func _build_logo() -> void:
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
	var starts: Array[Color] = [PINK, CORAL, LEMON, MINT]
	var ends: Array[Color] = [CORAL, LEMON, MINT, CYAN]
	for stroke_index in strokes.size():
		var source := _smooth_logo_stroke(strokes[stroke_index], 6)
		var points: Array[MoldPolylinePoint] = []
		for source_point in source:
			points.append(MoldPolylinePoint.new(
				Vector3(source_point.x + 1.0, source_point.y, 0.0), Color.WHITE))

		# No dash mask is applied, so the complete word remains on screen.
		var path := MoldPolyline.new(points, 0.14, false,
			MoldPolyline.Join.ROUND, MoldPolyline.Cap.ROUND, 4.0, 14)
		var style := MoldStyle.dual_gradient(starts[stroke_index], ends[stroke_index],
			Vector3.RIGHT, MoldStyle.GradientSpace.OBJECT, MoldStyle.BlendMode.OPAQUE,
			MoldStyle.ColorInterpolation.OKLAB, 0.72)
		var state := MoldRenderState.new(1, 100 + stroke_index,
			MoldRenderState.DepthTest.ALWAYS, MoldRenderState.DepthWrite.DISABLED,
			MoldRenderState.StencilFlags.DISABLED, MoldRenderState.StencilCompare.ALWAYS,
			0, MoldRenderState.FaceCull.DISABLED)
		var handle := world.create_polyline_transformed(path, Vector3(0.0, -0.35, 0.0),
			Quaternion.IDENTITY, Vector3.ONE * 1.45, style, state)
		handles.append(handle)


func _build_primitive_ring() -> void:
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
	var supported_kind_count := MoldShape.Kind.size()
	if shapes.size() != supported_kind_count:
		push_warning("Logo sample defines %d primitives, but Mold supports %d shape kinds."
			% [shapes.size(), supported_kind_count])
	for index in mini(shapes.size(), supported_kind_count):
		if shapes[index].kind != index:
			push_warning("Logo primitive %d is kind %d; expected %d."
				% [index, shapes[index].kind, index])

	world.prewarm(shapes)
	for index in shapes.size():
		var angle := TAU * index / shapes.size() + PI * 0.5
		var handle := world.create(shapes[index], _gradient_style(index))
		handle.set_transform(_primitive_position(angle, index * 0.73, 0.0),
			Quaternion.IDENTITY, Vector3.ONE * 0.001)
		handles.append(handle)
		primitives.append({
			"handle": handle,
			"is_2d": shapes[index].is_2d,
			"angle": angle,
			"phase": index * 0.73,
			"speed": 0.38 + index * 0.057,
		})


func _primitive_position(angle: float, phase: float, time: float) -> Vector3:
	var drift := sin(time * 0.42 + phase) * 0.13
	return Vector3(
		cos(angle + drift * 0.08) * 6.35,
		sin(angle) * 4.65 + sin(time * 1.15 + phase) * 0.22 + 0.25,
		-0.8 - sin(angle * 3.0 + time * 0.7 + phase) * 1.35
	)


func _gradient_style(index: int) -> MoldStyle:
	return MoldStyle.dual_gradient(PALETTE[index % PALETTE.size()],
		PALETTE[(index + 2) % PALETTE.size()], Vector3(0.4, 1.0, 0.3),
		MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.OPAQUE,
		MoldStyle.ColorInterpolation.OKLAB, 0.18)


func _smooth_logo_stroke(control_points: Array, subdivisions: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var steps := maxi(1, subdivisions)
	for index in control_points.size() - 1:
		var p0: Vector2 = control_points[maxi(0, index - 1)]
		var p1: Vector2 = control_points[index]
		var p2: Vector2 = control_points[index + 1]
		var p3: Vector2 = control_points[mini(control_points.size() - 1, index + 2)]
		for step in steps:
			var t := float(step) / steps
			var t_squared := t * t
			var t_cubed := t_squared * t
			result.append((p1 * 2.0 + (-p0 + p2) * t
				+ (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t_squared
				+ (-p0 + p1 * 3.0 - p2 * 3.0 + p3) * t_cubed) * 0.5)
	result.append(control_points[-1])
	return result


func _out_back(value: float) -> float:
	const overshoot := 1.70158
	var x := clampf(value, 0.0, 1.0) - 1.0
	return 1.0 + (overshoot + 1.0) * x * x * x + overshoot * x * x
