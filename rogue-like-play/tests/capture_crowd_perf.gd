extends SceneTree

# The cost of a crowd, drawn for real at 1600x900 with vsync off: the
# sandbox held at 30, 50, 100 and 200 foes around the hero, who keeps
# swinging at the nearest (so hits, effects and numbers are counted too) and
# is kept alive. For each count it prints the mean frame time over three
# seconds, the script time of the process and physics steps, and how many
# foes were on screen, and saves .godot/crowd_<count>.png.
#   godot --path . --log-file .godot/crowd-perf.log --script res://tests/capture_crowd_perf.gd

const FRAME := 1.0 / 60.0
const COUNTS: Array[int] = [30, 50, 100, 200]
const SWING_GAP := 0.4
var sandbox: CombatArea
var _swing_left := 0.0


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	root.size = Vector2i(1600, 900)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	sandbox = load("res://world/areas/sandbox.tscn").instantiate()
	sandbox.seed_value = 21
	root.add_child(sandbox)
	var hero := sandbox.hero
	hero.controlled = false
	hero.health.max_hp = 1000000
	hero.health.hp = 1000000
	physics_frame.connect(_drive)
	var result := OK
	for count in COUNTS:
		sandbox.director.fixed_alive = count
		var waited := 0
		while sandbox.foes.size() < count and waited < 1200:
			await physics_frame
			waited += 1
		for settle in 90:
			await physics_frame
		var measured: Dictionary = await _measure(3.0)
		var image := root.get_texture().get_image()
		result |= image.save_png("res://.godot/crowd_%d.png" % count)
		print("%d foes (%d on screen): frame %.2f ms, process %.2f ms, physics %.2f ms" % [count, measured.on_screen, measured.frame, measured.process, measured.physics])
	physics_frame.disconnect(_drive)
	sandbox.hit_stop.release()
	quit(0 if result == OK else 1)


# Each physics frame: the hero stands and swings at the nearest foe.
func _drive() -> void:
	if sandbox == null or sandbox.hero == null:
		return
	_swing_left -= FRAME
	var input := HeroInput.new()
	if _swing_left <= 0.0:
		_swing_left = SWING_GAP
		var nearest := INF
		for foe: Foe in sandbox.foes:
			var distance := foe.global_position.distance_to(sandbox.hero.global_position)
			if distance < nearest:
				nearest = distance
				input.aim = (foe.global_position - sandbox.hero.global_position).normalized()
		input.strike_pressed = true
		input.strike_held = true
	sandbox.hero.step(input, FRAME)


func _measure(seconds: float) -> Dictionary:
	var started := Time.get_ticks_usec()
	var frames := 0
	var process := 0.0
	var physics := 0.0
	var on_screen := 0
	while Time.get_ticks_usec() - started < int(seconds * 1000000.0):
		await process_frame
		frames += 1
		process += Performance.get_monitor(Performance.TIME_PROCESS)
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	for foe: Foe in sandbox.foes:
		if foe.on_screen:
			on_screen += 1
	return {"frame": seconds * 1000.0 / frames, "process": process * 1000.0 / frames, "physics": physics * 1000.0 / frames, "on_screen": on_screen}
