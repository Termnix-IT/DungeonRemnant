class_name FoeData
extends Resource

# An enemy of the real-time fight. Distances are world px, times seconds.

@export var id: StringName
@export var display_name := "敵"
# Which illustration rig draws it (EnemySprites.rig_path).
@export var visual_id := "basic"
# Drawn from its rig baked into frames (FoeFrames), for foes that come in
# crowds; otherwise the rig itself is drawn.
@export var baked := false
# How much larger than its rig's own size it is drawn (and its body made).
@export_range(0.5, 4.0) var size_scale := 1.0
# An elite wears a ring at its feet and a health bar over its head.
@export var elite := false
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
# How long a hit stops it walking. Zero is super armour: a hit never stops
# it, nor breaks off the wind-up of its attack.
@export_range(0.0, 2.0) var hitstun := 0.22
@export_range(0, 10000) var exp_reward := 1
# Its attacks, each with the range it is used at (AttackData.use_from and
# use_until); the first that fits is used. None: it only chases and touches.
@export var attacks: Array[AttackData] = []
# A swing's damage before its AttackData.damage_scale.
@export_range(0.0, 10000.0) var power := 10.0
# The least time from the end of one attack to the start of the next.
@export_range(0.0, 20.0) var attack_cooldown := 1.0
