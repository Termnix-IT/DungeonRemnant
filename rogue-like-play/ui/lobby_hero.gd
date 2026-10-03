class_name LobbyHero
extends TextureRect

# The lobby heroine's idle. She is two layers of one illustration: her body
# (this texture) and her long back hair (mio_lobby_hair.png) drawn behind
# it, so the hair can swing freely without painting anything in. The shader
# moves where each pixel is read from, so nothing tears: a slow lean pivoting
# at her feet, breathing in the chest, a small head tilt about the neck, the
# back hair bending from its root on a spring, and the strands in front of
# her shoulder and the coat hem following by mio_lobby_motion.png. Her eyes
# swap to cells of mio_lobby_eyes.png for a three-step blink and glances to
# either side. Timing uses its own random numbers, never the game's.

const SHADER := """
shader_type canvas_item;

uniform sampler2D hair_texture : filter_linear_mipmap;
uniform sampler2D eye_atlas : filter_linear_mipmap;
uniform sampler2D motion_mask : filter_linear_mipmap;
// Pixels of the texture.
uniform float lean = 0.0;
uniform float breath = 0.0;
uniform vec2 neck = vec2(440.0, 340.0);
uniform float chest_top = 340.0;
uniform float waist = 500.0;
uniform float head_angle = 0.0;
uniform vec2 hair_pivot = vec2(510.0, 280.0);
uniform float hair_root = 330.0;
uniform float hair_tip = 940.0;
uniform float hair_angle = 0.0;
uniform vec2 hair_offset = vec2(0.0);
uniform vec2 strand_shift = vec2(0.0);
uniform vec2 hem_shift = vec2(0.0);
uniform vec4 eye_rect = vec4(338.0, 182.0, 129.0, 88.0);
uniform float eye_cells = 4.0;
// 0 shows the painted eyes; 1 and up pick a cell of the eye atlas.
uniform float eye_frame = 0.0;
// Patches painted over the body for an expression and a passing pose: the
// changed area of an edit, cross-faded in by its mix and feathered at the
// edges of its rectangle (pixels of the texture).
uniform sampler2D face_texture : filter_linear_mipmap;
uniform vec4 face_rect = vec4(0.0);
uniform float face_mix = 0.0;
// A gesture steps through its frames: the frame it leaves stays fully on
// while the next one cross-fades in over it.
uniform sampler2D pose_from : filter_linear_mipmap;
uniform sampler2D pose_to : filter_linear_mipmap;
uniform vec4 pose_rect = vec4(0.0);
uniform float pose_from_mix = 0.0;
uniform float pose_to_mix = 0.0;
const float FEATHER = 18.0;

varying vec4 tint;

vec2 turn(vec2 p, vec2 pivot, float angle) {
	return pivot + mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * (p - pivot);
}

// The body's own motion: lean about the feet, breathing, the head about the neck.
vec2 posed(vec2 p, vec2 extent) {
	p.x -= lean * (1.0 - p.y / extent.y);
	p.y += breath * (1.0 - smoothstep(chest_top, waist, p.y));
	return turn(p, neck, head_angle * (1.0 - smoothstep(neck.y - 40.0, neck.y + 20.0, p.y)));
}

// 1 inside the texture, 0 in the empty space a swing pulls in from outside.
float within(vec2 uv) {
	return step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
}

vec4 patched(vec4 base, sampler2D patch, vec4 rect, float amount, vec2 p) {
	vec2 local = p - rect.xy;
	if (amount <= 0.0 || local.x < 0.0 || local.y < 0.0 || local.x > rect.z || local.y > rect.w) {
		return base;
	}
	float edge = min(min(local.x, rect.z - local.x), min(local.y, rect.w - local.y));
	vec4 over = texture(patch, local / rect.zw);
	vec4 mixed = mix(vec4(base.rgb * base.a, base.a), vec4(over.rgb * over.a, over.a), amount * smoothstep(0.0, FEATHER, edge));
	return vec4(mixed.rgb / max(mixed.a, 0.0001), mixed.a);
}

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 extent = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 p = posed(UV * extent, extent);
	vec4 sway = texture(motion_mask, p / extent);
	vec2 b = p - strand_shift * sway.r - hem_shift * sway.g;
	vec4 body = texture(TEXTURE, b / extent) * within(b / extent);
	vec2 local = b - eye_rect.xy;
	if (eye_frame > 0.5 && local.x >= 0.0 && local.y >= 0.0 && local.x < eye_rect.z && local.y < eye_rect.w) {
		vec2 cell = vec2(((eye_frame - 1.0) * eye_rect.z + local.x) / (eye_rect.z * eye_cells), local.y / eye_rect.w);
		vec4 eyes = texture(eye_atlas, cell);
		body.rgb = mix(body.rgb, eyes.rgb, eyes.a);
	}
	body = patched(body, face_texture, face_rect, face_mix, b);
	body = patched(body, pose_from, pose_rect, pose_from_mix, b);
	body = patched(body, pose_to, pose_rect, pose_to_mix, b);
	// The back hair bends more towards its tips and trails the body.
	// The root stays put; the bend and the trailing drop grow towards the tips.
	float bend = smoothstep(hair_root, hair_tip, p.y);
	vec2 h = turn(p - hair_offset * bend, hair_pivot, hair_angle * bend);
	vec4 hair = texture(hair_texture, h / extent) * within(h / extent);
	float alpha = body.a + hair.a * (1.0 - body.a);
	vec3 rgb = (body.rgb * body.a + hair.rgb * hair.a * (1.0 - body.a)) / max(alpha, 0.0001);
	COLOR = vec4(rgb, alpha) * tint;
}
"""

