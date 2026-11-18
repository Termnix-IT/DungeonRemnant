class_name RouteGateView
extends Node2D

# One gate of the route's choice (RouteGates), built of layers so that light
# can stand in it: a halo behind it, the veil of light in its opening, what
# leads the area standing in that light, the dust drifting there, the iron
# grille that comes down in a gate not chosen, and over them the chapter's
# painted stone, lit round its opening by the light inside. The page tells
# it how far it is turned to, how open it is and how far it has risen, and
# asks it where its opening and its keystone lie; it draws no words.
#
# Its own place (0, 0) is its foot: the middle of its threshold. The stone
# and its light picture (gate_<chapter>.png and gate_<chapter>_light.png,
# built by tools/build_route_gates.py) say where the opening is, so a gate
# repainted in another shape needs nothing changed here.

const VEIL := preload("res://ui/route_map/route_gate_veil.gdshader")
const FIGURE := preload("res://ui/route_map/route_gate_figure.gdshader")
const STONE := preload("res://ui/route_map/route_gate_stone.gdshader")
const BARS := preload("res://ui/route_map/route_gate_bars.gdshader")
const STONES := "res://art/ui/route/gate_%s.png"
const LIGHTS := "res://art/ui/route/gate_%s_light.png"
const GRILLE := "res://art/ui/route/gate_bars.png"
# The gate a chapter without its own is given.
const FALLBACK := &"ash_corridor"
# How tall the stone stands on the page when it is not turned to, how much
# it grows turned to, and how far down its gable the keystone's middle lies
# (as a share of the way from its top to the opening's tip).
const HEIGHT := 372.0
const GROWTH := 0.13
const SHRINK := 0.03
const KEYSTONE := 0.55
# The room what stands in it may take, as shares of the opening: wider than
# the opening itself, as it stands behind the stone and a broad one's sides
# are hidden by the jambs.
const FIGURE_ROOM := Vector2(1.14, 0.78)
# The veil's strength when the gate smoulders, and when all but out.
const SMOULDER := 0.4
const EMBER := 0.07

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
# How far the grille has come down (0 to 1), and the light flooding as she
# walks in (0 to 1).
var drop := 0.0
var flood := 0.0
# What stands in it is seen once turned to (a foe not met stays a shape).
var known := true
# The foe's own tint (a kin sharing another's picture).
var tone := Color.WHITE

var halo: Sprite2D
var veil: Sprite2D
var figure: Sprite2D
var motes: CPUParticles2D
var bars: Sprite2D
var stone: Sprite2D
var burst: CPUParticles2D
var dust: CPUParticles2D
# The stone's size in its picture, and its opening there (px).
var _size := Vector2(745.0, 1000.0)
var _opening := Rect2(117.0, 224.0, 511.0, 776.0)
var _shape := Color(0.03, 0.028, 0.03)
var _boss := false
static var _measured: Dictionary = {}
static var _spark: Texture2D


# Builds the gate for a chapter, with what stands in it (null: nothing).
func setup(chapter: StringName, portrait: Texture2D, boss: bool, shape: Color) -> void:
	_shape = shape
	_boss = boss
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var stone_art := _art(STONES, chapter)
	var light_art := _art(LIGHTS, chapter)
	var grille: Texture2D = load(GRILLE)
	_size = stone_art.get_size()
	_opening = opening_in(light_art)
	var opening_uv := Rect2(_opening.position / _size, _opening.size / _size)
	halo = Sprite2D.new()
	halo.texture = spark()
	halo.material = _adding()
	add_child(halo)
	veil = _layer(light_art, VEIL)
	_give(veil, &"opening", Vector4(opening_uv.position.x, opening_uv.position.y, opening_uv.size.x, opening_uv.size.y))
	_give(veil, &"dark", shape)
	figure = Sprite2D.new()
	figure.centered = false
	figure.texture = portrait
	var seen := ShaderMaterial.new()
	seen.shader = FIGURE
	seen.set_shader_parameter(&"shape", shape)
	figure.material = seen
	figure.visible = portrait != null
	add_child(figure)
	motes = _motes(boss)
	add_child(motes)
	bars = _layer(light_art, BARS)
	_give(bars, &"bars", grille)
	_give(bars, &"opening", Vector4(opening_uv.position.x, opening_uv.position.y, opening_uv.size.x, opening_uv.size.y))
	_give(bars, &"opening_tall", _opening.size.y / _opening.size.x)
	_give(bars, &"bars_tall", float(grille.get_height()) / grille.get_width())
	stone = _layer(stone_art, STONE)
	_give(stone, &"light_map", light_art)
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


