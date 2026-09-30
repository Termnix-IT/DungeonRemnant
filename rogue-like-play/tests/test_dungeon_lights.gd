extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func run_tests() -> void:
	var lights := preload("res://world/dungeon/dungeon_lights.gd").new()
	root.add_child(lights)
	var grid := GridState.new()
	grid.size = Vector2i(40, 40)
	var visible_cells: Dictionary = {}
	for x in 40:
		for y in 40:
			visible_cells[Vector2i(x, y)] = true
			# A wall row every fourth line faces open floor below it.
			if y % 4 == 0:
				grid.walls[Vector2i(x, y)] = true
	grid.walls[Vector2i(0, 1)] = true
	grid.pillars[Vector2i(0, 1)] = true
	seed(4411)
	var expected_random := randi()
	seed(4411)
	lights.refresh(grid, visible_cells, Vector2i(5, 5), true, false, 0)
	check(randi() == expected_random, "Placing torches preserves global gameplay RNG")
	check(not lights.torches.is_empty() and lights.torches.size() <= lights.MAX_TORCHES, "Torches appear within their budget")
	var all_valid := true
	for cell: Vector2i in lights.torches:
		all_valid = all_valid and grid.walls.has(cell) and not grid.pillars.has(cell) and grid.is_floor(cell + Vector2i.DOWN) and visible_cells.has(cell)
	check(all_valid, "Torches hang only on visible wall faces above floor")
	check(lights.stairs == Vector2i(5, 5), "Visible stairs receive their light")
	var calm := true
	for frame in 200:
		lights._phase = frame * 0.07
		for cell: Vector2i in lights.torches:
			var strength: float = lights.flicker(cell)
			calm = calm and strength >= 0.7 and strength <= 1.0
	check(calm, "Flicker stays within a gentle range")
	var first := lights.torches.duplicate()
	lights.refresh(grid, visible_cells, Vector2i(5, 5), true, false, 0)
	check(lights.torches == first, "Torch placement is stable between refreshes")
	lights.refresh(grid, visible_cells, Vector2i(5, 5), true, false, 2)
	check(lights.light_color == lights.THEME_LIGHTS[2], "Each depth band has its own light colour")
	lights.refresh(grid, visible_cells, Vector2i(5, 5), true, true, 1)
	check(lights.torches.is_empty(), "The forest has no wall torches")
	lights.refresh(grid, visible_cells, Vector2i(5, 5), false, false, 0)
	check(lights.stairs.x < 0, "Final floors have no stairs light")
	lights.refresh(grid, {}, Vector2i(5, 5), true, false, 0)
	check(lights.torches.is_empty() and lights.stairs.x < 0 and not lights.is_processing(), "Hidden cells clear every light")
	lights.refresh(grid, visible_cells, Vector2i(5, 5), true, false, 0)
	lights.hide()
	var paused: float = lights._phase
	await create_timer(0.04).timeout
	check(not lights.is_processing() and lights._phase == paused, "Hidden lights stop animating")
	lights.show()
	check(lights.is_processing(), "Shown lights resume")
	var glow: Node2D = lights.get_node("Glow")
	check((glow.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "Glow brightens the floor additively")
	lights.refresh(null, {}, Vector2i.ZERO, false, false, 0)
	check(not lights.is_processing(), "Floor teardown clears without a grid")

	var dungeon := preload("res://world/dungeon/dungeon.tscn").instantiate()
	root.add_child(dungeon)
	var order: Array[String] = []
	for child in dungeon.get_children():
		order.append(child.name)
	check(order.find("Lights") > order.find("Terrain") and order.find("Lights") < order.find("Items") and order.find("Lights") < order.find("Actors"), "Light sits above terrain and under items and actors")
	check(order.find("Mist") == 0 and order.find("ExploredTerrain") == 1, "Unexplored mist sits under every terrain layer")
	var mist: Node2D = dungeon.get_node("Mist")
	check(mist.material is ShaderMaterial, "The mist drifts in a shader")
	seed(7301)
	var expected_mist_random := randi()
	seed(7301)
	mist.refresh(Vector2i(30, 20), false, 2)
	check(randi() == expected_mist_random, "The mist consumes no gameplay RNG")
	var map_rect := Rect2(Vector2.ZERO, Vector2(30, 20) * 48.0)
	check(mist.area.encloses(map_rect.grow(15 * 48.0)), "The mist reaches well past the map edge")
	check(mist.tint == mist.THEME_TINTS[2], "The mist takes the terrain theme's colour")
	mist.refresh(Vector2i(30, 20), true, 1)
	check(mist.tint == mist.FOREST_TINT, "The forest has its own green mist")
	var actors: Node2D = dungeon.get_node("Actors")
	check(actors.y_sort_enabled, "Actors on lower rows are drawn in front")
	var hero_script := GDScript.new()
	hero_script.source_code = "extends Node2D\nvar cell := Vector2i.ZERO\n"
	hero_script.reload()
	var hero := Node2D.new()
	hero.set_script(hero_script)
	actors.add_child(hero)
	hero.cell = Vector2i(3, 3)
	var beside := preload("res://actors/enemy/enemy.tscn").instantiate()
	actors.add_child(beside)
	beside.cell = Vector2i(4, 3)
	dungeon.sync_actors()
	check(hero.get_index() > beside.get_index(), "On the same row the hero is drawn over an enemy beside her")
	dungeon.queue_free()
	lights.queue_free()
	await process_frame
	print("Dungeon lights: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
