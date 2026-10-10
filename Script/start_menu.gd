extends Control

const MAIN_GAME_SCENE := preload("res://Scene/main_game.tscn")
const SETTINGS_FILE_PATH := "user://settings.cfg"

const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_MUSIC_VOLUME := 1.0
const DEFAULT_SFX_VOLUME := 1.0
const DEFAULT_FULLSCREEN := true

@onready var settings_panel: Control = $SettingsPanel
@onready var master_slider: HSlider = $SettingsPanel/SettingsVBox/MasterRow/MasterSlider
@onready var master_label: Label = $SettingsPanel/SettingsVBox/MasterRow/MasterValue
@onready var music_slider: HSlider = $SettingsPanel/SettingsVBox/MusicRow/MusicSlider
@onready var music_label: Label = $SettingsPanel/SettingsVBox/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $SettingsPanel/SettingsVBox/SFXRow/SFXSlider
@onready var sfx_label: Label = $SettingsPanel/SettingsVBox/SFXRow/SFXValue
@onready var fullscreen_toggle: CheckBox = $SettingsPanel/SettingsVBox/FullscreenRow/FullscreenCheckBox
@onready var help_dialog: HelpDialog = $HelpDialog


func _ready() -> void:
	if settings_panel:
		settings_panel.hide()
	if help_dialog:
		help_dialog.close()
	_load_settings()
	AudioManager.play_music("main_menu")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and (event.keycode == KEY_H or event.keycode == KEY_ESCAPE):
		if settings_panel and settings_panel.visible:
			settings_panel.hide()
			get_viewport().set_input_as_handled()
			return
		if help_dialog:
			if help_dialog.is_open():
				help_dialog.close()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_H:
				help_dialog.open()
				get_viewport().set_input_as_handled()


func _on_help_pressed() -> void:
	if help_dialog:
		help_dialog.open()



func _on_start_pressed() -> void:
	get_tree().change_scene_to_packed(MAIN_GAME_SCENE)


func _on_setting_pressed() -> void:
	if settings_panel:
		_load_settings()
		settings_panel.show()


func _on_settings_back_pressed() -> void:
	if settings_panel:
		settings_panel.hide()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_master_slider_value_changed(value: float) -> void:
	var linear_vol := value / 100.0
	_apply_audio_volume("Master", linear_vol)
	if master_label:
		master_label.text = "%d%%" % int(value)
	_save_settings()


func _on_music_slider_value_changed(value: float) -> void:
	var linear_vol := value / 100.0
	_apply_audio_volume("Music", linear_vol)
	if music_label:
		music_label.text = "%d%%" % int(value)
	_save_settings()


func _on_sfx_slider_value_changed(value: float) -> void:
	var linear_vol := value / 100.0
	_apply_audio_volume("SFX", linear_vol)
	if sfx_label:
		sfx_label.text = "%d%%" % int(value)
	_save_settings()


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	_apply_fullscreen(toggled_on)
	_save_settings()


func _on_settings_reset_pressed() -> void:
	_reset_settings()


func _load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_FILE_PATH)

	var master_vol: float = DEFAULT_MASTER_VOLUME
	var music_vol: float = DEFAULT_MUSIC_VOLUME
	var sfx_vol: float = DEFAULT_SFX_VOLUME
	var is_fullscreen: bool = DEFAULT_FULLSCREEN

	if err == OK:
		master_vol = float(config.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME))
		music_vol = float(config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME))
		sfx_vol = float(config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME))
		is_fullscreen = bool(config.get_value("display", "fullscreen", DEFAULT_FULLSCREEN))

	master_vol = clampf(master_vol, 0.0, 1.0)
	music_vol = clampf(music_vol, 0.0, 1.0)
	sfx_vol = clampf(sfx_vol, 0.0, 1.0)

	_apply_audio_volume("Master", master_vol)
	_apply_audio_volume("Music", music_vol)
	_apply_audio_volume("SFX", sfx_vol)
	_apply_fullscreen(is_fullscreen)
	_update_ui_state(master_vol, music_vol, sfx_vol, is_fullscreen)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_FILE_PATH)

	var master_vol: float = (master_slider.value / 100.0) if master_slider else DEFAULT_MASTER_VOLUME
	var music_vol: float = (music_slider.value / 100.0) if music_slider else DEFAULT_MUSIC_VOLUME
	var sfx_vol: float = (sfx_slider.value / 100.0) if sfx_slider else DEFAULT_SFX_VOLUME
	var is_fullscreen: bool = fullscreen_toggle.button_pressed if fullscreen_toggle else DEFAULT_FULLSCREEN

	config.set_value("audio", "master_volume", master_vol)
	config.set_value("audio", "music_volume", music_vol)
	config.set_value("audio", "sfx_volume", sfx_vol)
	config.set_value("display", "fullscreen", is_fullscreen)

	var save_err := config.save(SETTINGS_FILE_PATH)
	if save_err != OK:
		push_warning("Failed to save settings: %d" % save_err)


func _reset_settings() -> void:
	_apply_audio_volume("Master", DEFAULT_MASTER_VOLUME)
	_apply_audio_volume("Music", DEFAULT_MUSIC_VOLUME)
	_apply_audio_volume("SFX", DEFAULT_SFX_VOLUME)
	_apply_fullscreen(DEFAULT_FULLSCREEN)
	_update_ui_state(DEFAULT_MASTER_VOLUME, DEFAULT_MUSIC_VOLUME, DEFAULT_SFX_VOLUME, DEFAULT_FULLSCREEN)
	_save_settings()


func _apply_audio_volume(bus_name: String, linear_vol: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		if linear_vol <= 0.001:
			AudioServer.set_bus_mute(idx, true)
		else:
			AudioServer.set_bus_mute(idx, false)
			AudioServer.set_bus_volume_db(idx, linear_to_db(linear_vol))


func _apply_fullscreen(enabled: bool) -> void:
	var current_mode := DisplayServer.window_get_mode()
	var is_currently_fullscreen := (
		current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	if enabled and not is_currently_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not enabled and is_currently_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _update_ui_state(master_vol: float, music_vol: float, sfx_vol: float, is_fullscreen: bool) -> void:
	var master_pct := int(roundf(master_vol * 100.0))
	var music_pct := int(roundf(music_vol * 100.0))
	var sfx_pct := int(roundf(sfx_vol * 100.0))

	if master_slider:
		master_slider.set_value_no_signal(master_pct)
	if master_label:
		master_label.text = "%d%%" % master_pct

	if music_slider:
		music_slider.set_value_no_signal(music_pct)
	if music_label:
		music_label.text = "%d%%" % music_pct

	if sfx_slider:
		sfx_slider.set_value_no_signal(sfx_pct)
	if sfx_label:
		sfx_label.text = "%d%%" % sfx_pct

	if fullscreen_toggle:
		fullscreen_toggle.set_pressed_no_signal(is_fullscreen)
