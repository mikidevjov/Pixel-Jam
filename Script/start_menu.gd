extends Control

const MAIN_GAME_SCENE := preload("res://Scene/main_game.tscn")

@onready var settings_panel: Control = $SettingsPanel


func _ready() -> void:
	if settings_panel:
		settings_panel.hide()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_packed(MAIN_GAME_SCENE)


func _on_setting_pressed() -> void:
	if settings_panel:
		settings_panel.show()


func _on_settings_back_pressed() -> void:
	if settings_panel:
		settings_panel.hide()


func _on_quit_pressed() -> void:
	get_tree().quit()
