class_name StatBoon
extends BoonEffect

# Adds to one of the build's stats per rank. Stats read by the fight:
# attack_speed (swings this much faster), charge_time (the charge this much
# shorter when negative), damage (the hero's power this much higher),
# move_speed (she walks this much faster), skill_cooldown (her
# skills rest this much less when negative).

@export var stat_name: StringName
@export var per_rank := 0.1

# What each stat is called on a card.
const NAMES := {&"attack_speed": "振りの速さ", &"charge_time": "溜め時間", &"damage": "攻撃力", &"move_speed": "移動速度", &"skill_cooldown": "スキルの再使用"}


func stat(name: StringName, rank: int) -> float:
	return per_rank * rank if name == stat_name else 0.0


func gains(rank: int) -> Array[String]:
	if is_zero_approx(per_rank) or not NAMES.has(stat_name):
		return []
	return ["%s %+d%% → %+d%%" % [NAMES[stat_name], roundi(per_rank * rank * 100.0), roundi(per_rank * (rank + 1) * 100.0)]]
