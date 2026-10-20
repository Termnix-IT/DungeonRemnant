class_name MioAnimation
extends RefCounted

# The hero's eight facings: their names (as the rig's facings are named) and
# the grid directions they face.
const DIRECTIONS: Array[StringName] = [&"front", &"back", &"left", &"right",
	&"front_left", &"front_right", &"back_left", &"back_right"]
const FACINGS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT,
	Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1)]


static func direction_name(facing: Vector2i) -> StringName:
	if facing.x != 0 and facing.y != 0:
		if facing.y > 0:
			return &"front_left" if facing.x < 0 else &"front_right"
		return &"back_left" if facing.x < 0 else &"back_right"
	if facing.y > 0 and absi(facing.y) >= absi(facing.x):
		return &"front"
	if facing.y < 0 and absi(facing.y) >= absi(facing.x):
		return &"back"
	if facing.x < 0:
		return &"left"
	return &"right"
