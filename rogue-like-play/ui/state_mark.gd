class_name StateMark
extends RefCounted

# The two small marks that say a choice's state before it is chosen: a
# padlock on what cannot be had yet, and a gold diamond on what can be had
# right now. Both are drawn, not textured, so they stay crisp at any scale
# and need no art.


# A padlock centred on centre, height tall: the shackle's arch over a body.
static func lock(canvas: CanvasItem, centre: Vector2, height: float, tone: Color) -> void:
	var width := height * 0.74
	var body := Rect2(centre.x - width * 0.5, centre.y - height * 0.06, width, height * 0.56)
	var arch := width * 0.3
	var stroke := maxf(1.5, height * 0.12)
	canvas.draw_arc(Vector2(centre.x, body.position.y), arch, PI, TAU, 12, tone, stroke, true)
	for side in [-1.0, 1.0]:
		var x: float = centre.x + side * arch
		canvas.draw_line(Vector2(x, body.position.y - 0.5), Vector2(x, body.position.y + 1.0), tone, stroke, true)
	canvas.draw_rect(body, tone)


# A gold diamond with a dark rim, so it reads on the dark discs and on the
# warm selection band alike.
static func ready(canvas: CanvasItem, centre: Vector2, radius: float, tone: Color) -> void:
	var rim := radius + 1.5
	canvas.draw_colored_polygon(PackedVector2Array([centre + Vector2(0, -rim), centre + Vector2(rim, 0), centre + Vector2(0, rim), centre + Vector2(-rim, 0)]), Color(0, 0, 0, 0.75))
	canvas.draw_colored_polygon(PackedVector2Array([centre + Vector2(0, -radius), centre + Vector2(radius, 0), centre + Vector2(0, radius), centre + Vector2(-radius, 0)]), tone)
