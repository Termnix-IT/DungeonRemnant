class_name HitQuery
extends RefCounted

# Which targets an attack's shape touches, worked out from positions alone:
# no Area2D per swing, so the hit never waits on the physics step or on
# what is drawn. A target is a circle (its position and radius); it is hit
# when any part of that circle is inside the shape.


static func touches(attack: AttackData, origin: Vector2, facing: Vector2, point: Vector2, radius: float = 0.0) -> bool:
	var offset := point - origin
	match attack.shape:
		AttackData.Shape.CIRCLE:
			return offset.length() <= attack.reach + radius
		AttackData.Shape.LINE:
			var along := facing.normalized()
			var forward := offset.dot(along)
			var side := absf(offset.cross(along))
			return forward >= -radius and forward <= attack.reach + radius and side <= attack.width * 0.5 + radius
	# ARC: within reach, and within the opening angle widened by the
	# target's own size seen from the attacker.
	var distance := offset.length()
	if distance > attack.reach + radius:
		return false
	if distance <= radius:
		return true
	var half := deg_to_rad(attack.arc_degrees) * 0.5 + asin(clampf(radius / distance, 0.0, 1.0))
	return absf(facing.angle_to(offset)) <= half


# The targets (Node2D with a `hit_radius`) the shape touches, in the order
# given, leaving out any already in `spent`.
static func targets(attack: AttackData, origin: Vector2, facing: Vector2, candidates: Array, spent: Dictionary = {}) -> Array:
	var found := []
	# Untyped: a freed target cannot be held in a typed variable.
	for target in candidates:
		if not is_instance_valid(target) or spent.has(target):
			continue
		var radius: Variant = target.get(&"hit_radius")
		if touches(attack, origin, facing, target.global_position, float(radius) if radius != null else 0.0):
			found.append(target)
	return found
