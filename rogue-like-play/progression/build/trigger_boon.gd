class_name TriggerBoon
extends BoonEffect

# Answers a fight event (CombatEvents) with a blow of its own: a blast in a
# circle, lightning chaining from foe to foe, or health back for the hero.
# It can ask that the foe carried a status, roll a chance, and rest between
# firings.

enum On { HIT, KILL, DASH_START, DASH_END, SKILL, HURT }
enum Action { BLAST, CHAIN, HEAL }
enum At { TARGET, HERO }

@export var on: On = On.KILL
# HIT and KILL: only when the foe carries this status.
@export var needs_status: StringName
@export_range(0.0, 1.0) var chance := 1.0
@export_range(0.0, 60.0) var cooldown := 0.0
@export var action: Action = Action.BLAST
@export var at: At = At.TARGET
# BLAST: its radius; CHAIN: how far each jump reaches.
@export_range(10.0, 1000.0) var radius := 90.0
# Of the hero's power, plus damage_per_rank for each rank past the first.
@export_range(0.0, 20.0) var damage_scale := 1.0
@export_range(0.0, 20.0) var damage_per_rank := 0.0
@export_range(0.0, 2000.0) var knockback := 200.0
# CHAIN: how many foes it jumps to, plus jumps_per_rank past the first rank.
@export_range(1, 50) var jumps := 3
@export_range(0, 10) var jumps_per_rank := 1
@export var inflicts: Array[StringName] = []
# HEAL: the health it gives back, plus heal_per_rank for each rank past the first.
@export_range(0, 100) var heal := 2
@export_range(0, 100) var heal_per_rank := 1
# The painted effect a blast shows (StrikeEffect kinds).
@export var effect: StringName = &"heavy"


func damage(rank: int) -> float:
	return damage_scale + damage_per_rank * (rank - 1)


func jump_count(rank: int) -> int:
	return jumps + jumps_per_rank * (rank - 1)


func heal_amount(rank: int) -> int:
	return heal + heal_per_rank * (rank - 1)
