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
@export var start_clear_radius := 5 ## radius of space around the start square (will be empty)
@export var end_radius := 3 ## radius of space around the end square (will be empty)

@export_group("Cave Parameters")
@export var link_caves := true
@export var min_cave_size := 15
@export var tunnel_width := 2

#TODO add more parameters

@export_group("Output")
@export var level_seed := 0
@export_file("*.png") var output_path := ""


var grid: Array[int] = []


func _ready() -> void:
	if output_path == "":
		print("you need an output path!")
		return
	
	var image := make_image(generate())
	var error := image.save_png(output_path)
	if error != OK: print("error occured")
	else: print("saved image")
	

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
	for generation in num_generations: run_generation()
	
	# figure out how to make it feel level like
	connect_caves()
	
	var start := find_first_water_cell()
	var end := 0 # get the furthest cell from the start pos
	var dists := get_distances_from(start)
	for index in dists.size(): if dists[index] > dists[end]: end = index 
	
	var level := build_level(start, end)
	
	return level

func make_image(cells: Array) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height: for x in width:
		image.set_pixel(x, y, cells[y][x])
	
	return image

## fills the starting state of the grid with a random set of cells
func fill_start_state(rng: RandomNumberGenerator) -> void:
	grid.resize(width * height)
	for y in height: for x in width:
		if (x == 0) or (y == 0) or (x == width - 1) or (y == height - 1):
			grid[get_idx(x, y)] = cell.ALIVE
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

## connect the caves together so it doesn't look like static
func connect_caves() -> void:
	var labels: Array[int] = []
	labels.resize(width * height)
	var caves: Array[Array] = []
	
	for start in width * height:
		if grid[start] == cell.DEAD and labels[start] == 0:
			caves.append(do_dfs(start, labels))
		
		caves.sort_custom(func(a, b): return a.size() > b.size())
		
	var caves_to_add: Array[Array] = []
	for cave in range(1, caves.size()): # skip the biggest cluster
		if link_caves and caves[cave].size() >= min_cave_size:
			caves_to_add.append(caves[cave])
		else:
			for index in caves[cave]:
				grid[index] = cell.ALIVE
	
	var connected_cave: Array[int] = []
	connected_cave.append_array(caves[0])
	for cave_to_add in caves_to_add:
		var cave: Array[int] = []
		cave.append_array(cave_to_add)
		var target := nearest_cell(connected_cave, get_center(cave))
		var start := nearest_cell(cave, Vector2(target % width, target / width))
		make_tunnel(start, target)
		connected_cave.append_array(cave)

## get the centroid of a group of cells
func get_center(cells: Array[int]) -> Vector2:
	var sum := Vector2.ZERO
	for index in cells: sum += Vector2(index % width, index / width)
	return sum / cells.size()

## get the cell nearest to the target
func nearest_cell(cells: Array[int], target: Vector2) -> int:
	var best_cell := cells[0]
	var best_dist := -1.0
	for index in cells:
		var dist := Vector2(index % width, index / width).distance_squared_to(target)
		if best_dist == -1 or dist < best_dist:
			best_dist = dist
			best_cell = index
	
	return best_cell

## make a tunnel between two caves
func make_tunnel(start: int, end: int) -> void:
	var start_pos := Vector2(start % width, start / width)
	var end_pos := Vector2(end % width, end / width)
	
	var max_step_size := maxf(absf(start_pos.x - end_pos.x), absf(start_pos.y - end_pos.y))
	var steps := maxi(int(max_step_size), 1)
	for step in steps + 1:
		var mid_point := start_pos.lerp(end_pos, float(step) / steps)
		clear_radius(get_idx(roundi(mid_point.x), roundi(mid_point.y)), tunnel_width)

## do a dfs and return every cell that it touches
func do_dfs(start: int, labels: Array[int]) -> Array[int]:
	var cave: Array[int] = []
	var stack: Array[int] = [start]
	labels[start] = 1
	
	while not stack.is_empty():
		var index: int = stack.pop_back()
		cave.append(index)
		for neighbor in get_neighbors(index):
			if grid[neighbor] == cell.DEAD and labels[neighbor] == 0:
				labels[neighbor] = 1
				stack.append(neighbor)
	
	return cave

## return the distances of each square from the starting square, using bfs
func get_distances_from(start: int) -> Array[int]:
	var dists: Array[int] = []
	dists.resize(width * height)
	dists.fill(-1)
	
	var queue: Array[int] = [start]
	var head := 0
	dists[start] = 0
	
	while head < queue.size():
		var index := queue[head]
		head += 1
		for neighbor in get_neighbors(index):
			if grid[neighbor] == cell.DEAD and dists[neighbor] == -1:
				dists[neighbor] = dists[index] + 1
				queue.append(neighbor)
	
	return dists

## gets the first water cell available
func find_first_water_cell() -> int:
	for x in range(1, width - 1): for y in range(1, height - 1):
		if grid[get_idx(x, y)] == cell.DEAD:
			return get_idx(x, y)
	return -1

## gets a raidus of cells around the target
func get_radius(target: int, radius: int) -> Array[int]:
	var target_x := target % width
	var target_y := target / width
	
	var min_x = mini(target_x + radius, width - 2) + 1
	var max_x = maxi(target_x - radius, 1)
	var min_y = mini(target_y + radius, height - 2) + 1
	var max_y = maxi(target_y - radius, 1)
	
	
	var cells: Array[int] = []
	
	for y in range(max_y , min_y): for x in range(max_x, min_x):
		if Vector2(x - target_x, y - target_y).length() <= radius:
			cells.append(get_idx(x, y))
	
	return cells

func clear_radius(target: int, radius: int) -> void:
	for index in get_radius(target, radius): grid[index] = cell.DEAD


func build_level(start: int, end: int) -> Array:
	var output := []
	
	for y in height:
		var row := []
		for x in width:
			row.append(WALL_COLOR if grid[get_idx(x, y)] == cell.ALIVE else WATER_COLOR)
		output.append(row)
	
	for index in get_radius(end, end_radius):
		output[index / width][index % width] = END_COLOR
	
	output[start / width][start % width] = START_COLOR
	
	return output
