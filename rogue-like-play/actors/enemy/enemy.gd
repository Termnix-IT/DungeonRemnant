extends Node2D

# An enemy is drawn as its illustration rig (EnemySprites.rig_path(), a
# CharacterRig drawn facing right) through a RigView, mirrored when it faces
# left. Its shadow and the rig sit behind this node's own drawing, so the
# facing arrow and health bar stay on top. The battle presentation's
# wind-up, hurt and down cues become the rig's attack, flinch and fall, and
# a warning turn its brace.
# World px from the soles to the top of the head, where the rig does not say
# (its "world_height" meta); the hero stands 64.
const RIG_HEIGHT := 60.0
# Where the rig's soles stand in the enemy's own (scaled) space.
const SOLE := Vector2(0, 13)

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
		_sync_rig()
		queue_redraw()
var visual_scale := Vector2.ONE:
	set(value):
		visual_scale = value
		_sync_rig()
		queue_redraw()
var visual_rotation := 0.0:
	set(value):
		visual_rotation = value
		_sync_rig()
		queue_redraw()
# The presentation's held cue (EnemySprites.FRAME_*); -1 returns to idle. The
# rig plays the hurt as a flinch and, once fallen, falls; its attack starts
# from play_attack().
var pose_frame := -1:
	set(value):
		pose_frame = value
		queue_redraw()
		if rig != null:
			if value == EnemySprites.FRAME_HURT:
				rig.hurt()
			elif value < 0 and hp <= 0:
				rig.fall()
var rig: CharacterRig
var rig_view: RigView
var _rig_shadow: Node2D


func _ready() -> void:
	hp = stats.max_hp
	_build_rig()
	visibility_changed.connect(_update_idle_processing)
	_update_idle_processing()


func _build_rig() -> void:
	var path := EnemySprites.rig_path(EnemySprites.visual_id(stats))
	if not ResourceLoader.exists(path):
		return
	_rig_shadow = Node2D.new()
	_rig_shadow.name = "RigShadow"
	_rig_shadow.show_behind_parent = true
	add_child(_rig_shadow)
	_rig_shadow.draw.connect(_draw_rig_shadow)
	rig_view = RigView.new()
	rig_view.name = "RigView"
	rig_view.show_behind_parent = true
	# In this node's scaled space, as the rig is.
	add_child(rig_view)
	rig = (load(path) as PackedScene).instantiate()
	rig.world_height = rig_height() / scale.x
	rig_view.setup(rig)
	_sync_rig()


# The rig's height in world px, as its description sets it (the size the
# enemy was designed at).
func rig_height() -> float:
	if rig != null and rig.has_meta(&"world_height"):
		return float(rig.get_meta(&"world_height"))
	return RIG_HEIGHT


# The rig follows the presentation's offset, squash and tilt, and faces the
# way the enemy does.
func _sync_rig() -> void:
	if rig_view == null:
		return
	rig_view.position = visual_offset + SOLE
	rig_view.rotation = visual_rotation
	rig_view.scale = Vector2(visual_scale.x * (-1.0 if facing.x < 0 else 1.0), visual_scale.y)
	_rig_shadow.queue_redraw()


func _draw_rig_shadow() -> void:
	_rig_shadow.draw_set_transform(visual_offset + Vector2(0, 11), 0, Vector2(1, 0.3))
	_rig_shadow.draw_circle(Vector2.ZERO, 12.0, Color(0.04, 0.045, 0.05, 0.5))


# The rig swings itself, timed to the presentation's impact; false leaves the
# wind-up and strike frames to the sprite.
func play_attack(_weapon: WeaponData) -> bool:
	if rig == null:
		return false
	rig.attack()
	return true


func play_walk(direction: Vector2i) -> void:
	if rig != null:
		rig.step(Vector2(direction))


func _update_idle_processing() -> void:
	set_process(is_inside_tree() and is_visible_in_tree() and hp > 0)


func _process(_delta: float) -> void:
	_sync_rig()
	if rig != null:
		rig.braced = hp > 0 and _bracing()
	queue_redraw()


# A warning turn: a turret aiming, a charger bracing, a nest about to hatch;
# the rig holds its brace.
func _bracing() -> bool:
	if shot_direction != Vector2i.ZERO:
		return true
	return stats.behavior == EnemyStats.Behavior.SUMMONER and summon_clock + 1 >= stats.summon_interval


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
	# Tactical markers stay readable when the body recoils.
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
		_draw_health(_health_bar_top())
	draw_set_transform(Vector2.ZERO)


# The bar stays just above the head.
func _health_bar_top() -> float:
	return SOLE.y - rig_height() / scale.x - 6.0


# The rig has a fall of its own, so the presentation never flattens it.
func has_sprite() -> bool:
	return rig_view != null


func _draw_health(top: float) -> void:
	var ratio := clampf(float(hp) / stats.max_hp, 0.0, 1.0)
	var frame := Rect2(-14, top, 28, 5)
	draw_rect(frame.grow(1), Color("12141e"))
	draw_rect(frame, Color("3b2e31"))
	var fill := Color("e8c26f") if ratio > 0.5 else (Color("e98a4a") if ratio > 0.25 else Color("e0483f"))
	draw_rect(Rect2(frame.position, Vector2(frame.size.x * ratio, frame.size.y)), fill)
	draw_rect(Rect2(frame.position, Vector2(frame.size.x * ratio, 1)), fill.lightened(0.35))
