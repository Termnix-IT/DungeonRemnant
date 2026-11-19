class_name RouteGateView
extends Node2D

# One gate of the route's choice (RouteGates), built of layers so that a
# place can be seen through it: a halo behind it; the place it leads to, in
# its light (a road, an arena, a small chamber or the boss's nave, by the
# area's kind); what leads the area standing on its threshold; the dust
# drifting there and the mist its feet stand in; the iron grille that comes
# down in a gate not chosen; and over them the chapter's painted stone, lit
# round its opening by the light inside. A gate wears its area's kind
# (DRESS), so that what waits beyond is read from its outline before its
# light: a field's stands bare; a trial's has a shield and crossed swords on
# its gable, spiked iron along its roof, a war banner down either jamb and a
# fire burning beside each; an event's has a lantern hanging in its arch,
# strings of charms from its shoulders and candles at its feet; the boss's
# wears a horned crown, the spikes and banners of a trial in its own red,
# and a spiked pylon at either side. The page tells it how far it is turned to, how open
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
const MIST := preload("res://ui/route_map/route_gate_mist.gdshader")
const FIRE := preload("res://ui/route_map/route_fire.gdshader")
const STONES := "res://art/ui/route/gate_%s.png"
const LIGHTS := "res://art/ui/route/gate_%s_light.png"
const INSIDES := "res://art/ui/route/inside_%s.png"
const FINIALS := "res://art/ui/route/finial_%s.png"
const GRILLE := "res://art/ui/route/gate_bars.png"
const BRAZIER := "res://art/ui/route/brazier.png"
const PARTS := "res://art/ui/route/dress_%s.png"
const PYLON := "res://art/ui/route/hall_pillar.png"
# The gate a chapter without its own is given.
const FALLBACK := &"ash_corridor"
# The kinds a gate is dressed by.
const FIELD := &"field"
const ARENA := &"arena"
const EVENT := &"event"
const BOSS := &"boss"
# What each kind's gate wears. A kind added to the game is dressed by a row
# here; a part is drawn only where its picture exists.
const DRESS := {
	FIELD: [],
	ARENA: [&"crest", &"ridges", &"banners", &"fires"],
	EVENT: [&"lantern", &"charms", &"candles"],
	BOSS: [&"pylons", &"crest", &"ridges", &"banners", &"fires"],
}
# How tall the stone stands on the page when it is not turned to, how much
# it grows turned to, and how far down its gable the keystone's middle lies
# (as a share of the way from its top to the opening's tip).
const HEIGHT := 356.0
const GROWTH := 0.11
const SHRINK := 0.03
const KEYSTONE := 0.55
# The room what stands in it may take, as shares of the opening: wider than
# the opening itself, as it stands behind the stone and a broad one's sides
# are hidden by the jambs.
const FIGURE_ROOM := Vector2(1.14, 0.78)
# The light's strength when the gate smoulders (a gate not turned to is
# still a way to weigh: its stone, its place and its name stay readable),
# and when all but out.
const SMOULDER := 0.56
const EMBER := 0.07
# The hall's own light on the stone of a gate not turned to and of the one
# turned to, and how much of it is left on one that is shut.
const STONE_DIM := 0.5
const STONE_LIT := 0.76
const STONE_SHUT := 0.66
# How much of a foe she has met shows in its shape before its gate is
# turned to, how far it starts as it is (a share of its size), how fast the
# start dies (a second), and how far it slides against the stone as the
# view leans (px).
const GLIMPSE := 0.5
const START := 0.045
const START_FADE := 3.4
const FIGURE_LEAN := 3.0
# What crowns the gable: how tall it stands (a share of the stone's height)
# and how far down from the stone's top its foot rests. The event's lantern
# hangs from the arch's tip instead, this tall (a share of the opening's).
const CREST := 0.15
const CREST_REST := 0.08
const LANTERN := 0.25
# The spiked iron along the roof: the stretch of each slope it lies on (from
# the shoulder, 0, to the peak, 1). A banner: how tall (a share of the
# opening's height) and how far up the opening it hangs from. A string of
# charms: how tall (a share of the stone's height). A cluster of candles:
# how tall (a share of the stone's), how far outside the stone's edge it
# stands (px), and where its wicks are in its picture. The boss's pylons:
# how tall (a share of the stone's) and how far outside the stone's edge
# their middles stand (a share of their width).
const RIDGE := Vector2(0.1, 0.7)
const BANNER := 0.46
const BANNER_FROM := 0.6
const CHARMS := 0.36
const CANDLES := 0.15
const CANDLES_OUT := 4.0
const WICKS: Array[Vector2] = [Vector2(0.47, 0.03), Vector2(0.21, 0.27), Vector2(0.74, 0.37), Vector2(0.6, 0.53), Vector2(0.32, 0.62)]
const PYLON_TALL := 0.8
const PYLON_OUT := 0.3
# A fire's stand: how tall (a share of the stone's height) and how far
# outside the opening's side its middle stands (a share of the opening's
# width); and the fires' colours.
const STAND := 0.37
const STAND_OUT := 0.37
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
var mist: Sprite2D
var bars: Sprite2D
var stone: Sprite2D
# What it wears for its kind: the crest on its gable or the lantern in its
# arch (with the lantern's light), and its fires (stand, flame and sparks).
var crest: Sprite2D
var lamp: Sprite2D
var stands: Array[Sprite2D] = []
var flames: Array[Sprite2D] = []
var embers: Array[CPUParticles2D] = []
# The rest of its dress, a pair of each (left, right): the spiked iron on
# its roof, its banners, its strings of charms, its candles (with a flame
# on every wick) and the boss's pylons (with their spikes).
var ridges: Array[Sprite2D] = []
var banners: Array[Sprite2D] = []
var charms: Array[Sprite2D] = []
var candles: Array[Sprite2D] = []
var wicks: Array[Sprite2D] = []
var pylons: Array[Sprite2D] = []
var caps: Array[Sprite2D] = []
var burst: CPUParticles2D
var dust: CPUParticles2D
var sparks: CPUParticles2D
# The start what stands in it gives as the gate is turned to (1, dying to 0).
var _stir := 0.0
# The stone's size in its picture, and its opening there (px).
var _size := Vector2(745.0, 1000.0)
var _opening := Rect2(117.0, 224.0, 511.0, 776.0)
var _shape := Color(0.03, 0.028, 0.03)
# How high its fires burn now (eased), and a number that sets its flames,
# its breath and its lantern's sway apart from the next gate's.
var _burning := 0.0
var _own := 0.0
static var _measured: Dictionary = {}
static var _roofs: Dictionary = {}
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
	if wears(&"pylons"):
		for side in 2:
			pylons.append(_part(PYLON))
			caps.append(_part(PARTS % &"ridge"))
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
	mist = _layer(light_art, MIST)
	_give(mist, &"opening", opening_at)
	_give(figure, &"own", _own)
	if wears(&"lantern"):
		crest = _part(FINIALS % EVENT)
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
	if wears(&"ridges"):
		for side in 2:
			ridges.append(_part(PARTS % &"ridge"))
	if wears(&"crest"):
		crest = _part(FINIALS % kind)
	if wears(&"banners"):
		for side in 2:
			banners.append(_part(PARTS % &"banner"))
	if wears(&"charms"):
		for side in 2:
			charms.append(_part(PARTS % &"charms"))
	if has_fires():
		for side in 2:
			stands.append(_part(BRAZIER))
			flames.append(_flame(_own * 3.1 + side * 5.7))
			var thrown := _embers()
			add_child(thrown)
			embers.append(thrown)
	if wears(&"candles"):
		for side in 2:
			candles.append(_part(PARTS % &"candles"))
			for wick in WICKS.size():
				wicks.append(_flame(_own * 2.3 + side * 4.1 + wick * 1.7))
	burst = _burst()
	add_child(burst)
	dust = _dust()
	add_child(dust)
	sparks = _sparks()
	add_child(sparks)
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