enum Eyes { OPEN, HALF, CLOSED, LEFT, RIGHT }

# Idle Base: one slow breath-and-lean loop.
const BREATH_PERIOD := 5.0
const BREATH_RISE := 3.5
const LEAN_PERIOD := 10.0
const LEAN_REACH := 5.0
# Blink every 3-7 s: half, shut, half.
const BLINK_GAP := Vector2(3.0, 7.0)
const BLINK_STEPS := [[0.04, Eyes.HALF], [0.07, Eyes.CLOSED], [0.05, Eyes.HALF]]
# Every 6-12 s she glances aside: eyes, head (1-2°) or both, held a while.
const GLANCE_GAP := Vector2(6.0, 12.0)
const GLANCE_ANGLE := Vector2(1.0, 2.0)
const GLANCE_HOLD := Vector2(1.2, 2.4)
# The back hair swings on a spring about 1 Hz, damped so it overshoots a
# little and settles; it answers the lean, the head and the hop.
const HAIR_FREQUENCY := 1.1
const HAIR_DAMPING := 0.3
const HAIR_LIMIT := 0.06
const HAIR_LIFT := 12.0
# Front strands and the coat hem take a share of the same motion.
const STRAND_REACH := 300.0
const HEM_REACH := 120.0
# Random Idle: every 12-25 s she makes a brief gesture - a hand on the hilt
# or a touch to her beret. Each gesture is a rectangle of the illustration
# (Rect2 in texture pixels; tools/build_lobby_hero.py cuts the same ones) and
# frames of the arm on its way: three in-betweens and the gesture itself.
# The arm passes through them in POSE_FADE_IN, holds 1-1.8 s, and goes back
# through them in POSE_FADE_OUT.
const POSES := {
	&"hilt": [Rect2(255, 340, 395, 470), [preload("res://art/characters/mio_lobby_pose_hilt_1.png"), preload("res://art/characters/mio_lobby_pose_hilt_2.png"), preload("res://art/characters/mio_lobby_pose_hilt_3.png"), preload("res://art/characters/mio_lobby_pose_hilt.png")]],
	&"beret": [Rect2(455, 125, 275, 460), [preload("res://art/characters/mio_lobby_pose_beret_1.png"), preload("res://art/characters/mio_lobby_pose_beret_2.png"), preload("res://art/characters/mio_lobby_pose_beret_3.png"), preload("res://art/characters/mio_lobby_pose_beret.png")]],
}
const POSE_GAP := Vector2(12.0, 25.0)
const POSE_FADE_IN := 0.44
const POSE_HOLD := Vector2(1.0, 1.8)
const POSE_FADE_OUT := 0.5
# A click brings a smile for a moment.
const SMILE: Texture2D = preload("res://art/characters/mio_lobby_face_smile.png")
const SMILE_RECT := Rect2(335, 175, 160, 165)
const SMILE_IN := 0.12
const SMILE_HOLD := 1.6
const SMILE_OUT := 0.25
# A click makes her hop slightly and turn her head.
const REACT_TIME := 0.5
# After a hop she stays on her feet a moment before the next one.
const REACT_REST := 0.3
const REACT_LIFT := 0.022
const REACT_ANGLE := 2.5

