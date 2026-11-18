class_name RouteGateView
extends Node2D

# One gate of the route's choice (RouteGates), built of layers so that a
# place can be seen through it: a halo behind it; the place it leads to, in
# its light (a road, an arena, a small chamber or the boss's nave, by the
# area's kind); what leads the area standing on its threshold; the dust
# drifting there; the iron grille that comes down in a gate not chosen; and
# over them the chapter's painted stone, lit round its opening by the light
# inside. A gate wears its area's kind: a trial's has a shield and crossed
# swords on its gable and a fire burning at either jamb, an event's a lantern
# hanging in its arch, the boss's a horned crown and fires of its own red; a
# field's stands bare. The page tells it how far it is turned to, how open
# it is and how far it has risen, and asks it where its opening and its
# keystone lie; it draws no words.
#
# Its own place (0, 0) is its foot: the middle of its threshold. The stone
# and its light picture (gate_<chapter>.png and gate_<chapter>_light.png,
# built by tools/build_route_gates.py) say where the opening is, so a gate
# repainted in another shape needs nothing changed here.

const INSIDE := preload("res://ui/route_map/route_gate_inside.gdshader")
const FIGURE := preload("res://ui/route_map/route_gate_figure.gdshader")
const STONE := preload("res://ui/route_map/route_gate_stone.gdshader")
const BARS := preload("res://ui/route_map/route_gate_bars.gdshader")
const FIRE := preload("res://ui/route_map/route_fire.gdshader")
const STONES := "res://art/ui/route/gate_%s.png"
const LIGHTS := "res://art/ui/route/gate_%s_light.png"
const INSIDES := "res://art/ui/route/inside_%s.png"
const FINIALS := "res://art/ui/route/finial_%s.png"
const GRILLE := "res://art/ui/route/gate_bars.png"
const BRAZIER := "res://art/ui/route/brazier.png"
# The gate a chapter without its own is given.
const FALLBACK := &"ash_corridor"
# The kinds a gate is dressed by.
const FIELD := &"field"
const ARENA := &"arena"
const EVENT := &"event"
const BOSS := &"boss"
# How tall the stone stands on the page when it is not turned to, how much
# it grows turned to, and how far down its gable the keystone's middle lies
# (as a share of the way from its top to the opening's tip).
const HEIGHT := 364.0
const GROWTH := 0.11
const SHRINK := 0.03
const KEYSTONE := 0.55
# The room what stands in it may take, as shares of the opening: wider than
# the opening itself, as it stands behind the stone and a broad one's sides
# are hidden by the jambs.
const FIGURE_ROOM := Vector2(1.14, 0.78)
# The light's strength when the gate smoulders, and when all but out.
const SMOULDER := 0.4
const EMBER := 0.07
# What crowns the gable: how tall it stands (a share of the stone's height)
# and how far down from the stone's top its foot rests. The event's lantern
# hangs from the arch's tip instead, this tall (a share of the opening's).
const CREST := 0.15
const CREST_REST := 0.08
const LANTERN := 0.2
# A fire's stand: how tall (a share of the stone's height) and how far
# outside the opening's side its middle stands (a share of the opening's
# width); and the fires' colours.
const STAND := 0.37
const STAND_OUT := 0.25
const FLAME := Color(1.0, 0.56, 0.2)
const BOSS_FLAME := Color(1.0, 0.3, 0.14)
# How far the place beyond slides against the stone as the view leans, and
# for a gate standing off the hall's middle (shares of the opening's width).
const LEAN := 0.035
const ASIDE := 0.03

# The colour of what the gate gives.
var colour := Color.WHITE:
	set(value):
		colour = value
		_tint()
