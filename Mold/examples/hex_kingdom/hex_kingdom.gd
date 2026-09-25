extends Node3D

const HEX_RADIUS:=1.36
const MAP_RADIUS:=7
const GROUND_ROTATION:=Quaternion(Vector3.RIGHT,-PI*.5)
const HEX_ROTATION:=Quaternion(Vector3.UP,-PI)
const GROUND_HEX_ROTATION:=HEX_ROTATION*GROUND_ROTATION
const DEFAULT_FOCUS:=Vector3(-2,1,.8)
const DEFAULT_YAW:=.775
const DEFAULT_PITCH:=.52
const DEFAULT_SIZE:=29.5
const CAMERA_DISTANCE:=46.0

const DEEP_INK:=Color("0b0d1c");const PARCHMENT:=Color("f6ddb0");const GOLD:=Color("e8ae45");const GOLD_LIGHT:=Color("fff0a2")
const GRASS:=Color("4d7443");const GRASS_LIGHT:=Color("8eae59");const FOREST:=Color("163f3a");const PINE:=Color("24614f")
const WATER:=Color("276379");const ROCK:=Color("686273");const ROCK_LIGHT:=Color("aaa0a5");const SNOW:=Color("c9c2bd")
const SOIL:=Color("875240");const SOIL_LIGHT:=Color("c78353");const BRICK:=Color("8c3f35");const BRICK_LIGHT:=Color("e17b4f")
const ROYAL:=Color("284862");const ROYAL_LIGHT:=Color("59a4aa");const VIOLET:=Color("553b77");const VIOLET_LIGHT:=Color("b68bd6")
const ENEMY:=Color("8f263d");const ENEMY_LIGHT:=Color("f15c59")

enum Biome{PLAINS,FOREST,WATER,MOUNTAIN,FIELDS,MOOR,SNOW,BURNED}

var world:MoldRuntimeInstance
@onready var camera:Camera3D=$Camera3D
var handles:Array[MoldHandle]=[];var cells:Dictionary={};var units:Array[Dictionary]=[];var spinners:Array[Dictionary]=[];var floaters:Array[Dictionary]=[]
var wind_lines:Array[MoldHandle]=[];var wind_bases:Array[Vector3]=[]
var wind_starts:=PackedVector3Array();var wind_ends:=PackedVector3Array()
var quest_beacon:MoldHandle;var morphing_relic:MoldHandle;var arcane_beacon:MoldHandle;var hidden_scout:MoldHandle;var last_mutation:=-1
var camera_focus:=DEFAULT_FOCUS;var target_focus:=DEFAULT_FOCUS;var camera_yaw:=DEFAULT_YAW;var target_yaw:=DEFAULT_YAW
var camera_pitch:=DEFAULT_PITCH;var target_pitch:=DEFAULT_PITCH;var target_size:=DEFAULT_SIZE
var orbit_dragging:=false;var pan_dragging:=false;var touch_dragging:=false


func _ready()->void:
	var settings:=MoldWorldSettings.new();settings.lod_mode=MoldWorldSettings.LodMode.CONTINUOUS;settings.lod_transition_width=0.15
	world=MoldRuntime.create_instance(self,settings)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=DEFAULT_SIZE;_update_camera()
	world.prewarm([MoldShape.rectangle(Vector2.ONE,.3),MoldShape.rectangle_rim(Vector2.ONE,.1,.3),MoldShape.disc(1),MoldShape.ring(1,.1),MoldShape.regular_polygon(6,1),MoldShape.regular_polygon_rim(6,1,.08),MoldShape.cuboid(Vector3.ONE,.2,MoldShape.Detail.LOW),MoldShape.cylinder(1,1,.2,MoldShape.Detail.LOW),MoldShape.regular_prism(6,1,1,.1,MoldShape.Detail.LOW),MoldShape.cone(1,1,MoldShape.Detail.LOW),MoldShape.sphere(1,MoldShape.Detail.LOW),MoldShape.hemisphere(1,true,MoldShape.Detail.LOW),MoldShape.capsule(.4,1.2,MoldShape.Detail.LOW),MoldShape.line_2d(Vector3.ZERO,Vector3.ONE,.1),MoldShape.line_3d(Vector3.ZERO,Vector3.ONE,.1,.25,MoldShape.Detail.LOW)])
	_create_realm();_create_details();_create_roads();_create_settlements();_create_armies();_create_landmarks();_create_wind();world.clear_unused_meshes()