# Whether its kind's gate wears a part, and the part's picture is there.
func wears(what: StringName) -> bool:
	if not (DRESS.get(kind, []) as Array).has(what):
		return false
	match what:
		&"crest":
			return ResourceLoader.exists(FINIALS % kind)
		&"lantern":
			return ResourceLoader.exists(FINIALS % EVENT)
		&"fires":
			return ResourceLoader.exists(BRAZIER)
		&"pylons":
			return ResourceLoader.exists(PYLON) and ResourceLoader.exists(PARTS % &"ridge")
		&"ridges":
			return ResourceLoader.exists(PARTS % &"ridge")
		&"banners":
			return ResourceLoader.exists(PARTS % &"banner")
	return ResourceLoader.exists(PARTS % what)


# A part of its dress: a picture, laid by _dress.
func _part(path: String) -> Sprite2D:
	var part := Sprite2D.new()
	part.texture = load(path)
	add_child(part)
	return part


# A flame (a brazier's, a candle's), drawn whole by its shader.
func _flame(seed: float) -> Sprite2D:
	var flame := Sprite2D.new()
	flame.texture = blank()
	var burning := ShaderMaterial.new()
	burning.shader = FIRE
	burning.set_shader_parameter(&"colour", fire_colour())
	burning.set_shader_parameter(&"seed", seed)
	flame.material = burning
	add_child(flame)
	return flame


