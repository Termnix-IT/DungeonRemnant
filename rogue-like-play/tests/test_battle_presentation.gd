extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func run_tests() -> void:
	root.add_child(preload("res://game/main.gd").new())
	var run := preload("res://game/run/run.tscn").instantiate()
	run.generation_seed = 47
	run.dungeon_settings = DungeonSettings.new()
	run.dungeon_settings.enemy_count = 0
	run.dungeon_settings.item_count = 0
	run.dungeon_settings.reinforcement_total_cap = 0
	root.add_child(run)
	var player: Node2D = run.turns.player
	var grid: GridState = run.dungeon.grid
	grid.walls.clear()
	grid.pillars.clear()
	grid.occupants.clear()
	grid.place(player, Vector2i(10, 10))
	run.dungeon.has_stairs = false
	run.dungeon.fog.reset()
	var pivot: Node2D = player.combat_visual
	for index in 5:
		player.reset_step()
	check(player.combat_visual == pivot and player.get_child_count() == 1, "Walking reset reuses the visual pivot")
	var weapons := [preload("res://data/weapons/sword.tres"), preload("res://data/weapons/spear.tres"), preload("res://data/weapons/hammer.tres")]
	for weapon in weapons:
		player.weapon = weapon
		var enemy := preload("res://actors/enemy/enemy.tscn").instantiate()
		enemy.stats = enemy.stats.duplicate()
		enemy.stats.exp_reward = 0
		run.dungeon.get_node("Actors").add_child(enemy)
		grid.place(enemy, Vector2i(11, 10))
		enemy.hp = 2
		run.turns.enemies.append(enemy)
		run._refresh()
		var location := player.position
		run._on_action("attack", Vector2i.RIGHT)
		check(enemy.hp == 0 and not grid.occupants.has(enemy.cell), "Lethal damage is applied before playback")
		check(run.presentation.playing and not player.input_enabled, "Playback locks world input")
		var has_ghost := false
		for child in run.presentation.get_children():
			if child is Node2D:
				has_ghost = true
		check(has_ghost, "Lethal target remains drawn from attack start")
		await create_timer(0.18).timeout
		check(player.position == location and player.cell == Vector2i(10, 10), "Attack motion cannot move the logical player")
		var found_damage := false
		for child in run.presentation.get_children():
			if child is Label and child.text == "2":
				found_damage = child.position.y < enemy.position.y - 35
		check(found_damage, "Actual lost HP is displayed above target, including overkill")
		if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/battle_%d.png" % weapon.kind)
		if run.presentation.playing:
			await run.presentation.finished
		await process_frame
		check(player.input_enabled and player.combat_visual.position.is_zero_approx(), "Input and attack pose recover")
		await create_timer(0.45).timeout
		check(run.presentation.get_child_count() == 0, "Transient damage, death and sound nodes expire")
	# Surviving target, knockback and retaliation exercise chained visual events.
	player.weapon = weapons[2]
	var survivor := preload("res://actors/enemy/enemy.tscn").instantiate()
	survivor.stats = survivor.stats.duplicate()
	survivor.stats.max_hp = 100
	run.dungeon.get_node("Actors").add_child(survivor)
	grid.place(survivor, Vector2i(11, 10))
	run.turns.enemies.append(survivor)
	run._refresh()
	run._on_action("attack", Vector2i.RIGHT)
	await run.presentation.finished
	await process_frame
	check(survivor.visual_offset.is_zero_approx(), "Knockback followed by enemy movement settles at logical cell")
	grid.remove_actor(survivor)
	grid.place(survivor, Vector2i(11, 10))
	player.weapon = weapons[0]
	run._refresh()
	var hp_before: int = player.hp
	run._on_action("attack", Vector2i.LEFT)
	await create_timer(0.4).timeout
	var received_damage := false
	for child in run.presentation.get_children():
		if child is Label and child.text == str(hp_before - player.hp):
			received_damage = child.position.y < player.position.y - 35
	check(received_damage, "Enemy damage appears above the player")
	if run.presentation.playing:
		await run.presentation.finished
	await process_frame
	run.dungeon.ground_items[player.cell] = InventoryEntry.new(preload("res://data/items/healing_potion.tres"), 2)
	run._collect_items()
	var pickup_seen := false
	for child in run.presentation.get_children():
		if child is Label and child.text.contains("×2"):
			pickup_seen = true
	check(pickup_seen, "Pickup feedback includes accepted quantity")
	var log_before: Array = run.hud.log_history.duplicate()
	run.hud._record_log("移動しました。")
	check(run.hud.log_history == log_before, "Routine movement preserves useful log entries")
	run._load_floor()
	check(not run.presentation.playing and run.presentation.get_child_count() == 0, "Floor transition clears all transient effects")
	check(player.combat_visual.position.is_zero_approx(), "Floor transition resets combat pose")
	# Reinforcements appear after enemy actions, with no immediate movement.
	run.dungeon_settings.reinforcement_total_cap = 1
	run.dungeon_settings.reinforcement_interval = 1
	run.dungeon_settings.reinforcement_chance = 1.0
	run._on_action("attack", Vector2i.RIGHT)
	check(run.turns.enemies.size() == 1, "Successful turn spawns configured reinforcement")
	if not run.turns.enemies.is_empty():
		var reinforcement: Node2D = run.turns.enemies[0]
		check(reinforcement.last_seen_cell == Vector2i(-1, -1) and not reinforcement.visible, "New reinforcement is hidden and has not acted")
	run.free()
	print("Battle presentation tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
