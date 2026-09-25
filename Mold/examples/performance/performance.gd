extends Node3D

const MOLD_COUNTS: Array[int] = [100, 1000, 10000, 20000, 40000, 80000, 160000]
const SPACING := 0.24
const Samples = preload("res://examples/performance/performance_samples.gd")

@export_range(100, 160000, 100) var mold_count := 20000
@export var animate := true

var ordering_mode := MoldWorldSettings.TransparentOrderingMode.NATIVE_COMPATIBLE
var ordering_warmup_frames := 0
var benchmark_arguments_valid := true

func _ordering_name() -> String:
	return "NativeCompatible" if ordering_mode == MoldWorldSettings.TransparentOrderingMode.NATIVE_COMPATIBLE else "Batched"

func _set_ordering_mode(mode: MoldWorldSettings.TransparentOrderingMode) -> void:
	if ordering_mode == mode: return
	ordering_mode = mode
	world.transparent_ordering_mode = mode
	_reset_metrics()
	ordering_warmup_frames = 120
	metrics.text = "Warming up…"
	_refresh_ordering_note()

func _refresh_ordering_note() -> void:
	$Interface/OrderingNote.text = "Native Compatible | Engine objects; native pool is created on first use." if ordering_mode == MoldWorldSettings.TransparentOrderingMode.NATIVE_COMPATIBLE else "Batched | Batch-slot ordering reduces submission overhead."

var world: MoldRuntimeInstance
@onready var camera: Camera3D = $Camera3D
@onready var metrics: Label = $Interface/Metrics
@onready var animate_button: Button = $Interface/AnimateButton

var count_buttons: Array[Button] = []
var handles: Array[MoldHandle] = []
var base_positions := PackedVector3Array()
var animated_positions := PackedVector3Array()
var rolling := Samples.new(120)
var benchmark_samples: Samples
var has_pending_sample := false
var benchmark_finished := false
var pending_simulation_ms := 0.0
var pending_update_ms := 0.0
var pending_updated := 0
var pending_render_sequence := 0
var hud_elapsed := 0.0
var benchmark := false
var benchmark_warmup_frames := 120
var benchmark_sample_frames := 600
var benchmark_frame := 0
var benchmark_last_frame_usec := 0


func _enter_tree() -> void:
	_parse_benchmark_arguments()
	if not benchmark_arguments_valid: return


func _ready() -> void:
	if not benchmark_arguments_valid: return
	var world_settings := MoldWorldSettings.new()
	world_settings.transparent_ordering_mode = ordering_mode
	world_settings.capacity = MOLD_COUNTS[-1]
	world_settings.lod_mode = MoldWorldSettings.LodMode.MANUAL
	world = MoldRuntime.create_instance(self, world_settings)
	for child in $Interface/CountSelector.get_children():
		if child is Button:
			count_buttons.append(child)
	if not benchmark:
		mold_count = _closest_supported_count(mold_count)
	metrics.text = "Collecting performance metrics..."
	world.performance_metrics.enabled = true
	benchmark_samples = Samples.new(benchmark_sample_frames)
	var button_count := mini(count_buttons.size(), MOLD_COUNTS.size())
	for index in button_count:
		count_buttons[index].pressed.connect(_set_mold_count.bind(MOLD_COUNTS[index]))
	animate_button.pressed.connect(_toggle_animation)
	var ordering_selector: OptionButton = $Interface/OrderingSelector
	ordering_selector.add_item("Native Compatible", MoldWorldSettings.TransparentOrderingMode.NATIVE_COMPATIBLE)
	ordering_selector.add_item("Batched", MoldWorldSettings.TransparentOrderingMode.BATCHED)
	ordering_selector.select(ordering_selector.get_item_index(ordering_mode))
	ordering_selector.item_selected.connect(func(index: int) -> void: _set_ordering_mode(ordering_selector.get_item_id(index)))
	_refresh_ordering_note()
	_build_workload()
	_refresh_controls()
	if benchmark:
		$Interface.visible = false
		$ShowcaseUI.visible = false
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		print("MOLD_BENCHMARK_BEGIN ordering=%s alpha=0.75 timing=wall_clock" % _ordering_name())