# The roof of a gate's stone, read from its picture: where its left shoulder
# and its peak lie (px), a line fitted to the stone's upper edge.
static func roof_of(stone_art: Texture2D) -> PackedVector2Array:
	if _roofs.has(stone_art):
		return _roofs[stone_art]
	var image := stone_art.get_image()
	if image.is_compressed():
		image.decompress()
	var wide := image.get_width()
	var high := image.get_height()
	var count := 9
	var sum := Vector2.ZERO
	var sum_xx := 0.0
	var sum_xy := 0.0
	for index in count:
		var x := roundi(wide * lerpf(0.14, 0.44, index / float(count - 1)))
		var y := 0
		while y < high - 1 and image.get_pixel(x, y).a < 0.5:
			y += 1
		sum += Vector2(x, y)
		sum_xx += float(x) * x
		sum_xy += float(x) * y
	var slope := (count * sum_xy - sum.x * sum.y) / maxf(1.0, count * sum_xx - sum.x * sum.x)
	var base := (sum.y - slope * sum.x) / count
	var roof := PackedVector2Array([Vector2(0.0, base), Vector2(wide * 0.5, base + slope * wide * 0.5)])
	_roofs[stone_art] = roof
	return roof


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


# The sparks struck off the threshold as the grille's points land.
func _sparks() -> CPUParticles2D:
	var struck := CPUParticles2D.new()
	struck.texture = spark()
	struck.material = _adding()
	struck.emitting = false
	struck.one_shot = true
	struck.explosiveness = 1.0
	struck.amount = 16
	struck.lifetime = 0.42
	struck.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	struck.direction = Vector2.UP
	struck.spread = 70.0
	struck.gravity = Vector2(0.0, 520.0)
	struck.initial_velocity_min = 60.0
	struck.initial_velocity_max = 190.0
	struck.scale_amount_min = 0.02
	struck.scale_amount_max = 0.05
	struck.color = Color(1.0, 0.78, 0.46)
	var life := Gradient.new()
	life.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	life.set_color(1, Color(1.0, 0.6, 0.3, 0.0))
	struck.color_ramp = life
	return struck


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
	for layer: Sprite2D in [inside, stone, bars, mist]:
		_give(layer, &"colour", colour)
	_give(figure, &"rim", colour)
	motes.color = colour.lerp(Color.WHITE, 0.35)
	burst.color = colour.lerp(Color.WHITE, 0.5)


# --- What it wears ---

# A trial's gate and the boss's have a fire beside either jamb.
func has_fires() -> bool:
	return wears(&"fires")


# An event's candles burn in the gate's own light; a fire in its own.
func fire_colour() -> Color:
	if wears(&"candles"):
		return colour.lerp(Color(1.0, 0.92, 0.8), 0.45)
	return BOSS_FLAME if kind == BOSS else FLAME


# How strongly its fires (or its candles) light the floor now (0 without
# any), and how far from its middle they stand on the page.
func fire_power() -> float:
	if has_fires():
		return _burning
	return _burning * 0.42 if wears(&"candles") else 0.0


func fire_off() -> float:
	if wears(&"candles"):
		return size().x * 0.5 + CANDLES_OUT
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
	_stir = 1.0


# The grille has landed: dust knocked up, sparks struck off the stone.
func land() -> void:
	dust.restart()
	dust.emitting = true
	sparks.restart()
	sparks.emitting = true


