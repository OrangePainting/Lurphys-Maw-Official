extends Node

const PROCGEN := preload("res://Levels/ProcGen/ProcGen.tscn")

var currentLevel : Level
var root : Root

var how_far := 0
var run_seed := -1

signal scrap_changed(total: int)

var scrap := 0

func start_run() -> void:
	MusicManager.play(MusicManager.Music.RUN)
	how_far = 0
	run_seed = randi()
	currentLevel = generate_level()
	root.load_scene.call_deferred(load("res://Scenes/LurphyLevel.tscn"))

func generate_level() -> Level:
	var proc_gen := PROCGEN.instantiate() as CaveGenerator
	proc_gen.level_seed = (run_seed + how_far) if run_seed != -1 else -1
	proc_gen.num_enemies = 10 + how_far * 2
	var result := proc_gen.make_image(proc_gen.generate())
	proc_gen.free() # have to free before returning
	how_far += 1
	return Level.image_to_level(result)

func load_next_level():
	currentLevel = currentLevel.nextLevel if currentLevel.nextLevel else generate_level()
	root.load_scene.call_deferred(load("res://Scenes/LurphyLevel.tscn"))

func add_scrap(amount: int) -> void:
	scrap += amount
	scrap_changed.emit(scrap)
	#print("Scrap total: ", scrap) # temporary, delete once the HUD shows it

func spend_scrap(amount: int) -> bool:
	if amount > scrap:
		return false
	scrap -= amount
	scrap_changed.emit(scrap)
	return true
