class_name ItemIcons
extends RefCounted

# Optional generated icons, looked up by ItemData.id so item data stays
# untouched: art/items/<id>.png (weapons use weapon_<WeaponData.Kind>), each a
# 48px pixel-art icon stored at 2x. A painted icon of the same name in
# PAINTED_DIRECTORY (tools/build_painted_objects.py) comes first while
# `painted` is on. Items without either keep ItemGlyph's drawn symbol, so art
# can arrive one item at a time.
const DIRECTORY := "res://art/items/"
const PAINTED_DIRECTORY := "res://art/items/painted/"
# What a canvas drawing icons uses: painted icons are shrunk smoothly from
# their mipmaps, pixel icons keep their pixels.
const PAINTED_FILTER := CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
# Grey theme colours mark secondary slots; icons dim instead of recolouring.
const MUTED_TINT := Color(0.62, 0.62, 0.62)

static var _cache: Dictionary = {}
static var painted := true:
	set(value):
		painted = value
		_cache.clear()


# Loads every icon once, before anything draws one (Main calls it on start):
# icons are looked up while drawing, and a texture first loaded inside a
# draw call can be drawn as a blank white quad.
static func warm() -> void:
	for directory in [PAINTED_DIRECTORY, DIRECTORY]:
		for file in ResourceLoader.list_directory(directory):
			if file.ends_with(".png"):
				var key := file.get_basename()
				if not _cache.has(key):
					icon_by_id(key)


static func icon(item: ItemData) -> Texture2D:
	if item == null or item.id.is_empty():
		return null
	return icon_by_id(String(item.id))


static func icon_by_id(key: String) -> Texture2D:
	if not _cache.has(key):
		var painted_path := PAINTED_DIRECTORY + key + ".png"
		var path := DIRECTORY + key + ".png"
		if painted and ResourceLoader.exists(painted_path):
			_cache[key] = load(painted_path)
		else:
			_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


# The filter for a canvas that draws item icons.
static func filter() -> CanvasItem.TextureFilter:
	return PAINTED_FILTER if painted else CanvasItem.TEXTURE_FILTER_NEAREST


# A weapon kind's painted icon, for the picture the hero holds; null without
# one. Cached like the icons: loading a texture inside a draw call leaves it
# drawn as a blank white quad.
static func painted_weapon(kind: int) -> Texture2D:
	var key := "painted_weapon_%d" % kind
	if not _cache.has(key):
		var path := PAINTED_DIRECTORY + "weapon_%d.png" % kind
		_cache[key] = load(path) if painted and ResourceLoader.exists(path) else null
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
