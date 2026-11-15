extends SceneTree

# Drives the three settings prototypes through their main operations,
# headless: reaching a setting, changing a volume and a choice, taking an
# action, and going from group to group.
#   godot --headless --path . --script res://prototypes/settings_redesign/check_proto.gd

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


func tap(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func run() -> void:
	var main: Control = load("res://prototypes/settings_redesign/proto_main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var model: ProtoSettings = main.model
	var files_before := DirAccess.get_files_at("user://")
	var master := AudioServer.get_bus_volume_linear(0)
	# The settings keep the game's own rows.
	check(ProtoSettings.ORDER.size() == HubSettings.CAPTIONS.size() and ProtoSettings.groups() == 3, "Every row of the game's settings is there, in three groups")
	check(model.value(0) == "100%" and model.value(1) == "80%" and model.value(4) == "標準" and model.value(5) == "ウィンドウ" and model.value(9) == "日本語" and model.value(7) == "開く", "Each row tells its value as the game does")
	check(model.change(0, 1) == false and model.change(1, -1) and model.percent(1) == 75, "A volume moves in steps of 5% and stops at its ends")
	check(model.change(4, -1) and model.chosen(4) == 2 and not model.change(9, -1) and model.change(9, 1) and model.chosen(9) == 1, "A choice goes round, but for the language, which stops")
	model.reset()
	for index in main.screens.size():
		var name: String = ProtoMain.names()[index]
		var screen: ProtoScreen = main.screens[index]
		# A moves along the board with left and right and changes with up and
		# down; B and C move with up and down and change with left and right.
		var on: StringName = &"ui_right" if index == 0 else &"ui_down"
		var back: StringName = &"ui_left" if index == 0 else &"ui_up"
		var more: StringName = &"ui_up" if index == 0 else &"ui_right"
		var less: StringName = &"ui_down" if index == 0 else &"ui_left"
		main.show_screen(index)
		screen.pose(&"initial")
		check(screen.focus == 0, "%s: opens on the first setting" % name)
		await press(back)
		check(screen.focus == 0, "%s: stops at the first setting" % name)
		await press(on)
		check(screen.focus == 1, "%s: goes to the next setting" % name)
		await press(less)
		await press(less)
		check(model.percent(1) == 70 and screen.since(&"change") < 1.0, "%s: turns a volume down" % name)
		await press(more)
		check(model.percent(1) == 75, "%s: and up again" % name)
		await tap(KEY_E)
		check(screen.focus == 4, "%s: E goes to the next group's first setting" % name)
		await press(&"ui_accept")
		check(model.chosen(4) == 1, "%s: Enter on a choice takes the next" % name)
		await tap(KEY_E)
		check(screen.focus == 9, "%s: E again reaches the last group, on the language" % name)
		await press(on)
		await press(on)
		check(screen.focus == 7, "%s: the help's row is reached" % name)
		await press(&"ui_accept")
		check(model.acted == &"help", "%s: Enter on it opens the help" % name)
		await press(on)
		await press(on)
		check(screen.focus == 8, "%s: stops at the last setting" % name)
		screen._click([&"act", 8])
		check(model.acted == &"quit", "%s: the pointer takes an action" % name)
		screen._click([&"set", 2, 40])
		check(screen.focus == 2 and model.percent(2) == 40, "%s: the pointer sets a volume where it clicks" % name)
		await tap(KEY_Q)
		check(screen.focus == 9, "%s: Q from the first group goes round to the last" % name)
		model.reset()
	check(DirAccess.get_files_at("user://") == files_before and is_equal_approx(AudioServer.get_bus_volume_linear(0), master), "No prototype writes a file or turns a bus")
	print("Prototype checks: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
