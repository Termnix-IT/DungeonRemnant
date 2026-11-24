extends SceneTree

# The run's result drawn for real, each of its three scenes as it plays and
# once it is all in: a run won (the dawn coming out of the door, the word
# struck, the seal stamped, the echo counting, the scene whole; then with a
# first clear and a step opened, with a large build and many foes newly
# recorded, at 1280x720 and 1920x1080, and in English), a run lost (the
# picture coming up out of the dark, who felled her rising, the scene whole;
# then a fall no blow named, the other sizes, English) and a run left (as it
# opens and whole). Images go to .godot/result_<state>_<width>.png. Look at
# them: whether each scene reads as its own picture, what is told first, the
# words over the painting, cut text, and the way on. Needs a rendering
# display driver:
#   godot --path . --rendering-method gl_compatibility --log-file .godot/result-capture.log --script res://tests/capture_result.gd

const SIZES: Array[Vector2i] = [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1920, 1080)]
const CHARGER := "res://data/foes/raging_charger.tres"
var shots := {}
var meta: MetaProgress


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	_size(SIZES[0])
	# A run won: the scene as it plays.
	var run := await _run(31, -1, 9, 420, 3)
	run.finish(true)
	for time: float in [0.12, 0.3, 0.5, 0.8, 1.3]:
		await _until(run, time)
		await _grab("result_clear_%03d_1600" % roundi(time * 100.0))
	await _whole(run)
	await _grab("result_clear_1600")
	run.end_view._boon_cells[3].grab_focus()
	await _wait(0.2)
	await _grab("result_clear_boon_1600")
	for size in [SIZES[1], SIZES[2]]:
		_size(size)
		await _wait(0.3)
		await _grab("result_clear_%d" % size.x)
	_size(SIZES[0])
	run.free()
	# The first clear, a step opened, a large build, many foes newly recorded.
	meta = MetaProgress.new()
	run = await _run(31, -1, 30, 1840, 12)
	run.finish(true)
	run.end_view.tell_opened(tr("難易度の段階が開いた"))
	await _whole(run)
	await _grab("result_clear_full_1600")
	run.free()
	# A run lost: the scene as it plays.
	run = await _run(31, 2, 5, 55, 2)
	run.fallen_to = load(CHARGER)
	run.finish(false)
	for time: float in [0.4, 0.9, 1.5, 2.1, 2.7]:
		await _until(run, time)
		await _grab("result_defeat_%03d_1600" % roundi(time * 100.0))
	await _whole(run)
	await _grab("result_defeat_1600")
	for size in [SIZES[1], SIZES[2]]:
		_size(size)
		await _wait(0.3)
		await _grab("result_defeat_%d" % size.x)
	_size(SIZES[0])
	run.free()
	# A fall no blow named, with nothing taken.
	run = await _run(31, 0, 0, 0, 0)
	run.finish(false)
	await _whole(run)
	await _grab("result_defeat_unnamed_1600")
	run.free()
	# A run left.
	run = await _run(31, 3, 7, 210, 1)
	run.finish(false, true)
	for time: float in [0.15, 0.45]:
		await _until(run, time)
		await _grab("result_return_%03d_1600" % roundi(time * 100.0))
	await _whole(run)
	await _grab("result_return_1600")
	_size(SIZES[2])
	await _wait(0.3)
	await _grab("result_return_1920")
	_size(SIZES[0])
	run.free()
	# In English.
	TranslationServer.set_locale("en")
	run = await _run(31, -1, 9, 420, 3)
	run.finish(true)
	await _whole(run)
	await _grab("result_clear_english_1600")
	run.free()
	run = await _run(31, 2, 5, 55, 2)
	run.fallen_to = load(CHARGER)
	run.finish(false)
	await _whole(run)
	await _grab("result_defeat_english_1600")
	run.free()
	TranslationServer.set_locale("ja")
	var result := OK
	for file_name: String in shots:
		result |= (shots[file_name] as Image).save_png("res://.godot/%s.png" % file_name)
	print("Captured the result: ", ", ".join(shots.keys()))
	quit(0 if result == OK else 1)


# A run that has walked `layers` layers (-1: all of them), taken `boons`
# boons, holds `echo` and met `fresh` foes the bestiary did not hold.
func _run(seed_value: int, layers: int, boons: int, echo: int, fresh: int) -> RunDirector:
	if meta == null:
		meta = MetaProgress.new()
		meta.echo = 240
		for foe in FoeCatalog.FOES.slice(0, 6):
			meta.met[foe.id] = true
	var director := RunDirector.new()
	director.seed_value = seed_value
	director.meta = meta
	director.returns_to_base = true
	root.add_child(director)
	await process_frame
	var run := director.run
	var walked := run.route.size() if layers < 0 else layers
	for layer in walked:
		run.taken.append(run.route.nodes(layer)[0])
	run.layer = walked
	for index in boons:
		var offer := run.build.offer(run.rng, 3)
		if offer.is_empty():
			break
		run.build.take(offer[0])
		if index % 3 == 0 and run.build.rank(offer[0].id) < offer[0].max_level:
			run.build.take(offer[0])
	run.echo = echo
	run.kills = 37 * walked + 4
	run.time = 71.0 * walked + 9.0
	run.progression.level = 1 + walked * 3
	var unknown: Array = FoeCatalog.FOES.filter(func(foe: FoeData) -> bool: return not meta.has_met(foe.id))
	for foe: FoeData in unknown.slice(0, fresh):
		run.met[foe.id] = true
	for foe in FoeCatalog.FOES.slice(0, 3):
		run.met[foe.id] = true
	return director


func _size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	root.size = size


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


# Waits until the result has played `time` seconds.
func _until(run: RunDirector, time: float) -> void:
	for frame in 1200:
		await process_frame
		if run.end_view._time >= time:
			return


# Waits until the result is all in.
func _whole(run: RunDirector) -> void:
	for frame in 1200:
		await process_frame
		if run.end_view.settled:
			break
	await _wait(1.0)


func _grab(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	shots[file_name] = root.get_texture().get_image()
