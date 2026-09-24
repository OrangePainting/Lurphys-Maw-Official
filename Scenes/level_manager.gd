extends Node
@onready var layer: TileMapLayer = $"../TileMapLayer" 
var spawnPos : Vector2

func _ready() -> void:
	var newImg = Level.new("res://Levels/LevelImages/test3.png")
	var pattern := create_tilemap_pattern(newImg)

	layer.set_pattern(Vector2i(0, 0), pattern)

func create_tilemap_pattern(levelRes : Level) -> TileMapPattern:
	var newPattern : TileMapPattern = TileMapPattern.new()
	newPattern.set_size(Vector2i(levelRes.mapping[0].size(), levelRes.mapping.size()))
	for y in levelRes.mapping.size():
		for x in levelRes.mapping[y].size():
			var c: Color = levelRes.mapping[y][x]
			if c.a > .5 and c.b > .5:
				newPattern.set_cell(Vector2i(x, y), 1, Vector2i(6, 3), 0)
			if c.a > .5 and c.g > .5:
				%Player.position = layer.map_to_local(Vector2i(x,y))
	return newPattern
