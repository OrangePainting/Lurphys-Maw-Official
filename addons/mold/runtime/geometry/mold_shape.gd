class_name MoldShape
extends RefCounted

enum Kind {
	RECTANGLE,
	RECTANGLE_RIM,
	DISC,
	RING,
	REGULAR_POLYGON,
	REGULAR_POLYGON_RIM,
	CUBOID,
	CYLINDER,
	REGULAR_PRISM,
	CONE,
	SPHERE,
	HEMISPHERE,
	CAPSULE,
	TORUS,
}

enum Detail { MINIMAL, LOW, MEDIUM, HIGH, EXTREME }
enum BillboardMode { DISABLED, FACE_CAMERA, FACE_CAMERA_Y }
enum RectangleRoundnessMode { CORNER_LOCAL, SHAPE_RELATIVE }

var kind: Kind = Kind.RECTANGLE
var size := Vector3.ZERO
var radius := 0.0
var height := 0.0
var thickness := 0.0
var roundness := 0.0
var rectangle_roundness_mode: RectangleRoundnessMode = RectangleRoundnessMode.CORNER_LOCAL
var start_radians := 0.0
var span_radians := TAU
var sides := 0
var detail: Detail = Detail.MINIMAL
var capped := true
var dash := MoldDash.new()
var line_enabled := false
var start_position := Vector3.ZERO
var end_position := Vector3.ZERO
var billboard_mode: BillboardMode = BillboardMode.DISABLED

var is_2d: bool:
	get: return kind <= Kind.REGULAR_POLYGON_RIM
var supports_dashes: bool:
	get: return is_line or kind in [Kind.RECTANGLE_RIM, Kind.RING, Kind.REGULAR_POLYGON_RIM]
var is_line: bool:
	get: return line_enabled and kind in [Kind.RECTANGLE, Kind.CYLINDER]
var is_empty: bool:
	get:
		if is_line:
			var delta := end_position - start_position
			if kind == Kind.RECTANGLE and billboard_mode != BillboardMode.FACE_CAMERA:
				delta.z = 0.0
			return thickness <= 0.0 or delta.length_squared() <= 0.000000000001
		if span_radians <= 0.0 and (is_2d or kind == Kind.TORUS): return true
		match kind:
			Kind.RECTANGLE:
				return size.x <= 0.0 or size.y <= 0.0
			Kind.RECTANGLE_RIM:
				return size.x <= 0.0 or size.y <= 0.0 or thickness <= 0.0
			Kind.DISC, Kind.REGULAR_POLYGON:
				return radius <= 0.0
			Kind.RING, Kind.REGULAR_POLYGON_RIM:
				return radius <= 0.0 or thickness <= 0.0
			Kind.CUBOID:
				return size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0
			Kind.CYLINDER, Kind.REGULAR_PRISM, Kind.CONE:
				return radius <= 0.0 or height <= 0.0
			Kind.SPHERE, Kind.HEMISPHERE:
				return radius <= 0.0
			Kind.CAPSULE:
				return radius <= 0.0 or height <= 0.0
			Kind.TORUS:
				return radius <= 0.0 or thickness <= 0.0
		return true


static func rectangle(value: Vector2, value_roundness: float = 0.0,
		value_roundness_mode: RectangleRoundnessMode = RectangleRoundnessMode.CORNER_LOCAL,
		start: float = 0.0, span: float = TAU) -> MoldShape:
	if not _valid_size2(value) or not _valid_roundness(value_roundness) \
			or not _valid_rectangle_roundness_mode(value_roundness_mode) \
			or not _valid_angles(start, span): return null
	var shape := _make(Kind.RECTANGLE, Vector3(value.x, value.y, 1.0))
	shape.roundness = value_roundness
	shape.rectangle_roundness_mode = value_roundness_mode
	shape.start_radians = start
	shape.span_radians = span
	return shape


static func rectangle_rim(value: Vector2, value_thickness: float, value_roundness: float = 0.0,
		value_dash: MoldDash = null,
		value_roundness_mode: RectangleRoundnessMode = RectangleRoundnessMode.CORNER_LOCAL,
		start: float = 0.0, span: float = TAU) -> MoldShape:
	return _rect_rim(Kind.RECTANGLE_RIM, value, value_thickness, value_roundness,
		value_dash, value_roundness_mode, start, span)


static func disc(value_radius: float, start: float = 0.0, span: float = TAU) -> MoldShape:
	if not _valid_dimension(value_radius, "radius") or not _valid_angles(start, span): return null
	var shape := _make(Kind.DISC)
	shape.radius = value_radius
	shape.start_radians = start
	shape.span_radians = span
	return shape


