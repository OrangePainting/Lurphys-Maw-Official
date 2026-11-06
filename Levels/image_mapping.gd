extends Resource
class_name ImageMapping

var tex: Texture2D
var img: Image
var mapping : Array[Array]


func _init(image : Image) -> void:
	img = image
	mapping.resize(img.get_height())
	for y in img.get_height():
		var row: Array = []
		row.resize(img.get_width())
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			row[x] = c
			mapping[y] = row
