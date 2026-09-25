extends Node3D

## Animated wave-field comparison, adapted from MoldUnity's Polyline Backend sample.
@export_range(8,1024,8) var path_count := 128
@export_range(8,512,8) var points_per_path := 192
@export var width := 26.0
@export var height := 15.0
@export var stroke_width := 0.026
@export var wave_amplitude := 0.28
@export var animation_speed := 1.0
@export var brightness := 2.2
@export var animate := true
@export var backend := MoldPolylineBackend.Mode.AUTO
var _runtime: MoldRuntimeInstance
var _renderer: MoldGpuPolylineRenderer
var _points := PackedFloat32Array()
var _paths: Array[MoldGpuPolylineRange] = []
var _cpu_points: Array = []
var _cpu_handles: Array[MoldHandle] = []
var _wave_seeds := PackedVector2Array()
var _status: Label
var _pending_count: SpinBox
var _time := 0.0
var _frame_ms := 0.0
var _generate_ms := 0.0
var _upload_ms := 0.0
var _using_gpu := false
var _built_paths := 0
var _built_points := 0
var _active_backend := MoldPolylineBackend.Mode.AUTO
var _built_dimensions := Vector4.ZERO

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = height*1.25
	camera.position = Vector3(0,0,20)
	camera.current = true
	add_child(camera)
	var world_environment := WorldEnvironment.new()
	world_environment.environment = Environment.new()
	world_environment.environment.background_mode = Environment.BG_COLOR
	world_environment.environment.background_color = Color(0.002,0.003,0.009)
	add_child(world_environment)
	_build_ui()
	_runtime = MoldRuntime.create_instance(self)
	_build()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18,18)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,14)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var title := Label.new()
	title.text = "Mold — Polyline Backend"
	box.add_child(title)
	_status = Label.new()
	_status.custom_minimum_size = Vector2(465,100)
	box.add_child(_status)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var auto := Button.new()
	auto.text = "Auto (GPU when supported)"
	auto.pressed.connect(func(): backend = MoldPolylineBackend.Mode.AUTO; _apply_backend())
	buttons.add_child(auto)
	var cpu := Button.new()
	cpu.text = "CPU"
	cpu.pressed.connect(func(): backend = MoldPolylineBackend.Mode.CPU; _apply_backend())
	buttons.add_child(cpu)
	var pause := CheckButton.new()
	pause.text = "Animate"
	pause.button_pressed = animate
	pause.toggled.connect(func(value: bool): animate = value)
	buttons.add_child(pause)
	var counts := HBoxContainer.new()
	box.add_child(counts)
	var label := Label.new()
	label.text = "Lines"
	counts.add_child(label)
	_pending_count = SpinBox.new()
	_pending_count.min_value = 8; _pending_count.max_value = 1024; _pending_count.step = 8; _pending_count.value = path_count
	counts.add_child(_pending_count)
	var apply := Button.new()
	apply.text = "Set"
	apply.pressed.connect(func(): path_count = int(_pending_count.value); _build())
	counts.add_child(apply)
	var help := Label.new()
	help.text = "Set rebuilds topology once. CPU rebuilds meshes while animated."
	box.add_child(help)

func _build() -> void:
	_release_backend()
	path_count = clampi(path_count,8,1024); points_per_path = clampi(points_per_path,8,512)
	_points.resize(path_count*points_per_path*8)
	_paths.clear(); _cpu_points.clear(); _wave_seeds.resize(path_count)
	for path in path_count:
		_paths.append(MoldGpuPolylineRange.new(path*points_per_path,points_per_path))
		var cpu_points: Array[MoldPolylinePoint] = []
		cpu_points.resize(points_per_path)
		for point in points_per_path: cpu_points[point] = MoldPolylinePoint.new()
		_cpu_points.append(cpu_points)
		var hash_value := fposmod(sin((path+1)*91.733)*43758.5453,1.0)
		_wave_seeds[path] = Vector2(hash_value*TAU,0.65+hash_value*1.7)
	_built_paths = path_count; _built_points = points_per_path
	_built_dimensions = Vector4(width,height,stroke_width,wave_amplitude)
	_generate_points()
	_apply_backend()

