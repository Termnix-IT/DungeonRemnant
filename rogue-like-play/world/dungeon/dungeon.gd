extends Node2D

const TILE_SIZE := 48
const TERRAIN_ATLASES: Array[Texture2D] = [
	preload("res://art/tiles/dungeon_terrain.png"),
	preload("res://art/tiles/dungeon_terrain_moss.png"),
	preload("res://art/tiles/dungeon_terrain_ember.png"),
	preload("res://art/tiles/dungeon_terrain_sanctum.png"),
]
const FOREST_TREES := preload("res://art/tiles/forest_trees.png")
# Trees are the forest's walls, so like the stone walls they sit a step below
# the floor and actors; remembered but unseen trees go darker still.
const TREE_TINT := Color(0.74, 0.77, 0.74)
const REMEMBERED_TREE_TINT := Color(0.34, 0.36, 0.36)
const TERRAIN_THEME_NAMES: Array[String] = ["Slate Ruins", "Moss Caverns", "Ember Depths", "Obsidian Sanctum"]
const FLOOR_TILES: Array[int] = [0, 3, 4]
const STAIRS_TILE := 1
const PILLAR_TILE := 2
const WALL_TILE_START := 5
const WALL_TILE_COUNT := 16
var grid := GridState.new()
var start_cell := Vector2i.ZERO
var stairs_cell := Vector2i(-1, -1)
var enemy_cells: Array[Vector2i] = []
var layout_name := ""
var terrain_theme_index := 0
var terrain_theme_name := ""
var has_stairs := true
var forest := false
var monster_house := Rect2i()
var house_discovered := false
var escape_cell := Vector2i(-1, -1)
var fog := FogOfWar.new()
var ground_items: Dictionary = {}
var decorations: Node2D
var ambient_details := preload("res://world/dungeon/ambient_details.gd").new()
var lights := preload("res://world/dungeon/dungeon_lights.gd").new()
var mist := preload("res://world/dungeon/unexplored_mist.gd").new()


func _ready() -> void:
	lights.name = "Lights"
	add_child(lights)
	move_child(lights, 2)
	add_child(ambient_details)
	move_child(ambient_details, 2)
	decorations = Node2D.new()
	add_child(decorations)
	move_child(decorations, 2)
	decorations.draw.connect(_draw_decorations)
	# Added last so the fixed layer indices above stay as they were; the mist
	# then moves under every terrain layer, so known tiles cover it.
	mist.name = "Mist"
	add_child(mist)
	move_child(mist, 0)


func build(settings: DungeonSettings, floor_number: int, rng: RandomNumberGenerator, final_floor: bool, kind: DungeonGenerator.Kind = DungeonGenerator.Kind.EXPLORATION) -> void:
	ambient_details.refresh(null, {}, Vector2i.ZERO, false, Vector2i.ZERO, false)
	lights.refresh(null, {}, Vector2i.ZERO, false, false, 0)
	forest = settings.forest
	escape_cell = Vector2i(-1, -1)
	var generated := DungeonGenerator.generate(settings, floor_number, rng, final_floor, kind)
	grid = generated.grid
	start_cell = generated.start
	stairs_cell = generated.stairs
	enemy_cells = generated.enemies
	enemy_cells.append_array(generated.house_enemies)
	monster_house = generated.house
	house_discovered = false
	layout_name = generated.layout
	terrain_theme_index = 1 if forest else _terrain_theme_index(floor_number)
	terrain_theme_name = "Forest" if forest else TERRAIN_THEME_NAMES[terrain_theme_index]
	# The antechamber's door always leads on, even on the final floor.
	has_stairs = kind == DungeonGenerator.Kind.ANTECHAMBER or not final_floor
	fog.reset()
	ground_items.clear()
	var terrain: TileMapLayer = $Terrain
	var remembered: TileMapLayer = $ExploredTerrain
	terrain.tile_set = _make_tileset(TERRAIN_ATLASES[terrain_theme_index])
	# Keep the existing grid, actor, and attack-preview coordinate convention.
	terrain.position = Vector2.ONE * TILE_SIZE / 2.0 - terrain.map_to_local(Vector2i.ZERO)
	remembered.tile_set = terrain.tile_set
	remembered.position = terrain.position
	mist.refresh(grid.size, forest, terrain_theme_index)
	terrain.clear()
	remembered.clear()
	$Items.tile_size = TILE_SIZE


