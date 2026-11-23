class_name Vfx
extends Sprite2D

# One effect of the fight. It is not a finished picture shown and faded: it
# is a painted picture (art/effects/vfx, white on black: how bright is how
# strong the light) moved by a shader for the length of its life: a blade's
# trail swept round its arc and burnt away from its tail, a thrust's streak
# run to its tip, a blow's burst snapping open with its rays, lightning
# striking three times along three different lines, fire rolling out as a
# ring of tongues, a shock carried over the floor to the blow's reach.
#
# The makers below add one to a parent (the area's effects, drawn over the
# fighters; a GroundRing among the floor's marks) and it frees itself. Its
# life runs on the world's clock, so a hit's stop holds the effect as it
# holds the blow. An effect is only seen: nothing in the fight reads one.

const SLASH: Shader = preload("res://combat/vfx/vfx_slash.gdshader")
const LANCE: Shader = preload("res://combat/vfx/vfx_lance.gdshader")
const BURST: Shader = preload("res://combat/vfx/vfx_burst.gdshader")
const RING: Shader = preload("res://combat/vfx/vfx_ring.gdshader")
const BOLT: Shader = preload("res://combat/vfx/vfx_bolt.gdshader")
const FLAME: Shader = preload("res://combat/vfx/vfx_flame.gdshader")
const TRAIL: Texture2D = preload("res://art/effects/vfx/slash_trail.png")
const BOLTS: Texture2D = preload("res://art/effects/vfx/bolt_strip.png")
const FLAMES: Texture2D = preload("res://art/effects/vfx/flame_strip.png")
const SHOCK: Texture2D = preload("res://art/effects/vfx/shock_ring.png")
const NOISE: Texture2D = preload("res://art/effects/vfx/noise.png")
# The painted burst at the heart of each kind of blow landing.
const BURSTS := {
	&"hit": preload("res://art/effects/painted/hit.png"),
	&"heavy": preload("res://art/effects/painted/heavy.png"),
	&"magic": preload("res://art/effects/painted/magic.png"),
}
# Where the blow's reach lies in each shader's quad (a share of its half
# width; the rest is room for the glow).
const SLASH_REACH := 0.87
const SLASH_CARRY := 1.12
const RING_REACH := 0.88
const FLAME_REACH := 0.9
# A bolt is drawn this high (world px), and one this long takes the whole
# of its painted strip.
const BOLT_HEIGHT := 96.0
const BOLT_LENGTH := 420.0

static var _shade: GradientTexture2D


# The soft dark that lies under a fighter's feet: darkest in the middle,
# gone at its rim. One picture for all of them.
static func shade() -> GradientTexture2D:
	if _shade == null:
		var fall := Gradient.new()
		fall.set_color(0, Color(0.0, 0.0, 0.0, 1.0))
		fall.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
		fall.add_point(0.55, Color(0.0, 0.0, 0.0, 0.55))
		_shade = GradientTexture2D.new()
		_shade.gradient = fall
		_shade.fill = GradientTexture2D.FILL_RADIAL
		_shade.fill_from = Vector2(0.5, 0.5)
		_shade.fill_to = Vector2(1.0, 0.5)
		_shade.width = 64
		_shade.height = 64
	return _shade


# How long it lasts (seconds) and how far through it is.
var life := 0.3
var age := 0.0
var look: ShaderMaterial


static func _make(into: Node, shader: Shader, picture: Texture2D, at: Vector2, across: Vector2, seconds: float, tint: Color) -> Vfx:
	var effect := Vfx.new()
	effect.texture = picture
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	effect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	effect.scale = across / picture.get_size()
	effect.position = at
	effect.z_index = 12
	effect.life = seconds
	effect.look = ShaderMaterial.new()
	effect.look.shader = shader
	effect.look.set_shader_parameter(&"tint", tint)
	effect.look.set_shader_parameter(&"seed", randf())
	effect.look.set_shader_parameter(&"noise", NOISE)
	effect.look.set_shader_parameter(&"age", 0.0)
	effect.material = effect.look
	into.add_child(effect)
	return effect


# A blade's cut round `at`: facing `facing`, out to `reach`, `arc` degrees
# wide (360: a whole turn), swept one way or the other (`turn`: 1 or -1);
# `weight` 0 for a light cut to 1 for a heavy one.
static func slash(into: Node, at: Vector2, facing: Vector2, reach: float, arc: float, tint: Color, turn: float = 1.0, weight: float = 0.0) -> Vfx:
	# Drawn a little past the blow's reach: a blade's light carries beyond its edge.
	var effect := _make(into, SLASH, TRAIL, at, Vector2.ONE * reach * SLASH_CARRY * 2.0 / SLASH_REACH, lerpf(0.26, 0.36, weight), tint)
	effect.rotation = facing.angle()
	effect.look.set_shader_parameter(&"half_arc", deg_to_rad(minf(arc, 360.0)) * 0.5)
	effect.look.set_shader_parameter(&"turn", turn)
	effect.look.set_shader_parameter(&"weight", weight)
	return effect


# A thrust from `from` along `facing` to `reach`, `wide` across (world px).
static func lance(into: Node, from: Vector2, facing: Vector2, reach: float, wide: float, tint: Color) -> Vfx:
	var effect := _make(into, LANCE, TRAIL, from + facing * reach * 0.55, Vector2(reach * 1.2, wide), 0.22, tint)
	effect.rotation = facing.angle()
	return effect


# A blow landing at `at`, `across` world px wide: `kind` picks its painted
# heart, `toward` the way the blow went (its rays lean that way), `weight`
# 0 to 1 how heavy it was.
static func burst(into: Node, at: Vector2, across: float, tint: Color, kind: StringName = &"hit", toward: Vector2 = Vector2.ZERO, weight: float = 0.0) -> Vfx:
	var effect := _make(into, BURST, BURSTS.get(kind, BURSTS[&"hit"]), at, Vector2.ONE * across, lerpf(0.22, 0.36, weight), tint)
	effect.look.set_shader_parameter(&"toward", toward.normalized() if toward.length() > 0.01 else Vector2.ZERO)
	effect.look.set_shader_parameter(&"weight", weight)
	return effect


# A shock over the floor from `at` out to `reach`, where it stops.
static func ring(into: Node, at: Vector2, reach: float, tint: Color, seconds: float = 0.36) -> Vfx:
	var effect := _make(into, RING, SHOCK, at, Vector2.ONE * reach * 2.0 / RING_REACH, seconds, tint)
	effect.z_index = 0
	return effect


# Lightning between two points.
static func bolt(into: Node, from: Vector2, to: Vector2, tint: Color) -> Vfx:
	var between := to - from
	var effect := _make(into, BOLT, BOLTS, (from + to) * 0.5, Vector2(maxf(between.length(), 8.0), BOLT_HEIGHT), 0.27, tint)
	effect.rotation = between.angle()
	effect.z_index = 13
	effect.look.set_shader_parameter(&"span", clampf(between.length() / BOLT_LENGTH, 0.2, 1.6))
	return effect


# Fire bursting from `at` out to `radius`.
static func flame(into: Node, at: Vector2, radius: float, tint: Color = Color.WHITE) -> Vfx:
	var effect := _make(into, FLAME, FLAMES, at, Vector2.ONE * radius * 2.0 / FLAME_REACH, 0.5, tint)
	effect.look.set_shader_parameter(&"turns", clampf(roundf(radius / 45.0), 2.0, 5.0))
	return effect


func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	look.set_shader_parameter(&"age", age / life)
