extends SceneTree

# Drives the three lobby prototypes through their main operations, headless:
# reaching every entry, opening one, and making her speak.
#   godot --headless --path . --script res://prototypes/lobby_redesign/check_proto.gd

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
	var main: Control = load("res://prototypes/lobby_redesign/proto_main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var model: ProtoLobby = main.model
	var files_before := DirAccess.get_files_at("user://")
	# The lobby keeps the game's own entries and what they tell.
	check(model.count() == 5 and model.name(0) == "出撃" and model.title(0) == "第2章　風哭きの樹海" and model.action(0) == "出撃先を選ぶ", "The departure is told by the chapter it opens on")
	check(model.facts(0) == [["道のり", "4層とボス"], ["記録", "第3層まで"]] and model.facts(2)[0] == ["装備中のスキル", "2 / 2"], "Each entry tells its two facts as the lobby does")
	check(model.ready() > 0 and model.waiting(1) and not model.waiting(0) and model.facts(1)[1][1] == "%d 件" % model.ready(), "The upgrades tell what the echo can buy")
	check(model.talk() == HubLobby.SPEECHES[1][0] and model.talk() == HubLobby.SPEECHES[1][1], "She speaks the lines for how far the journey has come, in turn")
	model.reset()
	# How each prototype reaches every entry from the departure, in the order
	# its own layout walks them: [key, the entry it lands on].
	var walks := [
		[[&"ui_left", 1], [&"ui_left", 2], [&"ui_left", 4], [&"ui_left", 4], [&"ui_right", 2], [&"ui_right", 1], [&"ui_right", 0], [&"ui_right", 3], [&"ui_right", 3]],
		[[&"ui_up", 0], [&"ui_down", 1], [&"ui_down", 2], [&"ui_down", 3], [&"ui_down", 4], [&"ui_down", 4]],
		[[&"ui_down", 1], [&"ui_left", 1], [&"ui_right", 2], [&"ui_right", 3], [&"ui_right", 4], [&"ui_right", 4], [&"ui_up", 0], [&"ui_down", 4]],
	]
	for index in main.screens.size():
		var name: String = ProtoMain.names()[index]
		var screen: ProtoScreen = main.screens[index]
		main.show_screen(index)
		screen.pose(&"initial")
		check(screen.chosen == 0, "%s: opens on the departure" % name)
		var reached := {0: true}
		for step: Array in walks[index]:
			await press(step[0])
			check(screen.chosen == step[1], "%s: %s lands on entry %d (was %d)" % [name, step[0], step[1], screen.chosen])
			reached[screen.chosen] = true
		check(reached.size() == model.count(), "%s: every entry is reached by the keys" % name)
		await press(&"ui_accept")
		check(model.entered == model.id(screen.chosen) and screen.since(&"enter") < 1.0, "%s: Enter opens the entry under the cursor" % name)
		screen._click([&"entry", 1])
		check(screen.chosen == 1 and model.entered != &"upgrade", "%s: the pointer chooses an entry" % name)
		screen._click([&"entry", 1])
		check(model.entered == &"upgrade", "%s: a click on the chosen entry opens it" % name)
		screen._click([&"enter", 3])
		check(screen.chosen == 3 and model.entered == &"codex", "%s: an entry's action opens it" % name)
		screen._click([&"hero"])
		check(not model.line.is_empty() and screen.since(&"talk") < 1.0, "%s: a click on her makes her speak" % name)
		model.reset()
	check(DirAccess.get_files_at("user://") == files_before, "No prototype writes to the save folder")
	print("Prototype checks: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
