extends Node
class_name RelicManager

## Manages the player's relics. Loads every relic in the game, equips relics for the current run, and
## passes gameplay events through every equipped relic.
##
## Each event has an apply function, such as [method apply_damage_taken], that is called by the player
## or level when the event happens. It calls the matching function on every equipped [Relic] in the order
## they were equipped, passing each relic's result into the next.

## The relics equipped for the current run, stored in [member RunData.equippedRelics].
var relics : Array[Relic] :
	get():
		return RunManager.run.equippedRelics

## The folder that every relic resource is loaded from.
const RELICS_PATH = "res://Relics/"
## Every relic in [constant RELICS_PATH], keyed by its [member Relic.displayName].
var relicsDict : Dictionary[String, Relic]

## Loads every relic resource in [constant RELICS_PATH] into [member relicsDict].
func load_relics():
	relicsDict.clear()
	for file in ResourceLoader.list_directory(RELICS_PATH):
		if not file.ends_with(".tres"):
			continue
		var relic = load(RELICS_PATH + file)
		if relic is Relic:
			relicsDict[relic.displayName] = relic

## Equips the relic with the display name [param relic] for the current run.
func equip_relic(relic : String):
	relics.append(relicsDict[relic])

## Calls [method Relic.on_level_start] on every equipped relic.
func apply_level_start(level : Level):
	for relic in relics:
		relic.on_level_start(level)

## Passes [param damage] through [method Relic.on_damage_taken] on every equipped relic and returns
## the damage the player should take.
func apply_damage_taken(damage : float, source : Node) -> float:
	for relic in relics:
		damage = relic.on_damage_taken(damage, source)
	return damage

## Passes [param damage] through [method Relic.on_enemy_hit] on every equipped relic and returns the
## damage the enemy should take.
func apply_enemy_hit(damage : float) -> float:
	for relic in relics:
		damage = relic.on_enemy_hit(damage)
	return damage

## Adds the RelicManager to the [LimboConsole] and loads every relic.
func _ready() -> void:
	LimboConsole.add_eval_input("RelicManager", self)
	load_relics()
