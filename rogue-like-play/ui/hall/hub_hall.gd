class_name HubHall
extends Control

# The hub's hall: the painting of the hall of preparation behind the lobby
# and its pages, drawn as a place (hub_hall.gdshader). Its lamps flicker, the
# far view through its great gate drifts with haze and its light swells and
# falls down the stairs, dust floats in the air, and the view leans a little
# with the pointer, the far view less than the hall. It has a camera (`eye`,
# `zoom`): the game's opening draws back from the gate, and the departure
# goes into it. The thing the lobby's chosen entry belongs to is lit
# (focus()): the gate itself for the departure, which shines harder.
#
# It never takes input and stops while the hub is hidden.

const PAINTING := preload("res://art/hub/lobby_hall.png")
const FAR := preload("res://art/hub/lobby_hall_far.png")
const SHADER := preload("res://ui/hall/hub_hall.gdshader")
# The painting's lamps: where each hangs (the painting's UV) and how far its
# glow reaches (a share of the painting's height), in the order the opening
# kindles them: from the gate outward.
const LAMPS := [
	[Vector2(0.671, 0.127), 0.105],  # hanging lantern by the gate
	[Vector2(0.449, 0.430), 0.06],  # altar candle right
	[Vector2(0.352, 0.440), 0.06],  # altar candle left
	[Vector2(0.710, 0.234), 0.08],  # wall lantern
	[Vector2(0.291, 0.229), 0.085],  # lantern over the weapon rack
	[Vector2(0.771, 0.381), 0.09],  # counter lantern
	[Vector2(0.168, 0.146), 0.105],  # hanging lantern by the banner
	[Vector2(0.869, 0.254), 0.085],  # stall lantern
	[Vector2(0.954, 0.264), 0.085],  # far right lantern
]
# The great gate: its opening's middle and where its light meets the floor.
const GATE := Vector2(0.555, 0.27)
const GATE_FOOT := Vector2(0.552, 0.44)
# The hall thing each lobby entry belongs to: where (the painting's UV), how
# far its light reaches and its colour. The departure's is the gate, which
# shines harder instead.
const FOCUS := {
	&"upgrade": [Vector2(0.398, 0.330), 0.11, Color(0.55, 0.66, 1.0)],  # rune crystal over the altar
	&"status": [Vector2(0.262, 0.470), 0.15, Color(1.0, 0.70, 0.38)],  # weapon rack
	&"codex": [Vector2(0.402, 0.425), 0.075, Color(1.0, 0.80, 0.50)],  # the open book on the altar
	&"settings": [Vector2(0.291, 0.229), 0.10, Color(1.0, 0.70, 0.38)],  # lantern
}
const GATE_ENTRY := &"departure"
const LAMP_COLOUR := Color(1.0, 0.68, 0.34)
const GATE_COLOUR := Color(0.45, 0.62, 1.0)
# How hard the gate shines at rest and as the departure's entry is chosen.
const GATE_REST := 1.0
const GATE_CHOSEN := 1.5
const FOCUS_TIME := 0.35
# How far the view leans: toward the pointer, and toward the lit thing.
const POINTER_LEAN := 0.0045
const FOCUS_LEAN := 0.012
const LEAN_EASE := 2.6
# The dark over the painting: behind the lobby (lighter, with its foot
# darkened for the plate and the keys), and behind the hub's other pages (as
# those pages were made on: an even shade, the foot left alone).
const VEIL := 0.1
const FOOT := 1.0
const PAGE_VEIL := 0.16

# Where the camera looks (the painting's UV at the screen's middle) and how
# close it is (1: the painting covers the screen).
var eye := Vector2(0.5, 0.5):
	set(value):
		eye = value
		_send(&"eye", eye)
var zoom := 1.0:
	set(value):
		zoom = value
		_send(&"zoom", zoom)
# How hard the gate shines.
var gate_power := GATE_REST:
	set(value):
		gate_power = value
		_send(&"gate_power", gate_power)
# 0: only what its lights show; 1: the whole hall.
var ambient := 1.0:
	set(value):
		ambient = value
		_send(&"ambient", ambient)