func _process(delta:float)->void:
	_animate_camera(delta);var time:=Time.get_ticks_msec()*.001;_animate_units(time);_animate_features(time)


func _unhandled_input(event:InputEvent)->void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:orbit_dragging=event.pressed and not event.shift_pressed;pan_dragging=event.pressed and event.shift_pressed
			MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE:pan_dragging=event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:target_size=clampf(target_size-1.6*event.factor,19,38)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:target_size=clampf(target_size+1.6*event.factor,19,38)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if orbit_dragging:_orbit(event.relative)
		if pan_dragging:_pan(event.relative)
		if orbit_dragging or pan_dragging:get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:touch_dragging=event.pressed;get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touch_dragging:_orbit(event.relative);get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_R:
		target_focus=DEFAULT_FOCUS;target_yaw=DEFAULT_YAW;target_pitch=DEFAULT_PITCH;target_size=DEFAULT_SIZE;get_viewport().set_input_as_handled()


func _orbit(relative:Vector2)->void:
	target_yaw=wrapf(target_yaw-relative.x*.006,-PI,PI);target_pitch=clampf(target_pitch+relative.y*.006,.28,1.16)


func _pan(relative:Vector2)->void:
	var scale:=target_size*.0012;var right:=Vector3(cos(target_yaw),0,-sin(target_yaw));var forward:=Vector3(-sin(target_yaw),0,-cos(target_yaw))
	target_focus+=right*(-relative.x*scale)+forward*(relative.y*scale);target_focus.x=clampf(target_focus.x,-12,12);target_focus.z=clampf(target_focus.z,-9,10)


func _animate_camera(delta:float)->void:
	var blend:=1.0-exp(-delta*12.0);camera_yaw=lerp_angle(camera_yaw,target_yaw,blend);camera_pitch=lerpf(camera_pitch,target_pitch,blend);camera_focus=camera_focus.lerp(target_focus,blend);camera.size=lerpf(camera.size,target_size,blend);_update_camera()


func _update_camera()->void:
	var horizontal:=cos(camera_pitch);var direction:=Vector3(sin(camera_yaw)*horizontal,sin(camera_pitch),cos(camera_yaw)*horizontal);camera.position=camera_focus+direction*CAMERA_DISTANCE;camera.look_at(camera_focus,Vector3.UP)


func _create_realm()->void:
	_add(MoldShape.cuboid(Vector3(49,.55,37),.24,MoldShape.Detail.LOW),MoldStyle.dual_gradient(DEEP_INK,Color("302c3f"),.18),Vector3(0,-.58,.4))
	for q in range(-MAP_RADIUS,MAP_RADIUS+1):
		var r_min:=maxi(-MAP_RADIUS,-q-MAP_RADIUS);var r_max:=mini(MAP_RADIUS,-q+MAP_RADIUS)
		for r in range(r_min,r_max+1):
			var axial:=Vector2i(q,r);var center:=_axial_world(axial);var noise:=_hash01(q,r);var biome:=_choose_biome(q,r,noise)
			var height:=.48+noise*.42+(.34 if biome==Biome.MOUNTAIN else 0.0)
			if biome==Biome.WATER:height=.38+noise*.08
			if biome==Biome.SNOW:height+=.16
			var style:=_biome_style(biome)
			var tile:=_add(MoldShape.regular_prism(6,HEX_RADIUS,height,.08,MoldShape.Detail.LOW),style,center+Vector3.UP*(height*.5),HEX_ROTATION)
			var border_color:=Color(.62,.95,.94,.34) if biome==Biome.WATER else Color(1,.83,.56,.26)
			var border:=_add(MoldShape.regular_polygon_rim(6,HEX_RADIUS*.94,.035,.08),MoldStyle.lighten(border_color),center+Vector3.UP*(height+.018),GROUND_HEX_ROTATION,Vector3.ONE,MoldRenderState.new(1,3,MoldRenderState.DepthTest.LESS_EQUAL,MoldRenderState.DepthWrite.DISABLED))
			cells[axial]={"axial":axial,"center":center,"top":height,"biome":biome,"tile":tile,"border":border}


