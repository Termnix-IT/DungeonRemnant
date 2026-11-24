extends SceneTree

# The scenes the help and the settings show (StageScenes), each drawn for
# real on a FightStage at four moments, as a sheet: one row a scene, time
# going right. Images go to .godot/stage_scenes.png. Needs a rendering
# display driver:
#   godot --path . --rendering-method gl_compatibility --log-file .godot/stage-capture.log --script res://tests/capture_stage.gd

const MOMENTS: Array[float] = [0.9, 1.7, 2.6, 3.6]
const CELL := Vector2i(480, 270)
const SCENES: Array[StringName] = [&"move", &"strike", &"charge", &"dash", &"skill", &"special", &"shards", &"shake", &"sounds"]


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	root.size = Vector2i(1600, 900)
	var back := ColorRect.new()
	back.color = Color(0.03, 0.035, 0.05)
	root.add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stage := FightStage.new()
	root.add_child(stage)
	stage.position = Vector2(80.0, 60.0)
	stage.size = Vector2(960.0, 540.0)
	var sheet := Image.create(CELL.x * MOMENTS.size(), CELL.y * SCENES.size(), false, Image.FORMAT_RGBA8)
	for row in SCENES.size():
		stage.show_scene(StageScenes.scene(SCENES[row]), row % AreaGround.THEMES.size(), 520.0)
		var began := Time.get_ticks_msec()
		for column in MOMENTS.size():
			while (Time.get_ticks_msec() - began) / 1000.0 < MOMENTS[column]:
				await process_frame
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image().get_region(Rect2i(80, 60, 960, 540))
			shot.convert(Image.FORMAT_RGBA8)
			shot.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, CELL), Vector2i(column * CELL.x, row * CELL.y))
	stage.halt()
	var result := sheet.save_png("res://.godot/stage_scenes.png")
	print("Captured the stage's scenes: stage_scenes")
	quit(0 if result == OK else 1)
