class_name HubAmbience
extends Control

# Living background for the hub: warm flicker over the painted light sources
# and slow drifting dust. It sits between the background and the panels,
# never takes input and stops while the hub is hidden.

# Light sources in the background texture, as texture UV, radius in texture
# pixels and base strength. They follow the covered background on resize.
const TEXTURE_SIZE := Vector2(1586, 992)
const LIGHTS := [
	[Vector2(0.500, 0.050), 150.0, 0.20],  # chandelier
	[Vector2(0.260, 0.020), 70.0, 0.16],  # upper-left sconce
	[Vector2(0.738, 0.020), 70.0, 0.16],  # upper-right sconce
	[Vector2(0.424, 0.257), 55.0, 0.18],  # stair candle left
	[Vector2(0.576, 0.257), 55.0, 0.18],  # stair candle right
	[Vector2(0.315, 0.383), 80.0, 0.20],  # wall torch left
	[Vector2(0.683, 0.383), 80.0, 0.20],  # wall torch right
	[Vector2(0.381, 0.403), 95.0, 0.22],  # brazier left
	[Vector2(0.618, 0.403), 95.0, 0.22],  # brazier right
	[Vector2(0.110, 0.560), 90.0, 0.20],  # desk lantern
	[Vector2(0.962, 0.655), 90.0, 0.20],  # right lantern
]
const LIGHT_COLOR := Color(1.0, 0.68, 0.34)
# Flicker stays within this share of each light's strength.
const FLICKER := 0.3

var glow: GradientTexture2D
var noise := FastNoiseLite.new()
var dust: CPUParticles2D
var time := 0.0


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


func _draw() -> void:
	for index in LIGHTS.size():
		var light: Array = LIGHTS[index]
		var wave := noise.get_noise_2d(time, index * 37.0)
		var strength: float = light[2] * (1.0 + FLICKER * wave)
		draw_texture_rect(glow, light_rect(light[0], light[1]), false, Color(1, 1, 1, strength))
