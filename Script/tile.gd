extends Node2D

enum State { ACTIVE, WARNING, FALLING, REMOVED }
var state: State = State.ACTIVE

@export var warning_duration: float = 2.5
@export var fall_duration: float = 1.2

var tile_size: float = 40.0
var timer: float = 0.0
var orig_pos: Vector2

@onready var sprite: Sprite2D = $Sprite2D
@onready var floor_shape: CollisionShape2D = $Area2D/CollisionShape2D

func set_tile_size(size: float) -> void:
	tile_size = size
	if is_node_ready():
		_apply_size()

func capture_origin() -> void:
	orig_pos = position

func _ready():
	_apply_size()
	if sprite:
		sprite.texture = _make_flat_texture(Color(0.38, 0.58, 0.42), Color(0.22, 0.32, 0.26))
		var s: float = tile_size / 32.0
		sprite.scale = Vector2(s, s)
	capture_origin()

func _apply_size() -> void:
	if floor_shape and floor_shape.shape is RectangleShape2D:
		(floor_shape.shape as RectangleShape2D).size = Vector2(tile_size, tile_size)

func _make_flat_texture(fill: Color, border: Color) -> ImageTexture:
	var px: int = 32
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	for x in px:
		img.set_pixel(x, 0, border)
		img.set_pixel(x, px - 1, border)
	for y in px:
		img.set_pixel(0, y, border)
		img.set_pixel(px - 1, y, border)
	var tex := ImageTexture.create_from_image(img)
	return tex

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
			if sprite:
				var base_s: float = tile_size / 32.0
				var shrink: float = 1.0 - t * 0.35
				sprite.scale = Vector2(base_s * shrink, base_s * shrink)
			if timer >= fall_duration:
				state = State.REMOVED
				queue_free()

func set_warning():
	if state == State.ACTIVE:
		state = State.WARNING
		timer = 0.0
		if sprite:
			sprite.texture = _make_flat_texture(Color(0.55, 0.42, 0.28), Color(0.35, 0.22, 0.12))

func start_falling():
	state = State.FALLING
	timer = 0.0
	position = orig_pos

func is_walkable() -> bool:
	return state == State.ACTIVE or state == State.WARNING
