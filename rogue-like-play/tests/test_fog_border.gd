extends SceneTree

var checks := 0
var failures := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _initialize() -> void:
	var grid := LayoutUtils.solid_grid(Vector2i(12, 12))
	LayoutUtils.carve_rect(grid, Rect2i(2, 2, 7, 7))
	var fog := FogOfWar.new()
	fog.update(grid, Vector2i(4, 4), 2)
	check(fog.visible.has(Vector2i(1, 4)), "Wall border extends one cell beyond floor radius")
	check(fog.visible.has(Vector2i(1, 1)), "Diagonal wall border fills room outline")
	check(not fog.visible.has(Vector2i(0, 4)), "Wall border never expands into second layer")
	check(not fog.visible.has(Vector2i(7, 4)), "Open floor outside radius stays hidden")
	grid.walls[Vector2i(5, 4)] = true
	grid.walls[Vector2i(5, 5)] = true
	fog.reset()
	fog.update(grid, Vector2i(4, 4), 2)
	check(not fog.visible.has(Vector2i(6, 4)), "Floor behind wall stays hidden")
	check(not fog.explored.has(Vector2i(6, 4)), "Hidden floor is not marked explored")
	fog.update(grid, Vector2i(8, 8), 1)
	check(fog.explored.has(Vector2i(1, 4)), "Additional wall remains explored")
	check(not fog.visible.has(Vector2i(1, 4)), "Additional wall leaves current visibility")
	fog.reset()
	check(fog.explored.is_empty(), "Reset clears expanded wall history")
	print("Fog border tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
