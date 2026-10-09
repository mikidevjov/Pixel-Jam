extends Node2D

@export var grid_width: int = 12
@export var grid_height: int = 12
@export var tile_footprint: Vector2 = PixelSpec.TILE_FOOTPRINT
@export var decay_interval: float = 10.0
@export var min_remaining_tiles: int = 6

var min_cluster_size: Vector2i = Vector2i(4, 4)
var use_edge_tile_decay: bool = false

var tiles: Dictionary = {}
var decay_timer: float = 0.0
var current_ring: int = 0
var max_ring: int = 0
var decay_enabled: bool = true
var tile_warning_duration: float = 1.0
var tile_fall_duration: float = 1.0
var tile_vibrate_land_before_fall: bool = true
var use_level1_finale_shrink: bool = false

signal ring_decaying(ring_index: int)
signal tile_restored(pos: Vector2)

var tile_scene = preload("res://Scene/tile.tscn")
var fallen_tiles: Array[Vector2i] = []

func get_tile_count() -> int:
	return grid_width * grid_height

func _ready():
	add_to_group("arena")
	if tiles.is_empty():
		build_grid()

func setup_arena(
	w: int,
	h: int,
	decay_time: float,
	auto_decay: bool = true,
	level1_finale_shrink: bool = false
) -> void:
	for cell in tiles.keys():
		var t = tiles[cell]
		if is_instance_valid(t):
			t.queue_free()
	tiles.clear()
	fallen_tiles.clear()

	grid_width = w
	grid_height = h
	decay_interval = decay_time
	decay_enabled = auto_decay
	use_level1_finale_shrink = level1_finale_shrink
	use_edge_tile_decay = false
	decay_timer = 0.0
	current_ring = 0
	max_ring = min(grid_width, grid_height) / 2

	build_grid()
	_apply_decay_timings_to_all_tiles()


func configure_tile_decay(
	warning_sec: float,
	fall_sec: float,
	vibrate_land_before_fall: bool = false
) -> void:
	tile_warning_duration = warning_sec
	tile_fall_duration = fall_sec
	tile_vibrate_land_before_fall = vibrate_land_before_fall
	_apply_decay_timings_to_all_tiles()


func accelerate_tile_fall_speed(speed_multiplier: float, min_duration: float = 0.22) -> void:
	if speed_multiplier <= 1.0:
		return
	tile_warning_duration = max(min_duration, tile_warning_duration / speed_multiplier)
	tile_fall_duration = max(min_duration, tile_fall_duration / speed_multiplier)
	_apply_decay_timings_to_all_tiles()


func _apply_decay_timings_to_all_tiles() -> void:
	for t in tiles.values():
		if is_instance_valid(t) and t.has_method("configure_decay"):
			t.configure_decay(tile_warning_duration, tile_fall_duration, tile_vibrate_land_before_fall)


func build_grid() -> void:
	max_ring = min(grid_width, grid_height) / 2
	for gy in range(grid_height):
		for gx in range(grid_width):
			_create_tile_at(gx, gy)

func _create_tile_at(gx: int, gy: int, play_restore_fx: bool = false) -> Node2D:
	var key = Vector2i(gx, gy)
	if tiles.has(key) and is_instance_valid(tiles[key]):
		if not tiles[key].is_queued_for_deletion() and tiles[key].is_walkable():
			return tiles[key]
		tiles[key].queue_free()
	var t = tile_scene.instantiate()
	t.position = get_tile_center_local(gx, gy)
	add_child(t)
	t.z_index = gy
	if t.has_method("set_tile_footprint"):
		t.set_tile_footprint(tile_footprint)
	if t.has_method("capture_origin"):
		t.capture_origin()
	if t.has_method("configure_decay"):
		t.configure_decay(tile_warning_duration, tile_fall_duration, tile_vibrate_land_before_fall)
	tiles[key] = t
	if play_restore_fx and t.has_method("play_restore_animation"):
		t.play_restore_animation()
	return t



func _grid_origin() -> Vector2:
	return Vector2(
		-grid_width * tile_footprint.x * 0.5,
		-grid_height * tile_footprint.y * 0.5
	)

func get_tile_center_local(gx: int, gy: int) -> Vector2:
	var origin: Vector2 = _grid_origin()
	return origin + Vector2((gx + 0.5) * tile_footprint.x, (gy + 0.5) * tile_footprint.y)

func grid_to_world(gx: int, gy: int) -> Vector2:
	return to_global(get_tile_center_local(gx, gy))

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = to_local(world_pos) - _grid_origin()
	var gx: int = int(floor(local_pos.x / tile_footprint.x))
	var gy: int = int(floor(local_pos.y / tile_footprint.y))
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
	if tiles.has(key) and is_instance_valid(tiles[key]):
		if tiles[key].is_queued_for_deletion():
			return false
		if tiles[key].has_method("is_walkable"):
			return tiles[key].is_walkable()
		return true
	return false

