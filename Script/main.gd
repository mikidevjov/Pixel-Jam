extends Node2D

const SCORE_MINION := 1
const SCORE_MEDIUM := 10
const SCORE_BOSS := 50

@export var spawn_interval: float = 1.2
@export var max_active_enemies: int = 7
@export var medium_unlock_time: float = 36.0
@export var medium_dust_delay: float = 10.0

const BOSS_SPAWN_INTERVALS: Array[float] = [90.0, 80.0, 70.0, 65.0, 60.0, 55.0, 50.0]

const LASER_UPGRADE_INTERVAL := 60.0
const LASER_ENERGY_BONUS := 25.0
const TILE_SPEED_INTERVAL := 30.0
const TILE_SPEED_MULTIPLIER := 1.20
const HEART_ROLL_INTERVAL := 45.0
const HEART_SPAWN_CHANCE := 0.12
const HEART_KILL_CHANCE_MEDIUM := 0.015
const HEART_KILL_CHANCE_BOSS := 0.20
const ENEMY_SPAWN_SPEEDUP_ON_BOSS := 1.5
const MIN_ENEMY_SPAWN_INTERVAL := 0.28
const BOSS_DEATH_WAVE_MINIONS := 6
const BOSS_DEATH_WAVE_MEDIUMS := 3
const BOSS_DEATH_WAVE_STAGGER := 0.12

const _NO_HEART_PREFER_POS := Vector2(999999.0, 999999.0)

const DUST_PICKUPS_FOR_RESTORE := 2
const DUST_RESTORE_TILES_MIN := 3
const DUST_RESTORE_TILES_MAX := 4

var score: int = 0
var dust_pickups_this_cycle: int = 0
var run_elapsed: float = 0.0
var spawn_timer: float = 0.0
var _base_spawn_interval: float = 1.2
var _current_spawn_interval: float = 1.2
var _enemy_spawn_rate_multiplier: float = 1.0
var dust_spawn_timer: float = 0.0
var heart_roll_timer: float = 0.0
var _boss_spawn_step: int = 0
var _next_boss_spawn_at: float = BOSS_SPAWN_INTERVALS[0]
var _stage2_music_started: bool = false
var _stage3_music_started: bool = false
var _medium_arrival_announced: bool = false
var _next_laser_upgrade_at: float = LASER_UPGRADE_INTERVAL
var _next_tile_speed_at: float = TILE_SPEED_INTERVAL

var is_game_over: bool = false
var trauma: float = 0.0

var minion_scene = preload("res://Scene/minion.tscn")
var medium_enemy_scene = preload("res://Scene/medium_enemy.tscn")
var boss_scene = preload("res://Scene/boss.tscn")
var restoration_wave_scene = preload("res://Scene/restoration_wave.tscn")
var core_dust_scene = preload("res://Scene/core_dust.tscn")
var heart_pickup_scene = preload("res://Scene/heart_pickup.tscn")

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
	_base_spawn_interval = spawn_interval
	_current_spawn_interval = spawn_interval
	_enemy_spawn_rate_multiplier = 1.0
	run_elapsed = 0.0
	score = 0
	_boss_spawn_step = 0
	_next_boss_spawn_at = BOSS_SPAWN_INTERVALS[0]
	_stage2_music_started = false
	_stage3_music_started = false
	_medium_arrival_announced = false
	dust_spawn_timer = 0.0
	heart_roll_timer = 0.0
	_next_laser_upgrade_at = LASER_UPGRADE_INTERVAL
	_next_tile_speed_at = TILE_SPEED_INTERVAL
	AudioManager.play_music("stage1")

	_clear_all_enemies_and_projectiles()

	_setup_arena()
	_apply_gameplay_layout()

	if ui:
		ui.setup_for_run()

	if player:
		player.setup_for_run()

	update_ui()
	_reset_dust_collection()
	if ui and ui.has_method("show_center_fade_text"):
		ui.call_deferred("show_center_fade_text", "EASY MODE", 16)

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
	if get_tree().paused and not is_game_over:
		return

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
	if not is_game_over and run_elapsed >= medium_unlock_time and not _medium_arrival_announced:
		_medium_arrival_announced = true
		if ui and ui.has_method("show_center_fade_text"):
			ui.show_center_fade_text("Enemy arrives", 14)
	if (
		not is_game_over
		and not _stage2_music_started
		and not _stage3_music_started
		and run_elapsed >= medium_unlock_time
	):
		_stage2_music_started = true
		AudioManager.play_music("stage2")
	_process_spawning(delta)
	_process_dust_spawns(delta)
	_process_heart_spawns(delta)
	_process_run_escalation()

func _process_spawning(delta: float) -> void:
	var alive_enemies: int = _alive_enemy_count()
	spawn_timer += delta
	if spawn_timer >= _current_spawn_interval:
		spawn_timer = 0.0
		if alive_enemies < max_active_enemies:
			_spawn_wave_enemy()

	_try_spawn_boss()