# Lays every layer for the state it is in; `clock` moves its light.
func apply(clock: float, delta := 0.0) -> void:
	if inside == null:
		return
	var unit := _unit()
	var corner := box().position
	var strength := power()
	var open_size := opening()
	for layer: Sprite2D in [inside, mist, bars, stone]:
		layer.position = corner
		layer.scale = Vector2.ONE * unit
		layer.self_modulate.a = rise
	_stir = maxf(0.0, _stir - delta * START_FADE)
	# Its fires: high when it is turned to, down to embers when it is shut or
	# still in the dark.
	var burn := 0.0
	if has_fires() or wears(&"candles"):
		burn = 0.12 if dark else (0.62 + 0.38 * lit + flare * 0.5) * (0.16 + 0.84 * open_share)
	_burning = burn if delta <= 0.0 else move_toward(_burning, burn, delta * 2.6)
	_give(inside, &"power", strength)
	_give(inside, &"clock", clock + _own * 11.0)
	_give(inside, &"flood", flood)
	_give(inside, &"deep", near)
	_give(inside, &"shift", Vector2(-lean * LEAN - aside * ASIDE, 0.0))
	_give(stone, &"power", strength)
	_give(stone, &"ambient", lerpf(STONE_DIM, STONE_LIT, lit) * lerpf(STONE_SHUT, 1.0, open_share))
	_give(mist, &"power", strength * (1.0 - parted))
	_give(mist, &"clock", clock + _own * 7.0)
	_give(stone, &"fire", _burning * rise * (0.5 if has_fires() else 0.0))
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
		# It starts as its gate is turned to (a quick swell from its feet),
		# and slides a hair against the stone as the view leans: it stands
		# nearer than the place behind it.
		var start := 1.0 + START * _stir * _stir
		figure.scale = Vector2(kept * start, kept * start)
		figure.position = Vector2(-full.x * kept * start * 0.5 - (lean + aside * 0.5) * FIGURE_LEAN, -full.y * kept * start - 2.0)
		figure.self_modulate.a = rise * (0.25 + 0.75 * open_share) * (1.0 - parted)
		_give(figure, &"seen", lit * open_share if known and not dark else 0.0)
		_give(figure, &"glimpse", GLIMPSE * open_share if known and not dark else 0.0)
		_give(figure, &"alive", 1.0 if alive else 0.0)
		_give(figure, &"clock", clock)
		_give(figure, &"stir", _stir)
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
	var unit := _unit()
	var corner := box().position
	# Iron in the hall's dim light, catching the gate's own.
	var iron := Color(0.5, 0.52, 0.6).lerp(colour, 0.3) * (0.5 + 0.6 * clampf(strength, 0.0, 1.2))
	iron.a = rise
	if crest != null:
		var art := crest.texture.get_size()
		if wears(&"lantern"):
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
	# The spiked iron along its roof: on either slope, between the shoulder
	# and the crest, its foot on the stone.
	if not ridges.is_empty():
		var roof := roof_of(stone.texture)
		var from := corner + roof[0].lerp(roof[1], RIDGE.x) * unit
		var to := corner + roof[0].lerp(roof[1], RIDGE.y) * unit
		var middle := (from + to) * 0.5
		var across := -corner.x * 2.0 - _size.x * unit
		for side in ridges.size():
			var ridge := ridges[side]
			var art := ridge.texture.get_size()
			ridge.scale = Vector2.ONE * from.distance_to(to) / art.x
			ridge.offset = Vector2(0.0, -art.y * 0.42)
			ridge.flip_h = side == 1
			# The right slope is the left one seen in a glass.
			var mirrored := Vector2(-middle.x - across, middle.y) if side == 1 else middle
			ridge.position = mirrored
			ridge.rotation = (to - from).angle() * (-1.0 if side == 1 else 1.0)
			ridge.modulate = iron
	# Its banners: down the front of either jamb, stirring.
	for side in banners.size():
		var banner := banners[side]
		var art := banner.texture.get_size()
		var tall := open_size.y * BANNER
		var way := -1.0 if side == 0 else 1.0
		banner.scale = Vector2.ONE * tall / art.y
		banner.offset = Vector2(0.0, art.y * 0.5)
		banner.position = Vector2(way * (open_size.x * 0.5 + (size().x - open_size.x) * 0.24), -open_size.y * BANNER_FROM)
		banner.rotation = sin(clock * 0.9 + _own + side * 1.9) * 0.022
		banner.skew = sin(clock * 1.3 + _own * 2.0 + side) * 0.03
		var cloth := Color(0.62, 0.56, 0.52).lerp(fire_colour() if kind == BOSS else colour, 0.42) * (0.42 + 0.5 * clampf(strength, 0.0, 1.2))
		banner.modulate = Color(cloth.r, cloth.g, cloth.b, rise)
	# Its strings of charms: from either shoulder, swaying slowly.
	for side in charms.size():
		var string := charms[side]
		var art := string.texture.get_size()
		var tall := high * CHARMS
		var way := -1.0 if side == 0 else 1.0
		string.scale = Vector2.ONE * tall / art.y
		string.offset = Vector2(0.0, art.y * 0.5)
		string.flip_h = side == 1
		var roof := roof_of(stone.texture)
		string.position = Vector2(way * (size().x * 0.5 - 9.0), corner.y + roof[0].y * unit + 10.0)
		string.rotation = sin(clock * 0.8 + _own * 1.7 + side * 2.6) * 0.045
		var cloth := Color(0.74, 0.72, 0.68).lerp(colour, 0.3) * (0.5 + 0.5 * clampf(strength, 0.0, 1.2))
		string.modulate = Color(cloth.r, cloth.g, cloth.b, rise)
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
	# Its candles: a cluster at either foot, a small flame on every wick.
	for side in candles.size():
		var cluster := candles[side]
		var art := cluster.texture.get_size()
		var tall := high * CANDLES
		var at := Vector2((-1.0 if side == 0 else 1.0) * fire_off(), 5.0)
		cluster.scale = Vector2.ONE * tall / art.y
		cluster.flip_h = side == 1
		cluster.position = at + Vector2(0.0, -tall * 0.5)
		var wax := Color(0.5, 0.48, 0.5).lerp(fire_colour(), 0.3 * _burning) * (0.75 + 0.45 * _burning)
		cluster.modulate = Color(wax.r, wax.g, wax.b, rise)
		var wide := art.x * cluster.scale.x
		for wick in WICKS.size():
			var flame := wicks[side * WICKS.size() + wick]
			var where := WICKS[wick]
			if side == 1:
				where.x = 1.0 - where.x
			var reach := Vector2(tall * 0.2, tall * 0.34)
			flame.scale = reach / 4.0
			flame.position = at + Vector2((where.x - 0.5) * wide, -tall + where.y * tall - reach.y * 0.42)
			flame.modulate.a = rise
			var burning := flame.material as ShaderMaterial
			burning.set_shader_parameter(&"colour", fire_colour())
			burning.set_shader_parameter(&"power", _burning * 0.9)
			burning.set_shader_parameter(&"clock", clock)
	# The boss's pylons: a column at either side, behind the gate, crowned
	# with spikes.
	for side in pylons.size():
		var pylon := pylons[side]
		var art := pylon.texture.get_size()
		var tall := high * PYLON_TALL
		var way := -1.0 if side == 0 else 1.0
		pylon.scale = Vector2.ONE * tall / art.y
		pylon.flip_h = side == 1
		pylon.region_enabled = true
		pylon.region_rect = Rect2(0.0, art.y * 0.42, art.x, art.y * 0.58)
		var shown := tall * 0.58
		var wide := art.x * pylon.scale.x
		var at := Vector2(way * (size().x * 0.5 + wide * PYLON_OUT), 4.0)
		pylon.position = at + Vector2(0.0, -shown * 0.5)
		var dusk := Color(0.3, 0.29, 0.34).lerp(fire_colour(), 0.16 + 0.2 * _burning)
		pylon.modulate = Color(dusk.r, dusk.g, dusk.b, rise)
		var cap := caps[side]
		var spikes := cap.texture.get_size()
		cap.scale = Vector2.ONE * wide * 0.62 / spikes.x
		cap.position = at + Vector2(0.0, -shown - spikes.y * cap.scale.y * 0.3)
		cap.modulate = iron