func is_step_allowed_for_player(gx: int, gy: int) -> bool:
	if not is_grid_in_bounds(gx, gy):
		return true
	if is_grid_walkable_for_player(gx, gy):
		return true
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

func get_boss_spawn_position() -> Vector2:
	var gx: int = (grid_width - 1) / 2
	var above_north_row: Vector2 = get_tile_center_local(gx, 0) + Vector2(0, -36.0)
	return to_global(above_north_row)


func get_spawn_margin_position() -> Vector2:
	var half_w: float = grid_width * tile_footprint.x * 0.5
	var half_h: float = grid_height * tile_footprint.y * 0.5
	var margin: float = max(tile_footprint.x, tile_footprint.y) * 1.5
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
		if use_edge_tile_decay:
			decay_random_edge_tiles()
		else:
			decay_outer_ring()

func _living_tile_count() -> int:
	var count: int = 0
	for key in tiles.keys():
		var t = tiles[key]
		if is_instance_valid(t) and not t.is_queued_for_deletion():
			if t.has_method("is_walkable") and t.is_walkable():
				count += 1
	return count


func _living_tiles_in_ring(ring: int) -> int:
	var count: int = 0
	for x in range(ring, grid_width - ring):
		if has_living_tile(x, ring):
			count += 1
		if grid_height - 1 - ring != ring and has_living_tile(x, grid_height - 1 - ring):
			count += 1
	for y in range(ring + 1, grid_height - 1 - ring):
		if has_living_tile(ring, y):
			count += 1
		if grid_width - 1 - ring != ring and has_living_tile(grid_width - 1 - ring, y):
			count += 1
	return count


func _living_tile_bounds() -> Dictionary:
	var min_gx: int = grid_width
	var max_gx: int = -1
	var min_gy: int = grid_height
	var max_gy: int = -1
	for gy in range(grid_height):
		for gx in range(grid_width):
			if has_living_tile(gx, gy):
				min_gx = mini(min_gx, gx)
				max_gx = maxi(max_gx, gx)
				min_gy = mini(min_gy, gy)
				max_gy = maxi(max_gy, gy)
	return {
		"min_gx": min_gx,
		"max_gx": max_gx,
		"min_gy": min_gy,
		"max_gy": max_gy,
	}


func get_random_walkable_world_position() -> Vector2:
	var candidates: Array[Vector2i] = []
	for gy in range(grid_height):
		for gx in range(grid_width):
			if is_grid_walkable_for_player(gx, gy):
				candidates.append(Vector2i(gx, gy))
	if candidates.is_empty():
		return Vector2.ZERO
	var pick: Vector2i = candidates[randi() % candidates.size()]
	return grid_to_world(pick.x, pick.y)


func _protected_core_bounds() -> Dictionary:
	var pw: int = min_cluster_size.x
	var ph: int = min_cluster_size.y
	var min_gx: int = (grid_width - pw) / 2
	var min_gy: int = (grid_height - ph) / 2
	return {
		"min_gx": min_gx,
		"min_gy": min_gy,
		"max_gx": min_gx + pw - 1,
		"max_gy": min_gy + ph - 1,
	}


func is_protected_core_tile(gx: int, gy: int) -> bool:
	if not is_grid_in_bounds(gx, gy):
		return false
	var b: Dictionary = _protected_core_bounds()
	return gx >= b.min_gx and gx <= b.max_gx and gy >= b.min_gy and gy <= b.max_gy


func _is_perimeter_living_tile(gx: int, gy: int) -> bool:
	if is_protected_core_tile(gx, gy):
		return false
	if not has_living_tile(gx, gy):
		return false
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = Vector2i(gx, gy) + dir
		if not is_grid_in_bounds(n.x, n.y) or not has_living_tile(n.x, n.y):
			return true
	return false


func _collect_edge_living_tiles() -> Array[Vector2i]:
	var edges: Array[Vector2i] = []
	for gy in range(grid_height):
		for gx in range(grid_width):
			if _is_perimeter_living_tile(gx, gy):
				edges.append(Vector2i(gx, gy))
	return edges


func decay_random_edge_tiles() -> void:
	var cluster: Vector2i = _living_cluster_size()
	if cluster.x <= min_cluster_size.x and cluster.y <= min_cluster_size.y:
		stop_decay()
		return

	var edges: Array[Vector2i] = _collect_edge_living_tiles()
	if edges.is_empty():
		stop_decay()
		return

	edges.shuffle()
	var fall_count: int = mini(randi_range(1, 2), edges.size())
	ring_decaying.emit(current_ring)
	for i in range(fall_count):
		var cell: Vector2i = edges[i]
		trigger_tile(cell.x, cell.y)


