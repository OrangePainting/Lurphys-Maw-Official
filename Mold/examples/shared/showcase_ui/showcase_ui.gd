@tool
extends CanvasLayer

@export var title_text := "MOLD SAMPLE":
	set(value):
		title_text = value
		_refresh()

@export var subtitle_text := "":
	set(value):
		subtitle_text = value
		_refresh()

@export_multiline var controls_text := "":
	set(value):
		controls_text = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	var title := get_node_or_null("TitleMargin/TitlePanel/TitlePadding/TitleStack/Title") as Label
	var subtitle := get_node_or_null("TitleMargin/TitlePanel/TitlePadding/TitleStack/Subtitle") as Label
	var controls_margin := get_node_or_null("ControlsMargin") as Control
	var controls := get_node_or_null("ControlsMargin/ControlsPanel/Controls") as Label
	if title:
		title.text = title_text
	if subtitle:
		subtitle.text = subtitle_text
		subtitle.visible = not subtitle_text.strip_edges().is_empty()
	if controls:
		controls.text = controls_text
	if controls_margin:
		controls_margin.visible = not controls_text.strip_edges().is_empty()
