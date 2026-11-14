class_name ProtoCodex
extends RefCounted

# The bestiary's record for the three redesign prototypes: the game's own
# catalog (FoeCatalog), which foes are met (a MetaProgress of its own, never
# saved), and what may be told of each. A foe not met gives away exactly what
# the shipped page gives away and no more: its kind and its shade, never its
# name, figures, epithet or account.

const UNKNOWN_NAME := "？？？"
const UNKNOWN_NOTE := "まだ出会っていない敵。探索で戦場に現れると記録される。"
const MET: Array[StringName] = [
	&"wandering_sentinel", &"dashing_rat", &"mud_swell", &"crystal_turret", &"brood_nest", &"moss_sentinel", &"gale_rat",
	&"skeleton", &"wisp", &"blood_rat", &"raging_charger", &"gale_warden", &"ruin_king", &"gale_wolf_king",
]

var meta: MetaProgress
var _portraits := {}


func _init() -> void:
	meta = MetaProgress.new()
	for id in MET:
		meta.met[id] = true


# The catalog's foes of a kind (0 all, 1 the crowd, 2 elites, 3 bosses).
func foes(kind: int) -> Array[FoeData]:
	var listed: Array[FoeData] = []
	for foe in FoeCatalog.FOES:
		if kind == 0 or FoeCatalog.kind_of(foe) == kind:
			listed.append(foe)
	return listed


func known(foe: FoeData) -> bool:
	return meta.has_met(foe.id)


# Its number in the catalog, from 1.
func number(foe: FoeData) -> int:
	return FoeCatalog.FOES.find(foe) + 1


func name_of(foe: FoeData) -> String:
	return foe.display_name if known(foe) else UNKNOWN_NAME


func epithet(foe: FoeData) -> String:
	return foe.epithet if known(foe) else ""


func kind_name(foe: FoeData) -> String:
	return FoeCatalog.KINDS[FoeCatalog.kind_of(foe)]


# [key, name, value] for each of its figures; none for one not met.
func stats(foe: FoeData) -> Array:
	if not known(foe):
		return []
	return [["hp", "HP", foe.max_hp], ["contact", "ぶつかる力", foe.contact_damage], ["speed", "速さ", roundi(foe.speed)]]


# Its account: [what it does, where it appears]; the note for one not met.
func account(foe: FoeData) -> Array[String]:
	if not known(foe):
		return [UNKNOWN_NOTE, ""]
	var parts := foe.description.split("\n", false)
	return [parts[0], parts[1] if parts.size() > 1 else ""]


# The foe's painted figure. A copy made from the picture's image: drawn
# straight from the imported texture inside these screens' _draw it came out
# as a blank rect (cause not found; the icons, made the same way as this
# copy, draw as they should).
func portrait(foe: FoeData) -> Texture2D:
	if _portraits.has(foe.visual_id):
		return _portraits[foe.visual_id]
	var painted := EnemySprites.codex_portrait(foe.visual_id)
	var made: Texture2D = HubCodex.tile_picture(foe.visual_id, true)
	if painted != null:
		var image := painted.get_image()
		image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		image.generate_mipmaps()
		made = ImageTexture.create_from_image(image)
	_portraits[foe.visual_id] = made
	return made


# The foe's shape alone, in flat white, to be drawn in any one colour: what
# a foe not met shows. Tinting the painted figure instead would let its
# details through, which is more than the shipped page gives away.
func silhouette(foe: FoeData) -> Texture2D:
	var key := "shape:" + foe.visual_id
	if _portraits.has(key):
		return _portraits[key]
	var image := portrait(foe).get_image()
	image.clear_mipmaps()
	for y in image.get_height():
		for x in image.get_width():
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, image.get_pixel(x, y).a))
	image.generate_mipmaps()
	_portraits[key] = ImageTexture.create_from_image(image)
	return _portraits[key]


func icon(foe: FoeData) -> Texture2D:
	return FoeIcon.of(foe.visual_id, known(foe), foe.tint)


# [met, all] of a kind.
func tally(kind: int) -> Array[int]:
	var met := 0
	var listed := foes(kind)
	for foe in listed:
		met += 1 if known(foe) else 0
	return [met, listed.size()]


# The largest of a figure among the foes met, to draw one against.
func most(key: String) -> float:
	var top := 1.0
	for foe in FoeCatalog.FOES:
		for row: Array in stats(foe):
			if row[0] == key:
				top = maxf(top, float(row[2]))
	return top