func _living_cluster_size() -> Vector2i:
	var bounds: Dictionary = _living_tile_bounds()
	if bounds.max_gy < 0:
		return Vector2i.ZERO
	return Vector2i(
		bounds.max_gx - bounds.min_gx + 1,
		bounds.max_gy - bounds.min_gy + 1
	)


func _decay_last_row_of_cluster() -> void:
	var bounds: Dictionary = _living_tile_bounds()
	if bounds.max_gy < 0:
		return
	ring_decaying.emit(current_ring)
	for gx in range(bounds.min_gx, bounds.max_gx + 1):
		trigger_tile(gx, bounds.max_gy)


func _decay_left_and_right_columns() -> void:
	var bounds: Dictionary = _living_tile_bounds()
	if bounds.max_gy < 0:
		return
	ring_decaying.emit(current_ring)
	for gy in range(bounds.min_gy, bounds.max_gy + 1):
		trigger_tile(bounds.min_gx, gy)
		if bounds.max_gx != bounds.min_gx:
			trigger_tile(bounds.max_gx, gy)


func _decay_full_ring() -> void:
	ring_decaying.emit(current_ring)
	for x in range(current_ring, grid_width - current_ring):
		trigger_tile(x, current_ring)
		trigger_tile(x, grid_height - 1 - current_ring)
	for y in range(current_ring + 1, grid_height - 1 - current_ring):
		trigger_tile(current_ring, y)
		trigger_tile(grid_width - 1 - current_ring, y)
	current_ring += 1


func decay_outer_ring():
	var living: int = _living_tile_count()
	if living <= min_remaining_tiles:
		stop_decay()
		return

	# Level 1 (8×8): ring down to 4×4, then 4×4→4×3 (last row), then 4×3→2×3 (side cols) = 6 tiles
	if use_level1_finale_shrink:
		var cluster: Vector2i = _living_cluster_size()
		if cluster == Vector2i(4, 4):
			_decay_last_row_of_cluster()
			return
		if cluster == Vector2i(4, 3):
			_decay_left_and_right_columns()
			return

	# Legacy 5×5 path: 3×3 (9) → one row → 6 tiles (levels 1–2 use 8×8 finale instead)
	if not use_level1_finale_shrink and living == 9:
		_decay_last_row_of_cluster()
		return

	if current_ring >= max_ring:
		stop_decay()
		return

	var ring_living: int = _living_tiles_in_ring(current_ring)
	if living - ring_living < min_remaining_tiles:
		if not use_level1_finale_shrink and living > min_remaining_tiles:
			_decay_last_row_of_cluster()
		else:
			stop_decay()
		return

	_decay_full_ring()

func trigger_tile(x: int, y: int):
	if is_protected_core_tile(x, y):
		return
	var key = Vector2i(x, y)
	if tiles.has(key) and is_instance_valid(tiles[key]):
		tiles[key].set_warning()
		if not fallen_tiles.has(key):
			fallen_tiles.append(key)

func restore_fallen_tiles(count: int = 2) -> Array[Vector2i]:
	var restored: Array[Vector2i] = []
	var candidates: Array[Vector2i] = []
	for cell in fallen_tiles:
		if not has_living_tile(cell.x, cell.y) and is_grid_in_bounds(cell.x, cell.y):
			candidates.append(cell)

	if candidates.is_empty():
		for gy in range(grid_height):
			for gx in range(grid_width):
				var cell = Vector2i(gx, gy)
				if not has_living_tile(gx, gy):
					candidates.append(cell)

	candidates.reverse()
	for cell in candidates:
		if restored.size() >= count:
			break
		_create_tile_at(cell.x, cell.y, true)
		restored.append(cell)
		fallen_tiles.erase(cell)
		tile_restored.emit(grid_to_world(cell.x, cell.y))
	return restored

func restore_full_land(target_w: int = 10, target_h: int = 10) -> void:
	stop_decay()
	grid_width = target_w
	grid_height = target_h
	var center := Vector2(grid_width * 0.5, grid_height * 0.5)
	for gy in range(grid_height):
		for gx in range(grid_width):
			var dist: float = Vector2(gx + 0.5, gy + 0.5).distance_to(center)
			var delay: float = dist * 0.08
			get_tree().create_timer(delay).timeout.connect(func():
				if is_instance_valid(self):
					_create_tile_at(gx, gy, true)
					tile_restored.emit(grid_to_world(gx, gy))
			)
