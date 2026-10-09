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
# Optional dressing over the slab; all off by default, which keeps the plain
# melting slab. A grain texture tiled over the opaque part, multiplied by
# grain_tint: its colour takes the texture's mid grey down to the slab's
# darkness and its alpha is how much of the face is the texture
# (art/ui/slab_stone.png, from tools/build_slab_texture.py); a soft light down
# from the top edge;
# bronze rails along the chosen edges (RAIL_* flags), fading at both ends, with
# a diamond stud at the middle of each.
const RAIL_TOP := 1
const RAIL_BOTTOM := 2
const RAIL_LEFT := 4
const RAIL_RIGHT := 8
@export var grain: Texture2D
@export var grain_tint := Color(1, 1, 1, 0)
@export var top_light := 0.0
@export var top_light_depth := 0.35
@export_flags("Top", "Bottom", "Left", "Right") var rail_edges := 0
@export var rail_color := Color(0.72, 0.58, 0.36, 0.0)
@export var rail_inset := 0.0


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
	var body := Rect2(left, rect.position.y, width, rect.size.y)
	if grain != null and grain_tint.a > 0.0:
		RenderingServer.canvas_item_add_texture_rect(to_canvas_item, body, grain.get_rid(), true, grain_tint)
	if top_light > 0.0:
		var depth := body.size.y * top_light_depth
		var lit := Color(1.0, 0.86, 0.62, top_light)
		var dark := Color(lit, 0.0)
		RenderingServer.canvas_item_add_polygon(to_canvas_item, PackedVector2Array([body.position, Vector2(body.end.x, body.position.y), Vector2(body.end.x, body.position.y + depth), Vector2(body.position.x, body.position.y + depth)]), PackedColorArray([lit, lit, dark, dark]))
	if rail_edges != 0 and rail_color.a > 0.0:
		var inner := body.grow(-rail_inset)
		if rail_edges & RAIL_TOP:
			_rail(to_canvas_item, inner.position, Vector2(inner.end.x, inner.position.y))
		if rail_edges & RAIL_BOTTOM:
			_rail(to_canvas_item, Vector2(inner.position.x, inner.end.y), inner.end)
		if rail_edges & RAIL_LEFT:
			_rail(to_canvas_item, inner.position, Vector2(inner.position.x, inner.end.y))
		if rail_edges & RAIL_RIGHT:
			_rail(to_canvas_item, Vector2(inner.end.x, inner.position.y), inner.end)


# A hairline that fades in from both ends, with a diamond at its middle.
func _rail(canvas: RID, from: Vector2, to: Vector2) -> void:
	var clear := Color(rail_color, 0.0)
	var points := PackedVector2Array([from, from.lerp(to, 0.18), from.lerp(to, 0.82), to])
	RenderingServer.canvas_item_add_polyline(canvas, points, PackedColorArray([clear, rail_color, rail_color, clear]), 1.0, true)
	var middle := from.lerp(to, 0.5)
	var stud := Color(rail_color, minf(1.0, rail_color.a * 1.6))
	RenderingServer.canvas_item_add_polygon(canvas, PackedVector2Array([middle + Vector2(0, -4), middle + Vector2(4, 0), middle + Vector2(0, 4), middle + Vector2(-4, 0)]), PackedColorArray([stud, stud, stud, stud]))
