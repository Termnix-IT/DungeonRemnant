class_name AreaGround
extends Node2D

# A battlefield's ground, as a place and not a tiling: one sheet drawn by a
# shader (area_floor.gdshader) lays the theme's paving large, with the wall
# round the room (the far one a face of stone standing over the floor) and
# the dark beyond, all in the place's light. The light is the ground's to
# keep (area_light.gdshaderinc): the dark of the place, the light she
# carries (follow()), the fires that stand in it (add_lamp(): on the far
# wall, and on the pillars that hold one) and the blows that flash in it
# (flash()). On its pillars stand things with height (plant(): broken
# columns, statues, spires, crystals, by the theme; a forest's trees),
# sorted among the fighters, and over its floor lie the leavings of old
# fights (scatter()). The props and the leavings take the same light.
#
# What stops a body is unchanged: one static body with a rectangle for each
# row's run of wall cells. The fight itself runs in free world px; the cells
# only place the ground and walls. Wall cells inside the room that nothing
# stands for (a test's, the sandbox's) are still drawn as joined walls from
# the theme's atlas.

const CELL := 48
const PAINTED_CELL := 96
const ATLASES: Array[Texture2D] = [
	preload("res://art/tiles/painted/slate_terrain.png"),
	preload("res://art/tiles/painted/moss_terrain.png"),
	preload("res://art/tiles/painted/ember_terrain.png"),
	preload("res://art/tiles/painted/sanctum_terrain.png"),
	preload("res://art/tiles/painted/grove_terrain.png"),
	preload("res://art/tiles/painted/crypt_terrain.png"),
	preload("res://art/tiles/painted/abyss_terrain.png"),
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

const FLOOR_SHADER := preload("res://world/areas/area_floor.gdshader")
const LIT_SHADER := preload("res://world/areas/area_lit.gdshader")
const FIRE_SHADER := preload("res://ui/route_map/route_fire.gdshader")
const THEMES: Array[StringName] = [&"slate", &"moss", &"ember", &"sanctum", &"grove", &"crypt", &"abyss"]
const STONES := "res://art/tiles/painted/floors/%s_floor.jpg"
const ROCKS := "res://art/tiles/painted/floors/%s_wall.jpg"
const DECALS: Texture2D = preload("res://art/tiles/painted/floor_decals.png")
const AIR_SHADER: Shader = preload("res://world/areas/area_air.gdshader")
# The air is drawn over everything that stands in the place.
const AIR_Z := 12
const SCONCE: Texture2D = preload("res://art/tiles/painted/wall_sconce.png")
# The sheet runs this far past the room, the far wall stands this high over
# the floor, and the paving repeats every this many world px.
const MARGIN := 560.0
const FACE := 96.0
const PERIOD := 512.0
# How many fires and flashes the shaders take (area_light.gdshaderinc).
const LAMPS := 12
const FLASHES := 6
# Each place's own light, by theme: the dark of it (alpha: how much light
# there is without her), its fires' colour, the cast over its stone and the
# things on it, and its mist (alpha: how thick).
const MOODS := [
	{ambient = Color(0.5, 0.58, 0.76, 0.66), lamp = Color(1.0, 0.62, 0.3, 0.9), tone = Color(1.0, 1.0, 1.0), mist = Color(0.7, 0.78, 0.9, 0.07), calm = Vector2(0.8, 0.8)},
	{ambient = Color(0.5, 0.66, 0.6, 0.68), lamp = Color(1.0, 0.66, 0.32, 0.9), tone = Color(0.9, 1.0, 0.84), mist = Color(0.7, 0.86, 0.78, 0.09), calm = Vector2(0.78, 0.8)},
	{ambient = Color(0.82, 0.52, 0.42, 0.66), lamp = Color(1.0, 0.52, 0.22, 0.95), tone = Color(1.0, 1.0, 1.0), mist = Color(0.92, 0.52, 0.36, 0.06), calm = Vector2(0.6, 0.66)},
	{ambient = Color(0.5, 0.5, 0.78, 0.6), lamp = Color(1.0, 0.6, 0.3, 1.0), tone = Color(0.9, 0.88, 1.0), mist = Color(0.62, 0.62, 0.9, 0.06), calm = Vector2(0.68, 0.7)},
	{ambient = Color(0.52, 0.7, 0.58, 0.72), lamp = Color(1.0, 0.7, 0.36, 0.9), tone = Color(1.0, 1.0, 1.0), mist = Color(0.72, 0.88, 0.8, 0.1), calm = Vector2(0.72, 0.76)},
	{ambient = Color(0.6, 0.5, 0.82, 0.62), lamp = Color(1.0, 0.72, 0.5, 0.9), tone = Color(1.0, 1.0, 1.0), mist = Color(0.72, 0.6, 0.9, 0.07), calm = Vector2(0.74, 0.8)},
	{ambient = Color(0.46, 0.44, 0.64, 0.58), lamp = Color(1.0, 0.8, 0.42, 0.95), tone = Color(1.0, 1.0, 1.0), mist = Color(0.6, 0.52, 0.7, 0.06), calm = Vector2(0.8, 0.8)},
]
# What drifts in each theme's air (area_air.gdshader): a mote's colour
# (alpha: how bright), which way and how fast they drift (world px a
# second), the share of the air's cells that hold one, a mote's size (world
# px) and how much it flickers. Dust settling in the ruins and the crypt,
# spores and fireflies in the woods, embers off the ash, lights rising in
# the sanctum and out of the deep.
const AIRS := [
	{mote = Color(0.78, 0.84, 1.0, 0.3), drift = Vector2(-7.0, 9.0), share = 0.4, across = 2.4, flicker = 0.3},
	{mote = Color(0.74, 1.0, 0.72, 0.36), drift = Vector2(5.0, -9.0), share = 0.45, across = 2.4, flicker = 0.4},
	{mote = Color(1.0, 0.56, 0.2, 0.75), drift = Vector2(8.0, -38.0), share = 0.6, across = 2.2, flicker = 0.8},
	{mote = Color(0.86, 0.72, 1.0, 0.36), drift = Vector2(0.0, -12.0), share = 0.4, across = 2.6, flicker = 0.5},
	{mote = Color(0.86, 1.0, 0.5, 0.6), drift = Vector2(10.0, -4.0), share = 0.3, across = 2.6, flicker = 0.9},
	{mote = Color(0.8, 0.7, 1.0, 0.3), drift = Vector2(-4.0, 7.0), share = 0.4, across = 2.4, flicker = 0.3},
	{mote = Color(0.56, 0.78, 1.0, 0.45), drift = Vector2(0.0, -16.0), share = 0.45, across = 2.6, flicker = 0.6},
]
# Her light: its colour (alpha: how strong) and how far it reaches.
const HERO_LIGHT := Color(1.0, 0.95, 0.84, 0.74)
const HERO_REACH := 450.0
# What stands on the pillars, by theme: the atlas (its frames side by side),
# how many frames, how wide a frame is drawn in the world, which frame holds
# a fire (-1: none), where the fire burns in it (from the frame's bottom
# middle, as shares of the frame; tools/build_battle_art.py --measure tells
# how high each thing stands) and how large the flame is.
const PROP_SETS := {
	&"ruin": {atlas = "res://art/tiles/painted/props_ruin.png", frames = 4, across = 116.0, fire = 3, fire_at = Vector2(0.0, -0.6), flame = 1.0},
	&"ember": {atlas = "res://art/tiles/painted/props_ember.png", frames = 4, across = 116.0, fire = 3, fire_at = Vector2(0.0, -0.655), flame = 1.0},
	&"crypt": {atlas = "res://art/tiles/painted/props_crypt.png", frames = 4, across = 116.0, fire = 3, fire_at = Vector2(0.0, -0.645), flame = 0.55},
	&"abyss": {atlas = "res://art/tiles/painted/props_abyss.png", frames = 4, across = 116.0, fire = 3, fire_at = Vector2(0.0, -0.47), flame = 0.7},
	&"trees": {atlas = "res://art/tiles/painted/forest_trees.png", frames = 4, across = 124.0, fire = -1, fire_at = Vector2.ZERO, flame = 1.0},
}
const PROPS_BY_THEME: Array[StringName] = [&"ruin", &"ruin", &"ember", &"ruin", &"trees", &"crypt", &"abyss"]
# A fire on a pillar and on the far wall: how far each lights the floor, the
# flame's size, and how far apart the wall's fires hang (cells).
const PROP_LAMP := 300.0
const WALL_LAMP := 330.0
const FLAME := Vector2(34.0, 54.0)
const WALL_FIRE_EVERY := 9
const SCONCE_ACROSS := 30.0
# The leavings on the floor: one to about this much floor (world px
# squared), each drawn about this wide, kept this far from walls.
const DECAL_FRAMES := Vector2i(3, 2)
const DECAL_ROOM := 170000.0
const DECAL_ACROSS := Vector2(40.0, 70.0)
const DECAL_CLEAR := 34.0
# The leavings are old: darker than they were painted, sunk into the floor.
const DECAL_TINT := Color(0.82, 0.8, 0.8, 0.92)
# How much of the place's light a standing thing and a lying thing take (the
# rest is their own, so they never sink wholly into the dark).
const UPRIGHT_HELD := 0.9
const FLAT_HELD := 1.0
# How dark a fighter far from her light is drawn (CombatArea shades the foes).
const FAR_SHADE := 0.8

var size := Vector2i.ZERO
var walls: Dictionary = {}
var screened: Dictionary = {}
var theme := 0
# Inner walls nothing stands for, drawn from the atlas.
var terrain: TileMapLayer
var body: StaticBody2D
var sheet: ColorRect
# The air over the fight (what drifts in it).
var air: ColorRect
var _air: ShaderMaterial
# The fires: where each burns and how far it lights (x, y, reach).
var lamps: Array[Vector3] = []
# The whole place brightened (an area cleared) and reddened (a boss enraged).
var lift := 1.0
var dread := 0.0
var _floor: ShaderMaterial
var _upright: ShaderMaterial
var _flat: ShaderMaterial
var _flames: Array[ShaderMaterial] = []
var _fires: Node2D
var _decals: Node2D
var _hero := Vector2.ZERO
var _eye := Vector2.ZERO
var _clock := 0.0
# Flashes still fading: [where, reach, strength, colour, seconds left, seconds in all].
var _flashes: Array = []
var _shown_lamps := PackedVector3Array()
var _lamps_at := Vector2.INF


func build(cells: Vector2i, wall_cells: Dictionary, theme_index: int = 0, screened_cells: Dictionary = {}) -> void:
	size = cells
	walls = wall_cells
	screened = screened_cells
	theme = clampi(theme_index, 0, THEMES.size() - 1)
	var mood: Dictionary = MOODS[theme]
	_floor = ShaderMaterial.new()
	_floor.shader = FLOOR_SHADER
	_floor.set_shader_parameter(&"stone", load(STONES % THEMES[theme]))
	_floor.set_shader_parameter(&"rock", load(ROCKS % THEMES[theme]))
	_floor.set_shader_parameter(&"plan", _plan())
	_floor.set_shader_parameter(&"room", bounds().size)
	_floor.set_shader_parameter(&"period", PERIOD)
	_floor.set_shader_parameter(&"wall", float(CELL))
	_floor.set_shader_parameter(&"face", FACE)
	_floor.set_shader_parameter(&"tone", mood.tone)
	_floor.set_shader_parameter(&"mist", mood.mist)
	_floor.set_shader_parameter(&"calm", mood.calm)
	_floor.set_shader_parameter(&"sheet_from", -Vector2.ONE * MARGIN)
	_floor.set_shader_parameter(&"sheet_size", bounds().size + Vector2.ONE * MARGIN * 2.0)
	_upright = _lit_material(1.0, mood.tone)
	_flat = _lit_material(0.0, mood.tone)
	sheet = ColorRect.new()
	sheet.name = "Sheet"
	sheet.material = _floor
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.position = -Vector2.ONE * MARGIN
	sheet.size = bounds().size + Vector2.ONE * MARGIN * 2.0
	add_child(sheet)
	_build_terrain()
	_decals = Node2D.new()
	_decals.name = "Decals"
	add_child(_decals)
	_fires = Node2D.new()
	_fires.name = "Fires"
	add_child(_fires)
	_hang_wall_fires()
	_build_body()
	# The air over the fight: drawn above the fighters, as light.
	var drifting: Dictionary = AIRS[theme]
	_air = ShaderMaterial.new()
	_air.shader = AIR_SHADER
	for key: String in drifting:
		_air.set_shader_parameter(key, drifting[key])
	_air.set_shader_parameter(&"sheet_from", Vector2.ZERO)
	_air.set_shader_parameter(&"sheet_size", bounds().size)
	air = ColorRect.new()
	air.name = "Air"
	air.material = _air
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	air.size = bounds().size
	air.z_index = AIR_Z
	add_child(air)
	_hero = bounds().get_center()
	_eye = _hero
	_send()


func _lit_material(upright: float, tone: Color) -> ShaderMaterial:
	var lit := ShaderMaterial.new()
	lit.shader = LIT_SHADER
	lit.set_shader_parameter(&"upright", upright)
	lit.set_shader_parameter(&"held", UPRIGHT_HELD if upright > 0.5 else FLAT_HELD)
	lit.set_shader_parameter(&"tone", tone)
	return lit


# The material of a thing that stands on this ground, and of one that lies on it.
func upright_material() -> ShaderMaterial:
	return _upright


func flat_material() -> ShaderMaterial:
	return _flat


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


# --- The light ---

# Where her light is now, and where the view's middle is (the fires nearest
# it are the ones the shaders are told of).
func follow(hero_at: Vector2, eye_at: Vector2) -> void:
	_hero = hero_at
	_eye = eye_at


# A fire that lights the floor round it.
func add_lamp(at: Vector2, reach: float) -> void:
	lamps.append(Vector3(at.x, at.y, reach))
	_lamps_at = Vector2.INF


# A flash of light where a blow lands, fading over `time`.
func flash(at: Vector2, reach: float, strength: float, colour := Color(1.0, 0.9, 0.7), time := 0.28) -> void:
	if _flashes.size() >= FLASHES:
		_flashes.pop_front()
	_flashes.append([at, reach, strength, colour, time, time])


# How lit a fighter at a point is drawn: whole in her light, FAR_SHADE far
# from it. (Her light alone: the fires' is left to the eye.)
func shade_at(at: Vector2) -> float:
	var near := clampf(1.0 - at.distance_to(_hero) / (HERO_REACH * 1.25), 0.0, 1.0)
	return lerpf(FAR_SHADE, 1.0, near * near * (3.0 - 2.0 * near)) * minf(lift, 1.25)


func _process(delta: float) -> void:
	_clock += delta
	for index in range(_flashes.size() - 1, -1, -1):
		_flashes[index][4] -= delta
		if _flashes[index][4] <= 0.0:
			_flashes.remove_at(index)
	_send()


# The light as it is now, told to the floor and to what stands and lies on it.
func _send() -> void:
	if _floor == null:
		return
	# The fires nearest the view's middle; chosen again once it has moved a way.
	if _lamps_at.distance_to(_eye) > 140.0:
		_lamps_at = _eye
		var near := lamps.duplicate()
		near.sort_custom(func(a: Vector3, b: Vector3) -> bool: return Vector2(a.x, a.y).distance_squared_to(_eye) < Vector2(b.x, b.y).distance_squared_to(_eye))
		_shown_lamps = PackedVector3Array(near.slice(0, LAMPS))
		_shown_lamps.resize(LAMPS)
	var flashes := PackedVector4Array()
	var colours := PackedColorArray()
	for flash_now: Array in _flashes:
		var left: float = flash_now[4] / flash_now[5]
		flashes.append(Vector4((flash_now[0] as Vector2).x, (flash_now[0] as Vector2).y, flash_now[1], flash_now[2] * left * left))
		colours.append(flash_now[3])
	flashes.resize(FLASHES)
	colours.resize(FLASHES)
	var mood: Dictionary = MOODS[theme]
	for lit: ShaderMaterial in [_floor, _upright, _flat]:
		lit.set_shader_parameter(&"ambient", mood.ambient)
		lit.set_shader_parameter(&"hero", _hero)
		lit.set_shader_parameter(&"hero_reach", HERO_REACH)
		lit.set_shader_parameter(&"hero_colour", HERO_LIGHT)
		lit.set_shader_parameter(&"lamps", _shown_lamps)
		lit.set_shader_parameter(&"lamp_colour", mood.lamp)
		lit.set_shader_parameter(&"flashes", flashes)
		lit.set_shader_parameter(&"flash_colours", colours)
		lit.set_shader_parameter(&"clock", _clock)
		lit.set_shader_parameter(&"lift", lift)
		lit.set_shader_parameter(&"dread", dread)
	for flame in _flames:
		flame.set_shader_parameter(&"clock", _clock)
	if _air != null:
		_air.set_shader_parameter(&"clock", _clock)


# --- What stands and lies on it ---

# A thing on each pillar (its top-left cell given), rooted at the pillar's
# bottom edge and added to `into` (sorted among the fighters, so one walking
# behind it is hidden). The first `placed` are the area's own pillars: every
# other one of them holds a fire, or all of them (`all_fires`, a boss's
# hall); the strewn ones are whichever their place draws.
func plant(corners: Array[Vector2i], into: Node2D, placed: int = 0, all_fires: bool = false) -> void:
	var prop_set: Dictionary = PROP_SETS[PROPS_BY_THEME[theme]]
	var atlas: Texture2D = load(prop_set.atlas)
	var frames: int = prop_set.frames
	var frame := Vector2(atlas.get_width() / float(frames), atlas.get_height())
	var fire: int = prop_set.fire
	var plain := frames - (1 if fire >= 0 else 0)
	for index in corners.size():
		var corner := corners[index]
		var kind := posmod(hash(corner), frames)
		if index < placed and fire >= 0:
			kind = fire if all_fires or index % 2 == 0 else posmod(hash(corner), plain)
		var prop := Sprite2D.new()
		var picture := AtlasTexture.new()
		picture.atlas = atlas
		picture.region = Rect2(kind * frame.x, 0.0, frame.x, frame.y)
		prop.texture = picture
		prop.offset = Vector2(0.0, -frame.y * 0.5)
		prop.scale = Vector2.ONE * (prop_set.across as float) / frame.x
		prop.position = (Vector2(corner) + Vector2(1.0, 2.0)) * CELL
		prop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		prop.material = _upright
		into.add_child(prop)
		if kind == fire:
			var at: Vector2 = prop.position + (prop_set.fire_at as Vector2) * Vector2(frame.x, frame.y) * prop.scale
			add_lamp(prop.position + Vector2(0.0, -8.0), PROP_LAMP)
			var flame := _flame(at, hash(corner) % 97, prop_set.flame)
			# With the fighters, just in front of its prop.
			flame.position = Vector2(at.x, prop.position.y + 1.0)
			(flame.get_child(0) as Control).position.y += at.y - prop.position.y - 1.0
			into.add_child(flame)


# A flame: a holder at a point with the fire drawn up from it.
func _flame(at: Vector2, seed_number: int, grown: float = 1.0) -> Node2D:
	var look := ShaderMaterial.new()
	look.shader = FIRE_SHADER
	look.set_shader_parameter(&"colour", (MOODS[theme].lamp as Color))
	look.set_shader_parameter(&"seed", float(seed_number))
	look.set_shader_parameter(&"power", 0.9)
	_flames.append(look)
	var holder := Node2D.new()
	holder.position = at
	var fire := ColorRect.new()
	fire.material = look
	fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fire.size = FLAME * grown
	fire.position = Vector2(-FLAME.x * 0.5, -FLAME.y) * grown
	holder.add_child(fire)
	return holder


# Fires along the far wall's face, each in its sconce.
func _hang_wall_fires() -> void:
	var count := maxi(1, int(size.x / WALL_FIRE_EVERY))
	var room := bounds().size
	for index in count:
		var x := room.x * (index + 0.5) / count
		var at := Vector2(x, -FACE * 0.34)
		var sconce := Sprite2D.new()
		sconce.texture = SCONCE
		sconce.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sconce.scale = Vector2.ONE * SCONCE_ACROSS / SCONCE.get_width()
		sconce.position = at + Vector2(0.0, SCONCE.get_height() * sconce.scale.y * 0.3)
		_fires.add_child(sconce)
		_fires.add_child(_flame(at, index * 31 + 7))
		add_lamp(Vector2(x, CELL * 1.2), WALL_LAMP)


# The leavings of old fights over the open floor, the same for the same
# seed: rubble, bones, broken arms. Nothing stops on them.
func scatter(seed_number: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_number
	var frame := Vector2(DECALS.get_size()) / Vector2(DECAL_FRAMES)
	var room := bounds()
	var count := int(room.get_area() / DECAL_ROOM)
	for index in count:
		var at := Vector2(rng.randf_range(room.position.x, room.end.x), rng.randf_range(room.position.y, room.end.y))
		var kind := rng.randi_range(0, DECAL_FRAMES.x * DECAL_FRAMES.y - 1)
		var turn := rng.randf() * TAU
		var across := rng.randf_range(DECAL_ACROSS.x, DECAL_ACROSS.y)
		var flipped := rng.randf() < 0.5
		if not is_open(at, DECAL_CLEAR):
			continue
		var decal := Sprite2D.new()
		var picture := AtlasTexture.new()
		picture.atlas = DECALS
		picture.region = Rect2(Vector2(kind % DECAL_FRAMES.x, kind / DECAL_FRAMES.x) * frame, frame)
		decal.texture = picture
		decal.position = at
		decal.rotation = turn
		decal.scale = Vector2.ONE * across / frame.x
		decal.flip_h = flipped
		decal.modulate = DECAL_TINT
		decal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		decal.material = _flat
		_decals.add_child(decal)


# --- The plan, the inner walls, the body ---

# The room's cells as a small picture, bright where something stands inside
# it (not its edge), smoothed, so the floor can darken toward each foot.
func _plan() -> ImageTexture:
	var image := Image.create(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_L8)
	for cell: Vector2i in walls:
		if cell.x > 0 and cell.y > 0 and cell.x < size.x - 1 and cell.y < size.y - 1:
			image.set_pixelv(cell, Color.WHITE)
	image.resize(size.x * 4, size.y * 4, Image.INTERPOLATE_CUBIC)
	return ImageTexture.create_from_image(image)


# An inner wall nothing stands for, drawn as one from the atlas.
func _drawn(cell: Vector2i) -> bool:
	return walls.has(cell) and not screened.has(cell) and cell.x > 0 and cell.y > 0 and cell.x < size.x - 1 and cell.y < size.y - 1


func _build_terrain() -> void:
	terrain = TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = _tileset(ATLASES[theme])
	terrain.scale = Vector2.ONE * CELL / PAINTED_CELL
	terrain.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	terrain.material = _flat
	add_child(terrain)
	terrain.position = Vector2.ONE * CELL / 2.0 - terrain.map_to_local(Vector2i.ZERO) * terrain.scale
	for cell: Vector2i in walls:
		if _drawn(cell):
			terrain.set_cell(cell, 0, _coords(_tile(cell)))


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


func _tile(cell: Vector2i) -> int:
	var mask := 0
	for bit: int in 4:
		if _drawn(cell + ([Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT] as Array[Vector2i])[bit]):
			mask |= 1 << bit
	var spot := posmod(cell.x, WALL_PERIOD) + posmod(cell.y, WALL_PERIOD) * WALL_PERIOD
	return WALL_START + mask if spot == 0 else WALL_SPOT_START + (spot - 1) * WALL_COUNT + mask


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
