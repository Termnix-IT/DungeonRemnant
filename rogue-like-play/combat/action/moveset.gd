class_name Moveset
extends Resource

# What a weapon does in real time: the normal attack's combo, swing by swing,
# the charged attack let loose after holding the strike, and the skill; and
# how the screens and her hand show it. The sword is held from the start;
# the others are learned on the upgrade tree's weapon branch and set in the
# status page's attack slot (MetaProgress.weapon).

@export var id: StringName
@export var display_name := "剣"
@export_multiline var description := ""
# Its medallion (EmblemIcons key).
@export var emblem := "sword_damage"
@export var owned_from_start := true
# Its picture in her hand in place of the rig's sword (WeaponMount), upright
# with its head at the top; none keeps the sword. The hand holds it at
# art_grip of its height from the head, and it is art_length times as long
# as the sword.
@export var art: Texture2D
@export_range(0.0, 1.0) var art_grip := 0.8
@export_range(0.2, 4.0) var art_length := 1.0
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
