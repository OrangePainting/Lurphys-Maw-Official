extends Node3D

const ORBIT_SENSITIVITY := 0.006
const PAN_SENSITIVITY := 0.0012
const CAMERA_DISTANCE := 38.2
const DEFAULT_FOCUS := Vector3(-0.5, 0.4, 0.0)
const DEFAULT_YAW := 0.729
const DEFAULT_PITCH := 0.601
const DEFAULT_SIZE := 25.5

const CANVAS := Color("fcf7eb")
const ROAD := Color("fcfbf9")
const ROAD_EDGE := Color("a2c1ca")
const WATER := Color("a6d6ea")
const WATER_DEEP := Color("90cde4")
const PARK := Color("dae9cc")
const PARK_DARK := Color("c6d7b2")
const SHADOW := Color("8ea3aa")
const INK := Color("32322e")
const PINK := Color("f36784")
const PINK_DEEP := Color("9b3f70")
const BLUE := Color("6c93c3")
const BLUE_DEEP := Color("413e7a")
const TEAL := Color("53b7d2")
const TEAL_DEEP := Color("2a718b")
const YELLOW := Color("ffc15b")
const YELLOW_DEEP := Color("f38c4b")
const MOTORWAY := Color("fae8a0")
const MOTORWAY_EDGE := Color("f4c96b")

var world: MoldRuntimeInstance
@onready var camera: Camera3D = $Camera3D

var handles: Array[MoldHandle] = []
var cars: Array[Dictionary] = []
var pulses: Array[MoldHandle] = []
var camera_focus := DEFAULT_FOCUS
var target_focus := DEFAULT_FOCUS
var camera_yaw := DEFAULT_YAW
var target_yaw := DEFAULT_YAW
var camera_pitch := DEFAULT_PITCH
var target_pitch := DEFAULT_PITCH
var target_size := DEFAULT_SIZE
var orbit_dragging := false
var pan_dragging := false
var touch_dragging := false


func _ready() -> void:
	var settings := MoldWorldSettings.new()
	settings.lod_mode = MoldWorldSettings.LodMode.CONTINUOUS
	settings.lod_transition_width = 0.15
	world = MoldRuntime.create_instance(self, settings)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = DEFAULT_SIZE
	camera.near = 1.0
	camera.far = 96.0
	_update_camera_transform()
	world.prewarm([
		MoldShape.cuboid(Vector3.ONE, 0.4, MoldShape.Detail.LOW),
		MoldShape.line_3d(Vector3.ZERO, Vector3.ONE, 0.2),
		MoldShape.cylinder(1.0, 1.0, 0.45, MoldShape.Detail.LOW),
		MoldShape.sphere(1.0, MoldShape.Detail.LOW),
		MoldShape.ring(1.0, 0.1),
	])
	_create_terrain()
	_create_roads()
	_create_blocks()
	_create_motorway()
	_create_traffic()
	world.clear_unused_meshes()


