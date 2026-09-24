@tool
class_name MoldStyleResource
extends Resource

@export var mode: MoldStyle.BlendMode = MoldStyle.BlendMode.OPAQUE:
	set(value):
		if mode == value: return
		mode = value
		notify_property_list_changed()
		emit_changed()
@export var color := Color.WHITE:
	set(value):
		if color == value: return
		color = value
		emit_changed()
@export var custom_material: ShaderMaterial:
	set(value):
		if custom_material == value: return
		custom_material = value
		emit_changed()
@export var secondary_color := Color.WHITE:
	set(value):
		if secondary_color == value: return
		secondary_color = value
		emit_changed()
@export var color_mode: MoldStyle.ColorMode = MoldStyle.ColorMode.SINGLE:
	set(value):
		if color_mode == value: return
		color_mode = value
		notify_property_list_changed()
		emit_changed()
@export var color_interpolation: MoldStyle.ColorInterpolation = MoldStyle.ColorInterpolation.LINEAR_RGB:
	set(value):
		if color_interpolation == value: return
		color_interpolation = value
		emit_changed()
@export var gradient_space: MoldStyle.GradientSpace = MoldStyle.GradientSpace.WORLD:
	set(value):
		if gradient_space == value: return
		gradient_space = value
		emit_changed()
@export var gradient_direction := Vector3.UP:
	set(value):
		if gradient_direction == value: return
		gradient_direction = value
		emit_changed()
@export_range(0.0, 16.0, 0.01, "or_greater") var emission_strength := 0.0:
	set(value):
		var next := maxf(value, 0.0) if is_finite(value) else 0.0
		if is_equal_approx(emission_strength, next): return
		emission_strength = next
		emit_changed()


func to_style(material_handle: MoldMaterialHandle = null) -> MoldStyle:
	if mode == MoldStyle.BlendMode.CUSTOM: return MoldStyle.custom(material_handle, color)
	if color_mode == MoldStyle.ColorMode.DUAL_RADIAL: return MoldStyle.dual_radial(color, secondary_color, mode, color_interpolation, emission_strength)
	if color_mode == MoldStyle.ColorMode.DUAL_RADIAL_BOUNDS: return MoldStyle.dual_radial_bounds(color, secondary_color, mode, color_interpolation, emission_strength)
	if color_mode == MoldStyle.ColorMode.DUAL_ANGULAR: return MoldStyle.dual_angular(color, secondary_color, mode, color_interpolation, emission_strength)
	if color_mode == MoldStyle.ColorMode.DUAL_GRADIENT: return MoldStyle.dual_gradient(color, secondary_color, gradient_direction, gradient_space, mode, color_interpolation, emission_strength)
	match mode:
		MoldStyle.BlendMode.TRANSPARENT: return MoldStyle.transparent(color)
		MoldStyle.BlendMode.ADDITIVE: return MoldStyle.additive(color)
		MoldStyle.BlendMode.MULTIPLICATIVE: return MoldStyle.multiplicative(color)
		MoldStyle.BlendMode.DITHER: return MoldStyle.dither(color)
		MoldStyle.BlendMode.SUBTRACTIVE: return MoldStyle.subtractive(color)
		MoldStyle.BlendMode.LINEAR_BURN: return MoldStyle.linear_burn(color)
		MoldStyle.BlendMode.SCREEN: return MoldStyle.screen(color)
		MoldStyle.BlendMode.LIGHTEN: return MoldStyle.lighten(color)
		MoldStyle.BlendMode.DARKEN: return MoldStyle.darken(color)
		MoldStyle.BlendMode.COLOR_DODGE: return MoldStyle.color_dodge(color)
		MoldStyle.BlendMode.COLOR_BURN: return MoldStyle.color_burn(color)
	return MoldStyle.opaque(color)


func _validate_property(property: Dictionary) -> void:
	var property_name: String = property.name
	var visible := true
	if property_name == "custom_material": visible = mode == MoldStyle.BlendMode.CUSTOM
	elif property_name == "color_mode": visible = mode != MoldStyle.BlendMode.CUSTOM
	elif property_name in ["secondary_color", "color_interpolation", "emission_strength"]: visible = mode != MoldStyle.BlendMode.CUSTOM and color_mode != MoldStyle.ColorMode.SINGLE
	elif property_name in ["gradient_space", "gradient_direction"]: visible = mode != MoldStyle.BlendMode.CUSTOM and color_mode == MoldStyle.ColorMode.DUAL_GRADIENT
	if not visible: property.usage &= ~PROPERTY_USAGE_EDITOR
