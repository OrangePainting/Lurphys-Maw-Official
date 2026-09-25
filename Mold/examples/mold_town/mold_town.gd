extends Node3D

const ORBIT_SENSITIVITY := 0.006
const PAN_SENSITIVITY := 0.0012
const CAMERA_DISTANCE := 36.0
const DEFAULT_FOCUS := Vector3(0.0, 2.0, 0.0)
const DEFAULT_YAW := 0.76
const DEFAULT_PITCH := 0.56
const DEFAULT_SIZE := 22.5
const BUILD_PUNCH_DURATION := 0.24
const BUILD_PUNCH_STRENGTH := 0.16

const WATER_LOW := Color("55afc7")
const WATER_HIGH := Color("8ed9e3")
const FOAM := Color("ddf7f2")
const STONE_LOW := Color("b8aa98")
const STONE_HIGH := Color("e8dac1")
const MORTAR := Color("f8ebd3")
const ROOF_DARK := Color("713f54")
const ROOF_LIGHT := Color("c96b72")
const WINDOW := Color("24465a")
const WINDOW_GLOW := Color("ffe18a")
const GREEN_LOW := Color("4b846d")
const GREEN_HIGH := Color("8ecf91")
const INK := Color("303c48")
const WALL_PALETTE := [
	[Color("b34f58"), Color("f07978")], [Color("c96c42"), Color("f4a05e")],
	[Color("c99b43"), Color("f0cf68")], [Color("3e7b7f"), Color("62b9b1")],
	[Color("3e668b"), Color("6e9bc1")], [Color("76558a"), Color("ae7eb2")],
	[Color("b86c79"), Color("e9a0a7")], [Color("d6c29d"), Color("f0dfc0")],
]

enum Interaction { NONE, PENDING_BUILD, PENDING_REMOVE, ORBIT, PAN }

var world: MoldRuntimeInstance
@onready var camera: Camera3D = $Camera3D

var handles: Array[MoldHandle] = []
var lots: Dictionary = {}
var floaters: Array[Dictionary] = []
var hover_ring: MoldHandle
var camera_focus := DEFAULT_FOCUS
var target_focus := DEFAULT_FOCUS
var camera_yaw := DEFAULT_YAW
var target_yaw := DEFAULT_YAW
var camera_pitch := DEFAULT_PITCH
var target_pitch := DEFAULT_PITCH
var target_size := DEFAULT_SIZE
var interaction := Interaction.NONE
var drag_distance := 0.0


func _ready() -> void:
	var settings := MoldWorldSettings.new()
	settings.lod_mode = MoldWorldSettings.LodMode.CONTINUOUS
	settings.lod_transition_width = 0.15
	world = MoldRuntime.create_instance(self, settings)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = DEFAULT_SIZE
	camera.near = 1.0
	camera.far = 92.0
	_update_camera_transform()
	world.prewarm([
		MoldShape.cuboid(Vector3.ONE, 0.36, MoldShape.Detail.LOW),
		MoldShape.line_3d(Vector3.ZERO, Vector3.ONE, 0.1),
		MoldShape.cylinder(1.0, 1.0, 0.42, MoldShape.Detail.LOW),
		MoldShape.line_3d(Vector3.ZERO, Vector3.ONE, 0.1, 0.0, MoldShape.Detail.LOW),
		MoldShape.regular_prism(8, 1.0, 1.0, 0.34, MoldShape.Detail.LOW),
		MoldShape.cone(1.0, 1.0, MoldShape.Detail.LOW), MoldShape.sphere(1.0, MoldShape.Detail.LOW),
		MoldShape.hemisphere(1.0, true, MoldShape.Detail.LOW), MoldShape.ring(1.0, 0.1),
	])
	_create_town()
	hover_ring = _add(MoldShape.ring(0.76, 0.065), MoldStyle.transparent(Color(1,1,1,0.78)), Vector3.ZERO, Quaternion(Vector3.RIGHT,-PI*0.5), Vector3.ONE, MoldRenderState.new(1,12,MoldRenderState.DepthTest.ALWAYS,MoldRenderState.DepthWrite.DISABLED))
	hover_ring.set_visible(false)
	world.clear_unused_meshes()


