extends Node3D

const NORMAL_LENGTH := 0.24
const MAX_NORMAL_LINES := 180

var _normal_material: ShaderMaterial
var _line_material: StandardMaterial3D


func _ready() -> void:
	_normal_material = ShaderMaterial.new()
	_normal_material.shader = load("res://examples/normal_visualization/normal_visualization.gdshader")
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.vertex_color_use_as_albedo = true
	_build_gallery()


func _build_gallery() -> void:
	var samples := [
		["Mold Cuboid", MoldShape.cuboid(Vector3.ONE, 0.0, MoldShape.Detail.LOW)],
		["Rounded Cuboid", MoldShape.cuboid(Vector3.ONE, 0.3, MoldShape.Detail.LOW)],
		["Cylinder", MoldShape.cylinder(0.5, 1.0, 0.0, MoldShape.Detail.LOW)],
		["Rounded Cylinder", MoldShape.cylinder(0.5, 1.0, 0.28, MoldShape.Detail.LOW)],
		["5-sided Prism", MoldShape.regular_prism(5, 0.5, 1.0, 0.0, MoldShape.Detail.LOW)],
		["Rounded Prism", MoldShape.regular_prism(6, 0.5, 1.0, 0.28, MoldShape.Detail.LOW)],
		["Cone", MoldShape.cone(0.5, 1.0, MoldShape.Detail.LOW)],
		["Sphere", MoldShape.sphere(0.5, MoldShape.Detail.LOW)],
		["Hemisphere", MoldShape.hemisphere(0.5, true, MoldShape.Detail.LOW)],
		["Capsule", MoldShape.capsule(0.5, 1.0, MoldShape.Detail.LOW)],
		["Torus", MoldShape.torus(0.5, 0.25, 0.0, TAU, MoldShape.Detail.LOW)],
	]
	var cache := MoldMeshCache.new()
	for index in samples.size():
		var shape: MoldShape = samples[index][1]
		_add_sample(samples[index][0], cache.mesh_for_testing(shape), _grid_position(index))
	var engine_box := BoxMesh.new()
	engine_box.size = Vector3.ONE
	_add_sample("Engine BoxMesh", engine_box, _grid_position(samples.size()))


func _add_sample(label: String, mesh: Mesh, position: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.name = label.replace(" ", "")
	pivot.position = position
	pivot.rotation = Vector3(0.12, -0.42, 0.06)
	add_child(pivot)
	var surface := MeshInstance3D.new()
	surface.mesh = mesh
	surface.material_override = _normal_material
	pivot.add_child(surface)
	var line_instance := MeshInstance3D.new()
	line_instance.mesh = _build_normal_lines(mesh)
	pivot.add_child(line_instance)
	var caption := Label3D.new()
	caption.text = label
	caption.position = Vector3(0.0, -0.82, 0.0)
	caption.font_size = 34
	caption.outline_size = 8
	caption.modulate = Color(1.0, 0.86, 0.3) if label.begins_with("Engine") else Color(0.78, 0.92, 1.0)
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pivot.add_child(caption)


func _build_normal_lines(mesh: Mesh) -> ImmediateMesh:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var stride := maxi(1, vertices.size() / MAX_NORMAL_LINES)
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES, _line_material)
	for index in range(0, vertices.size(), stride):
		var normal := normals[index].normalized()
		var color := Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5)
		var start := vertices[index] + normal * 0.006
		lines.surface_set_color(color)
		lines.surface_add_vertex(start)
		lines.surface_set_color(color)
		lines.surface_add_vertex(start + normal * NORMAL_LENGTH)
	lines.surface_end()
	return lines


func _grid_position(index: int) -> Vector3:
	var column := index % 4
	var row := index / 4
	return Vector3((column - 1.5) * 2.5, 1.7 - row * 2.3, 0.0)
