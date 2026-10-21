class_name EnemySprites
extends RefCounted

# Where a foe's illustration rig lives (art/enemies/rig/<visual id>_rig.tscn,
# built by tools/build_character_rig.gd from the JSON tools/write_enemy_rigs.py
# writes beside it), and a picture of the foe for screens that name it.

const RIG_DIRECTORY := "res://art/enemies/rig/"

static var _portraits: Dictionary = {}


static func rig_path(id: String) -> String:
	return RIG_DIRECTORY + id + "_rig.tscn"


# The foe's whole picture: {"texture", "region"}. A foe baked into frames
# shows its first idle frame; a rig drawn as one mesh, the rectangle of its
# body in the atlas; a rig drawn in parts, <id>_portrait.png beside it.
# Empty without any of them.
static func portrait(id: String) -> Dictionary:
	if _portraits.has(id):
		return _portraits[id]
	var found := {}
	var baked := FoeFrames.of(id)
	if not baked.is_empty():
		var first: AtlasTexture = (baked.frames as SpriteFrames).get_frame_texture(&"idle", 0)
		found = {"texture": first.atlas, "region": first.region}
	if found.is_empty() and ResourceLoader.exists(rig_path(id)):
		var rig: Node = (load(rig_path(id)) as PackedScene).instantiate()
		var body := rig.get_node_or_null(^"Parts/Body") as Polygon2D
		if body != null and body.texture != null:
			var region := Rect2(body.uv[0], Vector2.ZERO)
			for point in body.uv:
				region = region.expand(point)
			found = {"texture": body.texture, "region": region}
		rig.free()
	var own := RIG_DIRECTORY + id + "_portrait.png"
	if found.is_empty() and ResourceLoader.exists(own):
		var picture: Texture2D = load(own)
		found = {"texture": picture, "region": Rect2(Vector2.ZERO, picture.get_size())}
	_portraits[id] = found
	return found
