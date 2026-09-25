class_name MoldMeshCache
extends RefCounted

class MeshKey:
	extends RefCounted
	enum Kind { QUAD, CUBOID, ROUNDED_CUBOID, CYLINDER, ROUNDED_CYLINDER, REGULAR_PRISM, ROUNDED_REGULAR_PRISM, CONE, SPHERE, HEMISPHERE, CAPSULE, TORUS, POLYLINE }
	var kind: Kind
	var detail: MoldShape.Detail
	var sides: int
	var roundness_bucket: int
	var roundness_resolution: int
	var capped: bool
	var polyline: MoldPolyline
	var axial_roundness_bucket: int
	var depth_roundness_bucket: int
	func _init(value_kind: Kind, value_detail: MoldShape.Detail = MoldShape.Detail.MINIMAL, value_sides: int = 0, bucket: int = 0, resolution: int = 1, value_capped: bool = true, value_polyline: MoldPolyline = null, axial_bucket: int = -1, depth_bucket: int = -1) -> void:
		kind = value_kind
		detail = value_detail
		sides = value_sides
		roundness_bucket = bucket
		roundness_resolution = maxi(1, resolution)
		capped = value_capped
		polyline = value_polyline
		axial_roundness_bucket = axial_bucket
		depth_roundness_bucket = depth_bucket
	var axial_roundness: float:
		get: return float(axial_roundness_bucket if axial_roundness_bucket >= 0 else roundness_bucket) / roundness_resolution
	var depth_roundness: float:
		get: return float(depth_roundness_bucket if depth_roundness_bucket >= 0 else roundness_bucket) / roundness_resolution
	func packed_key() -> Vector3i:
		# Keep cache lookup structural. Formatting this data as a String made every
		# acquire/release and every automatic-LOD comparison allocate.
		return pack_values(kind, detail, sides, roundness_bucket,
			roundness_resolution, capped, axial_roundness_bucket,
			depth_roundness_bucket, polyline._geometry_id if polyline else 0)
	func equals(other: MeshKey) -> bool:
		return other != null and packed_key() == other.packed_key()
	static func pack_values(value_kind: Kind, value_detail: MoldShape.Detail,
		value_sides: int, bucket: int, resolution: int, value_capped: bool,
		axial_bucket: int = -1, depth_bucket: int = -1, geometry_id: int = 0) -> Vector3i:
		var topology := value_kind | (value_detail << 4) | (value_sides << 7) | (bucket << 15)
		var resolved_axial_bucket := maxi(0, axial_bucket if axial_bucket >= 0 else bucket)
		var parameters := maxi(1, resolution) | (int(value_capped) << 13) | (resolved_axial_bucket << 14)
		var third := geometry_id if value_kind == Kind.POLYLINE else maxi(0, depth_bucket if depth_bucket >= 0 else 0)
		return Vector3i(topology, parameters, third)

class CacheEntry:
	extends RefCounted
	var key: MeshKey
	var mesh: Mesh
	var reference_count := 0
	var last_use := 0

class MeshBuffers:
	extends RefCounted
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	# Polyline meshes bake their screen-space expansion vector here and read it back
	# as CUSTOM0 in the shader. ARRAY_TANGENT cannot carry it: Godot stores tangents
	# octahedron-encoded, which normalizes them and destroys the extrusion length.
	var extrusions := PackedFloat32Array()
	var polyline_coordinates := PackedFloat32Array()
	var polyline_changes := PackedFloat32Array()
	var uses_extrusion := false
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	func add_vertex(vertex: Vector3, normal: Vector3, uv: Vector2,
			color := Color.WHITE, extrusion := Vector4.ZERO) -> void:
		vertices.append(vertex); normals.append(normal); uvs.append(uv); colors.append(color)
		extrusions.append(extrusion.x); extrusions.append(extrusion.y)
		extrusions.append(extrusion.z); extrusions.append(extrusion.w)
	func add_triangle(first: int, second: int, third: int) -> void:
		indices.append(first); indices.append(second); indices.append(third)
	func create_mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var result := ArrayMesh.new()
		if uses_extrusion:
			arrays[Mesh.ARRAY_CUSTOM0] = extrusions
			arrays[Mesh.ARRAY_CUSTOM1] = polyline_coordinates
			arrays[Mesh.ARRAY_CUSTOM2] = polyline_changes
			var blend_shapes: Array[Array] = []
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blend_shapes, {},
				(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
				| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
				| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT))
		else: result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return result

