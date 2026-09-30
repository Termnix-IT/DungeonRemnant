class_name EmblemIcons
extends RefCounted

# Optional generated medallions for level-up abilities and permanent upgrades:
# art/emblems/<key>.png, a 48px pixel-art emblem stored at 2x like the item
# icons. Keys come from the ability Effect and the upgrade effect, so ability
# and upgrade data stay untouched. Without a file, ItemGlyph's drawn symbol
# stays, so art can arrive one emblem at a time.
const DIRECTORY := "res://art/emblems/"
# Permanent upgrades that share an ability's meaning share its emblem; the
# 生命力 branch and 魔力量 have their own.
const UPGRADE_KEYS := {&"hp": "max_hp", &"attack": "attack", &"defense": "defense", &"mp": "mana"}
const VITALITY_KEY := "vitality"

static var _cache: Dictionary = {}


static func ability_key(effect: AbilityData.Effect) -> String:
	return String(AbilityData.Effect.keys()[effect]).to_lower()


static func upgrade_key(effect: StringName, branch: bool) -> String:
	if branch and effect == &"hp":
		return VITALITY_KEY
	return UPGRADE_KEYS.get(effect, "")


static func texture(key: String) -> Texture2D:
	if key.is_empty():
		return null
	if not _cache.has(key):
		var path := DIRECTORY + key + ".png"
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


# Tests and previews inject emblems without writing files; null restores lookup.
static func set_override(key: String, value: Texture2D) -> void:
	if value == null:
		_cache.erase(key)
	else:
		_cache[key] = value


# Draws the emblem snapped to whole pixels; false when there is none, so the
# caller keeps its drawn symbol.
static func paint(canvas: CanvasItem, rect: Rect2, key: String) -> bool:
	var emblem := texture(key)
	if emblem == null:
		return false
	canvas.draw_texture_rect(emblem, Rect2(rect.position.round(), rect.size.round()), false)
	return true
