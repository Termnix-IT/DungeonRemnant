class_name ItemIcons
extends RefCounted

# Optional generated icons, looked up by ItemData.id so item data stays
# untouched: art/items/<id>.png (weapons use weapon_<WeaponData.Kind>). Each is
# a 48px pixel-art icon stored at 2x. Items without one keep ItemGlyph's drawn
# symbol, so art can arrive one item at a time.
const DIRECTORY := "res://art/items/"
# Grey theme colours mark secondary slots; icons dim instead of recolouring.
const MUTED_TINT := Color(0.62, 0.62, 0.62)

static var _cache: Dictionary = {}


static func icon(item: ItemData) -> Texture2D:
	if item == null or item.id.is_empty():
		return null
	var key := String(item.id)
	if not _cache.has(key):
		var path := DIRECTORY + key + ".png"
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


# Tests and previews inject icons without writing files; null restores lookup.
static func set_override(id: StringName, texture: Texture2D) -> void:
	if texture == null:
		_cache.erase(String(id))
	else:
		_cache[String(id)] = texture


# The drawn symbols take their colour from the Theme role. For an icon, a
# bright role shows it as painted and a grey one dims it; alpha always carries.
static func tint(color: Color) -> Color:
	var result := Color.WHITE if color.s > 0.2 or color.v > 0.85 else MUTED_TINT
	result.a = color.a
	return result
