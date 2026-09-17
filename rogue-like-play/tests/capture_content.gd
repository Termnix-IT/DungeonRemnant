extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var run := preload("res://game/run/run.tscn").instantiate()
	run.dungeon_settings = DungeonSettings.new()
	run.dungeon_settings.enemy_count = 0
	run.generation_seed = 47
	root.add_child(run)
	run.dungeon.grid.walls.clear()
	run.dungeon.grid.pillars.clear()
	run.dungeon.grid.occupants.clear()
	run.dungeon.grid.place(run.turns.player, Vector2i(10, 10))
	run.turns.player.weapon = preload("res://data/weapons/axe.tres")
	run.turns.player.aiming = true
	for index in 3:
		var enemy := preload("res://actors/enemy/enemy.tscn").instantiate()
		enemy.stats = [preload("res://data/enemies/fast_enemy.tres"), preload("res://data/enemies/summoner_enemy.tres"), preload("res://data/enemies/charge_enemy.tres")][index].duplicate()
		enemy.stats.elite = index == 0
		run.dungeon.get_node("Actors").add_child(enemy)
		run.dungeon.grid.place(enemy, Vector2i(11 + index, 9))
		run.turns.enemies.append(enemy)
		enemy.take_turn(run.dungeon.grid, run.turns.player)
	for item in ItemCatalog.talismans():
		run.turns.player.active_effects.add(item)
	run.turns.player.refresh_equipment_effects()
	run._refresh()
	for frame in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	var ok := root.get_texture().get_image().save_png("res://.godot/content_preview.png") == OK
	run.turns.submit("attack", Vector2i.RIGHT)
	if run.presentation.playing:
		await run.presentation.finished
	for frame in 2:
		await process_frame
		await RenderingServer.frame_post_draw
	ok = root.get_texture().get_image().save_png("res://.godot/content_attack.png") == OK and ok
	print("Content visual capture: ", ok)
	quit(0 if ok else 1)
