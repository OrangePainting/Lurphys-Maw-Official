class_name MoldGpuPolylineRenderer
extends RefCounted

## World-owned dynamic XY stroke stream, matching MoldUnity's SetData/UpdatePoints lifecycle.
## Points use eight packed floats: x, y, z, absolute thickness, r, g, b, a.
## Packed arrays avoid allocating one GDScript object per animated point.
enum BlendMode { ALPHA, ADDITIVE }
const MATERIAL_COMPATIBILITY_TAG := "MoldGpuPolyline"
const TEXTURE_WIDTH := 1024
const MAX_TEXELS := TEXTURE_WIDTH * 4096
const VERTEX_INCLUDE := "res://addons/mold/runtime/rendering/mold_gpu_polyline.gdshaderinc"
var _owner: WeakRef
var _node: MeshInstance3D
var _material := ShaderMaterial.new()
var _custom_material: ShaderMaterial
var _point_image: Image
var _point_texture: ImageTexture
var _segment_texture: ImageTexture
var _points := PackedFloat32Array()
var _paths: Array[MoldGpuPolylineRange] = []
var _style := MoldStyle.additive(Color.WHITE)
var _state := MoldRenderState.new()
var _disposed := false
var _material_dirty := true
var _visible := true
var _transform := Transform3D.IDENTITY
var _bounds := AABB()
var _manual_bounds := false
var _vertices_per_segment := 12
var _segment_count := 0
var _shaders: Dictionary = {}
var _join := MoldPolyline.Join.MITER
var _cap := MoldPolyline.Cap.BUTT
var _miter_limit := 4.0
var local_aa_quality := MoldWorldSettings.LocalAaQuality.HIGH
var is_valid: bool:
	get: return not _disposed and _owner != null and is_instance_valid(_owner.get_ref()) and _owner.get_ref()._is_available()
var point_count: int:
	get: return _points.size() / 8
var path_count: int:
	get: return _paths.size()
var segment_count: int:
	get: return _segment_count
var generated_vertex_count: int:
	get: return _segment_count * _vertices_per_segment
var local_bounds: AABB:
	get: return _bounds
var tint: Color:
	get: return _style.color
	set(value): _style.color = value
var join: int:
	get: return _join
	set(value):
		assert(value >= 0 and value <= MoldPolyline.Join.ROUND)
		_join = value
		_update_vertex_layout()
		_refresh_bounds()
var cap: int:
	get: return _cap
	set(value):
		assert(value >= 0 and value <= MoldPolyline.Cap.ROUND)
		_cap = value
		_update_vertex_layout()
		_refresh_bounds()
var miter_limit: float:
	get: return _miter_limit
	set(value):
		assert(is_finite(value) and value >= 1.0)
		_miter_limit = value
		_refresh_bounds()
var blend_mode: BlendMode:
	get: return BlendMode.ADDITIVE if _style.mode == MoldStyle.BlendMode.ADDITIVE else BlendMode.ALPHA
	set(value): configure(MoldStyle.additive(tint) if value == BlendMode.ADDITIVE else MoldStyle.transparent(tint), _state)

static func is_supported() -> bool:
	return DisplayServer.get_name() != "headless"

func _init(owner: Node3D, aa := MoldWorldSettings.LocalAaQuality.HIGH) -> void:
	_owner = weakref(owner)
	local_aa_quality = aa
	_node = MeshInstance3D.new()
	_node.name = "MoldGpuPolyline"
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	owner.add_child(_node, false, Node.INTERNAL_MODE_BACK)

static func is_material_compatible(material: ShaderMaterial) -> bool:
	return is_instance_valid(material) and is_instance_valid(material.shader) and bool(material.get_meta(MATERIAL_COMPATIBILITY_TAG, false))

func set_material(material: ShaderMaterial) -> void:
	assert(is_valid)
	assert(material == null or is_material_compatible(material), "GPU material must opt into the MoldGpuPolyline contract.")
	if _custom_material == material: return
	_custom_material = material
	_material_dirty = true

func configure(style: MoldStyle, render_state: MoldRenderState = null) -> void:
	assert(is_valid)
	assert(style.color_mode in [MoldStyle.ColorMode.SINGLE, MoldStyle.ColorMode.DUAL_GRADIENT])
	var state := render_state if render_state else MoldRenderState.new()
	_material_dirty = _material_dirty or _style.mode != style.mode or not _state.equals(state)
	_style = MoldStyle.new(style.mode,style.color,style.secondary_color,style.emission_strength,style.color_mode,style.color_interpolation,style.gradient_space,style.gradient_direction,style.custom_material)
	_state = state.duplicate_state()

func set_transform(value: Transform3D) -> void:
	assert(is_valid)
	_transform = value

func set_visible(value: bool) -> void:
	assert(is_valid)
	_visible = value

