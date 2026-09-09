class_name PermanentUpgrade
extends Resource

@export var display_name := "最大HP強化"
@export_range(1, 10) var hp_per_level := 1
@export var costs: Array[int] = [30, 60, 90]


func price(level: int) -> int:
	return costs[level] if level >= 0 and level < costs.size() else -1


func hp_bonus(level: int) -> int:
	return clampi(level, 0, costs.size()) * hp_per_level
