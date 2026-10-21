class_name Moveset
extends Resource

# What a weapon does in real time: the normal attack's combo, swing by swing,
# the charged attack let loose after holding the strike, and the skill.

@export var display_name := "剣"
@export var combo: Array[AttackData] = []
@export var charged: AttackData
# How long the strike is held, counted from the press, before the charged
# attack is ready.
@export_range(0.1, 3.0) var charge_time := 0.75
# After a swing ends, how long a new strike still continues the combo
# rather than starting it over.
@export_range(0.0, 1.0) var combo_grace := 0.25
# The active skill (skill_1), and how long it takes to come back.
@export var skill: AttackData
@export_range(0.0, 120.0) var skill_cooldown := 6.0
