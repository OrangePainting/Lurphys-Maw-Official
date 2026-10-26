@tool
class_name LevelColors

## Goal: Hold the colors that the images will use
## There are two different colors, one for the images the game will use, and one for debugging

const WALL := Color(0, 0, 1, 1)
const WATER := Color(0, 0, 0, 0)
const START := Color(1, 1, 1, 1)
const END := Color(0, 0, 0, 1)
const ENEMY := Color(1, 0, 0, 1)

const DEBUG_WALL := Color(0, 0.2, 0.5)
const DEBUG_WATER := Color(0.4, 0.6, 1)
const DEBUG_SPACE := Color(0.7, 0.8, 1) # showcase that there's a lot of space in this area
const DEBUG_PATH := Color(1, 0, 1)
const DEBUG_START := Color(0, 1, 0)
