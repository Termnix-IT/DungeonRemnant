class_name RoomGenerator
extends RefCounted


static func generate(settings: DungeonSettings, rng: RandomNumberGenerator) -> GridState:
	var grid := LayoutUtils.solid_grid(settings.map_size())
	var rooms: Array[Rect2i] = []
	for attempt in 100:
		var room_size := Vector2i(rng.randi_range(4, 8), rng.randi_range(4, 8))
		var origin := Vector2i(rng.randi_range(1, grid.size.x - room_size.x - 1), rng.randi_range(1, grid.size.y - room_size.y - 1))
		var room := Rect2i(origin, room_size)
		var overlaps := false
		for existing in rooms:
			if existing.grow(1).intersects(room):
				overlaps = true
				break
		if overlaps:
			continue
		LayoutUtils.carve_rect(grid, room)
		if not rooms.is_empty():
			var from: Vector2i = rooms.back().get_center()
			var to := room.get_center()
			if rng.randf() < 0.5:
				LayoutUtils.carve_corridor(grid, from, to)
			else:
				LayoutUtils.carve_corridor(grid, to, from)
		rooms.append(room)
		if rooms.size() >= clampi(settings.room_count, 4, 16):
			break
	return grid
