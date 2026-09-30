class_name EnemySprites
extends RefCounted

# Optional generated sprite strips. Each file is one row of square frames,
# facing right: idle 0-3, wind-up, strike, hurt, down. Enemies without a strip
# keep the procedural drawing, so art can arrive one enemy at a time.
const DIRECTORY := "res://art/enemies/"
const IDLE_FRAMES := 4
const FRAME_WIND_UP := 4
const FRAME_STRIKE := 5
const FRAME_HURT := 6
const FRAME_DOWN := 7
# A frame is drawn at 0.8 of its pixel size in world space, the same ratio as
# the hero's 64px frames, so both read at one pixel density on screen.
const WORLD_SCALE := 0.8
const BOSS_IDS := {
	"石門の守護者": "boss_stone_gate",
	"疾風の番人": "boss_gale_warden",
	"魔砲の監視者": "boss_cannon_watcher",
	"召喚の司祭": "boss_summoning_priest",
	"遺跡王": "boss_ruin_king",
	"根の番人": "boss_root_warden",
	"疾風の狼王": "boss_gale_wolf_king",
	"胞子の砲台": "boss_spore_cannon",
	"群れの主": "boss_swarm_lord",
	"古樹の王": "boss_ancient_tree_king",
}

# Sprites whose colours sit close to their stage's floor (the green Ancient
# Tree King on the moss floor) get a footprint-sized, darker ground shadow and
# a faint dark halo, so they stand clear of the floor.
const STANDOUT: Array[String] = ["boss_ancient_tree_king"]
const STANDOUT_SHADOW_ALPHA := 0.78
const STANDOUT_HALO := Color(0.0, 0.0, 0.0, 0.42)

static var _cache: Dictionary = {}
static var _foot_widths: Dictionary = {}
static var _body_heights: Dictionary = {}


static func visual_id(stats: EnemyStats) -> String:
	if stats.is_boss:
		var named: String = BOSS_IDS.get(stats.display_name, "")
		return named if not named.is_empty() and sheet(named) != null else "boss"
	if stats.behavior == EnemyStats.Behavior.SUMMONER:
		return "summoner"
	if stats.behavior == EnemyStats.Behavior.FAST:
		return "fast"
	if stats.behavior == EnemyStats.Behavior.CHARGER:
		return "charge"
	if stats.detection == EnemyStats.Detection.TURRET:
		return "turret"
	if stats.detection == EnemyStats.Detection.PROXIMITY:
		return "proximity"
	return "basic"


static func sheet(id: String) -> Texture2D:
	if not _cache.has(id):
		var path := DIRECTORY + id + ".png"
		_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return _cache[id]


static func sheet_for(stats: EnemyStats) -> Texture2D:
	return null if stats == null else sheet(visual_id(stats))


# Tests and previews inject strips without writing files; null restores lookup.
static func set_override(id: String, texture: Texture2D) -> void:
	if texture == null:
		_cache.erase(id)
	else:
		_cache[id] = texture


static func frame_count(texture: Texture2D) -> int:
	return maxi(1, texture.get_width() / maxi(1, texture.get_height()))


static func stands_out(stats: EnemyStats) -> bool:
	return stats != null and visual_id(stats) in STANDOUT and sheet_for(stats) != null


# Width in pixels of the first idle frame's lowest sixth, where it meets the floor.
static func foot_width(texture: Texture2D) -> int:
	if not _foot_widths.has(texture):
		var size := texture.get_height()
		var band := maxi(1, size / 6)
		var used := texture.get_image().get_region(Rect2i(0, size - band, size, band)).get_used_rect()
		_foot_widths[texture] = used.size.x if used.has_area() else size / 2
	return _foot_widths[texture]


# Pixels from the frame's bottom edge to the top of the first idle frame's body,
# so markers such as the health bar sit just above the head.
static func body_height(texture: Texture2D) -> int:
	if not _body_heights.has(texture):
		var size := texture.get_height()
		var used := texture.get_image().get_region(Rect2i(0, 0, size, size)).get_used_rect()
		_body_heights[texture] = size - used.position.y if used.has_area() else size
	return _body_heights[texture]
