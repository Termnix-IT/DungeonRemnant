class_name FogOfWar
extends RefCounted

var visible: Dictionary = {}
var explored: Dictionary = {}


func reset() -> void:
	visible.clear()
	explored.clear()


func update(grid: GridState, origin: Vector2i, radius: int) -> void:
	visible.clear()
	for y in range(maxi(0, origin.y - radius), mini(grid.size.y, origin.y + radius + 1)):
		for x in range(maxi(0, origin.x - radius), mini(grid.size.x, origin.x + radius + 1)):
			var cell := Vector2i(x, y)
			if LineOfSight.can_see(grid, origin, cell):
				visible[cell] = true
	# Only directly visible floors reveal their border; never expand from walls.
	var direct_cells := visible.keys()
	for cell: Vector2i in direct_cells:
		if not grid.is_floor(cell):
			continue
		for direction in LayoutUtils.DIRECTIONS:
			var border := cell + direction
			if grid.in_bounds(border) and grid.walls.has(border):
				visible[border] = true
	explored.merge(visible)
