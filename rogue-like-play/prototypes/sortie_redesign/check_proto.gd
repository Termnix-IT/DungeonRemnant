extends SceneTree

# Drives the three departure prototypes through their main operations,
# headless: reaching a chapter, setting out, being refused a sealed one, and
# choosing a difficulty step within those open.
#   godot --headless --path . --script res://prototypes/sortie_redesign/check_proto.gd

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
	var main: Control = load("res://prototypes/sortie_redesign/proto_main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var model: ProtoExpedition = main.model
	var saves_before := DirAccess.get_files_at("user://")
	# The departure keeps the game's own rules.
	check(model.open(0) and model.open(1) and not model.open(2) and not model.open(3), "The departure tells which chapters are open")
	check(model.frontier() == 1 and model.steps_open() == 0, "It opens on the frontier, the steps closed before the ending")
	check(model.state(0) == "踏破 2回" and model.state(1) == "第3層まで" and model.state(2) == "封印中", "It tells how far each chapter has been taken")
	check(model.description(2).contains("第2章") and model.action(2) == "第3章は封印中" and model.action(1) == "第2章へ出撃する", "It tells what opens a sealed chapter and what the action is")
	check(model.boss_name(0) != ProtoExpedition.UNKNOWN and model.boss_name(1) == ProtoExpedition.UNKNOWN, "A boss is named once met")
	check(model.foes(1).size() == Chapters.foes(Chapters.ALL[1]).size() and model.gear().size() == 4, "It lists the foes and what she carries")
	for index in main.screens.size():
		var name: String = ProtoMain.names()[index]
		var screen: ProtoScreen = main.screens[index]
		var back: StringName = &"ui_up" if index == 0 else &"ui_left"
		var on: StringName = &"ui_down" if index == 0 else &"ui_right"
		main.show_screen(index)
		screen.pose(&"initial")
		check(screen.chosen == 1, "%s: opens on the frontier" % name)
		await press(back)
		check(screen.chosen == 0, "%s: goes back a chapter" % name)
		await press(back)
		check(screen.chosen == 0, "%s: stops at the first chapter" % name)
		await press(on)
		await press(&"ui_accept")
		check(model.departed == 1 and screen.since(&"depart") < 1.0, "%s: Enter sets out for the chosen chapter" % name)
		model.departed = -1
		await press(on)
		await press(&"ui_accept")
		check(screen.chosen == 2 and model.departed == -1 and screen.since(&"refuse") < 1.0, "%s: a sealed chapter is refused" % name)
		await tap(KEY_E)
		check(model.step == 0, "%s: no step before the steps open" % name)
		screen._click([&"chapter", 0])
		screen._click([&"go"])
		check(screen.chosen == 0 and model.departed == 0, "%s: the pointer chooses a chapter and sets out by the action" % name)
		screen.pose(&"steps")
		check(screen.chosen == 3 and model.steps_open() == 4 and model.step == 2, "%s: past the ending four steps are open" % name)
		await tap(KEY_E)
		await tap(KEY_E)
		await tap(KEY_E)
		check(model.step == 4 and not model.step_hint().is_empty(), "%s: E raises the step no higher than those open" % name)
		await tap(KEY_Q)
		check(model.step == 3 and model.action(3) == "第4章へ出撃する（段階3）", "%s: Q lowers it, and the action tells the step" % name)
		screen._click([&"step", 0])
		check(model.step == 0 and model.step_note() == "制約なし", "%s: the pointer chooses a step" % name)
	check(DirAccess.get_files_at("user://") == saves_before, "No prototype writes to the save folder")
	print("Prototype checks: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
