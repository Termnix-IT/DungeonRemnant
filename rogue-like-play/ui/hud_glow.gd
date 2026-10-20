class_name HudGlow
extends Control

# A burst of warm light over the part of the HUD a level-up choice has just
# raised (the HP for more max HP, the map for a wider sight, the hero's face
# for her strength): a soft glow added round the part swells in and fades,
# while a bright spark runs once round its edge. It covers the HUD and takes
# no input; HUD.highlight_ability() aims it.
const COLOR := Color(1.0, 0.8, 0.42)
# How far the glow reaches past the part, in px.
const REACH := 22.0
const RISE_TIME := 0.16
const HOLD_TIME := 0.25
const FADE_TIME := 0.9
const SPARK_RADIUS := 12.0

static var _texture: GradientTexture2D

var area := Rect2()
var strength := 0.0:
	set(value):
		strength = value
		queue_redraw()
# The spark's way round the edge, 0 to 1.
var lap := 0.0:
	set(value):
		lap = value
		queue_redraw()
var _tween: Tween
var _lap_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var light := CanvasItemMaterial.new()
	light.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = light


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# Lights rect (in the HUD's coordinates) after delay seconds.
func shine(rect: Rect2, delay: float = 0.0) -> void:
	area = rect
	for old: Tween in [_tween, _lap_tween]:
		if old != null and old.is_valid():
			old.kill()
	strength = 0.0
	lap = 0.0
	# The spark runs round while the light rises, holds and half fades.
	_lap_tween = create_tween()
	_lap_tween.tween_interval(delay)
	_lap_tween.tween_property(self, "lap", 1.0, RISE_TIME + HOLD_TIME + FADE_TIME * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween = create_tween()
	_tween.tween_interval(delay)
	_tween.tween_property(self, "strength", 1.0, RISE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(self, "strength", 0.0, FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func shining() -> bool:
	return strength > 0.0


func _draw() -> void:
	if strength <= 0.0:
		return
	draw_texture_rect(_glow(), area.grow(REACH), false, Color(COLOR, strength * 0.7))
	draw_rect(area.grow(3.0), Color(COLOR, strength * 0.55), false, 2.0)
	draw_texture_rect(_glow(), Rect2(_edge_point(lap) - Vector2.ONE * SPARK_RADIUS, Vector2.ONE * SPARK_RADIUS * 2.0), false, Color(Color.WHITE, strength))


# A point lap of the way round the part's edge, clockwise from its top left.
func _edge_point(share: float) -> Vector2:
	var edge := area.grow(3.0)
	var along := fposmod(share, 1.0) * (edge.size.x + edge.size.y) * 2.0
	if along < edge.size.x:
		return edge.position + Vector2(along, 0)
	along -= edge.size.x
	if along < edge.size.y:
		return Vector2(edge.end.x, edge.position.y + along)
	along -= edge.size.y
	if along < edge.size.x:
		return Vector2(edge.end.x - along, edge.end.y)
	return Vector2(edge.position.x, edge.end.y - (along - edge.size.x))


# A soft round light, white in the middle and gone at the edge.
static func _glow() -> GradientTexture2D:
	if _texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
		_texture = GradientTexture2D.new()
		_texture.gradient = gradient
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
		_texture.width = 128
		_texture.height = 128
	return _texture