func _process(delta: float) -> void:
	_animate_camera(delta)
	_animate_build_punches(delta)
	var time := Time.get_ticks_msec() * 0.001
	for floater in floaters:
		var wave: float = sin(time * 1.45 + floater.phase) * floater.amount
		floater.handle.set_transform(floater.position + Vector3.UP * wave, floater.rotation, Vector3.ONE)
	_update_hover(get_viewport().get_mouse_position(), time)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_size = clampf(target_size - 1.45 * event.factor, 12.0, 34.0); get_viewport().set_input_as_handled(); return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_size = clampf(target_size + 1.45 * event.factor, 12.0, 34.0); get_viewport().set_input_as_handled(); return
		if event.pressed:
			drag_distance = 0.0
			if event.button_index == MOUSE_BUTTON_LEFT: interaction = Interaction.PAN if event.shift_pressed else Interaction.PENDING_BUILD
			elif event.button_index == MOUSE_BUTTON_RIGHT: interaction = Interaction.PENDING_REMOVE
			elif event.button_index == MOUSE_BUTTON_MIDDLE: interaction = Interaction.PAN
		else:
			if event.button_index == MOUSE_BUTTON_LEFT and interaction == Interaction.PENDING_BUILD: _grow_lot(_find_lot(event.position))
			elif event.button_index == MOUSE_BUTTON_RIGHT and interaction == Interaction.PENDING_REMOVE: _shrink_lot(_find_lot(event.position))
			interaction = Interaction.NONE
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]: get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		drag_distance += event.relative.length()
		if drag_distance > 5.0:
			if interaction == Interaction.PENDING_BUILD: interaction = Interaction.ORBIT
			if interaction == Interaction.PENDING_REMOVE: interaction = Interaction.PAN
		if interaction == Interaction.ORBIT: _orbit(event.relative)
		elif interaction == Interaction.PAN: _pan(event.relative)
		if interaction in [Interaction.ORBIT,Interaction.PAN]: get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed: interaction=Interaction.PENDING_BUILD;drag_distance=0.0
		else:
			if interaction==Interaction.PENDING_BUILD:_grow_lot(_find_lot(event.position))
			interaction=Interaction.NONE
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		drag_distance+=event.relative.length()
		if drag_distance>5.0:interaction=Interaction.ORBIT
		if interaction==Interaction.ORBIT:_orbit(event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_R:
		target_focus=DEFAULT_FOCUS;target_yaw=DEFAULT_YAW;target_pitch=DEFAULT_PITCH;target_size=DEFAULT_SIZE
		get_viewport().set_input_as_handled()


func _orbit(relative:Vector2)->void:
	target_yaw=wrapf(target_yaw-relative.x*ORBIT_SENSITIVITY,-PI,PI)
	target_pitch=clampf(target_pitch+relative.y*ORBIT_SENSITIVITY,.24,1.14)


func _pan(relative:Vector2)->void:
	var scale:=target_size*PAN_SENSITIVITY
	var right:=Vector3(cos(target_yaw),0,-sin(target_yaw));var forward:=Vector3(-sin(target_yaw),0,-cos(target_yaw))
	target_focus+=right*(-relative.x*scale)+forward*(relative.y*scale)
	target_focus.x=clampf(target_focus.x,-10,10);target_focus.z=clampf(target_focus.z,-8,8)


func _animate_camera(delta:float)->void:
	var blend:=1.0-exp(-delta*12.0)
	camera_yaw=lerp_angle(camera_yaw,target_yaw,blend);camera_pitch=lerpf(camera_pitch,target_pitch,blend)
	camera_focus=camera_focus.lerp(target_focus,blend);camera.size=lerpf(camera.size,target_size,blend)
	_update_camera_transform()


func _update_camera_transform()->void:
	var horizontal:=cos(camera_pitch)
	var direction:=Vector3(sin(camera_yaw)*horizontal,sin(camera_pitch),cos(camera_yaw)*horizontal)
	camera.position=camera_focus+direction*CAMERA_DISTANCE;camera.look_at(camera_focus,Vector3.UP)


func _create_town()->void:
	_add(MoldShape.cuboid(Vector3(31,.5,23),.18,MoldShape.Detail.LOW),MoldStyle.dual_gradient(WATER_LOW,WATER_HIGH,.28),Vector3(0,-.24,0))
	for band in range(-5,6):
		var z:=band*1.75;var drift:=.6 if band%2==0 else -.5
		for segment in 10:
			var x:float=-13.5+segment*3.0+drift
			_add(MoldShape.line_3d(Vector3(x,.08,z),Vector3(x+1.15,.08,z+.08),.025,0.0,MoldShape.Detail.LOW),MoldStyle.transparent(Color(FOAM.r,FOAM.g,FOAM.b,.28)),Vector3.ZERO,Quaternion.IDENTITY,Vector3.ONE,MoldRenderState.new(1,-3,MoldRenderState.DepthTest.LESS_EQUAL,MoldRenderState.DepthWrite.DISABLED))
	_create_lots();_seed_buildings();_create_harbor()


func _create_lots()->void:
	for z in range(-5,6):
		for x in range(-7,8):
			if x*x/49.0+z*z/25.0>1.0 or _is_canal(x,z) or _unit_hash(x,z,4)<.055:continue
			var row_offset:=0.0 if z%2==0 else .71
			var center:=Vector3(x*1.46+row_offset+(_unit_hash(x,z,9)-.5)*.14,0,z*1.27+(_unit_hash(x,z,12)-.5)*.12)
			lots[Vector2i(x,z)]={"coordinate":Vector2i(x,z),"center":center,"palette":int(_unit_hash(x,z,15)*WALL_PALETTE.size())%WALL_PALETTE.size(),"variant":int(_unit_hash(x,z,18)*700.0)%7,"level":0,"punch_elapsed":-1.0,"punch_pivot":center,"punch_parts":[],"building":[]}
	for coordinate in lots:
		var lot = lots[coordinate]
		_add_connections(lot)
		_add(MoldShape.regular_prism(8,.69,.34,.34,MoldShape.Detail.LOW),MoldStyle.dual_gradient(STONE_LOW,STONE_HIGH,.18),lot.center+Vector3.UP*.19,Quaternion(Vector3.UP,PI*.125))
		_add(MoldShape.regular_prism(8,.61,.055,.3,MoldShape.Detail.LOW),MoldStyle.opaque(MORTAR),lot.center+Vector3.UP*.39,Quaternion(Vector3.UP,PI*.125))


func _is_canal(x:int,z:int)->bool:
	return (x==0 and z>=-5 and z<=-1) or (x==1 and z>=1 and z<=4) or (z==1 and x>=-6 and x<=-3)


func _add_connections(lot:Dictionary)->void:
	for coordinate in [lot.coordinate+Vector2i.RIGHT,lot.coordinate+Vector2i.DOWN,lot.coordinate+Vector2i(-1,1)]:
		if not lots.has(coordinate):continue
		_add(MoldShape.line_3d(lot.center+Vector3.UP*.05,lots[coordinate].center+Vector3.UP*.05,.48),MoldStyle.dual_gradient(STONE_LOW.darkened(.08),STONE_HIGH,.14),Vector3.ZERO)


func _seed_buildings()->void:
	for coordinate in lots:
		var lot = lots[coordinate]
		var plaza:bool=(lot.coordinate.x+lot.coordinate.y*2)%11==0
		if not plaza and _unit_hash(lot.coordinate.x,lot.coordinate.y,23)>.25:
			var bias:float=1.0-clampf(lot.center.length()/12.0,0,1)
			lot.level=clampi(1+int(_unit_hash(lot.coordinate.x,lot.coordinate.y,27)*(3.0+bias*2.0)),1,5)
			_rebuild_building(lot)
		else:_add_plaza(lot)


func _add_plaza(lot:Dictionary)->void:
	if lot.variant%2==0:
		_add(MoldShape.cylinder(.28,.18,.42,MoldShape.Detail.LOW),MoldStyle.dual_gradient(STONE_LOW,STONE_HIGH,.14),lot.center+Vector3.UP*.5)
		_add(MoldShape.sphere(.11,MoldShape.Detail.LOW),MoldStyle.additive(Color(FOAM.r,FOAM.g,FOAM.b,.8)),lot.center+Vector3.UP*.72)
	else:_add_tree(lot.center+Vector3.UP*.42,.74+lot.variant*.025)


func _add_tree(base:Vector3,height:float)->void:
	_add(MoldShape.cylinder(.08,height*.56,.35,MoldShape.Detail.LOW),MoldStyle.dual_gradient(ROOF_DARK,ROOF_LIGHT,.12),base+Vector3.UP*(height*.28))
	_add(MoldShape.sphere(.34,MoldShape.Detail.LOW),MoldStyle.dual_gradient(GREEN_LOW,GREEN_HIGH,.2),base+Vector3.UP*(height*.74))


func _grow_lot(lot)->void:
	if lot==null or lot.level>=5:return
	var new_floor:int=lot.level
	if new_floor==0:lot.palette=(lot.palette+1)%WALL_PALETTE.size()
	lot.level+=1;_rebuild_building(lot,new_floor);_start_build_punch(lot,new_floor)


func _shrink_lot(lot)->void:
	if lot==null or lot.level<=0:return
	lot.level-=1;_rebuild_building(lot)


func _rebuild_building(lot:Dictionary,punch_floor:int=-1)->void:
	for part in lot.building:
		if part.handle and part.handle.is_valid:part.handle.release()
	lot.building.clear()
	lot.punch_parts.clear()
	lot.punch_elapsed=-1.0
	if lot.level<=0:return
	var colors:Array=WALL_PALETTE[lot.palette];var floor_height:=.68;var first_y:=.77;var arch:bool=lot.level>=2 and lot.variant%4==0
	for floor in lot.level:
		var segment_start:int=lot.building.size()
		var y:float=first_y+floor*floor_height;var width:float=1.12-floor*.018;var depth:float=1.10-floor*.018
		if floor==0 and arch:_add_arch(lot,colors[0],colors[1],y,width,depth)
		elif floor==lot.level-1 and lot.level>=4 and lot.variant%3==1:_add_tower_floor(lot,colors[0],colors[1],y)
		else:_add_house_floor(lot,colors[0],colors[1],floor,y,width,depth)
		if floor>0 and (floor+lot.variant)%3==0:_add_balcony(lot,y-floor_height*.28,width,depth)
		if floor==punch_floor:
			var segment_end: int = lot.building.size()
			for part_index in range(segment_start,segment_end):lot.punch_parts.append(lot.building[part_index])
	var roof_start:int=lot.building.size()
	_add_roof(lot,first_y+(lot.level-1)*floor_height+floor_height*.58,colors[1])
	if punch_floor>=0:
		var building_count: int = lot.building.size()
		for part_index in range(roof_start,building_count):lot.punch_parts.append(lot.building[part_index])


func _add_house_floor(lot:Dictionary,low:Color,high:Color,floor:int,y:float,width:float,depth:float)->void:
	_add_lot(lot,MoldShape.cuboid(Vector3(width,.68,depth),.28,MoldShape.Detail.LOW),MoldStyle.dual_gradient(low,high,.22),lot.center+Vector3.UP*y)
	if floor==0:
		_add_lot(lot,MoldShape.cuboid(Vector3(.25,.39,.045),.45,MoldShape.Detail.LOW),MoldStyle.dual_gradient(ROOF_DARK.darkened(.2),ROOF_DARK,.12),lot.center+Vector3(0,y-.14,depth*.505))
	_add_windows(lot,y,width,depth,floor)


func _add_arch(lot:Dictionary,low:Color,high:Color,y:float,width:float,depth:float)->void:
	var style:=MoldStyle.dual_gradient(low,high,.22)
	for side in [-1,1]:_add_lot(lot,MoldShape.cuboid(Vector3(.25,.68,depth),.25,MoldShape.Detail.LOW),style,lot.center+Vector3(side*width*.38,y,0))
	_add_lot(lot,MoldShape.cuboid(Vector3(width,.22,depth),.24,MoldShape.Detail.LOW),style,lot.center+Vector3.UP*(y+.28))


func _add_tower_floor(lot:Dictionary,low:Color,high:Color,y:float)->void:
	_add_lot(lot,MoldShape.cylinder(.51,.68,.42,MoldShape.Detail.LOW),MoldStyle.dual_gradient(low,high,.22),lot.center+Vector3.UP*y)
	for direction in 4:
		var angle:=direction*PI*.5;var outward:=Vector3(sin(angle),0,cos(angle))
		_add_lot(lot,MoldShape.cuboid(Vector3(.16,.25,.035),.3,MoldShape.Detail.LOW),MoldStyle.additive(Color(WINDOW_GLOW.r,WINDOW_GLOW.g,WINDOW_GLOW.b,.82)),lot.center+outward*.505+Vector3.UP*(y+.02),Quaternion(Vector3.UP,angle))


func _add_windows(lot:Dictionary,y:float,width:float,depth:float,floor:int)->void:
	var color:=WINDOW if floor%2==0 else WINDOW_GLOW;var style:=MoldStyle.opaque(color) if floor%2==0 else MoldStyle.additive(Color(color.r,color.g,color.b,.78))
	for x in [-.27,.27]:
		_add_lot(lot,MoldShape.cuboid(Vector3(.17,.24,.035),.32,MoldShape.Detail.LOW),style,lot.center+Vector3(x,y+.03,depth*.505))
		_add_lot(lot,MoldShape.cuboid(Vector3(.17,.24,.035),.32,MoldShape.Detail.LOW),style,lot.center+Vector3(x,y+.03,-depth*.505))
	for z in [-.27,.27]:
		_add_lot(lot,MoldShape.cuboid(Vector3(.035,.24,.17),.32,MoldShape.Detail.LOW),style,lot.center+Vector3(width*.505,y+.03,z))
		_add_lot(lot,MoldShape.cuboid(Vector3(.035,.24,.17),.32,MoldShape.Detail.LOW),style,lot.center+Vector3(-width*.505,y+.03,z))


func _add_balcony(lot:Dictionary,y:float,width:float,depth:float)->void:
	var front:Vector3=lot.center+Vector3(0,y,depth*.61)
	_add_lot(lot,MoldShape.cuboid(Vector3(width*.72,.08,.28),.26,MoldShape.Detail.LOW),MoldStyle.dual_gradient(STONE_LOW,STONE_HIGH,.12),front)
	for post in [-1,0,1]:_add_lot(lot,MoldShape.cylinder(.026,.29,.2,MoldShape.Detail.LOW),MoldStyle.opaque(INK),front+Vector3(post*width*.29,.18,.12))
	_add_lot(lot,MoldShape.line_3d(front+Vector3(-width*.31,.33,.12),front+Vector3(width*.31,.33,.12),.025,0.0,MoldShape.Detail.LOW),MoldStyle.opaque(INK),Vector3.ZERO)


func _add_roof(lot:Dictionary,y:float,wall_top:Color)->void:
	var roof:int=lot.variant%4
	if roof==0 or (lot.level>=4 and roof==1):_add_lot(lot,MoldShape.cone(.74,.72,MoldShape.Detail.LOW),MoldStyle.dual_gradient(ROOF_DARK,ROOF_LIGHT,.24),lot.center+Vector3.UP*(y+.33))
	elif roof==2:
		_add_lot(lot,MoldShape.hemisphere(.67,true,MoldShape.Detail.LOW),MoldStyle.dual_gradient(ROOF_DARK,ROOF_LIGHT,.22),lot.center+Vector3.UP*(y+.08))
		_add_lot(lot,MoldShape.sphere(.09,MoldShape.Detail.LOW),MoldStyle.additive(WINDOW_GLOW),lot.center+Vector3.UP*(y+.71))
	else:
		_add_lot(lot,MoldShape.cuboid(Vector3(1.22,.14,1.2),.32,MoldShape.Detail.LOW),MoldStyle.dual_gradient(wall_top.darkened(.18),wall_top,.16),lot.center+Vector3.UP*(y+.04))
		_add_lot(lot,MoldShape.cylinder(.09,.48,.28,MoldShape.Detail.LOW),MoldStyle.dual_gradient(STONE_LOW,MORTAR,.14),lot.center+Vector3(.3,y+.31,-.23))


func _create_harbor()->void:
	_add_boat(Vector3(-10.8,.18,-5.5),.48,.3);_add_boat(Vector3(10.4,.18,5.7),-2.2,1.8);_add_boat(Vector3(8.8,.18,-6.8),2.4,3.2);_add_boat(Vector3(-11.6,.18,4.8),-.8,4.5)
	for start in [Vector3(-8.8,.28,-5.3),Vector3(8.1,.28,5.4),Vector3(9.2,.28,-5.5),Vector3(-9.3,.28,4.9)]:
		var end:Vector3=start+Vector3(start.x,0,start.z).normalized()*1.8
		_add(MoldShape.line_3d(start,end,.34),MoldStyle.dual_gradient(ROOF_DARK.darkened(.2),ROOF_LIGHT.darkened(.12),.12),Vector3.ZERO)


func _add_boat(position:Vector3,yaw:float,phase:float)->void:
	var rotation:=Quaternion(Vector3.UP,yaw)
	var hull:=_add(MoldShape.cuboid(Vector3(1.05,.22,.42),.82,MoldShape.Detail.LOW),MoldStyle.dual_gradient(ROOF_DARK,ROOF_LIGHT,.18),position,rotation)
	var mast:=_add(MoldShape.cylinder(.035,.9,.2,MoldShape.Detail.LOW),MoldStyle.opaque(INK),position+Vector3.UP*.48,rotation)
	var sail_rotation:=rotation*Quaternion(Vector3.RIGHT,PI*.5)
	var sail:=_add(MoldShape.regular_prism(3,.34,.055,0,MoldShape.Detail.LOW),MoldStyle.dual_gradient(MORTAR,FOAM,.2),position+Vector3(.05,.55,0),sail_rotation)
	for data in [[hull,position,rotation],[mast,position+Vector3.UP*.48,rotation],[sail,position+Vector3(.05,.55,0),sail_rotation]]:floaters.append({"handle":data[0],"position":data[1],"rotation":data[2],"phase":phase,"amount":.045})


func _find_lot(screen:Vector2):
	var closest=null;var closest_distance:=INF;var radius:=clampf(38.0*DEFAULT_SIZE/camera.size,25,58)
	for coordinate in lots:
		var lot = lots[coordinate]
		var point:Vector3=lot.center+Vector3.UP*(.42+lot.level*.34)
		if camera.is_position_behind(point):continue
		var distance:=camera.unproject_position(point).distance_squared_to(screen)
		if distance<closest_distance and distance<=radius*radius:closest_distance=distance;closest=lot
	return closest


func _update_hover(mouse:Vector2,time:float)->void:
	var lot=_find_lot(mouse)
	if lot==null or interaction in [Interaction.ORBIT,Interaction.PAN]:hover_ring.set_visible(false);return
	hover_ring.set_visible(true);hover_ring.set_transform(lot.center+Vector3.UP*.43,Quaternion(Vector3.RIGHT,-PI*.5),Vector3.ONE*(1.0+sin(time*4.0)*.07))


func _start_build_punch(lot:Dictionary,floor:int)->void:
	lot.punch_elapsed=0.0
	lot.punch_pivot=lot.center+Vector3.UP*(.43+floor*.68)
	_apply_build_scale(lot,1.0)


func _animate_build_punches(delta:float)->void:
	for coordinate in lots:
		var lot = lots[coordinate]
		if lot.punch_elapsed<0.0:continue
		lot.punch_elapsed+=delta
		var progress:float=clampf(lot.punch_elapsed/BUILD_PUNCH_DURATION,0.0,1.0)
		_apply_build_scale(lot,_build_punch_scale(progress))
		if progress>=1.0:lot.punch_elapsed=-1.0


func _build_punch_scale(progress:float)->float:
	const PEAK_TIME:=.36
	var peak_scale:=1.0+BUILD_PUNCH_STRENGTH
	if progress<PEAK_TIME:return lerpf(1.0,peak_scale,_out_quad(progress/PEAK_TIME))
	return lerpf(peak_scale,1.0,_out_quad((progress-PEAK_TIME)/(1.0-PEAK_TIME)))


func _out_quad(progress:float)->float:
	return 1.0-(1.0-progress)*(1.0-progress)


func _apply_build_scale(lot:Dictionary,scale:float)->void:
	for part in lot.punch_parts:
		var position:Vector3=lot.punch_pivot+(part.position-lot.punch_pivot)*scale
		part.handle.set_transform(position,part.rotation,part.scale*scale)


func _unit_hash(x:int,z:int,salt:int=0)->float:
	return fposmod(sin(x*127.1+z*311.7+salt*74.7)*43758.5453,1.0)


func _add_lot(lot:Dictionary,shape:MoldShape,style:MoldStyle,position:Vector3,rotation:Quaternion=Quaternion.IDENTITY,scale:Vector3=Vector3.ONE,state:MoldRenderState=null)->MoldHandle:
	var handle:=_add(shape,style,position,rotation,scale,state);lot.building.append({"handle":handle,"position":position,"rotation":rotation,"scale":scale});return handle


func _add(shape:MoldShape,style:MoldStyle,position:Vector3,rotation:Quaternion=Quaternion.IDENTITY,scale:Vector3=Vector3.ONE,state:MoldRenderState=null)->MoldHandle:
	var handle:=world.create(shape,style,state);handle.set_transform(position,rotation,scale);handles.append(handle);return handle


func _exit_tree()->void:
	for handle in handles:
		if handle and handle.is_valid:handle.release()
	if world:world.dispose()
	world=null
