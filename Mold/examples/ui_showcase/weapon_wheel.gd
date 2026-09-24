extends Node3D

## An original retained radial weapon selector for category-based loadouts.
## Eight stable category positions build spatial memory. The selected category
## inverts contrast while the calm hub reports weapon, variant, and ammunition.

const SLOT_COUNT := 8
const SLOT_STEP := TAU / float(SLOT_COUNT)
const SEGMENT_RADIUS := 1.43
const SEGMENT_THICKNESS := 0.82
const SEGMENT_SPAN := deg_to_rad(40.0)
const ICON_RADIUS := 1.39
const AMMO_RADIUS := 1.72

const SCRIM := Color(0.012, 0.014, 0.017, 0.76)
const HUB := Color(0.025, 0.029, 0.032, 0.94)
const SEGMENT_IDLE := Color(0.68, 0.70, 0.70, 0.12)
const SEGMENT_ACTIVE := Color(0.91, 0.92, 0.90, 0.76)
const LINE := Color(0.82, 0.84, 0.82, 0.26)
const ICON := Color(0.88, 0.90, 0.88, 0.74)
const ICON_ACTIVE := Color(0.035, 0.042, 0.044, 0.98)
const COPY := Color(0.94, 0.95, 0.92, 0.96)
const COPY_MUTED := Color(0.67, 0.70, 0.68, 0.72)
const ACCENT := Color(0.48, 0.82, 0.88, 0.90)

@onready var camera: Camera3D = get_parent().get_node("Camera3D")
@onready var interface: CanvasLayer = get_parent().get_node("Interface")

var world: MoldRuntimeInstance
var handles: Array[MoldHandle] = []
var fixed_items: Array[Dictionary] = []
var wheel_labels: Array[Dictionary] = []
var slots: Array[Dictionary] = []
var stat_fills: Array[MoldHandle] = []

var weapon_name_label: Label
var weapon_index_label: Label
var attachment_label: Label
var selected_ammo_label: Label

var elapsed := 0.0
var selected_slot := 2
var selected_variants: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]


func _ready() -> void:
	set_process(false)
	_initialize.call_deferred()


func _initialize() -> void:
	var settings := MoldWorldSettings.new()
	settings.capacity = 160
	settings.lod_mode = MoldWorldSettings.LodMode.MANUAL
	settings.retained_unused_mesh_count = 32
	world = MoldRuntime.create_instance(self, settings)
	_build_wheel()
	_build_slots()
	_build_stats()
	_build_copy()
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()
	_update_wheel(true)
	set_process(true)


func _process(delta: float) -> void:
	elapsed += delta
	var cycle_index := int(elapsed / 2.25)
	var next_slot := (2 + cycle_index) % SLOT_COUNT
	if next_slot != selected_slot:
		selected_slot = next_slot
		selected_variants[selected_slot] = int(cycle_index / SLOT_COUNT) % 2
		_update_wheel(true)


func _exit_tree() -> void:
	for handle in handles:
		if handle and handle.is_valid:
			handle.release()
	handles.clear()
	slots.clear()
	wheel_labels.clear()
	stat_fills.clear()
	if world:
		world.dispose()
	world = null


func _build_wheel() -> void:
	_add_fixed(MoldShape.disc(2.00), MoldStyle.transparent(SCRIM), Vector3.ZERO, -40)
	_add_fixed(MoldShape.ring(1.94, 0.014), MoldStyle.transparent(LINE), Vector3.ZERO, -10)
	_add_fixed(MoldShape.ring(1.01, 0.012), MoldStyle.transparent(LINE), Vector3.ZERO, 5)
	_add_fixed(MoldShape.disc(0.82), MoldStyle.transparent(HUB), Vector3.ZERO, 8)
	_add_fixed(MoldShape.ring(0.82, 0.012), MoldStyle.transparent(LINE), Vector3.ZERO, 9)
	for index in SLOT_COUNT:
		var angle := _world_angle(index)
		var local := Vector3(cos(angle), sin(angle), 0.0) * 1.97
		_add_fixed(MoldShape.rectangle(Vector2(0.014, 0.075), 0.5),
			MoldStyle.transparent(LINE), local, 12,
			Quaternion(Vector3.BACK, angle - PI * 0.5))


