extends "res://tests/capture_preparation.gd"


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.state.gold = 300
	root.add_child(main)
	var hub = main.get_node("Hub")
	var shop: HubSell = hub.sell_page
	await settle()
	await enter(hub, hub.sell_button)
	await shot("cards_empty")
	check(shop.grid.cells.is_empty() and shop.grid.empty_label.visible and not shop.grid.empty_label.text.is_empty(), "An empty shop says why instead of an icon")
	await click(shop.buy_tab)
	shop.grid.cells[0].grab_focus()
	await key(KEY_RIGHT)
	check(shop.chosen_place() == 1 and shop.showcase.title.text == shop.rows[1].item.label(), "Native Right moves the focus to the next icon and shows it")
	await key(KEY_DOWN)
	check(shop.chosen_place() == GRID_ROW + 1, "Native Down moves a row down")
	await shot("cards_top")
	var last := shop.rows.size() - 1
	shop.grid.cells[last].grab_focus()
	await settle()
	check(shop.chosen_place() == last and shop.grid.scroll.get_v_scroll_bar().value >= 0, "The last icon can be reached")
	await shot("cards_last")
	var target := last - 1
	await click(shop.grid.cells[target])
	check(shop.chosen_place() == target and shop.showcase.title.text == shop.rows[target].item.label(), "A click on an icon chooses it")
	main.state.storage.add(ItemCatalog.POTION, 999)
	var long_item := preload("res://data/items/leather_armor.tres").duplicate() as ItemData
	long_item.display_name = "Z [b]長いアイテム名を省略表示するための防具・価格と重ならないことを確認[/b]"
	main.state.storage.add(long_item, 3)
	hub.refresh(main.state)
	await click(shop.sell_tab)
	var long_at := shop.rows.find_custom(func(row: Dictionary): return row.item == long_item)
	await click(shop.grid.cells[long_at])
	check(shop.showcase.title.text == long_item.label(), "The full name stays available as literal text")
	check(shop.rows[0].count == 999 and shop.rows[long_at].count == 3, "Icon quantity reflects grouped inventory")
	await shot("cards_long_name")
	root.size = Vector2i(1280, 720)
	await shot("cards_720")
	var before: int = main.state.gold
	await click(shop.sell_button)
	check(main.state.gold == before + long_item.sell_price and shop.rows[long_at].count == 2, "Icon selection sells the intended group")
	check(shop.chosen_place() == -1, "Refresh clears stale selection after sale")
	await key(KEY_ESCAPE)
	check(hub.page == "home", "Esc still returns home")
	main.free()
	print("Item icon render/input checks: ", "passed" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)


const GRID_ROW := HubSell.GRID_COLUMNS
