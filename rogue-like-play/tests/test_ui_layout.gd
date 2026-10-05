extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func centered(control: Control) -> void:
	var viewport := root.get_visible_rect()
	var rect := control.get_global_rect()
	check(rect.get_center().distance_to(viewport.get_center()) < 1.0, "%s stays centered" % control.name)
	check(viewport.encloses(rect), "%s fits the viewport" % control.name)


func settle() -> void:
	for frame in 3:
		await process_frame


func run_tests() -> void:
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	root.add_child(main)
	await settle()
	var hub = main.get_node("Hub")
	centered(hub.get_node("Content"))
	for page in ["equipment", "sell", "upgrade", "stages", "confirm"]:
		hub.show_page(page)
		# Measure the resting layout, after the page has slid into place.
		await create_timer(UIMotion.WINDOW_TIME + 0.05).timeout
		await settle()
		var content: Control = hub.get_node("Content")
		for control: Control in [hub.equipment_page, hub.sell_page, hub.departure_page, hub.upgrade_page]:
			if control.visible:
				# The shop's slab runs off the screen's left edge by design; it
				# still has to stay on the screen.
				var bounds: Rect2 = root.get_visible_rect() if control == hub.sell_page else content.get_global_rect()
				check(bounds.grow(1).encloses(control.get_global_rect()), "%s page fits Hub content" % page)
		if page == "confirm":
			check(not hub.departure_page.equipment_label.get_global_rect().intersects(hub.departure_page.review_button.get_global_rect()), "Confirmation equipment does not overlap review button")
			var rows: Control = hub.departure_page.equipment_rows
			check(rows.size.y >= rows.get_theme_constant(&"row_height") * 5 and rows.get_global_rect().end.y <= hub.departure_page.equipment_label.get_global_rect().position.y, "Confirmation equipment rows end before the stats")
		if page == "equipment":
			check(not hub.equipment_page.comparison.get_global_rect().intersects(hub.equipment_page.equip_button.get_global_rect()), "Equipment comparison leaves action visible")
			check(not hub.equipment_page.stat_sheet.get_global_rect().intersects(hub.equipment_page.swap_button.get_global_rect()), "Equipment stats leave swap visible")
	hub.show_page("home")
	enter(hub, hub.warehouse_button)
	await settle()
	centered(hub.warehouse_panel.get_node("Panel"))
	hub.warehouse_panel.close()
	enter(hub, hub.start_button)
	hub.departure_page.next_button.pressed.emit()
	hub.departure_page.confirm_button.pressed.emit()
	await settle()
	var run = main.active_run
	var hud = run.get_node("HUD")
	var panels: Array[Control] = []
	for path in ["TopLeft", "TopRight", "BottomLeft", "Log", "BottomRight"]:
		var panel: Control = hud.get_node(path)
		var safe_rect := root.get_visible_rect().grow(-15.0)
		check(safe_rect.encloses(panel.get_global_rect()), "%s keeps edge padding" % path)
		for other in panels:
			check(not panel.get_global_rect().intersects(other.get_global_rect()), "HUD panels do not overlap")
		panels.append(panel)
	run.inventory_panel.present(run.turns.player)
	await settle()
	centered(run.inventory_panel.get_node("Panel"))
	run.inventory_panel.hide()
	run.ability_choice.show()
	await settle()
	centered(run.ability_choice.get_node("Panel"))
	run.ability_choice.hide()
	run.result_panel.confirm_abort()
	await settle()
	centered(run.result_panel.presentation_panel)
	run.finish_run(false)
	await settle()
	centered(run.result_panel.presentation_panel)
	print("UI layout: ", "passed" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)


# A lobby entry is chosen by its first press and entered by the next.
func enter(hub: Node, button: Button) -> void:
	if hub.home_page.buttons[hub.home_page.selected] != button:
		button.pressed.emit()
	button.pressed.emit()
