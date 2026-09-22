extends Node2D

@export var stats: EnemyStats
var summon_clock := 0
var summon_due := false
var summoner: Node2D
var hp: int:
	set(value):
		hp = value
		_update_idle_processing()
		queue_redraw()
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
var visual_scale := Vector2.ONE:
	set(value):
		visual_scale = value
		queue_redraw()
var visual_rotation := 0.0:
	set(value):
		visual_rotation = value
		queue_redraw()
var _idle_time := 0.0


func _ready() -> void:
	hp = stats.max_hp
	visibility_changed.connect(_update_idle_processing)
	_update_idle_processing()


func _update_idle_processing() -> void:
	set_process(is_inside_tree() and is_visible_in_tree() and hp > 0)


func _process(delta: float) -> void:
	_idle_time = fmod(_idle_time + delta, TAU * 2.0)
	queue_redraw()


func detects(grid: GridState, target: Vector2i) -> bool:
	if not LineOfSight.in_range(cell, target, stats.detection_range):
		return false
	return stats.detection == EnemyStats.Detection.PROXIMITY or LineOfSight.can_see(grid, cell, target)


func take_turn(grid: GridState, player: Node2D) -> int:
	if hp <= 0 or player.hp <= 0:
		return 0
	if stats.behavior == EnemyStats.Behavior.SUMMONER:
		summon_clock += 1
		summon_due = summon_clock >= stats.summon_interval
		if summon_due:
			summon_clock = 0
		queue_redraw()
		return 0
	if stats.behavior == EnemyStats.Behavior.FAST:
		for step in stats.move_steps:
			if detects(grid, player.cell) and grid.can_step(cell, player.cell):
				return _take_normal_turn(grid, player)
			_take_normal_turn(grid, player)
		return 0
	if stats.behavior == EnemyStats.Behavior.CHARGER:
		return _take_charge_turn(grid, player)
	return _take_normal_turn(grid, player)


func _take_charge_turn(grid: GridState, player: Node2D) -> int:
	if shot_direction == Vector2i.ZERO:
		if detects(grid, player.cell):
			var delta: Vector2i = player.cell - cell
			shot_direction = Vector2i(signi(delta.x), signi(delta.y))
			facing = shot_direction
		queue_redraw()
		return 0
	var direction := shot_direction
	shot_direction = Vector2i.ZERO
	for step in stats.move_steps:
		if cell + direction == player.cell and grid.can_step(cell, player.cell):
			return CombatRules.attack(grid, self, direction)
		if not grid.move_actor(self, cell + direction):
			break
	queue_redraw()
	return 0


func _take_normal_turn(grid: GridState, player: Node2D) -> int:
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
	if stats == null:
		return
	# Ground shadow and tactical markers stay readable when the body recoils.
	draw_set_transform(visual_offset)
	draw_ellipse_shadow()
	var breath := sin(_idle_time * 2.4 + cell.x * 0.73 + cell.y * 1.13) if hp > 0 else 0.0
	var body_scale := visual_scale * Vector2(1.0 + breath * 0.018, 1.0 - breath * 0.025)
	if stats.behavior in [EnemyStats.Behavior.FAST, EnemyStats.Behavior.CHARGER] and facing.x > 0:
		body_scale.x *= -1.0
	draw_set_transform(visual_offset + Vector2(0, -0.5 * breath), visual_rotation, body_scale)
	if stats.is_boss:
		_draw_guardian(true)
	elif stats.behavior == EnemyStats.Behavior.SUMMONER:
		_draw_nest()
	elif stats.behavior == EnemyStats.Behavior.FAST:
		_draw_beast(false)
	elif stats.behavior == EnemyStats.Behavior.CHARGER:
		_draw_beast(true)
	elif stats.detection == EnemyStats.Detection.TURRET:
		_draw_turret()
	elif stats.detection == EnemyStats.Detection.PROXIMITY:
		_draw_slime()
	else:
		_draw_guardian(false)
	draw_set_transform(visual_offset)
	if hp <= 0:
		draw_set_transform(Vector2.ZERO)
		return
	var direction := Vector2(facing).normalized()
	var charged := shot_direction != Vector2i.ZERO
	var indicator_color := Color("efbb81") if charged else Color("b7ab92")
	if charged:
		draw_line(direction * 16, Vector2(shot_direction).normalized() * 28, indicator_color, 2)
	var tip := direction * (30 if charged else 17)
	var side := direction.orthogonal() * 2.5
	draw_colored_polygon(PackedVector2Array([tip, tip - direction * 4 + side, tip - direction * 4 - side]), indicator_color)
	if stats.elite:
		draw_arc(Vector2.ZERO, 16, 0, TAU, 24, Color("d3b56e"), 1.5)
	if stats.behavior == EnemyStats.Behavior.SUMMONER:
		draw_arc(Vector2.ZERO, 18, -PI / 2, -PI / 2 + TAU * (summon_clock + 1) / stats.summon_interval, 24, Color("b7c78c"), 2)
	if hp < stats.max_hp:
		draw_rect(Rect2(-12, -20, 24, 3), Color("45383c"))
		draw_rect(Rect2(-12, -20, 24.0 * maxi(0, hp) / stats.max_hp, 3), Color("efbb81"))
	draw_set_transform(Vector2.ZERO)


func draw_ellipse_shadow() -> void:
	draw_set_transform(visual_offset + Vector2(0, 11), 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 12, Color(0.04, 0.045, 0.05, 0.5))
	draw_set_transform(visual_offset)


