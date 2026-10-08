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
	await enter(hub, hub.upgrade_button)
	await shot("upgrades_locked")
	main.state.gold = 300
	hub.refresh(main.state)
	hub.show_page("upgrade")
	# Enter on the chosen node moves to the action; only the action spends.
	await key(KEY_ENTER)
	check(main.state.hp_upgrade_level == 0 and panel.upgrade_button.has_focus(), "Enter on a node goes to the action without buying")
	await key(KEY_ENTER)
	check(main.state.hp_upgrade_level == 1 and main.state.gold == 270, "Keyboard primary action buys HP")
	panel.upgrade_button.grab_focus()
	await key(KEY_ENTER)
	await key(KEY_ENTER)
	check(main.state.hp_upgrade_level == 3 and main.state.gold == 120 and panel.nodes[&"attack"].open, "Capping base HP by keys opens the branches")
	await click(panel.nodes[&"attack"])
	check(main.state.skill_rank(&"attack") == 0 and panel.selected_id == &"attack", "A click chooses a node without buying")
	await click(panel.upgrade_button)
	check(main.state.skill_rank(&"attack") == 1 and main.state.gold == 20, "Mouse selection and primary action buys attack")
	await shot("upgrades_branches")
	panel.root_button.grab_focus()
	await key(KEY_RIGHT)
	check(panel.selected_id == SkillCatalog.BRANCHES[0][0].id and panel.buttons[panel.selected_id].has_focus(), "Right from base HP moves to the first branch and chooses it")
	await key(KEY_DOWN)
	check(panel.selected_id == SkillCatalog.BRANCHES[1][0].id, "Down moves to the same tier of the next branch")
	await click(panel.nodes[&"defense"])
	check(panel.upgrade_button.text.contains("あと") and panel.upgrade_button.disabled, "A shortfall disables the action")
	await shot("upgrades_shortfall")
	await click(panel.entry_tab)
	await click(panel.stage_nodes[1])
	await shot("upgrades_stage_locked")
	main.state.record_boss(&"ancient_ruins", 50, true)
	main.state.record_boss(&"forest", 10, false)
	main.state.gold = 150
	hub.refresh(main.state)
	await settle()
	await click(panel.entry_nodes[1][0])
	await click(panel.upgrade_button)
	check(main.state.gold == 0 and main.state.can_start(panel.stages[1], 11), "Mouse unlocks selected dungeon floor")
	await shot("upgrades_entry_owned")
	root.size = Vector2i(1280, 720)
	await shot("upgrades_entry_720")
	await click(panel.growth_tab)
	await shot("upgrades_720")
	for button: Control in panel.buttons.values():
		check(panel.get_viewport().get_visible_rect().encloses(button.get_global_rect()), "Scaled node stays on the screen")
	await key(KEY_ESCAPE)
	check(hub.page == "home", "Esc returns home")
	main.free()
	print("Upgrade render/input checks: ", "passed" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
