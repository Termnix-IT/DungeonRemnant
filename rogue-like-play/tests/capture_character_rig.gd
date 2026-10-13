extends SceneTree

# Captures the rig PoC viewer (tests/rig_poc_viewer.tscn) for a visual check:
# the idle with the eight facings side by side, a walk's stride, the sword
# attack's wind-up, strike and follow, the strike in each facing, the three
# heights, pixel snap off, and the frame time with thirty-one rigs. Images
# go to .godot/rig_*.png. Frames are held in memory and written at the end,
# so writing never delays the next shot.

var shots: Dictionary = {}


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	root.size = Vector2i(1600, 900)
	var viewer: Node2D = (load("res://tests/rig_poc_viewer.tscn") as PackedScene).instantiate()
	root.add_child(viewer)
	await create_timer(1.2).timeout
	await _grab("rig_idle")
	viewer.do_step(Vector2i.RIGHT)
	await _grab_at(Time.get_ticks_msec(), {"rig_walk_0": 0.05, "rig_walk_1": 0.1, "rig_walk_2": 0.2, "rig_walk_3": 0.3})
	await create_timer(0.8).timeout
	await _grab("rig_walk_settled")
	viewer.do_step(Vector2i.LEFT)
	await create_timer(0.9).timeout
	viewer.face(Vector2i.DOWN)
	await create_timer(0.3).timeout
	viewer.do_attack()
	await _grab_at(Time.get_ticks_msec(), {"rig_attack_050": 0.05, "rig_attack_090": 0.09, "rig_attack_160": 0.16, "rig_attack_300": 0.3})
	await create_timer(0.8).timeout
	await _grab("rig_attack_settled")
	for direction: Vector2i in viewer.TURN_ORDER:
		viewer.face(direction)
		await create_timer(0.3).timeout
		viewer.do_attack()
		await _grab_at(Time.get_ticks_msec(), {"rig_strike_%s" % MioAnimation.direction_name(direction): 0.09})
		await create_timer(0.8).timeout
	viewer.face(Vector2i.DOWN)
	for height in [56.0, 72.0, 64.0]:
		viewer.set_world_height(height)
		await create_timer(0.3).timeout
		await _grab("rig_height_%d" % height)
	viewer.set_snap(false)
	await create_timer(0.3).timeout
	await _grab("rig_snap_off")
	viewer.set_snap(true)
	var single_ms: float = await _frame_time()
	viewer.set_stress(true)
	await create_timer(1.0).timeout
	var stressed_ms: float = await _frame_time()
	await _grab("rig_stress")
	viewer.set_stress(false)
	var result := OK
	for file_name: String in shots:
		result |= (shots[file_name] as Image).save_png("res://.godot/%s.png" % file_name)
	print("Frame time: one rig %.2f ms, thirty-one rigs %.2f ms (vsync may cap both)" % [single_ms, stressed_ms])
	print("Captured the rig PoC.")
	quit(0 if result == OK else 1)


func _grab(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	shots[file_name] = root.get_texture().get_image()


# Shots at seconds after started (msec ticks), each on the first frame drawn
# at or past its time.
func _grab_at(started: int, times: Dictionary) -> void:
	for file_name: String in times:
		while (Time.get_ticks_msec() - started) / 1000.0 < float(times[file_name]):
			await process_frame
		await _grab(file_name)


func _frame_time() -> float:
	var started := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - started < 2000000:
		await process_frame
		frames += 1
	return 2000.0 / frames
