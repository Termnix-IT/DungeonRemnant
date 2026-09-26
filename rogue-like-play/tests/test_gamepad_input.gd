extends SceneTree

var failures := 0
var checks := 0
const LEATHER := preload("res://data/items/leather_armor.tres")


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


func run_tests() -> void:
	check(StickDirections.direction_action(Vector2(1, 0)) == &"move_e" and StickDirections.direction_action(Vector2(0, -1)) == &"move_n", "Stick cardinals map to moves")
	check(StickDirections.direction_action(Vector2(0.7, 0.7)) == &"move_se" and StickDirections.direction_action(Vector2(-0.7, -0.7)) == &"move_nw", "Stick diagonals map to diagonal moves")
	check(StickDirections.direction_action(Vector2(0.3, 0.2)).is_empty(), "Stick inside the deadzone moves nothing")
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.state.inventory.add(LEATHER)
	root.add_child(main)
	await process_frame
	for binding: Array in [["attack", JOY_BUTTON_A], ["cancel_attack", JOY_BUTTON_B], ["inventory", JOY_BUTTON_X], ["switch_weapon", JOY_BUTTON_Y], ["restart", JOY_BUTTON_START], ["move_n", JOY_BUTTON_DPAD_UP]]:
		check(InputMap.action_has_event(binding[0], pad(binding[1])), "%s is bound on the gamepad" % binding[0])
	main.start_run()
	await create_timer(SceneTransition.HOLD_TIME + SceneTransition.REVEAL_TIME + 0.1).timeout
	var run: Node2D = main.active_run
	var player: Node2D = run.turns.player
	root.push_input(pad(JOY_BUTTON_A))
	root.push_input(pad(JOY_BUTTON_A, false))
	check(player.aiming, "Gamepad A starts aiming an attack")
	root.push_input(pad(JOY_BUTTON_B))
	root.push_input(pad(JOY_BUTTON_B, false))
	check(not player.aiming, "Gamepad B cancels aiming")
	root.push_input(pad(JOY_BUTTON_X))
	root.push_input(pad(JOY_BUTTON_X, false))
	await process_frame
	var inventory = run.inventory_panel
	check(inventory.visible and inventory.list.has_focus(), "Gamepad X opens the inventory with the list focused")
	var armor_index := -1
	for index in player.inventory.entries.size():
		if player.inventory.entries[index].item == LEATHER:
			armor_index = index
	inventory.list.select(armor_index)
	inventory._select_item(armor_index)
	check(inventory.activate_selected() and player.equipment.slots[Equipment.Slot.ARMOR] == LEATHER, "Confirm equips armour into its slot")
	var main_before: ItemData = player.equipment.slots[Equipment.Slot.MAIN]
	root.push_input(pad(JOY_BUTTON_Y))
	root.push_input(pad(JOY_BUTTON_Y, false))
	check(player.equipment.slots[Equipment.Slot.MAIN] != main_before and inventory.visible, "Gamepad Y switches weapons inside the inventory")
	root.push_input(pad(JOY_BUTTON_B))
	root.push_input(pad(JOY_BUTTON_B, false))
	check(not inventory.visible, "Gamepad B closes the inventory")
	var choice = run.ability_choice
	var abilities := AbilitySystem.new()
	choice.present(abilities.offer(), abilities, 2, 1)
	check(not choice.buttons[0].has_focus(), "Ability cards take no focus the instant they open")
	await create_timer(choice.FOCUS_DELAY + 0.05).timeout
	check(choice.buttons[0].has_focus(), "The first ability card takes focus after a beat")
	choice.dismiss()
	run.request_abort()
	var enter := InputEventAction.new()
	enter.action = "ui_accept"
	enter.pressed = true
	run._input(enter)
	check(not run.result.is_empty() and not run.result_panel.confirming, "Enter confirms the abort without a mouse")
	main.free()
	print("Gamepad input: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
