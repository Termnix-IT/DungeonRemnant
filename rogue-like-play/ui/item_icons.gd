class_name ItemIcons
extends RefCounted

# The painted icons, looked up by ItemData.id so item data stays untouched:
# DIRECTORY/<id>.png (weapons use weapon_<WeaponData.Kind>), 192 px, built by
# tools/build_painted_objects.py and drawn shrunk smoothly from their mipmaps
# (FILTER). Items without one keep ItemGlyph's drawn symbol.
const DIRECTORY := "res://art/items/painted/"
const FILTER := CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
# Grey theme colours mark secondary slots; icons dim instead of recolouring.
const MUTED_TINT := Color(0.62, 0.62, 0.62)

static var _cache: Dictionary = {}


# Loads every icon once, before anything draws one (Main calls it on start):
# icons are looked up while drawing, and a texture first loaded inside a
# draw call can be drawn as a blank white quad.
static func warm() -> void:
	for file in ResourceLoader.list_directory(DIRECTORY):
		if file.ends_with(".png") and not _cache.has(file.get_basename()):
			icon_by_id(file.get_basename())


static func icon(item: ItemData) -> Texture2D:
	if item == null or item.id.is_empty():
		return null
	return icon_by_id(String(item.id))


static func icon_by_id(key: String) -> Texture2D:
	if not _cache.has(key):
		var path := DIRECTORY + key + ".png"
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


# The filter for a canvas that draws item icons.
static func filter() -> CanvasItem.TextureFilter:
	return FILTER


# A weapon kind's icon, for the picture the hero holds; null without one.
static func painted_weapon(kind: int) -> Texture2D:
	return icon_by_id("weapon_%d" % kind)


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