var hits := 0
var misses := 0
var count: int:
	get: return _entries.size()

var _roundness_resolution: int
var _retained_unused_count: int
var _entries: Dictionary = {}
var _keys: Dictionary = {}
var _use_counter := 0


func _init(resolution: int = 256, retained_unused: int = 64) -> void:
	_roundness_resolution = clampi(resolution, 1, 4096)
	_retained_unused_count = maxi(0, retained_unused)


func resolve_key(shape: MoldShape, detail: MoldShape.Detail = -1) -> MeshKey:
	if shape.is_2d: return _canonical_key(MeshKey.Kind.QUAD, MoldShape.Detail.MINIMAL, 0, 0, 1, true)
	if detail < 0: detail = shape.detail
	var bucket := _quantize_roundness(shape.roundness)
	var axial_bucket := -1
	var depth_bucket := -1
	if shape.kind == MoldShape.Kind.CUBOID:
		# Express one physical corner radius along every canonical axis. Unequal
		# canonical radii become a circular fillet after per-instance scaling.
		var cuboid_roundness := shape.roundness * 0.5
		var shortest := minf(shape.size.x, minf(shape.size.y, shape.size.z))
		bucket = _quantize_positive_roundness(
			cuboid_roundness * shortest / maxf(shape.size.x, 0.0001))
		axial_bucket = _quantize_positive_roundness(
			cuboid_roundness * shortest / maxf(shape.size.y, 0.0001))
		depth_bucket = _quantize_positive_roundness(
			cuboid_roundness * shortest / maxf(shape.size.z, 0.0001))
	elif shape.kind in [MoldShape.Kind.CYLINDER, MoldShape.Kind.REGULAR_PRISM]:
		var diameter := shape.thickness if shape.is_line else shape.radius * 2.0
		var length := maxf(shape.start_position.distance_to(shape.end_position), 0.0001) if shape.is_line else shape.height
		var shortest := minf(diameter, length)
		var radial_roundness := minf(shape.roundness * shortest / maxf(diameter, 0.0001), 1.0)
		bucket = _quantize_roundness(radial_roundness)
		axial_bucket = _quantize_roundness(shape.roundness * shortest / maxf(length, 0.0001))
	match shape.kind:
		MoldShape.Kind.CUBOID:
			if bucket == 0 and axial_bucket == 0 and depth_bucket == 0:
				return _canonical_key(MeshKey.Kind.CUBOID, detail, 0, 0, 1, true)
			return _canonical_key(MeshKey.Kind.ROUNDED_CUBOID, detail, 0, bucket, _roundness_resolution, true, null, axial_bucket, depth_bucket)
		MoldShape.Kind.CYLINDER:
			if bucket == 0 or axial_bucket == 0:
				return _canonical_key(MeshKey.Kind.CYLINDER, detail, 0, 0, 1, true)
			return _canonical_key(MeshKey.Kind.ROUNDED_CYLINDER, detail, 0, bucket, _roundness_resolution, true, null, axial_bucket)
		MoldShape.Kind.REGULAR_PRISM:
			if bucket == 0 or axial_bucket == 0:
				return _canonical_key(MeshKey.Kind.REGULAR_PRISM, MoldShape.Detail.MINIMAL, shape.sides, 0, 1, true)
			return _canonical_key(MeshKey.Kind.ROUNDED_REGULAR_PRISM, detail, shape.sides, bucket, _roundness_resolution, true, null, axial_bucket)
		MoldShape.Kind.CONE: return _canonical_key(MeshKey.Kind.CONE, detail, 0, 0, 1, true)
		MoldShape.Kind.SPHERE: return _canonical_key(MeshKey.Kind.SPHERE, detail, 0, 0, 1, true)
		MoldShape.Kind.HEMISPHERE: return _canonical_key(MeshKey.Kind.HEMISPHERE, detail, 0, 0, 1, shape.capped)
		MoldShape.Kind.CAPSULE: return _canonical_key(MeshKey.Kind.CAPSULE, detail, 0, 0, 1, true)
		MoldShape.Kind.TORUS: return _canonical_key(MeshKey.Kind.TORUS, detail, 0, 0, 1,
			shape.span_radians > 0.0 and shape.span_radians < TAU)
	return _canonical_key(MeshKey.Kind.QUAD, MoldShape.Detail.MINIMAL, 0, 0, 1, true)


