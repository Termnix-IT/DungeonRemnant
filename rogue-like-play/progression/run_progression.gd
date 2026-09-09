class_name RunProgression
extends RefCounted

const MAX_LEVEL := 100
var settings: LevelSettings = preload("res://data/progression/levels.tres")
var level := 1
var exp := 0
var pending_choices := 0


func gain_exp(amount: int) -> void:
	if amount <= 0 or level >= MAX_LEVEL:
		return
	exp += amount
	while level < MAX_LEVEL and exp >= settings.required_exp(level):
		exp -= settings.required_exp(level)
		level += 1
		pending_choices += 1
	if level == MAX_LEVEL:
		exp = 0


func required_exp() -> int:
	return settings.required_exp(level) if level < MAX_LEVEL else 0
