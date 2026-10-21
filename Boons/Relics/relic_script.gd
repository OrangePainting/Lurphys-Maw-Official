@abstract
extends Script
class_name RelicScript

## The script assigned to each individual relic. This exact .gd file is not attached to anything, only
## extended.
##
## When extending, only the functions that are used by the relic need to be overridden. for
## example, if a item makes it so the player takes less damage from a specific source, that relic's
## relic script should override the [method on_damage_taken], check if the source is in the group
## corresponding to the applicable damage source type, and return the new damage reduced by whatever
## its damage reduction is. 

func on_level_start(level : Level):
	pass

func on_damage_taken(damage : int, source : Node) -> int:
	return damage

func on_enemy_hit(damage : int) -> int:
	return damage
