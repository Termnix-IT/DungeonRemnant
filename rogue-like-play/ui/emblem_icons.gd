class_name EmblemIcons
extends RefCounted

# Generated medallions for boons and lasting upgrades: art/emblems/<key>.png,
# a 192px painted emblem (tools/process_emblems.py) drawn shrunk from its
# mipmaps. The key is named by the data (BoonData.emblem, MetaUpgrade.emblem);
# without a file nothing is drawn, so art can arrive one emblem at a time.
const DIRECTORY := "res://art/emblems/"
# Emblems not painted yet, drawn meanwhile as an older medallion; a key's
# entry goes once its own file is in art/emblems/.
const STAND_INS := {
	"brute_force": "attack",
	"follow_up": "spear_damage",
	"long_reach": "spear_range",
	"rending_charge": "spear_pierce",
	"life_feast": "kill_heal",
	"riposte": "defense",
	"keen_art": "mana",
	"gale_step": "vision",
	"discharge": "chain_lightning",
	"thunder_step": "thunder_blade",
	"aftershock": "hammer_damage",
	"flame_art": "hellfire",
	"thunder_flash": "spear_range",
	"swallow_cut": "shockwave",
	"blaze_ring": "great_charge",
	"skill_drill": "mana",
	"echo_burst": "rising_burst",
	"sky_rend": "thunder_blade",
	"special_surge": "great_charge",
	"special_mastery": "attack",
}
static var _cache: Dictionary = {}


static func texture(key: String) -> Texture2D:
	if key.is_empty():
		return null
	if not _cache.has(key):
		var path := DIRECTORY + key + ".png"
		if not ResourceLoader.exists(path) and STAND_INS.has(key):
			path = DIRECTORY + STAND_INS[key] + ".png"
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


# Tests and previews inject emblems without writing files; null restores lookup.
static func set_override(key: String, value: Texture2D) -> void:
	if value == null:
		_cache.erase(key)
	else:
		_cache[key] = value


# Draws the emblem on whole pixels; false when there is none, so the caller
# keeps its drawn symbol.
static func paint(canvas: CanvasItem, rect: Rect2, key: String) -> bool:
	var emblem := texture(key)
	if emblem == null:
		return false
	canvas.draw_texture_rect(emblem, Rect2(rect.position.round(), rect.size.round()), false)
	return true
