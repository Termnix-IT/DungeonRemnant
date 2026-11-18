extends SceneTree

# The route's gates drawn for real, in the states worth looking at: the
# run's first choice (a new player's record, the foes not met as shapes),
# the same with its leading foe not met either (a shape in its lit gate),
# two areas in with three ways open (at 1600x900, 1280x720 and 1920x1080),
# another gate turned to, an event's gate, the question asked, her walk
# into the light, an area read on the thread, the page held behind an
# event's window, the boss's gate dark, coming out and come out, and the
# page in English. The run is a real RunDirector's on a fixed seed, moved on
# without its fights. Images go to .godot/route_<state>_<width>.png.
# Needs a rendering display driver:
#   godot --path . --rendering-method gl_compatibility --log-file .godot/route-capture.log --script res://tests/capture_route.gd

const SEED := 10
const BOONS: Array[StringName] = [&"thunder_blade", &"whirlwind", &"life_feast", &"gale_step", &"chain_lightning"]
# The areas taken before the states two areas in, and before the boss.
const TWO_IN: Array[int] = [0, 1]
const TO_BOSS: Array[int] = [0, 1, 1, 1]

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
	_size(Vector2i(1600, 900))
	_start(MetaProgress.new(), [])
	director.meta.met = {"moss_sentinel": true, "gale_rat": true}
	director.show_map()
	await _grab("start", 1.2)
	director.meta.met = {}
	await _grab("unmet", 0.3)
	_start(null, TWO_IN)
	for size: Vector2i in [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		_size(size)
		await _grab("gates", 1.2)
	_size(Vector2i(1600, 900))
	page.choose(1)
	await _grab("second", 0.5)
	page.choose(2)
	await _grab("event", 0.5)
	page.choose(1)
	page.ask()
	await _grab("asked", 0.6)
	page.go()
	await _grab("walk", RouteGates.TRAVEL_TIME * 0.62)
	director.show_map()
	await create_timer(1.0).timeout
	page.choose(1)
	page.enter_thread()
	page.move_thread(Vector2i.RIGHT)
	await _grab("thread", 0.5)
	page.move_thread(Vector2i.RIGHT)
	await _grab("thread_boss", 0.4)
	director.show_map()
	page.hold()
	await _grab("held", 0.5)
	_start(null, TO_BOSS)
	await _grab("boss_dark", RouteGates.REVEAL_DARK * 0.7)
	await _grab("boss_coming", RouteGates.REVEAL_DARK * 0.3 + RouteGates.COMING_OUT * 0.75)
	await _grab("boss", RouteGates.COMING_OUT + RouteGates.REVEAL_HOLD + RouteGates.REVEAL_FADE + 0.8)
	TranslationServer.set_locale("en")
	_start(null, TWO_IN)
	await _grab("english", 1.2)
	page.enter_thread()
	page.move_thread(Vector2i.RIGHT)
	await _grab("english_thread", 0.5)
	TranslationServer.set_locale("ja")
	print("Captured the route's gates")
	quit()


func _size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	root.size = size


# A run on the fixed seed through the second chapter, moved on past the
# areas of these rows without their fights.
func _start(meta: MetaProgress, rows: Array) -> void:
	if director != null:
		director.free()
	director = RunDirector.new()
	director.seed_value = SEED
	director.chapter = load("res://data/chapters/gale_woods.tres")
	director.meta = meta
	root.add_child(director)
	page = director.map_view.page
	var run := director.run
	for index in rows.size():
		run.taken.append(run.route.nodes(index)[rows[index]])
	run.layer = rows.size()
	if rows.is_empty():
		return
	run.hp = 68
	run.echo = 124 + 60 * (rows.size() - 2)
	run.progression.level = 3 + rows.size()
	for id in BOONS.slice(0, 2 + rows.size()):
		run.build.take(run.build.find(id))
	director.show_map(tr("報酬　「%s」を得た") % tr(run.build.find(&"gale_step").display_name) + tr("　残響 +%s") % "27")


func _grab(state: String, wait: float) -> void:
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/route_%s_%d.png" % [state, root.size.x])
