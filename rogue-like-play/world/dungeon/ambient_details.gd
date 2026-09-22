extends Node2D

const TILE_SIZE := 48.0
const MAX_MOTES := 24
const PHASE_PERIOD := TAU * 4.0

var _mote_cells: Array[Vector2i] = []
var _stairs := Vector2i(-1, -1)
var _escape := Vector2i(-1, -1)
var _forest := false
var _phase := 0.0


func _ready() -> void:
	visibility_changed.connect(_update_processing)
	_update_processing()


func refresh(grid: GridState, visible_cells: Dictionary, stairs_cell: Vector2i, has_stairs: bool, escape_cell: Vector2i, forest: bool) -> void:
	_mote_cells.clear()
	_stairs = Vector2i(-1, -1)
	_escape = Vector2i(-1, -1)
	_forest = forest
	if grid != null:
		for cell: Vector2i in visible_cells:
			if grid.is_floor(cell) and _cell_seed(cell) % 11 == 0 and _mote_cells.size() < MAX_MOTES:
				_mote_cells.append(cell)
		if has_stairs and visible_cells.has(stairs_cell) and grid.is_floor(stairs_cell):
			_stairs = stairs_cell
		if visible_cells.has(escape_cell) and grid.is_floor(escape_cell):
			_escape = escape_cell
	_update_processing()
	queue_redraw()


func _update_processing() -> void:
	set_process(is_inside_tree() and is_visible_in_tree() and (not _mote_cells.is_empty() or _stairs.x >= 0 or _escape.x >= 0))


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, PHASE_PERIOD)
	queue_redraw()


func _cell_seed(cell: Vector2i) -> int:
	# Coordinate hashing never consumes the generator's gameplay RNG stream.
	return absi((cell.x * 73856093) ^ (cell.y * 19349663))


func _mote_local_position(cell: Vector2i) -> Vector2:
	var seed_value := _cell_seed(cell)
	var cycle := _phase + float(seed_value % 100) * 0.25
	# The whole two-pixel mote stays within its own visible tile at every phase.
	return Vector2(24.0 + sin(cycle * 0.5) * 13.0, 24.0 + cos(cycle * 0.25) * 15.0)


func _draw() -> void:
	for cell in _mote_cells:
		var offset := _mote_local_position(cell)
		var shimmer := 0.13 + 0.10 * (0.5 + 0.5 * sin(_phase + float(_cell_seed(cell) % 31)))
		var tint := Color(0.71, 0.76, 0.54, shimmer) if _forest else Color(0.74, 0.70, 0.57, shimmer)
		draw_rect(Rect2(Vector2(cell) * TILE_SIZE + offset, Vector2(1.5, 1.5)), tint)
	if _stairs.x >= 0:
		_draw_exit_hint(_stairs, Color(0.66, 0.73, 0.65), 0.0)
	if _escape.x >= 0:
		_draw_exit_hint(_escape, Color(0.83, 0.69, 0.43), PI)


func _draw_exit_hint(cell: Vector2i, tint: Color, phase_offset: float) -> void:
	var pulse := 0.5 + sin(_phase * 0.5 + phase_offset) * 0.5
	tint.a = 0.14 + pulse * 0.12
	var center := (Vector2(cell) + Vector2.ONE * 0.5) * TILE_SIZE
	# Corner arcs outline the existing exit without covering its icon or warnings.
	for corner in 4:
		var angle := PI * 0.25 + corner * PI * 0.5
		draw_arc(center, 17.0 + pulse, angle - 0.22, angle + 0.22, 6, tint, 1.0)
