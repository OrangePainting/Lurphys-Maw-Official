class_name UpgradeCatalog extends RefCounted
## PLACEHOLDER list of upgrades
## Cost of the next level = base_cost + cost_step * current_level.

const ALL: Array[Dictionary] = [
	{
		"id": &"extra_dash",
		"name": "Extra Dash Charge",
		"description": "Hold one more dash charge.",
		"max_level": 2,
		"base_cost": 50,
		"cost_step": 75,
	},
	{
		"id": &"swim_speed",
		"name": "Stronger Fins",
		"description": "Swim faster.",
		"max_level": 3,
		"base_cost": 30,
		"cost_step": 30,
	},
]
