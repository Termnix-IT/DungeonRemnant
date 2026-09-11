extends SceneTree

const LOGICAL_TILE_SIZE := 16
const TILE_COUNT := 8
const SCALE := 2

const VOID := Color("0b1118")
const FLOOR_DARK := Color("18232d")
const FLOOR_BASE := Color("22313e")
const FLOOR_LIGHT := Color("2e4352")
const STONE_DARK := Color("263541")
const STONE_BASE := Color("405565")
const STONE_LIGHT := Color("6d8290")
const GOLD_DARK := Color("8f5b29")
const GOLD_BASE := Color("d69a3a")
const GOLD_LIGHT := Color("f2c35c")


func _initialize() -> void:
	var image := Image.create(LOGICAL_TILE_SIZE * TILE_COUNT, LOGICAL_TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(VOID)
	_draw_floor(image, 0, 0)
	_draw_wall(image, 1, 0)
	_draw_stairs(image, 2)
	_draw_pillar(image, 3)
	_draw_floor(image, 4, 1)
	_draw_floor(image, 5, 2)
	_draw_wall(image, 6, 1)
	_draw_wall(image, 7, 2)
	image.resize(image.get_width() * SCALE, image.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	var directory := "res://art/tiles"
	DirAccess.make_dir_recursive_absolute(directory)
	var error := image.save_png(directory + "/dungeon_terrain.png")
	print("Terrain atlas: ", "created" if error == OK else "FAILED")
	quit(0 if error == OK else 1)


func _tile_rect(index: int) -> Rect2i:
	return Rect2i(index * LOGICAL_TILE_SIZE, 0, LOGICAL_TILE_SIZE, LOGICAL_TILE_SIZE)


func _pixel(image: Image, tile: int, x: int, y: int, color: Color) -> void:
	image.set_pixel(tile * LOGICAL_TILE_SIZE + x, y, color)


func _rect(image: Image, tile: int, x: int, y: int, width: int, height: int, color: Color) -> void:
	image.fill_rect(Rect2i(tile * LOGICAL_TILE_SIZE + x, y, width, height), color)


func _draw_floor(image: Image, tile: int, variant: int) -> void:
	image.fill_rect(_tile_rect(tile), FLOOR_BASE)
	_rect(image, tile, 0, 0, 16, 1, FLOOR_DARK)
	_rect(image, tile, 0, 0, 1, 16, FLOOR_DARK)
	_rect(image, tile, 1, 15, 15, 1, FLOOR_LIGHT)
	_rect(image, tile, 15, 1, 1, 14, FLOOR_LIGHT)
	if variant == 1:
		for point: Vector2i in [Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 8), Vector2i(8, 8)]:
			_pixel(image, tile, point.x, point.y, FLOOR_DARK)
		_pixel(image, tile, 5, 4, FLOOR_LIGHT)
	elif variant == 2:
		for point: Vector2i in [Vector2i(5, 10), Vector2i(6, 9), Vector2i(7, 10), Vector2i(11, 5)]:
			_pixel(image, tile, point.x, point.y, FLOOR_DARK)
		_pixel(image, tile, 6, 9, FLOOR_LIGHT)
		_pixel(image, tile, 11, 4, FLOOR_LIGHT)


func _draw_wall(image: Image, tile: int, variant: int) -> void:
	image.fill_rect(_tile_rect(tile), STONE_DARK)
	_rect(image, tile, 1, 1, 14, 13, STONE_BASE)
	_rect(image, tile, 1, 1, 14, 2, STONE_LIGHT)
	_rect(image, tile, 1, 13, 14, 2, FLOOR_DARK)
	_rect(image, tile, 1, 7, 14, 1, STONE_DARK)
	_rect(image, tile, 7, 3, 1, 4, STONE_DARK)
	_rect(image, tile, 4, 8, 1, 5, STONE_DARK)
	if variant == 1:
		for point: Vector2i in [Vector2i(11, 3), Vector2i(10, 4), Vector2i(10, 5), Vector2i(9, 6)]:
			_pixel(image, tile, point.x, point.y, STONE_DARK)
	elif variant == 2:
		_rect(image, tile, 2, 11, 2, 1, STONE_LIGHT)
		_rect(image, tile, 12, 4, 2, 1, STONE_LIGHT)
		_pixel(image, tile, 9, 9, FLOOR_DARK)


func _draw_stairs(image: Image, tile: int) -> void:
	_draw_floor(image, tile, 0)
	_rect(image, tile, 4, 3, 8, 2, GOLD_LIGHT)
	_rect(image, tile, 5, 6, 7, 2, GOLD_BASE)
	_rect(image, tile, 6, 9, 6, 2, GOLD_BASE)
	_rect(image, tile, 7, 12, 5, 2, GOLD_DARK)
	_rect(image, tile, 4, 5, 8, 1, GOLD_DARK)
	_rect(image, tile, 5, 8, 7, 1, GOLD_DARK)
	_rect(image, tile, 6, 11, 6, 1, GOLD_DARK)


func _draw_pillar(image: Image, tile: int) -> void:
	_draw_floor(image, tile, 0)
	_rect(image, tile, 3, 3, 10, 10, STONE_DARK)
	_rect(image, tile, 4, 4, 8, 8, STONE_BASE)
	_rect(image, tile, 5, 5, 6, 2, STONE_LIGHT)
	_rect(image, tile, 5, 7, 2, 4, STONE_LIGHT)
	_rect(image, tile, 7, 7, 4, 4, STONE_DARK)
