class_name RouteMapView
extends CanvasLayer

# The run's route between areas, over everything else of the run: the layer
# that holds the page of gates (RouteGates), which shows the ways open now
# as gates before her and the chapter's whole route as a thread, and takes
# the pick. The run's director talks to this layer: it presents the route
# after each area, covers it with the run's menu, holds it behind an event's
# window, and is told the area chosen. Only the areas the last area's paths
# lead to can be chosen (the whole first layer at the start); that is
# RouteMap.open_after() and nothing the page adds to.

signal chosen(waypoint: RouteMap.Waypoint)
# The run's menu was asked for (Esc, Start).
signal menu_requested

var page: RouteGates
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
	hide()


# Shows the route at `at_layer` (the next to choose), with the run's state
# and a note (what the last area gave).
func present(route_map: RouteMap, at_layer: int, run: RunState, max_hp: int, note: String = "") -> void:
	show()
	page.present(route_map, at_layer, run, max_hp, note)


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
