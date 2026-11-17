extends SceneTree

# Drives the three status prototypes through their main operations,
# headless: reaching a slot and an entry, setting one, swapping two,
# emptying a slot, being refused what is not learned, and her figures.
#   godot --headless --path . --script res://prototypes/status_redesign/check_proto.gd

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
	var main: Control = load("res://prototypes/status_redesign/proto_main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var model: ProtoStatus = main.model
	var files_before := DirAccess.get_files_at("user://")
	# The status keeps the shipped page's own rules.
	check(model.slot == 1 and model.slot_holds(1)[1] == "叩きつけ" and model.here(), "It opens on the first skill slot, on what it holds")
	var skills := model.entries(1)
	check(skills.size() == MetaProgress.SKILLS.size() + 1 and skills[0].id == HubStatus.CLEAR_ID and model.entries(0).size() == MetaProgress.WEAPONS.size(), "Each slot lists everything it can hold")
	check(skills[model.row_of(&"thunder_flash")].state == HubStatus.State.ELSEWHERE and skills[model.row_of(&"swallow_cut")].state == HubStatus.State.FREE and skills[model.row_of(&"blaze_ring")].state == HubStatus.State.UNKNOWN, "An entry tells whether it is held elsewhere, free, or not learned")
	check(model.stats().size() == 14 and model.stats()[0][0] == "最大HP", "Her figures are the shipped page's")
	for index in main.screens.size():
		var name: String = ProtoMain.names()[index]
		var screen: ProtoScreen = main.screens[index]
		main.show_screen(index)
		screen.pose(&"initial")
		await press(&"ui_down")
		check(model.row == model.row_of(&"slam") + 1, "%s: down moves the cursor along the slot's things" % name)
		screen.row_to(model.row_of(&"swallow_cut"))
		check(model.told().can and not (model.told().outcome as String).is_empty(), "%s: a skill held nowhere can be set, and the card says what that does" % name)
		await press(&"ui_accept")
		check(model.meta.loadout[0] == &"swallow_cut" and model.changed == [1] and screen.since(&"seal") < 1.0, "%s: Enter sets it in the open slot" % name)
		screen.row_to(model.row_of(&"thunder_flash"))
		await press(&"ui_accept")
		check(model.meta.loadout[0] == &"thunder_flash" and model.meta.loadout[1] == &"swallow_cut" and model.changed.size() == 2, "%s: a skill the other slot holds swaps places with this one" % name)
		screen.row_to(model.row_of(&"blaze_ring"))
		await press(&"ui_accept")
		check(model.meta.loadout[0] == &"thunder_flash" and screen.since(&"refuse") < 1.0, "%s: one not learned is refused" % name)
		await tap(KEY_X)
		check(model.meta.loadout[0] == &"" and model.slot_holds(1)[0] == "", "%s: X empties the slot" % name)
		await press(&"ui_left")
		check(model.slot == 0, "%s: left turns to the attack" % name)
		await tap(KEY_X)
		check(model.meta.weapon == &"sword" and screen.since(&"refuse") < 1.0, "%s: the attack cannot be emptied" % name)
		screen._click([&"row", 0, model.row_of(&"spear")])
		screen._click([&"row", 0, model.row_of(&"spear")])
		check(model.meta.weapon == &"spear", "%s: the pointer chooses an entry, and a second click sets it" % name)
		await press(&"ui_left")
		check(model.slot == 3, "%s: left from the attack comes round to the special move" % name)
		await tap(KEY_R)
		check(model.figures_open, "%s: R opens her figures" % name)
		await press(&"ui_accept")
		check(model.meta.special == &"echo_burst", "%s: nothing is set while her figures are open" % name)
		screen._click([&"slot", 2])
		check(model.slot == 2 and not model.figures_open, "%s: the pointer turns to a slot, closing her figures" % name)
		model.reset()
	check(DirAccess.get_files_at("user://") == files_before, "No prototype writes to the save folder")
	print("Prototype checks: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
