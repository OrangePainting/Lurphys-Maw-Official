class_name MoldHandle
extends RefCounted

static var _next_world_id := 1
static var _worlds: Dictionary = {}

var _world_id: int
var _index: int
var _generation: int
var _world:
	get: return _resolve_world(_world_id)

var is_valid: bool:
	get:
		var world = _world
		return is_instance_valid(world) and world._is_available() and world.is_handle_valid(self)


func _init(world = null, index: int = -1, generation: int = 0) -> void:
	_world_id = world._world_id if is_instance_valid(world) else 0
	_index = index
	_generation = generation


func release() -> void:
	var world = _world
	if is_instance_valid(world) and world._is_available() and world.is_handle_valid(self):
		world.release(self)


func set_shape(value: MoldShape) -> void: _required_world().update_shape(self, value)
func set_dash(value: MoldDash) -> void: _required_world().update_dash(self, value)
func set_style(value: MoldStyle) -> void: _required_world().update_style(self, value)
func set_color(value: Color) -> void: _required_world().update_color(self, value)
func set_secondary_color(value: Color) -> void: _required_world().update_secondary_color(self, value)
func set_position(value: Vector3) -> void: _required_world().update_position(self, value)
func set_rotation(value: Quaternion) -> void: _required_world().update_rotation(self, value)
func set_rotation_radians(value: float) -> void: set_rotation(Quaternion(Vector3.BACK, value))
func set_rotation_degrees(value: float) -> void: set_rotation_radians(deg_to_rad(value))
func set_scale(value: Vector3) -> void: _required_world().update_scale(self, value)
func set_line_positions(start: Vector3, end: Vector3) -> void: _required_world().update_line_positions(self, start, end)
func set_polyline(value: MoldPolyline) -> void: _required_world().update_polyline(self, value)
func set_polyline_point(index: int, point: MoldPolylinePoint) -> void: _required_world().update_polyline_point(self, index, point)
func set_polyline_points(points: Array[MoldPolylinePoint]) -> void: _required_world().update_polyline_points(self, points)
func set_transform(position: Vector3, rotation: Quaternion, scale: Vector3) -> void: _required_world().update_transform(self, position, rotation, scale)
func set_render_state(value: MoldRenderState) -> void: _required_world().update_render_state(self, value)
func set_visible(value: bool) -> void: _required_world().update_visibility(self, value)


func _required_world():
	var world = _world
	assert(is_instance_valid(world) and world._is_available(), "Mold handle is stale or detached.")
	return world


static func _register_world(world) -> int:
	var id := _next_world_id
	_next_world_id += 1
	while id == 0 or _resolve_world(id) != null:
		id = _next_world_id
		_next_world_id += 1
	_worlds[id] = weakref(world)
	return id


static func _unregister_world(id: int, world) -> void:
	var reference := _worlds.get(id) as WeakRef
	if reference and reference.get_ref() == world:
		_worlds.erase(id)


static func _resolve_world(id: int):
	if id == 0: return null
	var reference := _worlds.get(id) as WeakRef
	var world = reference.get_ref() if reference else null
	if not is_instance_valid(world):
		_worlds.erase(id)
		return null
	return world
