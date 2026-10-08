extends Area2D

@export var speed: float = 68.0
@export var damage: int = 1
@export var lifetime: float = 5.0

var direction: Vector2 = Vector2.DOWN
var age: float = 0.0
var has_hit: bool = false
var from_player: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	add_to_group("projectile")
	monitoring = true
	monitorable = true
	rotation = direction.angle() + PI / 2.0
	set_collision_layer_value(4, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, false)

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
	if body.is_in_group("player") and body.has_method("take_damage"):
		hit_target(body)

func _on_area_entered(area: Area2D):
	if has_hit:
		return
	if area.is_in_group("projectile") and area != self:
		if area.get("from_player") == true:
			clash_with(area)

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
	spawn_hit_spark()
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
	for i in range(6):
		var spark = Sprite2D.new()
		if sprite:
			spark.texture = sprite.texture
		spark.scale = Vector2(0.6, 0.6)
		spark.modulate = Color(0.7, 0.1, 0.9, 1.0)
		spark.global_position = global_position
		spark.z_index = z_index + 1
		parent.add_child(spark)

		var angle = randf() * TAU
		var spd = randf_range(50.0, 110.0)
		var vel = Vector2(cos(angle), sin(angle)) * spd

		var tween = spark.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", spark.position + vel * 0.18, 0.18)
		tween.tween_property(spark, "scale", Vector2.ZERO, 0.18)
		tween.tween_property(spark, "modulate:a", 0.0, 0.18)
		tween.chain().tween_callback(spark.queue_free)