func _biome_style(biome:int)->MoldStyle:
	match biome:
		Biome.FOREST:return MoldStyle.dual_gradient(FOREST,GRASS,.24)
		Biome.WATER:return MoldStyle.opaque(WATER)
		Biome.MOUNTAIN:return MoldStyle.dual_gradient(Color("46434f"),ROCK,.2)
		Biome.FIELDS:return MoldStyle.dual_gradient(SOIL,SOIL_LIGHT,.2)
		Biome.MOOR:return MoldStyle.opaque(Color("5b5a48"))
		Biome.SNOW:return MoldStyle.dual_gradient(ROCK_LIGHT,SNOW,.32)
		Biome.BURNED:return MoldStyle.opaque(Color("4b3534"))
		_:return MoldStyle.dual_gradient(GRASS,GRASS_LIGHT,.22)


func _create_details()->void:
	for coordinate in cells:
		var cell = cells[coordinate]
		var noise:=_hash01(cell.axial.x+91,cell.axial.y-47);var ground:Vector3=cell.center+Vector3.UP*cell.top
		match cell.biome:
			Biome.FOREST:
				_add_pine(ground+Vector3(-.34,0,-.12),.72+noise*.2)
				if noise>.42:_add_pine(ground+Vector3(.38,0,.22),.58+noise*.18)
			Biome.MOUNTAIN:_add_mountain(ground,noise)
			Biome.WATER:_add_water_detail(ground,noise)
			Biome.FIELDS:_add_field(ground,noise)
			Biome.MOOR:_add(MoldShape.hemisphere(.56,false,MoldShape.Detail.LOW),MoldStyle.multiplicative(Color(.28,.2,.32,.42)),ground+Vector3(.12,.02,-.18))
			Biome.SNOW:_add(MoldShape.hemisphere(.92,false,MoldShape.Detail.LOW),MoldStyle.dither(Color(.9,.9,1,.48)),ground+Vector3(0,.04+noise*.08,0),Quaternion.IDENTITY,Vector3(1.1,.28,1))
			Biome.BURNED:_add_burned(ground,noise)
			Biome.PLAINS:
				if noise>.68:_add(MoldShape.sphere(.16,MoldShape.Detail.LOW),MoldStyle.lighten(Color(1,.88,.32,.82)),ground+Vector3(.22,.18,-.18))


func _add_pine(ground:Vector3,scale:float)->void:
	_add(MoldShape.cylinder(.1*scale,.72*scale,.2,MoldShape.Detail.LOW),MoldStyle.dual_gradient(Color("49382e"),SOIL_LIGHT,.25),ground+Vector3.UP*(.36*scale))
	_add(MoldShape.cone(.58*scale,1.42*scale,MoldShape.Detail.LOW),MoldStyle.dual_gradient(FOREST,PINE,.38),ground+Vector3.UP*(1.12*scale))
	_add(MoldShape.cone(.43*scale,1.05*scale,MoldShape.Detail.LOW),MoldStyle.dual_gradient(PINE,GRASS,.34),ground+Vector3.UP*(1.64*scale))


func _add_mountain(ground:Vector3,noise:float)->void:
	var height:=1.65+noise*1.3;_add(MoldShape.cone(.92,height,MoldShape.Detail.LOW),MoldStyle.dual_gradient(Color("3d3c48"),ROCK_LIGHT,.24),ground+Vector3.UP*(height*.5));_add(MoldShape.cone(.43,height*.55,MoldShape.Detail.LOW),MoldStyle.screen(Color(.86,.89,1,.38)),ground+Vector3.UP*(height*.79))
	if noise>.45:_add(MoldShape.sphere(.28,MoldShape.Detail.LOW),MoldStyle.darken(Color(.13,.12,.2,.76)),ground+Vector3(.62,.22,.3))


