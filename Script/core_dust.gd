extends Area2D

@export var dust_value: float = 35.0

var collected: bool = false
var time: float = 0.0
var base_y: float = 0.0
var player: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	add_to_group("core_dust")
	base_y = position.y
	player = get_tree().get_first_node_in_group("player")

	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func _process(delta: float):
	if collected:
		return
	time += delta
	if sprite:
		sprite.position.y = sin(time * 5.0) * 3.0

	# Magnetic attraction if player gets close (within 45px)
	if is_instance_valid(player) and not player.get("is_dead") and not player.get("is_falling"):
		var dist_sq = global_position.distance_squared_to(player.global_position)
		if dist_sq < 2025.0: # 45^2
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
	if main and main.has_method("collect_dust"):
		main.collect_dust(dust_value)

	# Fly to player and dissolve
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target_player.global_position, 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)