func _process(_delta: float) -> void:
	if not benchmark_arguments_valid or benchmark_finished: return
	var now := Time.get_ticks_usec()
	if has_pending_sample and world.performance_metrics.render_sequence > pending_render_sequence:
		var frame_ms := (now - benchmark_last_frame_usec) / 1000.0
		if benchmark:
			_advance_benchmark(frame_ms)
			if benchmark_finished: return
		elif ordering_warmup_frames > 0:
			ordering_warmup_frames -= 1
		else:
			rolling.add(frame_ms, pending_simulation_ms, pending_update_ms, world.performance_metrics, pending_updated)
			hud_elapsed += frame_ms / 1000.0
			if hud_elapsed >= 0.5: _refresh_metrics()
	benchmark_last_frame_usec = now
	pending_render_sequence = world.performance_metrics.render_sequence
	pending_simulation_ms = 0.0
	pending_update_ms = 0.0
	pending_updated = 0
	if animate:
		var start := Time.get_ticks_usec()
		var time := Time.get_ticks_msec() * 0.001
		for index in handles.size():
			var position := base_positions[index]
			position.y += sin(time * 2.0 + index * 0.017) * 0.12
			animated_positions[index] = position
		var generated := Time.get_ticks_usec()
		pending_updated = world.update_positions_bulk(handles, animated_positions)
		pending_update_ms = (Time.get_ticks_usec() - generated) / 1000.0
		pending_simulation_ms = (generated - start) / 1000.0
	has_pending_sample = true


func _reset_metrics() -> void:
	rolling.clear()
	has_pending_sample = false
	hud_elapsed = 0.0
	metrics.text = "Collecting performance metrics..."


func _refresh_metrics() -> void:
	hud_elapsed = 0.0
	var stats := world.statistics
	var mean_frame := rolling.mean(0)
	metrics.text = ("%.1f FPS | Frame %.2f ms | p95 %.2f ms\n" % [1000.0 / mean_frame if mean_frame > 0 else 0.0, mean_frame, rolling.percentile(0, 0.95)]
		+ "Molds %d | Batches %d | Meshes %d\n" % [stats.active_mold_count, stats.batch_count, stats.cached_mesh_count]
		+ "Simulation %.3f ms | Bulk update %.3f ms\n" % [rolling.mean(1), rolling.mean(2)]
		+ "Renderer CPU %.3f ms (includes LOD + upload)\n" % rolling.mean(3)
		+ "LOD %.3f ms | Upload CPU %.3f ms\n" % [rolling.mean(4), rolling.mean(5)]
		+ "Upload %.1f KiB/frame | Calls %.1f | Updated %.0f\n" % [rolling.mean(6) / 1024.0, rolling.mean(7), rolling.mean(8)]
		+ "120-frame window | HUD 2 Hz | GPU time not measured")


func _exit_tree() -> void:
	_clear_workload()
	if world: world.dispose()
	world = null


func _build_workload() -> void:
	var shapes: Array[MoldShape] = [
		MoldShape.cuboid(Vector3(0.16, 0.16, 0.16), 0.0, MoldShape.Detail.HIGH),
		MoldShape.sphere(0.1, MoldShape.Detail.HIGH),
		MoldShape.regular_prism(6, 0.1, 0.2, 0.0, MoldShape.Detail.HIGH),
		MoldShape.capsule(0.07, 0.24, MoldShape.Detail.HIGH),
	]
	var styles: Array[MoldStyle] = [
		MoldStyle.dual_gradient(Color(0.15, 0.25, 0.8, 0.75), Color(0.3, 0.95, 1.0, 0.75), Vector3.UP, MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.TRANSPARENT),
		MoldStyle.dual_gradient(Color(0.5, 0.08, 0.45, 0.75), Color(1.0, 0.45, 0.8, 0.75), Vector3.UP, MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.TRANSPARENT),
		MoldStyle.dual_gradient(Color(0.5, 0.35, 0.02, 0.75), Color(1.0, 0.95, 0.3, 0.75), Vector3.UP, MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.TRANSPARENT),
		MoldStyle.dual_gradient(Color(0.12, 0.4, 0.3, 0.75), Color(0.45, 1.0, 0.65, 0.75), Vector3.UP, MoldStyle.GradientSpace.WORLD, MoldStyle.BlendMode.TRANSPARENT),
	]

	# Closed transparent solids need only their outer, front-facing surface.
	# Drawing rear faces too exposes triangle order in conventional alpha blending.
	var render_state := MoldRenderState.new()
	render_state.face_cull = MoldRenderState.FaceCull.BACK
	var columns := ceili(sqrt(mold_count))
	var extent := (columns - 1) * SPACING * 0.5
	var shape_count := shapes.size()
	var style_count := styles.size()
	for index in mold_count:
		var column := index % columns
		var row := index / columns
		var position := Vector3(column * SPACING - extent, 0.2, row * SPACING - extent)
		var handle := world.create_transformed(shapes[index % shape_count], position, Quaternion.IDENTITY, Vector3.ONE, styles[index % style_count], render_state)
		handles.append(handle)
		base_positions.append(position)
		animated_positions.append(position)
	camera.size = maxf(8.0, columns * SPACING * 1.12)


func _set_mold_count(count: int) -> void:
	if mold_count == count:
		return
	mold_count = count
	_clear_workload()
	_build_workload()
	_refresh_controls()
	_reset_metrics()


func _toggle_animation() -> void:
	animate = not animate
	_refresh_controls()
	_reset_metrics()


