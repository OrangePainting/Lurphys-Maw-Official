extends Node3D

const COUNT_PRESETS: Array[int] = [64, 256, 1024, 4096]
const SHAPE_NAMES: Array[String] = [
	"Sphere",
	"Cylinder",
	"Cone",
	"Capsule",
	"Torus",
	"Rounded cuboid",
	"Rounded prism",
	"Hemisphere",
]
const DETAIL_NAMES: Array[String] = ["Minimal", "Low", "Medium", "High", "Extreme"]
const BLEND_MODE_NAMES: Array[String] = [
	"Opaque",
	"Transparent",
	"Additive",
	"Multiplicative",
	"Dither",
	"Subtractive",
	"Linear burn",
	"Screen",
	"Lighten",
	"Darken",
	"Color dodge",
	"Color burn",
]
const BLEND_MODES: Array[int] = [
	MoldStyle.BlendMode.OPAQUE,
	MoldStyle.BlendMode.TRANSPARENT,
	MoldStyle.BlendMode.ADDITIVE,
	MoldStyle.BlendMode.MULTIPLICATIVE,
	MoldStyle.BlendMode.DITHER,
	MoldStyle.BlendMode.SUBTRACTIVE,
	MoldStyle.BlendMode.LINEAR_BURN,
	MoldStyle.BlendMode.SCREEN,
	MoldStyle.BlendMode.LIGHTEN,
	MoldStyle.BlendMode.DARKEN,
	MoldStyle.BlendMode.COLOR_DODGE,
	MoldStyle.BlendMode.COLOR_BURN,
]
const FIELD_EXTENT := 22.0
const CAMERA_PITCH := 0.34

var world: MoldRuntimeInstance
var handles: Array[MoldHandle] = []
var preset_buttons: Array[Button] = []
var shape_index := 0
var blend_mode: MoldStyle.BlendMode = MoldStyle.BlendMode.OPAQUE
var automatic_lod := true
var fixed_detail: MoldShape.Detail = MoldShape.Detail.MEDIUM
var amount := 256
var camera_distance := 34.0

@onready var camera: Camera3D = $Camera3D
@onready var shape_selector: OptionButton = $Interface/ControlPanel/Content/ShapeSelector
@onready var blend_selector: OptionButton = $Interface/ControlPanel/Content/BlendSelector
@onready var mode_selector: OptionButton = $Interface/ControlPanel/Content/ModeRow/ModeSelector
@onready var quality_selector: OptionButton = $Interface/ControlPanel/Content/ModeRow/QualitySelector
@onready var amount_slider: HSlider = $Interface/ControlPanel/Content/AmountRow/AmountSlider
@onready var amount_value: Label = $Interface/ControlPanel/Content/AmountRow/AmountValue
@onready var distance_slider: HSlider = $Interface/ControlPanel/Content/DistanceRow/DistanceSlider
@onready var distance_value: Label = $Interface/ControlPanel/Content/DistanceRow/DistanceValue
@onready var statistics: Label = $Interface/Statistics


func _ready() -> void:
	for shape_name in SHAPE_NAMES:
		shape_selector.add_item(shape_name)
	for blend_mode_name in BLEND_MODE_NAMES:
		blend_selector.add_item(blend_mode_name)
	mode_selector.add_item("Fixed quality")
	mode_selector.add_item("Dithered auto LOD")
	for detail_name in DETAIL_NAMES:
		quality_selector.add_item(detail_name)
	for child in $Interface/ControlPanel/Content/PresetRow.get_children():
		if child is Button:
			preset_buttons.append(child)

	mode_selector.select(1)
	quality_selector.select(MoldShape.Detail.EXTREME)
	quality_selector.disabled = true
	shape_selector.item_selected.connect(_on_shape_selected)
	blend_selector.item_selected.connect(_on_blend_selected)
	mode_selector.item_selected.connect(_on_mode_selected)
	quality_selector.item_selected.connect(_on_quality_selected)
	amount_slider.value_changed.connect(_on_amount_changed)
	amount_slider.drag_ended.connect(_on_amount_drag_ended)
	distance_slider.value_changed.connect(_on_distance_changed)
	var preset_count := mini(preset_buttons.size(), COUNT_PRESETS.size())
	for index in preset_count:
		preset_buttons[index].pressed.connect(_set_amount.bind(COUNT_PRESETS[index]))

	amount_slider.value = amount
	distance_slider.value = camera_distance
	amount_value.text = "16 — 4,096"
	distance_value.text = "10.0 — 80.0"
	_apply_camera_distance()
	_recreate_world()


func _process(_delta: float) -> void:
	if not world: return
	var stats := world.statistics
	statistics.text = (
		"DETAIL DISTRIBUTION   MIN %s   LOW %s   MED %s   HIGH %s   EXT %s\n"
		+ "ACTIVE %s   BATCHES %s   TRANSITIONS %s   MIGRATED %s"
	) % [
		_format_integer(stats.lod_minimal_count),
		_format_integer(stats.lod_low_count),
		_format_integer(stats.lod_medium_count),
		_format_integer(stats.lod_high_count),
		_format_integer(stats.lod_extreme_count),
		_format_integer(stats.active_mold_count),
		_format_integer(stats.batch_count),
		_format_integer(stats.lod_transition_count),
		_format_integer(stats.last_lod_migration_count),
	]


