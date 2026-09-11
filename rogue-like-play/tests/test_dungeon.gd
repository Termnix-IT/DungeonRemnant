extends SceneTree

const RUN := preload("res://game/run/run.tscn")
const ENEMY := preload("res://actors/enemy/enemy.tscn")
const HAMMER := preload("res://data/weapons/hammer.tres")
var checks := 0
var failures := 0
var map_count := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func cardinal_region(grid: GridState, start: Vector2i) -> Dictionary:
	# Independent of the generator's eight-direction flood fill.
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next := cell + direction
			if grid.is_floor(next) and not visited.has(next):
				visited[next] = true
				queue.append(next)
	return visited


func test_generation() -> void:
	var settings := DungeonSettings.new()
	var rng := RandomNumberGenerator.new()
	for size in [20, 40, 60]:
		settings.width = size
		settings.height = size
		for layout in range(1, 4):
			var signatures: Dictionary = {}
			for seed_value in range(1, 21):
				rng.seed = seed_value
				var data := DungeonGenerator.generate(settings, layout, rng)
				var grid: GridState = data.grid
				var label := "%dx%d layout %d seed %d" % [size, size, layout, seed_value]
				map_count += 1
				signatures[hash(grid.walls)] = true
				check(grid.size == Vector2i(size, size), label + " dimensions")
				var border_ok := true
				for edge in size:
					border_ok = border_ok and not grid.is_floor(Vector2i(edge, 0)) and not grid.is_floor(Vector2i(edge, size - 1))
					border_ok = border_ok and not grid.is_floor(Vector2i(0, edge)) and not grid.is_floor(Vector2i(size - 1, edge))
				check(border_ok, label + " outer walls")
				var reached := cardinal_region(grid, data.start)
				check(reached.size() == size * size - grid.walls.size(), label + " all floors connected")
				check(data.start != data.stairs and reached.has(data.stairs), label + " stairs reachable")
				var placed: Dictionary = {data.start: true, data.stairs: true}
				var enemies_ok: bool = data.enemies.size() == settings.enemy_count
				var steps := LayoutUtils.distances(grid, data.start)
				for cell: Vector2i in data.enemies:
					enemies_ok = enemies_ok and reached.has(cell) and not placed.has(cell) and int(steps[cell]) >= settings.enemy_start_distance
					placed[cell] = true
				check(enemies_ok, label + " enemies reachable, separated, safe start")
				check(data.layout == DungeonGenerator.LAYOUT_NAMES[layout - 1], label + " layout type")
			check(signatures.size() > 1, "Different seeds change each layout")
	# Both terrain and spawn selection must be reproducible.
	rng.seed = 31415
	var first := DungeonGenerator.generate(settings, 2, rng)
	rng.seed = 31415
	var second := DungeonGenerator.generate(settings, 2, rng)
	check(first.grid.walls == second.grid.walls and first.start == second.start and first.stairs == second.stairs and first.enemies == second.enemies, "Seed reproducibility")
	settings.width = 20
	settings.height = 20
	settings.cave_wall_chance = 0.55
	settings.enemy_count = 20
	settings.enemy_start_distance = 12
	for layout in range(1, 4):
		rng.seed = 81
		var data := DungeonGenerator.generate(settings, layout, rng)
		check(cardinal_region(data.grid, data.start).has(data.stairs), "Dense settings keep stairs reachable")
		check(data.enemies.size() <= 20, "Crowded settings never overpopulate")


func new_run(enemy_count: int = 2) -> Node2D:
	var run := RUN.instantiate()
	run.generation_seed = 47
	run.dungeon_settings = DungeonSettings.new()
	run.dungeon_settings.enemy_count = enemy_count
	root.add_child(run)
	return run


