extends Node2D

const TILE_SIZE := 32
var grid := GridState.new()
var start_cell := Vector2i.ZERO
var stairs_cell := Vector2i(-1, -1)
var enemy_cells: Array[Vector2i] = []
var layout_name := ""
var has_stairs := true
var fog := FogOfWar.new()
var ground_items: Dictionary = {}


func build(settings: DungeonSettings, floor_number: int, rng: RandomNumberGenerator, final_floor: bool) -> void:
	var generated := DungeonGenerator.generate(settings, floor_number, rng)
	grid = generated.grid
	start_cell = generated.start
	stairs_cell = generated.stairs
	enemy_cells = generated.enemies
	layout_name = generated.layout
	has_stairs = not final_floor
	fog.reset()
	ground_items.clear()
	var terrain: TileMapLayer = $Terrain
	var remembered: TileMapLayer = $ExploredTerrain
	if terrain.tile_set == null:
		terrain.tile_set = _make_tileset()
	# Keep the existing grid, actor, and attack-preview coordinate convention.
	terrain.position = Vector2.ONE * TILE_SIZE / 2.0 - terrain.map_to_local(Vector2i.ZERO)
	remembered.tile_set = terrain.tile_set
	remembered.position = terrain.position
	terrain.clear()
	remembered.clear()


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
		var item := ItemCatalog.POTION if index % 3 == 2 else ItemCatalog.floor_item((floor_number - 1) * 4 + index - index / 3)
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
		var tile := 1 if grid.walls.has(cell) else 0
		if grid.pillars.has(cell):
			tile = 3
		if has_stairs and cell == stairs_cell:
			tile = 2
		terrain.set_cell(cell, 0, Vector2i(tile, 0))
		remembered.set_cell(cell, 0, Vector2i(tile, 0))
	$Items.entries = ground_items
	$Items.visible_cells = fog.visible
	$Items.queue_redraw()


func sync_actors() -> void:
	# Dead actors also need their final position after a lethal movement turn.
	for actor: Node2D in $Actors.get_children():
		actor.position = Vector2(actor.cell * TILE_SIZE) + Vector2.ONE * TILE_SIZE / 2.0


func _make_tileset() -> TileSet:
	# Placeholder tiles preserve the Phase 1 palette without external art assets.
	var texture_image := Image.create(TILE_SIZE * 4, TILE_SIZE, false, Image.FORMAT_RGBA8)
	texture_image.fill(Color("111a22"))
	for index in 4:
		var color := Color("374654") if index == 1 else Color("1b252e")
		texture_image.fill_rect(Rect2i(index * TILE_SIZE, 0, TILE_SIZE - 1, TILE_SIZE - 1), color)
	for step in 4:
		texture_image.fill_rect(Rect2i(TILE_SIZE * 2 + 5 + step * 2, 6 + step * 5, 22 - step * 4, 3), Color("efbb81"))
	texture_image.fill_rect(Rect2i(TILE_SIZE * 3 + 5, 5, 22, 22), Color("667b89"))
	texture_image.fill_rect(Rect2i(TILE_SIZE * 3 + 8, 8, 16, 16), Color("9aa9b0"))
	texture_image.fill_rect(Rect2i(TILE_SIZE * 3 + 8, 21, 16, 3), Color("4a5b66"))
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(texture_image)
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for index in 4:
		atlas.create_tile(Vector2i(index, 0))
	var result := TileSet.new()
	result.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	result.add_source(atlas, 0)
	return result
