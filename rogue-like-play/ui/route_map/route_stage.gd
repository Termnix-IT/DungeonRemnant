class_name RouteStage
extends RefCounted

# What stands for an area of a route, wherever one is shown: the foe that
# leads it (the gates of the route's choice stand it in their light; the
# result's journey stands it braced where she fell), an event's object, and
# the chapter's painted stage and road the journey is laid with. Nothing here
# is a node: the screens draw these as they like.

# A stage's width as the journey lays it is its own; the boss's is this much
# larger, and its top's middle lies this far down the stage picture (measured
# by `python tools/build_route_stages.py --measure`).
const BOSS_SCALE := 1.15
const PLATE_TOP := 0.37
# Figures stand this many times their fight height (64 world px for most).
const FIGURE_SCALE := 1.7
# The chapter's stage, and each event's object (built by
# tools/build_route_stages.py).
const PLATES := "res://art/ui/route/plate_%s.png"
const PROPS := "res://art/ui/route/prop_%s.png"
# Each chapter's road (built by tools/build_route_roads.py), repeated along
# a path; a chapter without one draws its roads in plain gold.
const ROADS := "res://art/ui/route/road_%s.png"
const ROAD_PLAIN := Color(0.84, 0.72, 0.48, 0.9)
# A road's middle: this share of its width (the rim is the rest), its cut
# edges fading over this share of the band.
const MIDDLE_SHARE := 0.64
const MIDDLE_FADE := 0.22

# Each chapter's road's middle band, cut once.
static var _middles: Dictionary = {}


# The chapter's stage picture, or null when it has none.
static func plate_for(chapter: StringName) -> Texture2D:
	var path := PLATES % chapter
	return load(path) if ResourceLoader.exists(path) else null


# An event's object, or the start's signpost (`sign`).
static func prop_for(id: StringName) -> Texture2D:
	var path := PROPS % id
	return load(path) if ResourceLoader.exists(path) else null


# The chapter's road, or null when it has none.
static func road_for(chapter: StringName) -> Texture2D:
	var path := ROADS % chapter
	return load(path) if ResourceLoader.exists(path) else null


# The middle band of a road: its rim cut away and the cut edges fading out,
# so a middle laid over another road's rim shows no seam.
static func middle_of(road: Texture2D) -> Texture2D:
	if road == null:
		return null
	if _middles.has(road.resource_path):
		return _middles[road.resource_path]
	var image := road.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var high := roundi(image.get_height() * MIDDLE_SHARE)
	var top := (image.get_height() - high) / 2
	var band := image.get_region(Rect2i(0, top, image.get_width(), high))
	var fade := high * MIDDLE_FADE
	for y in high:
		var keep := clampf(minf(y + 0.5, high - y - 0.5) / fade, 0.0, 1.0)
		if keep >= 1.0:
			continue
		for x in band.get_width():
			var color := band.get_pixel(x, y)
			color.a *= keep
			band.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(band)
	_middles[road.resource_path] = texture
	return texture


# The foe that stands for an area, so the kind of fight reads at a glance:
# the boss; a field's horde by the kind met most; an arena by its last
# wave's first, the one the waves build up to. Every fight of a chapter
# shares its elite, so a field showing it would make them all look alike.
static func leader(area: AreaData) -> FoeData:
	if area.boss != null:
		return area.boss
	if area.spawn_table != null:
		var kinds := _by_weight(area.spawn_table)
		return kinds[0] if not kinds.is_empty() else area.spawn_table.elite
	for index in range(area.waves.size() - 1, -1, -1):
		if not area.waves[index].foes.is_empty():
			return area.waves[index].foes[0]
	return null


# The one that comes with it: a field's next most met kind, else the first
# other kind it comes with.
static func company(area: AreaData) -> FoeData:
	var first := leader(area)
	if area.boss != null or first == null:
		return null
	var kinds: Array[FoeData] = []
	if area.spawn_table != null:
		kinds = _by_weight(area.spawn_table)
	for wave in area.waves:
		kinds.append_array(wave.foes)
	for kind in kinds:
		if kind != null and kind != first:
			return kind
	return null


# A field's kinds, the most met first (a tie keeps the table's order).
static func _by_weight(table: SpawnTable) -> Array[FoeData]:
	var entries := table.entries.filter(func(entry: SpawnEntry) -> bool: return entry != null and entry.foe != null)
	var order := range(entries.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return entries[a].weight > entries[b].weight or (entries[a].weight == entries[b].weight and a < b))
	var kinds: Array[FoeData] = []
	for index in order:
		kinds.append(entries[index].foe)
	return kinds


# How a stage of this width lies: the picture's height.
static func plate_height(texture: Texture2D, width: float) -> float:
	if texture == null:
		return width * 0.5
	return width * texture.get_height() / texture.get_width()


# A foe standing braced and facing left (the fight draws them facing right),
# `grow` times its size in the fight but no taller than `tallest`, then
# `share` of that: its rig, else its picture.
static func foe_figure(foe: FoeData, tallest: float, share: float = 1.0, grow: float = FIGURE_SCALE) -> Node2D:
	var holder := Node2D.new()
	holder.scale = Vector2(-1.0, 1.0)
	var path := EnemySprites.rig_path(foe.visual_id)
	if ResourceLoader.exists(path):
		var rig: CharacterRig = (load(path) as PackedScene).instantiate()
		var fight := float(rig.get_meta(&"world_height", 64.0)) * foe.size_scale
		rig.world_height = minf(fight * grow, tallest) * share
		rig.modulate = foe.tint
		holder.add_child(rig)
		# Its stance is played once the rig is ready to play it.
		if rig.is_node_ready():
			rig.braced = true
		else:
			rig.ready.connect(func(): rig.braced = true, CONNECT_ONE_SHOT)
		return holder
	var picture := HubCodex.tile_picture(foe.visual_id, true, foe.tint)
	if picture != null:
		var sprite := Sprite2D.new()
		sprite.texture = picture
		sprite.centered = false
		sprite.offset = Vector2(-picture.get_width() * 0.5, -picture.get_height())
		sprite.scale = Vector2.ONE * tallest * 0.7 * share / picture.get_height()
		holder.add_child(sprite)
	return holder
