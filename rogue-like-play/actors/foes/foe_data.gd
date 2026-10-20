class_name FoeData
extends Resource

# An enemy of the real-time fight. Distances are world px, times seconds.

@export var id: StringName
@export var display_name := "敵"
# Which illustration rig draws it (EnemySprites.rig_path).
@export var visual_id := "basic"
@export_range(1, 100000) var max_hp := 30
@export_range(0, 1000) var defense := 0
@export_range(0.0, 1000.0) var speed := 95.0
@export_range(10.0, 20000.0) var acceleration := 900.0
# A walking speed picked per foe within this share either side of speed, so
# a crowd spreads out rather than marching in step.
@export_range(0.0, 0.5) var speed_spread := 0.12
@export_range(0, 10000) var contact_damage := 8
@export_range(0.0, 2000.0) var contact_knockback := 260.0
# The least time between two touches that hurt.
@export_range(0.05, 5.0) var contact_cooldown := 0.9
@export_range(4.0, 128.0) var hit_radius := 14.0
# How much of a blow's push it shrugs off, 0 to 1.
@export_range(0.0, 1.0) var knockback_resist := 0.0
# How long a hit stops it walking.
@export_range(0.0, 2.0) var hitstun := 0.22
@export_range(0, 10000) var exp_reward := 1
