extends SceneTree

# Rubble, crates and pools: what each stops, the crate breaking, and where
# the generator puts them.

const BattlePresentation := preload("res://combat/battle_presentation.gd")

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func open_grid() -> GridState:
	var grid := GridState.new()
	grid.size = Vector2i(9, 5)
	for y in grid.size.y:
		for x in grid.size.x:
			if x == 0 or y == 0 or x == grid.size.x - 1 or y == grid.size.y - 1:
				grid.walls[Vector2i(x, y)] = true
	return grid


func run_tests() -> void:
	var grid := open_grid()
	var origin := Vector2i(1, 2)
	for kind: StringName in GridState.OBSTACLES:
		grid.obstacles.clear()
		grid.obstacles[Vector2i(3, 2)] = kind
		check(not grid.can_step(Vector2i(2, 2), Vector2i(3, 2)) and not grid.is_open(Vector2i(3, 2)), "%s cannot be walked through" % kind)
		var actor := Node2D.new()
		check(not grid.place(actor, Vector2i(3, 2)), "Nothing stands on %s" % kind)
		actor.free()
	# Sight: rubble and water are seen over, a crate hides what is behind it.
	grid.obstacles = {Vector2i(3, 2): GridState.RUBBLE}
	check(LineOfSight.can_see(grid, origin, Vector2i(6, 2)), "Rubble is seen over")
	grid.obstacles = {Vector2i(3, 2): GridState.WATER}
	check(LineOfSight.can_see(grid, origin, Vector2i(6, 2)), "Water is seen over")
	grid.obstacles = {Vector2i(3, 2): GridState.CRATE}
	check(not LineOfSight.can_see(grid, origin, Vector2i(6, 2)) and LineOfSight.can_see(grid, origin, Vector2i(3, 2)), "A crate is seen, but hides what is behind it")
	# Attacks: over water, not past rubble, onto a crate.
	grid.obstacles = {Vector2i(2, 2): GridState.WATER}
	check(Array(CombatRules.ray_cells(grid, origin, Vector2i.RIGHT, 3)) == [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)], "A thrust passes over water")
	grid.obstacles = {Vector2i(3, 2): GridState.RUBBLE}
	check(Array(CombatRules.ray_cells(grid, origin, Vector2i.RIGHT, 3)) == [Vector2i(2, 2)], "Rubble stops a thrust before it")
	grid.obstacles = {Vector2i(3, 2): GridState.CRATE}
	check(Array(CombatRules.ray_cells(grid, origin, Vector2i.RIGHT, 3)) == [Vector2i(2, 2), Vector2i(3, 2)], "A thrust ends on a crate")
	# Striking the crate breaks it and reports the splinters.
	grid.obstacles = {Vector2i(2, 2): GridState.CRATE}
	var attacker := preload("res://actors/enemy/enemy.tscn").instantiate()
	root.add_child(attacker)
	grid.place(attacker, origin)
	CombatRules.attack(grid, attacker, Vector2i.RIGHT)
	var breaks := grid.visual_events.filter(func(event: Dictionary): return event.kind == "break")
	check(not grid.obstacles.has(Vector2i(2, 2)) and breaks.size() == 1 and breaks[0].cell == Vector2i(2, 2) and grid.is_open(Vector2i(2, 2)), "A struck crate breaks and frees its cell")
	grid.visual_events.clear()
	grid.obstacles = {Vector2i(2, 2): GridState.RUBBLE}
	CombatRules.attack(grid, attacker, Vector2i.RIGHT)
	check(grid.obstacles.has(Vector2i(2, 2)), "Rubble does not break")
	# The presentation lets the crate go when the blow lands, not before.
	var presentation := BattlePresentation.new()
	root.add_child(presentation)
	var broken: Array[Vector2i] = []
	presentation.obstacle_broken.connect(func(cell: Vector2i): broken.append(cell))
	var seen := {origin: true, Vector2i(2, 2): true}
	var events: Array[Dictionary] = [
		{"kind": "attack", "actor": attacker, "origin": origin, "direction": Vector2i.RIGHT, "weapon": null, "cells": [Vector2i(2, 2)]},
		{"kind": "break", "cell": Vector2i(2, 2), "obstacle": GridState.CRATE}]
	var watcher := Node2D.new()
	root.add_child(watcher)
	presentation.present(events, watcher, seen, 48)
	check(broken.is_empty(), "A struck crate is still shown as the blow begins")
	await create_timer(BattlePresentation._impact_delay(null) + 0.1).timeout
	check(broken == [Vector2i(2, 2)], "It splinters when the blow lands")
	if presentation.playing:
		await presentation.finished
	var unseen: Array[Dictionary] = [{"kind": "break", "cell": Vector2i(6, 2), "obstacle": GridState.CRATE}]
	presentation.present(unseen, watcher, {}, 48)
	check(broken.has(Vector2i(6, 2)), "A crate broken out of sight goes at once")
	# Out of the finished signal before the presentation goes.
	await process_frame
	presentation.free()
	watcher.free()
	attacker.free()
	# Generation: rooms get obstacles that never touch each other or a kept
	# cell, and every open floor stays reachable from the start.
	var settings: DungeonSettings = preload("res://data/dungeon/default.tres").duplicate()
	var rng := RandomNumberGenerator.new()
	var placed := 0
	for seed_value in range(1, 31):
		rng.seed = seed_value
		var data := DungeonGenerator.generate(settings, seed_value % 9 + 1, rng)
		var map: GridState = data.grid
		placed += map.obstacles.size()
		var reached := LayoutUtils.distances(map, data.start)
		var open := 0
		for y in map.size.y:
			for x in map.size.x:
				if map.is_open(Vector2i(x, y)):
					open += 1
		check(reached.size() == open, "Seed %d: every open floor is reachable past the obstacles" % seed_value)
		var apart := true
		for cell: Vector2i in map.obstacles:
			for direction in LayoutUtils.DIRECTIONS:
				apart = apart and map.is_open(cell + direction)
			for kept: Vector2i in [data.start, data.stairs] + data.enemies:
				apart = apart and maxi(absi(kept.x - cell.x), absi(kept.y - cell.y)) > 1
			apart = apart and not (data.house.has_area() and data.house.grow(1).has_point(cell))
		check(apart, "Seed %d: obstacles stand in the open, clear of each other and kept cells" % seed_value)
	check(placed > 30 * 4, "Floors get obstacles (%d over 30 floors)" % placed)
	var fixed := DungeonGenerator.generate(settings, 10, rng, false, DungeonGenerator.Kind.BOSS_HALL)
	check((fixed.grid as GridState).obstacles.is_empty(), "The boss hall has none")
	# The same layout always gets the same obstacles.
	rng.seed = 5
	var first: Dictionary = DungeonGenerator.generate(settings, 3, rng).grid.obstacles
	rng.seed = 5
	var second: Dictionary = DungeonGenerator.generate(settings, 3, rng).grid.obstacles
	check(first == second and not first.is_empty(), "Obstacles follow the layout's seed")
	print("Obstacle tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