func _build_slots() -> void:
	var recipes := [
		{"category": "HANDGUNS", "kind": "handgun", "weapons": ["COMBAT PISTOL", "HEAVY REVOLVER"], "ammo": ["148 / 12", "72 / 6"], "attachment": ["SUPPRESSOR · LIGHT", "NO ATTACHMENTS"], "stats": Vector4(0.42, 0.48, 0.66, 0.44)},
		{"category": "MACHINE GUNS", "kind": "smg", "weapons": ["MICRO SMG", "COMBAT MG"], "ammo": ["246 / 30", "420 / 100"], "attachment": ["EXTENDED CLIP", "GRIP · SCOPE"], "stats": Vector4(0.48, 0.86, 0.54, 0.50)},
		{"category": "ASSAULT RIFLES", "kind": "rifle", "weapons": ["CARBINE RIFLE", "BULLPUP RIFLE"], "ammo": ["240 / 30", "180 / 30"], "attachment": ["SCOPE · GRIP", "SUPPRESSOR"], "stats": Vector4(0.62, 0.72, 0.72, 0.68)},
		{"category": "SNIPER RIFLES", "kind": "sniper", "weapons": ["HEAVY SNIPER", "MARKSMAN RIFLE"], "ammo": ["42 / 6", "64 / 8"], "attachment": ["ADVANCED SCOPE", "ZOOM SCOPE"], "stats": Vector4(0.94, 0.28, 0.92, 0.96)},
		{"category": "MELEE", "kind": "melee", "weapons": ["UNARMED", "BASEBALL BAT"], "ammo": ["—", "—"], "attachment": ["NO ATTACHMENTS", "NO ATTACHMENTS"], "stats": Vector4(0.30, 0.56, 0.76, 0.12)},
		{"category": "SHOTGUNS", "kind": "shotgun", "weapons": ["PUMP SHOTGUN", "SAWED-OFF"], "ammo": ["56 / 8", "34 / 2"], "attachment": ["FLASHLIGHT", "NO ATTACHMENTS"], "stats": Vector4(0.78, 0.34, 0.38, 0.32)},
		{"category": "HEAVY", "kind": "heavy", "weapons": ["RPG", "GRENADE LAUNCHER"], "ammo": ["8", "18 / 6"], "attachment": ["NO ATTACHMENTS", "GRIP"], "stats": Vector4(1.00, 0.18, 0.48, 0.82)},
		{"category": "THROWN", "kind": "thrown", "weapons": ["STICKY BOMB", "GRENADE"], "ammo": ["16", "12"], "attachment": ["REMOTE", "TIMED"], "stats": Vector4(0.86, 0.22, 0.36, 0.40)},
	]

	for index in SLOT_COUNT:
		var recipe: Dictionary = recipes[index]
		var angle := _world_angle(index)
		var segment := world.create(
			MoldShape.ring(SEGMENT_RADIUS, SEGMENT_THICKNESS,
				PI * 0.5 - angle - SEGMENT_SPAN * 0.5, SEGMENT_SPAN),
			MoldStyle.transparent(SEGMENT_IDLE), _ui_state(0))
		handles.append(segment)
		var parts := _create_icon(recipe.kind)
		var ammo_label := _make_label(recipe.ammo[0], 10, COPY_MUTED)
		ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ammo_label.size = Vector2(70.0, 18.0)
		slots.append({
			"segment": segment, "angle": angle, "parts": parts,
			"ammo_label": ammo_label, "ammo_size": ammo_label.size,
			"category": recipe.category, "weapons": recipe.weapons,
			"ammo": recipe.ammo, "attachment": recipe.attachment,
			"stats": recipe.stats,
		})