func spawn_items(settings: DungeonSettings, floor_number: int, rng: RandomNumberGenerator) -> void:
	var distances := LayoutUtils.distances(grid, start_cell)
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in distances:
		if cell != stairs_cell and not grid.occupants.has(cell):
			candidates.append(cell)
	for index in mini(clampi(settings.item_count, 0, 20), candidates.size()):
		# One nearby drop makes pickup discoverable; other drops reward exploration.
		var selected := 0 if index == 0 else rng.randi_range(0, candidates.size() - 1)
		var cell := candidates[selected]
		candidates.remove_at(selected)
		var item := ItemCatalog.POTION if index % 3 == 2 else ItemCatalog.ground_item((floor_number - 1) * 4 + index - index / 3)
		ground_items[cell] = InventoryEntry.new(item, 2 if item.stackable() else 1)
	var house_candidates: Array[Vector2i] = []
	for cell: Vector2i in distances:
		if monster_house.has_point(cell) and cell != start_cell and cell != stairs_cell and not grid.occupants.has(cell) and not ground_items.has(cell):
			house_candidates.append(cell)
	for index in mini(settings.monster_house_items, house_candidates.size()):
		var selected := rng.randi_range(0, house_candidates.size() - 1)
		var cell := house_candidates[selected]
		house_candidates.remove_at(selected)
		var item := ItemCatalog.POTION if index % 3 == 0 else ItemCatalog.ground_item(rng.randi_range(0, 1000))
		ground_items[cell] = InventoryEntry.new(item, 2 if item.stackable() else 1)


func collect_items(player: Node2D) -> String:
	if not ground_items.has(player.cell):
		return ""
	var entry: InventoryEntry = ground_items[player.cell]
	var remainder: int = player.inventory.add(entry.item, entry.count)
	var accepted := entry.count - remainder
	entry.count = remainder
	if remainder == 0:
		ground_items.erase(player.cell)
	var message := " %s ×%dを取得。" % [entry.item.display_name, accepted] if accepted > 0 else ""
	if remainder > 0:
		message += " 所持上限のため残りは床に置いたままです。"
	return message


func update_visibility(origin: Vector2i, radius: int) -> void:
	fog.update(grid, origin, radius)
	var terrain: TileMapLayer = $Terrain
	var remembered: TileMapLayer = $ExploredTerrain
	terrain.clear()
	for cell: Vector2i in fog.visible:
		var tile := _terrain_tile(cell)
		terrain.set_cell(cell, 0, Vector2i(tile, 0))
		remembered.set_cell(cell, 0, Vector2i(tile, 0))
	$Items.entries = ground_items
	$Items.visible_cells = fog.visible
	$Items.queue_redraw()
	decorations.queue_redraw()
	ambient_details.refresh(grid, fog.visible, stairs_cell, has_stairs, escape_cell, forest, terrain_theme_index)
	lights.refresh(grid, fog.visible, stairs_cell, has_stairs, forest, terrain_theme_index)


func sync_actors() -> void:
	# Dead actors also need their final position after a lethal movement turn.
	for actor: Node2D in $Actors.get_children():
		actor.position = Vector2(actor.cell * TILE_SIZE) + Vector2.ONE * TILE_SIZE / 2.0
	# Actors are y-sorted so a lower row stands in front. On the same row the
	# tree order decides, and the hero goes last so a large enemy beside her
	# never hides her.
	for actor: Node2D in $Actors.get_children():
		if not actor.get("stats") is EnemyStats:
			$Actors.move_child(actor, -1)


func _make_tileset(texture: Texture2D) -> TileSet:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for index in WALL_TILE_START + WALL_TILE_COUNT:
		atlas.create_tile(Vector2i(index, 0))
	var result := TileSet.new()
	result.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	result.add_source(atlas, 0)
	return result


func _terrain_theme_index(floor_number: int) -> int:
	if floor_number <= 3:
		return 0
	if floor_number <= 6:
		return 1
	if floor_number <= 9:
		return 2
	return 3


