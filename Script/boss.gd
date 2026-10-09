class_name BigBoss
extends CharacterBody2D

enum State { IDLE, TELEGRAPH, ATTACK, SUMMON, DEAD }

@export var boss_max_health: int = 70
@export var attack_interval: float = 2.4

var health: int = 70
var state: State = State.IDLE
var state_timer: float = 0.0
var hover_time: float = 0.0
var attack_counter: int = 0
var base_pos: Vector2 = Vector2.ZERO

var player: Node2D = null
var boss_projectile_scene = preload("res://Scene/boss_projectile.tscn")
var minion_scene = preload("res://Scene/minion.tscn")
var big_dust_scene = preload("res://Scene/big_core_dust.tscn")

signal boss_health_changed(current: int, maximum: int)
signal boss_died

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Sprite2D = $Shadow
@onready var aura: Sprite2D = $Aura
@onready var telegraph_glow: Sprite2D = $TelegraphGlow

func _ready():
	add_to_group("enemy")
	add_to_group("boss")
	health = boss_max_health
	base_pos = position
	player = get_tree().get_first_node_in_group("player")
	if telegraph_glow:
		telegraph_glow.hide()
	SoulFootAnchor.apply(self, sprite, shadow, PixelSpec.BOSS_SIZE)
	z_index = 120
	boss_health_changed.emit(health, boss_max_health)

func _process(delta: float):
	if state == State.DEAD:
		return

	hover_time += delta
	# Floating bob
	if state != State.TELEGRAPH:
		position.y = base_pos.y + sin(hover_time * 2.2) * 6.0
		position.x = base_pos.x

	state_timer += delta

	match state:
		State.IDLE:
			if state_timer >= attack_interval:
				state_timer = 0.0
				_start_telegraph()
		State.TELEGRAPH:
			# Shake during telegraph
			position = base_pos + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
			if state_timer >= 0.7:
				state_timer = 0.0
				_execute_attack()

func _start_telegraph():
	state = State.TELEGRAPH
	AudioManager.play_sfx("movement_boss_darksoul")
	if telegraph_glow:
		telegraph_glow.show()
		telegraph_glow.scale = Vector2.ZERO
		var tw = telegraph_glow.create_tween()
		tw.tween_property(telegraph_glow, "scale", Vector2(1.5, 1.5), 0.65)

func _execute_attack():
	if telegraph_glow:
		telegraph_glow.hide()

	attack_counter += 1
	# Every 3rd attack is Summon, others are Projectile Attack - aye aye , hi hiiii
	if attack_counter % 3 == 0:
		_perform_summon()
	else:
		_perform_projectile_attack()

	state = State.IDLE

func _perform_projectile_attack():
	if not is_instance_valid(player):
		return
	var to_player: Vector2 = (player.global_position - global_position).normalized()

	var proj = boss_projectile_scene.instantiate()
	proj.direction = to_player
	proj.global_position = global_position + Vector2(0, 35) + to_player * 10.0
	get_parent().add_child(proj)

	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("add_trauma"):
		main.add_trauma(0.25)

func _perform_summon():
	# Summon 1-2 minions near arena edges
	var main = get_tree().get_first_node_in_group("main")
	var arena = get_tree().get_first_node_in_group("arena")
	var count = 2 if randf() > 0.5 else 1
	for i in range(count):
		var minion = minion_scene.instantiate()
		var spawn_pos = Vector2(randf_range(-60, 60), randf_range(-30, 30))
		if arena and arena.has_method("get_spawn_margin_position"):
			spawn_pos = arena.get_spawn_margin_position()
		minion.global_position = spawn_pos
		get_parent().add_child(minion)

	if main and main.has_method("add_trauma"):
		main.add_trauma(0.2)

func take_damage(amount: int):
	if state == State.DEAD:
		return

	health = max(0, health - amount)
	boss_health_changed.emit(health, boss_max_health)

	# Impact flash
	if sprite:
		var prev = sprite.modulate
		sprite.modulate = Color(2.5, 0.4, 0.4, 1.0)
		create_tween().tween_property(sprite, "modulate", prev, 0.08)

	if health <= 0:
		die()

func die():
	if state == State.DEAD:
		return
	state = State.DEAD
	boss_died.emit()

	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("add_trauma"):
		main.add_trauma(0.7)

	# Death explosion sequence
	if telegraph_glow:
		telegraph_glow.hide()

	# Spawn explosion particles
	_spawn_death_fireworks()

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", sprite.scale * 1.5, 1.0)
	tween.tween_property(sprite, "modulate", Color(3.0, 0.5, 0.5, 0.0), 1.0)
	if shadow:
		tween.tween_property(shadow, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(func():
		# Drop Big Core Dust right at center of platform
		var big_dust = big_dust_scene.instantiate()
		big_dust.global_position = Vector2(0, 0)
		get_parent().add_child(big_dust)
		queue_free()
	)

func _spawn_death_fireworks():
	var parent = get_parent()
	if not parent:
		return
	for i in range(16):
		var p = Sprite2D.new()
		if sprite:
			p.texture = sprite.texture
		p.scale = Vector2(0.3, 0.3)
		p.modulate = Color(1.8, 0.2, 0.4, 0.9)
		p.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		p.z_index = z_index + 2
		parent.add_child(p)

		var angle = randf() * TAU
		var spd = randf_range(80.0, 200.0)
		var vel = Vector2(cos(angle), sin(angle)) * spd

		var tw = p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", p.position + vel * 0.4, 0.4)
		tw.tween_property(p, "scale", Vector2.ZERO, 0.4)
		tw.tween_property(p, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(p.queue_free)
