extends Node2D

@export var grid_width: int = 12
@export var grid_height: int = 12
@export var tile_size: float = 40.0
@export var decay_interval: float = 10.0

var tiles: Dictionary = {}
var decay_timer: float = 0.0
var current_ring: int = 0
var max_ring: int = 0
var decay_enabled: bool = true

signal ring_decaying(ring_index: int)

var tile_scene = preload("res://Scene/tile.tscn")

func get_tile_count() -> int:
	return grid_width * grid_height

func _ready():
	add_to_group("arena")
	max_ring = min(grid_width, grid_height) / 2

	for gy in range(grid_height):
		for gx in range(grid_width):
			var t = tile_scene.instantiate()
			t.position = get_tile_center_local(gx, gy)
			add_child(t)
			t.z_index = gy
			if t.has_method("set_tile_size"):
				t.set_tile_size(tile_size)
			if t.has_method("capture_origin"):
				t.capture_origin()
			tiles[Vector2i(gx, gy)] = t

func _grid_origin() -> Vector2:
	return Vector2(
		-grid_width * tile_size * 0.5,
		-grid_height * tile_size * 0.5
	)

func get_tile_center_local(gx: int, gy: int) -> Vector2:
	var origin: Vector2 = _grid_origin()
	return origin + Vector2((gx + 0.5) * tile_size, (gy + 0.5) * tile_size)

func grid_to_world(gx: int, gy: int) -> Vector2:
	return to_global(get_tile_center_local(gx, gy))

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = to_local(world_pos) - _grid_origin()
	var gx: int = int(floor(local_pos.x / tile_size))
	var gy: int = int(floor(local_pos.y / tile_size))
	return Vector2i(gx, gy)

func is_grid_in_bounds(gx: int, gy: int) -> bool:
	return gx >= 0 and gx < grid_width and gy >= 0 and gy < grid_height

func is_grid_walkable_for_player(gx: int, gy: int) -> bool:
	if not is_grid_in_bounds(gx, gy):
		return false
	var key = Vector2i(gx, gy)
	if tiles.has(key) and is_instance_valid(tiles[key]):
		return tiles[key].is_walkable()
	return false

func has_living_tile(gx: int, gy: int) -> bool:
	var key = Vector2i(gx, gy)
	return tiles.has(key) and is_instance_valid(tiles[key])

func is_step_allowed_for_player(gx: int, gy: int) -> bool:
	if not is_grid_in_bounds(gx, gy):
		return true
	if is_grid_walkable_for_player(gx, gy):
		return true
	# Collapsed outer tiles leave holes — player can walk into them to reach the void.
	return not has_living_tile(gx, gy)

func stop_decay() -> void:
	decay_enabled = false

func grid_step_toward(from: Vector2i, target: Vector2i) -> Vector2i:
	if from == target:
		return from
	var best: Vector2i = from
	var best_dist: int = (target - from).length_squared()
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var next: Vector2i = from + dir
		var dist: int = (target - next).length_squared()
		if dist < best_dist:
			best_dist = dist
			best = next
	return best

func is_position_walkable(world_pos: Vector2) -> bool:
	var cell: Vector2i = world_to_grid(world_pos)
	if not is_grid_in_bounds(cell.x, cell.y):
		return false
	if is_grid_walkable_for_player(cell.x, cell.y):
		return true
	return has_living_tile(cell.x, cell.y)

func get_spawn_margin_position() -> Vector2:
	var half_w: float = grid_width * tile_size * 0.5
	var half_h: float = grid_height * tile_size * 0.5
	var margin: float = tile_size * 1.5
	var side: int = randi() % 4
	var local: Vector2
	match side:
		0:
			local = Vector2(randf_range(-half_w, half_w), -half_h - margin)
		1:
			local = Vector2(randf_range(-half_w, half_w), half_h + margin)
		2:
			local = Vector2(-half_w - margin, randf_range(-half_h, half_h))
		_:
			local = Vector2(half_w + margin, randf_range(-half_h, half_h))
	return to_global(local)

func _process(delta: float):
	if not decay_enabled:
		return
	decay_timer += delta
	if decay_timer >= decay_interval:
		decay_timer = 0.0
		decay_outer_ring()

func decay_outer_ring():
	if current_ring >= max_ring:
		return

	ring_decaying.emit(current_ring)

	for x in range(current_ring, grid_width - current_ring):
		trigger_tile(x, current_ring)
		trigger_tile(x, grid_height - 1 - current_ring)

	for y in range(current_ring + 1, grid_height - 1 - current_ring):
		trigger_tile(current_ring, y)
		trigger_tile(grid_width - 1 - current_ring, y)

	current_ring += 1

func trigger_tile(x: int, y: int):
	var key = Vector2i(x, y)
	if tiles.has(key) and is_instance_valid(tiles[key]):
		tiles[key].set_warning()
