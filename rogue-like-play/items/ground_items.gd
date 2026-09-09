extends Node2D

var entries: Dictionary = {}
var visible_cells: Dictionary = {}
var tile_size := 32


func _draw() -> void:
	for cell: Vector2i in entries:
		if not visible_cells.has(cell):
			continue
		var center := Vector2(cell * tile_size) + Vector2.ONE * tile_size / 2.0
		var item: ItemData = entries[cell].item
		match item.kind:
			ItemData.Kind.WEAPON:
				draw_line(center + Vector2(-7, 7), center + Vector2(7, -7), Color("c9e3e9"), 4)
				draw_line(center + Vector2(-7, 0), center + Vector2(0, 7), Color("c9e3e9"), 3)
			ItemData.Kind.ARMOR:
				draw_rect(Rect2(center - Vector2(8, 8), Vector2(16, 16)), Color("6ba2c7"), false, 3)
			ItemData.Kind.ACCESSORY:
				draw_arc(center, 7, 0, TAU, 24, Color("e8cf80"), 3)
			ItemData.Kind.CONSUMABLE:
				draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 14)), Color("d488aa"))
				draw_rect(Rect2(center - Vector2(3, 10), Vector2(6, 4)), Color("e9d1dc"))
