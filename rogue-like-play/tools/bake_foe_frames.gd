extends SceneTree

# Bakes the crowd foes' illustration rigs into frames: each motion the rig
# has (idle, walk, attack_sword, hurt, down, brace) is played and drawn
# frame by frame in a transparent SubViewport, at SCALE texture px per world
# px, into one atlas per foe: art/enemies/frames/<id>_frames.png, with its
# layout in <id>_frames.json (cell size, columns, where the feet are, and
# each motion's first frame, count, rate and whether it loops). FoeFrames
# reads them back as SpriteFrames, so a crowd is drawn as sprites rather
# than skinned rigs (Phase 2 measured about 0.06 ms per rig). The rig stays
# the source: change it, then bake again. Needs a rendering display driver:
#   godot --path . --script res://tools/bake_foe_frames.gd [-- id ...]
# (the ids named after --, or every one in IDS), and then an import (godot --headless --path . --editor --import --quit).

# Foe: how many times its figure's height the square cell is, so swinging
# hair, a cape, a figure lying fallen and a long body leaping all fit.
const IDS := {"basic": 1.7, "fast": 2.5, "moss_sentinel": 1.7, "gale_rat": 2.5}
const OUT := "res://art/enemies/frames/"
const SCALE := 2.0
const COLUMNS := 12
# The feet sit this far down the cell.
const FEET_DOWN := 0.8
# Motion: frames per second, and whether it loops.
const PLANS := {
	&"idle": [8.0, true],
	&"walk": [16.0, true],
	&"attack_sword": [20.0, false],
	&"hurt": [20.0, false],
	&"down": [16.0, false],
	&"brace": [10.0, true],
}
# One-shots start from this long a settled idle.
const SETTLE := 0.8
# The rig is stepped at most this long at a time: its lean is a spring
# stepped as given, which a long step throws out (an upside-down figure).
const SUBSTEP := 1.0 / 60.0


func _initialize() -> void:
	call_deferred("bake")


func bake() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Baking requires a rendering display driver.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var result := OK
	var named := OS.get_cmdline_user_args()
	for id: String in IDS:
		if named.is_empty() or named.has(id):
			result |= await _bake(id, IDS[id])
	quit(result)


func _bake(id: String, share: float) -> Error:
	var rig: CharacterRig = (load(EnemySprites.rig_path(id)) as PackedScene).instantiate()
	var height := float(rig.get_meta(&"world_height", 60.0))
	var cell := int(ceil(height * SCALE * share / 2.0)) * 2
	var feet := Vector2(cell * 0.5, roundf(cell * FEET_DOWN))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(cell, cell)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.add_child(viewport)
	var holder := Node2D.new()
	holder.position = feet
	viewport.add_child(holder)
	holder.add_child(rig)
	rig.world_height = height * SCALE
	# The bake steps the rig itself.
	rig.set_process(false)
	var player := rig.animation_player
	var frames: Array[Image] = []
	var layout := {"cell": cell, "columns": COLUMNS, "feet": [feet.x, feet.y], "scale": SCALE, "height": height, "animations": {}}
	for motion: StringName in PLANS:
		if not player.has_animation(motion):
			continue
		var plan: Array = PLANS[motion]
		var length := player.get_animation(motion).length
		var count := maxi(2, roundi(length * float(plan[0])))
		var step := length / count
		_start(rig, motion)
		if plan[1]:
			# A loop is shot on its second cycle, the springs swinging as in play.
			for warm in count:
				_advance(rig, motion, step)
		layout.animations[String(motion)] = {"start": frames.size(), "count": count, "fps": count / length, "loop": plan[1]}
		for index in count:
			if index > 0:
				_advance(rig, motion, step)
			await RenderingServer.frame_post_draw
			frames.append(viewport.get_texture().get_image())
	viewport.queue_free()
	var rows := ceili(float(frames.size()) / COLUMNS)
	var atlas := Image.create(COLUMNS * cell, rows * cell, false, Image.FORMAT_RGBA8)
	for index in frames.size():
		var frame := frames[index]
		frame.convert(Image.FORMAT_RGBA8)
		atlas.blit_rect(frame, Rect2i(0, 0, cell, cell), Vector2i(index % COLUMNS, index / COLUMNS) * cell)
	var error := atlas.save_png(OUT + id + "_frames.png")
	var file := FileAccess.open(OUT + id + "_frames.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(layout, "\t"))
	file.close()
	print("Baked %s: %d frames, %dx%d px" % [id, frames.size(), atlas.get_width(), atlas.get_height()])
	return error


# Settles the rig, then starts the motion as play would.
func _start(rig: CharacterRig, motion: StringName) -> void:
	rig.braced = false
	rig.idle()
	_run(rig, SETTLE)
	match motion:
		CharacterRig.WALK:
			rig.step(Vector2.RIGHT)
		CharacterRig.ATTACK:
			rig.attack()
		CharacterRig.HURT:
			rig.hurt()
		CharacterRig.DOWN:
			rig.fall()
		CharacterRig.BRACE:
			rig.braced = true
	rig.advance(0.0)


func _advance(rig: CharacterRig, motion: StringName, step: float) -> void:
	# Walking is a step taken every frame, as a foe on the move takes them.
	if motion == CharacterRig.WALK:
		rig.step(Vector2.RIGHT)
	_run(rig, step)


func _run(rig: CharacterRig, time: float) -> void:
	var steps := maxi(1, ceili(time / SUBSTEP))
	for index in steps:
		rig.advance(time / steps)
