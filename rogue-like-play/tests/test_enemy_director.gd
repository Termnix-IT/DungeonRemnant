extends SceneTree

# The EnemyDirector over a CombatArea: how many foes it aims for as time goes
# on and its cap, the rate it brings them in, where they appear (open ground
# outside the camera's view), which kinds its table opens at which time,
# the elites' schedule and cap, the fixed trial count, and a hall too small
# to hide a spawn in. The director is advanced by hand, without physics
# frames between, so each foe still stands where it appeared.

const FRAME := 1.0 / 60.0
var failures := 0
var checks := 0
var sentinel: FoeData
var rat: FoeData
var charger: FoeData


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func make_area(size: Vector2i) -> CombatArea:
	var area := CombatArea.new()
	root.add_child(area)
	var walls := {}
	for x in size.x:
		walls[Vector2i(x, 0)] = true
		walls[Vector2i(x, size.y - 1)] = true
	for y in size.y:
		walls[Vector2i(0, y)] = true
		walls[Vector2i(size.x - 1, y)] = true
	area.ground.build(size, walls)
	var hero := area.spawn_hero(area.ground.bounds().get_center())
	hero.controlled = false
	return area


func make_table() -> SpawnTable:
	var table := SpawnTable.new()
	var always := SpawnEntry.new()
	always.foe = sentinel
	var window := SpawnEntry.new()
	window.foe = rat
	window.from_time = 10.0
	window.until_time = 20.0
	table.entries.assign([always, window])
	table.start_alive = 5
	table.alive_per_minute = 60.0
	table.max_alive = 20
	table.spawns_per_second = 10.0
	table.elite = charger
	table.elite_first = 5.0
	table.elite_every = 10.0
	table.elite_cap = 1
	return table


func advance(director: EnemyDirector, seconds: float) -> void:
	for index in roundi(seconds / FRAME):
		director.advance(FRAME)


func run_tests() -> void:
	sentinel = load("res://data/foes/wandering_sentinel.tres")
	rat = load("res://data/foes/dashing_rat.tres")
	charger = load("res://data/foes/raging_charger.tres")
	var area := make_area(Vector2i(64, 44))
	await process_frame
	var table := make_table()
	check(table.alive_at(0.0) == 5 and table.alive_at(3.0) == 8 and table.alive_at(600.0) == 20, "The aim grows with time up to its cap")
	var director := EnemyDirector.new()
	director.start(area, table, 9)
	check(director.target_alive() == 5, "The director starts at the table's first aim")
	advance(director, 0.05)
	check(area.foes.is_empty(), "Foes come in at the table's rate, not all at once")
	advance(director, 0.25)
	check(area.foes.size() >= 2 and area.foes.size() <= 4, "Some come in within a fraction of a second")
	advance(director, 1.0)
	check(area.foes.size() == director.target_alive(), "The director fills up to its aim")
	var view := area.view_rect().grow(EnemyDirector.VIEW_MARGIN)
	var bounds := area.ground.bounds()
	var placed_well := true
	for foe in area.foes:
		if view.has_point(foe.global_position) or not bounds.has_point(foe.global_position) or not area.ground.is_open(foe.global_position, 10.0):
			placed_well = false
	check(placed_well, "Foes appear on open ground outside the camera's view")
	check(area.foes.all(func(foe: Foe): return foe.data == sentinel), "Before the rats' time, only sentinels come")

	# The table's windows: rats only between 10 s and 20 s.
	var kinds := {}
	director.elapsed = 12.0
	for draw in 200:
		kinds[director.pick()] = true
	check(kinds.has(sentinel) and kinds.has(rat), "Inside a window both kinds are picked")
	kinds.clear()
	director.elapsed = 25.0
	for draw in 200:
		kinds[director.pick()] = true
	check(kinds.size() == 1 and kinds.has(sentinel), "After its window a kind is no longer picked")

	# Elites: the first at elite_first, then every elite_every, never past the cap.
	area.free()
	area = make_area(Vector2i(64, 44))
	await process_frame
	director = EnemyDirector.new()
	director.start(area, table, 4)
	advance(director, 4.9)
	check(director.elites_alive() == 0, "No elite before its first time")
	advance(director, 0.2)
	check(director.elites_alive() == 1, "The first elite comes at its time")
	advance(director, 10.0)
	check(director.elites_alive() == 1, "No elite beyond the cap while one stands")
	check(area.foes.size() >= director.target_alive(), "The crowd keeps up with the growing aim")
	advance(director, 60.0)
	check(area.foes.size() <= table.max_alive + table.elite_cap, "The crowd stops at the table's cap")

	# A fixed trial count overrides the aim, fills faster and sends no elites.
	area.free()
	area = make_area(Vector2i(64, 44))
	await process_frame
	director = EnemyDirector.new()
	director.start(area, table, 6)
	director.fixed_alive = 30
	advance(director, 1.0)
	check(area.foes.size() == 30, "A fixed count is filled, past the table's cap, at four times the rate")
	advance(director, 10.0)
	check(director.elites_alive() == 0 and area.foes.size() == 30, "A fixed count holds and sends no elites")

	# Nothing more comes once the hero is down.
	var elapsed := director.elapsed
	area.hero.health.hp = 0
	director.fixed_alive = 40
	advance(director, 1.0)
	check(director.elapsed == elapsed and area.foes.size() == 30, "The director stops while the hero is down")

	# A hall the camera shows whole has nowhere to hide a spawn.
	area.free()
	area = make_area(Vector2i(12, 10))
	await process_frame
	director = EnemyDirector.new()
	director.start(area, table, 3)
	check(director.spawn_point() == Vector2.INF, "With no ground out of view, no point is found")
	advance(director, 1.0)
	check(area.foes.is_empty(), "And nothing is spawned in plain sight")
	area.hit_stop.release()
	await process_frame
	area.free()
	await process_frame

	print("Enemy director tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
