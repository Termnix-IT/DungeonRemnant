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
	var ambient := preload("res://world/dungeon/ambient_details.gd").new()
	root.add_child(ambient)
	var grid := GridState.new()
	grid.size = Vector2i(40, 40)
	var visible_cells: Dictionary = {}
	for x in 40:
		for y in 40:
			visible_cells[Vector2i(x, y)] = true
	grid.walls[Vector2i.ZERO] = true
	seed(715)
	var expected_random := randi()
	seed(715)
	ambient.refresh(grid, visible_cells, Vector2i(1, 1), true, Vector2i(2, 2), false)
	check(randi() == expected_random, "Ambient refresh preserves global gameplay RNG")
	check(ambient._mote_cells.size() == ambient.MAX_MOTES, "Dense visibility respects mote budget")
	var all_on_floor := true
	for cell: Vector2i in ambient._mote_cells:
		all_on_floor = all_on_floor and grid.is_floor(cell) and visible_cells.has(cell)
	check(all_on_floor, "Motes only spawn on visible floor")
	var all_inside := true
	for frame in 300:
		ambient._phase = frame * 0.2
		for cell: Vector2i in ambient._mote_cells:
			var local: Vector2 = ambient._mote_local_position(cell)
			all_inside = all_inside and local.x >= 0 and local.y >= 0 and local.x + 1.5 < 48 and local.y + 1.5 < 48
	check(all_inside, "Drift stays inside the visible source cell at every phase")
	ambient.refresh(grid, {}, Vector2i(1, 1), true, Vector2i(2, 2), false)
	check(ambient._mote_cells.is_empty() and ambient._stairs.x < 0 and ambient._escape.x < 0 and not ambient.is_processing(), "Fog update immediately clears all hidden effects")
	ambient.refresh(grid, visible_cells, Vector2i(1, 1), false, Vector2i(-1, -1), true)
	check(ambient._stairs.x < 0 and ambient._escape.x < 0, "Absent exits never receive hints")
	ambient.hide()
	var paused: float = ambient._phase
	await create_timer(0.04).timeout
	check(not ambient.is_processing() and ambient._phase == paused, "Hidden ambient node stops animation")
	ambient.show()
	check(ambient.is_processing(), "Visible populated ambient resumes animation")
	ambient.refresh(null, {}, Vector2i.ZERO, false, Vector2i.ZERO, false)
	check(not ambient.is_processing() and ambient._mote_cells.is_empty(), "Floor teardown can clear without a grid")
	ambient.queue_free()
	await process_frame
	print("Ambient details: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
