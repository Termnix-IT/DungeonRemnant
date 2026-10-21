extends SceneTree

# The Phase 1 sandbox drawn for real at 1600x900: the hero among sentinels,
# mid-swing, charging, letting the charged attack loose, dashing with her
# afterimages, bringing her skill down with its ring on the floor, an
# elite and a rat winding up their attacks with their warnings, a level-up's
# cards and a build of lightning, fire and the wave in a crowd, the edges
# pulsing at low health, then
# the frame time with 12, 30 and 60 sentinels on the field (vsync off, the
# hero kept alive). Images go to .godot/action_*.png; the times are printed.
# Needs a rendering display driver:
#   godot --path . --log-file .godot/action-capture.log --script res://tests/capture_action_sandbox.gd

const FRAME := 1.0 / 60.0
var sandbox: CombatArea
var shots := {}


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
	sandbox.seed_value = 11
	root.add_child(sandbox)
	sandbox.director.fixed_alive = 12
	var hero := sandbox.hero
	hero.controlled = false
	# Kept standing through the frame-time runs.
	hero.health.max_hp = 100000
	hero.health.hp = 100000
	await drive(HeroInput.new(), 3.0)
	await _grab("action_crowd")
	await drive(HeroInput.make(Vector2.ZERO, _toward_nearest(), true), 0.1)
	await _grab("action_swing")
	await drive(HeroInput.new(), 0.4)
	var aim := _toward_nearest()
	await drive(HeroInput.make(Vector2.ZERO, aim, true, true), 0.9)
	await _grab("action_charge")
	await drive(HeroInput.make(Vector2.ZERO, aim), 0.12)
	await _grab("action_charged_blow")
	await drive(HeroInput.new(), 0.5)
	await drive(HeroInput.make(Vector2.RIGHT, Vector2.ZERO, false, false, true), 0.08)
	await _grab("action_dash")
	await drive(HeroInput.new(), 0.5)
	await drive(HeroInput.make(Vector2.ZERO, _toward_nearest(), false, false, false, true), 0.2)
	await _grab("action_skill")
	# A raging charger winding up its slam beside her, and a rat its pounce.
	sandbox.director.running = false
	var charger: Foe = sandbox.spawn_foe(load("res://data/foes/raging_charger.tres"), hero.global_position + Vector2(90, 20))
	charger.begin_attack(charger.data.attacks[0], hero.global_position - charger.global_position)
	var rat: Foe = sandbox.spawn_foe(load("res://data/foes/dashing_rat.tres"), hero.global_position + Vector2(-140, -40))
	rat.begin_attack(rat.data.attacks[0], hero.global_position - rat.global_position)
	await drive(HeroInput.new(), 0.3)
	await _grab("action_warnings")
	await drive(HeroInput.new(), 0.5)
	await _grab("action_slam")
	sandbox.director.running = true
	# A level-up's cards, then a build of lightning, fire and the wave at work
	# in a crowd.
	sandbox._on_gems(sandbox.run.progression.required_exp())
	await create_timer(0.6, true).timeout
	await _grab("action_levelup")
	sandbox.choice._select(0)
	for id: StringName in [&"thunder_blade", &"chain_lightning", &"hellfire", &"shockwave", &"shockwave"]:
		sandbox.run.build.take(sandbox.run.build.find(id))
	sandbox.director.fixed_alive = 60
	while sandbox.foes.size() < 60:
		await drive(HeroInput.new(), 0.25)
	await drive(HeroInput.new(), 1.5)
	for swing in 6:
		await drive(HeroInput.make(Vector2.ZERO, _toward_nearest(), true), 0.13)
	await _grab("action_build")
	# Low on health: the edges pulse red.
	hero.health.hp = hero.health.max_hp / 6
	await drive(HeroInput.new(), 0.3)
	await _grab("action_danger")
	hero.health.hp = hero.health.max_hp
	await drive(HeroInput.new(), 0.3)
	sandbox.director.fixed_alive = 12
	var times := {}
	for count in [12, 30, 60]:
		sandbox.director.fixed_alive = count
		while sandbox.foes.size() < count:
			await drive(HeroInput.new(), 0.25)
		await drive(HeroInput.new(), 1.0)
		times[count] = await _frame_time()
		if count == 60:
			await _grab("action_sixty")
	var result := OK
	for file_name: String in shots:
		result |= (shots[file_name] as Image).save_png("res://.godot/%s.png" % file_name)
	print("Frame time (vsync off): 12 foes %.2f ms, 30 foes %.2f ms, 60 foes %.2f ms" % [times[12], times[30], times[60]])
	sandbox.hit_stop.release()
	quit(0 if result == OK else 1)


# Steps the hero by hand for `seconds` of physics frames; a press counts on
# the first frame only.
func drive(input: HeroInput, seconds: float) -> void:
	for index in roundi(seconds / FRAME):
		await physics_frame
		var frame_input := input if index == 0 else HeroInput.make(input.move, input.aim, false, input.strike_held, false)
		sandbox.hero.step(frame_input, FRAME)


func _toward_nearest() -> Vector2:
	var hero := sandbox.hero
	var best := Vector2.RIGHT
	var nearest := INF
	for foe: Foe in sandbox.foes:
		var distance := foe.global_position.distance_to(hero.global_position)
		if distance < nearest:
			nearest = distance
			best = (foe.global_position - hero.global_position).normalized()
	return best


func _grab(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	shots[file_name] = root.get_texture().get_image()


# The mean frame time over two seconds, with the hero standing still.
func _frame_time() -> float:
	var started := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - started < 2000000:
		await process_frame
		frames += 1
	return 2000.0 / frames