func _process(delta: float) -> void:
	_animate_camera(delta)
	var time := Time.get_ticks_msec() * 0.001
	for car in cars:
		_animate_car(car, time * car.speed + car.offset)
	var pulse_count := pulses.size()
	for index in pulse_count:
		var wave := (sin(time * 2.4 + index * 1.3) + 1.0) * 0.5
		pulses[index].set_scale(Vector3.ONE * (0.86 + wave * 0.22))
		pulses[index].set_color(Color(1.0, 1.0, 1.0, 0.36 + wave * 0.32))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				orbit_dragging = event.pressed and not event.shift_pressed
				pan_dragging = event.pressed and event.shift_pressed
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				pan_dragging = event.pressed
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed: _zoom_camera(-1.6 * event.factor)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed: _zoom_camera(1.6 * event.factor)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if orbit_dragging: _orbit_camera(event.relative)
		if pan_dragging: _pan_camera(event.relative)
		if orbit_dragging or pan_dragging: get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		touch_dragging = event.pressed
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touch_dragging:
		_orbit_camera(event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_reset_camera()
		get_viewport().set_input_as_handled()


func _orbit_camera(relative: Vector2) -> void:
	target_yaw = wrapf(target_yaw - relative.x * ORBIT_SENSITIVITY, -PI, PI)
	target_pitch = clampf(target_pitch + relative.y * ORBIT_SENSITIVITY, 0.28, 1.16)


func _pan_camera(relative: Vector2) -> void:
	var scale := target_size * PAN_SENSITIVITY
	var right := Vector3(cos(target_yaw), 0.0, -sin(target_yaw))
	var forward := Vector3(-sin(target_yaw), 0.0, -cos(target_yaw))
	target_focus += right * (-relative.x * scale) + forward * (relative.y * scale)
	target_focus.x = clampf(target_focus.x, -16.0, 16.0)
	target_focus.z = clampf(target_focus.z, -11.0, 11.0)


func _zoom_camera(amount: float) -> void:
	target_size = clampf(target_size + amount, 15.0, 38.0)


func _reset_camera() -> void:
	target_focus = DEFAULT_FOCUS
	target_yaw = DEFAULT_YAW
	target_pitch = DEFAULT_PITCH
	target_size = DEFAULT_SIZE


func _animate_camera(delta: float) -> void:
	var blend := 1.0 - exp(-delta * 12.0)
	camera_yaw = lerp_angle(camera_yaw, target_yaw, blend)
	camera_pitch = lerpf(camera_pitch, target_pitch, blend)
	camera_focus = camera_focus.lerp(target_focus, blend)
	camera.size = lerpf(camera.size, target_size, blend)
	_update_camera_transform()


func _update_camera_transform() -> void:
	var horizontal := cos(camera_pitch)
	var direction := Vector3(sin(camera_yaw) * horizontal, sin(camera_pitch), cos(camera_yaw) * horizontal)
	camera.position = camera_focus + direction * CAMERA_DISTANCE
	camera.look_at(camera_focus, Vector3.UP)


func _create_terrain() -> void:
	_add(MoldShape.cuboid(Vector3(36.0, 0.42, 24.0), 0.28, MoldShape.Detail.LOW), MoldStyle.opaque(CANVAS), Vector3(0.0, -0.22, 0.0))
	_add(MoldShape.cuboid(Vector3(4.4, 0.18, 24.5), 0.48, MoldShape.Detail.LOW), MoldStyle.dual_gradient(WATER_DEEP, WATER, 0.18), Vector3(4.1, 0.01, 0.0))
	_add(MoldShape.cuboid(Vector3(8.0, 0.18, 5.5), 0.48, MoldShape.Detail.LOW), MoldStyle.dual_gradient(WATER_DEEP, WATER, 0.18), Vector3(-14.1, 0.01, -9.4))
	for data in [[Vector3(-10.0, 0.09, 1.5), Vector3(8.0, 0.15, 4.4)], [Vector3(-8.5, 0.09, 8.2), Vector3(9.5, 0.15, 4.1)], [Vector3(10.4, 0.09, 5.8), Vector3(9.2, 0.15, 4.8)], [Vector3(12.5, 0.09, -7.5), Vector3(7.4, 0.15, 4.0)]]:
		_add(MoldShape.cuboid(data[1], 0.5, MoldShape.Detail.LOW), MoldStyle.dual_gradient(PARK_DARK, PARK, 0.12), data[0])
	for index in range(-5, 6):
		var z := index * 2.0
		_add(MoldShape.line_3d(Vector3(1.95, 0.13, z), Vector3(6.25, 0.13, z), 0.025), MoldStyle.transparent(Color(0.35, 0.67, 0.75, 0.16)), Vector3.ZERO)
	for index in 3:
		var x := 2.55 + index * 1.5
		_add(MoldShape.line_3d(Vector3(x, 0.13, -12.0), Vector3(x, 0.13, 12.0), 0.025), MoldStyle.transparent(Color(0.35, 0.67, 0.75, 0.13)), Vector3.ZERO)
	for center in [Vector3(-14.6, 0.18, 7.8), Vector3(-10.0, 0.18, 8.8), Vector3(-6.2, 0.18, 7.7), Vector3(-13.8, 0.18, 1.6), Vector3(9.6, 0.18, 7.1), Vector3(14.6, 0.18, 6.4), Vector3(13.8, 0.18, -8.0)]:
		_add_tree_cluster(center)


func _add_tree_cluster(center: Vector3) -> void:
	var offsets := [Vector3(-0.28, 0.0, 0.16), Vector3(0.25, 0.0, 0.25), Vector3(0.06, 0.0, -0.25)]
	var radii := [0.34, 0.4, 0.3]
	var offset_count := offsets.size()
	for index in offset_count:
		var position: Vector3 = center + offsets[index]
		_add(MoldShape.cylinder(radii[index], 0.22 + index * 0.035, 0.48, MoldShape.Detail.LOW), MoldStyle.dual_gradient(PARK_DARK.darkened(0.08), PARK_DARK, 0.18), position + Vector3.UP * (0.11 + index * 0.018))
		_add(MoldShape.sphere(radii[index] * 0.62, MoldShape.Detail.LOW), MoldStyle.transparent(Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.22)), position + Vector3(0.28, 0.05, 0.27))


