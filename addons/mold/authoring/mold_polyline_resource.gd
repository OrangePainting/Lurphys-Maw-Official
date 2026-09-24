@tool
class_name MoldPolylineResource
extends Resource

@export var points: Array[MoldPolylinePointResource] = [
	_point(Vector3(-0.5, 0.0, 0.0)),
	_point(Vector3(0.0, 0.5, 0.0)),
	_point(Vector3(0.5, 0.0, 0.0)),
]:
	set(value):
		_disconnect_points()
		points = value if value else []
		_connect_points()
		emit_changed()
@export_range(0.001, 100000.0, 0.001, "or_greater") var thickness := 0.05:
	set(value): thickness = maxf(value, 0.001) if is_finite(value) else 0.05; emit_changed()
@export var closed := false:
	set(value): closed = value; notify_property_list_changed(); emit_changed()
@export var join: MoldPolyline.Join = MoldPolyline.Join.MITER:
	set(value): join = value; emit_changed()
@export var cap: MoldPolyline.Cap = MoldPolyline.Cap.BUTT:
	set(value): cap = value; emit_changed()
@export_range(1.0, 100.0, 0.01, "or_greater") var miter_limit := 4.0:
	set(value): miter_limit = maxf(value, 1.0) if is_finite(value) else 4.0; emit_changed()
@export_range(1, 64, 1) var round_subdivisions := 8:
	set(value): round_subdivisions = clampi(value, 1, 64); emit_changed()
func _init() -> void:
	_connect_points()


func to_polyline() -> MoldPolyline:
	var runtime_points: Array[MoldPolylinePoint] = []
	var count := points.size()
	runtime_points.resize(count)
	for index in count:
		assert(points[index] != null, "Polyline point %d is missing." % index)
		runtime_points[index] = points[index].to_point()
	return MoldPolyline.new(runtime_points, thickness, closed, join, cap,
		miter_limit, round_subdivisions)


func _connect_points() -> void:
	var count := points.size()
	for index in count:
		var point := points[index]
		if point and not point.changed.is_connected(_on_point_changed):
			point.changed.connect(_on_point_changed)


func _disconnect_points() -> void:
	var count := points.size()
	for index in count:
		var point := points[index]
		if point and point.changed.is_connected(_on_point_changed):
			point.changed.disconnect(_on_point_changed)


func _on_point_changed() -> void:
	emit_changed()


func _validate_property(property: Dictionary) -> void:
	var property_name: String = property.name
	if property_name == "cap" and closed:
		property.usage &= ~PROPERTY_USAGE_EDITOR


static func _point(value_position: Vector3) -> MoldPolylinePointResource:
	var result := MoldPolylinePointResource.new()
	result.position = value_position
	return result
