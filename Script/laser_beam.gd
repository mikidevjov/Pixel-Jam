extends Node2D

@export var max_length: float = 384.0
@export var damage_per_second: float = 8.0

var is_beam_active: bool = false
var damage_accumulator: float = 0.0

@onready var beam_sprite: Sprite2D = $BeamSprite
@onready var hit_area: Area2D = $HitArea
@onready var collision_shape: CollisionShape2D = $HitArea/CollisionShape2D

func _ready():
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_beam_active(false, Vector2.RIGHT, global_position)
	_update_beam_geometry(max_length)

func _update_beam_geometry(length: float) -> void:
	if beam_sprite:
		var tex_len: float = _beam_texture_length()
		beam_sprite.rotation = 0.0
		beam_sprite.scale = Vector2(length / tex_len, 1.0)
		beam_sprite.position = Vector2.ZERO
		var beam_h: float = _beam_texture_height()
		beam_sprite.offset = Vector2(0.0, -beam_h * 0.5)
	if collision_shape and collision_shape.shape is RectangleShape2D:
		(collision_shape.shape as RectangleShape2D).size = Vector2(length, float(PixelSpec.LASER_GAMEPLAY_WIDTH))
		collision_shape.position = Vector2(length * 0.5, 0.0)


func _beam_texture_length() -> float:
	if beam_sprite and beam_sprite.texture is AtlasTexture:
		return (beam_sprite.texture as AtlasTexture).region.size.x
	return float(PixelSpec.LASER_TEXTURE_SIZE.x)


func _beam_texture_height() -> float:
	if beam_sprite and beam_sprite.texture is AtlasTexture:
		return (beam_sprite.texture as AtlasTexture).region.size.y
	return float(PixelSpec.LASER_TEXTURE_SIZE.y)

func set_beam_active(active: bool, dir: Vector2, start_pos: Vector2) -> void:
	is_beam_active = active
	visible = active
	if not active:
		if hit_area:
			hit_area.monitoring = false
		return

	global_position = start_pos
	rotation = dir.angle()
	_update_beam_geometry(max_length)

	if hit_area:
		hit_area.monitoring = true

func _physics_process(delta: float):
	if not is_beam_active or not hit_area:
		return

	damage_accumulator += damage_per_second * delta
	var deal_damage_now: bool = false
	var dmg_to_deal: int = 1
	if damage_accumulator >= 1.0:
		deal_damage_now = true
		dmg_to_deal = int(damage_accumulator)
		damage_accumulator -= float(dmg_to_deal)

	var bodies = hit_area.get_overlapping_bodies()
	for body in bodies:
		if is_instance_valid(body) and body.is_in_group("enemy"):
			if deal_damage_now and body.has_method("take_damage"):
				body.take_damage(dmg_to_deal)
				_spawn_hit_spark(body.global_position)

	var areas = hit_area.get_overlapping_areas()
	for a in areas:
		if not is_instance_valid(a):
			continue
		if a.is_in_group("projectile"):
			if a.get("from_player") == false:
				_spawn_hit_spark(a.global_position)
				if a.has_method("destroy_from_clash"):
					a.destroy_from_clash()
				else:
					a.queue_free()
		elif a.is_in_group("enemy") or (a.get_parent() and a.get_parent().is_in_group("enemy")):
			var target = a if a.is_in_group("enemy") else a.get_parent()
			if deal_damage_now and target.has_method("take_damage"):
				target.take_damage(dmg_to_deal)
				_spawn_hit_spark(a.global_position)

func _spawn_hit_spark(pos: Vector2):
	var parent = get_parent()
	if not parent:
		return
	for i in range(2):
		var p = Sprite2D.new()
		p.texture = load("res://Assets/Sprites/bullet.png")
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p.modulate = Color(2.5, 0.4, 0.4, 1.0)
		p.global_position = pos + Vector2(randi_range(-2, 2), randi_range(-2, 2))
		p.z_index = 35
		parent.add_child(p)

		var tween = p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position", p.position + Vector2(randi_range(-8, 8), randi_range(-8, 8)), 0.15)
		tween.tween_property(p, "modulate:a", 0.0, 0.15)
		tween.chain().tween_callback(p.queue_free)