func _tint() -> void:
	if veil == null:
		return
	for layer: Sprite2D in [veil, stone, bars]:
		_give(layer, &"colour", colour)
	_give(figure, &"rim", colour)
	motes.color = colour.lerp(Color.WHITE, 0.35)
	burst.color = colour.lerp(Color.WHITE, 0.5)


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


# The keystone's middle, from the foot.
func keystone() -> Vector2:
	return Vector2(0.0, -(_size.y - _opening.position.y * KEYSTONE) * _unit())


# How strongly its light stands now: the veil's, and so the floor's.
func power() -> float:
	if dark:
		return EMBER
	var steady := (SMOULDER + (1.0 - SMOULDER) * lit) * (EMBER * 2.0 + (1.0 - EMBER * 2.0) * open_share)
	return (steady + flare) * rise


# --- Its moments ---

# Sparks from the threshold: the gate is turned to.
func kindle() -> void:
	burst.restart()
	burst.emitting = true


# The grille has landed.
func land() -> void:
	dust.restart()
	dust.emitting = true


# Lays every layer for the state it is in; `clock` moves its light.
func apply(clock: float) -> void:
	if veil == null:
		return
	var unit := _unit()
	var corner := box().position
	var strength := power()
	var open_size := opening()
	for layer: Sprite2D in [veil, bars, stone]:
		layer.position = corner
		layer.scale = Vector2.ONE * unit
		layer.self_modulate.a = rise
	_give(veil, &"power", strength)
	_give(veil, &"clock", clock)
	_give(veil, &"flood", flood)
	_give(stone, &"power", strength)
	_give(stone, &"ambient", lerpf(0.34, 0.6, lit) * lerpf(0.55, 1.0, open_share))
	_give(bars, &"drop", drop)
	_give(bars, &"power", strength)
	bars.visible = drop > 0.0
	# The halo behind it, breathing with the boss's.
	var beat := 0.8 + 0.2 * sin(clock * TAU / 1.8) if _boss else 1.0
	halo.position = Vector2(0.0, -open_size.y * 0.5)
	halo.scale = Vector2(open_size.x * 3.2, open_size.y * 2.0) / 128.0
	halo.modulate = Color(colour, clampf(strength * 0.34 * beat, 0.0, 0.8))
	# What stands in it: as large as its room, on the threshold.
	if figure.texture != null:
		var room := open_size * FIGURE_ROOM
		var full := figure.texture.get_size()
		var kept := minf(room.x / full.x, room.y / full.y)
		figure.scale = Vector2.ONE * kept
		figure.position = Vector2(-full.x * kept * 0.5, -full.y * kept - 2.0)
		figure.self_modulate.a = rise * (0.25 + 0.75 * open_share)
		_give(figure, &"seen", lit * open_share if known and not dark else 0.0)
		_give(figure, &"tint", tone)
		_give(figure, &"rim_power", clampf(strength * 1.2, 0.0, 1.4))
		_give(figure, &"edge_reach", 3.2 / maxf(kept, 0.05))
	motes.position = Vector2(0.0, -open_size.y * 0.42)
	motes.emission_rect_extents = Vector2(open_size.x * 0.42, open_size.y * 0.4)
	motes.modulate.a = clampf(strength, 0.0, 1.0) * (1.0 if not dark else 0.0)
	burst.position = Vector2(0.0, -6.0)
	burst.emission_rect_extents = Vector2(open_size.x * 0.4, 2.0)
	dust.position = Vector2(0.0, -4.0)
	dust.emission_rect_extents = Vector2(open_size.x * 0.46, 2.0)
