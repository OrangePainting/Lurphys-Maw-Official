extends HBoxContainer

@export var player: Node #TODO: potentially update with global, though looking unlikely

var dash_charge_texture = "res://icon.svg" #TODO: update when dash charge exists as a sprite
var num_charges: int = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	num_charges = player.dash_max_charges
	for i in num_charges:
		var charge = TextureRect.new()
		charge.texture = load(dash_charge_texture)
		charge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		charge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		charge.custom_minimum_size = Vector2(size.x/num_charges, size.y)
		add_child(charge)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if num_charges != player.get_dash_charges():
		var cur_charges = player.get_dash_charges()
		if cur_charges < num_charges:
			for i in range(num_charges - cur_charges):
				var last  = get_child(get_child_count()-1)
				remove_child(last)
		else:
			for i in range(cur_charges - num_charges):
				var charge = TextureRect.new()
				charge.texture = load(dash_charge_texture)
				charge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				charge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				charge.custom_minimum_size = Vector2(size.x/num_charges, size.y)
				add_child(charge)
		num_charges = cur_charges
