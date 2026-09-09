class_name CaveGenerator
extends RefCounted


static func generate(settings: DungeonSettings, rng: RandomNumberGenerator) -> GridState:
	var grid := LayoutUtils.solid_grid(settings.map_size())
	for y in range(1, grid.size.y - 1):
		for x in range(1, grid.size.x - 1):
			if rng.randf() > clampf(settings.cave_wall_chance, 0.35, 0.55):
				grid.walls.erase(Vector2i(x, y))
	# Cellular smoothing produces irregular caves; connectivity is checked afterward.
	for iteration in 4:
		var next_walls := grid.walls.duplicate()
		for y in range(1, grid.size.y - 1):
			for x in range(1, grid.size.x - 1):
				var cell := Vector2i(x, y)
				var adjacent_walls := 0
				for direction in LayoutUtils.DIRECTIONS:
					if grid.walls.has(cell + direction):
						adjacent_walls += 1
				if adjacent_walls >= 5:
					next_walls[cell] = true
				elif adjacent_walls <= 3:
					next_walls.erase(cell)
		grid.walls = next_walls
	return grid
