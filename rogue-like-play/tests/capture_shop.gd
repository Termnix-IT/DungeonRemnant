extends "res://tests/capture_preparation.gd"


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.state.gold = 300
	main.state.storage.add(ItemCatalog.floor_item(1), 5)
	main.state.storage.add(ItemCatalog.POTION, 7)
	root.add_child(main)
	var hub = main.get_node("Hub")
	var shop: HubSell = hub.sell_page
	await settle()
	await click(hub.sell_button)
	await click(shop.item_list, Vector2(35, 25))
	await click(shop.quantity.get_line_edit())
	shop.quantity.get_line_edit().text = "2"
	await key(KEY_ENTER)
	await shot("shop_sell")
	await click(shop.sell_button)
	check(main.state.gold == 310 and shop.rows[0].count == 3, "Mouse and typed quantity sell two grouped armor")
	await click(shop.item_list, Vector2(35, 25))
	await click(shop.sell_all_button)
	check(main.state.gold == 325 and main.state.storage.entries.size() == 1, "Mouse sells remainder of selected group")
	await click(shop.buy_tab)
	await click(shop.item_list, Vector2(35, 25))
	shop.quantity.value = 3
	await shot("shop_buy")
	await click(shop.sell_button)
	check(main.state.gold == 265 and main.state.storage.entries[0].count == 10, "Mouse purchase updates stack and Gold")
	await key(KEY_ESCAPE)
	check(hub.page == "home", "Shop returns home with Esc")
	root.size = Vector2i(1152, 720)
	await settle()
	await click(hub.sell_button)
	await click(shop.sell_tab)
	await click(shop.item_list, Vector2(28, 20))
	await shot("shop_720")
	main.free()
	print("Shop render/input checks: ", "passed" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