# How far it is turned to (0 to 1), a flare added on top for a moment, how
# open it is (1; 0 with its grille down), how far it has risen as the page
# opened, and whether it is the boss's still in the dark.
var lit := 0.0
var flare := 0.0
var open_share := 1.0
var rise := 1.0
var dark := false
# How far the grille has come down (0 to 1), and the light coming to meet
# her as she walks in (0 to 1).
var drop := 0.0
var flood := 0.0
# What stands in it is seen once turned to (a foe not met stays a shape).
var known := true
# The foe's own tint (a kin sharing another's picture).
var tone := Color.WHITE
# What stands in it is alive (it breathes; an event's object does not).
var alive := false
# How far the view leans (-1 to 1), how far off the hall's middle the gate
# stands (-1 to 1), how near she has come to its threshold (0 to 1), and how
# far what stands in it has given way to her (0 to 1: gone into the light).
var lean := 0.0
var aside := 0.0
var near := 0.0
var parted := 0.0
# Its area's kind (FIELD, ARENA, EVENT or BOSS).
var kind := FIELD

var halo: Sprite2D
var inside: Sprite2D
var figure: Sprite2D
var motes: CPUParticles2D
var bars: Sprite2D
var stone: Sprite2D
# What it wears for its kind: the crest on its gable or the lantern in its
# arch (with the lantern's light), and its fires (stand, flame and sparks).
var crest: Sprite2D
var lamp: Sprite2D
var stands: Array[Sprite2D] = []
var flames: Array[Sprite2D] = []
var embers: Array[CPUParticles2D] = []
var burst: CPUParticles2D
var dust: CPUParticles2D
# The stone's size in its picture, and its opening there (px).
var _size := Vector2(745.0, 1000.0)
var _opening := Rect2(117.0, 224.0, 511.0, 776.0)
var _shape := Color(0.03, 0.028, 0.03)
# How high its fires burn now (eased), and a number that sets its flames,
# its breath and its lantern's sway apart from the next gate's.
var _burning := 0.0
var _own := 0.0
static var _measured: Dictionary = {}
static var _spark: Texture2D
static var _blank: Texture2D


# Builds the gate for a chapter and an area's kind, with what stands in it
# (null: nothing).
func setup(chapter: StringName, area_kind: StringName, portrait: Texture2D, shape: Color) -> void:
	_shape = shape
	kind = area_kind
	_own = float(get_index()) * 2.39 + 0.7
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var stone_art := _art(STONES, chapter)
	var light_art := _art(LIGHTS, chapter)
	var grille: Texture2D = load(GRILLE)
	_size = stone_art.get_size()
	_opening = opening_in(light_art)
	var opening_uv := Rect2(_opening.position / _size, _opening.size / _size)
	var opening_at := Vector4(opening_uv.position.x, opening_uv.position.y, opening_uv.size.x, opening_uv.size.y)
	halo = Sprite2D.new()
	halo.texture = spark()
	halo.material = _adding()
	add_child(halo)
	inside = _layer(light_art, INSIDE)
	_give(inside, &"opening", opening_at)
	_give(inside, &"dark", shape)
	var beyond := INSIDES % kind
	_give(inside, &"beyond", load(beyond if ResourceLoader.exists(beyond) else INSIDES % FIELD))
	figure = Sprite2D.new()
	figure.centered = false
	figure.texture = portrait
	var seen := ShaderMaterial.new()
	seen.shader = FIGURE
	seen.set_shader_parameter(&"shape", shape)
	figure.material = seen
	figure.visible = portrait != null
	add_child(figure)
	motes = _motes(kind == BOSS)
	add_child(motes)
	if kind == EVENT and ResourceLoader.exists(FINIALS % EVENT):
		crest = Sprite2D.new()
		crest.texture = load(FINIALS % EVENT)
		add_child(crest)
		lamp = Sprite2D.new()
		lamp.texture = spark()
		lamp.material = _adding()
		add_child(lamp)
	bars = _layer(light_art, BARS)
	_give(bars, &"bars", grille)
	_give(bars, &"opening", opening_at)
	_give(bars, &"opening_tall", _opening.size.y / _opening.size.x)
	_give(bars, &"bars_tall", float(grille.get_height()) / grille.get_width())
	stone = _layer(stone_art, STONE)
	_give(stone, &"light_map", light_art)
	_give(stone, &"heart", opening_uv.get_center())
	_give(stone, &"fire_colour", fire_colour())
	if (kind == ARENA or kind == BOSS) and ResourceLoader.exists(FINIALS % kind):
		crest = Sprite2D.new()
		crest.texture = load(FINIALS % kind)
		add_child(crest)
	if has_fires():
		for side in 2:
			var stand := Sprite2D.new()
			stand.texture = load(BRAZIER)
			add_child(stand)
			stands.append(stand)
			var flame := Sprite2D.new()
			flame.texture = blank()
			var burning := ShaderMaterial.new()
			burning.shader = FIRE
			burning.set_shader_parameter(&"colour", fire_colour())
			burning.set_shader_parameter(&"seed", _own * 3.1 + side * 5.7)
			flame.material = burning
			add_child(flame)
			flames.append(flame)
			var thrown := _embers()
			add_child(thrown)
			embers.append(thrown)
	burst = _burst()
	add_child(burst)
	dust = _dust()
	add_child(dust)
	_tint()
	apply(0.0)