var gate_lit := 1.0:
	set(value):
		gate_lit = value
		_send(&"gate_lit", gate_lit)
# The dark laid over the whole painting, and how much over its foot.
var veil := VEIL:
	set(value):
		veil = value
		_send(&"veil", veil)
var foot := FOOT:
	set(value):
		foot = value
		_send(&"foot", foot)
var focus_power := 0.0:
	set(value):
		focus_power = value
		_send(&"focus_power", focus_power)
var focus_id := &""
var dust: CPUParticles2D
var time := 0.0
var _view: ColorRect
var _look: ShaderMaterial
var _lit := PackedFloat32Array()
var _lean := Vector2.ZERO
var _focus_tween: Tween
var _asked := &""
var _asked_shine := GATE_REST
var _light: Tween
var _camera: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_look = ShaderMaterial.new()
	_look.shader = SHADER
	_look.set_shader_parameter(&"painting", PAINTING)
	_look.set_shader_parameter(&"far_matte", FAR)
	_look.set_shader_parameter(&"aspect", PAINTING.get_size().aspect())
	_look.set_shader_parameter(&"lamp_colour", LAMP_COLOUR)
	_look.set_shader_parameter(&"gate_colour", GATE_COLOUR)
	_look.set_shader_parameter(&"gate", GATE)
	_look.set_shader_parameter(&"gate_foot", GATE_FOOT)
	_look.set_shader_parameter(&"veil", veil)
	_look.set_shader_parameter(&"foot", foot)
	var lamps := PackedVector3Array()
	for lamp: Array in LAMPS:
		lamps.append(Vector3((lamp[0] as Vector2).x, (lamp[0] as Vector2).y, lamp[1]))
	_look.set_shader_parameter(&"lamps", lamps)
	_lit.resize(LAMPS.size())
	_lit.fill(1.0)
	_look.set_shader_parameter(&"lamp_lit", _lit)
	_view = ColorRect.new()
	_view.name = "View"
	_view.material = _look
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_dust()
	resized.connect(_fit)
	visibility_changed.connect(func(): dust.emitting = is_visible_in_tree())
	_fit()
	eye = eye
	zoom = zoom
	gate_power = gate_power


func _send(what: StringName, value: Variant) -> void:
	if _look != null:
		_look.set_shader_parameter(what, value)


# Slow dust in the air, lit by the lamps.
func _build_dust() -> void:
	dust = CPUParticles2D.new()
	dust.amount = 40
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.direction = Vector2(0.3, -1)
	dust.spread = 40.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 3.0
	dust.initial_velocity_max = 9.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.6
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.82, 0.55, 0.0))
	fade.set_color(1, Color(1.0, 0.82, 0.55, 0.0))
	fade.add_point(0.25, Color(1.0, 0.82, 0.55, 0.38))
	fade.add_point(0.75, Color(1.0, 0.82, 0.55, 0.38))
	dust.color_ramp = fade
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	dust.material = additive
	add_child(dust)


# The painting covers the screen; the shader is told what share of it shows.
func _fit() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var full := PAINTING.get_size()
	var factor := maxf(size.x / full.x, size.y / full.y)
	_send(&"cover", size / (full * factor))
	if dust != null:
		dust.position = size * 0.5
		dust.emission_rect_extents = size * 0.5


# Where a place in the painting (its UV) is on the screen, as the camera
# looks now.
func spot(uv: Vector2) -> Vector2:
	var full := PAINTING.get_size()
	var cover := size / (full * maxf(size.x / full.x, size.y / full.y))
	return ((uv - eye) * zoom / cover + Vector2(0.5, 0.5)) * size


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	time += delta
	_send(&"clock", time)
	# The view leans toward the pointer and toward the lit thing; the far
	# view through the gate lags behind it.
	var want := Vector2.ZERO
	if size.x > 0.0 and get_window().has_focus():
		want = ((get_local_mouse_position() / size).clamp(Vector2.ZERO, Vector2.ONE) - Vector2(0.5, 0.5)) * POINTER_LEAN
	if FOCUS.has(focus_id):
		want += ((FOCUS[focus_id][0] as Vector2) - Vector2(0.5, 0.5)) * FOCUS_LEAN * focus_power
	elif focus_id == GATE_ENTRY:
		want += (GATE - Vector2(0.5, 0.5)) * FOCUS_LEAN * inverse_lerp(GATE_REST, GATE_CHOSEN, gate_power)
	_lean = _lean.lerp(want, clampf(delta * LEAN_EASE, 0.0, 1.0))
	_send(&"lean", _lean)


