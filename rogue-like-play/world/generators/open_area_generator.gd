class_name OpenAreaGenerator
extends RefCounted


static func generate(settings: DungeonSettings, rng: RandomNumberGenerator) -> GridState:
	var grid := LayoutUtils.solid_grid(settings.map_size())
	LayoutUtils.carve_rect(grid, Rect2i(Vector2i.ONE, grid.size - Vector2i(2, 2)))
	for y in range(2, grid.size.y - 2):
		for x in range(2, grid.size.x - 2):
			if rng.randf() < clampf(settings.obstacle_chance, 0.02, 0.2):
				grid.walls[Vector2i(x, y)] = true
				grid.pillars[Vector2i(x, y)] = true
	return grid
