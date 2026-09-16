extends SceneTree

const SPAWNER := preload("res://game/run/reinforcement_spawner.gd")
const ENEMY := preload("res://actors/enemy/enemy.tscn")
var checks := 0
var failures := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _initialize() -> void:
	var grid := GridState.new()
	grid.size = Vector2i(20, 20)
	var settings := DungeonSettings.new()
	settings.reinforcement_chance = 1.0
	settings.reinforcement_total_cap = 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 304
	var spawner := SPAWNER.new()
	var player := Vector2i(2, 2)
	var stairs := Vector2i(18, 18)
	spawner.reset(100)
	check(spawner.try_spawn(grid, player, {}, [], stairs, settings, 117, 1, rng) == SPAWNER.NO_CELL, "Interval starts at floor arrival")
	var cell := spawner.try_spawn(grid, player, {}, [], stairs, settings, 118, 1, rng)
	check(cell != SPAWNER.NO_CELL and not LineOfSight.in_range(player, cell, 5), "Spawn is distant")
	check(spawner.try_spawn(grid, player, {}, [], stairs, settings, 118, 1, rng) == SPAWNER.NO_CELL, "Same turn never repeats")
	check(spawner.try_spawn(grid, player, {}, [], stairs, settings, 136, 1, rng) != SPAWNER.NO_CELL, "Next interval allows another spawn")
	check(spawner.try_spawn(grid, player, {}, [], stairs, settings, 154, 1, rng) == SPAWNER.NO_CELL, "Total floor cap applies")
	spawner.reset(154)
	check(spawner.spawned_count == 0, "New floor resets quota")
	check(spawner.try_spawn(grid, player, {}, [], stairs, settings, 172, 10, rng) == SPAWNER.NO_CELL, "Boss floor never spawns")
	var enemy := ENEMY.instantiate()
	enemy.hp = 1
	settings.reinforcement_alive_cap = 1
	check(spawner.try_spawn(grid, player, {}, [enemy], stairs, settings, 172, 1, rng) == SPAWNER.NO_CELL, "Alive cap prevents spawn")
	enemy.hp = 0
	check(spawner.try_spawn(grid, player, {}, [enemy], stairs, settings, 190, 1, rng) != SPAWNER.NO_CELL, "Dead enemies do not count toward alive cap")
	enemy.free()
	spawner.reset(0)
	settings.reinforcement_chance = 0.0
	check(spawner.try_spawn(grid, player, {}, [], stairs, settings, 18, 1, rng) == SPAWNER.NO_CELL, "Zero probability disables spawn")
	settings.reinforcement_chance = 1.0
	check(spawner.try_spawn(grid, player, {}, [], stairs, settings, 18, 1, rng) == SPAWNER.NO_CELL, "Failed roll consumes interval")
	# Make all but one reachable tile ineligible and an isolated tile tempting.
	grid = LayoutUtils.solid_grid(Vector2i(20, 20))
	LayoutUtils.carve_rect(grid, Rect2i(1, 1, 17, 2))
	grid.walls.erase(Vector2i(18, 18))
	var visible := LayoutUtils.distances(grid, player)
	var valid := Vector2i(12, 1)
	var item_cell := Vector2i(13, 1)
	var occupied := Vector2i(14, 1)
	stairs = Vector2i(15, 1)
	for hidden: Vector2i in [valid, item_cell, occupied, stairs]:
		visible.erase(hidden)
	grid.occupants[occupied] = true
	var items := {item_cell: true}
	spawner.reset(0)
	check(spawner.try_spawn(grid, player, visible, [], stairs, settings, 18, 1, rng, items) == valid, "Spawn excludes visible, occupied, item, stairs and unreachable cells")
	visible[valid] = true
	spawner.reset(0)
	check(spawner.try_spawn(grid, player, visible, [], stairs, settings, 18, 1, rng, items) == SPAWNER.NO_CELL, "No safe cell returns no spawn")
	check(spawner.spawned_count == 0, "No safe cell does not consume quota")
	print("Reinforcement tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
