class_name DungeonMinimap
extends Control

const UNKNOWN_CELL := Vector2i(-1, -1)
# Walls stay darker than any floor, so a lit room reads as an outlined shape
# instead of one pale block.
const FLOOR_COLOR := Color("3a434b")
const VISIBLE_FLOOR_COLOR := Color("56626c")
const WALL_COLOR := Color("1a2025")
const VISIBLE_WALL_COLOR := Color("2b333a")
# Each marker differs from the others in both colour and shape: the player is
# a blue disc in a white ring, enemies red discs, items small green squares
# and the stairs a gold diamond.
const PLAYER_COLOR := Color("6aa6ff")
const PLAYER_RING := Color("f2f4f8")
const ENEMY_COLOR := Color("f0524c")
const ITEM_COLOR := Color("7fd26a")
const STAIRS_COLOR := Color("e8bd55")
const OUTLINE_COLOR := Color("101010")
# A fixed scale centred on the player: the map scrolls as the floor is
# explored instead of shrinking to fit everything seen so far. Whole pixels
# keep cells tiling without seams.
const CELL_SIZE := 8.0

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
	var origin := (size * 0.5 - (Vector2(player_cell) + Vector2.ONE * 0.5) * CELL_SIZE).round()
	var bounds := Rect2(Vector2.ZERO, size)
	for value: Variant in explored:
		var cell := value as Vector2i
		var rect := Rect2(origin + Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
		if not bounds.intersects(rect):
			continue
		var seen_now := visible_cells.has(cell)
		var color := VISIBLE_FLOOR_COLOR if seen_now else FLOOR_COLOR
		if walls.has(cell):
			color = VISIBLE_WALL_COLOR if seen_now else WALL_COLOR
		draw_rect(rect, color)
	for cell: Vector2i in item_cells:
		if explored.has(cell):
			var center := _center(cell, origin)
			var half := CELL_SIZE * 0.3
			draw_rect(Rect2(center - Vector2.ONE * (half + 1.0), Vector2.ONE * (half + 1.0) * 2.0), OUTLINE_COLOR)
			draw_rect(Rect2(center - Vector2.ONE * half, Vector2.ONE * half * 2.0), ITEM_COLOR)
	if stairs_cell != UNKNOWN_CELL and explored.has(stairs_cell):
		var center := _center(stairs_cell, origin)
		var radius := CELL_SIZE * 0.75
		var diamond := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
		draw_colored_polygon(diamond, STAIRS_COLOR)
		draw_polyline(diamond + PackedVector2Array([diamond[0]]), OUTLINE_COLOR, 1.0, true)
	for cell: Vector2i in enemy_cells:
		var center := _center(cell, origin)
		var radius := CELL_SIZE * 0.45
		draw_circle(center, radius + 1.0, OUTLINE_COLOR)
		draw_circle(center, radius, ENEMY_COLOR)
	if explored.has(player_cell):
		var center := _center(player_cell, origin)
		var radius := CELL_SIZE * 0.5
		draw_circle(center, radius + 2.0, OUTLINE_COLOR)
		draw_circle(center, radius + 1.0, PLAYER_RING)
		draw_circle(center, radius, PLAYER_COLOR)


func _center(cell: Vector2i, origin: Vector2) -> Vector2:
	return origin + (Vector2(cell) + Vector2.ONE * 0.5) * CELL_SIZE
