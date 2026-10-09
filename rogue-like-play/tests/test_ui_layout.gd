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
	var action_rects := {}
	for page in ["prepare", "sell", "upgrade", "stages"]:
		hub.show_page(page)
		# Measure the resting layout, after the page has slid into place.
		await create_timer(UIMotion.WINDOW_TIME + 0.05).timeout
		await settle()
		var content: Control = hub.get_node("Content")
		for control: Control in [hub.prepare_page, hub.sell_page, hub.departure_page, hub.upgrade_page]:
			if control.visible:
				# The slabs run off the screen's edges by design; they still have
				# to stay on the screen.
				check(root.get_visible_rect().grow(1).encloses(control.get_global_rect()), "%s page fits Hub content" % page)
		# Every screen keeps its decision column at the same place, its primary
		# action at the foot of it (docs/MVP_SPEC.md, 個別画面のUI文法).
		var action: Button = {"prepare": hub.prepare_page.primary_button, "sell": hub.sell_page.sell_button, "upgrade": hub.purchase_button, "stages": hub.departure_page.confirm_button}[page]
		action_rects[page] = action.get_global_rect()
		check(root.get_visible_rect().encloses(action.get_global_rect()), "The %s action stays on the screen" % page)
		if page == "stages":
			var slots: Array[ItemCell] = hub.departure_page.slot_cells
			var stats_top: float = hub.departure_page.hero_stats.specs.get_global_rect().position.y
			check(slots.all(func(cell: ItemCell): return cell.get_global_rect().end.y <= stats_top) and stats_top < hub.departure_page.confirm_button.get_global_rect().position.y, "The departure reads stage, kit, stats, then the action")
			check(not hub.departure_page.stage_details.get_global_rect().intersects(hub.departure_page.review_button.get_global_rect()), "The stage text leaves the preparation link clear")
		if page == "prepare":
			var worn: HubPrepare = hub.prepare_page
			var screen: Rect2 = root.get_visible_rect()
			check(worn.slots.all(func(slot: Button): return screen.encloses(slot.get_global_rect())) and screen.encloses(worn.detail_note.get_global_rect()), "Every slot and the detail line stay on the screen")
			check(worn.slots.all(func(slot: Button): return slot.get_global_rect().end.y <= worn.storage.get_global_rect().position.y), "The slots stand above the two grids")
			check(worn.storage.get_global_rect().end.x <= worn.carried.get_global_rect().position.x and worn.carried.get_global_rect().end.x <= worn.detail_name.get_global_rect().position.x, "Warehouse, carried and the column read left to right")
			var divider: Rect2 = worn.divider.get_global_rect()
			check(divider.position.x >= worn.storage.get_global_rect().end.x and divider.end.x <= worn.carried.get_global_rect().position.x and divider.size.y > worn.storage.get_global_rect().size.y * 0.8, "A rule stands between the warehouse and the carried grids")
	var lefts := {}
	for rect: Rect2 in action_rects.values():
		lefts[roundi(rect.position.x)] = true
	check(lefts.size() == 1, "Every screen's primary action starts at the same place: %s" % [action_rects])
	hub.show_page("prepare")
	await create_timer(UIMotion.WINDOW_TIME + 0.05).timeout
	await settle()
	var warehouse: HubPrepare = hub.prepare_page
	var left := warehouse.storage.get_global_rect()
	var right := warehouse.carried.get_global_rect()
	# Whatever the column says, nothing round it moves.
	var steady := true
	for item in ItemCatalog.shop_items():
		warehouse._show_item(item, "倉庫")
		await settle()
		steady = steady and is_equal_approx(warehouse.carried.get_global_rect().position.x, right.position.x) and is_equal_approx(warehouse.storage.get_global_rect().end.x, left.end.x)
	check(steady, "A long name in the column never pushes the grids aside")
	hub.go_back()
	enter(hub, hub.start_button)
	hub.departure_page.confirm_button.pressed.emit()
	await settle()
	var run = main.active_run
	var hud = run.get_node("HUD")
	var panels: Array[Control] = []
	for path in ["TopRight", "BottomLeft", "Log"]:
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