func _exit_tree() -> void:
	_clear_field()
	if world:
		world.dispose()
	world = null


func _on_shape_selected(index: int) -> void:
	shape_index = index
	_rebuild_field()


func _on_blend_selected(index: int) -> void:
	blend_mode = BLEND_MODES[index]
	_rebuild_field()


func _on_mode_selected(index: int) -> void:
	automatic_lod = index == 1
	quality_selector.disabled = automatic_lod
	quality_selector.select(MoldShape.Detail.EXTREME if automatic_lod else fixed_detail)
	_recreate_world()


func _on_quality_selected(index: int) -> void:
	fixed_detail = clampi(index, MoldShape.Detail.MINIMAL, MoldShape.Detail.EXTREME)
	if not automatic_lod:
		_rebuild_field()


func _on_amount_changed(value: float) -> void:
	amount = clampi(roundi(value), 16, COUNT_PRESETS[-1])


func _on_amount_drag_ended(changed: bool) -> void:
	if changed:
		_set_amount(amount)


func _on_distance_changed(value: float) -> void:
	camera_distance = value
	_apply_camera_distance()


func _set_amount(value: int) -> void:
	var clamped := clampi(value, 16, COUNT_PRESETS[-1])
	var changed := amount != clamped or handles.size() != clamped
	amount = clamped
	amount_slider.set_value_no_signal(amount)
	_refresh_preset_buttons()
	if changed:
		_rebuild_field()


func _recreate_world() -> void:
	_clear_field()
	if world:
		world.dispose()
	var settings := MoldWorldSettings.new()
	settings.capacity = COUNT_PRESETS[-1]
	settings.lod_mode = MoldWorldSettings.LodMode.CONTINUOUS if automatic_lod else MoldWorldSettings.LodMode.MANUAL
	settings.lod_bias = 1.0
	settings.lod_threshold_pixels = Vector4(12.0, 26.0, 54.0, 108.0)
	settings.lod_hysteresis = 0.14
	settings.lod_transition_width = 0.15
	settings.lod_evaluation_budget = COUNT_PRESETS[-1]
	world = MoldRuntime.create_instance(self, settings)
	_rebuild_field()


func _rebuild_field() -> void:
	if not world:
		return
	_clear_field()
	var shape := _selected_shape()
	var columns := ceili(sqrt(amount))
	var rows := ceili(float(amount) / columns)
	var spacing := FIELD_EXTENT / maxi(columns - 1, 1)
	var object_scale := clampf(spacing * 0.58, 0.18, 1.35)
	var x_offset := (columns - 1) * spacing * 0.5
	var z_offset := (rows - 1) * spacing * 0.5
	for index in amount:
		var column := index % columns
		var row := index / columns
		var phase := index * 0.6180339
		var position := Vector3(
			column * spacing - x_offset,
			sin(phase * 1.7) * object_scale * 0.18,
			row * spacing - z_offset
		)
		var lower := Color(
			0.08 + 0.12 * pow(sin(phase), 2.0),
			0.32 + 0.18 * pow(cos(phase * 0.7), 2.0),
			0.78
		)
		var upper := Color(
			0.82,
			0.26 + 0.24 * pow(sin(phase * 0.43), 2.0),
			0.72
		)
		var handle := world.create_transformed(
			shape,
			position,
			Quaternion.from_euler(Vector3(0.28, phase, 0.12)),
			Vector3.ONE * object_scale,
			MoldStyle.dual_gradient(
				lower,
				upper,
				Vector3.UP,
				MoldStyle.GradientSpace.OBJECT,
				blend_mode
			)
		)
		handles.append(handle)
	_refresh_preset_buttons()


func _selected_shape() -> MoldShape:
	var detail: MoldShape.Detail = MoldShape.Detail.EXTREME if automatic_lod else fixed_detail
	match shape_index:
		1: return MoldShape.cylinder(0.55, 1.15, 0.12, detail)
		2: return MoldShape.cone(0.62, 1.2, detail)
		3: return MoldShape.capsule(0.44, 1.45, detail)
		4: return MoldShape.torus(0.52, 0.28, 0.0, TAU, detail)
		5: return MoldShape.cuboid(Vector3.ONE, 0.24, detail)
		6: return MoldShape.regular_prism(6, 0.62, 1.1, 0.18, detail)
		7: return MoldShape.hemisphere(0.65, true, detail)
		_: return MoldShape.sphere(0.62, detail)


func _apply_camera_distance() -> void:
	if not camera:
		return
	var direction := Vector3(0.0, sin(CAMERA_PITCH), cos(CAMERA_PITCH))
	camera.position = direction * camera_distance
	camera.look_at(Vector3.ZERO, Vector3.UP)


func _refresh_preset_buttons() -> void:
	var preset_count := mini(preset_buttons.size(), COUNT_PRESETS.size())
	for index in preset_count:
		preset_buttons[index].button_pressed = amount == COUNT_PRESETS[index]


func _clear_field() -> void:
	for handle in handles:
		if handle and handle.is_valid:
			handle.release()
	handles.clear()


static func _format_integer(value: int) -> String:
	var digits := str(value)
	var formatted := ""
	while digits.length() > 3:
		formatted = "," + digits.substr(digits.length() - 3) + formatted
		digits = digits.left(digits.length() - 3)
	return digits + formatted
