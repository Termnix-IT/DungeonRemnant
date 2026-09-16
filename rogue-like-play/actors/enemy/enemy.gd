extends Node2D

@export var stats: EnemyStats
var hp: int
var cell := Vector2i.ZERO
var facing := Vector2i.LEFT
var last_seen_cell := Vector2i(-1, -1)
var exp_claimed := false
var shot_direction := Vector2i.ZERO
var shot_origin := Vector2i(-1, -1)
var visual_offset := Vector2.ZERO:
	set(value):
		visual_offset = value
		queue_redraw()


func _ready() -> void:
	hp = stats.max_hp


func detects(grid: GridState, target: Vector2i) -> bool:
	if not LineOfSight.in_range(cell, target, stats.detection_range):
		return false
	return stats.detection == EnemyStats.Detection.PROXIMITY or LineOfSight.can_see(grid, cell, target)


func take_turn(grid: GridState, player: Node2D) -> int:
	if hp <= 0 or player.hp <= 0:
		return 0
	var detected := detects(grid, player.cell)
	if stats.detection == EnemyStats.Detection.TURRET:
		return _take_turret_turn(grid, player, detected)
	if detected:
		last_seen_cell = player.cell
	elif stats.detection == EnemyStats.Detection.PROXIMITY:
		last_seen_cell = Vector2i(-1, -1)
	if last_seen_cell == Vector2i(-1, -1):
		return 0
	if detected and grid.can_step(cell, player.cell):
		var delta: Vector2i = player.cell - cell
		facing = Vector2i(signi(delta.x), signi(delta.y))
		queue_redraw()
		return CombatRules.attack(grid, self, facing)
	if cell != last_seen_cell:
		var next := choose_step(grid, last_seen_cell)
		if next != cell:
			facing = next - cell
			grid.move_actor(self, next)
	if not detected and cell == last_seen_cell:
		last_seen_cell = Vector2i(-1, -1)
	queue_redraw()
	return 0


func _take_turret_turn(grid: GridState, player: Node2D, detected: bool) -> int:
	var previous_direction := shot_direction
	var previous_origin := shot_origin
	shot_direction = Vector2i.ZERO
	shot_origin = Vector2i(-1, -1)
	queue_redraw()
	if not detected:
		return 0
	var delta: Vector2i = player.cell - cell
	facing = Vector2i(signi(delta.x), signi(delta.y))
	if delta.x != 0 and delta.y != 0 and absi(delta.x) != absi(delta.y):
		return 0
	var ray := CombatRules.ray_cells(grid, cell, facing, stats.attack_range)
	if ray.is_empty() or ray.back() != player.cell:
		return 0
	# Fire only along the previously warned ray, from the same position.
	if previous_direction == facing and previous_origin == cell:
		return CombatRules.damage_target(grid, self, player)
	shot_direction = facing
	shot_origin = cell
	return 0


func choose_step(grid: GridState, target: Vector2i) -> Vector2i:
	var pathfinder := AStarGrid2D.new()
	pathfinder.region = Rect2i(Vector2i.ZERO, grid.size)
	pathfinder.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	pathfinder.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	pathfinder.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	pathfinder.update()
	for wall: Vector2i in grid.walls:
		pathfinder.set_point_solid(wall)
	for occupied: Vector2i in grid.occupants:
		if occupied != cell and occupied != target:
			pathfinder.set_point_solid(occupied)
	var path := pathfinder.get_id_path(cell, target)
	return path[1] if path.size() > 1 else cell


func _draw() -> void:
	draw_set_transform(visual_offset)
	if stats.is_boss:
		draw_rect(Rect2(-14, -14, 28, 28), Color("de8172"))
		draw_rect(Rect2(-10, -10, 20, 20), Color("efbb81"), false, 3)
	match stats.detection:
		EnemyStats.Detection.VISION:
			draw_rect(Rect2(-10, -10, 20, 20), Color("de8172"))
		EnemyStats.Detection.PROXIMITY:
			draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(12, 0), Vector2(0, 12), Vector2(-12, 0)]), Color("dfb66d"))
		EnemyStats.Detection.TURRET:
			draw_circle(Vector2.ZERO, 11, Color("b79cde"))
			draw_rect(Rect2(-6, -6, 12, 12), Color("5b4975"))
	if stats.detection == EnemyStats.Detection.TURRET:
		var charging := shot_direction != Vector2i.ZERO
		draw_line(Vector2.ZERO, Vector2(facing) * (28 if charging else 16), Color.WHITE if charging else Color("716b82"), 3)
	else:
		draw_line(Vector2.ZERO, Vector2(facing) * 16, Color.WHITE, 3)
	if hp < stats.max_hp:
		draw_rect(Rect2(-12, -17, 24, 3), Color("45383c"))
		draw_rect(Rect2(-12, -17, 24.0 * hp / stats.max_hp, 3), Color("efbb81"))