func _terrain_tile(cell: Vector2i) -> int:
	if has_stairs and cell == stairs_cell:
		return STAIRS_TILE
	if grid.pillars.has(cell):
		return PILLAR_TILE
	if grid.walls.has(cell):
		return WALL_TILE_START + _wall_connection_mask(cell)
	var variation := absi(cell.x * 73856093 ^ cell.y * 19349663)
	return FLOOR_TILES[variation % 12] if variation % 12 < FLOOR_TILES.size() else FLOOR_TILES[0]


func _wall_connection_mask(cell: Vector2i) -> int:
	var mask := 0
	if _is_connectable_wall(cell + Vector2i.UP):
		mask |= 1
	if _is_connectable_wall(cell + Vector2i.RIGHT):
		mask |= 2
	if _is_connectable_wall(cell + Vector2i.DOWN):
		mask |= 4
	if _is_connectable_wall(cell + Vector2i.LEFT):
		mask |= 8
	return mask


func _is_connectable_wall(cell: Vector2i) -> bool:
	return grid.walls.has(cell) and not grid.pillars.has(cell)


# Forest walls are trees: one of four variants per cell by coordinate hash,
# rooted at the cell's bottom edge and wider than the cell so the canopies
# close into a wall. Rows are drawn top to bottom so nearer trees overlap
# the ones behind them; remembered but unseen trees stay dark.
func _draw_forest_trees() -> void:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in fog.explored:
		if grid.walls.has(cell):
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var size := float(FOREST_TREES.get_height())
	var variants := FOREST_TREES.get_width() / int(size)
	for cell in cells:
		var variant := absi(cell.x * 73856093 ^ cell.y * 19349663) % variants
		var base := Vector2(cell * TILE_SIZE) + Vector2(TILE_SIZE / 2.0, TILE_SIZE)
		var tint := TREE_TINT if fog.visible.has(cell) else REMEMBERED_TREE_TINT
		decorations.draw_texture_rect_region(FOREST_TREES, Rect2(base - Vector2(size / 2.0, size - 4.0), Vector2.ONE * size), Rect2(variant * size, 0, size, size), tint)


func _draw_decorations() -> void:
	# The monster house reads as a stained, scarred room rather than a grid
	# highlight: a low warm stain, scratches on some tiles, and an ember seam
	# only along the room's edge.
	for cell: Vector2i in fog.explored:
		if not monster_house.has_point(cell):
			continue
		var lit: bool = fog.visible.has(cell)
		var origin := Vector2(cell * TILE_SIZE)
		decorations.draw_rect(Rect2(origin, Vector2.ONE * TILE_SIZE), Color(0.42, 0.08, 0.05, 0.16 if lit else 0.07))
		var mark := absi(cell.x * 73856093 ^ cell.y * 19349663)
		if mark % 3 == 0:
			var scratch := Color(0.2, 0.08, 0.06, 0.55 if lit else 0.25)
			var start := origin + Vector2(12 + mark % 17, 14 + (mark / 7) % 15)
			for claw in 3:
				decorations.draw_line(start + Vector2(claw * 5, 0), start + Vector2(claw * 5 + 9, 13), scratch, 2.0)
		var seam := Color(0.86, 0.36, 0.16, 0.5 if lit else 0.2)
		for side: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			if monster_house.has_point(cell + side):
				continue
			var from := origin + Vector2.ONE * TILE_SIZE / 2.0 + Vector2(side) * (TILE_SIZE / 2.0 - 3) - Vector2(side).orthogonal() * TILE_SIZE / 2.0
			decorations.draw_line(from, from + Vector2(side).orthogonal() * TILE_SIZE, seam, 2.0)
	if forest:
		_draw_forest_trees()
	if escape_cell.x < 0 or not fog.visible.has(escape_cell):
		return
	var center := Vector2(escape_cell * TILE_SIZE) + Vector2.ONE * TILE_SIZE / 2.0
	decorations.draw_circle(center, 19, Color("5df1c3"), false, 4)
	decorations.draw_line(center + Vector2(0, 12), center + Vector2(0, -12), Color.WHITE, 3)
	decorations.draw_line(center + Vector2(0, -12), center + Vector2(-7, -5), Color.WHITE, 3)
	decorations.draw_line(center + Vector2(0, -12), center + Vector2(7, -5), Color.WHITE, 3)