func _quantize_roundness(value: float) -> int:
	return clampi(roundi(value * _roundness_resolution), 0, _roundness_resolution)


func _quantize_positive_roundness(value: float) -> int:
	return maxi(1, _quantize_roundness(value)) if value > 0.0 else 0


func resolve_polyline_key(polyline: MoldPolyline) -> MeshKey:
	# The key owns the source path needed to regenerate the mesh. Do not intern
	# these or released procedural paths would stay alive for the world's lifetime.
	return MeshKey.new(MeshKey.Kind.POLYLINE, MoldShape.Detail.MINIMAL,
		0, 0, 1, true, polyline)


func _canonical_key(kind: MeshKey.Kind, detail: MoldShape.Detail, sides: int,
	bucket: int, resolution: int, capped: bool, polyline: MoldPolyline = null,
	axial_bucket: int = -1, depth_bucket: int = -1) -> MeshKey:
	var packed := MeshKey.pack_values(kind, detail, sides, bucket, resolution,
		capped, axial_bucket, depth_bucket, polyline._geometry_id if polyline else 0)
	var found: MeshKey = _keys.get(packed)
	if found: return found
	var result := MeshKey.new(kind, detail, sides, bucket, resolution, capped, polyline, axial_bucket, depth_bucket)
	_keys[packed] = result
	return result


func acquire(key: MeshKey) -> Mesh:
	var entry := _get_or_create(key)
	entry.reference_count += 1
	_use_counter += 1
	entry.last_use = _use_counter
	return entry.mesh


func release(key: MeshKey) -> void:
	var entry: CacheEntry = _entries.get(key.packed_key())
	if not entry: return
	entry.reference_count = maxi(0, entry.reference_count - 1)
	_use_counter += 1
	entry.last_use = _use_counter
	_trim_unused()


func prewarm(shapes: Array) -> void:
	for shape: MoldShape in shapes:
		if not shape.is_empty: _get_or_create(resolve_key(shape))
	_trim_unused()


func clear_unused() -> void:
	for id in _entries:
		if (_entries[id] as CacheEntry).reference_count == 0: _entries.erase(id)


func mesh_for_testing(shape: MoldShape) -> Mesh:
	return _get_or_create(resolve_key(shape)).mesh


func polyline_mesh_for_testing(polyline: MoldPolyline) -> Mesh:
	return _get_or_create(resolve_polyline_key(polyline)).mesh


func _get_or_create(key: MeshKey) -> CacheEntry:
	var id := key.packed_key()
	var found: CacheEntry = _entries.get(id)
	if found:
		hits += 1
		_use_counter += 1
		found.last_use = _use_counter
		return found
	misses += 1
	var entry := CacheEntry.new()
	entry.key = key
	entry.mesh = _generate_mesh(key)
	_use_counter += 1
	entry.last_use = _use_counter
	_entries[id] = entry
	return entry


func _trim_unused() -> void:
	var unused_count := 0
	for id in _entries:
		if (_entries[id] as CacheEntry).reference_count == 0: unused_count += 1
	while unused_count > _retained_unused_count:
		var oldest_id = null
		var oldest_use := 9223372036854775807
		for id in _entries:
			var entry: CacheEntry = _entries[id]
			if entry.reference_count != 0 or entry.last_use >= oldest_use: continue
			oldest_id = id
			oldest_use = entry.last_use
		if oldest_id == null: break
		_entries.erase(oldest_id)
		unused_count -= 1


static func _detail_settings(detail: MoldShape.Detail) -> Vector4i:
	match detail:
		MoldShape.Detail.MINIMAL: return Vector4i(8, 2, 1, 0)
		MoldShape.Detail.LOW: return Vector4i(12, 4, 2, 1)
		MoldShape.Detail.HIGH: return Vector4i(48, 16, 6, 3)
		MoldShape.Detail.EXTREME: return Vector4i(96, 32, 12, 4)
	return Vector4i(24, 8, 3, 2)


