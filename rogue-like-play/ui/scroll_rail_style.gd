class_name ScrollRailStyle
extends StyleBox

# The scroll bars in the hall's own manner rather than a grey rounded bar:
# the track is a dark groove with a bronze hairline down its middle that
# fades out at both ends, like the slabs' rails; the grabber is a slim bronze
# rod with a gilt edge and a diamond stud at each end. One style draws either,
# along the longer side of its rect, so the same resource serves the vertical
# and the horizontal bar.

@export var grabber := false
# The rail or the rod's edge.
@export var edge := Color(0.72, 0.58, 0.36, 0.45)
# The groove's or the rod's body.
@export var body := Color(0.02, 0.018, 0.016, 0.5)
# Thickness of the groove or the rod across the bar.
@export var thickness := 4.0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var vertical := rect.size.y >= rect.size.x
	var across := minf(thickness, rect.size.x if vertical else rect.size.y)
	var middle := rect.get_center()
	var core := Rect2(Vector2(middle.x - across * 0.5, rect.position.y), Vector2(across, rect.size.y)) if vertical else Rect2(Vector2(rect.position.x, middle.y - across * 0.5), Vector2(rect.size.x, across))
	if grabber:
		_rod(to_canvas_item, core, vertical)
	else:
		_groove(to_canvas_item, core, vertical)


func _groove(canvas: RID, core: Rect2, vertical: bool) -> void:
	RenderingServer.canvas_item_add_rect(canvas, core, body)
	var start := Vector2(core.get_center().x, core.position.y) if vertical else Vector2(core.position.x, core.get_center().y)
	var finish := Vector2(core.get_center().x, core.end.y) if vertical else Vector2(core.end.x, core.get_center().y)
	var clear := Color(edge, 0.0)
	RenderingServer.canvas_item_add_polyline(canvas, PackedVector2Array([start, start.lerp(finish, 0.12), start.lerp(finish, 0.88), finish]), PackedColorArray([clear, edge, edge, clear]), 1.0, true)


func _rod(canvas: RID, core: Rect2, vertical: bool) -> void:
	# Room at both ends for the studs.
	var stud := core.size.x if vertical else core.size.y
	var rod := core.grow_individual(0, -stud, 0, -stud) if vertical else core.grow_individual(-stud, 0, -stud, 0)
	if rod.size.x <= 0.0 or rod.size.y <= 0.0:
		rod = core
	RenderingServer.canvas_item_add_rect(canvas, rod, body)
	var corners := PackedVector2Array([rod.position, Vector2(rod.end.x, rod.position.y), rod.end, Vector2(rod.position.x, rod.end.y), rod.position])
	RenderingServer.canvas_item_add_polyline(canvas, corners, PackedColorArray([edge, edge, edge, edge, edge]), 1.0, false)
	var ends := [Vector2(rod.get_center().x, rod.position.y), Vector2(rod.get_center().x, rod.end.y)] if vertical else [Vector2(rod.position.x, rod.get_center().y), Vector2(rod.end.x, rod.get_center().y)]
	var radius := stud * 0.75
	for end: Vector2 in ends:
		RenderingServer.canvas_item_add_polygon(canvas, PackedVector2Array([end + Vector2(0, -radius), end + Vector2(radius, 0), end + Vector2(0, radius), end + Vector2(-radius, 0)]), PackedColorArray([edge, edge, edge, edge]))
