extends CanvasLayer
# who did't read this code is gay
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

var heart_tex = preload("res://Assets/Resources/atlas_heart.tres")

func _ready():
	hide_all_overlays()
	setup_for_run()
	update_health(3)

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
		kills_label.text = "SCORE: 0"
	if laser_container:
		laser_container.show()
		laser_bar.value = 100.0
	if dust_container:
		dust_container.hide()
	if boss_container:
		boss_container.hide()

func update_score(total: int):
	if kills_label:
		kills_label.text = "SCORE: %d" % total

func update_health(health: int):
	if not hearts_container:
		return
	for child in hearts_container.get_children():
		child.queue_free()
	for i in range(max(0, health)):
		var heart_rect = TextureRect.new()
		heart_rect.texture = heart_tex
		heart_rect.stretch_mode = TextureRect.STRETCH_KEEP
		heart_rect.custom_minimum_size = Vector2(PixelSpec.HUD_HEART_SIZE)
		heart_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hearts_container.add_child(heart_rect)

func update_laser_energy(current: float, max_val: float):
	if laser_bar:
		laser_bar.value = (current / max_val) * 100.0

func show_game_over(final_score: int):
	if game_over_label:
		game_over_label.text = "SCORE\n%d" % final_score
		game_over_label.add_theme_font_size_override("font_size", 24)
		game_over_label.show()
	if restart_hint:
		restart_hint.text = "Press [R], [Space], or [Enter] to Restart"
		restart_hint.show()
