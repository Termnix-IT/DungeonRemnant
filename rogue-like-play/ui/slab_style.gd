class_name SlabStyle
extends StyleBox

# The dark slab behind a hub page's columns. `horizontal` is its colour and
# opacity from its left edge to its right (a short fade makes the lobby
# menu's melting edge); above and below, the slab thins out over `feather`
# pixels, outside the layout rect, so the hall is not cut by a straight line
# where the slab begins. The text inside stays on the fully opaque part.

const COLUMNS := 32
# Steps of each fade: the smoothstep is drawn in this many strips.
const FEATHER_STEPS := 5

@export var horizontal: Gradient
@export var feather := 48.0
@export var expand_left := 0.0
@export var expand_right := 0.0


func _get_draw_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position - Vector2(expand_left, feather), rect.size + Vector2(expand_left + expand_right, feather * 2.0))


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if horizontal == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var left := rect.position.x - expand_left
	var width := rect.size.x + expand_left + expand_right
	# Rows from the outer top edge to the outer bottom edge: [y, opacity].
	var rows: Array[Vector2] = []
	for step in FEATHER_STEPS:
		var along := float(step) / FEATHER_STEPS
		rows.append(Vector2(rect.position.y - feather * (1.0 - along), along * along * (3.0 - 2.0 * along)))
	rows.append(Vector2(rect.position.y, 1.0))
	rows.append(Vector2(rect.end.y, 1.0))
	for step in range(1, FEATHER_STEPS + 1):
		var along := float(step) / FEATHER_STEPS
		rows.append(Vector2(rect.end.y + feather * along, 1.0 - along * along * (3.0 - 2.0 * along)))
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for row in rows:
		for column in COLUMNS + 1:
			var across := float(column) / COLUMNS
			var color := horizontal.sample(across)
			color.a *= row.y
			points.append(Vector2(left + width * across, row.x))
			colors.append(color)
	var indices := PackedInt32Array()
	for row in rows.size() - 1:
		for column in COLUMNS:
			var a := row * (COLUMNS + 1) + column
			var b := a + 1
			var c := a + COLUMNS + 1
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])
	RenderingServer.canvas_item_add_triangle_array(to_canvas_item, indices, points, colors)
