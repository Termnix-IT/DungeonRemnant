class_name RouteMapView
extends CanvasLayer

# The run's route between areas, over everything else of the run: the layer
# that holds the page of gates (RouteGates), which shows the ways open now
# as gates before her and the chapter's whole route on a tablet, and takes
# the pick. The run's director talks to this layer: it presents the route
# after each area, covers it with the run's menu, holds it behind an event's
# window, and is told the area chosen. Only the areas the last area's paths
# lead to can be chosen (the whole first layer at the start); that is
# RouteMap.open_after() and nothing the page adds to.
#
# As she walks into her gate the screen goes dark (the page says how far:
# RouteGates.leaving()), and that dark is this layer's to draw, on a layer
# of its own over everything: it outlasts the page, lifting off the area she
# has come into (or the event's window) once the pick is taken.

signal chosen(waypoint: RouteMap.Waypoint)
# The run's menu was asked for (Esc, Start).
signal menu_requested

const CLOSING := preload("res://ui/route_map/route_curtain.gdshader")
# How long the dark takes to lift off what she has come into, and how many
# frames it waits first (the area is built in the frame of the pick, and
# that long frame would otherwise eat the lifting).
const LIFT_TIME := 0.45
const LIFT_WAIT := 2

var page: RouteGates
# The dark she walks into, on its own layer above the run's.
var curtain: CanvasLayer
var _dark: ColorRect
var _lifting: Tween
var _lift_in := 0
# The encyclopedia's record, for which foes are pictured as met (all of them
# without one).
var meta: MetaProgress:
	set(value):
		meta = value
		if page != null:
			page.meta = value

# The areas open now.
var current: Array:
	get:
		return page.open if page != null else []
# The layer to choose from now.
var route_layer: int:
	get:
		return page.route_layer if page != null else 0
# The run's menu lies over the page.
var covered: bool:
	get:
		return page != null and page.covered
# She is on her way to the pick, or the page is held behind an event's window.
var traveling: bool:
	get:
		return page != null and (page.traveling or page.held)


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	page = RouteGates.new()
	page.meta = meta
	add_child(page)
	page.taken.connect(_on_taken)
	page.menu_requested.connect(func(): menu_requested.emit())
	curtain = CanvasLayer.new()
	curtain.layer = 20
	add_child(curtain)
	_dark = ColorRect.new()
	_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark.color = Color(0.0, 0.0, 0.0, 0.0)
	var closing := ShaderMaterial.new()
	closing.shader = CLOSING
	_dark.material = closing
	curtain.add_child(_dark)
	hide()


# The dark follows her walk into the gate, closing on its far light, and
# lifts once she is through, opening from the screen's middle.
func _process(_delta: float) -> void:
	var closing := _dark.material as ShaderMaterial
	closing.set_shader_parameter(&"extent", _dark.size)
	if _lift_in > 0:
		_lift_in -= 1
		if _lift_in == 0:
			closing.set_shader_parameter(&"centre", Vector2(0.5, 0.5))
			_lifting = create_tween()
			_lifting.tween_property(_dark, "color:a", 0.0, LIFT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if page == null or not visible or not page.traveling:
		return
	var night := page.theme_colour(&"night")
	closing.set_shader_parameter(&"centre", page.exit_point())
	_dark.color = Color(night.r, night.g, night.b, page.leaving())


# Shows the route at `at_layer` (the next to choose), with the run's state
# and a note (what the last area gave).
func present(route_map: RouteMap, at_layer: int, run: RunState, max_hp: int, note: String = "") -> void:
	show()
	if _lifting != null:
		_lifting.kill()
	_lift_in = 0
	_dark.color.a = 0.0
	page.present(route_map, at_layer, run, max_hp, note)


# The cover over setting out opens on the route: the page opens again, seen.
func arrive() -> void:
	page.arrive()


# The run's menu lies over the route (or is lifted off it).
func cover(on: bool) -> void:
	page.cover(on)


# Kept behind an event's window: shown where she stopped, taking no pick
# until the route is presented again.
func hold() -> void:
	show()
	page.hold()


# A pick from the player: the question whether to go there.
func pick(waypoint: RouteMap.Waypoint) -> void:
	if visible:
		page.pick(waypoint)


# The pick taken at once (tests, and the end of her walk).
func _choose(waypoint: RouteMap.Waypoint) -> void:
	if visible:
		page.take(waypoint)


func _on_taken(waypoint: RouteMap.Waypoint) -> void:
	hide()
	chosen.emit(waypoint)
	# The dark she walked into lifts off what she has come to.
	if _lifting != null:
		_lifting.kill()
	if _dark.color.a > 0.0:
		_lift_in = LIFT_WAIT
