class_name AttackData
extends Resource

# One swing of the real-time combat: where it hits and when. The hit is
# decided only by these numbers (HitQuery and the attacker's clock), never by
# the animation, so a character's drawing can change without changing the
# fight. Times are seconds from the swing's start.

enum Shape { ARC, CIRCLE, LINE }

@export var shape: Shape = Shape.ARC
# How far the shape reaches from the attacker's feet, in world px (the hero
# stands 64 tall).
@export_range(8.0, 600.0) var reach := 90.0
# ARC: the whole opening angle, in degrees.
@export_range(10.0, 360.0) var arc_degrees := 120.0
# LINE: the line's full width.
@export_range(4.0, 300.0) var width := 40.0
@export_range(0.0, 2.0) var windup := 0.06
@export_range(0.01, 2.0) var active := 0.08
@export_range(0.0, 2.0) var recovery := 0.2
# From this time on, a buffered strike starts the next swing of the combo.
@export_range(0.0, 2.0) var combo_after := 0.18
# From this time on, a dash cuts the rest of the swing short.
@export_range(0.0, 2.0) var dash_after := 0.1
@export_range(0.0, 10.0) var damage_scale := 1.0
# The push given to what it hits, in world px per second.
@export_range(0.0, 2000.0) var knockback := 260.0
@export_range(0.0, 0.2) var hit_stop := 0.04
# The attacker's own walking speed while swinging, as a share of normal.
@export_range(0.0, 1.0) var move_scale := 0.25
# How far the swing carries the attacker forward over its active time.
@export_range(0.0, 200.0) var lunge := 14.0
# The painted effect it shows (StrikeEffect kinds: slash, heavy, thrust...).
@export var effect: StringName = &"slash"
# Lightning, fire...; empty is a plain blow. Read by later effects.
@export var element: StringName
# A foe's attack only: the distances to the hero (world px, feet to feet) at
# which it chooses this one. Its wind-up is the warning drawn on the floor.
@export_range(0.0, 2000.0) var use_from := 0.0
@export_range(0.0, 2000.0) var use_until := 0.0


func duration() -> float:
	return windup + active + recovery


# Whether, at this time into the swing, its shape can hit.
func hitting(time: float) -> bool:
	return time >= windup and time < windup + active