func _create_icon(kind: String) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	match kind:
		"handgun":
			specs = [_spec(MoldShape.rectangle(Vector2(0.34, 0.10), 0.18), Vector3(0.0, 0.045, 0.0)), _spec(MoldShape.rectangle(Vector2(0.09, 0.19), 0.15), Vector3(0.075, -0.065, 0.0), -0.22)]
		"smg":
			specs = [_spec(MoldShape.rectangle(Vector2(0.35, 0.12), 0.14), Vector3(-0.02, 0.03, 0.0)), _spec(MoldShape.rectangle(Vector2(0.20, 0.045), 0.3), Vector3(0.23, 0.045, 0.0)), _spec(MoldShape.rectangle(Vector2(0.075, 0.18), 0.2), Vector3(0.04, -0.08, 0.0), -0.18)]
		"rifle":
			specs = [_spec(MoldShape.rectangle(Vector2(0.42, 0.11), 0.14), Vector3(0.0, 0.03, 0.0)), _spec(MoldShape.rectangle(Vector2(0.28, 0.04), 0.3), Vector3(0.33, 0.045, 0.0)), _spec(MoldShape.regular_polygon(3, 0.13, 0.04), Vector3(-0.27, 0.025, 0.0), PI), _spec(MoldShape.rectangle(Vector2(0.07, 0.17), 0.2), Vector3(0.02, -0.08, 0.0), -0.18)]
		"sniper":
			specs = [_spec(MoldShape.rectangle(Vector2(0.68, 0.055), 0.4), Vector3(0.02, 0.0, 0.0)), _spec(MoldShape.ring(0.085, 0.035), Vector3(-0.04, 0.09, 0.0)), _spec(MoldShape.rectangle(Vector2(0.06, 0.16), 0.2), Vector3(0.06, -0.07, 0.0), -0.18)]
		"melee":
			specs = [_spec(MoldShape.line_2d(Vector3(-0.25, -0.11, 0.0), Vector3(0.25, 0.11, 0.0), 0.065), Vector3.ZERO), _spec(MoldShape.disc(0.075), Vector3(0.25, 0.11, 0.0))]
		"shotgun":
			specs = [_spec(MoldShape.rectangle(Vector2(0.66, 0.06), 0.35), Vector3(0.03, 0.03, 0.0)), _spec(MoldShape.rectangle(Vector2(0.18, 0.11), 0.18), Vector3(-0.23, 0.0, 0.0)), _spec(MoldShape.rectangle(Vector2(0.065, 0.16), 0.2), Vector3(-0.08, -0.07, 0.0), -0.22)]
		"heavy":
			specs = [_spec(MoldShape.rectangle(Vector2(0.58, 0.14), 0.45), Vector3(0.0, 0.02, 0.0)), _spec(MoldShape.ring(0.105, 0.04), Vector3(0.30, 0.02, 0.0)), _spec(MoldShape.rectangle(Vector2(0.08, 0.17), 0.2), Vector3(-0.04, -0.09, 0.0))]
		"thrown":
			specs = [_spec(MoldShape.regular_polygon(6, 0.15, 0.10), Vector3(0.0, -0.02, 0.0)), _spec(MoldShape.rectangle(Vector2(0.08, 0.09), 0.25), Vector3(0.0, 0.15, 0.0)), _spec(MoldShape.ring(0.07, 0.025, 0.0, PI), Vector3(0.07, 0.20, 0.0))]

	var parts: Array[Dictionary] = []
	for spec in specs:
		var handle := world.create(spec.shape, MoldStyle.transparent(ICON), _ui_state(20))
		handles.append(handle)
		parts.append({"handle": handle, "offset": spec.offset,
			"rotation": Quaternion(Vector3.BACK, float(spec.rotation))})
	return parts


func _spec(shape: MoldShape, offset: Vector3, rotation := 0.0) -> Dictionary:
	return {"shape": shape, "offset": offset, "rotation": rotation}


func _build_stats() -> void:
	var names := ["DAMAGE", "FIRE RATE", "ACCURACY", "RANGE"]
	for index in names.size():
		var y := 0.42 - float(index) * 0.25
		_add_fixed(MoldShape.rectangle(Vector2(0.82, 0.035), 0.5),
			MoldStyle.transparent(Color(0.75, 0.78, 0.76, 0.16)), Vector3(3.19, y, 0.0), 5)
		stat_fills.append(_add_fixed(MoldShape.rectangle(Vector2(0.40, 0.035), 0.5),
			MoldStyle.transparent(ACCENT), Vector3(2.78, y, 0.0), 15))
		_add_wheel_label(names[index], Vector3(2.28, y, 0.0), Vector2(78.0, 18.0),
			9, COPY_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)


