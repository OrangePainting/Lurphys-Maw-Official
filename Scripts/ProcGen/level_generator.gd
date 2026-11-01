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
@export var birth_floor := 5 # >= birth_floor -> becomes alive
@export var death_cap := 3 # <= death cap -> becomes dead

#TODO add more parameters