# The chapter's picture, or the first chapter's where it has none.
static func _art(pattern: String, chapter: StringName) -> Texture2D:
	var path := pattern % chapter
	return load(path if ResourceLoader.exists(path) else pattern % FALLBACK)


# Where the opening lies in a gate's light picture (px): its red, read down
# the middle for its tip and across near its foot for its sides.
static func opening_in(light_art: Texture2D) -> Rect2:
	if _measured.has(light_art):
		return _measured[light_art]
	var image := light_art.get_image()
	if image.is_compressed():
		image.decompress()
	var wide := image.get_width()
	var high := image.get_height()
	var top := 0
	while top < high - 1 and image.get_pixel(wide / 2, top).r < 0.5:
		top += 1
	var row := roundi(high * 0.9)
	var left := 0
	while left < wide - 1 and image.get_pixel(left, row).r < 0.5:
		left += 1
	var right := wide - 1
	while right > 0 and image.get_pixel(right, row).r < 0.5:
		right -= 1
	var found := Rect2(left, top, maxf(1.0, right + 1 - left), maxf(1.0, high - top))
	_measured[light_art] = found
	return found


# A soft round dot of light, for the halo and the dust.
static func spark() -> Texture2D:
	if _spark == null:
		var fade := Gradient.new()
		fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		fade.add_point(0.35, Color(1.0, 1.0, 1.0, 0.45))
		var dot := GradientTexture2D.new()
		dot.gradient = fade
		dot.fill = GradientTexture2D.FILL_RADIAL
		dot.fill_from = Vector2(0.5, 0.5)
		dot.fill_to = Vector2(1.0, 0.5)
		dot.width = 128
		dot.height = 128
		_spark = dot
	return _spark


# A plain white square, for what a shader draws whole (a flame).
static func blank() -> Texture2D:
	if _blank == null:
		var white := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
		white.fill(Color.WHITE)
		_blank = ImageTexture.create_from_image(white)
	return _blank


func _adding() -> CanvasItemMaterial:
	var adding := CanvasItemMaterial.new()
	adding.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return adding


func _layer(art: Texture2D, shader: Shader) -> Sprite2D:
	var layer := Sprite2D.new()
	layer.centered = false
	layer.texture = art
	var drawn := ShaderMaterial.new()
	drawn.shader = shader
	layer.material = drawn
	add_child(layer)
	return layer


func _give(layer: CanvasItem, item: StringName, value: Variant) -> void:
	(layer.material as ShaderMaterial).set_shader_parameter(item, value)


# The dust drifting in the gate's light; the boss's gate throws embers instead.
func _motes(boss: bool) -> CPUParticles2D:
	var drift := CPUParticles2D.new()
	drift.texture = spark()
	drift.material = _adding()
	drift.amount = 30 if boss else 22
	drift.lifetime = 2.8 if boss else 5.0
	drift.preprocess = drift.lifetime
	drift.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	drift.direction = Vector2.UP
	drift.spread = 16.0 if boss else 28.0
	drift.gravity = Vector2.ZERO
	drift.initial_velocity_min = 26.0 if boss else 4.0
	drift.initial_velocity_max = 62.0 if boss else 15.0
	drift.scale_amount_min = 0.03
	drift.scale_amount_max = 0.085 if boss else 0.07
	var life := Gradient.new()
	life.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	life.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	life.add_point(0.25, Color(1.0, 1.0, 1.0, 0.9))
	life.add_point(0.7, Color(1.0, 1.0, 1.0, 0.6))
	drift.color_ramp = life
	return drift


