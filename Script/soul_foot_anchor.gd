extends RefCounted
class_name SoulFootAnchor

const CHARACTER_Z_BASE := 50

## Body origin = feet on tile center; sprite rises above the tile (1× logical sprite scale).
static func apply(
	body: CharacterBody2D,
	sprite: Sprite2D,
	shadow: Sprite2D = null,
	logical_size: Vector2i = PixelSpec.RED_SOUL_SIZE
) -> float:
	if not sprite or not sprite.texture:
		return 0.0

	var foot_lift: float = float(logical_size.y) * 0.5
	sprite.position = Vector2(0.0, -foot_lift)
	sprite.scale = Vector2.ONE

	body.y_sort_enabled = true

	if shadow:
		shadow.visible = true
		shadow.position = Vector2(0.0, 0.0)
		shadow.z_index = -1
		shadow.modulate = Color(1.0, 1.0, 1.0, 0.5)
		shadow.scale = Vector2.ONE

	var center_y: float = -foot_lift
	var hit_radius: float = max(float(logical_size.x), float(logical_size.y)) * 0.5 - 1.0
	_set_circle_shape(body.get_node_or_null("CollisionShape2D"), hit_radius, center_y)
	_set_circle_shape(body.get_node_or_null("Hitbox/CollisionShape2D"), hit_radius + 1.0, center_y)

	return foot_lift


static func _set_circle_shape(node: Node, radius: float, center_y: float) -> void:
	if not node or not node is CollisionShape2D:
		return
	var shape: Shape2D = (node as CollisionShape2D).shape
	if shape is CircleShape2D:
		(shape as CircleShape2D).radius = radius
	(node as CollisionShape2D).position = Vector2(0.0, center_y)


static func sync_render_depth(body: Node2D, grid_row: int) -> void:
	body.z_index = CHARACTER_Z_BASE + grid_row


static func sync_render_depth_from_world_y(body: Node2D, world_y: float) -> void:
	body.z_index = CHARACTER_Z_BASE + int(round(world_y))


static func chest_offset(sprite: Sprite2D, foot_lift: float) -> Vector2:
	if foot_lift <= 0.0:
		return Vector2.ZERO
	return Vector2(0.0, -foot_lift * 0.55)