static func ring(value_radius: float, value_thickness: float, start: float = 0.0, span: float = TAU, value_dash: MoldDash = null) -> MoldShape:
	if not _valid_dimension(value_radius, "radius") or not _valid_dimension(value_thickness, "thickness") or not _valid_angles(start, span): return null
	var shape := _make(Kind.RING)
	shape.radius = value_radius
	shape.thickness = value_thickness
	shape.start_radians = start
	shape.span_radians = span
	shape.dash = value_dash.duplicate_dash() if value_dash else MoldDash.new()
	return shape


static func regular_polygon(value_sides: int, value_radius: float, value_roundness: float = 0.0,
		start: float = 0.0, span: float = TAU) -> MoldShape:
	return _polygon(Kind.REGULAR_POLYGON, value_sides, value_radius, value_roundness,
		0.0, null, start, span)


static func regular_polygon_rim(value_sides: int, value_radius: float, value_thickness: float,
		value_roundness: float = 0.0, value_dash: MoldDash = null,
		start: float = 0.0, span: float = TAU) -> MoldShape:
	return _polygon(Kind.REGULAR_POLYGON_RIM, value_sides, value_radius, value_roundness,
		value_thickness, value_dash, start, span)


static func cuboid(value: Vector3, value_roundness: float = 0.0, value_detail: Detail = Detail.MEDIUM) -> MoldShape:
	if not _valid_size3(value) or not _valid_roundness(value_roundness): return null
	var shape := _make(Kind.CUBOID, value)
	shape.roundness = value_roundness
	shape.detail = value_detail
	return shape


static func line_2d(start: Vector3, end: Vector3, value_thickness: float,
		billboard: BillboardMode = BillboardMode.DISABLED, value_roundness: float = 0.0,
		value_roundness_mode: RectangleRoundnessMode = RectangleRoundnessMode.CORNER_LOCAL) -> MoldShape:
	return _line_like(Kind.RECTANGLE, start, end, value_thickness, Detail.MINIMAL,
		billboard, value_roundness, value_roundness_mode)


static func line_3d(start: Vector3, end: Vector3, value_thickness: float,
		value_roundness: float = 0.0, value_detail: Detail = Detail.MEDIUM) -> MoldShape:
	return _line_like(Kind.CYLINDER, start, end, value_thickness, value_detail,
		BillboardMode.DISABLED, value_roundness)


static func cylinder(value_radius: float, value_height: float, value_roundness: float = 0.0, value_detail: Detail = Detail.MEDIUM) -> MoldShape:
	return _radial_3d(Kind.CYLINDER, value_radius, value_height, 0, value_roundness, value_detail)


static func regular_prism(value_sides: int, value_radius: float, value_height: float, value_roundness: float = 0.0, value_detail: Detail = Detail.MEDIUM) -> MoldShape:
	return _radial_3d(Kind.REGULAR_PRISM, value_radius, value_height, value_sides, value_roundness, value_detail)


static func cone(value_radius: float, value_height: float, value_detail: Detail = Detail.MEDIUM) -> MoldShape:
	return _radial_3d(Kind.CONE, value_radius, value_height, 0, 0.0, value_detail)


static func sphere(value_radius: float, value_detail: Detail = Detail.MEDIUM) -> MoldShape:
	if not _valid_dimension(value_radius, "radius"): return null
	var shape := _make(Kind.SPHERE)
	shape.radius = value_radius
	shape.detail = value_detail
	return shape


static func hemisphere(value_radius: float, value_capped: bool = true, value_detail: Detail = Detail.MEDIUM) -> MoldShape:
	if not _valid_dimension(value_radius, "radius"): return null
	var shape := _make(Kind.HEMISPHERE)
	shape.radius = value_radius
	shape.capped = value_capped
	shape.detail = value_detail
	return shape


static func capsule(value_radius: float, total_height: float, value_detail: Detail = Detail.MEDIUM) -> MoldShape:
	if not _valid_dimension(value_radius, "radius") or not _valid_dimension(total_height, "total_height"): return null
	if value_radius > 0.0 and total_height > 0.0 and total_height < value_radius * 2.0:
		push_error("Capsule height must be at least twice its radius.")
		return null
	var shape := _make(Kind.CAPSULE)
	shape.radius = value_radius
	shape.height = total_height
	shape.detail = value_detail
	return shape


