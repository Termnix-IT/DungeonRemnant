class_name DungeonGenerator
extends RefCounted

const LAYOUT_NAMES := ["Room", "Cave", "OpenArea"]


static func generate(settings: DungeonSettings, floor_number: int, rng: RandomNumberGenerator) -> Dictionary:
	var layout := (floor_number - 1) % LAYOUT_NAMES.size()
	var grid: GridState
	var floors: Array[Vector2i] = []
	# Bounded retries prevent bad settings or unlucky seeds from hanging a run.
	for attempt in 8:
		match layout:
			0: grid = RoomGenerator.generate(settings, rng)
			1: grid = CaveGenerator.generate(settings, rng)
			2: grid = OpenAreaGenerator.generate(settings, rng)
		floors = LayoutUtils.keep_largest_region(grid)
		if floors.size() >= 80:
			break
	if floors.size() < 80:
		# Repair a rare failed layout with a connected central space.
		LayoutUtils.carve_rect(grid, Rect2i(Vector2i(2, 2), grid.size - Vector2i(4, 4)))
		floors = LayoutUtils.keep_largest_region(grid)
	var start := floors[rng.randi_range(0, floors.size() - 1)]
	var distances := LayoutUtils.distances(grid, start)
	var stairs := start
	for cell: Vector2i in distances:
		if int(distances[cell]) > int(distances[stairs]):
			stairs = cell
	var candidates: Array[Vector2i] = []
	for cell in floors:
		if cell != start and cell != stairs and int(distances[cell]) >= clampi(settings.enemy_start_distance, 1, 12):
			candidates.append(cell)
	var enemies: Array[Vector2i] = []
	for index in mini(clampi(settings.enemy_count, 0, 20), candidates.size()):
		var selected := rng.randi_range(0, candidates.size() - 1)
		enemies.append(candidates[selected])
		candidates.remove_at(selected)
	return {"grid": grid, "start": start, "stairs": stairs, "enemies": enemies, "layout": LAYOUT_NAMES[layout]}
