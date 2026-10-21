class_name QuietWindowStyle
extends StyleBox

# The surface of a popup window: a dark see-through face, a hairline edge
# round it, and a gold line along its top that fades towards both ends, the
# only ornament. A soft shadow below lifts it off what it covers.

const SHADOW_STEPS := 6

@export var fill := Color(0.045, 0.05, 0.058, 0.94)
@export var edge := Color(0.32, 0.31, 0.29, 0.6)
@export var accent := Color(0.84, 0.72, 0.48, 0.9)
@export var accent_width := 2.0
@export var shadow := Color(0, 0, 0, 0.4)
@export var shadow_size := 16.0


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(shadow_size)


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var server := RenderingServer
	# The shadow: rings that fade outward, offset a little downward.
	for step in SHADOW_STEPS:
		var reach := shadow_size * float(SHADOW_STEPS - step) / SHADOW_STEPS
		var alpha := shadow.a * float(step + 1) / SHADOW_STEPS / SHADOW_STEPS * 2.0
		server.canvas_item_add_rect(to_canvas_item, rect.grow(reach).grow_side(SIDE_TOP, -reach * 0.5), Color(shadow, alpha))
	server.canvas_item_add_rect(to_canvas_item, rect, fill)
	# The hairline edge.
	for line: Rect2 in [Rect2(rect.position, Vector2(rect.size.x, 1)), Rect2(Vector2(rect.position.x, rect.end.y - 1), Vector2(rect.size.x, 1)),
			Rect2(rect.position, Vector2(1, rect.size.y)), Rect2(Vector2(rect.end.x - 1, rect.position.y), Vector2(1, rect.size.y))]:
		server.canvas_item_add_rect(to_canvas_item, line, edge)
	# The gold line along the top, bright in the middle.
	var top := rect.position.y + accent_width * 0.5
	var points := PackedVector2Array([Vector2(rect.position.x, top), Vector2(rect.get_center().x, top), Vector2(rect.end.x, top)])
	var colors := PackedColorArray([Color(accent, accent.a * 0.15), accent, Color(accent, accent.a * 0.15)])
	server.canvas_item_add_polyline(to_canvas_item, points, colors, accent_width)