var time := 0.0
var eye_frame: Eyes = Eyes.OPEN
var gaze: Eyes = Eyes.OPEN
var head_angle := 0.0
var hair_angle := 0.0
# The spring's own angle; hair_angle eases it into HAIR_LIMIT instead of
# stopping hard there.
var _hair_swing := 0.0
var hair_offset := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var pose := &""
# How far along its frames the gesture is: 0 the idle, the frame count the
# full gesture.
var pose_progress := 0.0
# How much the gesture covers the idle (0-1); the back hair holds by it.
var pose_mix := 0.0
var face_mix := 0.0
var _next_pose := 0.0
var _pose_time := -1.0
var _pose_hold := 0.0
var _smile_time := -1.0
var _hair_velocity := 0.0
var _lift_follow := 0.0
var _lift_velocity := 0.0
var _next_blink := 0.0
var _blink_time := -1.0
var _next_glance := 0.0
var _glance_left := 0.0
var _glance_target := 0.0
var _react_left := -REACT_REST
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
	shader_material.set_shader_parameter(&"hair_texture", preload("res://art/characters/mio_lobby_hair.png"))
	shader_material.set_shader_parameter(&"eye_atlas", preload("res://art/characters/mio_lobby_eyes.png"))
	shader_material.set_shader_parameter(&"motion_mask", preload("res://art/characters/mio_lobby_motion.png"))
	material = shader_material
	_next_blink = rng.randf_range(BLINK_GAP.x, BLINK_GAP.y)
	_next_glance = rng.randf_range(GLANCE_GAP.x, GLANCE_GAP.y)
	_next_pose = rng.randf_range(POSE_GAP.x, POSE_GAP.y)
	shader_material.set_shader_parameter(&"face_texture", SMILE)
	shader_material.set_shader_parameter(&"face_rect", _rect_vector(SMILE_RECT))
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))


# The click reaction: a small hop from the feet, a turn of the head, a blink.
# Clicks during a hop, or just after it, only hold the head turn, so quick
# taps never restart the hop mid-air, chain hops, or flip her head.
func react() -> void:
	if _react_left > -REACT_REST:
		_glance_left = maxf(_glance_left, REACT_TIME)
		if _smile_time >= 0.0:
			_smile_time = minf(_smile_time, SMILE_IN)
		return
	_react_left = REACT_TIME
	_glance_target = deg_to_rad(REACT_ANGLE) * (1.0 if rng.randf() < 0.5 else -1.0)
	_glance_left = REACT_TIME + 0.6
	gaze = Eyes.OPEN
	blink()
	_smile_time = 0.0


# Starts a Random Idle gesture now; the idle calls it every 12-25 s.
func gesture(name: StringName = &"") -> void:
	if name == &"":
		var names: Array = POSES.keys()
		names.erase(pose)
		name = names[rng.randi_range(0, names.size() - 1)]
	pose = name
	_pose_time = 0.0
	_pose_hold = rng.randf_range(POSE_HOLD.x, POSE_HOLD.y)
	var shader_material := material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter(&"pose_rect", _rect_vector(POSES[name][0]))


