extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func settle() -> void:
	for frame in 2:
		await process_frame
		await RenderingServer.frame_post_draw


func click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	await settle()


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	root.add_child(main)
	var hub = main.get_node("Hub")
	await settle()
	var ok := root.get_texture().get_image().save_png("res://.godot/hub_initial.png") == OK
	# Test-only funds make purchase verification repeatable; production starts at 0.
	main.state.gold = 101
	hub.refresh(main.state)
	await click(hub.purchase_button)
	ok = ok and main.state.gold == 71 and main.state.hp_upgrade_level == 1
	ok = root.get_texture().get_image().save_png("res://.godot/hub_purchased.png") == OK and ok
	await click(hub.start_button)
	ok = ok and main.active_run != null and not hub.visible
	var run: Node2D = main.active_run
	ok = ok and run.turns.player.hp == 25 and run.turns.gold == 71
	run.finish_run(false)
	await settle()
	ok = root.get_texture().get_image().save_png("res://.godot/hub_result.png") == OK and ok
	var event := InputEventKey.new()
	event.physical_keycode = KEY_R
	event.keycode = KEY_R
	event.pressed = true
	Input.parse_input_event(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	await settle()
	ok = ok and main.active_run == null and hub.visible and main.state.gold == 36
	ok = root.get_texture().get_image().save_png("res://.godot/hub_returned.png") == OK and ok
	await click(hub.start_button)
	ok = ok and main.active_run.turns.player.hp == 25 and main.active_run.turns.gold == 36
	main.active_run.finish_run(true)
	await settle()
	await click(main.active_run.result_panel.accept)
	ok = ok and hub.visible and main.active_run == null and main.state.gold == 36
	print("Hub capture, mouse purchase/start/return and keyboard R return: ", "passed" if ok else "FAILED")
	quit(0 if ok else 1)