func _add_water_detail(ground:Vector3,noise:float)->void:
	_add(MoldShape.disc(HEX_RADIUS*.78,.2,TAU*.9),MoldStyle.transparent(Color(.25,.78,.78,.28)),ground+Vector3.UP*.025,GROUND_ROTATION,Vector3.ONE,MoldRenderState.new(1,4,MoldRenderState.DepthTest.LESS_EQUAL,MoldRenderState.DepthWrite.DISABLED))
	if noise>.53:
		var ripple:=_add(MoldShape.ring(.48,.045,.2,TAU*.82),MoldStyle.screen(Color(.68,1,.96,.58)),ground+Vector3(.18,.045,-.12),GROUND_ROTATION);spinners.append({"handle":ripple,"position":ground+Vector3(.18,.045,-.12),"axis":Vector3.UP,"speed":.35,"phase":noise})


func _add_field(ground:Vector3,noise:float)->void:
	var rotation:=GROUND_ROTATION*Quaternion(Vector3.BACK,noise*.3-.15)
	_add(MoldShape.rectangle(Vector2(1.65,.82),.24),MoldStyle.multiplicative(Color(.52,.28,.16,.52)),ground+Vector3.UP*.035,rotation)
	_add(MoldShape.rectangle_rim(Vector2(1.55,.72),.055,.18,MoldDash.new(8,8,.36,noise,MoldDash.Type.NORMAL,.4)),MoldStyle.lighten(Color(1,.74,.32,.62)),ground+Vector3.UP*.055,rotation)


func _add_burned(ground:Vector3,noise:float)->void:
	_add(MoldShape.regular_polygon(6,HEX_RADIUS*.76,.2),MoldStyle.color_burn(Color(.55,.16,.11,.62)),ground+Vector3.UP*.025,GROUND_HEX_ROTATION)
	if noise>.38:
		var ember:=_add(MoldShape.sphere(.15,MoldShape.Detail.LOW),MoldStyle.additive(Color(1,.23,.08,.72)),ground+Vector3(.22,.26,.05));floaters.append({"handle":ember,"position":ground+Vector3(.22,.26,.05),"phase":noise*8,"amount":.12})


func _create_roads()->void:
	for route in [[Vector2i(-5,2),Vector2i(-4,1),Vector2i(-3,0),Vector2i(-2,-1),Vector2i(-1,-1),Vector2i(0,-2),Vector2i(2,-3)],[Vector2i(-2,-1),Vector2i(-1,0),Vector2i(0,1),Vector2i(1,2),Vector2i(2,2),Vector2i(4,1)],[Vector2i(-1,0),Vector2i(-2,2),Vector2i(-2,4),Vector2i(-1,5)]]:_add_road_path(route)


func _add_road_path(route:Array)->void:
	var route_count:=route.size()
	for index in route_count-1:
		if not cells.has(route[index]) or not cells.has(route[index+1]):continue
		var start:Vector3=cells[route[index]].center+Vector3.UP*(cells[route[index]].top+.08);var end:Vector3=cells[route[index+1]].center+Vector3.UP*(cells[route[index+1]].top+.08)
		_add(MoldShape.line_3d(start,end,.18),MoldStyle.dual_gradient(Color("6b4433"),BRICK_LIGHT,.35),Vector3.ZERO,Quaternion.IDENTITY,Vector3.ONE,MoldRenderState.new(1,7))


func _create_settlements()->void:
	_add_capital(cells[Vector2i(-2,-1)])
	for data in [[Vector2i(-5,2),BRICK,BRICK_LIGHT],[Vector2i(2,-3),ROYAL,ROYAL_LIGHT],[Vector2i(4,1),ENEMY,ENEMY_LIGHT],[Vector2i(-1,5),VIOLET,VIOLET_LIGHT],[Vector2i(2,2),GOLD,GOLD_LIGHT]]:_add_village(cells[data[0]],data[1],data[2])


