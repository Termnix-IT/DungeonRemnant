extends SceneTree

const PLAYER := preload("res://actors/player/player.tscn")
const ENEMY := preload("res://actors/enemy/enemy.tscn")
const RUN := preload("res://game/run/run.tscn")
const PROXIMITY := preload("res://data/enemies/proximity_enemy.tres")
const TURRET := preload("res://data/enemies/turret_enemy.tres")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func test_los_and_fog() -> void:
	var grid := GridState.new()
	grid.size = Vector2i(24, 24)
	var center := Vector2i(10, 10)
	for direction in LayoutUtils.DIRECTIONS:
		check(LineOfSight.can_see(grid, center, center + direction * 8), "Open sight in eight directions")
		check(LineOfSight.in_range(center, center + direction * 8, 8), "Inclusive grid radius")
		check(not LineOfSight.in_range(center, center + direction * 9, 8), "Beyond grid radius")
	check(not LineOfSight.can_see(grid, center, Vector2i(-1, 0)), "Bounds reject sight")
	grid.walls[Vector2i(11, 10)] = true
	check(LineOfSight.can_see(grid, center, Vector2i(11, 10)), "Blocking wall itself visible")
	check(not LineOfSight.can_see(grid, center, Vector2i(12, 10)), "Wall hides cells behind it")
	check(not LineOfSight.can_see(grid, center, Vector2i(11, 11)), "Single side wall blocks diagonal")
	check(not LineOfSight.can_see(grid, Vector2i(11, 11), center), "Reverse corner also blocked")
	grid.walls.clear()
	grid.walls[Vector2i(12, 11)] = true
	check(not LineOfSight.can_see(grid, center, Vector2i(12, 12)), "Second diagonal corner blocked")
	grid.walls.clear()
	grid.walls[Vector2i(11, 10)] = true
	grid.pillars[Vector2i(11, 10)] = true
	check(not grid.can_step(center, Vector2i(11, 10)), "Pillar blocks movement")
	check(not LineOfSight.can_see(grid, center, Vector2i(12, 10)), "Pillar blocks vision")
	check(CombatRules.ray_cells(grid, center, Vector2i.RIGHT, 4).is_empty(), "Pillar blocks attacks")
	var fog := FogOfWar.new()
	fog.update(grid, center, 3)
	check(fog.visible.has(center) and fog.visible.has(Vector2i(11, 10)), "Origin and wall visible")
	check(not fog.explored.has(Vector2i(12, 10)) and not fog.explored.has(Vector2i(20, 20)), "Occluded and distant terrain unexplored")
	fog.update(grid, Vector2i(20, 20), 2)
	check(fog.explored.has(center) and not fog.visible.has(center), "Explored history persists outside vision")
	fog.reset()
	check(fog.visible.is_empty() and fog.explored.is_empty(), "Floor reset clears all fog state")
	# Check reciprocity on arbitrary slopes, not only the eight attack directions.
	var rng := RandomNumberGenerator.new()
	rng.seed = 614
	grid.pillars.clear()
	for index in 70:
		grid.walls[Vector2i(rng.randi_range(0, 23), rng.randi_range(0, 23))] = true
	for index in 300:
		var a := Vector2i(rng.randi_range(0, 23), rng.randi_range(0, 23))
		var b := Vector2i(rng.randi_range(0, 23), rng.randi_range(0, 23))
		if grid.is_floor(a) and grid.is_floor(b):
			check(LineOfSight.can_see(grid, a, b) == LineOfSight.can_see(grid, b, a), "Reciprocal floor-to-floor sight")


func relocate(grid: GridState, actor: Node2D, cell: Vector2i) -> void:
	grid.remove_actor(actor)
	check(grid.place(actor, cell), "Test actor placed")