static func torus(value_radius: float, value_thickness: float, start: float = 0.0, span: float = TAU, value_detail: Detail = Detail.MEDIUM) -> MoldShape:
	if not _valid_dimension(value_radius, "radius") or not _valid_dimension(value_thickness, "thickness") or not _valid_angles(start, span): return null
	var shape := _make(Kind.TORUS)
	shape.radius = value_radius
	shape.thickness = value_thickness
	shape.start_radians = start
	shape.span_radians = span
	shape.detail = value_detail
	return shape


func duplicate_shape() -> MoldShape:
	var result := _make(kind, size)
	result.radius = radius
	result.height = height
	result.thickness = thickness
	result.roundness = roundness
	result.rectangle_roundness_mode = rectangle_roundness_mode
	result.start_radians = start_radians
	result.span_radians = span_radians
	result.sides = sides
	result.detail = detail
	result.capped = capped
	result.dash = dash.duplicate_dash()
	result.line_enabled = line_enabled
	result.start_position = start_position
	result.end_position = end_position
	result.billboard_mode = billboard_mode
	return result


func with_dash(value: MoldDash) -> MoldShape:
	if not supports_dashes:
		push_error("This shape does not support dash patterns.")
		return null
	var result := duplicate_shape()
	result.dash = value.duplicate_dash() if value else MoldDash.new()
	return result


func with_line_positions(start: Vector3, end: Vector3) -> MoldShape:
	if not is_line or not _valid_line(start, end, kind, thickness, billboard_mode):
		return null
	var result := duplicate_shape()
	result.start_position = start
	result.end_position = end
	return result


func with_billboard(mode: BillboardMode = BillboardMode.FACE_CAMERA) -> MoldShape:
	if mode < BillboardMode.DISABLED or mode > BillboardMode.FACE_CAMERA_Y:
		push_error("Invalid billboard mode.")
		return null
	if not is_2d or (is_line and kind != Kind.RECTANGLE):
		push_error("Billboard modes are supported only by 2D shapes and flat rectangle lines.")
		return null
	if is_line and mode == BillboardMode.FACE_CAMERA_Y:
		push_error("Y-axis billboarding is not supported by flat rectangle lines.")
		return null
	if is_line and not _valid_line(start_position, end_position, kind, thickness, mode):
		return null
	var result := duplicate_shape()
	result.billboard_mode = mode
	return result


func equals(other: MoldShape) -> bool:
	return other != null and kind == other.kind and size == other.size and radius == other.radius \
		and height == other.height and thickness == other.thickness and roundness == other.roundness \
		and rectangle_roundness_mode == other.rectangle_roundness_mode \
		and start_radians == other.start_radians and span_radians == other.span_radians \
		and sides == other.sides and detail == other.detail and capped == other.capped \
		and dash.equals(other.dash) and line_enabled == other.line_enabled \
		and start_position == other.start_position and end_position == other.end_position \
		and billboard_mode == other.billboard_mode


func dash_path_length() -> float:
	if is_line:
		var delta := end_position - start_position
		if kind == Kind.RECTANGLE and billboard_mode != BillboardMode.FACE_CAMERA:
			delta.z = 0.0
		return delta.length()
	match kind:
		Kind.RECTANGLE_RIM:
			return (size.x + size.y) * 2.0
		Kind.RING:
			return maxf(radius - thickness * 0.5, 0.0) * span_radians
		Kind.REGULAR_POLYGON_RIM:
			var half_angle := PI / maxi(sides, 3)
			var center_apothem := maxf(radius * cos(half_angle) - thickness * 0.5, 0.0)
			return 2.0 * sides * center_apothem * tan(half_angle)
		_:
			return 1.0


static func _make(value_kind: Kind, value_size: Vector3 = Vector3.ZERO) -> MoldShape:
	var shape := MoldShape.new()
	shape.kind = value_kind
	shape.size = value_size
	return shape


static func _rect_rim(value_kind: Kind, value: Vector2, value_thickness: float,
		value_roundness: float, value_dash: MoldDash,
		value_roundness_mode: RectangleRoundnessMode, start: float, span: float) -> MoldShape:
	if not _valid_size2(value) or not _valid_dimension(value_thickness, "thickness") \
			or not _valid_roundness(value_roundness) \
			or not _valid_rectangle_roundness_mode(value_roundness_mode) \
			or not _valid_angles(start, span): return null
	var shape := _make(value_kind, Vector3(value.x, value.y, 1.0))
	shape.thickness = value_thickness
	shape.roundness = value_roundness
	shape.rectangle_roundness_mode = value_roundness_mode
	shape.start_radians = start
	shape.span_radians = span
	shape.dash = value_dash.duplicate_dash() if value_dash else MoldDash.new()
	return shape