func test_terrain_art() -> void:
	var run := new_run(0)
	var terrain: TileMapLayer = run.dungeon.get_node("Terrain")
	var atlas := terrain.tile_set.get_source(0) as TileSetAtlasSource
	check(atlas != null and atlas.texture.get_size() == Vector2(672, 32), "Pixel terrain atlas loaded at twenty-one 32px tiles")
	check(atlas.get_tiles_count() == 21, "All terrain art variants registered")
	check(run.dungeon._terrain_tile(run.dungeon.stairs_cell) == run.dungeon.STAIRS_TILE, "Stairs use dedicated gold tile")
	var player_cell: Vector2i = run.turns.player.cell
	var first_tile: int = run.dungeon._terrain_tile(player_cell)
	run.dungeon.update_visibility(player_cell, run.turns.player.vision_range)
	check(first_tile in run.dungeon.FLOOR_TILES and terrain.get_cell_atlas_coords(player_cell).x == first_tile, "Floor art variant remains stable across visibility redraw")
	var wall_variants_valid := true
	for cell: Vector2i in run.dungeon.grid.walls:
		var tile: int = run.dungeon._terrain_tile(cell)
		if tile < run.dungeon.WALL_TILE_START or tile >= run.dungeon.WALL_TILE_START + run.dungeon.WALL_TILE_COUNT:
			wall_variants_valid = false
	check(wall_variants_valid, "Every generated wall maps to a registered connection tile")
	var theme_boundaries := [[1, 0], [3, 0], [4, 1], [6, 1], [7, 2], [9, 2], [10, 3], [99, 3]]
	for expectation: Array in theme_boundaries:
		check(run.dungeon._terrain_theme_index(int(expectation[0])) == int(expectation[1]), "Floor %d selects terrain theme %d" % expectation)
	var theme_floors := [1, 4, 7, 10]
	var theme_paths := [
		"res://art/tiles/dungeon_terrain.png",
		"res://art/tiles/dungeon_terrain_moss.png",
		"res://art/tiles/dungeon_terrain_ember.png",
		"res://art/tiles/dungeon_terrain_sanctum.png",
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	for theme_index in theme_floors.size():
		var floor_value: int = theme_floors[theme_index]
		run.dungeon.build(run.dungeon_settings, floor_value, rng, floor_value == 10)
		atlas = run.dungeon.get_node("Terrain").tile_set.get_source(0) as TileSetAtlasSource
		check(run.dungeon.terrain_theme_index == theme_index and atlas.texture.resource_path == theme_paths[theme_index] and atlas.texture.get_size() == Vector2(672, 32), "Floor %d loads its complete terrain theme atlas" % floor_value)
	var center := Vector2i(10, 10)
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for expected_mask in 16:
		run.dungeon.grid.walls.clear()
		run.dungeon.grid.pillars.clear()
		run.dungeon.grid.walls[center] = true
		for direction_index in directions.size():
			if expected_mask & (1 << direction_index):
				run.dungeon.grid.walls[center + directions[direction_index]] = true
		check(run.dungeon._terrain_tile(center) == run.dungeon.WALL_TILE_START + expected_mask, "Wall connection mask %d maps to its atlas tile" % expected_mask)
	run.dungeon.grid.walls.clear()
	run.dungeon.grid.walls[center] = true
	run.dungeon.grid.walls[center + Vector2i.ONE] = true
	check(run.dungeon._wall_connection_mask(center) == 0, "Diagonal walls do not create cardinal connections")
	run.dungeon.grid.walls[center + Vector2i.UP] = true
	run.dungeon.grid.pillars[center + Vector2i.UP] = true
	check(run.dungeon._wall_connection_mask(center) == 0, "Freestanding pillars do not merge into walls")
	run.free()


func test_ten_floors() -> void:
	# Walk real generated routes with no enemies to isolate transition semantics.
	var run := new_run(0)
	var player: Node2D = run.turns.player
	player.hp = 13
	player.weapon = HAMMER
	var turn_total := 0
	for expected_floor in range(1, 10):
		check(run.floor_number == expected_floor, "Floor progression order")
		var pathfinder := AStarGrid2D.new()
		pathfinder.region = Rect2i(Vector2i.ZERO, run.dungeon.grid.size)
		pathfinder.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		pathfinder.update()
		for wall: Vector2i in run.dungeon.grid.walls:
			pathfinder.set_point_solid(wall)
		var path := pathfinder.get_id_path(player.cell, run.dungeon.stairs_cell)
		check(path.size() > 1, "Playable route to stairs")
		for index in range(1, path.size()):
			check(run.turns.submit("move", path[index] - path[index - 1]), "Route step accepted")
			turn_total += 1
		check(run.floor_number == expected_floor + 1, "Stair move changes floor once")
		check(run.turns.player == player and player.hp == 13 and player.weapon == HAMMER, "HP, weapon and player preserved")
		check(run.turns.turn_count == turn_total, "Stairs cost exactly one move")
		check(run.camera.global_position == player.global_position, "Camera follows player after transition")
		check(not run.preview.visible and not player.aiming, "No stale attack preview")
		var terrain: TileMapLayer = run.dungeon.get_node("Terrain")
		check(terrain.position + terrain.map_to_local(player.cell) == player.position, "Tile and actor alignment")
	check(not run.dungeon.has_stairs and run.floor_number == 10, "10F has no exit to 11F")
	var count: int = run.turns.turn_count
	run.turns.submit("attack", Vector2i.RIGHT)
	check(run.floor_number == 10 and run.turns.turn_count == count + 1, "Final floor remains playable")
	run.free()
	run = new_run()
	check(run.floor_number == 1 and run.turns.turn_count == 0 and run.turns.player.hp == 24, "New run starts on 1F with full HP")
	run.free()


func arrange_stair_fight(run: Node2D) -> void:
	for enemy: Node2D in run.turns.enemies:
		enemy.get_parent().remove_child(enemy)
		enemy.free()
	run.turns.enemies.clear()
	run.dungeon.grid.size = Vector2i(8, 8)
	run.dungeon.grid.walls.clear()
	run.dungeon.grid.occupants.clear()
	run.dungeon.grid.place(run.turns.player, Vector2i(2, 2))
	run.dungeon.stairs_cell = Vector2i(3, 2)
	var enemy := ENEMY.instantiate()
	run.dungeon.get_node("Actors").add_child(enemy)
	run.dungeon.grid.place(enemy, Vector2i(4, 2))
	run.turns.enemies.append(enemy)
	run._refresh()


func test_stair_combat() -> void:
	var run := new_run()
	arrange_stair_fight(run)
	var old_enemy: Node2D = run.turns.enemies[0]
	run.turns.submit("move", Vector2i.RIGHT)
	check(run.floor_number == 2 and run.turns.player.hp == 21, "Old enemy attacks before stairs")
	check(old_enemy.is_queued_for_deletion() and old_enemy.get_parent() == null, "Old enemies detached and released")
	var fresh := true
	for enemy: Node2D in run.turns.enemies:
		fresh = fresh and enemy.hp == enemy.stats.max_hp and enemy.cell in run.dungeon.enemy_cells
	check(fresh and run.turns.enemies.size() == 2, "New enemies have not acted")
	check(run.dungeon.grid.occupants.size() == 3 and run.dungeon.get_node("Actors").get_child_count() == 3, "No stale occupancy or actors")
	run.free()
	run = new_run()
	arrange_stair_fight(run)
	run.turns.player.hp = 3
	run.turns.submit("move", Vector2i.RIGHT)
	check(run.floor_number == 1 and run.turns.ended and run.turns.player.hp == 0, "Death prevents descent")
	check(not run.turns.submit("move", Vector2i.LEFT), "Dead player cannot leave stairs")
	run.free()


func run_tests() -> void:
	test_generation()
	test_terrain_art()
	test_ten_floors()
	test_stair_combat()
	print("Dungeon tests: %d maps, %d checks, %d failures" % [map_count, checks, failures])
	quit(0 if failures == 0 else 1)
