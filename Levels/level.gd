extends Resource
class_name Level

var tex: Texture2D
var img: Image
var mapping : Array[Array]


func _init(imagePath : String) -> void:
	tex = load(imagePath)
	img = tex.get_image()
	mapping.resize(img.get_height())
	for y in img.get_height():
		var row: Array = []
		row.resize(img.get_width())
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			row[x] = c
			mapping[y] = row