func _try_spawn_boss() -> void:
	if is_game_over or run_elapsed < _next_boss_spawn_at:
		return
	if not boss_scene:
		return
	var boss: Node2D = boss_scene.instantiate()
	if boss.has_signal("boss_died"):
		boss.boss_died.connect(_on_boss_died.bind(boss))
	add_child(boss)
	if arena and arena.has_method("get_boss_spawn_position"):
		boss.global_position = arena.get_boss_spawn_position()
	else:
		boss.global_position = Vector2(0.0, -68.0)
	boss.base_pos = boss.position
	if not _stage3_music_started:
		_stage3_music_started = true
		AudioManager.play_music("stage3")
	add_trauma(0.5)
	var interval_idx := mini(_boss_spawn_step + 1, BOSS_SPAWN_INTERVALS.size() - 1)
	_next_boss_spawn_at = run_elapsed + BOSS_SPAWN_INTERVALS[interval_idx]
	_boss_spawn_step = mini(_boss_spawn_step + 1, BOSS_SPAWN_INTERVALS.size() - 1)

func _enemy_spawn_margin_position() -> Vector2:
	if arena and arena.has_method("get_spawn_margin_position"):
		return arena.get_spawn_margin_position()
	return Vector2(0.0, -200.0)


func _spawn_minion_at_margin() -> void:
	if not minion_scene:
		return
	var minion = minion_scene.instantiate()
	minion.soul_size = Minion.SoulSize.MEDIUM
	minion.global_position = _enemy_spawn_margin_position()
	add_child(minion)


func _spawn_medium_at_margin() -> void:
	if not medium_enemy_scene:
		return
	var med = medium_enemy_scene.instantiate()
	med.global_position = _enemy_spawn_margin_position()
	add_child(med)


func _spawn_wave_enemy() -> void:
	var medium_count := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is MediumEnemy:
			medium_count += 1

	var mediums_allowed: bool = run_elapsed >= medium_unlock_time
	if mediums_allowed and medium_count < 3 and randf() < 0.35:
		_spawn_medium_at_margin()
	else:
		_spawn_minion_at_margin()


func _spawn_post_boss_enemy_wave() -> void:
	if is_game_over:
		return
	var stagger := BOSS_DEATH_WAVE_STAGGER / _enemy_spawn_rate_multiplier
	var delay: float = 0.0
	for _i in range(BOSS_DEATH_WAVE_MEDIUMS):
		var spawn_delay := delay
		get_tree().create_timer(spawn_delay).timeout.connect(func() -> void:
			if is_instance_valid(self) and not is_game_over:
				_spawn_medium_at_margin()
		)
		delay += stagger
	for _j in range(BOSS_DEATH_WAVE_MINIONS):
		var spawn_delay := delay
		get_tree().create_timer(spawn_delay).timeout.connect(func() -> void:
			if is_instance_valid(self) and not is_game_over:
				_spawn_minion_at_margin()
		)
		delay += stagger

func _alive_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemy").size()

func add_score(points: int) -> void:
	if is_game_over or points <= 0:
		return
	score += points
	add_trauma(0.12)
	update_ui()

func enemy_killed(_at_world: Vector2 = _NO_HEART_PREFER_POS) -> void:
	add_score(SCORE_MINION)

func medium_enemy_killed(at_world: Vector2 = _NO_HEART_PREFER_POS) -> void:
	add_score(SCORE_MEDIUM)
	_try_roll_heart_drop(HEART_KILL_CHANCE_MEDIUM, at_world, true)


func _process_dust_spawns(delta: float) -> void:
	if is_game_over:
		return

	dust_spawn_timer += delta
	while dust_spawn_timer >= medium_dust_delay:
		dust_spawn_timer -= medium_dust_delay
		_spawn_core_dust_on_land()


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

func collect_dust(_amount: float = 1.0) -> void:
	_add_dust_pickups(1)


func collect_heart() -> void:
	if is_game_over or not player:
		return
	if player.heal(1):
		AudioManager.play_sfx("Dust_Pickup")
		add_trauma(0.05)


func _process_heart_spawns(delta: float) -> void:
	if is_game_over:
		return
	heart_roll_timer += delta
	if heart_roll_timer < HEART_ROLL_INTERVAL:
		return
	heart_roll_timer = 0.0
	if randf() < HEART_SPAWN_CHANCE:
		_spawn_heart_pickup(_NO_HEART_PREFER_POS, false)


func _try_roll_heart_drop(chance: float, at_world: Vector2, from_kill: bool) -> void:
	if is_game_over or chance <= 0.0:
		return
	if randf() < chance:
		_spawn_heart_pickup(at_world, from_kill)


func _resolve_heart_spawn_position(prefer_world: Vector2) -> Vector2:
	if not arena:
		return _NO_HEART_PREFER_POS
	if prefer_world != _NO_HEART_PREFER_POS:
		if arena.has_method("is_position_walkable") and arena.is_position_walkable(prefer_world):
			return prefer_world
		if arena.has_method("world_to_grid") and arena.has_method("grid_to_world"):
			var cell: Vector2i = arena.world_to_grid(prefer_world)
			if arena.has_method("is_grid_walkable_for_player") and arena.is_grid_walkable_for_player(cell.x, cell.y):
				return arena.grid_to_world(cell.x, cell.y)
	if arena.has_method("get_random_walkable_world_position") and _arena_has_walkable_tiles():
		return arena.get_random_walkable_world_position()
	return _NO_HEART_PREFER_POS


