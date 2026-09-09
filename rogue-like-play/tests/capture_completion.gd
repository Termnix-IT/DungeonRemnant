extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func settle() -> void:
	for frame in 2:
		await process_frame
		await RenderingServer.frame_post_draw


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var save_path := "res://.godot/completion-visual-%d.json" % Time.get_ticks_usec()
	var main := preload("res://game/main.tscn").instantiate()
	main.save_store.path = save_path
	root.add_child(main)
	main.start_run()
	var run: Node2D = main.active_run
	run.floor_number = 10
	run.rng.seed = 47
	run._load_floor()
	var boss: Node2D = run.turns.enemies.back()
	var grid: GridState = run.dungeon.grid
	var neighbor: Vector2i = boss.cell
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if grid.can_step(boss.cell, boss.cell + direction) and not grid.occupants.has(boss.cell + direction):
			neighbor = boss.cell + direction
			break
	assert(neighbor != boss.cell)
	grid.remove_actor(run.turns.player)
	grid.place(run.turns.player, neighbor)
	run.turns.player.facing = boss.cell - neighbor
	run._refresh()
	await settle()
	var ok := root.get_texture().get_image().save_png("res://.godot/completion_boss.png") == OK
	# Only the visual fixture reduces boss HP; production uses the Resource value.
	boss.hp = 1
	for press in 2:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_SPACE
		event.keycode = KEY_SPACE
		event.pressed = true
		Input.parse_input_event(event)
		var release := event.duplicate() as InputEventKey
		release.pressed = false
		Input.parse_input_event(release)
		await settle()
	ok = ok and run.result.get("cleared", false) and run.result_panel.save_label.text.contains("保存済み")
	ok = root.get_texture().get_image().save_png("res://.godot/completion_clear.png") == OK and ok
	var saved_gold: int = run.turns.gold
	main.free()
	main = preload("res://game/main.tscn").instantiate()
	main.save_store.path = save_path
	root.add_child(main)
	await settle()
	ok = ok and main.state.gold == saved_gold and main.get_node("Hub").save_label.text.contains("読み込み")
	ok = root.get_texture().get_image().save_png("res://.godot/completion_loaded.png") == OK and ok
	main.save_store.path = "res://.godot/nonexistent-save-directory/progress.json"
	main.start_run()
	await settle()
	ok = ok and main.active_run == null and main.get_node("Hub").save_label.text.contains("保存失敗")
	ok = root.get_texture().get_image().save_png("res://.godot/completion_save_error.png") == OK and ok
	print("Completion visuals: boss / Space kill / clear / restored Hub / save error: ", "passed" if ok else "FAILED")
	quit(0 if ok else 1)