func _rect_vector(rect: Rect2) -> Vector4:
	return Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y)


func blink() -> void:
	_blink_time = 0.0


func _process(delta: float) -> void:
	advance(delta)


# Steps the idle by delta seconds; tests call it to run time forward.
func advance(delta: float) -> void:
	time += delta
	var breath := (1.0 - cos(time * TAU / BREATH_PERIOD)) * 0.5 * BREATH_RISE
	var lean := sin(time * TAU / LEAN_PERIOD) * LEAN_REACH
	_step_blink(delta)
	_step_glance(delta)
	_step_pose(delta)
	_step_smile(delta)
	var head_target := _glance_target if _glance_left > 0.0 else 0.0
	head_angle = lerpf(head_angle, head_target, 1.0 - exp(-delta / 0.35))
	var lift := 0.0
	# Counts down through the hop, then on through the rest after it.
	_react_left = maxf(-REACT_REST, _react_left - delta)
	if _react_left > 0.0:
		var progress := 1.0 - _react_left / REACT_TIME
		lift = sin(progress * PI) * (1.0 - progress * 0.5)
	scale = _rest_scale * Vector2(1.0 - lift * REACT_LIFT * 0.4, 1.0 + lift * REACT_LIFT)
	# The hair chases a target made of the lean, the head and a slow drift of
	# its own; a spring gives it the lag, the overshoot and the settling.
	var target := lean * 0.004 + head_angle * 0.8 + sin(time * TAU / 6.3) * 0.008
	var omega := TAU * HAIR_FREQUENCY
	# Small fixed steps keep the spring stable however long the frame was.
	var steps := maxi(1, ceili(delta / 0.01))
	var step := delta / steps
	var lift_pixels := lift * HAIR_LIFT
	for i in steps:
		_hair_velocity += (omega * omega * (target - _hair_swing) - 2.0 * HAIR_DAMPING * omega * _hair_velocity) * step
		_hair_swing += _hair_velocity * step
		_lift_velocity += (omega * omega * (lift_pixels - _lift_follow) - 2.0 * HAIR_DAMPING * omega * _lift_velocity) * step
		_lift_follow += _lift_velocity * step
	hair_angle = HAIR_LIMIT * tanh(_hair_swing / HAIR_LIMIT)
	# While she rises the hair stays a little below, then catches up.
	hair_offset = Vector2(0.0, -(lift_pixels - _lift_follow))
	eye_frame = gaze
	if _blink_time >= 0.0:
		eye_frame = _blink_frame()
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter(&"breath", breath)
	shader_material.set_shader_parameter(&"lean", lean)
	shader_material.set_shader_parameter(&"head_angle", head_angle)
	# A pose patch carries the back hair as painted; hold the swing still under
	# it so the two never part.
	var hair_free := 1.0 - pose_mix
	shader_material.set_shader_parameter(&"hair_angle", hair_angle * hair_free)
	shader_material.set_shader_parameter(&"hair_offset", hair_offset * hair_free)
	shader_material.set_shader_parameter(&"strand_shift", Vector2(-hair_angle * STRAND_REACH, hair_offset.y * 0.5))
	shader_material.set_shader_parameter(&"hem_shift", Vector2(-hair_angle * HEM_REACH, hair_offset.y * 0.25))
	shader_material.set_shader_parameter(&"eye_frame", float(eye_frame))
	_show_pose(shader_material)
	shader_material.set_shader_parameter(&"face_mix", face_mix)


func _step_blink(delta: float) -> void:
	_next_blink -= delta
	if _next_blink <= 0.0:
		blink()
		_next_blink = rng.randf_range(BLINK_GAP.x, BLINK_GAP.y)
	if _blink_time >= 0.0:
		_blink_time += delta
		var total := 0.0
		for blink_step: Array in BLINK_STEPS:
			total += blink_step[0]
		if _blink_time >= total:
			_blink_time = -1.0