func _create_roads() -> void:
	var roads := [
		[Vector3(-15, 0, -6), Vector3(1.9, 0, -6)], [Vector3(-15, 0, -1), Vector3(1.9, 0, -1)], [Vector3(-15, 0, 4), Vector3(1.9, 0, 4)], [Vector3(-12, 0, 8), Vector3(1.9, 0, 8)],
		[Vector3(-12, 0, -8.5), Vector3(-12, 0, 8)], [Vector3(-7, 0, -8.5), Vector3(-7, 0, 8)], [Vector3(-2, 0, -8.5), Vector3(-2, 0, 8)], [Vector3(-15, 0, 4), Vector3(-12, 0, 8)],
		[Vector3(6.3, 0, -6), Vector3(15, 0, -6)], [Vector3(6.3, 0, -1), Vector3(15, 0, -1)], [Vector3(6.3, 0, 4), Vector3(15, 0, 4)], [Vector3(6.3, 0, 8), Vector3(13, 0, 8)],
		[Vector3(8, 0, -8.5), Vector3(8, 0, 8)], [Vector3(13, 0, -8.5), Vector3(13, 0, 8)], [Vector3(13, 0, 8), Vector3(15.5, 0, 10)],
	]
	for road in roads: _add_road(road[0], road[1])
	_add_bridge(Vector3(1.75, 0, -1), Vector3(6.45, 0, -1))
	_add_bridge(Vector3(1.75, 0, 4), Vector3(6.45, 0, 4))
	_add_roundabout(Vector3(-7, 0, -1))
	for point in [Vector3(-12,0,-6),Vector3(-12,0,-1),Vector3(-12,0,4),Vector3(-12,0,8),Vector3(-7,0,-6),Vector3(-7,0,4),Vector3(-7,0,8),Vector3(-2,0,-6),Vector3(-2,0,-1),Vector3(-2,0,4),Vector3(-2,0,8),Vector3(8,0,-6),Vector3(8,0,-1),Vector3(8,0,4),Vector3(8,0,8),Vector3(13,0,-6),Vector3(13,0,-1),Vector3(13,0,4),Vector3(13,0,8)]:
		_add_intersection(point)


func _add_road(start: Vector3, end: Vector3) -> void:
	var shadow_offset := Vector3(0.28, 0.09, 0.3)
	_add(MoldShape.line_3d(start + shadow_offset, end + shadow_offset, 0.68), MoldStyle.transparent(Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.26)), Vector3.ZERO, Quaternion.IDENTITY, Vector3.ONE, MoldRenderState.new(1, -2, MoldRenderState.DepthTest.LESS_EQUAL, MoldRenderState.DepthWrite.DISABLED))
	_add(MoldShape.line_3d(start + Vector3.UP * 0.16, end + Vector3.UP * 0.16, 0.56), MoldStyle.opaque(ROAD_EDGE), Vector3.ZERO)
	_add(MoldShape.line_3d(start + Vector3.UP * 0.29, end + Vector3.UP * 0.29, 0.42), MoldStyle.opaque(ROAD), Vector3.ZERO)


func _add_intersection(position: Vector3) -> void:
	_add(MoldShape.cylinder(0.46, 0.08, 0.48, MoldShape.Detail.LOW), MoldStyle.opaque(ROAD_EDGE), position + Vector3.UP * 0.47)
	_add(MoldShape.cylinder(0.39, 0.06, 0.48, MoldShape.Detail.LOW), MoldStyle.opaque(ROAD), position + Vector3.UP * 0.54)


func _add_roundabout(center: Vector3) -> void:
	_add(MoldShape.cylinder(1.18, 0.08, 0.48, MoldShape.Detail.LOW), MoldStyle.opaque(ROAD_EDGE), center + Vector3.UP * 0.47)
	_add(MoldShape.cylinder(1.02, 0.06, 0.48, MoldShape.Detail.LOW), MoldStyle.opaque(ROAD), center + Vector3.UP * 0.54)
	_add(MoldShape.cylinder(0.48, 0.10, 0.48, MoldShape.Detail.LOW), MoldStyle.dual_gradient(PARK_DARK, PARK, 0.12), center + Vector3.UP * 0.62)
	_add(MoldShape.ring(0.68, 0.045), MoldStyle.opaque(ROAD_EDGE), center + Vector3.UP * 0.69, Quaternion(Vector3.RIGHT, -PI * 0.5))


