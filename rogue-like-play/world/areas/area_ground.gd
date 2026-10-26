class_name AreaGround
extends Node2D

# A battlefield's ground: the painted terrain (the dungeon's atlases, 96 px
# cells shown at 48 px) laid over a rectangle of cells, its wall cells drawn
# as joined walls with their shadow on the floor, and one static body that
# stops anything at them. Wall cells that something else stands for (a
# forest's trees, `screened`) stop as walls but are drawn as floor, without
# a wall's shadow. The fight itself runs in free world px; the cells only
# place the ground and walls.

const CELL := 48
const PAINTED_CELL := 96
const ATLASES: Array[Texture2D] = [
	preload("res://art/tiles/painted/slate_terrain.png"),
	preload("res://art/tiles/painted/moss_terrain.png"),
	preload("res://art/tiles/painted/ember_terrain.png"),
	preload("res://art/tiles/painted/sanctum_terrain.png"),
	preload("res://art/tiles/painted/grove_terrain.png"),
	preload("res://art/tiles/painted/crypt_terrain.png"),
]
# Where the atlas keeps its tiles (as world/dungeon/dungeon.gd lays them).
const COLUMNS := 16
const WALL_START := 5
const WALL_COUNT := 16
const FLOOR_START := 21
const FLOOR_PERIOD := 4
const WALL_PERIOD := 2
const WALL_SPOT_START := FLOOR_START + FLOOR_PERIOD * FLOOR_PERIOD
const TILE_COUNT := WALL_SPOT_START + (WALL_PERIOD * WALL_PERIOD - 1) * WALL_COUNT
const WALL_SHADE := Color(0.02, 0.025, 0.04, 0.5)
const WALL_SHADE_DEPTH := 0.45

var size := Vector2i.ZERO
var walls: Dictionary = {}
var screened: Dictionary = {}
var terrain: TileMapLayer
var body: StaticBody2D
var _shade: Node2D


func build(cells: Vector2i, wall_cells: Dictionary, theme: int = 0, screened_cells: Dictionary = {}) -> void:
	size = cells
	walls = wall_cells
	screened = screened_cells
	terrain = TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = _tileset(ATLASES[clampi(theme, 0, ATLASES.size() - 1)])
	terrain.scale = Vector2.ONE * CELL / PAINTED_CELL
	terrain.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(terrain)
	terrain.position = Vector2.ONE * CELL / 2.0 - terrain.map_to_local(Vector2i.ZERO) * terrain.scale
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			terrain.set_cell(cell, 0, _coords(_tile(cell)))
	_shade = Node2D.new()
	_shade.name = "WallShade"
	add_child(_shade)
	_shade.draw.connect(_draw_shade)
	_build_body()


# The world rectangle inside the ground.
func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size * CELL))


func is_open(point: Vector2, margin: float = 0.0) -> bool:
	if not bounds().grow(-margin).has_point(point):
		return false
	for offset: Vector2 in [Vector2.ZERO, Vector2(margin, 0), Vector2(-margin, 0), Vector2(0, margin), Vector2(0, -margin)]:
		if walls.has(Vector2i((point + offset) / CELL)):
			return false
	return true


func _tileset(texture: Texture2D) -> TileSet:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(PAINTED_CELL, PAINTED_CELL)
	for index in TILE_COUNT:
		atlas.create_tile(_coords(index))
	var result := TileSet.new()
	result.tile_size = Vector2i(PAINTED_CELL, PAINTED_CELL)
	result.add_source(atlas, 0)
	return result


func _coords(index: int) -> Vector2i:
	return Vector2i(index % COLUMNS, index / COLUMNS)


# A wall drawn as one.
func _drawn(cell: Vector2i) -> bool:
	return walls.has(cell) and not screened.has(cell)


func _tile(cell: Vector2i) -> int:
	if _drawn(cell):
		var mask := 0
		for bit: int in 4:
			if _drawn(cell + ([Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT] as Array[Vector2i])[bit]):
				mask |= 1 << bit
		var spot := posmod(cell.x, WALL_PERIOD) + posmod(cell.y, WALL_PERIOD) * WALL_PERIOD
		return WALL_START + mask if spot == 0 else WALL_SPOT_START + (spot - 1) * WALL_COUNT + mask
	return FLOOR_START + posmod(cell.y, FLOOR_PERIOD) * FLOOR_PERIOD + posmod(cell.x, FLOOR_PERIOD)


# One body; each row's run of walls is one rectangle.
func _build_body() -> void:
	body = StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = Hero.WALLS
	body.collision_mask = 0
	add_child(body)
	for y in size.y:
		var x := 0
		while x < size.x:
			if not walls.has(Vector2i(x, y)):
				x += 1
				continue
			var start := x
			while x < size.x and walls.has(Vector2i(x, y)):
				x += 1
			var shape := RectangleShape2D.new()
			shape.size = Vector2((x - start) * CELL, CELL)
			var holder := CollisionShape2D.new()
			holder.shape = shape
			holder.position = Vector2((start + x) * CELL * 0.5, (y + 0.5) * CELL)
			body.add_child(holder)


# Floor cells just below a wall get its shadow; beside one, a fainter one.
func _draw_shade() -> void:
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if _drawn(cell):
				continue
			var origin := Vector2(cell * CELL)
			var side := float(CELL)
			if _drawn(cell + Vector2i.UP):
				_strip(origin, Vector2(side, 0), Vector2(0, side * WALL_SHADE_DEPTH), 1.0)
			if _drawn(cell + Vector2i.LEFT):
				_strip(origin, Vector2(0, side), Vector2(side * WALL_SHADE_DEPTH * 0.5, 0), 0.6)
			if _drawn(cell + Vector2i.RIGHT):
				_strip(origin + Vector2(side, 0), Vector2(0, side), Vector2(-side * WALL_SHADE_DEPTH * 0.5, 0), 0.6)


func _strip(start: Vector2, along: Vector2, inward: Vector2, strength: float) -> void:
	var dark := Color(WALL_SHADE, WALL_SHADE.a * strength)
	var clear := Color(WALL_SHADE, 0.0)
	_shade.draw_polygon(PackedVector2Array([start, start + along, start + along + inward, start + inward]),
		PackedColorArray([dark, dark, clear, clear]))
