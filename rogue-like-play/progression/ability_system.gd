class_name AbilitySystem
extends RefCounted

var definitions: Array[AbilityData] = [
	preload("res://data/abilities/max_hp.tres"),
	preload("res://data/abilities/attack.tres"),
	preload("res://data/abilities/defense.tres"),
	preload("res://data/abilities/sword_damage.tres"),
	preload("res://data/abilities/spear_damage.tres"),
	preload("res://data/abilities/hammer_damage.tres"),
	preload("res://data/abilities/spear_range.tres"),
	preload("res://data/abilities/spear_pierce.tres"),
	preload("res://data/abilities/vision.tres"),
	preload("res://data/abilities/kill_heal.tres"),
]
var levels: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func level_of(ability: AbilityData) -> int:
	return int(levels.get(ability.id, 0))


func upgrade(ability: AbilityData) -> bool:
	if ability not in definitions or level_of(ability) >= ability.max_level:
		return false
	levels[ability.id] = level_of(ability) + 1
	return true


func total(effect: AbilityData.Effect) -> int:
	var result := 0
	for ability in definitions:
		if ability.effect == effect:
			result += level_of(ability) * ability.amount
	return result


func offer() -> Array[AbilityData]:
	var candidates: Array[AbilityData] = []
	for ability in definitions:
		if level_of(ability) < ability.max_level:
			candidates.append(ability)
	var result: Array[AbilityData] = []
	while result.size() < 3 and not candidates.is_empty():
		var index := rng.randi_range(0, candidates.size() - 1)
		result.append(candidates[index])
		candidates.remove_at(index)
	return result
