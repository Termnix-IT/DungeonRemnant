class_name HubAmbience
extends Control

# Living background for the hub: warm flicker over the painted light sources
# and slow drifting dust. It sits between the background and the panels,
# never takes input and stops while the hub is hidden.

# Light sources in the background texture, as texture UV, radius in texture
# pixels and base strength. They follow the covered background on resize.
const TEXTURE_SIZE := Vector2(1536, 1024)
const LIGHTS := [
	[Vector2(0.168, 0.146), 70.0, 0.20],  # hanging lantern by the banner
	[Vector2(0.291, 0.229), 55.0, 0.18],  # lantern over the weapon rack
	[Vector2(0.352, 0.440), 38.0, 0.16],  # altar candle left
	[Vector2(0.449, 0.430), 38.0, 0.16],  # altar candle right
	[Vector2(0.671, 0.127), 70.0, 0.18],  # hanging lantern by the gate
	[Vector2(0.710, 0.234), 50.0, 0.16],  # wall lantern
	[Vector2(0.771, 0.381), 60.0, 0.20],  # counter lantern
	[Vector2(0.869, 0.254), 55.0, 0.18],  # stall lantern
	[Vector2(0.954, 0.264), 55.0, 0.18],  # far right lantern
]
# The hall object each lobby entry belongs to: texture UV, radius in texture
# pixels and the light's colour. The chosen entry's object glows softly.
const FOCUS := {
	&"departure": [Vector2(0.550, 0.300), 210.0, Color(0.45, 0.62, 1.0)],  # gate to the depths
	&"prepare": [Vector2(0.250, 0.450), 150.0, Color(1.0, 0.70, 0.38)],  # weapon rack
	&"shop": [Vector2(0.690, 0.420), 150.0, Color(1.0, 0.72, 0.40)],  # merchant counter
	&"upgrade": [Vector2(0.398, 0.330), 140.0, Color(0.55, 0.62, 1.0)],  # rune crystal on the altar
	&"settings": [Vector2(0.291, 0.229), 110.0, Color(1.0, 0.70, 0.38)],  # lantern
}
const FOCUS_STRENGTH := 0.5
const FOCUS_TIME := 0.35
const LIGHT_COLOR := Color(1.0, 0.68, 0.34)
# Flicker stays within this share of each light's strength.
const FLICKER := 0.3

var glow: GradientTexture2D
# White, so each focus colour shows true.
var focus_glow: GradientTexture2D
var noise := FastNoiseLite.new()
var dust: CPUParticles2D
var time := 0.0
var focus_id := &""
var focus_strength := 0.0
# 1 over the lobby painting, whose lamps LIGHTS marks; 0 over a page's own
# painting, where those positions mean nothing. The dust drifts either way.
var lights_mix := 1.0:
	set(value):
		lights_mix = value
		queue_redraw()
var _focus_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	var gradient := Gradient.new()
	gradient.set_color(0, LIGHT_COLOR)
	gradient.set_color(1, Color(LIGHT_COLOR, 0.0))
	glow = GradientTexture2D.new()
	glow.gradient = gradient
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	glow.width = 128
	glow.height = 128
	focus_glow = glow.duplicate() as GradientTexture2D
	var white := Gradient.new()
	white.set_color(0, Color.WHITE)
	white.set_color(1, Color(1, 1, 1, 0))
	focus_glow.gradient = white
	noise.frequency = 1.6
	_build_dust()
	resized.connect(_place_dust)
	visibility_changed.connect(func(): dust.emitting = is_visible_in_tree())
	_place_dust()


func _build_dust() -> void:
	dust = CPUParticles2D.new()
	dust.amount = 36
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.direction = Vector2(0.3, -1)
	dust.spread = 40.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 3.0
	dust.initial_velocity_max = 9.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.82, 0.55, 0.0))
	fade.set_color(1, Color(1.0, 0.82, 0.55, 0.0))
	fade.add_point(0.25, Color(1.0, 0.82, 0.55, 0.35))
	fade.add_point(0.75, Color(1.0, 0.82, 0.55, 0.35))
	dust.color_ramp = fade
	add_child(dust)


func _place_dust() -> void:
	if dust == null:
		return
	dust.position = size * 0.5
	dust.emission_rect_extents = size * 0.5


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	time += delta
	queue_redraw()


# The background is drawn KEEP_ASPECT_COVERED; map texture UV the same way.
func light_rect(uv: Vector2, radius: float) -> Rect2:
	var factor := maxf(size.x / TEXTURE_SIZE.x, size.y / TEXTURE_SIZE.y)
	var covered := TEXTURE_SIZE * factor
	var center := (size - covered) * 0.5 + uv * covered
	var extent := Vector2.ONE * radius * factor * 2.0
	return Rect2(center - extent * 0.5, extent)


# Fades the old object's light out and the new one in. An unknown or empty
# id clears it, as away from the lobby.
func focus(id: StringName) -> void:
	if id == focus_id and _focus_tween != null and _focus_tween.is_running():
		return
	if _focus_tween != null:
		_focus_tween.kill()
	_focus_tween = create_tween().set_trans(Tween.TRANS_SINE)
	if focus_id != &"" and focus_strength > 0.0:
		_focus_tween.tween_property(self, "focus_strength", 0.0, FOCUS_TIME * 0.5)
	_focus_tween.tween_callback(func(): focus_id = id if FOCUS.has(id) else &"")
	if FOCUS.has(id):
		_focus_tween.tween_property(self, "focus_strength", 1.0, FOCUS_TIME)


func _draw() -> void:
	if focus_id != &"" and focus_strength > 0.0:
		var target: Array = FOCUS[focus_id]
		# Slow breathing, so the object reads as lit rather than flashing.
		var breath := 0.85 + 0.15 * sin(time * 2.2)
		var tint: Color = target[2]
		draw_texture_rect(focus_glow, light_rect(target[0], target[1]), false, Color(tint, FOCUS_STRENGTH * focus_strength * breath))
		draw_texture_rect(focus_glow, light_rect(target[0], target[1] * 0.45), false, Color(tint, FOCUS_STRENGTH * 0.6 * focus_strength * breath))
	if lights_mix <= 0.0:
		return
	for index in LIGHTS.size():
		var light: Array = LIGHTS[index]
		var wave := noise.get_noise_2d(time, index * 37.0)
		var strength: float = light[2] * (1.0 + FLICKER * wave) * lights_mix
		draw_texture_rect(glow, light_rect(light[0], light[1]), false, Color(1, 1, 1, strength))