# The sparks thrown up from the threshold as the gate is turned to.
func _burst() -> CPUParticles2D:
	var thrown := CPUParticles2D.new()
	thrown.texture = spark()
	thrown.material = _adding()
	thrown.emitting = false
	thrown.one_shot = true
	thrown.explosiveness = 0.86
	thrown.amount = 30
	thrown.lifetime = 0.95
	thrown.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	thrown.direction = Vector2.UP
	thrown.spread = 34.0
	thrown.gravity = Vector2(0.0, -30.0)
	thrown.initial_velocity_min = 50.0
	thrown.initial_velocity_max = 190.0
	thrown.damping_min = 60.0
	thrown.damping_max = 110.0
	thrown.scale_amount_min = 0.045
	thrown.scale_amount_max = 0.14
	var life := Gradient.new()
	life.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	life.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	thrown.color_ramp = life
	return thrown


# The dust the grille knocks up as it lands.
func _dust() -> CPUParticles2D:
	var knocked := CPUParticles2D.new()
	knocked.texture = spark()
	knocked.emitting = false
	knocked.one_shot = true
	knocked.explosiveness = 0.95
	knocked.amount = 18
	knocked.lifetime = 0.9
	knocked.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	knocked.direction = Vector2.UP
	knocked.spread = 78.0
	knocked.gravity = Vector2(0.0, 40.0)
	knocked.initial_velocity_min = 16.0
	knocked.initial_velocity_max = 74.0
	knocked.damping_min = 40.0
	knocked.damping_max = 80.0
	knocked.scale_amount_min = 0.12
	knocked.scale_amount_max = 0.32
	var life := Gradient.new()
	life.set_color(0, Color(0.62, 0.6, 0.58, 0.34))
	life.set_color(1, Color(0.5, 0.5, 0.5, 0.0))
	knocked.color_ramp = life
	return knocked


# The sparks a fire throws up.
func _embers() -> CPUParticles2D:
	var thrown := CPUParticles2D.new()
	thrown.texture = spark()
	thrown.material = _adding()
	thrown.amount = 9
	thrown.lifetime = 1.3
	thrown.preprocess = 1.3
	thrown.randomness = 0.6
	thrown.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	thrown.direction = Vector2.UP
	thrown.spread = 20.0
	thrown.gravity = Vector2(0.0, -26.0)
	thrown.initial_velocity_min = 18.0
	thrown.initial_velocity_max = 52.0
	thrown.scale_amount_min = 0.02
	thrown.scale_amount_max = 0.055
	thrown.color = fire_colour().lerp(Color.WHITE, 0.3)
	var life := Gradient.new()
	life.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
	life.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	thrown.color_ramp = life
	return thrown


func _tint() -> void:
	if inside == null:
		return
	for layer: Sprite2D in [inside, stone, bars]:
		_give(layer, &"colour", colour)
	_give(figure, &"rim", colour)
	motes.color = colour.lerp(Color.WHITE, 0.35)
	burst.color = colour.lerp(Color.WHITE, 0.5)


# --- What it wears ---

# A trial's gate and the boss's have a fire at either jamb.
func has_fires() -> bool:
	return (kind == ARENA or kind == BOSS) and ResourceLoader.exists(BRAZIER)


func fire_colour() -> Color:
	return BOSS_FLAME if kind == BOSS else FLAME


# How high its fires burn now (0 without any), and how far from its middle
# they stand on the page.
func fire_power() -> float:
	return _burning if has_fires() else 0.0


func fire_off() -> float:
	return opening().x * (0.5 + STAND_OUT)


# --- Where it stands ---

# How much larger than HEIGHT it stands now.
func grown() -> float:
	var eased := lit * lit * (3.0 - 2.0 * lit)
	return 1.0 + GROWTH * eased - SHRINK * (1.0 - eased)


# Page px to a px of the stone's picture.
func _unit() -> float:
	return HEIGHT * grown() / _size.y


