class_name MoldMultiMeshRenderer
extends RefCounted

const DATA_TEXELS_PER_INSTANCE := 7
const DATA_TEXTURE_WIDTH := 1024
const CULLING_EXTENT := 1000000.0

class BatchState:
	extends RefCounted
	var native_nodes: Array[MeshInstance3D] = []
	var native_mode := false
	var native_visible_count := 0
	var node: MultiMeshInstance3D
	var multimesh: MultiMesh
	var material: ShaderMaterial
	var data_image: Image
	var data_texture: ImageTexture
	var transform_buffer := PackedFloat32Array()
	var property_buffer := PackedByteArray()
	var capacity := 0
	var visible_count := -1
	var transform_revision := 0
	var property_revision := 0
	var viewport_size := Vector2.ZERO
	var msaa_enabled := false

var _viewport_size := Vector2.ZERO
var _viewport_changed := false
var _msaa_enabled := false
var _world
var _settings: MoldWorldSettings
var _states: Dictionary = {}
var _shaders: Dictionary = {}


func _init(world, settings: MoldWorldSettings) -> void:
	_world = world
	_settings = settings


func sync(batches: Array[MoldBatch], retired_batches: Array[MoldBatch]) -> void:
	var size: Vector2 = _world.get_viewport().get_visible_rect().size
	var msaa_enabled: bool = _world.get_viewport().msaa_3d != Viewport.MSAA_DISABLED
	_viewport_changed = size != _viewport_size or msaa_enabled != _msaa_enabled
	_msaa_enabled = msaa_enabled
	_viewport_size = size
	for batch in retired_batches:
		_remove(batch)
		batches.erase(batch)
	for batch in batches:
		var native: bool = _settings.transparent_ordering_mode == MoldWorldSettings.TransparentOrderingMode.NATIVE_COMPATIBLE and batch.mode not in [MoldStyle.BlendMode.OPAQUE, MoldStyle.BlendMode.DITHER, MoldStyle.BlendMode.CUSTOM]
		var changed: bool = _states.has(batch) and _states[batch].native_mode != native
		if batch.transform_pending or batch.property_pending or _viewport_changed or changed:
			_sync(batch, native)


func _sync(batch: MoldBatch, native: bool) -> void:
	var count := batch.count()
	var state: BatchState = _states.get(batch)
	if not state:
		if count == 0:
			batch.acknowledge_changes()
			return
		state = _create(batch)
		_states[batch] = state
	if state.native_mode != native:
		state.native_mode = native
		state.transform_revision = -1
		state.property_revision = -1
	state.node.visible = not native
	if not native or count == 0:
		for i in state.native_visible_count: state.native_nodes[i].visible = false
		state.native_visible_count = 0
	if count == 0:
		if state.visible_count != 0: state.multimesh.visible_instance_count = 0
		state.visible_count = 0
		batch.acknowledge_changes()
		return
	if native:
		_batch_aabb(batch)
		while state.native_nodes.size() < count:
			var node := MeshInstance3D.new()
			node.name = "Mold Native Shape"
			node.mesh = batch.mesh
			# Material uniforms avoid the finite global instance-uniform buffer.
			node.material_override = state.material.duplicate()
			node.material_override.set_shader_parameter("mold_instance_index", state.native_nodes.size())
			node.layers = batch.render_state.render_layer_mask
			node.sorting_use_aabb_center = true
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_world.add_child(node, false, Node.INTERNAL_MODE_BACK)
			state.native_nodes.append(node)
		for i in range(state.native_visible_count, count): state.native_nodes[i].visible = true
		for i in range(count, state.native_visible_count): state.native_nodes[i].visible = false
		state.native_visible_count = count
		for i in count:
			var node := state.native_nodes[i]
			var transform := batch.transform_at(i)
			if node.transform != transform: node.transform = transform
			var bounds: AABB = batch.immediate_bounds[i] if batch.is_immediate else batch.relative_bounds[i]
			if batch.is_immediate: bounds.position -= transform.origin
			var local_bounds := (Transform3D(transform.basis.inverse(), Vector3.ZERO) * bounds).grow(_settings.culling_bounds_padding) if absf(transform.basis.determinant()) > 0.000001 else AABB(Vector3.ZERO, Vector3.ONE * 0.001)
			if node.custom_aabb != local_bounds: node.custom_aabb = local_bounds
	_sync_batch(batch, state, count)


