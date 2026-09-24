class_name MoldImmediate
extends RefCounted

var world
var position := Vector3.ZERO
var rotation := Quaternion.IDENTITY
var scale := Vector3.ONE
var style := MoldStyle.opaque(Color.WHITE)
var render_state := MoldRenderState.new()
var thickness := 0.05
var dash := MoldDash.new()
var _states: Array[Dictionary] = []
var _ended := false
var _generation := 0


func _init(value_world, generation: int) -> void:
	world = value_world
	_generation = generation


func push_state() -> void: _states.append(_capture_state())


func pop_state() -> void:
	if _states.is_empty():
		push_error("MoldImmediate state stack is empty.")
		return
	_restore_state(_states.pop_back())


func with_state(callback: Callable) -> void:
	push_state()
	callback.call()
	pop_state()


func shape(value: MoldShape, local_position: Vector3 = Vector3.ZERO, local_rotation: Quaternion = Quaternion.IDENTITY, local_scale: Vector3 = Vector3.ONE) -> void:
	if not _require_active(): return
	if dash.is_enabled and value.supports_dashes:
		value = value.with_dash(dash)
	world._record_immediate(_generation, value, position + rotation * (local_position * scale), rotation * local_rotation, local_scale * scale, style, render_state)


func line(start: Vector3, end: Vector3) -> void:
	shape(MoldShape.line_2d(start, end, maxf(thickness, 0.0001)))


func polyline(value: MoldPolyline, local_position: Vector3 = Vector3.ZERO, local_rotation: Quaternion = Quaternion.IDENTITY, local_scale: Vector3 = Vector3.ONE) -> void:
	if not _require_active() or not value: return
	world._record_immediate_polyline(_generation, value, position + rotation * (local_position * scale), rotation * local_rotation, local_scale * scale, style, render_state)


func end() -> void:
	if _ended: return
	_states.clear()
	_ended = true


func _require_active() -> bool:
	if not _ended: return true
	push_error("This MoldImmediate frame has already ended.")
	return false


func _capture_state() -> Dictionary:
	return {"position": position, "rotation": rotation, "scale": scale, "style": style.duplicate_style(), "render_state": render_state.duplicate_state(), "thickness": thickness, "dash": dash.duplicate_dash()}


func _restore_state(state: Dictionary) -> void:
	position = state.position; rotation = state.rotation; scale = state.scale
	style = state.style; render_state = state.render_state; thickness = state.thickness; dash = state.dash