# The stone's whole size on the page now.
func size() -> Vector2:
	return _size * _unit()


# The opening's size on the page now, and how far its sides stand from the
# foot's middle.
func opening() -> Vector2:
	return _opening.size * _unit()


# The stone's box round the foot (the foot is the opening's middle below).
func box() -> Rect2:
	var unit := _unit()
	var middle := (_opening.position.x + _opening.size.x * 0.5) * unit
	return Rect2(-middle, -_size.y * unit, _size.x * unit, _size.y * unit)


# How far above its foot the gate reaches with what crowns it.
func crown() -> float:
	var high := size().y
	if crest != null and kind != EVENT:
		high += high * (CREST - CREST_REST)
	return high


# The keystone's middle, from the foot.
func keystone() -> Vector2:
	return Vector2(0.0, -(_size.y - _opening.position.y * KEYSTONE) * _unit())


# What stands in it, as it stands on the page now: its size (zero: nothing).
func figure_size() -> Vector2:
	if figure == null or figure.texture == null or not figure.visible:
		return Vector2.ZERO
	return figure.texture.get_size() * figure.scale * (1.0 - parted)


# How strongly its light stands now: in its opening, and so on the floor.
func power() -> float:
	if dark:
		return EMBER
	var steady := (SMOULDER + (1.0 - SMOULDER) * lit) * (EMBER * 2.0 + (1.0 - EMBER * 2.0) * open_share)
	return (steady + flare) * rise


# --- Its moments ---

# Sparks from the threshold: the gate is turned to (more of them, chosen).
func kindle(chosen := false) -> void:
	burst.amount = 54 if chosen else 30
	burst.restart()
	burst.emitting = true


# The grille has landed.
func land() -> void:
	dust.restart()
	dust.emitting = true


# Lays every layer for the state it is in; `clock` moves its light.
func apply(clock: float, delta := 0.0) -> void:
	if inside == null:
		return
	var unit := _unit()
	var corner := box().position
	var strength := power()
	var open_size := opening()
	for layer: Sprite2D in [inside, bars, stone]:
		layer.position = corner
		layer.scale = Vector2.ONE * unit
		layer.self_modulate.a = rise
	# Its fires: high when it is turned to, down to embers when it is shut or
	# still in the dark.
	var burn := 0.0
	if has_fires():
		burn = 0.12 if dark else (0.62 + 0.38 * lit + flare * 0.5) * (0.16 + 0.84 * open_share)
	_burning = burn if delta <= 0.0 else move_toward(_burning, burn, delta * 2.6)
	_give(inside, &"power", strength)
	_give(inside, &"clock", clock + _own * 11.0)
	_give(inside, &"flood", flood)
	_give(inside, &"deep", near)
	_give(inside, &"shift", Vector2(-lean * LEAN - aside * ASIDE, 0.0))
	_give(stone, &"power", strength)
	_give(stone, &"ambient", lerpf(0.34, 0.6, lit) * lerpf(0.55, 1.0, open_share))
	_give(stone, &"fire", _burning * rise * 0.5)
	_give(bars, &"drop", drop)
	_give(bars, &"power", strength)
	bars.visible = drop > 0.0
	# The halo behind it, breathing with the boss's.
	var beat := 0.8 + 0.2 * sin(clock * TAU / 1.8) if kind == BOSS else 1.0
	halo.position = Vector2(0.0, -open_size.y * 0.5)
	halo.scale = Vector2(open_size.x * 3.2, open_size.y * 2.0) / 128.0
	halo.modulate = Color(colour, clampf(strength * 0.34 * beat, 0.0, 0.8))
	# What stands in it: as large as its room, on the threshold, breathing
	# if it lives.
	var feet := Vector3(0.5, 0.3, 0.0)
	if figure.texture != null:
		var room := open_size * FIGURE_ROOM
		var full := figure.texture.get_size()
		var kept := minf(room.x / full.x, room.y / full.y)
		var breath := 1.0 + (0.011 * sin(clock * 1.7 + _own) if alive else 0.0)
		figure.scale = Vector2(kept, kept * breath)
		figure.position = Vector2(-full.x * kept * 0.5, -full.y * kept * breath - 2.0)
		figure.self_modulate.a = rise * (0.25 + 0.75 * open_share) * (1.0 - parted)
		_give(figure, &"seen", lit * open_share if known and not dark else 0.0)
		_give(figure, &"tint", tone)
		_give(figure, &"rim_power", clampf(strength * 1.2, 0.0, 1.4))
		_give(figure, &"edge_reach", 3.2 / maxf(kept, 0.05))
		feet = Vector3(0.5, full.x * kept / open_size.x * 0.4, rise * (1.0 - parted))
	_give(inside, &"feet", feet)
	motes.position = Vector2(0.0, -open_size.y * 0.42)
	motes.emission_rect_extents = Vector2(open_size.x * 0.42, open_size.y * 0.4)
	motes.modulate.a = clampf(strength, 0.0, 1.0) * (1.0 if not dark else 0.0)
	burst.position = Vector2(0.0, -6.0)
	burst.emission_rect_extents = Vector2(open_size.x * 0.4, 2.0)
	dust.position = Vector2(0.0, -4.0)
	dust.emission_rect_extents = Vector2(open_size.x * 0.46, 2.0)
	_dress(clock, strength)


