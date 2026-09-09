extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	var main := load("res://game/main.gd").new() as Node
	var run = (load("res://game/run/run.tscn") as PackedScene).instantiate()
	main.add_child(run)
	run.generation_seed = 47
	root.add_child(main)
	for floor_value in [1, 2, 3, 10]:
		if floor_value != 1:
			run.floor_number = floor_value
			run._load_floor()
		run._refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png("res://.godot/floor_%d.png" % floor_value)
		if result != OK:
			quit(1)
			return
	# Capture the exit marker and attack overlay together for alignment checks.
	run.floor_number = 1
	run._load_floor()
	var hero: Node2D = run.turns.player
	var grid: GridState = run.dungeon.grid
	for direction in LayoutUtils.DIRECTIONS:
		var adjacent: Vector2i = run.dungeon.stairs_cell - direction
		if grid.can_step(adjacent, run.dungeon.stairs_cell) and grid.is_floor(adjacent) and not grid.occupants.has(adjacent):
			grid.remove_actor(hero)
			grid.place(hero, adjacent)
			hero.facing = direction
			hero.aiming = true
			break
	run._refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://.godot/stairs_preview.png")
	if result != OK:
		quit(1)
		return
	# Controlled exploration fixture: remembered left area, visible center,
	# unknown right area, a pillar shadow, and an enemy behind a wall.
	grid.size = Vector2i(32, 24)
	grid.walls.clear()
	grid.pillars.clear()
	grid.occupants.clear()
	for y in grid.size.y:
		for x in grid.size.x:
			if x == 0 or y == 0 or x == 31 or y == 23:
				grid.walls[Vector2i(x, y)] = true
	for y in range(3, 21):
		grid.walls[Vector2i(19, y)] = true
	grid.walls[Vector2i(15, 10)] = true
	grid.pillars[Vector2i(15, 10)] = true
	run.dungeon.stairs_cell = Vector2i(10, 15)
	run.dungeon.fog.reset()
	run.dungeon.get_node("ExploredTerrain").clear()
	hero.aiming = false
	grid.place(hero, Vector2i(6, 12))
	var positions: Array[Vector2i] = [Vector2i(21, 12), Vector2i(17, 14), Vector2i(16, 8)]
	for index in run.turns.enemies.size():
		grid.place(run.turns.enemies[index], positions[index])
	run._refresh()
	grid.remove_actor(hero)
	grid.place(hero, Vector2i(14, 12))
	run._refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	# Allow queued tile/transform updates to settle before reading the viewport.
	await process_frame
	await RenderingServer.frame_post_draw
	result = root.get_texture().get_image().save_png("res://.godot/exploration_preview.png")
	print("Captured floors, stairs, and exploration preview.")
	quit(0 if result == OK else 1)
