class_name DungeonGenerator
extends RefCounted

# Exploration floors are rooms joined by corridors. A boss floor is two maps:
# an empty antechamber whose door leads on, then the boss's single hall.
enum Kind { EXPLORATION, ANTECHAMBER, BOSS_HALL }
const ROOM_LAYOUT := "Room"
const ANTECHAMBER_LAYOUT := "Antechamber"
const BOSS_HALL_LAYOUT := "BossHall"
# Both boss-floor maps run left to right: at 1.5x the camera shows about
# eleven columns to either side of the player but only five rows above, so
# the door and the boss stand seven columns right of the entrance, inside the
# eight-cell sight radius and on screen from the first turn.
# Antechamber: a small room with a short corridor out to the door.
const ANTECHAMBER_SIZE := Vector2i(14, 11)
const ANTECHAMBER_ROOM := Rect2i(3, 3, 6, 5)
const ANTECHAMBER_DOOR := Vector2i(11, 5)
const ANTECHAMBER_START := Vector2i(4, 5)
const ANTECHAMBER_PILLARS: Array[Vector2i] = [Vector2i(6, 4), Vector2i(6, 6)]
# Boss hall: one wide room; the player enters on the left and the boss waits
# on the right, where the stairs open once it falls.
const BOSS_HALL_SIZE := Vector2i(18, 13)
const BOSS_HALL_ROOM := Rect2i(3, 2, 12, 9)
const BOSS_HALL_START := Vector2i(5, 6)
const BOSS_HALL_THRONE := Vector2i(12, 6)
const BOSS_HALL_PILLARS: Array[Vector2i] = [Vector2i(7, 4), Vector2i(7, 8), Vector2i(10, 4), Vector2i(10, 8)]
const HOUSE_ATTEMPTS := 6


static func generate(settings: DungeonSettings, floor_number: int, rng: RandomNumberGenerator, final_floor: bool = false, kind: Kind = Kind.EXPLORATION) -> Dictionary:
	match kind:
		Kind.ANTECHAMBER:
			return _fixed_room(ANTECHAMBER_SIZE, ANTECHAMBER_ROOM, ANTECHAMBER_PILLARS, ANTECHAMBER_START, ANTECHAMBER_DOOR, ANTECHAMBER_LAYOUT)
		Kind.BOSS_HALL:
			return _fixed_room(BOSS_HALL_SIZE, BOSS_HALL_ROOM, BOSS_HALL_PILLARS, BOSS_HALL_START, BOSS_HALL_THRONE, BOSS_HALL_LAYOUT)
	var grid: GridState
	var floors: Array[Vector2i] = []
	# Bounded retries prevent bad settings or unlucky seeds from hanging a run.
	for attempt in 8:
		grid = RoomGenerator.generate(settings, rng)
		floors = LayoutUtils.keep_largest_region(grid)
		if floors.size() >= 80:
			break
	if floors.size() < 80:
		# Repair a rare failed layout with a connected central space.
		LayoutUtils.carve_rect(grid, Rect2i(Vector2i(2, 2), grid.size - Vector2i(4, 4)))
		floors = LayoutUtils.keep_largest_region(grid)
	var house := Rect2i()
	var start := Vector2i(-1, -1)
	var stairs := start
	var distances: Dictionary = {}
	if not final_floor and floor_number % 10 != 0 and settings.monster_house_chance > 0.0 and rng.randf() < settings.monster_house_chance:
		# Rooms meet through single corridors, so a house can land on the only
		# way to the stairs. A start inside the house stays allowed (an intended
		# ambush); from a start outside it, the stairs must also lie outside and
		# a route must go around. Otherwise try elsewhere, then go without.
		var base_walls := grid.walls.duplicate()
		var base_pillars := grid.pillars.duplicate()
		var base_floors := floors.duplicate()
		for attempt in HOUSE_ATTEMPTS:
			var center := floors[rng.randi_range(0, floors.size() - 1)]
			var anchor := center
			center = center.clamp(Vector2i(4, 4), grid.size - Vector2i(5, 5))
			house = Rect2i(center - Vector2i(3, 3), Vector2i(7, 7))
			# Connect to the chosen floor even if clamping moved the room off that region.
			LayoutUtils.carve_corridor(grid, anchor, center)
			LayoutUtils.carve_rect(grid, house)
			floors = LayoutUtils.keep_largest_region(grid)
			start = floors[rng.randi_range(0, floors.size() - 1)]
			distances = LayoutUtils.distances(grid, start)
			stairs = _farthest(distances, start)
			if house.has_point(start) or (not house.has_point(stairs) and _bypasses(grid, start, stairs, house)):
				break
			grid.walls = base_walls.duplicate()
			grid.pillars = base_pillars.duplicate()
			floors = base_floors.duplicate()
			house = Rect2i()
			start = Vector2i(-1, -1)
	if not house.has_area():
		start = floors[rng.randi_range(0, floors.size() - 1)]
		distances = LayoutUtils.distances(grid, start)
		stairs = _farthest(distances, start)
	var candidates: Array[Vector2i] = []
	for cell in floors:
		if cell != start and cell != stairs and int(distances[cell]) >= clampi(settings.enemy_start_distance, 1, 12):
			candidates.append(cell)
	var enemies: Array[Vector2i] = []
	for index in mini(clampi(settings.enemy_count, 0, 20), candidates.size()):
		var selected := rng.randi_range(0, candidates.size() - 1)
		enemies.append(candidates[selected])
		candidates.remove_at(selected)
	var house_enemies: Array[Vector2i] = []
	var house_candidates: Array[Vector2i] = []
	for cell in floors:
		if house.has_point(cell) and cell != start and cell != stairs and cell not in enemies:
			house_candidates.append(cell)
	for index in mini(settings.monster_house_enemies, house_candidates.size()):
		var selected := rng.randi_range(0, house_candidates.size() - 1)
		house_enemies.append(house_candidates.pop_at(selected))
	return {"grid": grid, "start": start, "stairs": stairs, "enemies": enemies, "layout": ROOM_LAYOUT, "house": house, "house_enemies": house_enemies}


static func _farthest(distances: Dictionary, start: Vector2i) -> Vector2i:
	var farthest := start
	for cell: Vector2i in distances:
		if int(distances[cell]) > int(distances[farthest]):
			farthest = cell
	return farthest


# Whether start reaches goal without stepping inside the house.
static func _bypasses(grid: GridState, start: Vector2i, goal: Vector2i, house: Rect2i) -> bool:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		if cell == goal:
			return true
		for direction in LayoutUtils.DIRECTIONS:
			var next := cell + direction
			if not seen.has(next) and not house.has_point(next) and grid.can_step(cell, next):
				seen[next] = true
				queue.append(next)
	return false


# A hand-laid map: no random terrain, enemies or monster house. `goal` is the
# antechamber's door or the boss hall's throne.
static func _fixed_room(size: Vector2i, room: Rect2i, pillars: Array[Vector2i], start: Vector2i, goal: Vector2i, layout: String) -> Dictionary:
	var grid := LayoutUtils.solid_grid(size)
	LayoutUtils.carve_rect(grid, room)
	# The goal lies level with the entrance, on or beyond the room's right edge.
	LayoutUtils.carve_corridor(grid, Vector2i(room.end.x - 1, goal.y), goal)
	for cell in pillars:
		grid.walls[cell] = true
		grid.pillars[cell] = true
	var enemies: Array[Vector2i] = []
	return {"grid": grid, "start": start, "stairs": goal, "enemies": enemies, "layout": layout, "house": Rect2i(), "house_enemies": enemies.duplicate()}
