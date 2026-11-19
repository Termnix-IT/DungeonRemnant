class_name HubOpening
extends Control

# The game's opening, over the hub's hall (HubHall) once at the start of a
# sitting: the first thing the player sees. Out of the dark the great gate's
# light comes first, the hall's lamps kindle one after another from the gate
# outward, and the game's logo comes out of the dark over the floor as the
# camera draws slowly back from the gate. The logo stands a moment, a light
# crossing it, and then (`begun`) it lifts away, the camera finishes drawing
# back, and the hub brings the lobby in (Hub._enter_lobby).
#
# It is a passage, not a screen: it asks for nothing and goes on to the
# lobby by itself (AUTO_AT), and nothing of it has to be waited for. Any
# key, button or click at any time, even while the hall is still dark, goes
# straight to the lobby. Only the very first moment is deaf (DEAF), so the
# key that started the game does not skip it.

signal begun

const LOGO: Texture2D = preload("res://art/hub/title/logo.png")
const LOGO_SHADER := preload("res://ui/hall/logo.gdshader")
# Where the camera starts (close on the gate) and where it has drawn back to
# by the time the logo stands, still closer than the lobby's view.
const START_VIEW := Vector2(0.553, 0.31)
const START_ZOOM := 1.62
const TITLE_VIEW := Vector2(0.528, 0.452)
const TITLE_ZOOM := 1.13
const DRAW_BACK := 5.2
# When each thing begins, and how long it takes.
const GATE_AT := 0.15
const GATE_TIME := 1.2
const LAMPS_AT := 0.7
const LAMP_STEP := 0.13
const LAMP_TIME := 0.45
const HALL_AT := 1.2
const HALL_TIME := 1.9
const LOGO_AT := 1.25
const LOGO_TIME := 1.15
const BYNAME_TIME := 0.6
const SHEEN_AT := 2.7
const SHEEN_TIME := 1.1
# When it goes on to the lobby by itself.
const AUTO_AT := 5.0
const DEAF := 0.35
# Leaving: the logo lifts away in LEAVE_TIME while the hall is lit whole in
# LIGHT_TIME, and the lobby's things take LOBBY_TIME to come to their places.
const LEAVE_TIME := 0.45
const LIGHT_TIME := 0.35
const LOBBY_TIME := 0.7
# The logo's width as a share of the screen's, and where its middle stands.
const LOGO_WIDTH := 0.36
const LOGO_MIDDLE := Vector2(0.5, 0.625)
const BYNAME_GAP := 10.0
const BYNAME_AT := 2.0

var hall: HubHall
# The opening is up and has not been answered.
var playing := false
var logo: TextureRect
# The game's name in the player's language under the logo, where it has one
# (the project's localized name: 残響の迷宮).
var byname: Label
var time := 0.0
var _pool: TextureRect
var _look: ShaderMaterial
var _run: Tween


func _ready() -> void:
	name = "Opening"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = HubTheme.create()
	# A pool of dark under the logo, so the gold reads on the lit floor.
	var fall := Gradient.new()
	fall.set_color(0, Color(0, 0, 0, 0.72))
	fall.set_color(1, Color(0, 0, 0, 0.0))
	fall.add_point(0.55, Color(0, 0, 0, 0.44))
	var dark := GradientTexture2D.new()
	dark.gradient = fall
	dark.fill = GradientTexture2D.FILL_RADIAL
	dark.fill_from = Vector2(0.5, 0.5)
	dark.fill_to = Vector2(1.0, 0.5)
	_pool = TextureRect.new()
	_pool.texture = dark
	_pool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pool.stretch_mode = TextureRect.STRETCH_SCALE
	_pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pool.modulate.a = 0.0
	add_child(_pool)
	_look = ShaderMaterial.new()
	_look.shader = LOGO_SHADER
	_look.set_shader_parameter(&"shown", 0.0)
	logo = TextureRect.new()
	logo.name = "Logo"
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_SCALE
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo.material = _look
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	byname = Label.new()
	byname.name = "Byname"
	byname.theme_type_variation = &"LobbyTitle"
	byname.text = local_name()
	byname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	byname.mouse_filter = Control.MOUSE_FILTER_IGNORE
	byname.modulate.a = 0.0
	add_child(byname)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	if logo == null or size.x <= 0.0:
		return
	var wide := size.x * LOGO_WIDTH
	var extent := Vector2(wide, wide / LOGO.get_size().aspect())
	logo.size = extent
	logo.position = size * LOGO_MIDDLE - extent * 0.5
	logo.pivot_offset = extent * 0.5
	_pool.size = extent * Vector2(1.9, 1.7)
	_pool.position = size * LOGO_MIDDLE - _pool.size * 0.5 + Vector2(0.0, extent.y * 0.12)
	byname.size = Vector2(size.x, 44.0)
	byname.position = Vector2(0.0, logo.position.y + extent.y + BYNAME_GAP)


