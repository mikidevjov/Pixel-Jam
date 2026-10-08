extends Node2D

enum State { ACTIVE, WARNING, FALLING, REMOVED }
var state: State = State.ACTIVE
const LAND_CRUMBLE_SHEET := preload("res://Assets/NewArt-assets/land-crumble-Sheet.webp")

var _land_tile_texture: AtlasTexture
var tile_footprint: Vector2 = PixelSpec.TILE_FOOTPRINT

@export var warning_duration: float = 1.0
@export var fall_duration: float = 1.0

var _vibrate_land_before_fall: bool = true
var timer: float = 0.0
var orig_pos: Vector2

@onready var sprite: Sprite2D = $Sprite2D
@onready var floor_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var animated_crack: AnimatedSprite2D = get_node_or_null("ExampleAnimatedCrack")

func _get_animated_crack() -> AnimatedSprite2D:
	if not animated_crack:
		animated_crack = get_node_or_null("ExampleAnimatedCrack")
	return animated_crack

func set_tile_footprint(footprint: Vector2) -> void:
	tile_footprint = footprint
	if is_node_ready():
		_apply_footprint()


func set_tile_size(size: float) -> void:
	set_tile_footprint(Vector2(size, size * 0.5))


func capture_origin() -> void:
	orig_pos = position


func configure_decay(warning_sec: float, fall_sec: float, vibrate_land_before_fall: bool = false) -> void:
	warning_duration = warning_sec
	fall_duration = fall_sec
	_vibrate_land_before_fall = vibrate_land_before_fall

func _land_texture() -> AtlasTexture:
	if not _land_tile_texture:
		_land_tile_texture = AtlasTexture.new()
		_land_tile_texture.atlas = LAND_CRUMBLE_SHEET
		_land_tile_texture.region = PixelSpec.crumble_cell_region(0)
	return _land_tile_texture


func _crumble_scale() -> Vector2:
	return PixelSpec.crumble_content_to_footprint_scale(tile_footprint)


func _ready():
	_apply_footprint()
	if sprite:
		sprite.show()
		sprite.texture = _land_texture()
		sprite.scale = _crumble_scale()
	if animated_crack:
		animated_crack.hide()
		animated_crack.stop()
		animated_crack.scale = _crumble_scale()
	capture_origin()


func _apply_footprint() -> void:
	if floor_shape and floor_shape.shape is RectangleShape2D:
		(floor_shape.shape as RectangleShape2D).size = tile_footprint
	if sprite:
		sprite.scale = _crumble_scale()
	var anim = _get_animated_crack()
	if anim:
		anim.scale = _crumble_scale()

func _process(delta: float):
	match state:
		State.WARNING:
			timer += delta
			position = orig_pos + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			if timer >= warning_duration:
				start_falling()
		State.FALLING:
			timer += delta
			position = orig_pos
			var t: float = clampf(timer / fall_duration, 0.0, 1.0)
			modulate.a = 1.0 - t
			var shrink: float = 1.0 - t * 0.35
			if sprite:
				sprite.scale = _crumble_scale() * shrink
			var anim = _get_animated_crack()
			if anim:
				anim.scale = _crumble_scale() * shrink
			if timer >= fall_duration:
				state = State.REMOVED
				queue_free()

func set_warning():
	if state == State.ACTIVE:
		state = State.WARNING
		timer = 0.0
		var anim = _get_animated_crack()
		if _vibrate_land_before_fall:
			if sprite:
				sprite.show()
			if anim:
				anim.hide()
				anim.stop()
		else:
			if sprite:
				sprite.hide()
			if anim:
				anim.show()
				anim.frame = 0
				anim.play("default")

func start_falling():
	state = State.FALLING
	timer = 0.0
	position = orig_pos
	if _vibrate_land_before_fall:
		if sprite:
			sprite.hide()
		var anim = _get_animated_crack()
		if anim:
			anim.show()
			anim.frame = 0
			anim.play("default")

func play_restore_animation():
	state = State.ACTIVE
	timer = 0.0
	var anim = _get_animated_crack()
	if anim:
		anim.stop()
		anim.hide()
	if sprite:
		sprite.show()
		sprite.texture = _land_texture()
		sprite.scale = _crumble_scale()

	modulate = Color(2.5, 0.4, 0.4, 0.0)
	position = orig_pos + Vector2(0, tile_footprint.y)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", orig_pos, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, 0.35)


func is_walkable() -> bool:
	return state == State.ACTIVE or state == State.WARNING
