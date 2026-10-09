class_name HelpDialog
extends Control

signal help_open_changed(is_open: bool)

## When true (in-game), opening this dialog pauses the scene tree.
@export var pauses_gameplay: bool = false

@onready var _body: Label = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/Body
@onready var _footer: Label = $PanelContainer/MarginContainer/VBoxContainer/Footer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _body:
		_body.text = GameHelp.get_text()
	if _footer:
		_footer.text = "ESC — CLOSE"


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	show()
	if pauses_gameplay:
		get_tree().paused = true
	help_open_changed.emit(true)


func close() -> void:
	if not visible:
		return
	hide()
	help_open_changed.emit(false)
	if pauses_gameplay and not _gameplay_should_stay_paused():
		get_tree().paused = false


func _gameplay_should_stay_paused() -> bool:
	var main = get_tree().get_first_node_in_group("main")
	return main != null and main.get("is_game_over")


func toggle() -> bool:
	if visible:
		close()
	else:
		open()
	return visible
