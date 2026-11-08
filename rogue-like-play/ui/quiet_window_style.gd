class_name QuietWindowStyle
extends StyleBox

# The quiet surface of a popup window and of a hub page's main panel: a dark
# see-through face and a hairline edge, with no ornament (no gold line along
# its top, which reads as a web page's card). A soft shadow below lifts it
# off what it covers. A page's two columns are one panel: each draws only its
# own edges (`sides`).

const SHADOW_STEPS := 6
const SIDE_LEFT := 1
const SIDE_TOP := 2
const SIDE_RIGHT := 4
const SIDE_BOTTOM := 8

@export var fill := Color(0.045, 0.05, 0.058, 0.94)
@export var edge := Color(0.32, 0.31, 0.29, 0.6)
@export_flags("Left", "Top", "Right", "Bottom") var sides := 15
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
	# The hairline edges it owns.
	var lines := {
		SIDE_LEFT: Rect2(rect.position, Vector2(1, rect.size.y)),
		SIDE_TOP: Rect2(rect.position, Vector2(rect.size.x, 1)),
		SIDE_RIGHT: Rect2(Vector2(rect.end.x - 1, rect.position.y), Vector2(1, rect.size.y)),
		SIDE_BOTTOM: Rect2(Vector2(rect.position.x, rect.end.y - 1), Vector2(rect.size.x, 1)),
	}
	for side: int in lines:
		if sides & side:
			server.canvas_item_add_rect(to_canvas_item, lines[side], edge)