func _refresh_controls() -> void:
	var button_count := mini(count_buttons.size(), MOLD_COUNTS.size())
	for index in button_count:
		count_buttons[index].button_pressed = MOLD_COUNTS[index] == mold_count
	animate_button.text = "Pause animation" if animate else "Resume animation"


func _clear_workload() -> void:
	for handle in handles:
		if handle and handle.is_valid:
			handle.release()
	handles.clear()
	base_positions.clear()
	animated_positions.clear()


static func _closest_supported_count(requested: int) -> int:
	var closest := MOLD_COUNTS[0]
	var closest_distance := absi(requested - closest)
	var mold_count := MOLD_COUNTS.size()
	for index in range(1, mold_count):
		var distance := absi(requested - MOLD_COUNTS[index])
		if distance < closest_distance:
			closest = MOLD_COUNTS[index]
			closest_distance = distance
	return closest


func _parse_benchmark_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--benchmark":
			benchmark = true
		elif argument == "--benchmark-ordering" or argument.begins_with("--benchmark-ordering="):
			var mode := argument.trim_prefix("--benchmark-ordering=")
			if mode not in ["native", "batched"]:
				benchmark_arguments_valid = false
				push_error("Invalid --benchmark-ordering: use native or batched.")
				get_tree().quit(2)
				return
			ordering_mode = MoldWorldSettings.TransparentOrderingMode.NATIVE_COMPATIBLE if mode == "native" else MoldWorldSettings.TransparentOrderingMode.BATCHED
		elif argument == "--benchmark-static":
			animate = false
		elif argument.begins_with("--benchmark-count="):
			mold_count = clampi(int(argument.get_slice("=", 1)), 1, MOLD_COUNTS[-1])
		elif argument.begins_with("--benchmark-warmup="):
			benchmark_warmup_frames = maxi(1, int(argument.get_slice("=", 1)))
		elif argument.begins_with("--benchmark-frames="):
			benchmark_sample_frames = maxi(1, int(argument.get_slice("=", 1)))


func _advance_benchmark(frame_milliseconds: float) -> void:
	if benchmark_finished: return
	benchmark_frame += 1
	if benchmark_frame <= benchmark_warmup_frames: return
	benchmark_samples.add(frame_milliseconds, pending_simulation_ms, pending_update_ms, world.performance_metrics, pending_updated)
	if benchmark_samples.count < benchmark_sample_frames: return
	benchmark_finished = true
	var frame_mean: float = benchmark_samples.mean(0)
	var stats := world.statistics
	var result := {
		"backend": "MeshInstance3D" if ordering_mode == MoldWorldSettings.TransparentOrderingMode.NATIVE_COMPATIBLE else "MultiMesh",
		"transparent_ordering_mode": _ordering_name(),
		"workload_alpha": 0.75,
		"mold_count": mold_count,
		"animate": animate,
		"lod": "manual",
		"detail": "high",
		"warmup_frames": benchmark_warmup_frames,
		"sample_frames": benchmark_sample_frames,
		"batches": stats.batch_count,
		"timing": "wall_clock_process_interval",
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"max_fps": Engine.max_fps,
		"frame_mean_ms": frame_mean,
		"frame_median_ms": benchmark_samples.percentile(0, 0.50),
		"frame_p95_ms": benchmark_samples.percentile(0, 0.95),
		"fps_from_mean": 1000.0 / frame_mean if frame_mean > 0 else 0.0,
		"update_mean_ms": benchmark_samples.mean(9),
		"update_p95_ms": benchmark_samples.percentile(9, 0.95),
		"simulation_mean_ms": benchmark_samples.mean(1),
		"simulation_p95_ms": benchmark_samples.percentile(1, 0.95),
		"bulk_update_mean_ms": benchmark_samples.mean(2),
		"bulk_update_p95_ms": benchmark_samples.percentile(2, 0.95),
		"render_cpu_mean_ms": benchmark_samples.mean(3),
		"render_cpu_p95_ms": benchmark_samples.percentile(3, 0.95),
		"lod_cpu_mean_ms": benchmark_samples.mean(4),
		"lod_cpu_p95_ms": benchmark_samples.percentile(4, 0.95),
		"upload_cpu_mean_ms": benchmark_samples.mean(5),
		"upload_cpu_p95_ms": benchmark_samples.percentile(5, 0.95),
		"upload_bytes_mean": benchmark_samples.mean(6),
		"upload_calls_mean": benchmark_samples.mean(7),
		"updated_molds_mean": benchmark_samples.mean(8),
		"port": "godot_gdscript",
		"metrics_enabled": true,
		"hud_refresh_hz": 0,
		"gpu_time_measured": false,
		"renderer": RenderingServer.get_video_adapter_name(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"godot": Engine.get_version_info().string,
	}
	print("MOLD_BENCHMARK " + JSON.stringify(result))
	get_tree().quit()
