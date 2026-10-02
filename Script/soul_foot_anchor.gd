extends RefCounted
class_name SoulFootAnchor

const PLAYER_SOUL_SCALE: float = 1.62

## Body origin = feet on tile center; sprite rises above the tile.
static func apply(body: CharacterBody2D, sprite: Sprite2D, shadow: Sprite2D = null) -> float:
	if not sprite or not sprite.texture:
		return 0.0

	var scaled_h: float = sprite.texture.get_height() * abs(sprite.scale.y)
	var foot_lift: float = scaled_h * 0.5
	sprite.position = Vector2(0.0, -foot_lift)

	body.y_sort_enabled = true

	if shadow:
		shadow.visible = true
		shadow.position = Vector2(0.0, 0.0)
		shadow.z_index = -1
		shadow.modulate = Color(1.0, 1.0, 1.0, 0.5)

	var torso_y: float = -foot_lift * 0.45
	if body.has_node("CollisionShape2D"):
		body.get_node("CollisionShape2D").position = Vector2(0.0, torso_y)
	if body.has_node("Hitbox/CollisionShape2D"):
		body.get_node("Hitbox/CollisionShape2D").position = Vector2(0.0, torso_y)

	return foot_lift

static func chest_offset(sprite: Sprite2D, foot_lift: float) -> Vector2:
	if foot_lift <= 0.0:
		return Vector2.ZERO
	return Vector2(0.0, -foot_lift * 0.55)
