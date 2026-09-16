extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	var board := Node2D.new()
	root.add_child(board)
	board.draw.connect(func():
		for y in 15:
			for x in 24:
				board.draw_rect(Rect2(x * 48, y * 48, 48, 48), Color("242936") if (x + y) % 2 == 0 else Color("303847"))
	)
	board.queue_redraw()
	var camera := Camera2D.new()
	camera.zoom = Vector2(1.25, 1.25)
	camera.position = Vector2(576, 360)
	board.add_child(camera)
	var directions := [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT,
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	var weapons := [preload("res://data/weapons/sword.tres"), preload("res://data/weapons/spear.tres"), preload("res://data/weapons/hammer.tres")]
	var players: Array[Node2D] = []
	for row in weapons.size():
		for column in directions.size():
			var player = preload("res://actors/player/player.tscn").instantiate()
			board.add_child(player)
			player.position = Vector2(72 + column * 144, 120 + row * 192)
			player.facing = directions[column]
			player.weapon = weapons[row]
			player.input_enabled = false
			player.queue_redraw()
			players.append(player)
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://.godot/player_integration_idle.png")
	for player in players:
		player.play_step(player.facing, 48)
	await create_timer(0.22).timeout
	await RenderingServer.frame_post_draw
	error |= root.get_texture().get_image().save_png("res://.godot/player_integration_walk.png")
	print("Captured player integration: 8 directions, 3 weapons, 48px tiles, 1.25 camera.")
	board.free()
	root.add_child(preload("res://game/main.gd").new())
	var run := preload("res://game/run/run.tscn").instantiate()
	run.generation_seed = 47
	run.dungeon_settings = run.dungeon_settings.duplicate()
	run.dungeon_settings.enemy_count = 0
	run.dungeon_settings.item_count = 0
	root.add_child(run)
	var hero: Node2D = run.turns.player
	var grid: GridState = run.dungeon.grid
	for direction: Vector2i in MioAnimation.FACINGS:
		# Exercise real action/turn/camera handling on generated dungeon terrain.
		for y in range(1, grid.size.y - 1):
			var found := false
			for x in range(1, grid.size.x - 1):
				var origin := Vector2i(x, y)
				if grid.is_floor(origin) and grid.can_step(origin, origin + direction) and origin + direction != run.dungeon.stairs_cell:
					grid.remove_actor(hero)
					grid.place(hero, origin)
					found = true
					break
			if found:
				break
		hero.reset_step()
		run._refresh()
		run._on_action("move", direction)
		for frame in 4:
			await create_timer(0.08).timeout
			await RenderingServer.frame_post_draw
			error |= root.get_texture().get_image().save_png("res://.godot/player_dungeon_%s_%d.png" % [MioAnimation.direction_name(direction), frame])
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		error |= root.get_texture().get_image().save_png("res://.godot/player_dungeon_%s_idle.png" % MioAnimation.direction_name(direction))
	print("Captured real dungeon actions: eight directions, walk sequence and idle.")
	quit(0 if error == OK else 1)
