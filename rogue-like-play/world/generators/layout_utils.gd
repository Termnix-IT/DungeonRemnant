class_name LayoutUtils
extends RefCounted

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]


static func solid_grid(size: Vector2i) -> GridState:
	var grid := GridState.new()
	grid.size = size
	for y in size.y:
		for x in size.x:
			grid.walls[Vector2i(x, y)] = true
	return grid


static func carve_rect(grid: GridState, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if x > 0 and y > 0 and x < grid.size.x - 1 and y < grid.size.y - 1:
				grid.walls.erase(Vector2i(x, y))
				grid.pillars.erase(Vector2i(x, y))


static func carve_corridor(grid: GridState, from: Vector2i, to: Vector2i) -> void:
	var cell := from
	grid.walls.erase(cell)
	grid.pillars.erase(cell)
	while cell.x != to.x:
		cell.x += signi(to.x - cell.x)
		grid.walls.erase(cell)
		grid.pillars.erase(cell)
	while cell.y != to.y:
		cell.y += signi(to.y - cell.y)
		grid.walls.erase(cell)
		grid.pillars.erase(cell)


static func distances(grid: GridState, start: Vector2i) -> Dictionary:
	if not grid.is_floor(start):
		return {}
	var result := {start: 0}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for direction in DIRECTIONS:
			var next := cell + direction
			if not result.has(next) and grid.can_step(cell, next):
				result[next] = int(result[cell]) + 1
				queue.append(next)
	return result


static func keep_largest_region(grid: GridState) -> Array[Vector2i]:
	var seen: Dictionary = {}
	var largest: Array[Vector2i] = []
	for y in grid.size.y:
		for x in grid.size.x:
			var cell := Vector2i(x, y)
			if not grid.is_floor(cell) or seen.has(cell):
				continue
			var region := distances(grid, cell)
			seen.merge(region)
			if region.size() > largest.size():
				largest.assign(region.keys())
	var retained: Dictionary = {}
	for cell in largest:
		retained[cell] = true
	for cell: Vector2i in seen:
		if not retained.has(cell):
			grid.walls[cell] = true
	return largest
