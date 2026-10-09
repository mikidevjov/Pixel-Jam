class_name MediumEnemy
extends CharacterBody2D
# who did't read this code is gay
@export var step_interval: float = 0.58
@export var fire_rate: float = 2.8
@export var health: int = 7
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
	foot_lift = SoulFootAnchor.apply(self, sprite, shadow, PixelSpec.MEDIUM_SIZE)
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
	SoulFootAnchor.sync_render_depth(self, grid_pos.y)

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
	if to_player.length_squared() <= 9.0:
		return
	shoot_cluster(to_player.normalized())

func shoot_cluster(dir: Vector2) -> void:
	last_shot_time = 0.0
	var spawn_pos: Vector2 = global_position + SoulFootAnchor.chest_offset(sprite, foot_lift)
	var angles = [-0.22, 0.0, 0.22] # ~12 degree spread
	for angle in angles:
		var proj = projectile_scene.instantiate()
		proj.direction = dir.rotated(angle)
		proj.global_position = spawn_pos + proj.direction * 14.0
		get_parent().add_child(proj)
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
	AudioManager.play_sfx("movement_darksouls")
	var target: Vector2 = arena.grid_to_world(next.x, next.y)
	var tween = create_tween()
	tween.tween_property(self, "global_position", target, step_interval * 0.90)
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
	ghost.modulate = Color(0.3, 0.1, 0.45, 0.35)
	ghost.scale = sprite.scale
	ghost.z_index = z_index - 1
	parent.add_child(ghost)

	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.28)
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
	# Flash red/white on hit
	if sprite:
		var prev_mod = sprite.modulate
		sprite.modulate = Color(2.0, 0.3, 0.3, 1.0)
		create_tween().tween_property(sprite, "modulate", prev_mod, 0.08)

	if health <= 0:
		die(true)

func die(killed_by_player: bool = true):
	if is_dead:
		return
	is_dead = true

	if killed_by_player:
		var main = get_tree().get_first_node_in_group("main")
		if main and main.has_method("medium_enemy_killed"):
			main.medium_enemy_killed(global_position)
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
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)

func spawn_death_particles():
	var parent = get_parent()
	if not parent or not sprite:
		return
	for i in range(8):
		var p = Sprite2D.new()
		p.texture = sprite.texture
		p.scale = Vector2(0.2, 0.2)
		p.modulate = Color(0.6, 0.15, 0.7, 0.9)
		p.global_position = global_position
		p.z_index = z_index + 1
		parent.add_child(p)

		var angle = randf() * TAU
		var spd = randf_range(60.0, 140.0)
		var vel = Vector2(cos(angle), sin(angle)) * spd

		var tween = p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position", p.position + vel * 0.22, 0.22)
		tween.tween_property(p, "scale", Vector2.ZERO, 0.22)
		tween.tween_property(p, "modulate:a", 0.0, 0.22)
		tween.chain().tween_callback(p.queue_free)
