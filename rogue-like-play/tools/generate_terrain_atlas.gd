extends SceneTree

const LOGICAL_TILE_SIZE := 16
const WALL_TILE_START := 5
const WALL_TILE_COUNT := 16
const TILE_COUNT := WALL_TILE_START + WALL_TILE_COUNT
const SCALE := 2

const THEMES := [
	{
		"file": "dungeon_terrain.png",
		"void": Color("0b1118"), "floor_dark": Color("18232d"), "floor_base": Color("22313e"), "floor_light": Color("2e4352"),
		"stone_dark": Color("263541"), "stone_base": Color("405565"), "stone_light": Color("6d8290"),
		"gold_dark": Color("8f5b29"), "gold_base": Color("d69a3a"), "gold_light": Color("f2c35c"),
	},
	{
		"file": "dungeon_terrain_moss.png",
		"void": Color("08120f"), "floor_dark": Color("142820"), "floor_base": Color("1d382e"), "floor_light": Color("2c5040"),
		"stone_dark": Color("263a32"), "stone_base": Color("405e50"), "stone_light": Color("739283"),
		"gold_dark": Color("805c24"), "gold_base": Color("c79a3b"), "gold_light": Color("e8c462"),
	},
	{
		"file": "dungeon_terrain_ember.png",
		"void": Color("150b0d"), "floor_dark": Color("2a1718"), "floor_base": Color("3c2322"), "floor_light": Color("59372f"),
		"stone_dark": Color("3b2827"), "stone_base": Color("68443b"), "stone_light": Color("9a6853"),
		"gold_dark": Color("934b20"), "gold_base": Color("df7b2f"), "gold_light": Color("ffc15a"),
	},
	{
		"file": "dungeon_terrain_sanctum.png",
		"void": Color("0d0914"), "floor_dark": Color("1b1627"), "floor_base": Color("292039"), "floor_light": Color("423257"),
		"stone_dark": Color("302841"), "stone_base": Color("55456d"), "stone_light": Color("8d78a6"),
		"gold_dark": Color("996026"), "gold_base": Color("e0a13d"), "gold_light": Color("ffd875"),
	},
]

var palette: Dictionary


func _initialize() -> void:
	var directory := "res://art/tiles"
	DirAccess.make_dir_recursive_absolute(directory)
	var success := true
	for theme: Dictionary in THEMES:
		palette = theme
		var image := Image.create(LOGICAL_TILE_SIZE * TILE_COUNT, LOGICAL_TILE_SIZE, false, Image.FORMAT_RGBA8)
		image.fill(palette.void)
		_draw_floor(image, 0, 0)
		_draw_stairs(image, 1)
		_draw_pillar(image, 2)
		_draw_floor(image, 3, 1)
		_draw_floor(image, 4, 2)
		for mask in WALL_TILE_COUNT:
			_draw_connected_wall(image, WALL_TILE_START + mask, mask)
		image.resize(image.get_width() * SCALE, image.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
		var error := image.save_png(directory + "/" + str(theme.file))
		success = success and error == OK
	print("Terrain theme atlases: ", "created" if success else "FAILED")
	quit(0 if success else 1)


func _tile_rect(index: int) -> Rect2i:
	return Rect2i(index * LOGICAL_TILE_SIZE, 0, LOGICAL_TILE_SIZE, LOGICAL_TILE_SIZE)


func _pixel(image: Image, tile: int, x: int, y: int, color: Color) -> void:
	image.set_pixel(tile * LOGICAL_TILE_SIZE + x, y, color)


func _rect(image: Image, tile: int, x: int, y: int, width: int, height: int, color: Color) -> void:
	image.fill_rect(Rect2i(tile * LOGICAL_TILE_SIZE + x, y, width, height), color)


func _draw_floor(image: Image, tile: int, variant: int) -> void:
	image.fill_rect(_tile_rect(tile), palette.floor_base)
	_rect(image, tile, 0, 0, 16, 1, palette.floor_dark)
	_rect(image, tile, 0, 0, 1, 16, palette.floor_dark)
	_rect(image, tile, 1, 15, 15, 1, palette.floor_light)
	_rect(image, tile, 15, 1, 1, 14, palette.floor_light)
	if variant == 1:
		for point: Vector2i in [Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 8), Vector2i(8, 8)]:
			_pixel(image, tile, point.x, point.y, palette.floor_dark)
		_pixel(image, tile, 5, 4, palette.floor_light)
	elif variant == 2:
		for point: Vector2i in [Vector2i(5, 10), Vector2i(6, 9), Vector2i(7, 10), Vector2i(11, 5)]:
			_pixel(image, tile, point.x, point.y, palette.floor_dark)
		_pixel(image, tile, 6, 9, palette.floor_light)
		_pixel(image, tile, 11, 4, palette.floor_light)


func _draw_connected_wall(image: Image, tile: int, connections: int) -> void:
	image.fill_rect(_tile_rect(tile), palette.stone_base)
	_rect(image, tile, 0, 7, 16, 1, palette.stone_dark)
	_rect(image, tile, 7, 2, 1, 5, palette.stone_dark)
	_rect(image, tile, 4, 8, 1, 6, palette.stone_dark)
	if connections & 1:
		_rect(image, tile, 0, 0, 16, 1, palette.stone_light)
	else:
		_rect(image, tile, 0, 0, 16, 2, palette.void)
		_rect(image, tile, 2, 2, 12, 1, palette.stone_light)
	if connections & 2:
		_rect(image, tile, 15, 0, 1, 16, palette.stone_dark)
	else:
		_rect(image, tile, 14, 0, 2, 16, palette.void)
		_rect(image, tile, 13, 2, 1, 12, palette.stone_dark)
	if connections & 4:
		_rect(image, tile, 0, 15, 16, 1, palette.floor_dark)
	else:
		_rect(image, tile, 0, 14, 16, 2, palette.void)
		_rect(image, tile, 2, 13, 12, 1, palette.floor_dark)
	if connections & 8:
		_rect(image, tile, 0, 0, 1, 16, palette.stone_light)
	else:
		_rect(image, tile, 0, 0, 2, 16, palette.void)
		_rect(image, tile, 2, 2, 1, 12, palette.stone_light)


func _draw_stairs(image: Image, tile: int) -> void:
	_draw_floor(image, tile, 0)
	_rect(image, tile, 4, 3, 8, 2, palette.gold_light)
	_rect(image, tile, 5, 6, 7, 2, palette.gold_base)
	_rect(image, tile, 6, 9, 6, 2, palette.gold_base)
	_rect(image, tile, 7, 12, 5, 2, palette.gold_dark)
	_rect(image, tile, 4, 5, 8, 1, palette.gold_dark)
	_rect(image, tile, 5, 8, 7, 1, palette.gold_dark)
	_rect(image, tile, 6, 11, 6, 1, palette.gold_dark)


func _draw_pillar(image: Image, tile: int) -> void:
	_draw_floor(image, tile, 0)
	_rect(image, tile, 3, 3, 10, 10, palette.stone_dark)
	_rect(image, tile, 4, 4, 8, 8, palette.stone_base)
	_rect(image, tile, 5, 5, 6, 2, palette.stone_light)
	_rect(image, tile, 5, 7, 2, 4, palette.stone_light)
	_rect(image, tile, 7, 7, 4, 4, palette.stone_dark)
