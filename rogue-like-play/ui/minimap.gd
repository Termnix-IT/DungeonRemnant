class_name DungeonMinimap
extends Control

const UNKNOWN_CELL := Vector2i(-1, -1)
const FLOOR_COLOR := Color("46515b")
const VISIBLE_FLOOR_COLOR := Color("77838d")
const WALL_COLOR := Color("252d34")
const VISIBLE_WALL_COLOR := Color("59636c")
const PLAYER_COLOR := Color("6aa6ff")
const ENEMY_COLOR := Color("ef615b")
const STAIRS_COLOR := Color("e8bd55")
const ITEM_COLOR := Color("d9903d")
const OUTLINE_COLOR := Color("101010")
# The view frames the known area, never smaller than this many cells, so a
# fresh floor is not blown up to a few giant tiles.
const MIN_VIEW_CELLS := Vector2i(20, 14)
const MAX_CELL_SIZE := 10.0

var grid_size := Vector2i.ZERO
var walls: Dictionary = {}
var explored: Dictionary = {}
var visible_cells: Dictionary = {}
var player_cell := UNKNOWN_CELL
var stairs_cell := UNKNOWN_CELL
var enemy_cells: Array[Vector2i] = []
var item_cells: Array[Vector2i] = []
var view := Rect2i()


func refresh(
	grid: GridState,
	explored_cells: Dictionary,
	currently_visible: Dictionary,
	player_position: Vector2i,
	discovered_stairs: Vector2i,
	visible_enemies: Array[Vector2i],
	discovered_items: Array[Vector2i]
) -> void:
	grid_size = grid.size
	walls = grid.walls.duplicate()
	explored = explored_cells.duplicate()
	visible_cells = currently_visible.duplicate()
	player_cell = player_position
	stairs_cell = discovered_stairs
	enemy_cells = visible_enemies.duplicate()
	item_cells = discovered_items.duplicate()
	view = _known_view()
	queue_redraw()


func _known_view() -> Rect2i:
	var bounds := Rect2i(player_cell, Vector2i.ONE)
	for value: Variant in explored:
		bounds = bounds.merge(Rect2i(value as Vector2i, Vector2i.ONE))
	bounds = bounds.grow(1)
	var extent := Vector2i(maxi(bounds.size.x, MIN_VIEW_CELLS.x), maxi(bounds.size.y, MIN_VIEW_CELLS.y))
	return Rect2i(bounds.get_center() - extent / 2, extent)


func _draw() -> void:
	if explored.is_empty() or grid_size == Vector2i.ZERO:
		return
	var padding := 6.0
	var cell_size := minf((size.x - padding * 2.0) / view.size.x, (size.y - padding * 2.0) / view.size.y)
	cell_size = clampf(cell_size, 1.0, MAX_CELL_SIZE)
	var origin := size * 0.5 - (Vector2(view.position) + Vector2(view.size) * 0.5) * cell_size
	for value: Variant in explored:
		var cell := value as Vector2i
		var seen_now := visible_cells.has(cell)
		var color := VISIBLE_FLOOR_COLOR if seen_now else FLOOR_COLOR
		if walls.has(cell):
			color = VISIBLE_WALL_COLOR if seen_now else WALL_COLOR
		_draw_cell(cell, origin, cell_size, color)
	for cell: Vector2i in item_cells:
		if explored.has(cell):
			_draw_marker(cell, origin, cell_size, ITEM_COLOR, 0.52)
	if stairs_cell != UNKNOWN_CELL and explored.has(stairs_cell):
		var center := _center(stairs_cell, origin, cell_size)
		var radius := maxf(3.5, cell_size * 0.75)
		var diamond := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
		draw_colored_polygon(diamond, STAIRS_COLOR)
		draw_polyline(diamond + PackedVector2Array([diamond[0]]), OUTLINE_COLOR, 1.0, true)
	for cell: Vector2i in enemy_cells:
		_draw_marker(cell, origin, cell_size, ENEMY_COLOR, 0.62)
	if explored.has(player_cell):
		var center := _center(player_cell, origin, cell_size)
		var radius := maxf(3.0, cell_size * 0.5)
		draw_circle(center, radius + 1.5, OUTLINE_COLOR)
		draw_circle(center, radius, PLAYER_COLOR)


func _draw_cell(cell: Vector2i, origin: Vector2, cell_size: float, color: Color) -> void:
	var rect := Rect2(origin + Vector2(cell) * cell_size, Vector2.ONE * maxf(cell_size - 0.35, 1.0))
	draw_rect(rect, color)


func _draw_marker(cell: Vector2i, origin: Vector2, cell_size: float, color: Color, scale: float) -> void:
	if not explored.has(cell):
		return
	var center := _center(cell, origin, cell_size)
	var radius := maxf(1.5, cell_size * scale * 0.5)
	draw_circle(center, radius, color)


func _center(cell: Vector2i, origin: Vector2, cell_size: float) -> Vector2:
	return origin + (Vector2(cell) + Vector2.ONE * 0.5) * cell_size
