extends SceneTree

# Drives the three route prototypes through a pick, headless, and checks
# that none of them lets the route's rules slip: what is open is what
# RouteMap.open_after() says and nothing else, a pick is asked before it is
# gone ahead with, an area that is not open cannot be gone to, the boss
# stays in the dark until her way reaches it, and nothing is saved.
#   godot --headless --path . --script res://prototypes/route_redesign/check_proto.gd

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func run() -> void:
	var main: Control = load("res://prototypes/route_redesign/proto_main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var files_before := DirAccess.get_files_at("user://")
	var model: ProtoRoute = main.model
	# The route is the game's own, laid the same way every time.
	var again := RouteMap.generate(model.chapter, RunState.new(ProtoRoute.SEED).rng)
	var same := again.size() == model.route.size()
	for index in again.size():
		same = same and again.nodes(index).size() == model.route.nodes(index).size()
		for row in again.nodes(index).size():
			var ours: RouteMap.Waypoint = model.route.nodes(index)[row]
			var theirs: RouteMap.Waypoint = again.nodes(index)[row]
			same = same and ours.area == theirs.area and ours.reward == theirs.reward and ours.next.size() == theirs.next.size()
	check(same, "The route shown is RouteMap's own for the seed")
	for index in main.screens.size():
		var name: String = ProtoMain.names()[index]
		var screen: ProtoScreen = main.screens[index]
		var on: StringName = &"ui_down" if index == 0 else &"ui_right"
		main.show_screen(index)
		await process_frame
		var here: RouteMap.Waypoint = model.here()
		check(model.run.layer == 2 and model.open == model.route.open_after(here) and model.open.size() == 3, "%s: three ways are open, the ones the last area leads to" % name)
		check(model.cursor == 0 and not model.armed, "%s: opens on the first way, nothing asked" % name)
		await press(on)
		check(model.cursor == 1, "%s: the keys move to the next way" % name)
		await press(&"ui_accept")
		check(model.armed and model.run.layer == 2 and screen.departures == 0, "%s: Enter asks first and goes nowhere" % name)
		await press(&"ui_cancel")
		check(not model.armed and screen.menu_asked == 0, "%s: Esc takes the question back" % name)
		await press(&"ui_cancel")
		check(screen.menu_asked == 1, "%s: Esc with nothing asked calls the run's menu" % name)
		# An area that is not open is told of and never gone to.
		var far: RouteMap.Waypoint = model.route.nodes(3)[0]
		var shut: RouteMap.Waypoint = model.route.nodes(1)[0]
		for point: RouteMap.Waypoint in [far, shut]:
			screen._point([&"node", point])
			screen._click([&"node", point])
			screen._click([&"node", point])
			check(not screen.going and model.run.layer == 2 and screen.departures == 0, "%s: an area not open cannot be gone to" % name)
		check(model.tell(model.route.nodes(4)[0]).name == ProtoRoute.VEILED_NAME, "%s: the boss is not named before her way reaches it" % name)
		# The pointer picks: once to turn to it, once to ask, once to go.
		screen._point(null)
		screen._click([&"node", model.open[2]] if index == 0 else [&"open", 2])
		check(model.cursor == 2 and not model.armed, "%s: a click turns to a way" % name)
		screen.number(1)
		check(model.cursor == 1 and model.armed, "%s: a number key turns to its way and asks" % name)
		var picked := model.selected()
		await press(&"ui_accept")
		check(screen.going and screen.departures == 1, "%s: Enter again goes" % name)
		await press(&"ui_right")
		check(model.selected() == picked, "%s: nothing is taken on the way" % name)
		await create_timer(screen.go_time() + 0.3).timeout
		check(not screen.going and model.run.layer == 3 and model.run.taken.back() == picked and model.open == picked.next, "%s: the pick is taken and its ways open" % name)
		# On to the boss and round to a new run.
		for step in 2:
			screen.number(0)
			await press(&"ui_accept")
			await create_timer(screen.go_time() + 0.3).timeout
		check(model.run.layer == 0 and model.run.taken.is_empty() and model.open.size() == model.chapter.first_choices, "%s: past the boss the run starts over" % name)
	var chart: ProtoChart = main.screens[0]
	main.show_screen(0)
	await press(&"ui_right")
	check(chart.plan.size() == 2 and (chart.plan[0] as RouteMap.Waypoint).next.has(chart.plan[1]) and not model.armed, "The chart's course runs on only along a way that leads there")
	await press(&"ui_accept")
	check(model.armed and model.selected() == chart.plan[0], "The chart goes to the course's first leg, never past it")
	await press(&"ui_cancel")
	await press(&"ui_left")
	check(chart.plan.size() == 1, "The chart's course is drawn back a layer")
	check(DirAccess.get_files_at("user://") == files_before, "No prototype writes to the save folder")
	print("Prototype checks: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