func test_detection() -> void:
	var grid := GridState.new()
	grid.size = Vector2i(24, 24)
	var player := PLAYER.instantiate()
	var enemy := ENEMY.instantiate()
	root.add_child(player)
	root.add_child(enemy)
	grid.place(enemy, Vector2i(2, 2))
	grid.place(player, Vector2i(10, 2))
	enemy.take_turn(grid, player)
	check(enemy.cell == Vector2i(2, 2) and enemy.last_seen_cell == Vector2i(-1, -1), "Vision enemy idle before detection")
	relocate(grid, player, Vector2i(5, 2))
	grid.walls[Vector2i(3, 2)] = true
	check(not enemy.detects(grid, player.cell), "Vision detection blocked by wall")
	enemy.take_turn(grid, player)
	check(enemy.cell == Vector2i(2, 2), "Hidden target does not wake vision enemy")
	grid.walls.clear()
	enemy.take_turn(grid, player)
	check(enemy.cell == Vector2i(3, 2) and enemy.last_seen_cell == Vector2i(5, 2), "Detection records target and approaches")
	relocate(grid, player, Vector2i(18, 18))
	enemy.take_turn(grid, player)
	check(enemy.cell == Vector2i(4, 2), "Lost target: continue to last seen cell")
	enemy.take_turn(grid, player)
	check(enemy.cell == Vector2i(5, 2) and enemy.last_seen_cell == Vector2i(-1, -1), "Stops at last seen location")
	enemy.take_turn(grid, player)
	check(enemy.cell == Vector2i(5, 2), "No omniscient pursuit after search")
	relocate(grid, player, Vector2i(5, 5))
	enemy.take_turn(grid, player)
	check(enemy.cell == Vector2i(5, 3) and enemy.last_seen_cell == Vector2i(5, 5), "Can reacquire target")
	enemy.stats = PROXIMITY
	relocate(grid, enemy, Vector2i(2, 2))
	relocate(grid, player, Vector2i(5, 2))
	grid.walls[Vector2i(3, 2)] = true
	check(enemy.detects(grid, player.cell), "Proximity detects through wall")
	enemy.take_turn(grid, player)
	check(enemy.cell != Vector2i(2, 2) and grid.is_floor(enemy.cell) and player.hp == 24, "Proximity moves around wall without attacking through it")
	var stopped: Vector2i = enemy.cell
	relocate(grid, player, Vector2i(18, 18))
	enemy.take_turn(grid, player)
	check(enemy.cell == stopped, "Proximity stops outside range")
	grid.walls.clear()
	enemy.stats = TURRET
	relocate(grid, enemy, Vector2i(4, 4))
	relocate(grid, player, Vector2i(4, 1))
	enemy.visible = false
	check(enemy.take_turn(grid, player) == 0 and player.hp == 24 and enemy.shot_direction == Vector2i.UP, "Turret warns before its first shot")
	check(enemy.take_turn(grid, player) == 3 and player.hp == 21, "Turret fires independently of display visibility")
	check(enemy.take_turn(grid, player) == 0 and player.hp == 21, "Turret must warn again after firing")
	check(enemy.cell == Vector2i(4, 4), "Turret stays fixed")
	relocate(grid, player, Vector2i(1, 1))
	check(enemy.take_turn(grid, player) == 0, "Changing firing direction requires a fresh warning")
	check(enemy.take_turn(grid, player) == 3, "Turret can fire diagonally")
	relocate(grid, player, Vector2i(1, 2))
	check(enemy.take_turn(grid, player) == 0, "Turret cannot fire off the eight axes")
	relocate(grid, player, Vector2i(4, 9))
	check(enemy.take_turn(grid, player) == 0 and enemy.cell == Vector2i(4, 4), "Turret range limit and no chase")
	relocate(grid, player, Vector2i(4, 1))
	grid.walls[Vector2i(4, 3)] = true
	check(enemy.take_turn(grid, player) == 0, "Wall blocks turret")
	grid.pillars[Vector2i(4, 3)] = true
	check(enemy.take_turn(grid, player) == 0, "Pillar blocks turret")
	grid.walls.clear()
	grid.pillars.clear()
	var blocker := ENEMY.instantiate()
	root.add_child(blocker)
	grid.place(blocker, Vector2i(4, 2))
	check(enemy.take_turn(grid, player) == 0 and blocker.hp == 8, "Another enemy shields player without friendly fire")
	check(LineOfSight.can_see(grid, enemy.cell, player.cell), "Actors do not block terrain vision")
	grid.remove_actor(blocker)
	blocker.free()
	relocate(grid, player, Vector2i(1, 1))
	grid.walls[Vector2i(3, 4)] = true
	check(enemy.take_turn(grid, player) == 0, "Turret cannot shoot through diagonal corner")
	player.free()
	enemy.free()


