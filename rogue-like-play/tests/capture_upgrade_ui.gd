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
	check(main.state.hp_upgrade_level == 1 and main.state.gold == 270, "Initial focus supports keyboard HP purchase")
	await key(KEY_DOWN)
	check(panel.nodes[&"attack"].has_focus(), "Down skips locked vitality and reaches attack")
	await key(KEY_ENTER)
	check(main.state.skill_rank(&"attack") == 1 and main.state.gold == 170, "Keyboard buys attack and unlocks defense")
	await shot("upgrades_branches")
	await click(panel.nodes[&"defense"])
	check(main.state.skill_rank(&"defense") == 1 and main.state.gold == 20, "Mouse purchases newly unlocked defense")
	check(panel.stage_choice.has_focus(), "Purchase disabling its button moves focus to a non-purchasing control")
	await shot("upgrades_shortfall")
	await click(panel.stage_choice)
	# Mouse opening leaves no focused menu item: down once per item.
	await key(KEY_DOWN)
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	check(panel.stage_choice.selected == 1, "Stage selector responds to keyboard")
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
	await shot("upgrades_720")
	for row: Dictionary in panel.skill_rows.values() + panel.entry_rows:
		check(panel.get_global_rect().grow(1).encloses(row.control.get_global_rect()), "Scaled row stays inside panel")
		for field in ["title", "effect", "condition"]:
			check(row[field].get_line_count() <= 1, "Compact row does not unexpectedly wrap: " + row[field].text)
	await key(KEY_ESCAPE)
	check(hub.page == "home", "Esc returns home")
	main.free()
	print("Upgrade render/input checks: ", "passed" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
