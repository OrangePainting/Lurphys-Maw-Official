extends Node3D

## A small autonomous world used behind the retained HUD showcase.

const NIGHT_TOP := Color(0.018, 0.035, 0.075)
const DAY_TOP := Color(0.12, 0.42, 0.70)
const DAWN_HORIZON := Color(0.92, 0.42, 0.23)
const DAY_HORIZON := Color(0.56, 0.76, 0.86)
const NIGHT_GROUND := Color(0.018, 0.025, 0.030)
const DAY_GROUND := Color(0.14, 0.18, 0.17)

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun

var sky_material: ProceduralSkyMaterial
var elapsed := 0.0


func _ready() -> void:
	_build_dynamic_environment()
	_build_scenery()


func _process(delta: float) -> void:
	elapsed += delta
	var cycle := elapsed * 0.045
	var daylight := clampf(0.58 + sin(cycle) * 0.42, 0.12, 1.0)
	var horizon_warmth := 1.0 - absf(daylight - 0.48) * 1.75
	sun.rotation_degrees = Vector3(-18.0 - daylight * 48.0, fposmod(elapsed * 1.8, 360.0), 0.0)
	sun.light_energy = 0.35 + daylight * 1.05
	sun.light_color = Color(1.0, 0.68, 0.48).lerp(Color(1.0, 0.95, 0.82), daylight)
	sky_material.sky_top_color = NIGHT_TOP.lerp(DAY_TOP, daylight)
	sky_material.sky_horizon_color = NIGHT_TOP.lerp(
		DAWN_HORIZON.lerp(DAY_HORIZON, daylight), clampf(horizon_warmth, 0.0, 1.0))
	sky_material.ground_bottom_color = NIGHT_GROUND.lerp(DAY_GROUND, daylight)
	sky_material.ground_horizon_color = NIGHT_GROUND.lerp(DAY_HORIZON * 0.52, daylight)


func _build_dynamic_environment() -> void:
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = DAY_TOP
	sky_material.sky_horizon_color = DAY_HORIZON
	sky_material.ground_bottom_color = DAY_GROUND
	sky_material.ground_horizon_color = DAY_HORIZON * 0.52
	sky_material.sun_angle_max = 8.0
	sky_material.sun_curve = 0.08

	var sky := Sky.new()
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.34, 0.48, 0.55)
	environment.fog_light_energy = 0.62
	environment.fog_density = 0.008
	environment.fog_height = 0.0
	environment.fog_height_density = 0.075
	world_environment.environment = environment
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY


func _build_scenery() -> void:
	var road_material := _material(Color(0.045, 0.060, 0.064), 0.82)
	var road := MeshInstance3D.new()
	var road_mesh := PlaneMesh.new()
	road_mesh.size = Vector2(16.0, 86.0)
	road_mesh.material = road_material
	road.mesh = road_mesh
	road.position = Vector3(0.0, 0.018, -28.0)
	add_child(road)

	var mark_material := _material(Color(0.22, 0.72, 0.80), 0.38, true)
	for index in 18:
		var marker := MeshInstance3D.new()
		var marker_mesh := BoxMesh.new()
		marker_mesh.size = Vector3(0.08, 0.018, 1.8)
		marker_mesh.material = mark_material
		marker.mesh = marker_mesh
		marker.position = Vector3(0.0, 0.045, 7.0 - float(index) * 4.6)
		add_child(marker)

	var pylon_material := _material(Color(0.09, 0.12, 0.13), 0.62)
	var light_material := _material(Color(1.0, 0.48, 0.16), 0.25, true)
	for index in 12:
		for side in [-1.0, 1.0]:
			var pylon := MeshInstance3D.new()
			var pylon_mesh := BoxMesh.new()
			var height := 1.8 + float(index % 4) * 0.75
			pylon_mesh.size = Vector3(0.72, height, 0.72)
			pylon_mesh.material = pylon_material
			pylon.mesh = pylon_mesh
			pylon.position = Vector3(side * (8.5 + float(index % 3) * 1.8), height * 0.5,
				3.0 - float(index) * 6.2)
			add_child(pylon)

			var beacon := MeshInstance3D.new()
			var beacon_mesh := BoxMesh.new()
			beacon_mesh.size = Vector3(0.20, 0.20, 0.20)
			beacon_mesh.material = light_material
			beacon.mesh = beacon_mesh
			beacon.position = pylon.position + Vector3(0.0, height * 0.52, 0.0)
			add_child(beacon)


func _material(color: Color, roughness: float, emissive := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.2
	return material

