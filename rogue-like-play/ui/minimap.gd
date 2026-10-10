class_name DungeonMinimap
extends Control

const UNKNOWN_CELL := Vector2i(-1, -1)
# Walls stay darker than any floor, so a lit room reads as an outlined shape
# instead of one pale block. The stone is warm, like the bronze frame round
# it, so the hero's blue gem and the green item gems stand out from it.
const FLOOR_COLOR := Color("3f3a30")
const VISIBLE_FLOOR_COLOR := Color("5c5544")
const WALL_COLOR := Color("1f1c17")
const VISIBLE_WALL_COLOR := Color("332e25")
# Each marker is a small painted icon (the theme's DungeonMinimap icons),
# differing from the others in both colour and shape: the hero a blue-white
# gem, enemies red horned skulls, items green gems and the stairs a gold
# stairway. Each icon is built at the size it is drawn (tools/build_hud_art.py),
# the hero largest, so it lands on whole pixels unscaled.

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
			_marker(&"item", cell, origin)
	if stairs_cell != UNKNOWN_CELL and explored.has(stairs_cell):
		_marker(&"stairs", stairs_cell, origin)
	for cell: Vector2i in enemy_cells:
		_marker(&"enemy", cell, origin)
	if explored.has(player_cell):
		_marker(&"player", player_cell, origin)


func _marker(kind: StringName, cell: Vector2i, origin: Vector2) -> void:
	var icon := get_theme_icon(kind, &"DungeonMinimap")
	draw_texture(icon, (_center(cell, origin) - icon.get_size() * 0.5).round())


func _center(cell: Vector2i, origin: Vector2) -> Vector2:
	return origin + (Vector2(cell) + Vector2.ONE * 0.5) * CELL_SIZE
