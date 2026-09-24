@tool
extends EditorNode3DGizmoPlugin


func _init() -> void:
	create_material("mold_bounds", Color(0.35, 0.95, 1.0, 0.85))


func _has_gizmo(node: Node3D) -> bool:
	return node is MoldNode3D or node is MoldPolylineNode3D


func _get_gizmo_name() -> String:
	return "Mold"


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var mold := gizmo.get_node_3d()
	if not mold is MoldNode3D and not mold is MoldPolylineNode3D: return
	var lines := _bounds_lines(mold.get_mold_aabb())
	gizmo.add_lines(lines, get_material("mold_bounds", gizmo))
	gizmo.add_collision_segments(lines)


static func _bounds_lines(bounds: AABB) -> PackedVector3Array:
	var minimum := bounds.position
	var maximum := bounds.end
	var points := [
		Vector3(minimum.x, minimum.y, minimum.z), Vector3(maximum.x, minimum.y, minimum.z),
		Vector3(maximum.x, maximum.y, minimum.z), Vector3(minimum.x, maximum.y, minimum.z),
		Vector3(minimum.x, minimum.y, maximum.z), Vector3(maximum.x, minimum.y, maximum.z),
		Vector3(maximum.x, maximum.y, maximum.z), Vector3(minimum.x, maximum.y, maximum.z),
	]
	var edges := [0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 5, 6, 6, 7, 7, 4, 0, 4, 1, 5, 2, 6, 3, 7]
	var result := PackedVector3Array()
	for index in edges: result.append(points[index])
	return result