# Lays what the gate wears for its kind.
func _dress(clock: float, strength: float) -> void:
	var high := size().y
	var open_size := opening()
	# Iron in the hall's dim light, catching the gate's own.
	var iron := Color(0.5, 0.52, 0.6).lerp(colour, 0.3) * (0.5 + 0.6 * clampf(strength, 0.0, 1.2))
	iron.a = rise
	if crest != null:
		var art := crest.texture.get_size()
		if kind == EVENT:
			# The lantern hangs from the arch's tip, swaying, alight in the
			# gate's colour.
			var tall := open_size.y * LANTERN
			crest.scale = Vector2.ONE * tall / art.y
			crest.offset = Vector2(0.0, art.y * 0.5)
			crest.position = Vector2(0.0, -open_size.y + 1.0)
			crest.rotation = sin(clock * 1.1 + _own) * 0.05
			crest.modulate = iron
			var hangs := crest.position + Vector2(0.0, tall * 0.62).rotated(crest.rotation)
			lamp.position = hangs
			lamp.scale = Vector2.ONE * tall * (1.5 + 0.1 * sin(clock * 5.3 + _own)) / 128.0
			lamp.modulate = Color(colour.lerp(Color.WHITE, 0.25), clampf(0.3 + strength * 0.6, 0.0, 1.0) * rise * (0.2 + 0.8 * open_share))
		else:
			var tall := high * CREST
			crest.scale = Vector2.ONE * tall / art.y
			crest.position = Vector2(0.0, -high + high * CREST_REST - tall * 0.5)
			crest.modulate = iron
	for side in stands.size():
		var stand := stands[side]
		var art := stand.texture.get_size()
		var tall := high * STAND
		var at := Vector2((-1.0 if side == 0 else 1.0) * fire_off(), 7.0)
		stand.scale = Vector2.ONE * tall / art.y
		stand.position = at + Vector2(0.0, -tall * 0.5)
		var warm := Color(0.46, 0.46, 0.52).lerp(fire_colour(), 0.4 * _burning)
		stand.modulate = Color(warm.r, warm.g, warm.b, rise)
		var bowl := art.x * stand.scale.x
		var flame := flames[side]
		var reach := Vector2(bowl * 1.5, bowl * 1.9)
		flame.scale = reach / 4.0
		flame.position = at + Vector2(0.0, -tall + bowl * 0.16 - reach.y * 0.5)
		flame.modulate.a = rise
		var burning := flame.material as ShaderMaterial
		burning.set_shader_parameter(&"power", _burning)
		burning.set_shader_parameter(&"clock", clock)
		var thrown := embers[side]
		thrown.position = at + Vector2(0.0, -tall + bowl * 0.1)
		thrown.emission_rect_extents = Vector2(bowl * 0.3, 2.0)
		thrown.modulate.a = clampf(_burning * 1.4 - 0.3, 0.0, 1.0) * rise
