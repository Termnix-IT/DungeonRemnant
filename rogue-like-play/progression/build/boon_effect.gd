class_name BoonEffect
extends Resource

# One thing a BoonData does. Three kinds: StatBoon (adds to a number),
# AttackBoon (changes a swing as it starts) and TriggerBoon (answers a fight
# event with a blast or a chain). Each answers only the questions its kind
# is asked; these defaults answer "nothing".


# How much it adds to a stat at this rank.
func stat(_name: StringName, _rank: int) -> float:
	return 0.0


# What raising its boon from `rank` to the next changes, as short parts
# ("威力 135% → 155%"); empty when no number of its own changes.
func gains(_rank: int) -> Array[String]:
	return []
