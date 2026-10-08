extends Node2D

const SCORE_MINION := 1
const SCORE_MEDIUM := 10
const SCORE_BOSS := 50

@export var spawn_interval: float = 1.2
@export var max_active_enemies: int = 7
@export var medium_unlock_time: float = 36.0
@export var boss_unlock_time: float = 90.0
@export var medium_dust_delay: float = 10.0

var score: int = 0
var run_elapsed: float = 0.0
var spawn_timer: float = 0.0
var dust_spawn_timer: float = 0.0
var pending_dust_spawns: Array[float] = []
var boss_spawned_this_run: bool = false

var is_game_over: bool = false
var trauma: float = 0.0

var minion_scene = preload("res://Scene/minion.tscn")
var medium_enemy_scene = preload("res://Scene/medium_enemy.tscn")
var boss_scene = preload("res://Scene/boss.tscn")
var restoration_wave_scene = preload("res://Scene/restoration_wave.tscn")
var core_dust_scene = preload("res://Scene/core_dust.tscn")

var current_boss: Node2D = null

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
		player.laser_energy_changed.connect(_on_player_laser_energy_changed)

	if arena and arena.has_signal("ring_decaying"):
		arena.ring_decaying.connect(_on_ring_decaying)

	start_game()

func start_game() -> void:
	is_game_over = false
	get_tree().paused = false
	spawn_timer = 0.0
	run_elapsed = 0.0
	score = 0
	boss_spawned_this_run = false
	current_boss = null
	dust_spawn_timer = 0.0
	pending_dust_spawns.clear()

	_clear_all_enemies_and_projectiles()

	_setup_arena()
	_apply_gameplay_layout()

	if ui:
		ui.setup_for_run()

	if player:
		player.setup_for_run()

	update_ui()

func _setup_arena() -> void:
	if not arena:
		return
	arena.setup_arena(8, 8, 5.0, true, false)
	arena.use_edge_tile_decay = true
	arena.min_cluster_size = Vector2i(4, 4)
	arena.min_remaining_tiles = 16
	arena.configure_tile_decay(1.0, 1.0, true)


func _apply_gameplay_layout() -> void:
	var offset := Vector2(0.0, float(PixelSpec.GAMEPLAY_VERTICAL_OFFSET))
	if arena:
		arena.position = offset
	if player:
		player.spawn_world_position = offset

func _process(delta: float):
	if trauma > 0.0:
		trauma = max(0.0, trauma - delta * 2.0)
		if camera:
			camera.offset = Vector2(
				randf_range(-1.0, 1.0) * trauma * 8.0,
				randf_range(-1.0, 1.0) * trauma * 8.0
			)
	elif camera and camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

	if is_game_over:
		if Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_R):
			get_tree().paused = false
			start_game()
		return

	run_elapsed += delta
	_process_spawning(delta)
	_process_dust_spawns(delta)

func _process_spawning(delta: float) -> void:
	var alive_enemies: int = _alive_enemy_count()
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		if alive_enemies < max_active_enemies:
			_spawn_wave_enemy()

	_try_spawn_boss()

func _try_spawn_boss() -> void:
	if boss_spawned_this_run or run_elapsed < boss_unlock_time:
		return
	if get_tree().get_first_node_in_group("boss"):
		return
	if not boss_scene:
		return
	boss_spawned_this_run = true
	current_boss = boss_scene.instantiate()
	if current_boss.has_signal("boss_died"):
		current_boss.boss_died.connect(_on_boss_died)
	add_child(current_boss)
	if arena and arena.has_method("get_boss_spawn_position"):
		current_boss.global_position = arena.get_boss_spawn_position()
	else:
		current_boss.global_position = Vector2(0.0, -68.0)
	current_boss.base_pos = current_boss.position
	add_trauma(0.5)

func _spawn_wave_enemy() -> void:
	var spawn_pos: Vector2 = Vector2(0, -200)
	if arena and arena.has_method("get_spawn_margin_position"):
		spawn_pos = arena.get_spawn_margin_position()

	var medium_count := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is MediumEnemy:
			medium_count += 1

	var mediums_allowed: bool = run_elapsed >= medium_unlock_time
	if mediums_allowed and medium_count < 3 and randf() < 0.35:
		var med = medium_enemy_scene.instantiate()
		med.global_position = spawn_pos
		add_child(med)
	else:
		var minion = minion_scene.instantiate()
		minion.soul_size = Minion.SoulSize.MEDIUM
		minion.global_position = spawn_pos
		add_child(minion)

