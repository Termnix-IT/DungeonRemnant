extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func inspect_styles(node: Node) -> void:
	if node is Control:
		var overrides: Array[String] = []
		for property in node.get_property_list():
			if str(property.name).begins_with("theme_override_") and node.get(property.name) != null:
				overrides.append(property.name)
		check(overrides.is_empty(), "%s inherits theme without overrides: %s" % [node.name, overrides])
	for child in node.get_children():
		inspect_styles(child)


func run_tests() -> void:
	var theme := preload("res://ui/theme/dungeon_theme.tres")
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.state.gold = 100
	root.add_child(main)
	var hub = main.get_node("Hub")
	var shop: HubSell = hub.sell_page
	hub.show_page("sell")
	shop.set_buying(true)
	for frame in 3:
		await process_frame
	check(shop.sell_button.disabled, "Transaction is disabled until selection")
	shop.item_list.select(0)
	shop.item_list.item_selected.emit(0)
	check(not shop.sell_button.disabled, "Valid purchase enables transaction")
	for control: Control in [shop.item_list, shop.details, shop.quantity, shop.total_label, shop.sell_button, shop.source_choice]:
		check(shop.get_global_rect().grow(1).encloses(control.get_global_rect()), "%s fits shop" % control.get_class())
	check(shop.source_label.size.y <= shop.source_choice.size.y, "Source caption stays on one row")
	check(not shop.total_label.get_global_rect().intersects(shop.sell_button.get_global_rect()), "Quote leaves action visible")
	inspect_styles(hub.get_node("Content"))
	inspect_styles(hub.warehouse_panel)
	var normal := shop.sell_button.get_theme_stylebox("normal")
	for state in ["hover", "pressed", "disabled", "focus"]:
		check(shop.sell_button.get_theme_stylebox(state) != normal, "Gold button has distinct " + state)
	var focus := shop.sell_button.get_theme_stylebox("focus") as StyleBoxFlat
	check(not focus.draw_center and focus.border_width_left >= 2, "Focus overlays a visible outline without hiding state")
	check(shop.sell_button.get_theme_color("font_disabled_color") != shop.sell_button.get_theme_color("font_color"), "Disabled text is distinct")
	check(shop.sell_button.get_theme_stylebox("normal") == hub.purchase_button.get_theme_stylebox("normal"), "Shop and upgrade share Gold style resource")
	check(shop.sell_button.get_theme_stylebox("focus") == hub.back_button.get_theme_stylebox("focus"), "Buttons share focus resource")
	var original := theme.get_color("font_color", "GoldLabel")
	var probe := Color(0.7, 0.8, 0.9)
	theme.set_color("font_color", "GoldLabel", probe)
	check(shop.total_label.get_theme_color("font_color") == probe and hub.gold_label.get_theme_color("font_color") == probe and hub.warehouse_panel.get_node("Panel/Gold").get_theme_color("font_color") == probe, "One theme edit reaches shop, home and warehouse")
	theme.set_color("font_color", "GoldLabel", original)
	main.free()
	print("UI theme: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
