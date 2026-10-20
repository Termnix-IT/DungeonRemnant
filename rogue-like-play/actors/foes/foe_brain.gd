class_name FoeBrain
extends RefCounted

# How a foe means to move, as a velocity it walks towards. This one chases
# straight at its target; the other kinds (rushers, shooters, elites) extend
# it in Phase 2.


func steer(position: Vector2, target: Vector2, speed: float) -> Vector2:
	var offset := target - position
	if offset.length() < 1.0:
		return Vector2.ZERO
	return offset.normalized() * speed
