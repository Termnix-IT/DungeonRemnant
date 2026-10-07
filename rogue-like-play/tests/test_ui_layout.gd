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
	for page in ["equipment", "sell", "warehouse", "upgrade", "stages", "confirm"]:
		hub.show_page(page)
		# Measure the resting layout, after the page has slid into place.
		await create_timer(UIMotion.WINDOW_TIME + 0.05).timeout
		await settle()
		var content: Control = hub.get_node("Content")
		for control: Control in [hub.equipment_page, hub.sell_page, hub.warehouse_page, hub.departure_page, hub.upgrade_page]:
			if control.visible:
				# The shop's slab runs off the screen's left edge by design; it
				# still has to stay on the screen.
				var bounds: Rect2 = root.get_visible_rect() if control in [hub.sell_page, hub.equipment_page, hub.warehouse_page, hub.upgrade_page, hub.departure_page] else content.get_global_rect()
				check(bounds.grow(1).encloses(control.get_global_rect()), "%s page fits Hub content" % page)
		if page == "confirm":
			var rows: Control = hub.departure_page.equipment_rows
			check(rows.size.y >= rows.get_theme_constant(&"row_height") * 5 and rows.get_global_rect().end.y <= hub.departure_page.inventory_list.get_global_rect().position.y, "Confirmation equipment rows end before the carried goods")
			check(not hub.departure_page.inventory_list.get_global_rect().intersects(hub.departure_page.review_button.get_global_rect()), "Carried goods leave the review action clear")
			check(root.get_visible_rect().encloses(hub.departure_page.confirm_button.get_global_rect()), "The sortie action stays on the screen")
		if page == "equipment":
			var worn: HubEquipment = hub.equipment_page
			var screen: Rect2 = root.get_visible_rect()
			check(worn.slots.all(func(slot: Button): return screen.encloses(slot.get_global_rect())) and screen.encloses(worn.detail_note.get_global_rect()), "Every slot and the detail line stay on the screen")
			check(not worn._gear_scroll.get_global_rect().intersects(worn.detail_name.get_global_rect()), "The gear icons leave the plaque clear")
			check(worn.grid.get_global_rect().end.x <= worn.slots[0].get_global_rect().position.x and worn.slots[0].get_global_rect().end.x < worn.detail_name.get_global_rect().get_center().x, "The slots stand right beside the gear, the plaque out in the hall")
	hub.show_page("home")
	enter(hub, hub.warehouse_button)
	await create_timer(UIMotion.WINDOW_TIME + 0.05).timeout
	await settle()
	var warehouse: HubWarehouse = hub.warehouse_page
	# The two stocks mirror each other about the screen's centre.
	var middle := root.get_visible_rect().get_center().x
	var left := warehouse.carried.get_global_rect()
	var right := warehouse.storage.get_global_rect()
	check(absf((left.position.x - middle) + (right.end.x - middle)) < 2.0, "Warehouse stocks mirror about the centre")
	var plaque := warehouse.detail_name.get_global_rect().merge(warehouse.detail_note.get_global_rect())
	check(root.get_visible_rect().encloses(plaque) and left.end.x <= plaque.position.x and plaque.end.x <= right.position.x, "The plaque stands in the hall between the two slabs")
	# Whatever the plaque says, nothing round it moves.
	var steady := true
	for item in ItemCatalog.shop_items():
		warehouse._show_item(item)
		await settle()
		steady = steady and is_equal_approx(warehouse.storage.get_global_rect().position.x, right.position.x) and is_equal_approx(warehouse.carried.get_global_rect().end.x, left.end.x)
	check(steady, "A long plaque line never pushes the slabs aside")
	hub.go_back()
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


# One press on a lobby entry enters it.
func enter(_hub: Node, button: Button) -> void:
	button.pressed.emit()