static func _generate_mesh(key: MeshKey) -> Mesh:
	var detail := _detail_settings(key.detail)
	match key.kind:
		MeshKey.Kind.QUAD: return _quad()
		MeshKey.Kind.CUBOID: return _cuboid()
		MeshKey.Kind.ROUNDED_CUBOID:
			return _rounded_box_axes(
				float(key.roundness_bucket) / key.roundness_resolution,
				key.axial_roundness,
				key.depth_roundness,
				detail.z)
		MeshKey.Kind.CYLINDER: return _cylinder(detail.x, detail.y)
		MeshKey.Kind.ROUNDED_CYLINDER:
			return _rounded_cylinder(detail.x, detail.y, detail.z,
				float(key.roundness_bucket) / key.roundness_resolution,
				key.axial_roundness)
		MeshKey.Kind.REGULAR_PRISM: return _cylinder(key.sides, 1)
		MeshKey.Kind.ROUNDED_REGULAR_PRISM:
			return _rounded_cylinder(key.sides, 1, detail.z,
				float(key.roundness_bucket) / key.roundness_resolution,
				key.axial_roundness)
		MeshKey.Kind.CONE: return _cylinder(detail.x, detail.y, 0.0, 0.5)
		MeshKey.Kind.SPHERE: return _sphere(detail.w)
		MeshKey.Kind.HEMISPHERE: return _hemisphere(detail.x, maxi(1, detail.y / 2), key.capped)
		MeshKey.Kind.CAPSULE: return _capsule(detail.x, maxi(2, detail.y / 2))
		MeshKey.Kind.TORUS: return _torus(detail.x, maxi(6, detail.y * 2), key.capped)
		MeshKey.Kind.POLYLINE:
			var data := MeshBuffers.new()
			MoldPolylineMeshGenerator.generate(data, key.polyline)
			return data.create_mesh()
	return _quad()


static func _torus(major_segments: int, minor_segments: int, capped: bool) -> ArrayMesh:
	major_segments = maxi(3, major_segments)
	minor_segments = maxi(3, minor_segments)
	var data := MeshBuffers.new()
	for major in range(major_segments + 1):
		var u := float(major) / major_segments
		var major_angle := -u * TAU
		var radial := Vector3(cos(major_angle), 0.0, sin(major_angle))
		for minor in range(minor_segments + 1):
			var v := float(minor) / minor_segments
			var minor_angle := v * TAU
			var normal := radial * cos(minor_angle) + Vector3.UP * sin(minor_angle)
			data.add_vertex(radial * 0.375 + normal * 0.125, normal, Vector2(u, v))
	var stride := minor_segments + 1
	for major in range(major_segments):
		for minor in range(minor_segments):
			var index := major * stride + minor
			data.add_triangle(index, index + 1, index + stride)
			data.add_triangle(index + 1, index + stride + 1, index + stride)
	if capped:
		_add_torus_cap(data, minor_segments, 0.375, 0.125, true)
		_add_torus_cap(data, minor_segments, 0.375, 0.125, false)
	return data.create_mesh()


static func _add_torus_cap(data: MeshBuffers, segments: int,
		major_radius: float, tube_radius: float, start: bool) -> void:
	var center := data.vertices.size()
	var normal := Vector3.FORWARD if start else Vector3.BACK
	var uv_marker := -1.0 if start else 2.0
	data.add_vertex(Vector3(major_radius, 0.0, 0.0), normal,
		Vector2(uv_marker, 0.5))
	for segment in range(segments + 1):
		var v := float(segment) / segments
		var angle := v * TAU
		data.add_vertex(Vector3(
			major_radius + cos(angle) * tube_radius,
			sin(angle) * tube_radius,
			0.0), normal, Vector2(uv_marker, v))
	for segment in range(segments):
		var edge := center + segment + 1
		if start: data.add_triangle(center, edge, edge + 1)
		else: data.add_triangle(center, edge + 1, edge)


static func _quad() -> ArrayMesh:
	var data := MeshBuffers.new()
	data.add_vertex(Vector3(-0.5, -0.5, 0.0), Vector3.BACK, Vector2.ZERO)
	data.add_vertex(Vector3(-0.5, 0.5, 0.0), Vector3.BACK, Vector2(0.0, 1.0))
	data.add_vertex(Vector3(0.5, 0.5, 0.0), Vector3.BACK, Vector2.ONE)
	data.add_vertex(Vector3(0.5, -0.5, 0.0), Vector3.BACK, Vector2.RIGHT)
	data.add_triangle(0, 1, 2)
	data.add_triangle(0, 2, 3)
	return data.create_mesh()