func _blink_frame() -> Eyes:
	var elapsed := 0.0
	for blink_step: Array in BLINK_STEPS:
		elapsed += blink_step[0]
		if _blink_time < elapsed:
			return blink_step[1]
	return gaze


func _step_glance(delta: float) -> void:
	_next_glance -= delta
	if _next_glance <= 0.0:
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		# Positive turns her head towards the right of the screen.
		var kind := rng.randi_range(0, 2)
		_glance_target = 0.0 if kind == 0 else deg_to_rad(rng.randf_range(GLANCE_ANGLE.x, GLANCE_ANGLE.y)) * side
		gaze = Eyes.OPEN if kind == 1 else (Eyes.RIGHT if side > 0.0 else Eyes.LEFT)
		_glance_left = rng.randf_range(GLANCE_HOLD.x, GLANCE_HOLD.y)
		_next_glance = rng.randf_range(GLANCE_GAP.x, GLANCE_GAP.y)
	if _glance_left > 0.0:
		_glance_left = maxf(0.0, _glance_left - delta)
		if _glance_left == 0.0:
			# The eyes come back at once; the head eases back after them.
			gaze = Eyes.OPEN


func _step_pose(delta: float) -> void:
	if _pose_time < 0.0:
		_next_pose -= delta
		# Not in the middle of a click reaction.
		if _next_pose <= 0.0 and _react_left <= -REACT_REST:
			gesture()
			_next_pose = rng.randf_range(POSE_GAP.x, POSE_GAP.y)
		return
	_pose_time += delta
	var frames := float((POSES[pose][1] as Array).size())
	var hold_until := POSE_FADE_IN + _pose_hold
	# Eased, so the arm starts and lands softly.
	if _pose_time < POSE_FADE_IN:
		pose_progress = frames * smoothstep(0.0, 1.0, _pose_time / POSE_FADE_IN)
	elif _pose_time < hold_until:
		pose_progress = frames
	elif _pose_time < hold_until + POSE_FADE_OUT:
		pose_progress = frames * (1.0 - smoothstep(0.0, 1.0, (_pose_time - hold_until) / POSE_FADE_OUT))
	else:
		pose_progress = 0.0
		_pose_time = -1.0
	pose_mix = clampf(pose_progress, 0.0, 1.0)


# The frame the arm is leaving stays on; the next cross-fades in over it.
func _show_pose(shader_material: ShaderMaterial) -> void:
	if pose == &"" or pose_progress <= 0.0:
		shader_material.set_shader_parameter(&"pose_from_mix", 0.0)
		shader_material.set_shader_parameter(&"pose_to_mix", 0.0)
		return
	var frames: Array = POSES[pose][1]
	var step := mini(floori(pose_progress), frames.size() - 1)
	var blend := clampf(pose_progress - step, 0.0, 1.0)
	if pose_progress >= frames.size():
		step = frames.size()
		blend = 0.0
	shader_material.set_shader_parameter(&"pose_from", frames[step - 1] if step > 0 else frames[0])
	shader_material.set_shader_parameter(&"pose_from_mix", 1.0 if step > 0 else 0.0)
	if step < frames.size():
		shader_material.set_shader_parameter(&"pose_to", frames[step])
	shader_material.set_shader_parameter(&"pose_to_mix", blend if step < frames.size() else 0.0)


func _step_smile(delta: float) -> void:
	if _smile_time < 0.0:
		face_mix = 0.0
		return
	_smile_time += delta
	if _smile_time < SMILE_IN:
		face_mix = _smile_time / SMILE_IN
	elif _smile_time < SMILE_IN + SMILE_HOLD:
		face_mix = 1.0
	elif _smile_time < SMILE_IN + SMILE_HOLD + SMILE_OUT:
		face_mix = 1.0 - (_smile_time - SMILE_IN - SMILE_HOLD) / SMILE_OUT
	else:
		face_mix = 0.0
		_smile_time = -1.0
