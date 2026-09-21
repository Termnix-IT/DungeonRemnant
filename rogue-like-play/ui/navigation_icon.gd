class_name NavigationIcon
extends Control

var kind := "出撃"


func _init() -> void:
	custom_minimum_size = Vector2(48, 48)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var color := get_theme_color(&"font_color", &"GoldLabel")
	draw_set_transform((size - Vector2(48, 48)) / 2, 0, Vector2(1.5, 1.5))
	match kind:
		"出撃":
			_line([Vector2(5, 27), Vector2(24, 4), Vector2(28, 3), Vector2(27, 8), Vector2(8, 29)], color)
			_line([Vector2(3, 20), Vector2(13, 28)], color)
			_line([Vector2(6, 4), Vector2(26, 28)], color)
			_line([Vector2(20, 28), Vector2(29, 21)], color)
		"装備":
			_line([Vector2(4, 5), Vector2(16, 8), Vector2(28, 5), Vector2(26, 21), Vector2(16, 29), Vector2(6, 21), Vector2(4, 5)], color)
			_line([Vector2(16, 11), Vector2(16, 25)], color)
		"倉庫":
			draw_rect(Rect2(3, 10, 26, 19), color, false, 2)
			_line([Vector2(3, 16), Vector2(29, 16)], color)
			draw_rect(Rect2(13, 13, 6, 7), color, false, 2)
			_line([Vector2(10, 10), Vector2(10, 5), Vector2(22, 5), Vector2(22, 10)], color)
		"ショップ":
			_line([Vector2(11, 10), Vector2(8, 3), Vector2(16, 5), Vector2(24, 3), Vector2(21, 10)], color)
			_line([Vector2(10, 11), Vector2(22, 11), Vector2(28, 23), Vector2(24, 29), Vector2(8, 29), Vector2(4, 23), Vector2(10, 11)], color)
		"永久強化":
			_line([Vector2(16, 7), Vector2(5, 3), Vector2(3, 26), Vector2(16, 29), Vector2(29, 26), Vector2(27, 3), Vector2(16, 7), Vector2(16, 29)], color)
			_line([Vector2(8, 10), Vector2(12, 12)], color)
			_line([Vector2(20, 12), Vector2(24, 10)], color)
	draw_set_transform(Vector2.ZERO)


func _line(points: PackedVector2Array, color: Color) -> void:
	draw_polyline(points, color, 1.5, true)