static func _polygon(value_kind: Kind, value_sides: int, value_radius: float,
		value_roundness: float, value_thickness: float, value_dash: MoldDash,
		start: float, span: float) -> MoldShape:
	if not _valid_sides(value_sides) or not _valid_dimension(value_radius, "radius") \
			or not _valid_roundness(value_roundness) or not _valid_angles(start, span): return null
	if not _valid_dimension(value_thickness, "thickness"): return null
	var shape := _make(value_kind)
	shape.sides = value_sides
	shape.radius = value_radius
	shape.roundness = value_roundness
	shape.thickness = value_thickness
	shape.start_radians = start
	shape.span_radians = span
	shape.dash = value_dash.duplicate_dash() if value_dash else MoldDash.new()
	return shape


static func _radial_3d(value_kind: Kind, value_radius: float, value_height: float, value_sides: int, value_roundness: float, value_detail: Detail) -> MoldShape:
	if not _valid_dimension(value_radius, "radius") or not _valid_dimension(value_height, "height") or not _valid_roundness(value_roundness): return null
	if value_sides != 0 and not _valid_sides(value_sides): return null
	var shape := _make(value_kind)
	shape.radius = value_radius
	shape.height = value_height
	shape.sides = value_sides
	shape.roundness = value_roundness
	shape.detail = value_detail
	return shape


static func _line_like(value_kind: Kind, start: Vector3, end: Vector3, value_thickness: float,
		value_detail: Detail, billboard: BillboardMode = BillboardMode.DISABLED,
		value_roundness: float = 0.0,
		value_roundness_mode: RectangleRoundnessMode = RectangleRoundnessMode.CORNER_LOCAL) -> MoldShape:
	if billboard < BillboardMode.DISABLED or billboard > BillboardMode.FACE_CAMERA_Y:
		push_error("Invalid billboard mode.")
		return null
	if value_kind != Kind.RECTANGLE and billboard != BillboardMode.DISABLED:
		push_error("Billboard modes are supported only by flat rectangle lines.")
		return null
	if billboard == BillboardMode.FACE_CAMERA_Y:
		push_error("Y-axis billboarding is not supported by flat rectangle lines.")
		return null
	if value_kind in [Kind.RECTANGLE, Kind.CYLINDER] and not _valid_roundness(value_roundness):
		return null
	if value_kind == Kind.RECTANGLE and not _valid_rectangle_roundness_mode(value_roundness_mode):
		return null
	if not _valid_dimension(value_thickness, "thickness") or not _valid_line(start, end, value_kind, value_thickness, billboard): return null
	var shape := _make(value_kind)
	shape.thickness = value_thickness
	shape.roundness = value_roundness
	shape.rectangle_roundness_mode = value_roundness_mode
	shape.detail = value_detail
	shape.line_enabled = true
	shape.start_position = start
	shape.end_position = end
	shape.billboard_mode = billboard
	return shape


static func _valid_line(start: Vector3, end: Vector3, value_kind: Kind, value_thickness: float, billboard: BillboardMode = BillboardMode.DISABLED) -> bool:
	if not start.is_finite() or not end.is_finite():
		push_error("Line positions must be finite.")
		return false
	return true


static func _valid_size2(value: Vector2) -> bool:
	return _valid_dimension(value.x, "width") and _valid_dimension(value.y, "height")


static func _valid_size3(value: Vector3) -> bool:
	return _valid_dimension(value.x, "width") and _valid_dimension(value.y, "height") and _valid_dimension(value.z, "depth")


static func _valid_dimension(value: float, label: String) -> bool:
	if not is_finite(value) or value < 0.0:
		push_error("%s must be finite and non-negative." % label)
		return false
	return true


static func _valid_roundness(value: float) -> bool:
	if not is_finite(value) or value < 0.0 or value > 1.0:
		push_error("roundness must be between zero and one.")
		return false
	return true


static func _valid_rectangle_roundness_mode(value: RectangleRoundnessMode) -> bool:
	if value < RectangleRoundnessMode.CORNER_LOCAL or value > RectangleRoundnessMode.SHAPE_RELATIVE:
		push_error("Invalid rectangle roundness mode.")
		return false
	return true


static func _valid_angles(start: float, span: float) -> bool:
	if not is_finite(start) or not is_finite(span) or span < 0.0 or span > TAU:
		push_error("span_radians must be between zero and TAU.")
		return false
	return true


static func _valid_sides(value: int) -> bool:
	if value < 3 or value > 128:
		push_error("sides must be between 3 and 128.")
		return false
	return true
