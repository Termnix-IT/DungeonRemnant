extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func snapshot(path: String) -> bool:
	for frame in 2:
		await process_frame
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png(path) == OK


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	var main := load("res://game/main.gd").new() as Node
	var run = (load("res://game/run/run.tscn") as PackedScene).instantiate()
	main.add_child(run)
	run.generation_seed = 47
	run.dungeon_settings = DungeonSettings.new()
	run.dungeon_settings.enemy_count = 0
	root.add_child(main)
	var grid: GridState = run.dungeon.grid
	grid.size = Vector2i(20, 20)
	grid.walls.clear()
	grid.pillars.clear()
	grid.occupants.clear()
	run.dungeon.has_stairs = false
	run.dungeon.fog.reset()
	run.dungeon.get_node("ExploredTerrain").clear()
	grid.place(run.turns.player, Vector2i(4, 4))
	for cell: Vector2i in [Vector2i(5, 4), Vector2i(4, 6)]:
		var enemy := (load("res://actors/enemy/enemy.tscn") as PackedScene).instantiate()
		run.dungeon.get_node("Actors").add_child(enemy)
		grid.place(enemy, cell)
		run.turns.enemies.append(enemy)
	run.turns.enemies[0].hp = 4
	run.turns.submit("attack", Vector2i.RIGHT)
	if not run.ability_choice.visible or not await snapshot("res://.godot/progression_choice.png"):
		quit(1)
		return
	var event := InputEventKey.new()
	event.keycode = KEY_1
	event.physical_keycode = KEY_1
	event.pressed = true
	Input.parse_input_event(event)
	var saved := await snapshot("res://.godot/progression_resumed.png")
	if run.turns.busy or run.ability_choice.visible:
		push_error("Number key did not resume gameplay.")
		quit(1)
		return
	print("Captured ability choices and resumed gameplay; number-key input passed.")
	quit(0 if saved else 1)
