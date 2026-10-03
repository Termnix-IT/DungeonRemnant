class_name LobbyHero
extends TextureRect

# The lobby heroine's idle on one flat illustration. The shader moves where
# each pixel is read from, so the picture never tears: a slow lean pivoting at
# her feet, breathing in the chest, a small head tilt about the neck, and the
# hair and coat hem following the body a moment late (mio_lobby_motion.png
# says how far each pixel may sway). Closed eyes come from a second texture
# that differs only around the eyes. Timing uses its own random numbers, never
# the game's.

const SHADER := """
shader_type canvas_item;

uniform sampler2D blink_texture : filter_linear_mipmap;
uniform sampler2D motion_mask : filter_linear_mipmap;
uniform float blink : hint_range(0.0, 1.0) = 0.0;
// Pixels of the texture.
uniform float lean = 0.0;
uniform float breath = 0.0;
uniform vec2 neck = vec2(440.0, 340.0);
uniform float chest_top = 340.0;
uniform float waist = 500.0;
uniform float head_angle = 0.0;
uniform vec2 hair_shift = vec2(0.0);
uniform vec2 hem_shift = vec2(0.0);

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 extent = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 p = UV * extent;
	// Lean about the feet: nothing at the soles, most at the top of the head.
	p.x -= lean * (1.0 - p.y / extent.y);
	// The shoulders and head rise; the waist and below stay put.
	p.y += breath * (1.0 - smoothstep(chest_top, waist, p.y));
	// Turn what lies above the neck about it.
	float angle = head_angle * (1.0 - smoothstep(neck.y - 40.0, neck.y + 20.0, p.y));
	p = neck + mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * (p - neck);
	vec4 sway = texture(motion_mask, p / extent);
	p -= hair_shift * sway.r + hem_shift * sway.g;
	vec2 uv = p / extent;
	vec4 color = mix(texture(TEXTURE, uv), texture(blink_texture, uv), blink);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		color = vec4(0.0);
	}
	COLOR = color * tint;
}
"""

# Idle Base: one slow breath-and-lean loop.
const BREATH_PERIOD := 5.0
const BREATH_RISE := 3.5
const LEAN_PERIOD := 5.0 * 2.0
const LEAN_REACH := 5.0
# Blink every 3-7 s, eyes shut for a moment.
const BLINK_GAP := Vector2(3.0, 7.0)
const BLINK_TIME := 0.13
# Every 6-12 s the head tilts 1-2° and holds a little before settling back.
const GLANCE_GAP := Vector2(6.0, 12.0)
const GLANCE_ANGLE := Vector2(1.0, 2.0)
const GLANCE_HOLD := Vector2(1.2, 2.4)
# Hair and hem trail the body by about 0.2 s and 0.25 s.
const HAIR_LAG := 0.2
const HEM_LAG := 0.25
const HAIR_REACH := 9.0
const HEM_REACH := 5.0
# A click makes her hop slightly and turn her head.
const REACT_TIME := 0.5
const REACT_LIFT := 0.022
const REACT_ANGLE := 2.5

var time := 0.0
var blink_amount := 0.0
var head_angle := 0.0
var hair_shift := Vector2.ZERO
var hem_shift := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var _next_blink := 0.0
var _blink_left := 0.0
var _next_glance := 0.0
var _glance_left := 0.0
var _glance_target := 0.0
var _react_left := 0.0
var _rest_scale := Vector2.ONE


func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng.randomize()


func _ready() -> void:
	var shader_material := ShaderMaterial.new()
	shader_material.shader = Shader.new()
	shader_material.shader.code = SHADER
	shader_material.set_shader_parameter(&"blink_texture", preload("res://art/characters/mio_lobby_blink.png"))
	shader_material.set_shader_parameter(&"motion_mask", preload("res://art/characters/mio_lobby_motion.png"))
	material = shader_material
	_next_blink = rng.randf_range(BLINK_GAP.x, BLINK_GAP.y)
	_next_glance = rng.randf_range(GLANCE_GAP.x, GLANCE_GAP.y)
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))


# The click reaction: a small hop from the feet, a turn of the head, a blink.
func react() -> void:
	_react_left = REACT_TIME
	_glance_target = deg_to_rad(REACT_ANGLE) * (1.0 if rng.randf() < 0.5 else -1.0)
	_glance_left = REACT_TIME + 0.6
	_blink_left = BLINK_TIME


func _process(delta: float) -> void:
	advance(delta)


# Steps the idle by delta seconds; tests call it to run time forward.
func advance(delta: float) -> void:
	time += delta
	var breath := (1.0 - cos(time * TAU / BREATH_PERIOD)) * 0.5 * BREATH_RISE
	var lean := sin(time * TAU / LEAN_PERIOD) * LEAN_REACH
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink_left = BLINK_TIME
		_next_blink = rng.randf_range(BLINK_GAP.x, BLINK_GAP.y)
	_blink_left = maxf(0.0, _blink_left - delta)
	blink_amount = 1.0 if _blink_left > 0.0 else 0.0
	_next_glance -= delta
	if _next_glance <= 0.0:
		_glance_target = deg_to_rad(rng.randf_range(GLANCE_ANGLE.x, GLANCE_ANGLE.y)) * (1.0 if rng.randf() < 0.5 else -1.0)
		_glance_left = rng.randf_range(GLANCE_HOLD.x, GLANCE_HOLD.y)
		_next_glance = rng.randf_range(GLANCE_GAP.x, GLANCE_GAP.y)
	_glance_left = maxf(0.0, _glance_left - delta)
	var head_target := _glance_target if _glance_left > 0.0 else 0.0
	head_angle = lerpf(head_angle, head_target, 1.0 - exp(-delta / 0.35))
	var lift := 0.0
	if _react_left > 0.0:
		_react_left = maxf(0.0, _react_left - delta)
		var progress := 1.0 - _react_left / REACT_TIME
		lift = sin(progress * PI) * (1.0 - progress * 0.5)
	scale = _rest_scale * Vector2(1.0 - lift * REACT_LIFT * 0.4, 1.0 + lift * REACT_LIFT)
	# Hair and hem chase where the body leans, the head turns and the hop
	# lifts them, each a little late, plus a slow drift of their own.
	var drive := Vector2(lean * 0.9 + rad_to_deg(head_angle) * 2.0, -lift * 14.0 + breath * 0.4)
	var drift := Vector2(sin(time * TAU / 3.7) * 1.5, 0.0)
	hair_shift = hair_shift.lerp((drive + drift).limit_length(HAIR_REACH), 1.0 - exp(-delta / HAIR_LAG))
	hem_shift = hem_shift.lerp((drive * 0.5 + drift * 0.6).limit_length(HEM_REACH), 1.0 - exp(-delta / HEM_LAG))
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter(&"breath", breath)
	shader_material.set_shader_parameter(&"lean", lean)
	shader_material.set_shader_parameter(&"blink", blink_amount)
	shader_material.set_shader_parameter(&"head_angle", head_angle)
	shader_material.set_shader_parameter(&"hair_shift", hair_shift)
	shader_material.set_shader_parameter(&"hem_shift", hem_shift)
