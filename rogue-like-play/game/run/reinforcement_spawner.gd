class_name ReinforcementSpawner
extends RefCounted

const NO_CELL := Vector2i(-1, -1)
const BOSS_FLOOR := 10

var spawned_count := 0
var last_attempt_turn := 0


func reset(current_turn: int) -> void:
	spawned_count = 0
	last_attempt_turn = current_turn


func try_spawn(grid: GridState, player_cell: Vector2i, visible: Dictionary,
		enemies: Array, stairs_cell: Vector2i, settings: DungeonSettings,
		current_turn: int, floor_number: int, rng: RandomNumberGenerator,
		occupied_items: Dictionary = {}) -> Vector2i:
	if floor_number >= BOSS_FLOOR or spawned_count >= settings.reinforcement_total_cap:
		return NO_CELL
	if current_turn - last_attempt_turn < maxi(1, settings.reinforcement_interval):
		return NO_CELL
	# A failed or blocked attempt consumes this interval as well.
	last_attempt_turn = current_turn
	var alive_count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.hp > 0:
			alive_count += 1
	if alive_count >= settings.reinforcement_alive_cap:
		return NO_CELL
	if rng.randf() >= clampf(settings.reinforcement_chance, 0.0, 1.0):
		return NO_CELL
	var candidates: Array[Vector2i] = []
	var distances := LayoutUtils.distances(grid, player_cell)
	var minimum := maxi(1, settings.reinforcement_min_distance)
	for cell: Vector2i in distances:
		var delta := cell - player_cell
		if maxi(absi(delta.x), absi(delta.y)) < minimum or int(distances[cell]) < minimum:
			continue
		if visible.has(cell) or grid.occupants.has(cell) or occupied_items.has(cell) or cell == stairs_cell:
			continue
		candidates.append(cell)
	if candidates.is_empty():
		return NO_CELL
	spawned_count += 1
	return candidates[rng.randi_range(0, candidates.size() - 1)]
