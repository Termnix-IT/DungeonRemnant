class_name DungeonSettings
extends Resource

@export_range(20, 60) var width: int = 40
@export_range(20, 60) var height: int = 40
@export_range(0, 20) var enemy_count: int = 3
@export_range(0, 20) var item_count: int = 6
@export_range(1, 12) var enemy_start_distance: int = 6
@export_range(4, 16) var room_count: int = 9
@export_range(0.35, 0.55) var cave_wall_chance: float = 0.45
@export_range(0.02, 0.2) var obstacle_chance: float = 0.08


func map_size() -> Vector2i:
	return Vector2i(clampi(width, 20, 60), clampi(height, 20, 60))
