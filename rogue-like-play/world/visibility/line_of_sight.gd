class_name LineOfSight
extends RefCounted


static func in_range(from: Vector2i, to: Vector2i, radius: int) -> bool:
	var delta := to - from
	return maxi(absi(delta.x), absi(delta.y)) <= radius


static func can_see(grid: GridState, from: Vector2i, to: Vector2i) -> bool:
	if not grid.is_floor(from) or not grid.in_bounds(to):
		return false
	var delta := to - from
	var width := absi(delta.x)
	var height := absi(delta.y)
	var step := Vector2i(signi(delta.x), signi(delta.y))
	var cell := from
	var x_steps := 0
	var y_steps := 0
	# Traverse every grid cell touched by the center-to-center ray. Integer
	# comparisons keep forward/reverse rays symmetric and handle exact corners.
	while cell != to:
		var crossing_x := (1 + 2 * x_steps) * height
		var crossing_y := (1 + 2 * y_steps) * width
		if crossing_x == crossing_y:
			if not grid.is_floor(cell + Vector2i(step.x, 0)) or not grid.is_floor(cell + Vector2i(0, step.y)):
				return false
			cell += step
			x_steps += 1
			y_steps += 1
		elif crossing_x < crossing_y:
			cell.x += step.x
			x_steps += 1
		else:
			cell.y += step.y
			y_steps += 1
		# An obstructing wall/pillar itself is visible, but nothing behind it is.
		if cell != to and not grid.is_floor(cell):
			return false
	return true