func _add_bridge(start: Vector3, end: Vector3) -> void:
	var lifted_start := start + Vector3.UP * 0.58
	var lifted_end := end + Vector3.UP * 0.58
	_add(MoldShape.line_3d(lifted_start + Vector3(0.28,-0.18,0.3), lifted_end + Vector3(0.28,-0.18,0.3), 0.75), MoldStyle.transparent(Color(SHADOW.r,SHADOW.g,SHADOW.b,0.32)), Vector3.ZERO)
	_add(MoldShape.line_3d(lifted_start, lifted_end, 0.64), MoldStyle.opaque(ROAD_EDGE), Vector3.ZERO)
	_add(MoldShape.line_3d(lifted_start + Vector3.UP*0.13, lifted_end + Vector3.UP*0.13, 0.48), MoldStyle.opaque(ROAD), Vector3.ZERO)
	for side in [-1, 1]:
		var lateral: Vector3 = Vector3.FORWARD * (side * 0.34)
		_add(MoldShape.line_3d(lifted_start+lateral+Vector3.UP*0.42, lifted_end+lateral+Vector3.UP*0.42, 0.035, 0.0, MoldShape.Detail.LOW), MoldStyle.opaque(INK), Vector3.ZERO)


func _create_blocks() -> void:
	var destinations := [[Vector3(-9.5,0,-4.45),PINK_DEEP,PINK,3],[Vector3(-3.55,0,2.4),YELLOW_DEEP,YELLOW,3],[Vector3(-9.2,0,6.45),BLUE_DEEP,BLUE,2],[Vector3(10.4,0,-3.9),TEAL_DEEP,TEAL,3],[Vector3(10.45,0,6.3),BLUE_DEEP,BLUE,3],[Vector3(14.55,0,2.1),PINK_DEEP,PINK,2]]
	for data in destinations: _add_destination(data[0],data[1],data[2],data[3])
	var homes := [[-14,-4.7,PINK_DEEP,PINK,-14,-6],[-11,-7.4,BLUE_DEEP,BLUE,-11,-6],[-8.6,-4.8,PINK_DEEP,PINK,-8.6,-6],[-5.1,-7.25,TEAL_DEEP,TEAL,-5.1,-6],[-0.6,-4.8,YELLOW_DEEP,YELLOW,-0.6,-6],[-14.1,0.7,BLUE_DEEP,BLUE,-14.1,-1],[-10.1,2.1,PINK_DEEP,PINK,-10.1,4],[-5.2,2.2,YELLOW_DEEP,YELLOW,-5.2,4],[-0.55,0.8,TEAL_DEEP,TEAL,-0.55,-1],[-14.2,6.3,PINK_DEEP,PINK,-14.2,4],[-5.3,6.5,BLUE_DEEP,BLUE,-5.3,8],[-0.5,6.4,TEAL_DEEP,TEAL,-0.5,8],[7,-7.4,YELLOW_DEEP,YELLOW,8,-7.4],[10.3,-4.55,TEAL_DEEP,TEAL,10.3,-6],[14.5,-7.3,PINK_DEEP,PINK,13,-7.3],[7,0.6,BLUE_DEEP,BLUE,8,0.6],[10.6,1.4,PINK_DEEP,PINK,10.6,-1],[14.8,0.7,YELLOW_DEEP,YELLOW,14.8,-1],[7,6.2,TEAL_DEEP,TEAL,8,6.2],[12.1,6,BLUE_DEEP,BLUE,12.1,8],[15,6.1,PINK_DEEP,PINK,13,6.1]]
	for h in homes: _add_home(Vector3(h[0],0,h[1]),h[2],h[3],Vector3(h[4],0,h[5]))


