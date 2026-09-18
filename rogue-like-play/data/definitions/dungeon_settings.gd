class_name DungeonSettings
extends Resource

@export_range(1, 10000) var floor_turn_limit: int = 5000
@export_range(0, 1000) var boss_grace_turns: int = 150

@export_range(0.0, 1.0) var scroll_drop_chance: float = 0.02
@export_range(0.0, 1.0) var elite_chance: float = 0.08
@export_range(0.0, 1.0) var accessory_drop_chance: float = 0.15
@export_range(0.0, 1.0) var monster_house_chance: float = 0.0
@export_range(1, 20) var monster_house_enemies: int = 8
@export_range(1, 20) var monster_house_items: int = 8

@export_range(20, 60) var width: int = 40
@export_range(20, 60) var height: int = 40
@export_range(0, 20) var enemy_count: int = 3
@export_range(0, 20) var item_count: int = 6
@export_range(1, 12) var enemy_start_distance: int = 6
@export_range(4, 16) var room_count: int = 9
@export_range(0.35, 0.55) var cave_wall_chance: float = 0.45
@export_range(0.02, 0.2) var obstacle_chance: float = 0.08
@export_range(1, 100) var reinforcement_interval: int = 18
@export_range(0.0, 1.0) var reinforcement_chance: float = 0.65
@export_range(0, 20) var reinforcement_alive_cap: int = 5
@export_range(0, 20) var reinforcement_total_cap: int = 4
@export_range(1, 20) var reinforcement_min_distance: int = 6


func map_size() -> Vector2i:
	return Vector2i(clampi(width, 20, 60), clampi(height, 20, 60))

@export var forest := false
@export var depth_scaling := false
@export_range(0, 10) var difficulty_offset: int = 0
@export var depth_hp_step: int = 5
@export var depth_attack_step: int = 2
@export var depth_defense_step: int = 1
