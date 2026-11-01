class_name CaveGenerator
extends Node

## Goal: make a cave generator, using cellular automota
## using this as a tutorial: youtube.com/watch?v=S9QTsf9AUqQ

## fill map randomly
## for each generation, have each cell look at it's neighbors
## if alive conditions, then become alive, if dead conditions, then become dead



enum cell {DEAD, ALIVE} ## alive is 1, dead is 0

const WALL_COLOR := Color(0, 0, 1, 1)
const START_COLOR := Color(1, 1, 1, 1)
const END_COLOR := Color(0, 0, 0, 1)
const WATER_COLOR := Color(0, 0, 0, 0)

@export_group("Dimensions")
@export var width := 256
@export var height := 256

@export_group("Parameters")
@export_range(0, 100, 1) var start_alive_chance := 50
@export var num_generations := 10
@export var birth_floor := 5 ## >= birth_floor -> becomes alive
@export var death_cap := 3 ## <= death cap -> becomes dead
@export var use_same_grid := false ## use the same grid for cellular automata (dynamic)

@export_group("Layout")
@export var start_radius := 5 ## radius of space around the start square (will be empty)
@export var end_radius := 3 ## radius of space around the end square (will be empty)

#TODO add more parameters

@export_group("Output")
@export var level_seed := 0
@export_file("*.png") var output_path := ""


var grid: Array[int] = []


func _ready() -> void:
	if output_path == "":
		print("you need an output path!")
		return
	# generate image
	print("saved image")
	

func get_idx(x: int, y: int) -> int: return y * width + x

func get_neighbors(index: int) -> Array[int]:
	var x := index % width
	var y := index / width
	
	var neighbors: Array[int] = []
	if x > 0: neighbors.append(index - 1)
	if x < width - 1: neighbors.append(index + 1)
	if y > 0: neighbors.append(index - width)
	if y < height - 1: neighbors.append(index + width)

	return neighbors

## return an array of each color
func generate() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed
	
	# fill the grid randomly
	fill_start_state(rng)
	
	# run cellular automata
	# for generation in num_generations: run_generation()
	
	return []

## fills the starting state of the grid with a random set of cells
func fill_start_state(rng: RandomNumberGenerator) -> void:
	grid.resize(width * height)
	for y in height: for x in width:
		if (x == 0) or (y == 0) or (x == width - 1) or (y == height - 1):
			grid[get_idx(x, y)] == cell.ALIVE
		else:
			if rng.randi_range(0, 100) < start_alive_chance:
				grid[get_idx(x, y)] = cell.ALIVE
			else:
				grid[get_idx(x, y)] = cell.DEAD

## counts the number of alive neighbors around a cell
func get_alive_neighbors(cells: Array[int], x: int, y: int) -> int:
	var total := 0
	var x_dirs := [-1, 0, 1]
	var y_dirs := [-1, 0, 1]
	
	for y_dir in y_dirs: for x_dir in x_dirs:
		if not (x_dir == 0 and y_dir == 0): 
			total += cells[get_idx(x + x_dir, y + y_dir)]
	
	return total

## runs a generation of cellular automata
func run_generation() -> void:
	var grid_copy := grid if use_same_grid else grid.duplicate(true)
	
	for y in range(1, height - 1): for x in range(1, width - 1):
		var index := get_idx(x, y)
		var num_alive := get_alive_neighbors(grid_copy, x, y)
		if grid_copy[index] == cell.DEAD and num_alive >= birth_floor:
			grid[index] = cell.ALIVE
		elif grid_copy[index] == cell.ALIVE and num_alive >= death_cap:
			grid[index] = cell.DEAD 