func set_polyline(polyline: MoldPolyline) -> void:
	assert(is_valid)
	var points := PackedFloat32Array()
	points.resize(polyline._points.size()*8)
	for i in polyline._points.size():
		var p := polyline._points[i]
		var o := i*8
		points[o] = p.position.x; points[o+1] = p.position.y; points[o+2] = p.position.z; points[o+3] = p.thickness*polyline.thickness
		points[o+4] = p.color.r; points[o+5] = p.color.g; points[o+6] = p.color.b; points[o+7] = p.color.a
	_join = polyline.join; _cap = polyline.cap; _miter_limit = polyline.miter_limit
	if _paths.size() == 1 and _paths[0].start_index == 0 and _paths[0].point_count == points.size()/8 and _paths[0].closed == polyline.closed:
		_update_vertex_layout()
		update_points(points)
	else:
		set_data(points, [MoldGpuPolylineRange.new(0, points.size()/8, polyline.closed)])

func set_data(points: PackedFloat32Array, paths: Array[MoldGpuPolylineRange]) -> void:
	assert(is_valid)
	assert(points.size()%8 == 0)
	for i in points.size(): assert(is_finite(points[i]), "GPU points must be finite.")
	for i in points.size()/8: assert(points[i*8+3] > 0.0, "Thickness must be positive.")
	var count := 0
	for path in paths:
		assert(path.start_index >= 0 and path.point_count >= (3 if path.closed else 2) and path.start_index <= points.size()/8-path.point_count, "Invalid GPU path range.")
		count += path.point_count if path.closed else path.point_count-1
	assert(points.size()/4 <= MAX_TEXELS and count*2 <= MAX_TEXELS, "Split large GPU streams into multiple streams.")
	var segments := PackedFloat32Array()
	segments.resize(_texture_float_count(count))
	var write := 0
	for path in paths:
		var end := path.start_index+path.point_count
		var n := path.point_count if path.closed else path.point_count-1
		var distance := 0.0
		var first_segment := write
		for s in n:
			var a := path.start_index+s
			var b := path.start_index if a+1 == end else a+1
			var length := Vector2(points[b*8]-points[a*8],points[b*8+1]-points[a*8+1]).length()
			var o := write*8
			write += 1
			segments[o] = (end-1 if path.closed else a) if s == 0 else a-1
			segments[o+1] = a; segments[o+2] = b
			segments[o+3] = (path.start_index if path.closed else b) if b+1 == end else b+1
			segments[o+4] = 0 if path.closed else (1 if s == 0 else 0)+(2 if s == n-1 else 0)
			segments[o+5] = distance; distance += length; segments[o+6] = distance
		for s in range(first_segment,write): segments[s*8+7] = maxf(distance,0.00001)
	_points = points
	_paths.clear()
	for path in paths: _paths.append(MoldGpuPolylineRange.new(path.start_index,path.point_count,path.closed))
	_segment_count = count
	_segment_texture = ImageTexture.create_from_image(Image.create_from_data(TEXTURE_WIDTH, segments.size()/(TEXTURE_WIDTH*4), false, Image.FORMAT_RGBAF, segments.to_byte_array()))
	_manual_bounds = false
	_upload_points()
	recalculate_bounds()
	_rebuild_mesh()

## Distance metrics retain SetData's rest lengths, matching Unity. Reuses texture dimensions.
func update_points(points: PackedFloat32Array, recalculate := true) -> void:
	assert(is_valid)
	assert(points.size() == _points.size(), "Point count changed; call set_data.")
	_points = points
	_upload_points()
	if recalculate: recalculate_bounds()

func copy_points() -> PackedFloat32Array:
	assert(is_valid)
	return _points.duplicate()

static func _texture_float_count(records: int) -> int:
	return TEXTURE_WIDTH*maxi(1,(records*2+TEXTURE_WIDTH-1)/TEXTURE_WIDTH)*4

func _upload_points() -> void:
	var data := _points.to_byte_array()
	data.resize(_texture_float_count(point_count)*4)
	var height := data.size()/(TEXTURE_WIDTH*16)
	if not _point_image or _point_image.get_height() != height:
		_point_image = Image.create_from_data(TEXTURE_WIDTH,height,false,Image.FORMAT_RGBAF,data)
		_point_texture = ImageTexture.create_from_image(_point_image)
	else:
		_point_image.set_data(TEXTURE_WIDTH,height,false,Image.FORMAT_RGBAF,data)
		_point_texture.update(_point_image)

func recalculate_bounds() -> void:
	assert(is_valid)
	_manual_bounds = false
	var minimum := Vector3(_points[0],_points[1],_points[2]) if point_count else Vector3.ZERO
	var maximum := minimum
	var radius := 0.0
	for i in point_count:
		var p := Vector3(_points[i*8],_points[i*8+1],_points[i*8+2])
		minimum = minimum.min(p); maximum = maximum.max(p)
		radius = maxf(radius,_points[i*8+3]*0.5)
	_bounds = AABB(minimum,maximum-minimum).grow(radius*maxf(2.0,_miter_limit)+0.25)
	_node.custom_aabb = _bounds

