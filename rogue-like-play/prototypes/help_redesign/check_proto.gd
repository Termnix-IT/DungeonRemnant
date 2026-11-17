extends SceneTree

# Drives the three help prototypes through their main operations, headless:
# reaching every topic by the keys, by the pointer and by the wheel, and
# closing.
#   godot --headless --path . --script res://prototypes/help_redesign/check_proto.gd

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
	var main: Control = load("res://prototypes/help_redesign/proto_main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var files_before := DirAccess.get_files_at("user://")
	check(ProtoScreen.count() == 6 and ProtoScreen.title_of(0) == "探索の流れ" and ProtoScreen.points_of(2).size() == HubSettings.HELP[2][1].size() and ProtoScreen.key_rows().size() == HubSettings.HELP_KEYS.size(), "The help is the game's own: its six topics, their points and the keys")
	for index in main.screens.size():
		var name: String = ProtoMain.names()[index]
		var screen: ProtoScreen = main.screens[index]
		var on: StringName = &"ui_right" if index == 0 else &"ui_down"
		var back: StringName = &"ui_left" if index == 0 else &"ui_up"
		main.show_screen(index)
		check(screen.topic == 0 and not screen.closed, "%s: opens on the first topic" % name)
		await press(back)
		check(screen.topic == 0, "%s: stops at the first topic" % name)
		for step in ProtoScreen.count() - 1:
			await press(on)
		check(screen.topic == ProtoScreen.count() - 1, "%s: the keys reach every topic in turn" % name)
		await press(on)
		check(screen.topic == ProtoScreen.count() - 1, "%s: stops at the last topic" % name)
		screen._click([&"topic", HubSettings.TOPIC_CONTROLS])
		check(screen.topic == HubSettings.TOPIC_CONTROLS, "%s: the pointer opens a topic" % name)
		screen.pose(0)
		screen._wheel(1)
		if index == 1:
			# The scroll rolls freely: the wheel reaches the next topic in a few turns.
			for turn in 12:
				screen._wheel(1)
			check(screen.topic >= 1 and (screen as ProtoScroll)._rolled_to > 0.0, "%s: the wheel rolls the scroll on to the next topics" % name)
		else:
			check(screen.topic == 1, "%s: the wheel goes to the next topic" % name)
		await press(&"ui_cancel")
		check(screen.closed, "%s: Esc closes" % name)
	var scroll: ProtoScroll = main.screens[1]
	scroll.pose(ProtoScreen.count() - 1)
	check(scroll.rolled <= scroll._length and scroll._heads.size() == ProtoScreen.count() and scroll._heads[1] > scroll._heads[0], "The scroll knows where every topic's heading stands")
	check(DirAccess.get_files_at("user://") == files_before, "No prototype writes to the save folder")
	print("Prototype checks: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
