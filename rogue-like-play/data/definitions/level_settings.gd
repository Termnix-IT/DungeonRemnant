class_name LevelSettings
extends Resource

@export_range(1, 1000) var base_exp: int = 10
@export_range(0, 1000) var exp_per_level: int = 2


func required_exp(level: int) -> int:
	return maxi(1, base_exp + (level - 1) * exp_per_level)