func _apply_backend() -> void:
	if not _runtime: return
	_release_backend()
	_active_backend = backend
	_using_gpu = backend == MoldPolylineBackend.Mode.AUTO and MoldGpuPolylineRenderer.is_supported()
	if _using_gpu:
		_renderer = _runtime.create_gpu_polyline_renderer()
		_renderer.miter_limit = 2
		_renderer.set_data(_points,_paths)
		_renderer.set_local_bounds(AABB(Vector3(-width/2-1,-height/2-wave_amplitude-1,-1),Vector3(width+2,height+2*wave_amplitude+2,2)))
		_renderer.set_transform(global_transform)
	else:
		_synchronize_cpu_points()
		for path in path_count:
			_cpu_handles.append(_runtime.create_polyline(MoldPolyline.new(_cpu_points[path],1.0,false,MoldPolyline.Join.MITER,MoldPolyline.Cap.BUTT,2),MoldStyle.additive(Color.WHITE),null,MoldPolylineBackend.Mode.CPU))
		_update_cpu_transforms()

func _release_backend() -> void:
	if _renderer: _renderer.dispose()
	_renderer = null
	for handle in _cpu_handles:
		if handle.is_valid: handle.release()
	_cpu_handles.clear()

func _process(delta: float) -> void:
	if not _runtime: return
	if _built_paths != path_count or _built_points != points_per_path or _built_dimensions != Vector4(width,height,stroke_width,wave_amplitude): _build()
	elif _active_backend != backend: _apply_backend()
	if animate:
		_time += delta*animation_speed
		var start := Time.get_ticks_usec()
		_generate_points()
		var generated := Time.get_ticks_usec()
		if _using_gpu: _renderer.update_points(_points,false)
		else:
			_synchronize_cpu_points()
			for path in path_count:
				_cpu_handles[path].set_polyline(MoldPolyline.new(_cpu_points[path],1.0,false,MoldPolyline.Join.MITER,MoldPolyline.Cap.BUTT,2))
		_generate_ms = (generated-start)/1000.0
		_upload_ms = (Time.get_ticks_usec()-generated)/1000.0
	if _using_gpu: _renderer.set_transform(global_transform)
	else: _update_cpu_transforms()
	_frame_ms = lerpf(delta*1000 if _frame_ms <= 0 else _frame_ms,delta*1000,0.04)
	_status.text = "%s paths · %s points\nRequested: %s · Active: %s · %.2f ms/frame\nPoint generation: %.2f ms · Update: %.2f ms\n%s" % [path_count,_points.size()/8,"Auto" if backend == 0 else "CPU","GPU" if _using_gpu else "CPU",_frame_ms,_generate_ms,_upload_ms,("%s shader vertices · GDScript point producer" % _renderer.generated_vertex_count) if _using_gpu else "Cached CPU mesh backend · GDScript point producer"]

func _update_cpu_transforms() -> void:
	var t := global_transform
	for handle in _cpu_handles: handle.set_transform(t.origin,t.basis.orthonormalized().get_rotation_quaternion(),t.basis.get_scale())

func _generate_points() -> void:
	for path in path_count:
		var path_t := float(path)/(path_count-1)
		var lane := (path_t-0.5)*height
		var seed := _wave_seeds[path]
		for point in points_per_path:
			var point_t := float(point)/(points_per_path-1)
			var x := (point_t-0.5)*width
			var traveling := sin(x*seed.y+seed.x+_time*(1.1+path_t*1.7))
			var interference := sin(x*0.47-_time*1.9+path_t*PI*13)
			var pulse := 0.68+0.32*sin(point_t*PI*8-_time*2.5+seed.x)
			var y := lane+(traveling*0.72+interference*0.28)*wave_amplitude*sin(point_t*PI)
			var color := Color.from_hsv(fposmod(path_t*0.82+point_t*0.22+_time*0.018,1),0.72,1)*brightness
			var o := (path*points_per_path+point)*8
			_points[o] = x; _points[o+1] = y; _points[o+2] = 0; _points[o+3] = stroke_width*pulse
			_points[o+4] = color.r; _points[o+5] = color.g; _points[o+6] = color.b; _points[o+7] = 0.72

func _synchronize_cpu_points() -> void:
	for path in path_count:
		for point in points_per_path:
			var o := (path*points_per_path+point)*8
			var p: MoldPolylinePoint = _cpu_points[path][point]
			p.position = Vector3(_points[o],_points[o+1],_points[o+2])
			p.thickness = _points[o+3]
			p.color = Color(_points[o+4],_points[o+5],_points[o+6],_points[o+7])

func _exit_tree() -> void:
	_release_backend()
	if _runtime: _runtime.dispose()
	_runtime = null
