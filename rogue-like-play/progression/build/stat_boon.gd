class_name StatBoon
extends BoonEffect

# Adds to one of the build's stats per rank. Stats read by the fight:
# attack_speed (swings this much faster), charge_time (the charge this much
# shorter when negative), damage (the hero's power this much higher),
# move_speed (she walks this much faster), skill_cooldown (her
# skills rest this much less when negative).

@export var stat_name: StringName
@export var per_rank := 0.1


func stat(name: StringName, rank: int) -> float:
	return per_rank * rank if name == stat_name else 0.0