func test_turret_counterplay() -> void:
	var run := RUN.instantiate()
	run.dungeon_settings = DungeonSettings.new()
	run.dungeon_settings.enemy_count = 0
	run.dungeon_settings.item_count = 0
	run.generation_seed = 47
	root.add_child(run)
	var grid: GridState = run.dungeon.grid
	grid.walls.clear()
	grid.pillars.clear()
	grid.occupants.clear()
	run.dungeon.has_stairs = false
	var player: Node2D = run.turns.player
	grid.place(player, Vector2i(4, 1))
	var enemy := ENEMY.instantiate()
	enemy.stats = TURRET
	run.dungeon.get_node("Actors").add_child(enemy)
	grid.place(enemy, Vector2i(4, 4))
	run.turns.enemies.append(enemy)
	run.turns.submit("attack", Vector2i.UP)
	check(player.hp == 24 and enemy.shot_direction == Vector2i.UP, "First world action produces a warning, not damage")
	run._on_action("switch", Vector2i.UP)
	check(player.hp == 24 and run.turns.turn_count == 1 and enemy.shot_direction == Vector2i.UP, "Free weapon switch does not advance a pending shot")
	run.turns.submit("move", Vector2i.RIGHT)
	check(player.hp == 24 and enemy.shot_direction == Vector2i.ZERO, "One sideways movement dodges and cancels the shot")
	run.turns.submit("move", Vector2i.LEFT)
	check(player.hp == 24 and enemy.shot_direction == Vector2i.UP, "Returning to the ray requires a new warning")
	run.turns.submit("move", Vector2i.DOWN)
	check(player.hp == 21 and enemy.shot_direction == Vector2i.ZERO, "Moving closer along the warned ray does not dodge")
	run.turns.submit("attack", Vector2i.UP)
	check(player.hp == 21 and enemy.shot_direction == Vector2i.UP, "Shot is followed by a full warning turn")
	grid.walls[Vector2i(4, 3)] = true
	check(enemy.take_turn(grid, player) == 0 and enemy.shot_direction == Vector2i.ZERO, "Cover appearing after warning cancels shot")
	grid.walls.clear()
	check(enemy.take_turn(grid, player) == 0, "Removing cover requires a new warning")
	var blocker := ENEMY.instantiate()
	run.dungeon.get_node("Actors").add_child(blocker)
	grid.place(blocker, Vector2i(4, 3))
	check(enemy.take_turn(grid, player) == 0 and enemy.shot_direction == Vector2i.ZERO and blocker.hp == 8, "Actor entering warned ray cancels shot without friendly fire")
	grid.remove_actor(blocker)
	blocker.free()
	enemy.take_turn(grid, player)
	relocate(grid, enemy, Vector2i(4, 5))
	check(enemy.take_turn(grid, player) == 0 and enemy.shot_origin == enemy.cell, "Displaced turret must warn from its new position")
	relocate(grid, player, Vector2i(20, 20))
	check(enemy.take_turn(grid, player) == 0 and enemy.shot_direction == Vector2i.ZERO, "Leaving range clears pending shot")
	run.free()


