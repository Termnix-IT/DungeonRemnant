class_name FoeIcon
extends RefCounted

# A foe's round icon for a list: the part of its bestiary portrait that tells
# it apart at a glance (a face or a head; the eye or the mouth of a foe with
# no head), cut as a square and masked to a circle, so every icon is the same
# size, turned as the foe stands on the stage, and none is blown up from the
# small frames baked for the fight. A foe with no portrait is cut from its
# rig's illustration instead. A foe not met is its shade. Made once per
# picture and kept.

# Pixels across the icon; drawn at about half this, so it stays sharp when
# the window is larger than the base size.
const SIZE := 112
# Where each portrait's icon is cut: the centre (x and y as shares of the
# trimmed figure's width and height) and the side (as a share of its
# height). A picture not listed is cut from its top (DEFAULT_CROP).
const CROPS := {
	"basic": Vector3(0.28, 0.24, 0.46),
	"moss_sentinel": Vector3(0.35, 0.22, 0.42),
	"skeleton": Vector3(0.32, 0.15, 0.28),
	"wraith": Vector3(0.3, 0.2, 0.36),
	"wisp": Vector3(0.42, 0.6, 0.5),
	"bell": Vector3(0.5, 0.6, 0.72),
	"fast": Vector3(0.18, 0.48, 0.95),
	"gale_rat": Vector3(0.17, 0.55, 0.62),
	"proximity": Vector3(0.22, 0.45, 0.9),
	"spore_swell": Vector3(0.2, 0.55, 0.95),
	"turret": Vector3(0.36, 0.3, 0.6),
	"summoner": Vector3(0.5, 0.45, 0.85),
	"charge": Vector3(0.22, 0.58, 0.6),
	"boss_spore_cannon": Vector3(0.22, 0.55, 0.45),
	"boss_gale_warden": Vector3(0.4, 0.2, 0.38),
	"boss_stone_gate": Vector3(0.42, 0.33, 0.42),
	"boss": Vector3(0.3, 0.2, 0.42),
	"boss_cannon_watcher": Vector3(0.35, 0.34, 0.5),
	"boss_ruin_king": Vector3(0.48, 0.2, 0.36),
	"boss_gale_wolf_king": Vector3(0.2, 0.58, 0.55),
	"boss_summoning_priest": Vector3(0.36, 0.42, 0.34),
	"boss_master_of_echoes": Vector3(0.46, 0.19, 0.27),
}
const DEFAULT_CROP := Vector3(0.5, 0.25, 0.5)
const SHADOW := Color(0.0, 0.0, 0.0, 0.85)

static var _icons: Dictionary = {}


static func of(visual_id: String, known: bool, tint: Color = Color.WHITE) -> Texture2D:
	var key := "%s:%s:%s" % [visual_id, known, tint.to_html()]
	if _icons.has(key):
		return _icons[key]
	var shown := {}
	var painted := EnemySprites.codex_portrait(visual_id)
	if painted != null:
		shown = {"texture": painted, "region": Rect2(Vector2.ZERO, painted.get_size())}
	if shown.is_empty():
		shown = EnemySprites.illustration(visual_id)
	if shown.is_empty():
		shown = EnemySprites.portrait(visual_id)
	if shown.is_empty():
		return null
	var image := (shown.texture as Texture2D).get_image()
	if image == null:
		return null
	image.decompress()
	image.clear_mipmaps()
	image = image.get_region(Rect2i(shown.region))
	image.convert(Image.FORMAT_RGBA8)
	var used := image.get_used_rect()
	if used.has_area():
		image = image.get_region(used)
	var crop: Vector3 = CROPS.get(visual_id, DEFAULT_CROP)
	var side := maxi(1, roundi(crop.z * image.get_height()))
	var corner := Vector2i(roundi(crop.x * image.get_width()) - side / 2, roundi(crop.y * image.get_height()) - side / 2)
	# The square may run past the figure's edge; what lies outside is clear.
	var square := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	square.blit_rect(image, Rect2i(corner, Vector2i(side, side)), Vector2i.ZERO)
	square.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	var radius := SIZE * 0.5
	for y in SIZE:
		for x in SIZE:
			var pixel := square.get_pixel(x, y)
			var reach := Vector2(x + 0.5 - radius, y + 0.5 - radius).length()
			var inside := clampf(radius - reach, 0.0, 1.0)
			if not known:
				pixel = Color(SHADOW, pixel.a * SHADOW.a)
			elif tint != Color.WHITE:
				pixel *= tint
			pixel.a *= inside
			square.set_pixel(x, y, pixel)
	# Drawn at about half its size: smaller steps keep it smooth.
	square.generate_mipmaps()
	_icons[key] = ImageTexture.create_from_image(square)
	return _icons[key]
