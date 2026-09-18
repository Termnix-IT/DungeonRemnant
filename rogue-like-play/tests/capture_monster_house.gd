extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var run := preload("res://game/run/run.tscn").instantiate()
	run.dungeon_settings = preload("res://data/dungeon/default.tres").duplicate()
	run.dungeon_settings.monster_house_chance = 1.0
	run.generation_seed = 17
	root.add_child(run)
	var house: Rect2i = run.dungeon.monster_house
	for y in range(house.position.y, house.end.y):
		var cell := Vector2i(house.position.x, y)
		if not run.dungeon.grid.occupants.has(cell):
			run.dungeon.grid.remove_actor(run.turns.player)
			run.dungeon.grid.place(run.turns.player, cell)
			break
	run._refresh()
	for frame in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/monster_house.png")
	print("Monster house capture complete")
	quit()
