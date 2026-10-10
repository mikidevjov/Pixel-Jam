class_name HelpDialog
extends Control

signal help_open_changed(is_open: bool)

## When true (in-game), opening this dialog pauses the scene tree.
@export var pauses_gameplay: bool = false

@onready var _dim: ColorRect = $Dim
@onready var _body: Label = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/Body
@onready var _footer: Label = $PanelContainer/MarginContainer/VBoxContainer/Footer

var _was_paused_before_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _dim:
		_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	if _body:
		_body.text = GameHelp.get_text()
	if _footer:
		_footer.text = "H - CLOSE"


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	_was_paused_before_open = get_tree().paused
	show()
	if pauses_gameplay:
		get_tree().paused = true
	help_open_changed.emit(true)


func close() -> void:
	if not visible:
		return
	hide()
	help_open_changed.emit(false)
	if pauses_gameplay and not _was_paused_before_open and not _gameplay_should_stay_paused():
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


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and (event.keycode == KEY_H or event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close()
