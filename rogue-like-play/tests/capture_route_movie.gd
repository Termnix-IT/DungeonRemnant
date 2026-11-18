extends SceneTree

# The route's gates played through once, for a film of it: the page opening,
# each gate turned to, an area read on the tablet, the question asked and
# taken back, asked again and gone ahead with (her walk through the gate and
# the dark lifting off the area), then the boss's gate coming out of the
# dark and her walk into it. The run is a real RunDirector's on a fixed
# seed, moved on without its fights.
# Run under the movie writer, which also records the sound, and turn the
# result into a film with ffmpeg:
#   godot --path . --rendering-method gl_compatibility --resolution 1280x720 --fixed-fps 60 --write-movie .godot/route_movie.avi --script res://tests/capture_route_movie.gd
#   ffmpeg -y -i .godot/route_movie.avi -c:v libx264 -pix_fmt yuv420p -crf 20 -c:a aac .godot/route_movie.mp4

const SEED := 10
const BOONS: Array[StringName] = [&"thunder_blade", &"whirlwind", &"life_feast", &"gale_step"]

var director: RunDirector
var page: RouteGates


func _initialize() -> void:
	call_deferred("play")


func play() -> void:
	TranslationServer.set_locale("ja")
	_start([0, 1])
	await _wait(1.6)
	page.choose(1)
	await _wait(1.3)
	page.choose(2)
	await _wait(1.3)
	page.choose(1)
	await _wait(0.9)
	page.enter_thread()
	await _wait(1.0)
	page.move_thread(Vector2i.RIGHT)
	await _wait(1.0)
	page.move_thread(Vector2i.RIGHT)
	await _wait(1.1)
	page._leave_thread()
	await _wait(0.5)
	page.ask()
	await _wait(1.3)
	page.cancel()
	await _wait(0.9)
	page.choose(0)
	await _wait(1.1)
	page.ask()
	await _wait(1.2)
	page.go()
	await _wait(RouteGates.TRAVEL_TIME + 1.4)
	_start([0, 1, 1, 1])
	await _wait(RouteGates.REVEAL_DARK + RouteGates.COMING_OUT + RouteGates.REVEAL_HOLD + RouteGates.REVEAL_FADE + 1.0)
	page.ask()
	await _wait(1.0)
	page.go()
	await _wait(RouteGates.TRAVEL_TIME * 0.98)
	quit()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


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
	run.echo = 124 + 60 * (rows.size() - 2)
	run.progression.level = 3 + rows.size()
	for id in BOONS.slice(0, rows.size()):
		run.build.take(run.build.find(id))
	director.show_map(tr("報酬　「%s」を得た") % tr(run.build.find(&"gale_step").display_name) + tr("　残響 +%s") % "27")
