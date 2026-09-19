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
	await shot("shop_disabled")
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
	check_shop_layout(shop)
	await capture_button_states(shop.sell_button)
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
	check_shop_layout(shop)
	main.free()
	print("Shop render/input checks: ", "passed" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)


func check_shop_layout(shop: HubSell) -> void:
	var bounds := shop.get_global_rect().grow(1)
	for control: Control in [shop.item_list, shop.source_choice, shop.quantity, shop.total_label, shop.sell_button, shop.sell_all_button, shop.help_label]:
		if control.is_visible_in_tree():
			check(bounds.encloses(control.get_global_rect()), "%s fits shop at %s" % [control.get_class(), root.size])
	check(not shop.sell_button.get_global_rect().intersects(shop.total_label.get_global_rect()), "Quote and action do not overlap")


func capture_button_states(button: Button) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_final_transform() * button.get_global_rect().get_center()
	Input.parse_input_event(motion)
	await settle()
	check(button.is_hovered(), "Purchase hover responds to pointer")
	await shot("shop_hover")
	button.grab_focus()
	check(button.has_focus(), "Purchase accepts keyboard focus")
	await shot("shop_focus")
	var press := InputEventMouseButton.new()
	press.position = motion.position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await settle()
	check(button.get_draw_mode() == BaseButton.DRAW_HOVER_PRESSED or button.get_draw_mode() == BaseButton.DRAW_PRESSED, "Purchase renders pressed state")
	await shot("shop_pressed")
	# Release outside so this appearance check cannot perform a transaction.
	motion.position = Vector2(5, 5)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	press.position = motion.position
	press.pressed = false
	Input.parse_input_event(press)
	await settle()