func _add_home(position: Vector3, bottom: Color, top: Color, road_point: Vector3) -> void:
	_add_driveway(position, road_point)
	_add(MoldShape.cuboid(Vector3(0.82,0.09,0.78),0.34,MoldShape.Detail.LOW), MoldStyle.transparent(Color(SHADOW.r,SHADOW.g,SHADOW.b,0.28)), position+Vector3(0.32,0.17,0.32))
	_add(MoldShape.cuboid(Vector3(0.78,0.72,0.74),0.2,MoldShape.Detail.LOW), MoldStyle.dual_gradient(bottom,top,0.34), position+Vector3.UP*0.54)
	_add(MoldShape.cuboid(Vector3(0.8,0.12,0.76),0.22,MoldShape.Detail.LOW), MoldStyle.opaque(top), position+Vector3.UP*0.94)


func _add_destination(position: Vector3, bottom: Color, top: Color, pins: int) -> void:
	_add(MoldShape.cuboid(Vector3(2.65,0.09,2.3),0.38,MoldShape.Detail.LOW), MoldStyle.transparent(Color(SHADOW.r,SHADOW.g,SHADOW.b,0.32)), position+Vector3(0.42,0.15,0.42))
	_add(MoldShape.cuboid(Vector3(2.65,0.12,2.3),0.36,MoldShape.Detail.LOW), MoldStyle.opaque(ROAD), position+Vector3.UP*0.18)
	_add(MoldShape.cuboid(Vector3(1.56,1.15,1.5),0.22,MoldShape.Detail.LOW), MoldStyle.dual_gradient(bottom,top,0.48), position+Vector3.UP*0.78)
	_add(MoldShape.cuboid(Vector3(1.62,0.13,1.55),0.24,MoldShape.Detail.LOW), MoldStyle.opaque(top), position+Vector3.UP*1.42)
	for index in pins:
		var x := (index-(pins-1)*0.5)*0.38
		_add(MoldShape.cylinder(0.14,0.08,0.45,MoldShape.Detail.LOW),MoldStyle.opaque(INK),position+Vector3(x,1.56,0.02))
		_add(MoldShape.cylinder(0.072,0.09,0.45,MoldShape.Detail.LOW),MoldStyle.opaque(ROAD),position+Vector3(x,1.61,0.02))
	var pulse := _add(MoldShape.ring(0.92,0.055),MoldStyle.transparent(Color(1,1,1,0.5)),position+Vector3.UP*1.55,Quaternion(Vector3.RIGHT,-PI*0.5),Vector3.ONE,MoldRenderState.new(1,8,MoldRenderState.DepthTest.ALWAYS,MoldRenderState.DepthWrite.DISABLED))
	pulses.append(pulse)


func _add_driveway(building: Vector3, road_point: Vector3) -> void:
	var start := Vector3(building.x,0.21,building.z)
	var end := Vector3(road_point.x,0.21,road_point.z)
	if start.distance_squared_to(end)<0.05:return
	_add(MoldShape.line_3d(start,end,0.34),MoldStyle.opaque(ROAD_EDGE),Vector3.ZERO)
	_add(MoldShape.line_3d(start+Vector3.UP*0.09,end+Vector3.UP*0.09,0.24),MoldStyle.opaque(ROAD),Vector3.ZERO)


func _create_motorway() -> void:
	var path := [Vector3(-16,1.35,8.9),Vector3(-10,1.42,6.9),Vector3(-3.8,1.5,4.2),Vector3(3.7,1.58,1.8),Vector3(10.2,1.48,-1.2),Vector3(16,1.38,-4.8)]
	var path_count:=path.size()
	for index in path_count-1:
		var start:Vector3=path[index];var end:Vector3=path[index+1]
		_add(MoldShape.line_3d(start+Vector3(0.42,-0.46,0.48),end+Vector3(0.42,-0.46,0.48),0.82),MoldStyle.transparent(Color(SHADOW.r,SHADOW.g,SHADOW.b,0.34)),Vector3.ZERO)
		_add(MoldShape.line_3d(start,end,0.72),MoldStyle.opaque(MOTORWAY_EDGE),Vector3.ZERO)
		_add(MoldShape.line_3d(start+Vector3.UP*0.11,end+Vector3.UP*0.11,0.58),MoldStyle.dual_gradient(MOTORWAY,Color("fff1b3"),0.34),Vector3.ZERO)
	for point in path:_add(MoldShape.cylinder(0.37,0.06,0.34,MoldShape.Detail.LOW),MoldStyle.dual_gradient(MOTORWAY,Color("fff1b3"),0.34),point+Vector3.UP*0.43)


