class_name AttackBoon
extends BoonEffect

# Changes a swing as it starts, when the swing is of the kind it watches for:
# a status it leaves, a wider or longer shape, more damage, a wave sent
# flying. BuildState.shape hands it its own copy of the swing to change.

enum When { ANY, SWINGS, COMBO_STEP, AFTER_DASH, CHARGED, SKILL }

@export var when: When = When.ANY
# COMBO_STEP: which swing of the combo (0 is the first).
@export var combo_step := 0
# AFTER_DASH: how long after a dash ends, in seconds.
@export var window := 0.6
@export var inflict: StringName
# Multiplies the reach, plus reach_per_rank for each rank past the first.
@export var reach_scale := 1.0
@export var reach_per_rank := 0.0
# Above zero: the opening becomes this (ARC swings).
@export var arc_degrees := 0.0
@export var damage_scale := 1.0
# Added to damage_scale for each rank past the first.
@export var damage_per_rank := 0.0
@export var projectile: ProjectileData
# Added to the wave's distance for each rank past the first.
@export var distance_per_rank := 0.0
# Replaces the painted effect, if set.
@export var effect: StringName


# Whether it changes a swing of this kind (BuildState's: combo, charged,
# skill), at this combo step, this long after a dash.
func applies(kind: StringName, combo_index: int, since_dash: float) -> bool:
	match when:
		When.SWINGS:
			return kind != &"skill"
		When.COMBO_STEP:
			return kind == &"combo" and combo_index == combo_step
		When.AFTER_DASH:
			return kind != &"skill" and since_dash <= window
		When.CHARGED:
			return kind == &"charged"
		When.SKILL:
			return kind == &"skill"
	return true


func change(attack: AttackData, rank: int) -> void:
	if not inflict.is_empty() and inflict not in attack.inflicts:
		attack.inflicts.append(inflict)
	attack.reach *= reach_scale + reach_per_rank * (rank - 1)
	if arc_degrees > 0.0:
		attack.arc_degrees = maxf(attack.arc_degrees, arc_degrees)
	attack.damage_scale *= damage_scale + damage_per_rank * (rank - 1)
	if not effect.is_empty():
		attack.effect = effect
	if projectile != null:
		var wave: ProjectileData = projectile.duplicate()
		wave.distance += distance_per_rank * (rank - 1)
		attack.projectile = wave
