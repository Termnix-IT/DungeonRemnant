class_name SkillNode
extends Resource

@export var id: StringName
@export var display_name: String
@export var effect: StringName
@export var amount: int = 1
@export var max_rank: int = 10
@export var base_cost: int = 100
@export var cost_step: int = 50
@export var prerequisite: StringName
@export var prerequisite_rank: int = 1

func price(rank: int) -> int:
	return base_cost + rank * cost_step if rank >= 0 and rank < max_rank else -1
