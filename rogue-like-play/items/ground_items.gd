extends Node2D

var entries: Dictionary = {}
var visible_cells: Dictionary = {}
var tile_size := 48


func _draw() -> void:
	var visual_scale := float(tile_size) / 32.0
	for cell: Vector2i in entries:
		if not visible_cells.has(cell):
			continue
		var center := Vector2(cell * tile_size) + Vector2.ONE * tile_size / 2.0
		var item: ItemData = entries[cell].item
		draw_set_transform(center, 0.0, Vector2.ONE * visual_scale)
		if not item.effect_id.is_empty():
			draw_rect(Rect2(-6, -10, 12, 20), Color("e8cf80"))
			draw_line(Vector2(0, -6), Vector2(0, 6), Color("4d3944"), 3)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		match item.kind:
			ItemData.Kind.WEAPON:
				draw_line(Vector2(-7, 7), Vector2(7, -7), Color("c9e3e9"), 4)
				draw_line(Vector2(-7, 0), Vector2(0, 7), Color("c9e3e9"), 3)
			ItemData.Kind.ARMOR:
				draw_rect(Rect2(Vector2(-8, -8), Vector2(16, 16)), Color("6ba2c7"), false, 3)
			ItemData.Kind.ACCESSORY:
				draw_arc(Vector2.ZERO, 7, 0, TAU, 24, Color("e8cf80"), 3)
			ItemData.Kind.CONSUMABLE:
				draw_rect(Rect2(Vector2(-6, -6), Vector2(12, 14)), Color("d488aa"))
				draw_rect(Rect2(Vector2(-3, -10), Vector2(6, 4)), Color("e9d1dc"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