func dispose() -> void:
	for key in _states:
		var state: BatchState = _states[key]
		for node in state.native_nodes: node.free()
		if is_instance_valid(state.node): state.node.free()
	_states.clear()
	_shaders.clear()


func _create(batch: MoldBatch) -> BatchState:
	var material: ShaderMaterial
	if batch.mode == MoldStyle.BlendMode.CUSTOM:
		if not is_instance_valid(batch.custom_material):
			push_error("A custom Mold batch lost its registered ShaderMaterial.")
			material = ShaderMaterial.new()
		else:
			material = batch.custom_material.duplicate() as ShaderMaterial
	else:
		var coverage_output := batch.coverage_output
		var shader_key := batch.render_state.shader_key(batch.mode) | (int(coverage_output) << 24)
		var shader: Shader = _shaders.get(shader_key)
		if not shader:
			shader = Shader.new()
			shader.code = MoldShader.source(batch.mode, batch.render_state, true, coverage_output)
			_shaders[shader_key] = shader
		material = ShaderMaterial.new()
		material.shader = shader
	material.render_priority = clampi(batch.render_state.sorting_order, -128, 127)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = batch.mesh
	multimesh.custom_aabb = _unculled_aabb()
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.material_override = material
	node.layers = batch.render_state.render_layer_mask
	_world.add_child(node, false, Node.INTERNAL_MODE_BACK)
	var state := BatchState.new()
	state.node = node
	state.multimesh = multimesh
	state.material = material
	return state


func _set_batch_parameter(state: BatchState, name: StringName, value: Variant) -> void:
	state.material.set_shader_parameter(name, value)
	for node in state.native_nodes:
		node.material_override.set_shader_parameter(name, value)


func _sync_batch(batch: MoldBatch, state: BatchState, count: int) -> void:
	if _viewport_size != state.viewport_size or _msaa_enabled != state.msaa_enabled:
		_set_batch_parameter(state, "mold_viewport_size", _viewport_size)
		state.viewport_size = _viewport_size
		_set_batch_parameter(state, "mold_msaa_enabled", _msaa_enabled)
		state.msaa_enabled = _msaa_enabled
	var required_capacity := _next_power_of_two(count)
	var resized := state.capacity < required_capacity
	if resized:
		state.multimesh.instance_count = 0
		state.multimesh.instance_count = required_capacity
		state.capacity = required_capacity
		state.transform_revision = 0
		state.property_revision = 0
	if state.visible_count != count:
		state.multimesh.visible_instance_count = count
		state.visible_count = count
	if state.transform_revision != batch.transform_revision:
		_sync_transforms(batch, state)
		state.transform_revision = batch.transform_revision
	if state.property_revision != batch.property_revision:
		_sync_properties(batch, state)
		state.property_revision = batch.property_revision
	batch.acknowledge_changes()


func _sync_transforms(batch: MoldBatch, state: BatchState) -> void:
	var required := state.capacity * 12
	# Store the native MultiMesh layout directly; translation writes only three floats.
	state.transform_buffer = batch.transform_buffer if batch.transform_buffer.size() == required else batch.transform_buffer.slice(0, required)
	var upload_start: int = _world.performance_metrics.begin_upload()
	if not state.native_mode: RenderingServer.multimesh_set_buffer(state.multimesh.get_rid(), state.transform_buffer)
	_world.performance_metrics.end_upload(upload_start, 0 if state.native_mode else required * 4)
	state.multimesh.custom_aabb = _unculled_aabb() if _settings.culling_mode == MoldWorldSettings.CullingMode.NONE else _batch_aabb(batch)


static func _unculled_aabb() -> AABB:
	return AABB(Vector3.ONE * -CULLING_EXTENT, Vector3.ONE * CULLING_EXTENT * 2.0)



