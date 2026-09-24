class_name MoldDash
extends RefCounted

## A repeating pattern for lines and 2D rims. new() defines the normalized
## count/percentage form; sized() defines exact local-space dash and gap lengths.

enum Type { NORMAL, CHEVRON, ROUNDED }

const _TYPE_CODE_START := 0.1
const _TYPE_CODE_STEP := 0.3
const _MODIFIER_CODE_SCALE := 0.075

var fill_count: int
var total_count: int
var spacing: float
var offset: float
var type: Type
var modifier: float
var length := 0.0
var uses_fixed_size := false

var is_enabled: bool:
	get: return length > 0.0 if uses_fixed_size else total_count > 0


func _init(
	fill: int = 0,
	total: int = 0,
	dash_spacing: float = 0.1,
	dash_offset: float = 0.0,
	dash_type: Type = Type.NORMAL,
	dash_modifier: float = 0.0,
) -> void:
	if total < 0 or fill < 0 or fill > total:
		push_error("MoldDash counts must satisfy 0 <= fill_count <= total_count.")
		total = 0
		fill = 0
	fill_count = fill
	total_count = total
	spacing = clampf(dash_spacing if is_finite(dash_spacing) else 0.1, 0.0, 1.0)
	offset = dash_offset if is_finite(dash_offset) else 0.0
	type = dash_type if dash_type >= Type.NORMAL and dash_type <= Type.ROUNDED else Type.NORMAL
	modifier = clampf(dash_modifier if is_finite(dash_modifier) else 0.0, -1.0, 1.0)


static func corner(side_count: int) -> MoldDash:
	var count := maxi(side_count, 1)
	return MoldDash.new(count, count, 0.5, 0.25)


static func edge(side_count: int) -> MoldDash:
	var count := maxi(side_count, 1)
	return MoldDash.new(count, count, 0.5, -0.25)


## Creates a fully repeating pattern with exact local-space dash and gap lengths.
## Offset uses the same local-space units.
static func sized(dash_length: float, dash_spacing: float, dash_offset := 0.0) -> MoldDash:
	assert(is_finite(dash_length) and dash_length > 0.0, "Dash length must be positive and finite.")
	assert(is_finite(dash_spacing) and dash_spacing >= 0.0, "Dash spacing must be non-negative and finite.")
	assert(is_finite(dash_offset), "Dash offset must be finite.")
	var result := MoldDash.new()
	result.length = dash_length
	result.spacing = dash_spacing
	result.offset = dash_offset
	result.uses_fixed_size = true
	return result


func duplicate_dash() -> MoldDash:
	if uses_fixed_size:
		return MoldDash.sized(length, spacing, offset)
	return MoldDash.new(fill_count, total_count, spacing, offset, type, modifier)


func equals(other: MoldDash) -> bool:
	return other != null and fill_count == other.fill_count and total_count == other.total_count \
		and spacing == other.spacing and offset == other.offset and type == other.type \
		and modifier == other.modifier and length == other.length \
		and uses_fixed_size == other.uses_fixed_size


func to_gpu_data(path_length := 1.0) -> Vector4:
	if not is_enabled:
		return Vector4.ZERO
	if uses_fixed_size:
		if not is_finite(path_length) or path_length <= 0.0:
			return Vector4.ZERO
		return Vector4(-path_length, length, spacing, offset)
	var total := maxi(total_count, 1)
	var type_code := _TYPE_CODE_START + _TYPE_CODE_STEP * type + _MODIFIER_CODE_SCALE * modifier
	return Vector4(clampi(fill_count, 0, total), total + type_code, spacing, offset)