func _draw_guardian(boss: bool) -> void:
	var width := 13.0 if boss else 10.0
	draw_rect(Rect2(-width, -8, width * 2, 18), Color("292d36"))
	draw_rect(Rect2(-7, 8, 5, 5), Color("62594f"))
	draw_rect(Rect2(2, 8, 5, 5), Color("62594f"))
	draw_rect(Rect2(-width + 2, -5, width * 2 - 4, 14), Color("8f655c") if boss else Color("68757a"))
	draw_rect(Rect2(-5, -12, 10, 13), Color("b2997b") if boss else Color("9daba7"))
	draw_rect(Rect2(-4, -6, 8, 3), Color("272f38"))
	draw_rect(Rect2(-3, -5, 2, 1), Color("f1c486"))
	draw_rect(Rect2(2, -5, 2, 1), Color("f1c486"))
	draw_line(Vector2(-width + 2, 0), Vector2(width - 2, 0), Color("b7a080"), 2)
	draw_line(Vector2(0, 1), Vector2(0, 7), Color("414955"), 2)
	if boss:
		draw_colored_polygon(PackedVector2Array([Vector2(-7,-10),Vector2(-10,-17),Vector2(-3,-13),Vector2(0,-17),Vector2(3,-13),Vector2(10,-17),Vector2(7,-10)]), Color("d4b275"))
		draw_rect(Rect2(-15, -5, 5, 8), Color("b58a70"))
		draw_rect(Rect2(10, -5, 5, 8), Color("b58a70"))


func _draw_slime() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-12,8),Vector2(-11,-1),Vector2(-6,-10),Vector2(3,-12),Vector2(9,-7),Vector2(12,7),Vector2(7,11),Vector2(-7,11)]), Color("303833"))
	draw_colored_polygon(PackedVector2Array([Vector2(-9,7),Vector2(-8,-1),Vector2(-4,-8),Vector2(3,-9),Vector2(7,-5),Vector2(9,7),Vector2(5,9),Vector2(-5,9)]), Color("a99c65"))
	draw_rect(Rect2(-5, -6, 5, 2), Color("d0c68b"))
	draw_rect(Rect2(-4, 0, 2, 3), Color("343936"))
	draw_rect(Rect2(3, 0, 2, 3), Color("343936"))
	draw_line(Vector2(-6, 7), Vector2(5, 7), Color("7d7950"), 2)


func _draw_beast(charger: bool) -> void:
	var hide_color := Color("9c7b67") if charger else Color("8c8b8b")
	draw_line(Vector2(7, 6), Vector2(15, 2), Color("b29a83"), 2)
	draw_rect(Rect2(-8, 8, 4, 4), Color("43424a"))
	draw_rect(Rect2(4, 8, 4, 4), Color("43424a"))
	draw_colored_polygon(PackedVector2Array([Vector2(-12,3),Vector2(-8,-7),Vector2(6,-9),Vector2(11,-2),Vector2(10,9),Vector2(-6,10)]), Color("33333c"))
	draw_colored_polygon(PackedVector2Array([Vector2(-9,3),Vector2(-6,-5),Vector2(5,-7),Vector2(8,-1),Vector2(7,7),Vector2(-5,8)]), hide_color)
	draw_rect(Rect2(-7, -10, 4, 6), hide_color)
	draw_rect(Rect2(3, -11, 4, 5), hide_color)
	draw_rect(Rect2(-10, 1, 7, 6), Color("bdab96"))
	draw_rect(Rect2(-11, 2, 2, 3), Color("3c3640"))
	draw_rect(Rect2(-5, -2, 2, 2), Color("eed6a0"))
	if charger:
		draw_colored_polygon(PackedVector2Array([Vector2(-10,4),Vector2(-14,-2),Vector2(-7,1)]), Color("e3d2ab"))
		draw_line(Vector2(0,-7),Vector2(5,5),Color("66554f"),3)


func _draw_nest() -> void:
	draw_circle(Vector2(0, 2), 13, Color("343a34"))
	for index in 6:
		var point := Vector2.from_angle(index * TAU / 6) * 9
		draw_line(point, point.rotated(0.7), Color("80745a"), 4)
	draw_circle(Vector2(-3, 0), 5, Color("8f9b73"))
	draw_circle(Vector2(5, 3), 4, Color("b5bc8b"))
	draw_circle(Vector2(1, -5), 4, Color("a3ad7f"))
	draw_line(Vector2(-4,-2),Vector2(-1,2),Color("52604a"),1)


func _draw_turret() -> void:
	draw_rect(Rect2(-11, 5, 22, 8), Color("383743"))
	draw_rect(Rect2(-8, 4, 16, 7), Color("767385"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,-14),Vector2(10,-5),Vector2(7,5),Vector2(-7,5),Vector2(-10,-5)]), Color("524b65"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,-11),Vector2(6,-4),Vector2(0,3),Vector2(-6,-4)]), Color("afa3c0"))
	draw_line(Vector2(0,-10),Vector2(0,2),Color("d8cde0"),2)
	draw_line(Vector2(0,-3),Vector2(facing).normalized() * 12, Color("4e485b"), 5)
	draw_circle(Vector2(facing).normalized() * 12, 2, Color("eed6a0") if shot_direction != Vector2i.ZERO else Color("9e91ad"))
