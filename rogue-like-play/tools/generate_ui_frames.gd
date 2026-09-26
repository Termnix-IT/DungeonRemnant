extends SceneTree

# Generates the 9-slice ornament frames used by the Theme. These are
# placeholders with the final file names: replace a PNG with drawn art of the
# same size and margins (SIZE / MARGIN below) and the Theme picks it up.
# Run: godot --headless --path . --script res://tools/generate_ui_frames.gd
const SIZE := 48
const MARGIN := 16
const BORDER := Color("525252")
const SHADOW := Color(0, 0, 0, 0.55)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/ui"))
	_save(_frame(Color(0.145, 0.145, 0.145, 1.0), BORDER, Color("8a7349")), "frame_panel.png")
	_save(_frame(Color(0.12, 0.12, 0.12, 0.92), BORDER, Color("8a7349")), "frame_card.png")
	_save(_frame(Color(0.16, 0.145, 0.105, 0.95), Color("b89759"), Color("e0c38a")), "frame_card_active.png")
	quit()


func _frame(fill: Color, border: Color, ornament: Color) -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Soft one-pixel shadow outside the border, then the panel body.
	_rect(image, Rect2i(0, 0, SIZE, SIZE), SHADOW)
	_rect(image, Rect2i(1, 1, SIZE - 2, SIZE - 2), border)
	_rect(image, Rect2i(2, 2, SIZE - 4, SIZE - 4), fill)
	# A thin inner rule gives the edge depth without competing with content.
	var rule := Color(border, 0.35)
	_hline(image, 4, 4, SIZE - 5, rule)
	_hline(image, SIZE - 5, 4, SIZE - 5, rule)
	_vline(image, 4, 4, SIZE - 5, rule)
	_vline(image, SIZE - 5, 4, SIZE - 5, rule)
	for flip_x in [false, true]:
		for flip_y in [false, true]:
			_corner(image, flip_x, flip_y, ornament)
	return image


# Bracket of two lines and a small diamond, drawn for the top-left corner and
# mirrored into the others. Everything stays inside MARGIN so it never stretches.
func _corner(image: Image, flip_x: bool, flip_y: bool, color: Color) -> void:
	var points: Array[Vector2i] = []
	for step in range(3, 14):
		points.append(Vector2i(step, 3))
		points.append(Vector2i(3, step))
	for step in range(6, 10):
		points.append(Vector2i(step, 6))
		points.append(Vector2i(6, step))
	for offset: Vector2i in [Vector2i(9, 9), Vector2i(8, 9), Vector2i(10, 9), Vector2i(9, 8), Vector2i(9, 10)]:
		points.append(offset)
	for point in points:
		var x := SIZE - 1 - point.x if flip_x else point.x
		var y := SIZE - 1 - point.y if flip_y else point.y
		image.set_pixel(x, y, color)


func _rect(image: Image, rect: Rect2i, color: Color) -> void:
	image.fill_rect(rect, color)


func _hline(image: Image, y: int, from: int, to: int, color: Color) -> void:
	for x in range(from, to + 1):
		image.set_pixel(x, y, image.get_pixel(x, y).blend(color))


func _vline(image: Image, x: int, from: int, to: int, color: Color) -> void:
	for y in range(from, to + 1):
		image.set_pixel(x, y, image.get_pixel(x, y).blend(color))


func _save(image: Image, name: String) -> void:
	var path := "res://art/ui/" + name
	if image.save_png(path) != OK:
		push_error("Could not save " + path)