func _alive_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemy").size()

func add_score(points: int) -> void:
	if is_game_over or points <= 0:
		return
	score += points
	add_trauma(0.12)
	update_ui()

func enemy_killed() -> void:
	add_score(SCORE_MINION)

func medium_enemy_killed() -> void:
	add_score(SCORE_MEDIUM)
	pending_dust_spawns.append(run_elapsed + medium_dust_delay)


func _process_dust_spawns(delta: float) -> void:
	if is_game_over:
		return

	dust_spawn_timer += delta
	while dust_spawn_timer >= medium_dust_delay:
		dust_spawn_timer -= medium_dust_delay
		_spawn_core_dust_on_land()

	var i: int = 0
	while i < pending_dust_spawns.size():
		if run_elapsed >= pending_dust_spawns[i]:
			pending_dust_spawns.remove_at(i)
			_spawn_core_dust_on_land()
		else:
			i += 1


func _spawn_core_dust_on_land() -> void:
	if is_game_over or not core_dust_scene or not arena:
		return
	if not arena.has_method("get_random_walkable_world_position"):
		return
	if not _arena_has_walkable_tiles():
		return
	var dust_pos: Vector2 = arena.get_random_walkable_world_position()
	var dust = core_dust_scene.instantiate()
	dust.global_position = dust_pos
	dust.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(dust)


func _arena_has_walkable_tiles() -> bool:
	if not arena:
		return false
	for gy in range(arena.grid_height):
		for gx in range(arena.grid_width):
			if arena.is_grid_walkable_for_player(gx, gy):
				return true
	return false

func collect_dust(_amount: float) -> void:
	if is_game_over:
		return
	add_trauma(0.08)
	if arena and arena.has_method("restore_fallen_tiles"):
		arena.restore_fallen_tiles(1)
	if player:
		spawn_restoration_wave(player.global_position, Color(2.5, 0.4, 0.3, 0.9), 280.0)

func spawn_restoration_wave(pos: Vector2, color: Color = Color(2.5, 0.3, 0.3, 0.9), radius: float = 350.0) -> void:
	if restoration_wave_scene:
		var wave = restoration_wave_scene.instantiate()
		wave.global_position = pos
		wave.ring_color = color
		wave.max_radius = radius
		add_child(wave)

func on_enemy_lost_without_kill() -> void:
	pass

func update_ui() -> void:
	if ui:
		ui.update_score(score)

func _on_player_laser_energy_changed(current: float, max_val: float) -> void:
	if ui:
		ui.update_laser_energy(current, max_val)

func _on_player_health_changed(new_health: int) -> void:
	add_trauma(0.4)
	if ui:
		ui.update_health(new_health)

func _on_player_fired() -> void:
	add_trauma(0.05)

func _on_ring_decaying(_ring_index: int) -> void:
	add_trauma(0.25)

func _on_boss_died() -> void:
	add_score(SCORE_BOSS)
	add_trauma(0.6)
	current_boss = null

func on_boss_dust_collected() -> void:
	add_trauma(0.4)
	if arena and arena.has_method("restore_fallen_tiles"):
		arena.restore_fallen_tiles(2)

func _on_player_died() -> void:
	is_game_over = true
	_stop_game()
	add_trauma(0.6)
	if ui:
		ui.show_game_over(score)

func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _stop_game() -> void:
	if arena and arena.has_method("stop_decay"):
		arena.stop_decay()
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS

func _clear_all_enemies_and_projectiles() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			e.queue_free()
	for p in get_tree().get_nodes_in_group("projectile"):
		if is_instance_valid(p):
			p.queue_free()
	for d in get_tree().get_nodes_in_group("core_dust"):
		if is_instance_valid(d):
			d.queue_free()
	for b in get_tree().get_nodes_in_group("big_core_dust"):
		if is_instance_valid(b):
			b.queue_free()
