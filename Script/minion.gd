class_name Minion
extends CharacterBody2D

enum SoulSize { SMALL, MEDIUM, LARGE }

static func scale_for_size(size: SoulSize) -> float:
	var base: float = SoulFootAnchor.PLAYER_SOUL_SCALE
	match size:
		SoulSize.SMALL:
			return base * 0.5
		SoulSize.MEDIUM:
			return base * (2.0 / 3.0)
		SoulSize.LARGE:
			return base * 0.9
		_:
			return base * (2.0 / 3.0)

@export var soul_size: SoulSize = SoulSize.MEDIUM
@export var step_interval: float = 0.36
@export var fire_rate: float = 3.5
@export var health: int = 1
@export var damage: int = 1

var player: Node2D = null
var is_dead: bool = false
var arena: Node2D = null
var last_shot_time: float = 0.0

var grid_pos: Vector2i = Vector2i.ZERO
var step_timer: float = 0.0
var is_stepping: bool = false
var foot_lift: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Sprite2D = $Shadow

var projectile_scene = preload("res://Scene/projectile.tscn")

func _ready():
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")
	arena = get_tree().get_first_node_in_group("arena")
	if sprite:
		sprite.rotation = 0.0
		var scale_factor: float = scale_for_size(soul_size)
		sprite.scale = Vector2(scale_factor, scale_factor)
	foot_lift = SoulFootAnchor.apply(self, sprite, shadow)
	if has_node("Hitbox"):
		var hitbox: Area2D = $Hitbox
		hitbox.collision_mask = 1
		hitbox.monitoring = true
	call_deferred("_snap_to_grid")

func _snap_to_grid():
	if not arena:
		arena = get_tree().get_first_node_in_group("arena")
	if not arena:
		return
	grid_pos = arena.world_to_grid(global_position)
	global_position = arena.grid_to_world(grid_pos.x, grid_pos.y)

func _physics_process(delta: float):
	if is_dead:
		return

	velocity = Vector2.ZERO

	if is_instance_valid(player) and not player.get("is_dead") and not player.get("is_falling"):
		_try_auto_shoot(delta)
		_try_grid_step(delta)
		_check_shared_tile_with_player()
	else:
		move_and_slide()

func _try_auto_shoot(delta: float) -> void:
	last_shot_time += delta
	if last_shot_time < fire_rate:
		return
	if not is_instance_valid(player):
		return
	var to_player: Vector2 = player.global_position - global_position
	if to_player.length_squared() <= 4.0:
		return
	shoot(to_player.normalized())

func shoot(dir: Vector2) -> void:
	last_shot_time = 0.0
	var proj = projectile_scene.instantiate()
	proj.direction = dir
	get_parent().add_child(proj)
	proj.global_position = global_position + SoulFootAnchor.chest_offset(sprite, foot_lift) + dir * 14.0
	if proj.has_method("setup"):
		proj.setup(false)

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

	var target_grid: Vector2i = arena.world_to_grid(player.global_position)
	var next: Vector2i = arena.grid_step_toward(grid_pos, target_grid)
	if next == grid_pos:
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
		_on_landed_after_step()
	)

func _on_landed_after_step() -> void:
	if is_dead or not is_instance_valid(player) or not arena:
		return
	var player_cell: Vector2i = arena.world_to_grid(player.global_position)
	if grid_pos == player_cell:
		_touch_player()

func spawn_trail():
	var parent = get_parent()
	if not parent or not sprite:
		return
	var ghost = Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.global_position = sprite.global_position
	ghost.rotation = 0.0
	ghost.modulate = Color(0.2, 0.1, 0.4, 0.4)
	ghost.z_index = z_index - 1
	parent.add_child(ghost)

	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tween.tween_callback(ghost.queue_free)

func _check_shared_tile_with_player() -> void:
	if is_dead or is_stepping or not is_instance_valid(player):
		return
	if not arena:
		return
	var player_cell: Vector2i = arena.world_to_grid(player.global_position)
	if grid_pos == player_cell:
		_touch_player()

func _touch_player() -> void:
	if is_dead or not is_instance_valid(player):
		return
	if player.has_method("take_damage"):
		player.take_damage(damage)
	die(false)

func _on_hitbox_body_entered(body: Node2D):
	if is_dead:
		return
	if body.is_in_group("player"):
		_touch_player()

func take_damage(amount: int):
	if is_dead:
		return
	health -= amount
	if health <= 0:
		die(true)

func die(killed_by_player: bool = true):
	if is_dead:
		return
	is_dead = true

	if killed_by_player:
		var main = get_tree().get_first_node_in_group("main")
		if main and main.has_method("enemy_killed"):
			main.enemy_killed()
	else:
		var main = get_tree().get_first_node_in_group("main")
		if main and main.has_method("on_enemy_lost_without_kill"):
			main.on_enemy_lost_without_kill()

	if has_node("Hitbox/CollisionShape2D"):
		$Hitbox/CollisionShape2D.set_deferred("disabled", true)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)

	spawn_death_particles()

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)

func spawn_death_particles():
	var parent = get_parent()
	if not parent or not sprite:
		return
	for i in range(6):
		var p = Sprite2D.new()
		p.texture = sprite.texture
		p.scale = Vector2(0.3, 0.3)
		p.modulate = Color(0.5, 0.2, 0.7, 0.9)
		p.global_position = global_position
		p.z_index = z_index + 1
		parent.add_child(p)

		var angle = randf() * TAU
		var spd = randf_range(50.0, 120.0)
		var vel = Vector2(cos(angle), sin(angle)) * spd

		var tween = p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position", p.position + vel * 0.2, 0.2)
		tween.tween_property(p, "scale", Vector2.ZERO, 0.2)
		tween.tween_property(p, "modulate:a", 0.0, 0.2)
		tween.chain().tween_callback(p.queue_free)