func _build_copy() -> void:
	weapon_name_label = _add_wheel_label("CARBINE RIFLE", Vector3(0.0, 0.23, 0.0), Vector2(190.0, 24.0), 14, COPY, HORIZONTAL_ALIGNMENT_CENTER)
	weapon_index_label = _add_wheel_label("1 / 2  ·  ASSAULT RIFLES", Vector3(0.0, 0.00, 0.0), Vector2(210.0, 20.0), 10, COPY_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	attachment_label = _add_wheel_label("SCOPE · GRIP", Vector3(0.0, -0.22, 0.0), Vector2(180.0, 18.0), 9, COPY_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	selected_ammo_label = _add_wheel_label("240  |  30", Vector3(0.0, -0.43, 0.0), Vector2(130.0, 24.0), 13, COPY, HORIZONTAL_ALIGNMENT_CENTER)


func _update_wheel(update_copy: bool) -> void:
	if not world:
		return
	var center := _wheel_center()
	for index in slots.size():
		var slot: Dictionary = slots[index]
		var active := index == selected_slot
		(slot.segment as MoldHandle).set_position(center)
		(slot.segment as MoldHandle).set_color(SEGMENT_ACTIVE if active else SEGMENT_IDLE)
		var icon_center := center + Vector3(cos(slot.angle), sin(slot.angle), 0.0) * ICON_RADIUS
		var icon_scale := 1.10 if active else 0.88
		for part in slot.parts:
			(part.handle as MoldHandle).set_transform(icon_center + part.offset * icon_scale,
				part.rotation, Vector3.ONE * icon_scale)
			(part.handle as MoldHandle).set_color(ICON_ACTIVE if active else ICON)
		var label := slot.ammo_label as Label
		var ammo_position := center + Vector3(cos(slot.angle), sin(slot.angle), 0.0) * AMMO_RADIUS
		label.position = camera.unproject_position(ammo_position) - slot.ammo_size * 0.5
		label.add_theme_color_override("font_color", ICON_ACTIVE if active else COPY_MUTED)
		label.text = slot.ammo[selected_variants[index]]
	if update_copy:
		_update_selected_copy()


func _update_selected_copy() -> void:
	var slot: Dictionary = slots[selected_slot]
	var variant := selected_variants[selected_slot]
	weapon_name_label.text = slot.weapons[variant]
	weapon_index_label.text = "%d / %d  ·  %s" % [variant + 1, slot.weapons.size(), slot.category]
	attachment_label.text = slot.attachment[variant]
	selected_ammo_label.text = str(slot.ammo[variant]).replace(" / ", "  |  ")
	var values: Vector4 = slot.stats
	for index in stat_fills.size():
		var width := maxf(0.012, 0.82 * values[index])
		var y := 0.42 - float(index) * 0.25
		stat_fills[index].set_shape(MoldShape.rectangle(Vector2(width, 0.035), 0.5))
		stat_fills[index].set_position(_wheel_center() + Vector3(2.78 + width * 0.5, y, 0.0))


func _world_angle(index: int) -> float:
	return PI * 0.5 - float(index) * SLOT_STEP


func _wheel_center() -> Vector3:
	return Vector3(0.0, 0.78, 0.0)


func _layout_hud() -> void:
	var center := _wheel_center()
	for item in fixed_items:
		(item.handle as MoldHandle).set_position(center + item.local)
	for item in wheel_labels:
		var label := item.label as Label
		label.position = camera.unproject_position(center + item.local) - item.size * 0.5
	_update_wheel(false)


func _add_fixed(shape: MoldShape, style: MoldStyle, local_position: Vector3,
		order: int, rotation: Quaternion = Quaternion.IDENTITY) -> MoldHandle:
	var handle := world.create(shape, style, _ui_state(order))
	handle.set_transform(_wheel_center() + local_position, rotation, Vector3.ONE)
	handles.append(handle)
	fixed_items.append({"handle": handle, "local": local_position})
	return handle


func _add_wheel_label(text: String, local: Vector3, size: Vector2,
		font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := _make_label(text, font_size, color)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = size
	wheel_labels.append({"label": label, "local": local, "size": size})
	return label


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", font_size)
	interface.add_child(label)
	return label


func _ui_state(order: int) -> MoldRenderState:
	return MoldRenderState.new(1, order, MoldRenderState.DepthTest.ALWAYS,
		MoldRenderState.DepthWrite.DISABLED, MoldRenderState.StencilFlags.DISABLED,
		MoldRenderState.StencilCompare.ALWAYS, 0, MoldRenderState.FaceCull.DISABLED)
