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
	hub.warehouse_button.pressed.emit()
	await settle()
	centered(hub.warehouse_panel.get_node("Panel"))
	hub.warehouse_panel.hide()
	hub.start_button.pressed.emit()
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
	centered(run.result_panel.get_node("Panel"))
	run.finish_run(false)
	await settle()
	centered(run.result_panel.get_node("Panel"))
	print("UI layout: ", "passed" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
