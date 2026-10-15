class_name Shield extends Weapon

@export var iframes := 0.5 # invincibility frames, seconds

# amount exists, just in case we want it to still damage player, but i'm leaninig towareds just preventing one hit
func prevent_damage(amount: float) -> bool:
	if state != State.ACTIVE: return false # do we want it to be passive (i.e. also works on free?)
	(holder as Player).start_iframes(iframes)
	end_active()
	return true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
