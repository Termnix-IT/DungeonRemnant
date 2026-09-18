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
	var settings := DungeonSettings.new()
	settings.monster_house_chance = 1.0
	var rng := RandomNumberGenerator.new()
	var surprise := false
	var outside := false
	for seed_value in range(1, 81):
		rng.seed = seed_value
		var data := DungeonGenerator.generate(settings, seed_value % 3 + 1, rng)
		var reached := LayoutUtils.distances(data.grid, data.start)
		var house: Rect2i = data.house
		check(house.has_area() and reached.size() == settings.width * settings.height - data.grid.walls.size(), "House retains connected map")
		check(reached.has(data.stairs) and data.stairs != data.start, "Reachable distinct stairs")
		var occupied := {data.start: true, data.stairs: true}
		for cell: Vector2i in data.enemies:
			occupied[cell] = true
		var valid: bool = data.house_enemies.size() == settings.monster_house_enemies
		for cell: Vector2i in data.house_enemies:
			valid = valid and house.has_point(cell) and not occupied.has(cell) and reached.has(cell)
			occupied[cell] = true
		check(valid, "Extra enemies distinct and inside house")
		var boundary_open := false
		for y in range(house.position.y, house.end.y):
			for x in range(house.position.x, house.end.x):
				var cell := Vector2i(x, y)
				for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					if not house.has_point(cell + direction) and data.grid.can_step(cell, cell + direction):
						boundary_open = true
		check(boundary_open, "Retreat path not sealed")
		surprise = surprise or house.has_point(data.start)
		outside = outside or not house.has_point(data.start)
	check(surprise and outside, "Both surprise starts and later discoveries exist")
	check(not DungeonGenerator.generate(settings, 10, rng).house.has_area(), "No house on midboss floor")
	check(not DungeonGenerator.generate(settings, 7, rng, true).house.has_area(), "No house on custom final floor")
	settings.monster_house_chance = 0.0
	check(not DungeonGenerator.generate(settings, 1, rng).house.has_area(), "Zero chance disables house")
	settings.monster_house_chance = 1.0
	settings.reinforcement_total_cap = 0
	var run := preload("res://game/run/run.tscn").instantiate()
	run.dungeon_settings = settings
	run.generation_seed = 17
	root.add_child(run)
	check(run.turns.enemies.size() == settings.enemy_count + settings.monster_house_enemies, "Run spawns extra enemies")
	check(run.dungeon.ground_items.size() == settings.item_count + settings.monster_house_items, "Run spawns extra rewards")
	var house: Rect2i = run.dungeon.monster_house
	var safe_cell := Vector2i(-1, -1)
	for y in range(house.position.y, house.end.y):
		for x in range(house.position.x, house.end.x):
			var cell := Vector2i(x, y)
			if not run.dungeon.grid.occupants.has(cell):
				safe_cell = cell
	check(safe_cell.x >= 0, "House has space for player")
	run.dungeon.grid.remove_actor(run.turns.player)
	run.dungeon.grid.place(run.turns.player, safe_cell)
	run._refresh()
	check(run.dungeon.house_discovered and run.hud.area.text == "モンスターハウス", "Discovery updates log and area")
	var revision: int = run.discovery_revision
	run._refresh()
	check(run.discovery_revision == revision, "Discovery recorded once")
	for entry: InventoryEntry in run.dungeon.ground_items.values():
		check(entry.item.kind != ItemData.Kind.SCROLL and entry.item.effect_id.is_empty(), "House respects shop/drop-only items")
	run.floor_number = 10
	run._load_floor()
	check(not run.dungeon.monster_house.has_area() and not run.dungeon.house_discovered, "House state resets on next floor")
	run.free()
	await process_frame
	print("Monster house tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
