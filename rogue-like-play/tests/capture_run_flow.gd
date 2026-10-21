extends SceneTree

# A real-time run drawn for real at 1600x900: the route map at the start,
# an open field a few seconds in (its goal on the HUD), the map after the
# first area with its reward noted, an arena's wave arriving on its marks,
# a boon reward's cards, and the end of the run. Images go to
# .godot/run_*.png. Needs a rendering display driver:
#   godot --path . --log-file .godot/run-capture.log --script res://tests/capture_run_flow.gd

const FRAME := 1.0 / 60.0
var shots := {}


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	root.size = Vector2i(1600, 900)
	var director := RunDirector.new()
	director.seed_value = 12
	root.add_child(director)
	await create_timer(0.6).timeout
	await _grab("run_map")
	director.map_view._choose(director.run.route.nodes(0)[0])
	await process_frame
	director.area.hero.controlled = false
	await create_timer(4.0).timeout
	await _grab("run_field")
	var area := director.area
	if area.data.survive_time > 0.0:
		area.elapsed = area.data.survive_time
	else:
		area.kills = area.data.kill_target
	await create_timer(BattleArea.CLEAR_PAUSE + 0.6).timeout
	if director.choice.visible:
		await _grab("run_reward")
		director.choice._select(0)
	await create_timer(0.6).timeout
	await _grab("run_map_after")
	# An arena's first wave on its marks.
	var arena_choice: RouteMap.Waypoint = null
	for waypoint: RouteMap.Waypoint in director.run.route.nodes(1):
		if waypoint.area.kind == AreaData.Kind.ARENA:
			arena_choice = waypoint
	director.map_view._choose(arena_choice if arena_choice != null else director.run.route.nodes(1)[0])
	await process_frame
	director.area.hero.controlled = false
	await create_timer(1.8).timeout
	await _grab("run_wave")
	director.area.hero.health.hp = 1
	director.area.hero.receive(DamageInfo.make(1000.0, Vector2.RIGHT))
	await create_timer(RunDirector.FALL_PAUSE + 0.6).timeout
	await _grab("run_end")
	var result := OK
	for file_name: String in shots:
		result |= (shots[file_name] as Image).save_png("res://.godot/%s.png" % file_name)
	print("Captured the run flow: ", ", ".join(shots.keys()))
	quit(0 if result == OK else 1)


func _grab(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	shots[file_name] = root.get_texture().get_image()