# The game's name in the language shown, when the project gives it one
# other than the logo's own.
static func local_name() -> String:
	var names: Dictionary = ProjectSettings.get_setting("application/config/name_localized", {})
	var language := TranslationServer.get_locale().get_slice("_", 0)
	return str(names.get(language, ""))


# Begins it: the hall dark and the camera close on the gate, then all of it
# on one clock.
func play() -> void:
	if hall == null or playing:
		return
	playing = true
	time = 0.0
	hall.darken()
	hall.set_camera(START_VIEW, START_ZOOM)
	hall.look(TITLE_VIEW, TITLE_ZOOM, DRAW_BACK, Tween.TRANS_QUART, Tween.EASE_OUT)
	GameAudio.play(self, &"title_swell", -9.0)
	_run = create_tween().set_parallel()
	_run.tween_property(hall, "gate_lit", 1.0, GATE_TIME).set_delay(GATE_AT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for index in HubHall.LAMPS.size():
		# Each lamp catches, flares past its light and settles.
		_run.tween_method(_kindle.bind(index), 0.0, 1.0, LAMP_TIME).set_delay(LAMPS_AT + index * LAMP_STEP)
	_run.tween_property(hall, "ambient", 1.0, HALL_TIME).set_delay(HALL_AT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_run.tween_method(_show_logo, 0.0, 1.0, LOGO_TIME).set_delay(LOGO_AT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_run.tween_property(_pool, "modulate:a", 1.0, LOGO_TIME).set_delay(LOGO_AT)
	_run.tween_method(_sweep, -0.3, 1.3, SHEEN_TIME).set_delay(SHEEN_AT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_run.tween_property(byname, "modulate:a", 1.0, BYNAME_TIME).set_delay(BYNAME_AT)


func _kindle(share: float, index: int) -> void:
	hall.set_lamp(index, share * (1.0 + 0.5 * sin(share * PI)))


func _show_logo(share: float) -> void:
	_look.set_shader_parameter(&"shown", share)
	# It settles down into place as it comes.
	logo.scale = Vector2.ONE * lerpf(1.05, 1.0, share)


func _sweep(at: float) -> void:
	_look.set_shader_parameter(&"sheen", at)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	time += delta
	_look.set_shader_parameter(&"clock", time)
	# Left alone, it goes on to the lobby.
	if playing and time >= AUTO_AT:
		begin()


# Any key, button or click answers it. Everything else is kept from the
# lobby underneath while it is up.
func _input(event: InputEvent) -> void:
	if not playing:
		return
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventJoypadButton or event is InputEventMouseButton:
		pressed = event.pressed
	elif event is InputEventAction:
		pressed = event.pressed
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction:
		get_viewport().set_input_as_handled()
	if pressed and time >= DEAF:
		get_viewport().set_input_as_handled()
		begin()


# The answer: the hall is lit whole, the camera goes on back to the lobby's
# view, the logo lifts away, and the hub is told to bring the lobby in.
func begin() -> void:
	if not playing:
		return
	playing = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _run != null:
		_run.kill()
	GameAudio.play(self, &"title_start", -11.0)
	hall.light_all(LIGHT_TIME)
	hall.look(Vector2(0.5, 0.5), 1.0, LOBBY_TIME + 0.25, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	var leave := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	leave.tween_method(_sweep, 0.1, 1.3, LEAVE_TIME * 0.8)
	leave.tween_property(logo, "scale", Vector2.ONE * 1.08, LEAVE_TIME)
	leave.tween_method(func(share: float): _look.set_shader_parameter(&"fade", share), 1.0, 0.0, LEAVE_TIME)
	leave.tween_property(_pool, "modulate:a", 0.0, LEAVE_TIME)
	leave.tween_property(byname, "modulate:a", 0.0, LEAVE_TIME * 0.6)
	leave.chain().tween_callback(queue_free)
	begun.emit()
