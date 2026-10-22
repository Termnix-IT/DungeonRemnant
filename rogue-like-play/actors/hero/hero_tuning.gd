class_name HeroTuning
extends Resource

# How the hero moves and holds up in real time. Distances are world px (she
# stands 64 tall), times are seconds.

@export_range(50.0, 800.0) var max_speed := 250.0
@export_range(100.0, 20000.0) var acceleration := 2600.0
@export_range(100.0, 20000.0) var deceleration := 3200.0
@export_range(20.0, 600.0) var dash_distance := 150.0
@export_range(0.05, 1.0) var dash_time := 0.17
# Untouchable from the dash's start for this long; a little past its end, so
# a dash through a blow reads as safe.
@export_range(0.0, 1.0) var dash_invulnerable := 0.22
# How long one spent dash takes to come back, counted after the dash ends.
@export_range(0.0, 3.0) var dash_cooldown := 0.45
@export_range(1, 5) var dash_charges := 1
# A strike or dash pressed while busy is kept this long.
@export_range(0.0, 0.5) var input_buffer := 0.18
# Walking speed while holding a charge, as a share of max_speed.
@export_range(0.0, 1.0) var charge_move_scale := 0.35
# How fast a push from a blow dies away (per second).
@export_range(1.0, 60.0) var push_decay := 10.0
@export_range(1, 10000) var max_hp := 100
@export_range(0, 1000) var defense := 0
# A normal swing's damage before its AttackData.damage_scale.
@export_range(1.0, 10000.0) var power := 10.0
# Untouchable for this long after being hurt.
@export_range(0.0, 3.0) var hurt_mercy := 0.8
@export_range(4.0, 64.0) var hit_radius := 14.0
# How her special move's gauge fills: for each blow of hers that lands, each
# foe felled, and each point of health a foe's blow takes.
@export_range(0.0, 20.0) var special_per_hit := 0.4
@export_range(0.0, 20.0) var special_per_kill := 1.0
@export_range(0.0, 20.0) var special_per_hurt := 0.8
