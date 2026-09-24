@tool
extends EditorPlugin

const MoldGizmoPlugin = preload("res://addons/mold/editor/mold_gizmo_plugin.gd")
var _gizmo_plugin: EditorNode3DGizmoPlugin
var _hdr_color_inspector_plugin: EditorInspectorPlugin


class MoldHdrColorProperty extends EditorProperty:
	var _picker := ColorPickerButton.new()
	var _color_before_popup := Color.WHITE
	var _updating := false

	func _init() -> void:
		_picker.edit_alpha = true
		_picker.edit_intensity = true
		_picker.flat = true
		_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(_picker)
		add_focusable(_picker)
		_picker.color_changed.connect(_on_color_changed)
		_picker.picker_created.connect(_on_picker_created)
		_picker.popup_closed.connect(_on_popup_closed)

	func _update_property() -> void:
		_updating = true
		_picker.color = get_edited_object().get(get_edited_property())
		_updating = false

	func _set_read_only(read_only: bool) -> void:
		_picker.disabled = read_only

	func _on_picker_created() -> void:
		_picker.get_popup().about_to_popup.connect(_on_popup_opening)
		_picker.get_picker().edit_intensity = true

	func _on_popup_opening() -> void:
		_color_before_popup = _picker.color

	func _on_color_changed(color: Color) -> void:
		if not _updating: get_edited_object().set(get_edited_property(), color)

	func _on_popup_closed() -> void:
		var color := _picker.color
		if color.is_equal_approx(_color_before_popup): return
		get_edited_object().set(get_edited_property(), _color_before_popup)
		emit_changed(get_edited_property(), color)


class MoldHdrColorInspectorPlugin extends EditorInspectorPlugin:
	func _can_handle(object: Object) -> bool:
		return object is MoldStyleResource or object is MoldPolylinePointResource

	func _parse_property(object: Object, type: Variant.Type, name: String,
			_hint_type: PropertyHint, _hint_string: String, _usage_flags: int,
			_wide: bool) -> bool:
		if type != TYPE_COLOR: return false
		var is_style_color := object is MoldStyleResource \
			and name in [&"color", &"secondary_color"]
		var is_point_color := object is MoldPolylinePointResource and name == &"color"
		if not is_style_color and not is_point_color: return false
		add_property_editor(name, MoldHdrColorProperty.new())
		return true

func _enter_tree() -> void:
	_gizmo_plugin = MoldGizmoPlugin.new()
	add_node_3d_gizmo_plugin(_gizmo_plugin)
	_hdr_color_inspector_plugin = MoldHdrColorInspectorPlugin.new()
	add_inspector_plugin(_hdr_color_inspector_plugin)


func _exit_tree() -> void:
	if _hdr_color_inspector_plugin:
		remove_inspector_plugin(_hdr_color_inspector_plugin)
		_hdr_color_inspector_plugin = null
	if _gizmo_plugin:
		remove_node_3d_gizmo_plugin(_gizmo_plugin)
		_gizmo_plugin = null
