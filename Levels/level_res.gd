extends Resource
class_name Level

@export var img : Texture2D:
	set(value):
		img = value
		imgMapping = ImageMapping.new(img.get_image()) if img else null
var imgMapping : ImageMapping
@export var nextLevel : Level