func _add_capital(cell:Dictionary)->void:
	var ground:Vector3=cell.center+Vector3.UP*cell.top
	_add(MoldShape.regular_prism(6,1.04,.26,.2,MoldShape.Detail.LOW),MoldStyle.dual_gradient(SOIL,PARCHMENT,.45),ground+Vector3.UP*.13,HEX_ROTATION)
	_add(MoldShape.cuboid(Vector3(1.45,1.65,1.28),.18,MoldShape.Detail.LOW),MoldStyle.dual_gradient(Color("7a4f48"),PARCHMENT,.72),ground+Vector3.UP*1.02)
	for offset in [Vector3(-.72,0,-.58),Vector3(.72,0,-.58),Vector3(-.72,0,.58),Vector3(.72,0,.58)]:
		var tower:Vector3=ground+offset;_add(MoldShape.cylinder(.31,1.75,.25,MoldShape.Detail.LOW),MoldStyle.dual_gradient(BRICK,BRICK_LIGHT,.72),tower+Vector3.UP*1.02);_add(MoldShape.cone(.44,.88,MoldShape.Detail.LOW),MoldStyle.dual_gradient(ROYAL,ROYAL_LIGHT,.86),tower+Vector3.UP*2.28);_add(MoldShape.sphere(.09,MoldShape.Detail.LOW),MoldStyle.color_dodge(Color(1,.72,.22,.9)),tower+Vector3.UP*2.78)
	_add(MoldShape.cone(.88,1.35,MoldShape.Detail.LOW),MoldStyle.dual_gradient(ROYAL,ROYAL_LIGHT,.92),ground+Vector3.UP*2.48)


func _add_village(cell:Dictionary,roof:Color,roof_light:Color)->void:
	var ground:Vector3=cell.center+Vector3.UP*cell.top;var offsets:=[Vector3(-.45,0,-.2),Vector3(.42,0,.32),Vector3(.3,0,-.48)]
	var offset_count:=offsets.size()
	for index in offset_count:
		var scale:=.88 if index==0 else .68;var home:Vector3=ground+offsets[index]
		_add(MoldShape.cuboid(Vector3(.72,.58,.65)*scale,.2,MoldShape.Detail.LOW),MoldStyle.dual_gradient(SOIL,PARCHMENT,.46),home+Vector3.UP*(.3*scale));_add(MoldShape.cone(.53*scale,.62*scale,MoldShape.Detail.LOW),MoldStyle.dual_gradient(roof,roof_light,.64),home+Vector3.UP*(.84*scale))


func _create_armies()->void:
	var routes:=[[[Vector2i(-5,2),Vector2i(-4,1),Vector2i(-3,0),Vector2i(-2,-1)],ROYAL,ROYAL_LIGHT,.48,0.0],[[Vector2i(-2,-1),Vector2i(-1,0),Vector2i(0,1),Vector2i(1,2)],GOLD,GOLD_LIGHT,.42,1.8],[[Vector2i(4,1),Vector2i(3,1),Vector2i(2,2),Vector2i(1,2)],ENEMY,ENEMY_LIGHT,.5,3.1],[[Vector2i(2,-3),Vector2i(1,-2),Vector2i(0,-2),Vector2i(-2,-1)],VIOLET,VIOLET_LIGHT,.45,.9],[[Vector2i(-1,5),Vector2i(-2,4),Vector2i(-2,2),Vector2i(-1,0)],BRICK,BRICK_LIGHT,.38,2.4]]
	for data in routes:_add_unit(data[0],data[1],data[2],data[3],data[4])


func _add_unit(axials:Array,bottom:Color,top:Color,speed:float,phase:float)->void:
	var route:Array[Vector3]=[]
	for axial in axials:route.append(cells[axial].center+Vector3.UP*(cells[axial].top+.66))
	var body:=_add(MoldShape.capsule(.24,1.12,MoldShape.Detail.LOW),MoldStyle.dual_gradient(bottom,top,.82),route[0]);var pennant:=_add(MoldShape.regular_polygon(3,.22,.1),MoldStyle.lighten(Color(top.r,top.g,top.b,.86)),route[0]+Vector3(.34,.9,.02));units.append({"body":body,"pennant":pennant,"route":route,"speed":speed,"phase":phase})


