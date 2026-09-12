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

var grid_size := Vector2i.ZERO
var walls: Dictionary = {}
var explored: Dictionary = {}
var visible_cells: Dictionary = {}
var player_cell := UNKNOWN_CELL
var stairs_cell := UNKNOWN_CELL
var enemy_cells: Array[Vector2i] = []
var item_cells: Array[Vector2i] = []


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
	queue_redraw()


func _draw() -> void:
	if explored.is_empty() or grid_size == Vector2i.ZERO:
		return
	var padding := 6.0
	var cell_size := minf((size.x - padding * 2.0) / grid_size.x, (size.y - padding * 2.0) / grid_size.y)
	cell_size = maxf(cell_size, 1.0)
	var map_size := Vector2(grid_size) * cell_size
	var origin := (size - map_size) * 0.5
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
	if stairs_cell != UNKNOWN_CELL:
		_draw_marker(stairs_cell, origin, cell_size, STAIRS_COLOR, 0.72)
	for cell: Vector2i in enemy_cells:
		_draw_marker(cell, origin, cell_size, ENEMY_COLOR, 0.62)
	_draw_marker(player_cell, origin, cell_size, PLAYER_COLOR, 0.78)


func _draw_cell(cell: Vector2i, origin: Vector2, cell_size: float, color: Color) -> void:
	var rect := Rect2(origin + Vector2(cell) * cell_size, Vector2.ONE * maxf(cell_size - 0.35, 1.0))
	draw_rect(rect, color)


func _draw_marker(cell: Vector2i, origin: Vector2, cell_size: float, color: Color, scale: float) -> void:
	if not explored.has(cell):
		return
	var center := origin + (Vector2(cell) + Vector2.ONE * 0.5) * cell_size
	var radius := maxf(1.5, cell_size * scale * 0.5)
	draw_circle(center, radius, color)
