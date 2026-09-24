@tool
extends Node3D

var _drawers: Array = []
var _world: MoldRuntimeInstance
var _dirty := true
var _had_active_drawer := false
var _camera_snapshot: Array = []


func _ready() -> void:
	process_priority = 900
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Scene-view previews use the detail requested by each immediate command.
	# Runtime drawers retain Mold's screen-space continuous LOD.
	var settings: MoldWorldSettings
	if Engine.is_editor_hint():
		settings = MoldWorldSettings.new()
		settings.lod_mode = MoldWorldSettings.LodMode.MANUAL
	_world = MoldRuntime.create_attached_instance(self, settings)


func _process(_delta: float) -> void:
	_remove_invalid_drawers()
	if _drawers.is_empty() or not _world: return
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport else null
	var snapshot := []
	if camera:
		snapshot = [camera.global_transform, camera.projection, camera.fov,
			camera.size, camera.cull_mask, viewport.get_visible_rect().size]
	var camera_changed := snapshot != _camera_snapshot
	_camera_snapshot = snapshot
	var has_active_drawer := false
	var continuous := false
	for drawer in _drawers:
		if not drawer._mold_should_draw(camera): continue
		has_active_drawer = true
		continuous = continuous or drawer.continuously_redraw
	var activity_changed := has_active_drawer != _had_active_drawer
	_had_active_drawer = has_active_drawer
	if Engine.is_editor_hint() and not _dirty and not camera_changed and not continuous and not activity_changed: return
	if not Engine.is_editor_hint() and not has_active_drawer and not _dirty: return
	_dirty = false
	_world.draw(func(draw: MoldImmediate) -> void:
		for drawer in _drawers:
			if drawer._mold_should_draw(camera):
				draw.with_state(func() -> void: drawer.draw_molds(draw, camera))
	)


func register(drawer: Node) -> void:
	if drawer not in _drawers: _drawers.append(drawer)
	_dirty = true


func unregister(drawer: Node) -> void:
	_drawers.erase(drawer)
	_dirty = true


func request_redraw() -> void:
	_dirty = true


func drawer_count() -> int:
	return _drawers.size()


func shutdown() -> void:
	set_process(false)
	_drawers.clear()
	if _world: _world.dispose()
	_world = null
	if is_inside_tree(): queue_free.call_deferred()


func _remove_invalid_drawers() -> void:
	for index in range(_drawers.size() - 1, -1, -1):
		if not is_instance_valid(_drawers[index]) or not _drawers[index].is_inside_tree():
			_drawers.remove_at(index)
