extends Resource
class_name Relic

## Relics are gathered during a run and extracted back up to the base, at which they are stored
## and equipped for other runs. Each one applies much more active and game changing upgrades than
## base upgrades, but are lost when you die holding them on a run.
##
## Each relic is a single resource whose own script is a built-in script that extends Relic. When
## extending, only the functions that are used by the relic need to be overridden. for example, if a
## item makes it so the player takes less damage from a specific source, that relic's script should
## override the [method on_damage_taken], check if the source is in the group corresponding to the
## applicable damage source type, and return the new damage reduced by whatever its damage reduction
## is.
##
## To make a new relic, create a new Relic resource in [constant RelicManager.RELICS_PATH], then set its
## Script to a new built-in script that extends Relic. Every relic in that folder is loaded into
## [member RelicManager.relicsDict] by its [member displayName], and the functions below are called on
## every equipped relic through the [RelicManager].

@export var displayName : String
@export var description : String

## Called when a new level starts, through [method RelicManager.apply_level_start].
func on_level_start(level : Level):
	pass

## Called when the player takes damage from [param source], through
## [method RelicManager.apply_damage_taken]. Returns the damage the player should take.
func on_damage_taken(damage : float, source : Node) -> float:
	return damage

## Called when the player hits an enemy, through [method RelicManager.apply_enemy_hit]. Returns the
## damage the enemy should take.
func on_enemy_hit(damage : float) -> float:
	return damage
