extends SceneTree

## Asset import: key the source's green matte and pack generated frames.
const SOURCE := "res://art/characters/shiramine_mio_diagonal_source.png"
const OUTPUT := "res://art/characters/shiramine_mio_diagonal.png"
const FRAME := 80


func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	if source == null:
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			var color := source.get_pixel(x, y)
			if color.g > maxf(color.r, color.b) + 0.12:
				source.set_pixel(x, y, Color(0, 0, 0, 0))
	var sprites: Array[Image] = []
	var max_height := 0
	var max_width := 0
	for row in 4:
		for column in 6:
			# Generated columns have a small rightward offset; cut in the gutters.
			var gutter_offset := 48.0 if row % 2 == 0 else 12.0
			var left := 0 if column == 0 else roundi((gutter_offset + column * 244.0) * source.get_width() / 1536.0)
			var top := roundi(row * source.get_height() / 4.0)
			var right := source.get_width() if column == 5 else roundi((gutter_offset + (column + 1) * 244.0) * source.get_width() / 1536.0)
			var bottom := roundi((row + 1) * source.get_height() / 4.0)
			var sprite := source.get_region(Rect2i(left, top, right - left, bottom - top))
			sprite = _main_component(sprite)
			var bounds := sprite.get_used_rect()
			if bounds.size == Vector2i.ZERO:
				push_error("Empty generated frame")
				quit(1)
				return
			sprite = sprite.get_region(bounds)
			max_height = maxi(max_height, sprite.get_height())
			max_width = maxi(max_width, sprite.get_width())
			sprites.append(sprite)
	var scale_factor := minf(74.0 / max_height, 74.0 / max_width)
	var atlas := Image.create(480, 320, false, Image.FORMAT_RGBA8)
	for index in sprites.size():
		var sprite := sprites[index]
		sprite.resize(roundi(sprite.get_width() * scale_factor), roundi(sprite.get_height() * scale_factor), Image.INTERPOLATE_NEAREST)
		var position := Vector2i(index % 6 * FRAME + (FRAME - sprite.get_width()) / 2,
			index / 6 * FRAME + 78 - sprite.get_height())
		atlas.blit_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), position)
	var error := atlas.save_png(OUTPUT)
	print("Diagonal atlas: 24 frames, 480x320, shared scale and foot baseline")
	quit(0 if error == OK else 1)


func _main_component(source: Image) -> Image:
	var size := source.get_size()
	var visited := PackedByteArray()
	visited.resize(size.x * size.y)
	var largest: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			var start := Vector2i(x, y)
			if visited[y * size.x + x] or source.get_pixelv(start).a == 0.0:
				continue
			var component: Array[Vector2i] = [start]
			visited[y * size.x + x] = 1
			var index := 0
			while index < component.size():
				var point := component[index]
				index += 1
				for delta in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					var next: Vector2i = point + delta
					if next.x < 0 or next.y < 0 or next.x >= size.x or next.y >= size.y:
						continue
					var slot := next.y * size.x + next.x
					if visited[slot] or source.get_pixelv(next).a == 0.0:
						continue
					visited[slot] = 1
					component.append(next)
			if component.size() > largest.size():
				largest = component
	var result := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for point in largest:
		result.set_pixelv(point, source.get_pixelv(point))
	return result