func _create_traffic() -> void:
	var west := [Vector3(-12,.62,-6),Vector3(-7,.62,-6),Vector3(-2,.62,-6),Vector3(-2,.62,-1),Vector3(-2,.62,4),Vector3(-7,.62,4),Vector3(-12,.62,4),Vector3(-12,.62,-1)]
	var east := [Vector3(8,.62,-6),Vector3(13,.62,-6),Vector3(13,.62,-1),Vector3(13,.62,4),Vector3(8,.62,4),Vector3(8,.62,-1)]
	var cross := [Vector3(-12,.62,-1),Vector3(-7.9,.62,-1),Vector3(-6.1,.62,-1),Vector3(-2,.62,-1),Vector3(1.75,1.06,-1),Vector3(6.45,1.06,-1),Vector3(8,.62,-1),Vector3(13,.62,-1),Vector3(13,.62,4),Vector3(8,.62,4),Vector3(6.45,1.06,4),Vector3(1.75,1.06,4),Vector3(-2,.62,4),Vector3(-7,.62,4),Vector3(-12,.62,4)]
	var highway := [Vector3(-16,1.87,8.76),Vector3(-10,1.94,6.76),Vector3(-3.8,2.02,4.06),Vector3(3.7,2.1,1.66),Vector3(10.2,2,-1.34),Vector3(16,1.9,-4.94),Vector3(16,1.9,-4.56),Vector3(10.2,2,-.86),Vector3(3.7,2.1,2.14),Vector3(-3.8,2.02,4.54),Vector3(-10,1.94,7.14),Vector3(-16,1.87,9.14)]
	var colors := [PINK,BLUE,TEAL,YELLOW]
	for index in 10:_add_car(colors[index%4],CANVAS,west,1.65+(index%3)*.14,index*3.15)
	for index in 8:_add_car(colors[(index+1)%4],CANVAS,east,1.72+(index%2)*.17,index*3.6)
	for index in 10:_add_car(colors[(index+2)%4],CANVAS,cross,1.82+(index%3)*.12,index*4.2)
	for index in 7:_add_car(colors[index%4],MOTORWAY,highway,2.45+(index%2)*.22,index*5.0)


func _add_car(color:Color,roof_color:Color,route:Array,speed:float,offset:float)->void:
	var body:=_add(MoldShape.cuboid(Vector3(.46,.18,.26),.78,MoldShape.Detail.LOW),MoldStyle.dual_gradient(color.darkened(.18),color,.34),route[0])
	var roof:=_add(MoldShape.cuboid(Vector3(.23,.12,.22),.72,MoldShape.Detail.LOW),MoldStyle.dual_gradient(roof_color.darkened(.12),roof_color,.28),route[0]+Vector3.UP*.13)
	cars.append({"body":body,"roof":roof,"route":route,"speed":speed,"offset":offset})


func _animate_car(car:Dictionary,distance:float)->void:
	var route:Array=car.route
	var total:=0.0;var route_count:=route.size()
	for index in route_count:total+=(route[index] as Vector3).distance_to(route[(index+1)%route_count])
	var remaining:=fposmod(distance,total)
	for index in route_count:
		var start:Vector3=route[index];var end:Vector3=route[(index+1)%route_count]
		var length:=start.distance_to(end)
		if remaining<=length:
			var position:=start.lerp(end,remaining/length);var direction:=(end-start).normalized();var rotation:=Quaternion(Vector3.UP,atan2(-direction.z,direction.x))
			car.body.set_transform(position,rotation,Vector3.ONE);car.roof.set_transform(position+Vector3.UP*.13,rotation,Vector3.ONE)
			return
		remaining-=length
	var position:Vector3=route[0];var direction:Vector3=(route[1]-route[0]).normalized();var rotation:=Quaternion(Vector3.UP,atan2(-direction.z,direction.x))
	car.body.set_transform(position,rotation,Vector3.ONE);car.roof.set_transform(position+Vector3.UP*.13,rotation,Vector3.ONE)


func _add(shape:MoldShape,style:MoldStyle,position:Vector3,rotation:Quaternion=Quaternion.IDENTITY,scale:Vector3=Vector3.ONE,state:MoldRenderState=null)->MoldHandle:
	var handle:=world.create(shape,style,state)
	handle.set_transform(position,rotation,scale)
	handles.append(handle)
	return handle


func _exit_tree()->void:
	for handle in handles:
		if handle and handle.is_valid:handle.release()
	if world:world.dispose()
	world=null
