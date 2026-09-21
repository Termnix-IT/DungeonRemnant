extends "res://tests/capture_preparation.gd"


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	root.add_child(main)
	var hub = main.get_node("Hub")
	var panel: SkillTreePanel = hub.upgrade_page
	await settle()
	await click(hub.upgrade_button)
	await shot("upgrades_locked")
	main.state.gold = 300
	hub.refresh(main.state)
	hub.show_page("upgrade")
	await key(KEY_ENTER)
	check(main.state.hp_upgrade_level == 0, "Keyboard selecting an ability does not purchase")
	panel.upgrade_button.grab_focus()
	await key(KEY_ENTER)
	check(main.state.hp_upgrade_level == 1 and main.state.gold == 270, "Keyboard primary action buys HP")
	await click(panel.nodes[&"attack"])
	await click(panel.upgrade_button)
	check(main.state.skill_rank(&"attack") == 1 and main.state.gold == 170, "Mouse selection and primary action buys attack")
	await shot("upgrades_branches")
	await click(panel.nodes[&"defense"])
	panel.upgrade_button.grab_focus()
	await key(KEY_ENTER)
	check(main.state.skill_rank(&"defense") == 1 and main.state.gold == 20, "Keyboard primary action buys newly unlocked defense")
	check(panel.nodes[&"defense"].has_focus(), "Disabled action returns focus to selected ability")
	await shot("upgrades_shortfall")
	await click(panel.tabs[1])
	panel.stage_choice.select(1)
	panel.stage_choice.item_selected.emit(1)
	await shot("upgrades_stage_locked")
	main.state.record_boss(&"ancient_ruins", 50, true)
	main.state.record_boss(&"forest", 10, false)
	main.state.gold = 150
	hub.refresh(main.state)
	await settle()
	await click(panel.entry_buttons[0])
	check(main.state.gold == 0 and main.state.can_start(panel.stages[1], 11), "Mouse unlocks selected dungeon floor")
	await shot("upgrades_entry_owned")
	root.size = Vector2i(1152, 720)
	await shot("upgrades_entry_720")
	await click(panel.tabs[0])
	await shot("upgrades_720")
	for row: Dictionary in panel.skill_rows.values():
		check(panel.get_global_rect().grow(1).encloses(row.control.get_global_rect()), "Scaled ability stays inside panel")
	await key(KEY_ESCAPE)
	check(hub.page == "home", "Esc returns home")
	main.free()
	print("Upgrade render/input checks: ", "passed" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
