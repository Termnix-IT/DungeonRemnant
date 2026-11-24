class_name FightStage
extends Control

# A window onto a real fight, for the screens that show the fight outside a
# run: the bestiary watching a foe move and strike, the help showing what a
# key does, the settings showing what a setting changes. Behind the window
# is a StageArea (the fight's own area, apart from any run) in a viewport of
# its own, drawn into this control with soft corners and a darkened rim.
#
# It is given a scene: a function that fills a fresh StageArea (who stands
# where, and what happens when). The scene plays, and when its period is
# over the stage fades for a moment, throws the area away and builds the
# scene again, so every showing starts clean. show_scene() changes the
# scene; replay() starts it over; halt() stops it and frees everything (no
# actor, sound, timer or effect is left running once it is hidden or gone).

const WINDOW := preload("res://ui/stage/stage_window.gdshader")
const BLINK := 0.14
# The viewport is never made larger than this (px).
const MOST := Vector2(1920.0, 1080.0)

# The area now playing (null while halted).
var area: StageArea
var viewport: SubViewport
# How many world px the window shows across, and where its middle is from
# the room's (world px).
var across := 760.0
var look := Vector2.ZERO
var _scene := Callable()
var _theme := 0
var _screen: TextureRect
var _blink: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.size = Vector2i(640, 360)
	add_child(viewport)
	_screen = TextureRect.new()
	_screen.texture = viewport.get_texture()
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_SCALE
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var look_of := ShaderMaterial.new()
	look_of.shader = WINDOW
	_screen.material = look_of
	add_child(_screen)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_fit)
	visibility_changed.connect(_on_shown)
	# The window's size on the screen changes with the game's window too.
	get_viewport().size_changed.connect(_fit)
	_fit()


# The area's camera is the stage's view. A camera put in as another is
# taken out can be left not looking (the engine picks the view by itself,
# and can pick none): the stage sees to it that its area's is the one.
func _process(_delta: float) -> void:
	if area != null and not area.camera.is_current():
		area.camera.make_current()
		_frame()


# Plays `scene` (a function taking the fresh StageArea) in the fight's
# theme `theme`, showing `width` world px across.
func show_scene(scene: Callable, theme: int = 0, width: float = 760.0, offset: Vector2 = Vector2.ZERO) -> void:
	_scene = scene
	_theme = theme
	across = width
	look = offset
	_build()


func replay() -> void:
	if _scene.is_valid():
		_build()


# Stops and frees what is playing.
func halt() -> void:
	_scene = Callable()
	_clear()
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func playing() -> bool:
	return area != null


func _clear() -> void:
	if area != null:
		area.hit_stop.release()
		viewport.remove_child(area)
		area.free()
		area = null


func _build() -> void:
	_clear()
	if not _scene.is_valid() or not is_visible_in_tree():
		return
	area = StageArea.new()
	area.theme_index = _theme
	viewport.add_child(area)
	area.ended.connect(_start_over, CONNECT_DEFERRED)
	_scene.call(area)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_frame()


# The period is over: a blink, and the scene again.
func _start_over() -> void:
	if _blink != null:
		_blink.kill()
	_blink = create_tween()
	_blink.tween_property(_screen, "modulate:a", 0.0, BLINK)
	_blink.tween_callback(_build)
	_blink.tween_property(_screen, "modulate:a", 1.0, BLINK)


func _on_shown() -> void:
	if is_visible_in_tree():
		if _scene.is_valid() and area == null:
			_build()
	else:
		_clear()
		if viewport != null:
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


# The viewport as large as the window is on the screen, so it is sharp at
# any window size; and the view over the room.
func _fit() -> void:
	if viewport == null:
		return
	var scale_now := get_global_transform_with_canvas().get_scale() * get_viewport().get_stretch_transform().get_scale() if is_inside_tree() else Vector2.ONE
	var wanted := (size * scale_now).clamp(Vector2(64.0, 36.0), MOST)
	viewport.size = Vector2i(wanted.round())
	_frame()


func _frame() -> void:
	if area == null:
		return
	if not area.camera.is_current():
		area.camera.make_current()
	area.camera.zoom = Vector2.ONE * (viewport.size.x / maxf(across, 1.0))
	area.camera.global_position = area.middle() + look


func _exit_tree() -> void:
	_clear()
