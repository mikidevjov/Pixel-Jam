extends CharacterBody2D

@export var step_interval: float = 0.14
@export var max_health: int = 3
@export var fire_rate: float = 0.22

var health: int = 3
var last_shot_time: float = 999.0
var is_falling: bool = false
var is_dead: bool = false
var died_from_void: bool = false
var invulnerable_timer: float = 0.0
var off_tile_timer: float = 0.0
var game_start_grace: float = 0.5

var grid_pos: Vector2i = Vector2i.ZERO
var step_timer: float = 0.0
var is_stepping: bool = false
var foot_lift: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Sprite2D = $Shadow

var arena: Node2D = null
var projectile_scene = preload("res://Scene/projectile.tscn")

signal player_died
signal player_health_changed(new_health: int)
signal player_fired

func _ready():
	add_to_group("player")
	health = max_health
	arena = get_tree().get_first_node_in_group("arena")
	if sprite:
		sprite.rotation = 0.0
	foot_lift = SoulFootAnchor.apply(self, sprite, shadow)
	call_deferred("_snap_to_grid")

func _snap_to_grid():
	if not arena:
		arena = get_tree().get_first_node_in_group("arena")
	if not arena:
		return
	grid_pos = arena.world_to_grid(global_position)
	global_position = arena.grid_to_world(grid_pos.x, grid_pos.y)

func _process(delta: float):
	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0.0:
			sprite.modulate = Color.WHITE

func _physics_process(delta: float):
	if _is_game_stopped():
		return
	if is_dead or is_falling:
		return

	if game_start_grace > 0.0:
		game_start_grace -= delta

	velocity = Vector2.ZERO

	var mouse_pos: Vector2 = get_global_mouse_position()
	var to_mouse: Vector2 = mouse_pos - global_position
	last_shot_time += delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and last_shot_time >= fire_rate:
		if to_mouse.length_squared() > 16.0:
			shoot(to_mouse.normalized())

	_try_grid_step(delta)
	check_tile_standing(delta)

func _get_grid_input_dir() -> Vector2i:
	var dir := Vector2i.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if dir.x != 0 and dir.y != 0:
		dir.y = 0
	return dir

func _try_grid_step(delta: float):
	if is_stepping:
		return
	if not arena:
		arena = get_tree().get_first_node_in_group("arena")
		if not arena:
			return

	step_timer += delta
	if step_timer < step_interval:
		return

	var move_dir: Vector2i = _get_grid_input_dir()
	if move_dir == Vector2i.ZERO:
		return

	var next: Vector2i = grid_pos + move_dir
	if not arena.is_step_allowed_for_player(next.x, next.y):
		return

	step_timer = 0.0
	_begin_grid_step(next)
	spawn_trail()

func _begin_grid_step(next: Vector2i):
	is_stepping = true
	grid_pos = next
	var target: Vector2 = arena.grid_to_world(next.x, next.y)
	var tween = create_tween()
	tween.tween_property(self, "global_position", target, step_interval * 0.92)
	tween.tween_callback(func():
		is_stepping = false
		global_position = target
	)

func spawn_trail():
	var parent = get_parent()
	if not parent or not sprite:
		return
	var ghost = Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.global_position = sprite.global_position
	ghost.rotation = 0.0
	ghost.modulate = Color(1.0, 0.2, 0.25, 0.45)
	ghost.z_index = z_index - 1
	parent.add_child(ghost)

	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ghost.queue_free)

func shoot(dir: Vector2):
	last_shot_time = 0.0
	var proj = projectile_scene.instantiate()
	proj.direction = dir
	get_parent().add_child(proj)
	proj.global_position = global_position + SoulFootAnchor.chest_offset(sprite, foot_lift) + dir * 14.0
	if proj.has_method("setup"):
		proj.setup(true)
	player_fired.emit()

func check_tile_standing(delta: float):
	if game_start_grace > 0.0 or is_stepping:
		return
	if not arena:
		arena = get_tree().get_first_node_in_group("arena")
		if not arena:
			return

	if arena.is_position_walkable(global_position):
		off_tile_timer = 0.0
	else:
		off_tile_timer += delta
		if off_tile_timer >= 0.2:
			fall_into_void()

func _is_game_stopped() -> bool:
	var main = get_tree().get_first_node_in_group("main")
	return main != null and (main.get("is_game_over") or main.get("is_level_complete"))

func fall_into_void():
	if is_falling or is_dead:
		return
	died_from_void = true
	is_falling = true
	velocity = Vector2.ZERO
	if shadow:
		shadow.hide()

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 40.0, 0.7)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.7)
	tween.tween_property(self, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(die)

func take_damage(amount: int) -> bool:
	if is_dead or is_falling or invulnerable_timer > 0.0:
		return false

	health -= amount
	invulnerable_timer = 1.0
	player_health_changed.emit(health)

	var tween = create_tween()
	tween.set_loops(4)
	tween.tween_property(sprite, "modulate", Color(2.5, 0.3, 0.3, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.5), 0.1)

	if health <= 0:
		die()
	return true

func die():
	if is_dead:
		return
	is_dead = true
	player_died.emit()
	hide()