func _create_landmarks()->void:
	var rift_cell=cells[Vector2i(-4,-2)];var rift:Vector3=rift_cell.center+Vector3.UP*(rift_cell.top+.07)
	_add(MoldShape.disc(.82,.1,TAU*.86),MoldStyle.subtractive(Color(.42,.16,.28,.78)),rift,GROUND_ROTATION)
	var burn:=_add(MoldShape.ring(.93,.1,.2,TAU*.82,MoldDash.new(9,12,.38,.1,MoldDash.Type.CHEVRON,.82)),MoldStyle.linear_burn(Color(.38,.12,.16,.8)),rift+Vector3.UP*.025,GROUND_ROTATION);spinners.append({"handle":burn,"position":rift+Vector3.UP*.025,"axis":Vector3.UP,"speed":-.32,"phase":0.0})
	var shrine_cell=cells[Vector2i(0,3)];var shrine:Vector3=shrine_cell.center+Vector3.UP*shrine_cell.top
	_add(MoldShape.hemisphere(.78,true,MoldShape.Detail.LOW),MoldStyle.screen(Color(.3,.9,1,.42)),shrine+Vector3.UP*.05);morphing_relic=_add(MoldShape.sphere(.48,MoldShape.Detail.LOW),MoldStyle.lighten(Color(1,.84,.32,.74)),shrine+Vector3.UP*.72);floaters.append({"handle":morphing_relic,"position":shrine+Vector3.UP*.72,"phase":.4,"amount":.13})
	var enemy_cell=cells[Vector2i(4,0)];var enemy:Vector3=enemy_cell.center+Vector3.UP*enemy_cell.top
	hidden_scout=_add(MoldShape.sphere(.66,MoldShape.Detail.LOW),MoldStyle.transparent(Color(1,.18,.28,.72)),enemy+Vector3(0,.72,-.38),Quaternion.IDENTITY,Vector3.ONE,MoldRenderState.new(1,24,MoldRenderState.DepthTest.GREATER,MoldRenderState.DepthWrite.DISABLED))
	var beacon_cell=cells[Vector2i(1,-4)];var beacon:Vector3=beacon_cell.center+Vector3.UP*(beacon_cell.top+1)
	quest_beacon=_add(MoldShape.regular_polygon(5,.48,.2),MoldStyle.color_dodge(Color(1,.64,.18,.82)),beacon,Quaternion.IDENTITY,Vector3.ONE,MoldRenderState.new(2,60,MoldRenderState.DepthTest.ALWAYS,MoldRenderState.DepthWrite.DISABLED));floaters.append({"handle":quest_beacon,"position":beacon,"phase":1.3,"amount":.18})
	arcane_beacon=_add(MoldShape.ring(.72,.11,0,TAU,MoldDash.new(8,8,.32,0,MoldDash.Type.ROUNDED,.7)),MoldStyle.additive(Color(.65,.42,1,.7)),beacon+Vector3.UP*.12,GROUND_ROTATION,Vector3.ONE,MoldRenderState.new(2,61,MoldRenderState.DepthTest.ALWAYS,MoldRenderState.DepthWrite.DISABLED))


func _create_wind()->void:
	for index in 4:
		var cell=cells[[Vector2i(-3,3),Vector2i(-1,3),Vector2i(1,1),Vector2i(3,-1)][index]];var center:Vector3=cell.center+Vector3.UP*(cell.top+2.15+index*.08)
		var wind_shape:=MoldShape.line_3d(center+Vector3.LEFT,center+Vector3.RIGHT,.045,.5,MoldShape.Detail.LOW) if index==0 else MoldShape.line_3d(center+Vector3.LEFT,center+Vector3.RIGHT,.045,0.0,MoldShape.Detail.LOW)
		wind_lines.append(_add(wind_shape,MoldStyle.screen(Color(.52,.92,1,.54)),Vector3.ZERO,Quaternion.IDENTITY,Vector3.ONE,MoldRenderState.new(1,50,MoldRenderState.DepthTest.ALWAYS,MoldRenderState.DepthWrite.DISABLED)));wind_bases.append(center);wind_starts.append(center+Vector3.LEFT);wind_ends.append(center+Vector3.RIGHT)


