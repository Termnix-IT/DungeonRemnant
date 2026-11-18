extends SceneTree

# The route's gates in motion, as strips of frames a twentieth of a second
# apart, to read the timing of what a still cannot show: the page opening,
# a gate turned to, the question asked (the grilles falling), the question
# taken back, her walk into the gate, the dark lifting off the area she has
# come into, and the boss's coming out. Each strip
# is written to .godot/route_motion_<moment>.png, its frames left to right
# and top to bottom. The run is a real RunDirector's on a fixed seed, moved
# on without its fights.
# Needs a rendering display driver:
#   godot --path . --rendering-method gl_compatibility --log-file .godot/route-motion.log --script res://tests/capture_route_motion.gd

const SEED := 10
const STEP := 0.05
const FRAME := Vector2i(640, 360)
const ACROSS := 6

var director: RunDirector
var page: RouteGates


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	TranslationServer.set_locale("ja")
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	_start([0, 1])
	await _strip("open", 18)
	await create_timer(0.6).timeout
	page.choose(1)
	await _strip("turn", 12)
	await create_timer(0.4).timeout
	page.ask()
	await _strip("ask", 18)
	page.cancel()
	await _strip("back", 12)
	await create_timer(0.3).timeout
	page.ask()
	await create_timer(0.7).timeout
	page.go()
	await _strip("go", 24, false)
	# The same walk with the run going on into the area: the last of it, and
	# the dark lifting off the fight.
	_start([0, 1])
	await create_timer(0.8).timeout
	page.choose(0)
	page.ask()
	await create_timer(0.6).timeout
	page.go()
	await create_timer(RouteGates.TRAVEL_TIME * 0.7).timeout
	await _strip("enter", 18)
	_start([0, 1, 1, 1])
	await _strip("boss", 48)
	print("Captured the route's motion")
	quit()


# A run on the fixed seed through the second chapter, moved on past the
# areas of these rows without their fights.
func _start(rows: Array) -> void:
	if director != null:
		director.free()
	director = RunDirector.new()
	director.seed_value = SEED
	director.chapter = load("res://data/chapters/gale_woods.tres")
	root.add_child(director)
	page = director.map_view.page
	var run := director.run
	for index in rows.size():
		run.taken.append(run.route.nodes(index)[rows[index]])
	run.layer = rows.size()
	run.hp = 68
	run.echo = 124
	director.show_map()


# `count` frames from now, STEP apart, laid in one picture. A strip that
# ends the page (her walk) keeps the run from entering its area after it.
func _strip(moment: String, count: int, keep := true) -> void:
	if not keep and director.map_view.chosen.is_connected(director.enter):
		director.map_view.chosen.disconnect(director.enter)
	var frames: Array[Image] = []
	for index in count:
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		frame.resize(FRAME.x, FRAME.y, Image.INTERPOLATE_LANCZOS)
		frames.append(frame)
		await create_timer(STEP).timeout
	var down := ceili(float(count) / ACROSS)
	var sheet := Image.create_empty(FRAME.x * ACROSS, FRAME.y * down, false, frames[0].get_format())
	for index in frames.size():
		sheet.blit_rect(frames[index], Rect2i(Vector2i.ZERO, FRAME), Vector2i((index % ACROSS) * FRAME.x, (index / ACROSS) * FRAME.y))
	sheet.save_png("res://.godot/route_motion_%s.png" % moment)
