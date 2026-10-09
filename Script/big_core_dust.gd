extends Area2D

var collected: bool = false
var time: float = 0.0
var player: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	add_to_group("big_core_dust")
	player = get_tree().get_first_node_in_group("player")

	position.y -= 24.0
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 24.0, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)

func _process(delta: float):
	if collected:
		return
	time += delta
	if sprite:
		var pulse := 1.0 + sin(time * 5.0) * 0.12
		sprite.scale = Vector2(pulse, pulse)
		sprite.rotation += delta * 1.5
		sprite.position.y = sin(time * 4.0) * 4.0
		var glow := 0.2 + sin(time * 8.0) * 0.15
		sprite.modulate = Color(2.5 + glow, 0.5 + glow * 0.2, 0.3, 1.0)

	# Attract if player gets close (within 55px)
	if is_instance_valid(player) and not player.get("is_dead") and not player.get("is_falling"):
		var dist_sq = global_position.distance_squared_to(player.global_position)
		if dist_sq < 3025.0:
			collect(player)

func _on_body_entered(body: Node2D):
	if collected:
		return
	if body.is_in_group("player"):
		collect(body)

func collect(target_player: Node2D):
	if collected:
		return
	collected = true

	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("on_boss_dust_collected"):
		main.on_boss_dust_collected()

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target_player.global_position, 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)
