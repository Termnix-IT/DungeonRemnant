class_name RouteSigns
extends RefCounted

# The small signs the route's choice tells an area by, drawn the same under
# a gate (RouteGates) and on the tablet over the hall (RouteTablet): a
# boon's star, a heal's heart, the echo's ring, an event's lozenge with a
# dot, and danger's lozenges.

# A lozenge, filled or (with a width) in outline.
static func lozenge(canvas: CanvasItem, centre: Vector2, radius: float, colour: Color, width := 0.0) -> void:
	var points := PackedVector2Array([centre + Vector2(0.0, -radius), centre + Vector2(radius, 0.0), centre + Vector2(0.0, radius), centre + Vector2(-radius, 0.0)])
	if width <= 0.0:
		canvas.draw_colored_polygon(points, colour)
	else:
		points.append(points[0])
		canvas.draw_polyline(points, colour, width, true)


# A reward's sign; an event (reward -1) a lozenge with a dot.
static func reward(canvas: CanvasItem, centre: Vector2, radius: float, what: int, colour: Color) -> void:
	match what:
		AreaData.Reward.BOON:
			HubUI.star(canvas, centre, radius * 1.25, colour)
		AreaData.Reward.HEAL:
			var points := PackedVector2Array()
			for step in 32:
				var t := TAU * step / 32.0
				points.append(centre + Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * radius / 16.0 + Vector2(0.0, -radius * 0.12))
			canvas.draw_colored_polygon(points, colour)
		AreaData.Reward.ECHO:
			canvas.draw_arc(centre, radius * 0.92, 0.0, TAU, 24, colour, maxf(1.5, radius * 0.22), true)
			canvas.draw_circle(centre, radius * 0.36, colour)
		_:
			lozenge(canvas, centre, radius, colour, maxf(1.5, radius * 0.2))
			canvas.draw_circle(centre, radius * 0.22, colour)
