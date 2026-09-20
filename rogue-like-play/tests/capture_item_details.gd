extends "res://tests/capture_preparation.gd"


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.state.gold = 300
	var armor := preload("res://data/items/leather_armor.tres").duplicate() as ItemData
	armor.display_name = "[b]長い名前[/b]のテスト装備・比較と折り返しの確認"
	main.state.storage.add(armor)
	main.state.storage.add(ItemCatalog.POTION, 2)
	root.add_child(main)
	var hub = main.get_node("Hub")
	await settle()
	await click(hub.sell_button)
	await click(hub.sell_page.item_list, Vector2(35, 25))
	check(hub.sell_page.details.get_parsed_text().contains(armor.display_name), "BBCode-like names remain literal")
	check(hub.sell_page.details.get_parsed_text().contains("単価 %d Gold" % armor.sell_price), "Price matches item data")
	await shot("details_shop")
	await key(KEY_ESCAPE)
	await click(hub.equipment_button)
	await click(hub.equipment_page.slots[Equipment.Slot.ARMOR])
	var comparison: ItemDetails = hub.equipment_page.comparison
	check(comparison.get_parsed_text().contains("DEF") and comparison.get_parsed_text().contains("+%d" % armor.defense_bonus), "Comparison preserves numeric bonus")
	comparison.grab_focus()
	await key(KEY_END)
	check(comparison.get_v_scroll_bar().value > 0, "Keyboard can scroll long details")
	await shot("details_equipment_scrolled")
	hub.equipment_page.select_slot(Equipment.Slot.ARMOR)
	check(comparison.get_v_scroll_bar().value == 0, "New comparison resets scroll")
	await shot("details_equipment")
	hub.open_warehouse()
	await settle()
	await click(hub.warehouse_panel.get_node("Panel/StorageList"), Vector2(35, 25))
	check(hub.warehouse_panel.get_node("Panel/Help").get_parsed_text().contains(armor.display_name), "Warehouse selection exposes description without hover")
	await shot("details_warehouse")
	for resolution in [Vector2i(1440, 900), Vector2i(1152, 720)]:
		root.size = resolution
		await settle()
		var list: ItemList = hub.warehouse_panel.get_node("Panel/StorageList")
		var motion := InputEventMouseMotion.new()
		motion.position = root.get_final_transform() * (list.get_global_rect().position + Vector2(35, 25))
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		await create_timer(1.0).timeout
		await settle()
		var tooltip := find_tooltip(root, ItemTooltipList.description(armor))
		check(tooltip != null, "Native tooltip appears at %s" % resolution)
		if tooltip != null:
			check(tooltip.get_line_count() > 2, "Long tooltip wraps")
			var popup := tooltip.get_window()
			check(root.get_visible_rect().encloses(Rect2(popup.position, popup.size)), "Tooltip remains inside viewport")
		await shot("details_tooltip_%d" % resolution.y)
		motion.position = Vector2(5, 5)
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		await settle()
	main.free()
	print("Item details render/input checks: ", "passed" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)


func find_tooltip(node: Node, content: String) -> Label:
	if node is Label and node.text == content and node.is_visible_in_tree():
		return node
	for child in node.get_children(true):
		var found := find_tooltip(child, content)
		if found != null:
			return found
	return null
