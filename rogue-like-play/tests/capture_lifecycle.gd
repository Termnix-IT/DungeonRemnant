extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)


func settle() -> void:
	for frame in 2:
		await process_frame
		await RenderingServer.frame_post_draw


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var main := load("res://game/main.gd").new() as Node
	var run = (load("res://game/run/run.tscn") as PackedScene).instantiate()
	main.add_child(run)
	run.generation_seed = 47
	root.add_child(main)
	for index in 8:
		run.turns.player.inventory.add(ItemCatalog.floor_item(index), 4)
	run.turns.player.inventory.add(ItemCatalog.POTION, 15)
	run.turns.gold = 101
	run.turns.earned_gold = 101
	run._refresh()
	await settle()
	var ok := root.get_texture().get_image().save_png("res://.godot/lifecycle_hud.png") == OK
	key(KEY_R)
	await settle()
	ok = ok and run.result_panel.visible and run.result_panel.confirming and not run.turns.player.input_enabled
	ok = root.get_texture().get_image().save_png("res://.godot/lifecycle_confirm.png") == OK and ok
	key(KEY_ESCAPE)
	await settle()
	ok = ok and not run.result_panel.visible and run.turns.player.input_enabled and run.turns.gold == 101
	key(KEY_R)
	await settle()
	var click := InputEventMouseButton.new()
	click.position = run.result_panel.accept.get_global_rect().get_center()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	await settle()
	ok = ok and not run.result.is_empty() and run.turns.gold == 51
	ok = root.get_texture().get_image().save_png("res://.godot/lifecycle_result.png") == OK and ok
	key(KEY_R)
	await settle()
	ok = ok and run.result.is_empty() and run.turns.gold == 51 and run.turns.player.input_enabled and not run.result_panel.visible
	run.finish_run(true)
	await settle()
	ok = root.get_texture().get_image().save_png("res://.godot/lifecycle_clear.png") == OK and ok
	print("Lifecycle capture and R / Esc / mouse confirm / retry input: ", "passed" if ok else "FAILED")
	quit(0 if ok else 1)
