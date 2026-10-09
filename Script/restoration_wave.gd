extends Node2D
# who did't read this code is gay
@export var max_radius: float = 350.0
@export var duration: float = 0.65
@export var ring_color: Color = Color(2.5, 0.3, 0.3, 0.9)

var current_radius: float = 0.0
var current_alpha: float = 1.0

func _ready():
	z_index = 40
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_radius, 5.0, max_radius, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_alpha, 1.0, 0.0, duration)
	tween.chain().tween_callback(queue_free)

func _set_radius(r: float):
	current_radius = r
	queue_redraw()

func _set_alpha(a: float):
	current_alpha = a
	queue_redraw()

func _draw():
	if current_radius <= 0.0 or current_alpha <= 0.0:
		return
	var c = ring_color
	c.a *= current_alpha
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 64, c, 7.0, true)
	var glow_c = ring_color * 0.5
	glow_c.a *= current_alpha * 0.4
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 64, glow_c, 16.0, true)
	draw_arc(Vector2.ZERO, current_radius * 0.55, 0.0, TAU, 32, c * 0.6, 3.0, true)
