class_name MoldPolyline
extends RefCounted

enum Join { MITER, BEVEL, ROUND }
enum Cap { BUTT, SQUARE, ROUND }

static var _next_geometry_id := 0

var _points: Array[MoldPolylinePoint] = []
var _thickness := 0.05
var _closed := false
var _join := Join.MITER
var _cap := Cap.BUTT
var _miter_limit := 4.0
var _round_subdivisions := 8
var _bounds := AABB()
var _length := 0.0
var _geometry_id := 0

var points: Array[MoldPolylinePoint]:
	get: return _duplicate_points()
var thickness: float:
	get: return _thickness
var closed: bool:
	get: return _closed
var join: int:
	get: return _join
var cap: int:
	get: return _cap
var miter_limit: float:
	get: return _miter_limit
var round_subdivisions: int:
	get: return _round_subdivisions
var bounds: AABB:
	get: return _bounds
var length: float:
	get: return _length


func _init(value_points: Array[MoldPolylinePoint] = [], value_thickness := 0.05,
		value_closed := false, value_join := Join.MITER, value_cap := Cap.BUTT,
		value_miter_limit := 4.0, value_round_subdivisions := 8) -> void:
	assert(is_finite(value_thickness) and value_thickness > 0.0, "Polyline thickness must be positive and finite.")
	assert(value_join >= Join.MITER and value_join <= Join.ROUND, "Invalid polyline join.")
	assert(value_cap >= Cap.BUTT and value_cap <= Cap.ROUND, "Invalid polyline cap.")
	assert(is_finite(value_miter_limit) and value_miter_limit >= 1.0, "Polyline miter limit must be at least one.")
	assert(value_round_subdivisions >= 1 and value_round_subdivisions <= 64, "Polyline round subdivisions must be in [1, 64].")
	var count := value_points.size()
	if value_closed and count > 2 and value_points[0].position == value_points[count - 1].position:
		count -= 1
	assert(count >= (3 if value_closed else 2), "A polyline needs at least two open or three closed points.")
	for index in count:
		var point := value_points[index].duplicate_point()
		if index > 0:
			assert(absf(point.position.z - _points[0].position.z) <= 0.00001, "Polyline points must lie on one local XY plane.")
			assert(_planar_distance_squared(_points[index - 1], point) >= 0.000000000001, "Consecutive polyline points cannot share an XY position.")
		_points.append(point)
	if value_closed:
		assert(_planar_distance_squared(_points[-1], _points[0]) >= 0.000000000001, "The closing segment cannot have zero XY length.")
	_thickness = value_thickness
	_closed = value_closed
	_join = value_join
	_cap = value_cap
	_miter_limit = value_miter_limit
	_round_subdivisions = value_round_subdivisions
	_length = _calculate_length()
	_bounds = _calculate_bounds()
	MoldPolyline._next_geometry_id += 1
	_geometry_id = MoldPolyline._next_geometry_id


func with_point(index: int, point: MoldPolylinePoint) -> MoldPolyline:
	assert(index >= 0 and index < _points.size(), "Polyline point index is out of range.")
	var copy := _duplicate_points()
	copy[index] = point.duplicate_point()
	return _copy(copy)


func with_points(value: Array[MoldPolylinePoint]) -> MoldPolyline:
	return _copy(value)


func _copy(value_points: Array[MoldPolylinePoint]) -> MoldPolyline:
	return MoldPolyline.new(value_points, _thickness, _closed, _join, _cap, _miter_limit, _round_subdivisions)


func _duplicate_points() -> Array[MoldPolylinePoint]:
	var copy: Array[MoldPolylinePoint] = []
	var count := _points.size()
	copy.resize(count)
	for index in count: copy[index] = _points[index].duplicate_point()
	return copy


func _calculate_bounds() -> AABB:
	var minimum := _points[0].position
	var maximum := minimum
	var padding := 0.0
	for point in _points:
		minimum = Vector3(minf(minimum.x, point.position.x), minf(minimum.y, point.position.y), minf(minimum.z, point.position.z))
		maximum = Vector3(maxf(maximum.x, point.position.x), maxf(maximum.y, point.position.y), maxf(maximum.z, point.position.z))
		padding = maxf(padding, _thickness * point.thickness * 0.5 * _miter_limit)
	return AABB(minimum - Vector3.ONE * padding, maximum - minimum + Vector3.ONE * padding * 2.0)


func _calculate_length() -> float:
	var result := 0.0
	var point_count := _points.size()
	for index in range(1, point_count):
		result += Vector2(_points[index].position.x - _points[index - 1].position.x, _points[index].position.y - _points[index - 1].position.y).length()
	if _closed:
		result += Vector2(_points[0].position.x - _points[-1].position.x, _points[0].position.y - _points[-1].position.y).length()
	return result


static func _planar_distance_squared(first: MoldPolylinePoint, second: MoldPolylinePoint) -> float:
	return Vector2(first.position.x - second.position.x, first.position.y - second.position.y).length_squared()
