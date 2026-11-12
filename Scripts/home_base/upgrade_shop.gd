class_name UpgradeShop extends CanvasLayer
## Lists everything in UpgradeCatalog and lets the player buy it.
## Pauses the game while open. Esc or the Close button closes it.

signal closed

# TEMPORARY: coins and levels live here for now. Once the team decides
# how currency works, move these into one shared place.
var currency := 200
var levels: Dictionary = {} # id -> level

@onready var _rows: VBoxContainer = %Rows
@onready var _currency_label: Label = %CurrencyLabel
@onready var _close_button: Button = %CloseButton

var _row_widgets: Dictionary = {} # id -> {level: Label, buy: Button}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # keep working while the game is paused
	hide()
	_build_rows()
	_close_button.pressed.connect(close)
	_refresh()


func open() -> void:
	if visible:
		return
	show()
	get_tree().paused = true
	_refresh()
	_close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _level(id: StringName) -> int:
	return levels.get(id, 0)


func _cost(entry: Dictionary) -> int:
	return entry["base_cost"] + entry["cost_step"] * _level(entry["id"])


func _buy(entry: Dictionary) -> void:
	var id: StringName = entry["id"]
	if _level(id) >= entry["max_level"] or currency < _cost(entry):
		return
	currency -= _cost(entry)
	levels[id] = _level(id) + 1
	_refresh()


func _build_rows() -> void:
	for entry in UpgradeCatalog.ALL:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		_rows.add_child(row)

		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)

		var name_label := Label.new()
		name_label.text = entry["name"]
		text.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = entry["description"]
		desc_label.modulate = Color(1, 1, 1, 0.7)
		text.add_child(desc_label)

		var level_label := Label.new()
		level_label.custom_minimum_size.x = 80
		row.add_child(level_label)

		var buy_button := Button.new()
		buy_button.custom_minimum_size.x = 140
		buy_button.pressed.connect(_buy.bind(entry))
		row.add_child(buy_button)

		_row_widgets[entry["id"]] = {"level": level_label, "buy": buy_button}


func _refresh() -> void:
	_currency_label.text = "Coins: %d" % currency
	for entry in UpgradeCatalog.ALL:
		var widgets: Dictionary = _row_widgets[entry["id"]]
		var level := _level(entry["id"])
		widgets["level"].text = "Lv %d/%d" % [level, entry["max_level"]]
		var buy: Button = widgets["buy"]
		if level >= entry["max_level"]:
			buy.text = "MAX"
			buy.disabled = true
		else:
			buy.text = "Buy (%d)" % _cost(entry)
			buy.disabled = currency < _cost(entry)
