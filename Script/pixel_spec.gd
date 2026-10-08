extends Node
## Authoritative logical pixel sizes for RED IN THE VOID (384×216 internal resolution).

const VIEWPORT_SIZE := Vector2i(384, 216)
const DISPLAY_SCALE_1080P := 5
## Shifts arena + player down so the boss hover slot stays in frame.
const GAMEPLAY_VERTICAL_OFFSET := 24

const TILE_FOOTPRINT := Vector2(32, 16)
const CRUMBLE_CELL_SIZE := 80
## Opaque land art inset inside each 80×80 sheet cell (8 px margin on all sides).
const CRUMBLE_CONTENT_INSET := Vector2i(8, 8)
const CRUMBLE_CONTENT_SIZE := Vector2i(64, 64)

const RED_SOUL_SIZE := Vector2i(16, 16)
const MINION_SIZE := Vector2i(16, 16)
const MEDIUM_SIZE := Vector2i(24, 24)
const BOSS_SIZE := Vector2i(64, 64)

const SHADOW_SMALL := Vector2i(16, 4)
const SHADOW_MEDIUM := Vector2i(24, 6)
const SHADOW_BOSS := Vector2i(64, 8)

const BULLET_SIZE := Vector2i(4, 4)
const BOSS_PROJECTILE_SIZE := Vector2i(16, 16)
const LASER_TEXTURE_SIZE := Vector2i(128, 8)
const LASER_GAMEPLAY_WIDTH := 8

const CORE_DUST_SMALL := Vector2i(4, 4)
const CORE_DUST_BIG := Vector2i(16, 16)

const HUD_HEART_SIZE := Vector2i(16, 16)
const HUD_HEART_SPACING := 4
const HUD_MARGIN := 16
const HUD_DUST_GAUGE_SIZE := Vector2i(128, 8)
const HUD_BOSS_BAR_SIZE := Vector2i(320, 8)
const HUD_SCORE_AREA := Vector2i(80, 16)

const VOID_TEXTURE_SIZE := Vector2i(768, 432)
const VOID_LOGICAL_SCALE := Vector2(0.5, 0.5)

const TITLE_TEXTURE_SIZE := Vector2i(208, 96)


static func crumble_content_to_footprint_scale(footprint: Vector2 = TILE_FOOTPRINT) -> Vector2:
	return Vector2(
		footprint.x / float(CRUMBLE_CONTENT_SIZE.x),
		footprint.y / float(CRUMBLE_CONTENT_SIZE.y)
	)


static func crumble_cell_region(frame_index: int) -> Rect2:
	var fx: float = float(frame_index * CRUMBLE_CELL_SIZE + CRUMBLE_CONTENT_INSET.x)
	var fy: float = float(CRUMBLE_CONTENT_INSET.y)
	return Rect2(
		fx,
		fy,
		float(CRUMBLE_CONTENT_SIZE.x),
		float(CRUMBLE_CONTENT_SIZE.y)
	)
