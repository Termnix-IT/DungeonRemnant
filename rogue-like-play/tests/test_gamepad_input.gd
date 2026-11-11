extends SceneTree

# Playing on a gamepad: the fight's actions are bound on it (project.godot's
# InputMap), the left stick moves and the right stick aims, a pad press
# swings and dashes, the base is walked with the D-pad and A / B, and the
# level-up cards and the menu answer the pad too.

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func pad(button: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func stick(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func run_tests() -> void:
	for binding: Array in [["strike", JOY_BUTTON_X], ["dash", JOY_BUTTON_A], ["dash", JOY_BUTTON_RIGHT_SHOULDER], ["skill_1", JOY_BUTTON_Y], ["pause", JOY_BUTTON_START], ["move_up", JOY_BUTTON_DPAD_UP]]:
		check(InputMap.action_has_event(binding[0], pad(binding[1])), "%s is bound on the gamepad" % binding[0])
	# The right trigger swings too, so the thumb can stay on the aiming stick.
	check(InputMap.action_has_event(&"strike", stick(JOY_AXIS_TRIGGER_RIGHT, 1.0)), "strike is bound to the right trigger as well")
	for binding: Array in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_down", JOY_AXIS_LEFT_Y, 1.0], ["aim_right", JOY_AXIS_RIGHT_X, 1.0], ["aim_up", JOY_AXIS_RIGHT_Y, -1.0]]:
		check(InputMap.action_has_event(binding[0], stick(binding[1], binding[2])), "%s is bound to its stick" % binding[0])

	var main: Node = load("res://game/main.tscn").instantiate()
	main.show_prologue = false
	main.saving_enabled = false
	main.run_seed = 3
	root.add_child(main)
	await process_frame
	var hub = main.get_node("Hub")
	for binding: Array in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B], ["ui_down", JOY_BUTTON_DPAD_DOWN]]:
		check(InputMap.action_has_event(binding[0], pad(binding[1])), "%s is bound on the gamepad for the base" % binding[0])
	# The base: down to the upgrades, A to enter, B to come back.
	hub.home_page.focus_selected()
	await process_frame
	root.push_input(pad(JOY_BUTTON_DPAD_DOWN))
	root.push_input(pad(JOY_BUTTON_DPAD_DOWN, false))
	await process_frame
	check(hub.home_page.selected_id() == &"upgrade", "The D-pad moves down the lobby's menu")
	root.push_input(pad(JOY_BUTTON_A))
	root.push_input(pad(JOY_BUTTON_A, false))
	await process_frame
	check(hub.page == "upgrade", "A enters the chosen page")
	root.push_input(pad(JOY_BUTTON_B))
	root.push_input(pad(JOY_BUTTON_B, false))
	await process_frame
	check(hub.page == "home", "B comes back to the lobby")
	# The departure: up to it, A for where to set out, A on the chapter to go.
	root.push_input(pad(JOY_BUTTON_DPAD_UP))
	root.push_input(pad(JOY_BUTTON_DPAD_UP, false))
	await process_frame
	root.push_input(pad(JOY_BUTTON_A))
	root.push_input(pad(JOY_BUTTON_A, false))
	await process_frame
	check(hub.page == "sortie" and hub.sortie_page.cards[0].has_focus(), "A on the departure opens where to set out, on its chapter")
	root.push_input(pad(JOY_BUTTON_A))
	root.push_input(pad(JOY_BUTTON_A, false))
	await process_frame
	check(main.active_run != null, "A on the chapter sets out")

	# A run: into the first area.
	await create_timer(SceneTransition.HOLD_TIME + SceneTransition.REVEAL_TIME + 0.1).timeout
	var run: RunDirector = main.active_run
	run.map_view._choose(run.run.route.nodes(0)[0])
	await process_frame
	var hero: Hero = run.area.hero
	Input.parse_input_event(stick(JOY_AXIS_LEFT_X, 1.0))
	Input.parse_input_event(stick(JOY_AXIS_RIGHT_Y, -1.0))
	await physics_frame
	var input := hero.read_input()
	check(input.move.x > 0.9, "The left stick moves")
	check(input.aim.is_equal_approx(Vector2.UP), "The right stick aims")
	# The right stick let go (synthetic small axis events do not reach the
	# action, so it is released directly).
	Input.action_release(&"aim_up")
	await physics_frame
	input = hero.read_input()
	check(input.aim.x > 0.9, "With the right stick at rest she aims where she moves")
	Input.parse_input_event(pad(JOY_BUTTON_X))
	for frame in 5:
		await physics_frame
		if hero.motor.swing_serial >= 1:
			break
	check(hero.motor.swing_serial >= 1, "X swings")
	Input.parse_input_event(pad(JOY_BUTTON_X, false))
	await create_timer(0.5).timeout
	Input.parse_input_event(pad(JOY_BUTTON_A))
	for frame in 5:
		await physics_frame
		if hero.motor.state == HeroMotor.State.DASH:
			break
	check(hero.motor.state == HeroMotor.State.DASH or hero.motor.since_dash < 0.3, "A dashes")
	Input.parse_input_event(pad(JOY_BUTTON_A, false))
	Input.parse_input_event(stick(JOY_AXIS_LEFT_X, 0.05))
	# The menu on Start, and back with B.
	root.push_input(pad(JOY_BUTTON_START))
	root.push_input(pad(JOY_BUTTON_START, false))
	await process_frame
	check(run.area.menu.visible and paused, "Start opens the menu and stops the fight")
	root.push_input(pad(JOY_BUTTON_B))
	root.push_input(pad(JOY_BUTTON_B, false))
	await process_frame
	check(not run.area.menu.visible and not paused, "B backs out of the menu and resumes the fight")
	# With the player away the fight waits: the window left, or the gamepad
	# she plays with pulled out, opens the menu.
	run.area.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(run.area.menu.visible and paused, "Leaving the window opens the menu and stops the fight")
	run.area.menu.back()
	await process_frame
	run.area._on_joy_connection(0, false)
	check(run.area.hero.using_pad() and run.area.menu.visible and paused, "Pulling the gamepad out opens the menu too")
	run.area.menu.back()
	await process_frame
	run.area.hero.controlled = false
	run.area.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not run.area.menu.visible and not paused, "A hero not under the player's control is never stopped")
	run.area.hero.controlled = true
	# The level-up cards: a direction focuses one, A takes it. A is also the
	# dash: held (or mashed) as the cards arm, it takes none.
	var choice_script := preload("res://ui/ability_choice.gd")
	Input.parse_input_event(pad(JOY_BUTTON_A))
	run.area._on_gems(run.run.progression.required_exp())
	# The lead-in, then the hand dealt and armed.
	await create_timer(BattleArea.LEAD_TIME + choice_script.arm_time(3) + 0.15, true, false, true).timeout
	root.push_input(pad(JOY_BUTTON_A, false))
	root.push_input(pad(JOY_BUTTON_A))
	await process_frame
	check(run.area.choice.armed and run.area.choice.resting() and run.area.choice.visible and run.run.build.owned().is_empty(), "A dash still mashed when the cards arm takes no card")
	Input.parse_input_event(pad(JOY_BUTTON_A, false))
	root.push_input(pad(JOY_BUTTON_A, false))
	await create_timer(choice_script.REST + 0.15, true, false, true).timeout
	check(not run.area.choice.resting(), "Once the fight's buttons have rested, they pick again")
	root.push_input(pad(JOY_BUTTON_A))
	root.push_input(pad(JOY_BUTTON_A, false))
	await process_frame
	check(run.run.build.owned().size() == 1 and not paused, "A takes the focused card and the fight goes on")
	main.free()
	await process_frame
	print("Gamepad input: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