func _animate_units(time:float)->void:
	for unit in units:
		var progress:=fposmod(time*unit.speed+unit.phase,unit.route.size());var segment:=floori(progress);var position:Vector3=unit.route[segment].lerp(unit.route[(segment+1)%unit.route.size()],progress-segment);var stride:=sin(time*7+unit.phase)
		unit.body.set_transform(position+Vector3.UP*(absf(stride)*.08),Quaternion(Vector3.FORWARD,stride*.08),Vector3(1-absf(stride)*.04,1+absf(stride)*.035,1));unit.pennant.set_position(position+Vector3(.34,.9,.02))


func _animate_features(time:float)->void:
	for spinner in spinners:spinner.handle.set_transform(spinner.position,Quaternion(spinner.axis,spinner.phase+time*spinner.speed),Vector3.ONE)
	for floater in floaters:
		var wave:=sin(time*1.8+floater.phase);floater.handle.set_position(floater.position+Vector3.UP*(wave*floater.amount));floater.handle.set_scale(Vector3.ONE*(1+wave*.08))
	quest_beacon.set_visible(int(time*2.5)&1==0);quest_beacon.set_color(GOLD.lerp(GOLD_LIGHT,(sin(time*4)+1)*.5))
	var wind_count:=wind_lines.size()
	for index in wind_count:
		var drift:=sin(time*1.1+index*.8)*.42;wind_starts[index]=wind_bases[index]+Vector3(-.8,drift,0);wind_ends[index]=wind_bases[index]+Vector3(.8,-drift*.35,.2)
	world.update_line_positions_bulk(wind_lines,wind_starts,wind_ends)
	var second:=floori(time)
	if second==last_mutation:return
	last_mutation=second;morphing_relic.set_shape(MoldShape.sphere(.48,MoldShape.Detail.LOW) if second%2==0 else MoldShape.hemisphere(.62,false,MoldShape.Detail.LOW))
	arcane_beacon.set_style([MoldStyle.screen(Color(.5,.8,1,.7)),MoldStyle.color_dodge(Color(1,.55,.24,.66)),MoldStyle.additive(Color(.78,.42,1,.62))][second%3]);hidden_scout.set_render_state(MoldRenderState.new(1,24 if second%2==0 else 25,MoldRenderState.DepthTest.GREATER,MoldRenderState.DepthWrite.DISABLED))


func _axial_world(axial:Vector2i)->Vector3:return Vector3(HEX_RADIUS*1.5*axial.x,0,HEX_RADIUS*sqrt(3)*(axial.y+axial.x*.5))


func _choose_biome(q:int,r:int,noise:float)->int:
	var distance:=maxi(abs(q),maxi(abs(r),abs(-q-r)))
	if distance>=7:return Biome.SNOW if noise>.48 else Biome.MOUNTAIN
	if q<=-3 and r>=2:return Biome.WATER
	if q>=4 and r>=-1:return Biome.MOUNTAIN if noise>.48 else Biome.BURNED
	if q>=2 and r<=-2:return Biome.MOUNTAIN
	if q+r<=-5:return Biome.MOOR
	if q in [-5,-4] and r>=-1 and r<=2:return Biome.FIELDS
	if q in [2,3] and r>=1 and r<=3:return Biome.FIELDS
	if noise>.64 and abs(q+2)+abs(r+1)>2:return Biome.FOREST
	return Biome.PLAINS


func _hash01(x:int,y:int)->float:return fposmod(sin(x*127.1+y*311.7)*43758.5453,1.0)


func _add(shape:MoldShape,style:MoldStyle,position:Vector3,rotation:Quaternion=Quaternion.IDENTITY,scale:Vector3=Vector3.ONE,state:MoldRenderState=null)->MoldHandle:
	var handle:=world.create(shape,style,state);handle.set_transform(position,rotation,scale);handles.append(handle);return handle


func _exit_tree()->void:
	for handle in handles:
		if handle and handle.is_valid:handle.release()
	if world:world.dispose()
	world=null
