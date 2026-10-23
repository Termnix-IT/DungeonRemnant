class_name TickSmoothing
extends RefCounted

# Bodies move only on physics frames (60 a second) while the screen may draw
# far more often (a 240 Hz monitor draws four frames to each), so a body
# drawn where it stands jumps every few frames and, with the camera gliding
# after it, looks shaken and blurred. What draws a body is instead offset by
# lag(): from where the body stands back towards where it stood at the start
# of the last physics frame, by the share of the next physics frame still to
# come. The picture trails the body by at most one physics frame and moves
# every drawn frame. Only the drawing moves; hits are measured at the body.


# The offset from `now` (where the body stands) to where it is drawn, given
# `before` (where it stood as the last physics frame began).
static func lag(before: Vector2, now: Vector2) -> Vector2:
	return (before - now) * (1.0 - Engine.get_physics_interpolation_fraction())
