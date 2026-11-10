extends Node2D

@onready var _upgrade_station: Interactable = %UpgradeStation
@onready var _run_portal: Interactable = %RunPortal
@onready var _shop: UpgradeShop = %UpgradeShop


func _ready() -> void:
	_upgrade_station.interacted.connect(_shop.open)
	_run_portal.interacted.connect(_on_run_portal_interacted)


func _on_run_portal_interacted() -> void:
	# PLACEHOLDER: swap this for loading the real run scene once the team
	# decides how runs start.
	print("Portal used")