func set_local_bounds(bounds: AABB) -> void:
	assert(is_valid)
	assert(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.x >= 0 and bounds.size.y >= 0 and bounds.size.z >= 0)
	_bounds = bounds.grow(0.25)
	_manual_bounds = true
	_node.custom_aabb = _bounds

func _refresh_bounds() -> void:
	if not _manual_bounds: recalculate_bounds()

func _update_vertex_layout() -> void:
	var next := 12 if _join == MoldPolyline.Join.MITER and _cap != MoldPolyline.Cap.ROUND else 36
	if next == _vertices_per_segment: return
	_vertices_per_segment = next
	_rebuild_mesh()

func _rebuild_mesh() -> void:
	_vertices_per_segment = 12 if _join == MoldPolyline.Join.MITER and _cap != MoldPolyline.Cap.ROUND else 36
	_node.mesh = null
	if not segment_count: return
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	vertices.resize(generated_vertex_count)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.custom_aabb = _bounds
	_node.mesh = mesh

static func shader_source(mode: int, state: MoldRenderState) -> String:
	var source := MoldShader.source(mode,state,false,mode == MoldStyle.BlendMode.OPAQUE)
	source = source.replace("CUSTOM0","gpu_custom0").replace("CUSTOM1","gpu_custom1").replace("CUSTOM2","gpu_custom2")
	return source.replace("void vertex() {", '#include "'+VERTEX_INCLUDE+'"\nvoid vertex() {\nvec4 gpu_custom0, gpu_custom1, gpu_custom2;\nmold_gpu_vertex(VERTEX_ID, VERTEX, COLOR, UV, gpu_custom0, gpu_custom1, gpu_custom2);\nNORMAL=vec3(0.0,0.0,1.0);')

func _sync() -> void:
	if _disposed: return
	if _material_dirty:
		_material = _custom_material.duplicate() if _custom_material else ShaderMaterial.new()
		if not _custom_material:
			var key := str(_style.mode)+":"+str(_state.shader_key(_style.mode))
			if not _shaders.has(key):
				var shader := Shader.new()
				shader.code = shader_source(_style.mode,_state)
				_shaders[key] = shader
			_material.shader = _shaders[key]
		_node.material_override = _material
		_material_dirty = false
	_node.visible = _visible and segment_count > 0
	_node.transform = _transform
	_node.layers = _state.render_layer_mask
	_material.render_priority = clampi(_state.sorting_order,-128,127)
	_material.set_shader_parameter("primary_color",MoldMultiMeshRenderer.pack_color_vector(_style.color,_style.color_mode,_style.color_interpolation))
	_material.set_shader_parameter("secondary_color",MoldMultiMeshRenderer.pack_color_vector(_style.secondary_color,_style.color_mode,_style.color_interpolation))
	_material.set_shader_parameter("emission_strength",_style.emission_strength)
	var d := _style.gradient_direction
	_material.set_shader_parameter("gradient_data",Vector4(d.x,d.y,d.z,_style.color_mode+8*_style.color_interpolation+16*_style.gradient_space))
	var aa := 0 if local_aa_quality == 0 else (1 if local_aa_quality == 1 else 33)
	_material.set_shader_parameter("mold_flags",Vector4(_style.emission_strength,0,0,aa+12))
	_material.set_shader_parameter("mold_gpu_points",_point_texture)
	_material.set_shader_parameter("mold_gpu_segments",_segment_texture)
	_material.set_shader_parameter("mold_gpu_vertices_per_segment",_vertices_per_segment)
	_material.set_shader_parameter("mold_gpu_join",_join)
	_material.set_shader_parameter("mold_gpu_cap",_cap)
	_material.set_shader_parameter("mold_gpu_miter_limit",_miter_limit)
	var viewport: Viewport = _owner.get_ref().get_viewport()
	_material.set_shader_parameter("mold_viewport_size",viewport.get_visible_rect().size)
	_material.set_shader_parameter("mold_msaa_enabled",viewport.msaa_3d != Viewport.MSAA_DISABLED)

func dispose() -> void:
	if _disposed: return
	var owner: Node = _owner.get_ref()
	if is_instance_valid(owner): owner.release_gpu_polyline_renderer(self)
	else: _dispose_from_world()

func _dispose_from_world() -> void:
	if _disposed: return
	_disposed = true
	_node.mesh = null
	_node.material_override = null
	_node.queue_free()
	_point_image = null; _point_texture = null; _segment_texture = null; _material = null; _custom_material = null
	_shaders.clear(); _points = PackedFloat32Array(); _paths.clear()
