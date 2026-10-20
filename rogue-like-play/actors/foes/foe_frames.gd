class_name FoeFrames
extends RefCounted

# A crowd foe's rig baked into frames (tools/bake_foe_frames.gd): the atlas
# art/enemies/frames/<id>_frames.png and its layout <id>_frames.json, read
# once per foe kind into SpriteFrames shared by every foe drawn with them.

const DIRECTORY := "res://art/enemies/frames/"

static var _cache: Dictionary = {}


static func exists(id: String) -> bool:
	return ResourceLoader.exists(DIRECTORY + id + "_frames.png") and FileAccess.file_exists(DIRECTORY + id + "_frames.json")


# {"frames": SpriteFrames, "feet": Vector2 (texture px), "scale": texture px
# per world px, "height": world px}, or {} when the foe has none baked.
static func of(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var found := {}
	if exists(id):
		var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + id + "_frames.json"))
		if layout is Dictionary:
			found = _build(load(DIRECTORY + id + "_frames.png"), layout)
	_cache[id] = found
	return found


static func _build(atlas: Texture2D, layout: Dictionary) -> Dictionary:
	var cell := int(layout.cell)
	var columns := int(layout.columns)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var motions: Dictionary = layout.animations
	for motion: String in motions:
		var plan: Dictionary = motions[motion]
		frames.add_animation(motion)
		frames.set_animation_speed(motion, float(plan.fps))
		frames.set_animation_loop(motion, bool(plan.loop))
		for index in int(plan.count):
			var at := int(plan.start) + index
			var piece := AtlasTexture.new()
			piece.atlas = atlas
			piece.region = Rect2(Vector2(at % columns, at / columns) * cell, Vector2.ONE * cell)
			frames.add_frame(motion, piece)
	var feet: Array = layout.feet
	return {"frames": frames, "feet": Vector2(feet[0], feet[1]), "scale": float(layout.scale), "height": float(layout.height)}
