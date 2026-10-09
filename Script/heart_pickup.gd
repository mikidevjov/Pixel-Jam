extends Area2D

var collected: bool = false
var time: float = 0.0
var player: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D

const VISUAL_SCALE := 1.0

func _ready() -> void:
	add_to_group("heart_pickup")
	player = get_tree().get_first_node_in_group("player")
	if sprite:
		sprite.scale = Vector2(VISUAL_SCALE, VISUAL_SCALE)
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _process(delta: float) -> void:
	if collected:
		return
	time += delta
	if sprite:
		var pulse := 1.0 + sin(time * 6.0) * 0.12
		sprite.scale = Vector2(VISUAL_SCALE, VISUAL_SCALE) * pulse
		sprite.position.y = sin(time * 4.0) * 2.0

	if is_instance_valid(player) and not player.get("is_dead") and not player.get("is_falling"):
		var dist_sq := global_position.distance_squared_to(player.global_position)
		if dist_sq < 2025.0:
			collect(player)


func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	if body.is_in_group("player"):
		collect(body)


func collect(target_player: Node2D) -> void:
	if collected:
		return
	collected = true
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("collect_heart"):
		main.collect_heart()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target_player.global_position, 0.18)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(queue_free)
