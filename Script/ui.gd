extends CanvasLayer

@onready var kills_label: Label = $Control/KillsLabel
@onready var hearts_container: HBoxContainer = $Control/HeartsContainer
@onready var game_over_label: Label = $Control/GameOverLabel
@onready var level_complete_label: Label = $Control/LevelCompleteLabel
@onready var restart_hint: Label = $Control/RestartHint

var heart_tex = preload("res://Assets/Sprites/heart.png")

func _ready():
	if game_over_label:
		game_over_label.hide()
	if level_complete_label:
		level_complete_label.hide()
	if restart_hint:
		restart_hint.hide()
	update_health(3)

func update_kills(current: int, required: int):
	if kills_label:
		kills_label.text = "MINIONS: %d / %d" % [current, required]

func update_health(health: int):
	if not hearts_container:
		return
	for child in hearts_container.get_children():
		child.queue_free()
	for i in range(max(0, health)):
		var heart_rect = TextureRect.new()
		heart_rect.texture = heart_tex
		heart_rect.stretch_mode = TextureRect.STRETCH_KEEP
		heart_rect.custom_minimum_size = Vector2(16, 16)
		hearts_container.add_child(heart_rect)

func show_game_over(reason: String = ""):
	if game_over_label:
		if reason != "":
			game_over_label.text = "GAME OVER\n%s" % reason
		else:
			game_over_label.text = "GAME OVER"
		game_over_label.show()
	if restart_hint:
		restart_hint.text = "Press [R], [Space], or [Enter] to Restart"
		restart_hint.show()

func show_level_complete():
	if level_complete_label:
		level_complete_label.text = "LEVEL 1 COMPLETE\nLEVEL 2 NOT IMPLEMENTED"
		level_complete_label.show()
	if restart_hint:
		restart_hint.text = "Press [R], [Space], or [Enter] to Play Again"
		restart_hint.show()