# Lights the thing an entry belongs to and lets the last one go dark. The
# departure's is the gate, which shines harder (or as hard as `shine` says:
# the departure's page stands before it). An unknown or empty id clears it,
# as away from the lobby.
func focus(id: StringName, shine := -1.0) -> void:
	var gate := shine if shine >= 0.0 else (GATE_CHOSEN if id == GATE_ENTRY else GATE_REST)
	if id == _asked and is_equal_approx(gate, _asked_shine):
		return
	_asked = id
	_asked_shine = gate
	if _focus_tween != null:
		_focus_tween.kill()
	_focus_tween = create_tween().set_trans(Tween.TRANS_SINE)
	var known := FOCUS.has(id)
	_focus_tween.tween_property(self, "gate_power", gate, FOCUS_TIME)
	if focus_power > 0.0 and focus_id != id:
		_focus_tween.parallel().tween_property(self, "focus_power", 0.0, FOCUS_TIME * 0.5)
	_focus_tween.tween_callback(func():
		focus_id = id if known or id == GATE_ENTRY else &""
		if known:
			var target: Array = FOCUS[id]
			_send(&"focus", Vector3((target[0] as Vector2).x, (target[0] as Vector2).y, target[1]))
			_send(&"focus_colour", target[2]))
	if known:
		_focus_tween.tween_property(self, "focus_power", 1.0, FOCUS_TIME)


# Moves the camera: where it looks and how close, eased over a time.
func look(to_eye: Vector2, to_zoom: float, duration: float, trans := Tween.TRANS_CUBIC, ease := Tween.EASE_IN_OUT) -> Tween:
	if _camera != null:
		_camera.kill()
	_camera = create_tween().set_parallel().set_trans(trans).set_ease(ease)
	_camera.tween_property(self, "eye", to_eye, duration)
	_camera.tween_property(self, "zoom", to_zoom, duration)
	return _camera


# The hall as the lobby stands in it, or as it lies behind another page.
func dress(for_lobby: bool) -> void:
	veil = VEIL if for_lobby else PAGE_VEIL
	foot = FOOT if for_lobby else 0.0


# The camera is on the lobby's view of the hall and is not moving.
func rests() -> bool:
	return (_camera == null or not _camera.is_running()) and is_equal_approx(zoom, 1.0) and eye.is_equal_approx(Vector2(0.5, 0.5))


# Sets the camera at once, ending any move.
func set_camera(to_eye: Vector2, to_zoom: float) -> void:
	if _camera != null:
		_camera.kill()
	eye = to_eye
	zoom = to_zoom


# A lamp lit or out (0 to 1), by its place in LAMPS.
func set_lamp(index: int, value: float) -> void:
	_lit[index] = value
	_send(&"lamp_lit", _lit)


func lamp(index: int) -> float:
	return _lit[index]


# The whole hall dark: no lamp lit, the gate's light out.
func darken() -> void:
	if _light != null:
		_light.kill()
	_lit.fill(0.0)
	_send(&"lamp_lit", _lit)
	ambient = 0.0
	gate_lit = 0.0


# The whole hall lit as at rest, over a time (0: at once), whatever of it
# was lit before.
func light_all(duration := 0.0) -> void:
	if _light != null:
		_light.kill()
	if duration <= 0.0:
		_lit.fill(1.0)
		_send(&"lamp_lit", _lit)
		ambient = 1.0
		gate_lit = 1.0
		return
	var from := _lit.duplicate()
	_light = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_light.tween_method(func(share: float):
		for index in _lit.size():
			_lit[index] = lerpf(from[index], 1.0, share)
		_send(&"lamp_lit", _lit), 0.0, 1.0, duration)
	_light.tween_property(self, "ambient", 1.0, duration)
	_light.tween_property(self, "gate_lit", 1.0, duration)
