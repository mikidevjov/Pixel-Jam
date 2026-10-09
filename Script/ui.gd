extends CanvasLayer
# who did't read this code is gay

const MAIN_MENU_SCENE := preload("res://Scene/start_menu.tscn")

@onready var kills_label: Label = $Control/KillsLabel
@onready var hearts_container: HBoxContainer = $Control/HeartsContainer
@onready var level_label: Label = $Control/LevelLabel
@onready var game_over_label: Label = $Control/GameOverLabel
@onready var level_complete_label: Label = $Control/LevelCompleteLabel
@onready var victory_label: Label = $Control/VictoryLabel
@onready var restart_hint: Label = $Control/RestartHint
@onready var level_banner: Label = $Control/LevelBanner

@onready var laser_container: VBoxContainer = $Control/LaserContainer
@onready var laser_bar: ProgressBar = $Control/LaserContainer/LaserBar

@onready var dust_container: VBoxContainer = $Control/DustContainer
@onready var dust_bar: ProgressBar = $Control/DustContainer/DustBar
@onready var dust_count_label: Label = $Control/DustContainer/DustCountLabel

@onready var boss_container: VBoxContainer = $Control/BossContainer
@onready var boss_bar: ProgressBar = $Control/BossContainer/BossBar
@onready var boss_label: Label = $Control/BossContainer/BossLabel

@onready var help_dialog: HelpDialog = $Control/HelpDialog

var heart_tex = preload("res://Assets/Resources/atlas_heart.tres")
const HUD_MAX_HEART_ICONS := 12

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide_all_overlays()
	setup_for_run()
	update_health(3)
	if help_dialog:
		help_dialog.pauses_gameplay = true
		help_dialog.close()

func hide_all_overlays():
	if game_over_label:
		game_over_label.hide()
	if level_complete_label:
		level_complete_label.hide()
	if victory_label:
		victory_label.hide()
	if restart_hint:
		restart_hint.hide()
	if level_banner:
		level_banner.hide()

func setup_for_run():
	hide_all_overlays()
	if level_label:
		level_label.hide()
	if kills_label:
		kills_label.show()
		kills_label.text = "Score: 0"
	if laser_container:
		laser_container.show()
		laser_bar.value = 100.0
	if dust_container:
		dust_container.show()
		update_dust_collection(0.0)
	if boss_container:
		boss_container.hide()

func update_score(total: int):
	if kills_label:
		kills_label.text = "Score: %d" % total

func update_health(health: int):
	if not hearts_container:
		return
	for child in hearts_container.get_children():
		child.queue_free()
	var count := maxi(0, health)
	var icon_count := mini(count, HUD_MAX_HEART_ICONS)
	for i in range(icon_count):
		var heart_rect = TextureRect.new()
		heart_rect.texture = heart_tex
		heart_rect.stretch_mode = TextureRect.STRETCH_KEEP
		heart_rect.custom_minimum_size = Vector2(PixelSpec.HUD_HEART_SIZE)
		heart_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hearts_container.add_child(heart_rect)
	if count > HUD_MAX_HEART_ICONS:
		var more := Label.new()
		more.text = "+%d" % (count - HUD_MAX_HEART_ICONS)
		more.add_theme_font_size_override("font_size", 8)
		more.add_theme_color_override("font_color", Color(0.95, 0.75, 0.78, 1))
		more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hearts_container.add_child(more)

func update_laser_energy(current: float, max_val: float):
	if laser_bar:
		laser_bar.value = (current / max_val) * 100.0

func update_dust_collection(percent: float) -> void:
	if not dust_container:
		return
	dust_container.show()
	var clamped := clampf(percent, 0.0, 100.0)
	if dust_bar:
		dust_bar.value = clamped
	if dust_count_label:
		dust_count_label.text = "%d%%" % int(round(clamped))

func show_tiles_restored_float(tile_count: int) -> void:
	var root: Control = $Control
	if root == null:
		return
	var lbl := Label.new()
	lbl.text = "+%d tiles restored" % tile_count
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lbl.z_index = 60
	var text_w := 200.0
	var text_h := 16.0
	var vp := Vector2(PixelSpec.VIEWPORT_SIZE)
	lbl.custom_minimum_size = Vector2(text_w, text_h)
	lbl.size = Vector2(text_w, text_h)
	lbl.position = Vector2((vp.x - text_w) * 0.5, vp.y * 0.5 - text_h * 0.5)
	root.add_child(lbl)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 32.0, 0.95).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.95).set_delay(0.25)
	tween.chain().tween_callback(lbl.queue_free)

func show_center_fade_text(message: String, font_size: int = 14) -> void:
	var root: Control = $Control
	if root == null:
		return
	var lbl := Label.new()
	lbl.text = message
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lbl.z_index = 60
	var text_w := 260.0
	var text_h := float(font_size) + 6.0
	var vp := Vector2(PixelSpec.VIEWPORT_SIZE)
	lbl.custom_minimum_size = Vector2(text_w, text_h)
	lbl.size = Vector2(text_w, text_h)
	lbl.position = Vector2((vp.x - text_w) * 0.5, vp.y * 0.5 - text_h * 0.5)
	root.add_child(lbl)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 36.0, 1.85).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 1.85).set_delay(0.45)
	tween.chain().tween_callback(lbl.queue_free)


func show_next_wave_float() -> void:
	show_center_fade_text("Next wave arrives", 14)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and event.keycode == KEY_TAB:
		_go_to_main_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		_handle_escape_help()
		get_viewport().set_input_as_handled()

func _go_to_main_menu() -> void:
	if help_dialog and help_dialog.is_open():
		help_dialog.close()
	get_tree().paused = false
	get_tree().change_scene_to_packed(MAIN_MENU_SCENE)

func _handle_escape_help() -> void:
	if _is_game_over():
		return
	if not help_dialog:
		return
	if help_dialog.is_open():
		help_dialog.close()
	else:
		help_dialog.open()

func _is_game_over() -> bool:
	var main = get_tree().get_first_node_in_group("main")
	return main != null and main.get("is_game_over")

func show_game_over(final_score: int):
	if help_dialog and help_dialog.is_open():
		help_dialog.close()
	if game_over_label:
		game_over_label.text = "SCORE\n%d" % final_score
		game_over_label.add_theme_font_size_override("font_size", 24)
		game_over_label.show()
	if restart_hint:
		restart_hint.text = "Press [R], [Space], or [Enter] to Restart"
		restart_hint.show()
