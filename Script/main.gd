extends Node2D

var kills: int = 0
@export var level_index: int = 1
@export var required_kills: int = 20
@export var spawn_interval: float = 1.2
@export var max_active_enemies: int = 7
@export var level_1_minion_cap: int = 20

var spawn_timer: float = 0.0
var minions_spawned: int = 0
var minion_spawn_replacements: int = 0
var minion_scene = preload("res://Scene/minion.tscn")

var is_game_over: bool = false
var is_level_complete: bool = false
var trauma: float = 0.0

@onready var player = $Player
@onready var ui = $UI
@onready var camera = $Camera2D
@onready var arena = $Arena

func _ready():
	get_tree().paused = false
	add_to_group("main")
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ui:
		ui.process_mode = Node.PROCESS_MODE_ALWAYS
	if player:
		player.player_died.connect(_on_player_died)
		player.player_health_changed.connect(_on_player_health_changed)
		player.player_fired.connect(_on_player_fired)
	
	if arena and arena.has_signal("ring_decaying"):
		arena.ring_decaying.connect(_on_ring_decaying)
		
	update_ui()

func _process(delta: float):
	# Screen shake update
	if trauma > 0.0:
		trauma = max(0.0, trauma - delta * 2.0)
		if camera:
			camera.offset = Vector2(
				randf_range(-1.0, 1.0) * trauma * 8.0,
				randf_range(-1.0, 1.0) * trauma * 8.0
			)
	elif camera and camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

	# Restart handler
	if is_game_over or is_level_complete:
		if Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_R):
			get_tree().paused = false
			get_tree().reload_current_scene()
		return

	_try_finish_level_one()

	# Minion spawning
	var alive_enemies: int = _alive_enemy_count()
	if alive_enemies == 0 and _can_spawn_more_minions():
		spawn_enemy()
	elif _can_spawn_more_minions():
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_timer = 0.0
			if alive_enemies < max_active_enemies:
				spawn_enemy()

func _alive_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemy").size()

func _try_finish_level_one() -> void:
	if level_index != 1 or is_game_over or is_level_complete:
		return
	if kills >= required_kills:
		level_complete()

func on_enemy_lost_without_kill() -> void:
	if is_game_over or is_level_complete:
		return
	if level_index == 1:
		minion_spawn_replacements += 1

func _can_spawn_more_minions() -> bool:
	if level_index == 1:
		if kills >= level_1_minion_cap:
			return false
		var spawn_budget: int = level_1_minion_cap + minion_spawn_replacements
		return minions_spawned < spawn_budget
	return true

func spawn_enemy():
	var spawn_pos: Vector2 = Vector2(0, -200)
	if arena and arena.has_method("get_spawn_margin_position"):
		spawn_pos = arena.get_spawn_margin_position()

	if not _can_spawn_more_minions():
		return

	var minion = minion_scene.instantiate()
	minion.soul_size = _black_soul_size_for_level(level_index)
	minion.global_position = spawn_pos
	add_child(minion)
	minions_spawned += 1

func _black_soul_size_for_level(level: int) -> Minion.SoulSize:
	# Level 1 roster: medium black souls (minions) only.
	match level:
		1:
			return Minion.SoulSize.MEDIUM
		_:
			return Minion.SoulSize.MEDIUM

func enemy_killed():
	if is_game_over or is_level_complete:
		return
	kills += 1
	add_trauma(0.15)
	update_ui()
	if kills >= required_kills:
		level_complete()

func update_ui():
	if ui:
		ui.update_kills(kills, required_kills)
		
func _on_player_health_changed(new_health: int):
	add_trauma(0.4)
	if ui:
		ui.update_health(new_health)

func _on_player_fired():
	add_trauma(0.05)

func _on_ring_decaying(_ring_index: int):
	add_trauma(0.25)

func _on_player_died():
	is_game_over = true
	_stop_level()
	add_trauma(0.6)
	if ui:
		var reason := "SOUL CRUSHED"
		if player and player.get("died_from_void"):
			reason = "FALLEN INTO THE VOID"
		ui.show_game_over(reason)

func level_complete():
	is_level_complete = true
	_stop_level()
	add_trauma(0.3)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("die"):
			enemy.die(false)
		else:
			enemy.queue_free()
	if ui:
		ui.show_level_complete()

func add_trauma(amount: float):
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _stop_level() -> void:
	if arena and arena.has_method("stop_decay"):
		arena.stop_decay()
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