func _batch_aabb(batch: MoldBatch) -> AABB:
	var count := batch.count()
	if count == 0: return AABB(Vector3.ZERO, Vector3.ONE * 0.001)
	var block_count := (count + MoldBatch.BOUNDS_BLOCK_SIZE - 1) / MoldBatch.BOUNDS_BLOCK_SIZE
	var result := AABB()
	for block in block_count:
		if batch.bounds_dirty[block] != 0:
			var first := block * MoldBatch.BOUNDS_BLOCK_SIZE
			batch.bounds_blocks[block] = _uncached_block_aabb(batch, first, mini(first + MoldBatch.BOUNDS_BLOCK_SIZE, count)) if batch.full_bounds_rebuild else _block_aabb(batch, first, mini(first + MoldBatch.BOUNDS_BLOCK_SIZE, count))
			batch.bounds_dirty[block] = 0
		result = batch.bounds_blocks[block] if block == 0 else result.merge(batch.bounds_blocks[block])
	batch.full_bounds_rebuild = false
	var padding := _settings.culling_bounds_padding
	if padding > 0.0:
		result.position -= Vector3.ONE * padding
		result.size += Vector3.ONE * padding * 2.0
	return result


func _block_aabb(batch: MoldBatch, first: int, end: int) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var transforms := batch.transform_buffer
	for index in range(first, end):
		var transformed: AABB
		if batch.is_immediate:
			transformed = batch.immediate_bounds[index]
		else:
			if batch.bounds_valid[index] == 0:
				var slot: int = batch.slots[index]
				var transform := batch.transform_at(index)
				transform.origin = Vector3.ZERO
				var polyline: MoldPolyline = _world._polylines[slot]
				if polyline:
					batch.relative_bounds[index] = _transform_aabb(polyline.bounds, transform)
				else:
					var shape: MoldShape = _world._shapes[slot]
					batch.relative_bounds[index] = _instance_aabb(shape, _local_aabb(shape, batch.custom_data_at(index)), transform)
				batch.bounds_valid[index] = 1
			transformed = batch.relative_bounds[index]
			var offset := index * MoldBatch.TRANSFORM_FLOATS_PER_INSTANCE
			transformed.position += Vector3(transforms[offset + 3], transforms[offset + 7], transforms[offset + 11])
		minimum = minimum.min(transformed.position)
		maximum = maximum.max(transformed.end)
	return AABB(minimum, maximum - minimum)


static func _instance_aabb(shape: MoldShape, local: AABB, transform: Transform3D) -> AABB:
	if shape.is_line and shape.billboard_mode == MoldShape.BillboardMode.FACE_CAMERA:
		var half_tangent := transform.basis.x * 0.5
		var first := transform.origin - half_tangent
		var second := transform.origin + half_tangent
		var half_width := transform.basis.y.length() * 0.5
		var minimum := Vector3(
			minf(first.x, second.x),
			minf(first.y, second.y),
			minf(first.z, second.z)) - Vector3.ONE * half_width
		var maximum := Vector3(
			maxf(first.x, second.x),
			maxf(first.y, second.y),
			maxf(first.z, second.z)) + Vector3.ONE * half_width
		return AABB(minimum, maximum - minimum)
	return _transform_aabb(local, transform)


static func immediate_aabb(shape: MoldShape, custom: Vector4, transform: Transform3D) -> AABB:
	return _instance_aabb(shape, _local_aabb(shape, custom), transform)


static func immediate_polyline_aabb(polyline: MoldPolyline, transform: Transform3D) -> AABB:
	return _transform_aabb(polyline.bounds, transform)


static func _local_aabb(shape: MoldShape, custom: Vector4) -> AABB:
	if shape.billboard_mode != MoldShape.BillboardMode.DISABLED:
		var radius := sqrt(0.5)
		return AABB(Vector3.ONE * -radius, Vector3.ONE * radius * 2.0)
	if shape.kind == MoldShape.Kind.CAPSULE:
		var half_height := 0.5 + custom.y
		return AABB(Vector3(-0.5, -half_height, -0.5), Vector3(1.0, half_height * 2.0, 1.0))
	if shape.kind == MoldShape.Kind.TORUS:
		return AABB(Vector3(-0.5, -custom.y, -0.5), Vector3(1.0, custom.y * 2.0, 1.0))
	if shape.kind == MoldShape.Kind.HEMISPHERE:
		return AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 0.5, 1.0))
	if shape.is_2d:
		return AABB(Vector3(-0.5, -0.5, -0.01), Vector3(1.0, 1.0, 0.02))
	return AABB(Vector3.ONE * -0.5, Vector3.ONE)


static func _transform_aabb(source: AABB, transform: Transform3D) -> AABB:
	return transform * source


