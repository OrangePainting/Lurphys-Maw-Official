extends Node
class_name LevelManager
@onready var layer: TileMapLayer = $"../TileMapLayer" 
var spawnPos : Vector2
@onready var lurphyLevel : LurphyLevel = get_parent()
var levelDimensions : Vector2


func update_level_to_levelres(levelRes : Level):
	var mapping = levelRes.imgMapping
	var newPattern : TileMapPattern = TileMapPattern.new()
	newPattern.set_size(Vector2i(mapping.mapping[0].size(), mapping.mapping.size()))
	levelDimensions = (layer.map_to_local(Vector2i(mapping.mapping[0].size() - 1, mapping.mapping.size() - 1)))
	var exitZoneArray : PackedVector2Array 
	for y in mapping.mapping.size():
		for x in mapping.mapping[y].size():
			var c: Color = mapping.mapping[y][x]
			match c:
				Color(0.0, 0.0, 1.0, 1.0):
					newPattern.set_cell(Vector2i(x, y), 1, Vector2i(6, 3), 0)
				Color(1.0, 1.0, 1.0, 1.0):
					%Player.position = layer.map_to_local(Vector2i(x,y))
				Color(0.0, 0.0, 0.0, 1.0):
					exitZoneArray.append(layer.map_to_local(Vector2(x, y)))
	layer.set_pattern(Vector2i(0, 0), newPattern)
	lurphyLevel.exitZoneCS.polygon = Geometry2D.convex_hull(exitZoneArray)
