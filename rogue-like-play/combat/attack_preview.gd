extends Node2D

var cells: Array[Vector2i] = []
var tile_size := 48


func _draw() -> void:
	for cell in cells:
		var area := Rect2(Vector2(cell * tile_size), Vector2.ONE * tile_size)
		draw_rect(area, Color(1.0, 0.76, 0.3, 0.35))
		# The outline is centered on its path; keep its two-pixel stroke inside the cell.
		draw_rect(area.grow(-1.0), Color(1.0, 0.76, 0.3, 0.9), false, 2.0)
