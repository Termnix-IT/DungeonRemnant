class_name ProjectileData
extends Resource

# Something that flies on its own once sent: a wave from a swing. It hits
# each foe it passes over once and keeps going until its distance is spent.

@export_range(10.0, 5000.0) var speed := 700.0
@export_range(10.0, 5000.0) var distance := 360.0
# Its hit circle, world px.
@export_range(2.0, 300.0) var radius := 26.0
# Of the hero's power.
@export_range(0.0, 20.0) var damage_scale := 1.2
@export_range(0.0, 2000.0) var knockback := 200.0
@export var inflicts: Array[StringName] = []
# The painted effect it is drawn as (StrikeEffect kinds).
@export var effect: StringName = &"slash"
# How large it is drawn, world px across.
@export_range(10.0, 400.0) var size := 80.0