func _sync_properties(batch: MoldBatch, state: BatchState) -> void:
	var texel_count := state.capacity * DATA_TEXELS_PER_INSTANCE
	var height := maxi(1, ceili(float(texel_count) / DATA_TEXTURE_WIDTH))
	var byte_count := DATA_TEXTURE_WIDTH * height * 16
	var active_texel_count := batch.count() * DATA_TEXELS_PER_INSTANCE
	state.property_buffer = batch.property_texels.slice(0, active_texel_count).to_byte_array()
	state.property_buffer.resize(byte_count)
	var upload_start: int = _world.performance_metrics.begin_upload()
	if not state.data_image or state.data_image.get_height() != height:
		state.data_image = Image.create_from_data(DATA_TEXTURE_WIDTH, height, false, Image.FORMAT_RGBAF, state.property_buffer)
		state.data_texture = ImageTexture.create_from_image(state.data_image)
		_set_batch_parameter(state, "mold_instance_data", state.data_texture)
	else:
		state.data_image.set_data(DATA_TEXTURE_WIDTH, height, false, Image.FORMAT_RGBAF, state.property_buffer)
		state.data_texture.update(state.data_image)
	_world.performance_metrics.end_upload(upload_start, byte_count)


static func instance_texture_color(value: Color) -> Color:
	var linear := value.srgb_to_linear()
	linear.a = value.a
	return linear


static func pack_color(value: Color, color_mode: MoldStyle.ColorMode, interpolation: MoldStyle.ColorInterpolation) -> Color:
	var linear := instance_texture_color(value)
	if color_mode == MoldStyle.ColorMode.SINGLE or interpolation == MoldStyle.ColorInterpolation.LINEAR_RGB:
		return linear
	var l := _signed_cbrt(0.4122214708 * linear.r + 0.5363325363 * linear.g + 0.0514459929 * linear.b)
	var m := _signed_cbrt(0.2119034982 * linear.r + 0.6806995451 * linear.g + 0.1073969566 * linear.b)
	var s := _signed_cbrt(0.0883024619 * linear.r + 0.2817188376 * linear.g + 0.6299787005 * linear.b)
	return Color(
		0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
		linear.a,
	)


static func pack_color_vector(value: Color, color_mode: MoldStyle.ColorMode, interpolation: MoldStyle.ColorInterpolation) -> Vector4:
	var packed := pack_color(value, color_mode, interpolation)
	return Vector4(packed.r, packed.g, packed.b, packed.a)


static func create_single_instance_texture(primary_color: Color, shape_data: Vector4,
		dash_data: Vector4, flags: Vector4, gradient_data: Vector4,
		lod_data := Vector4(1.0, 0.0, 0.0, 0.0)) -> ImageTexture:
	var primary := instance_texture_color(primary_color)
	var texels := PackedVector4Array([
		Vector4(primary.r, primary.g, primary.b, primary.a),
		Vector4.ZERO,
		shape_data,
		dash_data,
		flags,
		gradient_data,
		lod_data,
	])
	var bytes := texels.to_byte_array()
	bytes.resize(DATA_TEXTURE_WIDTH * 16)
	var image := Image.create_from_data(DATA_TEXTURE_WIDTH, 1, false, Image.FORMAT_RGBAF, bytes)
	return ImageTexture.create_from_image(image)


static func _signed_cbrt(value: float) -> float:
	return signf(value) * pow(absf(value), 1.0 / 3.0)


func _remove(batch: MoldBatch) -> void:
	var state: BatchState = _states.get(batch)
	if not state: return
	_states.erase(batch)
	for node in state.native_nodes:
		node.visible = false
		node.queue_free()
	if is_instance_valid(state.node): state.node.queue_free()


static func _next_power_of_two(value: int) -> int:
	var result := 1
	while result < value: result <<= 1
	return result


# Dense TRS changes invalidate every relative cache each frame. Compute their
# bounds directly; populate relative caches lazily when translation-only updates resume.
func _uncached_block_aabb(batch: MoldBatch, first: int, end: int) -> AABB:
	var result := AABB()
	for index in range(first, end):
		var slot: int = batch.slots[index]
		var polyline: MoldPolyline = _world._polylines[slot]
		var transform := batch.transform_at(index)
		var bounds: AABB
		if polyline:
			bounds = _transform_aabb(polyline.bounds, transform)
		else:
			var shape: MoldShape = _world._shapes[slot]
			bounds = _instance_aabb(shape, _local_aabb(shape, batch.custom_data_at(index)), transform)
		result = bounds if index == first else result.merge(bounds)
	return result