static func _cuboid() -> ArrayMesh:
	var data := MeshBuffers.new()
	_add_cuboid_face(data, Vector3.BACK, Vector3.RIGHT, Vector3.UP)
	_add_cuboid_face(data, Vector3.FORWARD, Vector3.LEFT, Vector3.UP)
	_add_cuboid_face(data, Vector3.LEFT, Vector3.BACK, Vector3.UP)
	_add_cuboid_face(data, Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	_add_cuboid_face(data, Vector3.DOWN, Vector3.RIGHT, Vector3.BACK)
	_add_cuboid_face(data, Vector3.UP, Vector3.RIGHT, Vector3.FORWARD)
	return data.create_mesh()


static func _add_cuboid_face(data: MeshBuffers, normal: Vector3, axis_x: Vector3, axis_y: Vector3) -> void:
	var first := data.vertices.size()
	var center := normal * 0.5
	data.add_vertex(center - axis_x * 0.5 - axis_y * 0.5, normal, Vector2.ZERO)
	data.add_vertex(center - axis_x * 0.5 + axis_y * 0.5, normal, Vector2(0.0, 1.0))
	data.add_vertex(center + axis_x * 0.5 + axis_y * 0.5, normal, Vector2.ONE)
	data.add_vertex(center + axis_x * 0.5 - axis_y * 0.5, normal, Vector2.RIGHT)
	data.add_triangle(first, first + 1, first + 2)
	data.add_triangle(first, first + 2, first + 3)


static func _cylinder(columns: int, rows: int, top_radius := 0.5, bottom_radius := 0.5, capped := true) -> ArrayMesh:
	columns = maxi(3, columns)
	rows = maxi(1, rows)
	var data := MeshBuffers.new()
	var slope := top_radius - bottom_radius
	var side_normal := Vector2(1.0, -slope).normalized()
	for y in range(rows + 1):
		var v := float(y) / rows
		var radius := lerpf(bottom_radius, top_radius, v)
		var height := v - 0.5
		for x in range(columns + 1):
			var u := float(x) / columns
			var angle := -u * TAU
			var radial := Vector3(cos(angle), 0.0, sin(angle))
			data.add_vertex(radial * radius + Vector3.UP * height, radial * side_normal.x + Vector3.UP * side_normal.y, Vector2(u, v))
	_add_surface_indices(data, columns, rows + 1, 0, bottom_radius <= 0.000001, top_radius <= 0.000001)
	if capped:
		_add_cap(data, columns, bottom_radius, -0.5, false)
		_add_cap(data, columns, top_radius, 0.5, true)
	return data.create_mesh()


static func _sphere(subdivisions: int) -> ArrayMesh:
	subdivisions = clampi(subdivisions, 0, 8)
	var golden_ratio := (1.0 + sqrt(5.0)) * 0.5
	var vertices: Array[Vector3] = [
		Vector3(-1.0, golden_ratio, 0.0).normalized(),
		Vector3(1.0, golden_ratio, 0.0).normalized(),
		Vector3(-1.0, -golden_ratio, 0.0).normalized(),
		Vector3(1.0, -golden_ratio, 0.0).normalized(),
		Vector3(0.0, -1.0, golden_ratio).normalized(),
		Vector3(0.0, 1.0, golden_ratio).normalized(),
		Vector3(0.0, -1.0, -golden_ratio).normalized(),
		Vector3(0.0, 1.0, -golden_ratio).normalized(),
		Vector3(golden_ratio, 0.0, -1.0).normalized(),
		Vector3(golden_ratio, 0.0, 1.0).normalized(),
		Vector3(-golden_ratio, 0.0, -1.0).normalized(),
		Vector3(-golden_ratio, 0.0, 1.0).normalized(),
	]
	var triangles := PackedInt32Array([
		0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11,
		1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9,
		4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1,
	])
	for _level in range(subdivisions):
		var midpoints: Dictionary = {}
		var triangle_count := triangles.size() / 3
		var subdivided := PackedInt32Array()
		subdivided.resize(triangle_count * 12)
		var output := 0
		for triangle in range(triangle_count):
			var offset := triangle * 3
			var first := triangles[offset]
			var second := triangles[offset + 1]
			var third := triangles[offset + 2]
			var first_second := _sphere_midpoint(vertices, midpoints, first, second)
			var second_third := _sphere_midpoint(vertices, midpoints, second, third)
			var third_first := _sphere_midpoint(vertices, midpoints, third, first)
			subdivided[output] = first; output += 1
			subdivided[output] = first_second; output += 1
			subdivided[output] = third_first; output += 1
			subdivided[output] = first_second; output += 1
			subdivided[output] = second; output += 1
			subdivided[output] = second_third; output += 1
			subdivided[output] = third_first; output += 1
			subdivided[output] = second_third; output += 1
			subdivided[output] = third; output += 1
			subdivided[output] = first_second; output += 1
			subdivided[output] = second_third; output += 1
			subdivided[output] = third_first; output += 1
		triangles = subdivided
	var data := MeshBuffers.new()
	var vertex_count := vertices.size()
	for index in range(vertex_count):
		var normal := vertices[index]
		data.add_vertex(normal * 0.5, normal, Vector2.ZERO)
	var triangle_count := triangles.size() / 3
	for triangle in range(triangle_count):
		var offset := triangle * 3
		data.add_triangle(triangles[offset], triangles[offset + 2], triangles[offset + 1])
	return data.create_mesh()


static func _sphere_midpoint(vertices: Array[Vector3], midpoints: Dictionary, first: int, second: int) -> int:
	var lower := mini(first, second)
	var upper := maxi(first, second)
	var key := (lower << 32) | upper
	if midpoints.has(key): return midpoints[key]
	var index := vertices.size()
	vertices.append(((vertices[first] + vertices[second]) * 0.5).normalized())
	midpoints[key] = index
	return index


static func _capsule(columns: int, hemisphere_rows: int) -> ArrayMesh:
	columns = maxi(3, columns)
	hemisphere_rows = maxi(2, hemisphere_rows)
	var positions := PackedVector2Array()
	var normals := PackedVector2Array()
	var bottom_center := Vector2(0.0, -0.5)
	var top_center := Vector2(0.0, 0.5)
	for index in range(hemisphere_rows + 1):
		var angle := lerpf(-PI * 0.5, 0.0, float(index) / hemisphere_rows)
		var normal := Vector2(cos(angle), sin(angle))
		positions.append(bottom_center + normal * 0.5)
		normals.append(normal)
	positions.append(Vector2(0.5, 0.5))
	normals.append(Vector2.RIGHT)
	for index in range(1, hemisphere_rows + 1):
		var angle := lerpf(0.0, PI * 0.5, float(index) / hemisphere_rows)
		var normal := Vector2(cos(angle), sin(angle))
		positions.append(top_center + normal * 0.5)
		normals.append(normal)
	var data := MeshBuffers.new()
	_add_profile(data, columns, positions, normals)
	return data.create_mesh()


static func _hemisphere(columns: int, rows: int, capped: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for y in range(rows + 1):
		var v := float(y) / rows
		var latitude := v * PI * 0.5
		for x in range(columns + 1):
			var u := float(x) / columns
			var angle := -u * TAU
			var normal := Vector3(cos(angle) * cos(latitude), sin(latitude), sin(angle) * cos(latitude))
			vertices.append(normal * 0.5)
			normals.append(normal)
			uvs.append(Vector2(u, v))
			colors.append(Color.WHITE)
	var stride := columns + 1
	for y in range(rows):
		for x in range(columns):
			var i := y * stride + x
			indices.append_array(PackedInt32Array([i, i + stride, i + 1]))
			if y < rows - 1: indices.append_array(PackedInt32Array([i + 1, i + stride, i + stride + 1]))
	if capped:
		var center := vertices.size()
		vertices.append(Vector3.ZERO); normals.append(Vector3.DOWN); uvs.append(Vector2.ONE * 0.5); colors.append(Color.WHITE)
		for x in range(columns + 1):
			var angle := -float(x) / columns * TAU
			vertices.append(Vector3(cos(angle) * 0.5, 0.0, sin(angle) * 0.5))
			normals.append(Vector3.DOWN)
			uvs.append(Vector2(cos(angle), sin(angle)) * 0.5 + Vector2.ONE * 0.5)
			colors.append(Color.WHITE)
		for x in range(columns): indices.append_array(PackedInt32Array([center, center + x + 1, center + x + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _rounded_box_axes(x_rounding: float, y_rounding: float,
		z_rounding: float, divisions: int) -> ArrayMesh:
	var data := MeshBuffers.new()
	const MAXIMUM_NORMALIZED_FILLET_RADIUS := 0.25
	var radii := Vector3(
		minf(clampf(x_rounding, 0.0, 1.0) * 0.5, MAXIMUM_NORMALIZED_FILLET_RADIUS),
		minf(clampf(y_rounding, 0.0, 1.0) * 0.5, MAXIMUM_NORMALIZED_FILLET_RADIUS),
		minf(clampf(z_rounding, 0.0, 1.0) * 0.5, MAXIMUM_NORMALIZED_FILLET_RADIUS))
	divisions = maxi(1, divisions)
	_rounded_box_add_face(data, Vector3.RIGHT, Vector3.UP, Vector3.BACK, radii, divisions)
	_rounded_box_add_face(data, Vector3.LEFT, Vector3.UP, Vector3.FORWARD, radii, divisions)
	_rounded_box_add_face(data, Vector3.FORWARD, Vector3.DOWN, Vector3.LEFT, radii, divisions)
	_rounded_box_add_face(data, Vector3.BACK, Vector3.DOWN, Vector3.RIGHT, radii, divisions)
	_rounded_box_add_face(data, Vector3.RIGHT, Vector3.BACK, Vector3.DOWN, radii, divisions)
	_rounded_box_add_face(data, Vector3.LEFT, Vector3.BACK, Vector3.UP, radii, divisions)
	return data.create_mesh()


static func _rounded_box_add_face(data: MeshBuffers, axis_u: Vector3,
		axis_v: Vector3, normal: Vector3, radii: Vector3, divisions: int) -> void:
	var radius_u := _axis_value(axis_u, radii)
	var radius_v := _axis_value(axis_v, radii)
	var edge_vertices := divisions * 2 + 2
	var first := data.vertices.size()
	for row in range(edge_vertices):
		var v := _rounded_box_edge_coordinate(row, radius_v, divisions)
		for column in range(edge_vertices):
			var u := _rounded_box_edge_coordinate(column, radius_u, divisions)
			var cube_point := axis_u * u + axis_v * v + normal * 0.5
			var rounded := _rounded_box_round_point(cube_point, radii)
			data.add_vertex(rounded[0], rounded[1], Vector2(u + 0.5, v + 0.5))
	for row in range(edge_vertices - 1):
		for column in range(edge_vertices - 1):
			var index := first + row * edge_vertices + column
			data.add_triangle(index, index + edge_vertices, index + 1)
			data.add_triangle(index + 1, index + edge_vertices, index + edge_vertices + 1)


static func _rounded_box_edge_coordinate(index: int, radius: float,
		divisions: int) -> float:
	return -0.5 + radius * index / divisions if index <= divisions \
		else 0.5 + radius * (index - divisions * 2 - 1) / divisions


static func _rounded_box_round_point(cube_point: Vector3, radii: Vector3) -> Array[Vector3]:
	var center := Vector3(
		clampf(cube_point.x, -0.5 + radii.x, 0.5 - radii.x),
		clampf(cube_point.y, -0.5 + radii.y, 0.5 - radii.y),
		clampf(cube_point.z, -0.5 + radii.z, 0.5 - radii.z))
	var direction := Vector3(
		(cube_point.x - center.x) / radii.x,
		(cube_point.y - center.y) / radii.y,
		(cube_point.z - center.z) / radii.z).normalized()
	var position := center + Vector3(
		radii.x * direction.x,
		radii.y * direction.y,
		radii.z * direction.z)
	var normal := Vector3(
		direction.x / radii.x,
		direction.y / radii.y,
		direction.z / radii.z).normalized()
	return [position, normal]


static func _axis_value(axis: Vector3, values: Vector3) -> float:
	return values.x if absf(axis.x) > 0.5 else (values.y if absf(axis.y) > 0.5 else values.z)


static func _rounded_cylinder(columns: int, side_rows: int, fillet_divisions: int,
		rounding: float, axial_rounding: float = -1.0) -> ArrayMesh:
	columns = maxi(3, columns)
	side_rows = maxi(1, side_rows)
	fillet_divisions = maxi(1, fillet_divisions)
	var radial_radius := clampf(rounding, 0.0, 1.0) * 0.5
	var axial_radius := clampf(axial_rounding if axial_rounding >= 0.0 else rounding, 0.0, 1.0) * 0.5
	if radial_radius <= 0.000001 or axial_radius <= 0.000001:
		return _cylinder(columns, side_rows)
	var positions := PackedVector2Array()
	var normals := PackedVector2Array()
	var bottom_center := Vector2(0.5 - radial_radius, -0.5 + axial_radius)
	var top_center := Vector2(0.5 - radial_radius, 0.5 - axial_radius)
	for index in range(fillet_divisions + 1):
		var angle := lerpf(-PI * 0.5, 0.0, float(index) / fillet_divisions)
		var normal := Vector2(cos(angle), sin(angle))
		positions.append(bottom_center + Vector2(normal.x * radial_radius, normal.y * axial_radius))
		normals.append(Vector2(normal.x, normal.y * radial_radius / axial_radius))
	var bottom_tangent := bottom_center + Vector2.RIGHT * radial_radius
	var top_tangent := top_center + Vector2.RIGHT * radial_radius
	for index in range(1, side_rows + 1):
		positions.append(bottom_tangent.lerp(top_tangent, float(index) / side_rows))
		normals.append(Vector2.RIGHT)
	for index in range(1, fillet_divisions + 1):
		var angle := lerpf(0.0, PI * 0.5, float(index) / fillet_divisions)
		var normal := Vector2(cos(angle), sin(angle))
		positions.append(top_center + Vector2(normal.x * radial_radius, normal.y * axial_radius))
		normals.append(Vector2(normal.x, normal.y * radial_radius / axial_radius))
	var data := MeshBuffers.new()
	_add_profile(data, columns, positions, normals)
	_add_cap(data, columns, bottom_center.x, -0.5, false)
	_add_cap(data, columns, top_center.x, 0.5, true)
	return data.create_mesh()


static func _add_profile(data: MeshBuffers, columns: int, positions: PackedVector2Array, normals: PackedVector2Array) -> void:
	var position_count := positions.size()
	var profile_v := PackedFloat32Array()
	profile_v.resize(position_count)
	var arc_length := 0.0
	for index in range(1, position_count):
		arc_length += positions[index - 1].distance_to(positions[index])
		profile_v[index] = arc_length
	if arc_length > 0.000001:
		for index in range(1, position_count): profile_v[index] /= arc_length
	for y in range(position_count):
		for x in range(columns + 1):
			var u := float(x) / columns
			var angle := -u * TAU
			var radial := Vector3(cos(angle), 0.0, sin(angle))
			data.add_vertex(radial * positions[y].x + Vector3.UP * positions[y].y, radial * normals[y].x + Vector3.UP * normals[y].y, Vector2(u, profile_v[y]))
	_add_surface_indices(data, columns, position_count, 0,
		absf(positions[0].x) <= 0.000001,
		absf(positions[position_count - 1].x) <= 0.000001)


static func _add_surface_indices(data: MeshBuffers, columns: int, ring_count: int, first: int,
		first_ring_collapsed := false, last_ring_collapsed := false) -> void:
	var stride := columns + 1
	for y in range(ring_count - 1):
		for x in range(columns):
			var index := first + y * stride + x
			var lower_collapsed := first_ring_collapsed and y == 0
			var upper_collapsed := last_ring_collapsed and y == ring_count - 2
			if not lower_collapsed:
				data.add_triangle(index, index + stride, index + 1)
			if not upper_collapsed:
				data.add_triangle(index + 1, index + stride, index + stride + 1)


static func _add_cap(data: MeshBuffers, columns: int, radius: float, height: float, top: bool) -> void:
	if radius <= 0.000001: return
	var center := data.vertices.size()
	var normal := Vector3.UP if top else Vector3.DOWN
	data.add_vertex(Vector3(0.0, height, 0.0), normal, Vector2.ONE * 0.5)
	for x in range(columns + 1):
		var angle := -float(x) / columns * TAU
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		data.add_vertex(radial * radius + Vector3.UP * height, normal, Vector2(cos(angle), sin(angle)) * 0.5 + Vector2.ONE * 0.5)
	for x in range(columns):
		if top: data.add_triangle(center, center + x + 2, center + x + 1)
		else: data.add_triangle(center, center + x + 1, center + x + 2)
