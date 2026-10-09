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
	await enter(hub, hub.sell_button)
	await click(hub.sell_page.grid.cells[0])
	check(hub.sell_page.showcase.title.text == armor.label(), "BBCode-like names remain literal")
	# The counter shows one total, not a unit-price formula.
	check(hub.sell_page.total_label.text == "+%d G" % (armor.sell_price * int(hub.sell_page.quantity.value)), "Price matches item data")
	await shot("details_shop")
	await key(KEY_ESCAPE)
	await enter(hub, hub.prepare_button)
	await settle()
	var stored: StockGrid = hub.prepare_page.storage
	var stored_at: int = stored.entries.find_custom(func(entry: Dictionary): return entry.item == armor)
	await click(stored.cells[stored_at])
	check(hub.prepare_page.detail_name.text == armor.label(), "The chosen gear is named in the column without hover")
	await shot("details_prepare")
	for resolution in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		root.size = resolution
		await settle()
		var cell: ItemCell = hub.prepare_page.storage.cells[stored_at]
		var motion := InputEventMouseMotion.new()
		motion.position = root.get_final_transform() * cell.get_global_rect().get_center()
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		await create_timer(1.0).timeout
		await settle()
		var tooltip := find_tooltip(root, ItemTooltipList.description(armor))
		check(tooltip != null, "Native tooltip appears at %s" % resolution)
		if tooltip != null:
			# Near the screen's edge a long name wraps; with room it keeps one
			# line. Either way the name and the description stay whole.
			check(tooltip.get_line_count() >= 2 and tooltip.text.contains(armor.label()), "Long tooltip keeps the whole name above the description")
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


# The full name must be readable in the detail area: the showcase title wraps
# without a limit, and details name the item when there is no showcase.
func shows_name(showcase: ItemShowcase, details: ItemDetails, item: ItemData) -> bool:
	return showcase.title.text == item.label() or details.get_parsed_text().contains(item.label())
