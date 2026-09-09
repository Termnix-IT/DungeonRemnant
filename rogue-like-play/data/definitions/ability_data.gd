class_name AbilityData
extends Resource

enum Effect { MAX_HP, ATTACK, DEFENSE, SWORD_DAMAGE, SPEAR_DAMAGE, HAMMER_DAMAGE, SPEAR_RANGE, SPEAR_PIERCE, VISION, KILL_HEAL }

@export var id: StringName
@export var display_name: String
@export var description: String
@export var effect: Effect
@export var amount: int = 1
@export_range(1, 10) var max_level: int = 5


func effect_description() -> String:
	return description.format({"amount": amount})
