extends Resource
class_name Level

@export var img : Texture2D:
	set(value):
		img = value
		imgMapping = ImageMapping.new(img.get_image()) if img else null
var imgMapping : ImageMapping
@export var nextLevel : Level

# make a Level dataset from the image we give it
static func image_to_level(image: Image) -> Level:
	var level := Level.new()
	level.imgMapping = ImageMapping.new(image)
	return level
