extends Resource
class_name Relic

## Relics are gathered during a run and extracted back up to the base, at which they are stored
## and equipped for other runs. Each one applies much more active and game changing upgrades than
## base upgrades, but are lost when you die holding them on a run.

## The RelicScript that this relic uses to function. It is not attached to the resource the way a script
## normally would be, but is a variable that is used by using the built in call function, calling
## either the active or passive buff through the player when applicable.
##
## [b]Must extend RelicScript.
@export var relicScript : Script
@export var displayName : String
@export var description : String