func _spawn_heart_pickup(prefer_world: Vector2, from_kill: bool) -> void:
	if is_game_over or not heart_pickup_scene or not arena or not player:
		return
	if from_kill:
		for h in get_tree().get_nodes_in_group("heart_pickup"):
			if is_instance_valid(h):
				h.queue_free()
	elif not get_tree().get_nodes_in_group("heart_pickup").is_empty():
		return
	var spawn_pos := _resolve_heart_spawn_position(prefer_world)
	if spawn_pos == _NO_HEART_PREFER_POS:
		return
	var heart := heart_pickup_scene.instantiate()
	heart.global_position = spawn_pos
	heart.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(heart)


func _process_run_escalation() -> void:
	if is_game_over:
		return
	while run_elapsed >= _next_tile_speed_at:
		_next_tile_speed_at += TILE_SPEED_INTERVAL
		_escalate_tile_fall_speed()
	while run_elapsed >= _next_laser_upgrade_at:
		_next_laser_upgrade_at += LASER_UPGRADE_INTERVAL
		_upgrade_laser_timelimit()


func _escalate_tile_fall_speed() -> void:
	if arena and arena.has_method("accelerate_tile_fall_speed"):
		arena.accelerate_tile_fall_speed(TILE_SPEED_MULTIPLIER)


func _upgrade_laser_timelimit() -> void:
	if player and player.has_method("upgrade_laser_timelimit"):
		player.upgrade_laser_timelimit(LASER_ENERGY_BONUS)
		if ui:
			ui.update_laser_energy(player.laser_energy, player.max_laser_energy)


func _reset_dust_collection() -> void:
	dust_pickups_this_cycle = 0
	if ui and ui.has_method("update_dust_collection"):
		ui.update_dust_collection(0.0)


func _add_dust_pickups(count: int) -> void:
	if is_game_over or count <= 0:
		return
	AudioManager.play_sfx("Dust_Pickup")
	add_trauma(0.08)
	dust_pickups_this_cycle += count
	_sync_dust_collection_ui()
	while dust_pickups_this_cycle >= DUST_PICKUPS_FOR_RESTORE:
		dust_pickups_this_cycle -= DUST_PICKUPS_FOR_RESTORE
		_trigger_dust_land_restore()
	_sync_dust_collection_ui()


func _sync_dust_collection_ui() -> void:
	if not ui or not ui.has_method("update_dust_collection"):
		return
	var pct := (
		float(dust_pickups_this_cycle) / float(DUST_PICKUPS_FOR_RESTORE)
	) * 100.0
	ui.update_dust_collection(pct)


func _trigger_dust_land_restore() -> void:
	var tile_count := randi_range(DUST_RESTORE_TILES_MIN, DUST_RESTORE_TILES_MAX)
	var restored := 0
	if arena and arena.has_method("restore_fallen_tiles"):
		restored = arena.restore_fallen_tiles(tile_count).size()
	if restored <= 0:
		restored = tile_count
	if player:
		spawn_restoration_wave(player.global_position, Color(2.5, 0.4, 0.3, 0.9), 280.0)
	if ui:
		if ui.has_method("show_tiles_restored_float"):
			ui.show_tiles_restored_float(restored)
		add_trauma(0.12)

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

func _accelerate_enemy_spawn_rate_after_boss() -> void:
	_enemy_spawn_rate_multiplier *= ENEMY_SPAWN_SPEEDUP_ON_BOSS
	_current_spawn_interval = maxf(
		MIN_ENEMY_SPAWN_INTERVAL,
		_base_spawn_interval / _enemy_spawn_rate_multiplier
	)


func _on_boss_died(boss: Node2D) -> void:
	var boss_pos: Vector2 = _NO_HEART_PREFER_POS
	if is_instance_valid(boss):
		boss_pos = boss.global_position
	add_score(SCORE_BOSS)
	add_trauma(0.6)
	_try_roll_heart_drop(HEART_KILL_CHANCE_BOSS, boss_pos, true)
	AudioManager.play_sfx("boss_very_dead")
	_accelerate_enemy_spawn_rate_after_boss()
	if ui and ui.has_method("show_center_fade_text"):
		ui.show_center_fade_text("Next wave arrives", 14)
	var wave_tween := create_tween()
	wave_tween.tween_interval(0.85)
	wave_tween.tween_callback(_spawn_post_boss_enemy_wave)

func on_boss_dust_collected() -> void:
	add_trauma(0.4)
	if player:
		spawn_restoration_wave(
			player.global_position,
			Color(3.0, 0.55, 0.25, 0.95),
			420.0
		)
	_add_dust_pickups(DUST_PICKUPS_FOR_RESTORE)

func _on_player_died() -> void:
	is_game_over = true
	_stop_game()
	AudioManager.play_music("game_over", false)
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
	for h in get_tree().get_nodes_in_group("heart_pickup"):
		if is_instance_valid(h):
			h.queue_free()
