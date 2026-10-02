extends Area2D

@export var speed: float = 220.0
@export var damage: int = 1
@export var lifetime: float = 3.0

const PROJECTILE_LAYER: int = 4

var direction: Vector2 = Vector2.UP
var age: float = 0.0
var has_hit: bool = false
var from_player: bool = true

func _ready():
	add_to_group("projectile")
	monitoring = true
	monitorable = true
	rotation = direction.angle() + PI / 2.0

func setup(is_from_player: bool) -> void:
	from_player = is_from_player
	set_collision_layer_value(PROJECTILE_LAYER, true)
	monitoring = true
	if from_player:
		set_collision_mask_value(2, true)
		set_collision_mask_value(1, false)
		set_collision_mask_value(PROJECTILE_LAYER, true)
	else:
		set_collision_mask_value(1, true)
		set_collision_mask_value(2, false)
		set_collision_mask_value(PROJECTILE_LAYER, false)
		modulate = Color(0.55, 0.35, 0.85, 1.0)

func _physics_process(delta: float):
	if has_hit:
		return
	position += direction * speed * delta
	age += delta
	if age > lifetime:
		queue_free()

func _on_body_entered(body: Node2D):
	if has_hit:
		return
	if from_player:
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			hit_target(body)
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		hit_target(body)

func _on_area_entered(area: Area2D):
	if has_hit:
		return
	if from_player and area.is_in_group("projectile") and area != self:
		if area.get("from_player") == false:
			clash_with(area)
			return
	if not from_player:
		return
	var parent = area.get_parent()
	if parent and parent.is_in_group("enemy") and parent.has_method("take_damage"):
		hit_target(parent)

func clash_with(other: Area2D) -> void:
	if has_hit:
		return
	has_hit = true
	spawn_hit_spark()
	queue_free()
	if other.has_method("destroy_from_clash"):
		other.destroy_from_clash()

func destroy_from_clash() -> void:
	if has_hit:
		return
	has_hit = true
	queue_free()

func hit_target(target: Node):
	has_hit = true
	target.take_damage(damage)
	spawn_hit_spark()
	queue_free()

func spawn_hit_spark():
	var parent = get_parent()
	if not parent:
		return
	for i in range(4):
		var spark = Sprite2D.new()
		spark.texture = $Sprite2D.texture
		spark.scale = Vector2(0.4, 0.4)
		spark.modulate = Color(1.5, 0.4, 0.4, 1.0) if from_player else Color(0.6, 0.4, 1.2, 1.0)
		spark.global_position = global_position
		spark.z_index = z_index + 1
		parent.add_child(spark)

		var angle = randf() * TAU
		var spd = randf_range(40.0, 90.0)
		var vel = Vector2(cos(angle), sin(angle)) * spd

		var tween = spark.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", spark.position + vel * 0.15, 0.15)
		tween.tween_property(spark, "modulate:a", 0.0, 0.15)
		tween.chain().tween_callback(spark.queue_free)
