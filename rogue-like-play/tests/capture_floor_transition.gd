extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.gui_embed_subwindows = true
	var run := preload("res://game/run/run.tscn").instantiate()
	run.generation_seed = 47
	root.add_child(run)
	run._request_transition("stairs")
	run._refresh()
	for frame in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	var ok := root.get_texture().get_image().save_png("res://.godot/stair_confirmation.png") == OK
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	ok = ok and run.transition_kind.is_empty() and not run.turns.paused
	print("Stair dialog capture and Escape cancellation: ", ok)
	quit(0 if ok else 1)