func test_scene_visibility() -> void:
	var run := RUN.instantiate()
	run.generation_seed = 47
	run.dungeon_settings = DungeonSettings.new()
	run.dungeon_settings.enemy_count = 0
	root.add_child(run)
	var grid: GridState = run.dungeon.grid
	grid.size = Vector2i(24, 24)
	grid.walls.clear()
	grid.pillars.clear()
	run.dungeon.fog.reset()
	run.dungeon.get_node("ExploredTerrain").clear()
	relocate(grid, run.turns.player, Vector2i(4, 4))
	var enemy := ENEMY.instantiate()
	run.dungeon.get_node("Actors").add_child(enemy)
	grid.place(enemy, Vector2i(6, 4))
	run.turns.enemies.append(enemy)
	run._refresh()
	check(enemy.visible, "Enemy visible in current field of view")
	check(run.hud.minimap.player_cell == run.turns.player.cell, "HUD minimap tracks player position")
	check(run.hud.minimap.enemy_cells.has(enemy.cell), "HUD minimap shows only visible enemies")
	grid.walls[Vector2i(5, 4)] = true
	grid.pillars[Vector2i(5, 4)] = true
	run._refresh()
	check(not enemy.visible and run.dungeon.fog.explored.has(enemy.cell), "Remembered enemy cell hides actor")
	check(not run.hud.minimap.enemy_cells.has(enemy.cell), "HUD minimap does not reveal hidden enemies")
	check(run.dungeon.get_node("Terrain").get_cell_source_id(enemy.cell) == -1, "Occluded tile removed from bright layer")
	check(run.dungeon.get_node("ExploredTerrain").get_cell_source_id(enemy.cell) == 0, "Remembered terrain retained")
	check(run.dungeon.get_node("Terrain").get_cell_atlas_coords(Vector2i(5, 4)) == Vector2i(run.dungeon.PILLAR_TILE, 0), "Pillar uses distinct tile")
	check(run.dungeon.get_node("ExploredTerrain").get_cell_source_id(Vector2i(23, 23)) == -1, "Unexplored map not rendered")
	check(run.hud.status.text.contains("視界内の敵 0"), "HUD does not reveal hidden enemy count")
	grid.walls.clear()
	grid.pillars.clear()
	run.turns.player.vision_range = 1
	run.turns.player.weapon = preload("res://data/weapons/spear.tres")
	run.turns.player.aiming = true
	run.turns.player.facing = Vector2i.RIGHT
	run._refresh()
	check(run.preview.cells == [Vector2i(5, 4)], "Preview clips cells outside current sight")
	check(not enemy.visible, "Enemy hidden beyond reduced vision radius")
	run.turns.player.vision_range = 8
	run._refresh()
	check(enemy.visible, "Enemy reappears when sight restored")
	enemy.hp = 0
	run._refresh()
	check(not enemy.visible, "Dead enemy stays hidden in sight")
	run.dungeon.fog.explored[Vector2i(-1, -1)] = true
	run.floor_number = 2
	run._load_floor()
	check(run.dungeon.fog.visible.is_empty() and run.dungeon.fog.explored.is_empty(), "New floor clears previous exploration")
	check(run.dungeon.get_node("ExploredTerrain").get_used_cells().is_empty(), "New floor clears remembered tile layer")
	run._refresh()
	check(run.dungeon.fog.visible.has(run.turns.player.cell), "New floor reveals starting view")
	run.free()
	# Three enemies per floor rotate through all three behavior resources.
	run = RUN.instantiate()
	run.generation_seed = 47
	root.add_child(run)
	for floor_value in range(1, 11):
		run.floor_number = floor_value
		run._load_floor()
		check(run.turns.enemies.size() == (4 if floor_value == 10 else 3), "Three regular enemies per floor plus final boss")
		for index in 3:
			check(run.turns.enemies[index].stats.detection == (floor_value - 1 + index) % 3, "Floor composition rotates through three enemy types")
	run.floor_number = 3
	run._load_floor()
	check(not run.dungeon.grid.pillars.is_empty(), "OpenArea generates pillars")
	var pillars_valid := true
	for cell: Vector2i in run.dungeon.grid.pillars:
		pillars_valid = pillars_valid and run.dungeon.grid.walls.has(cell) and not run.dungeon.grid.is_floor(cell)
	check(pillars_valid, "Generated pillars consistently block movement")
	run.free()


func run_tests() -> void:
	test_los_and_fog()
	test_detection()
	test_turret_counterplay()
	test_scene_visibility()
	print("Exploration tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
