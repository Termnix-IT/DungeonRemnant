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
	await click(hub.sell_button)
	await shot("cards_empty")
	check(shop.item_list.item_count == 1 and shop.item_list.is_item_disabled(0), "Empty list retains disabled placeholder")
	await click(shop.buy_tab)
	shop.item_list.grab_focus()
	await key(KEY_DOWN)
	check(shop.item_list.get_selected_items() == PackedInt32Array([0]), "Native Down selects first card")
	await key(KEY_DOWN)
	check(shop.item_list.get_selected_items() == PackedInt32Array([1]), "Native arrow selects next card")
	check(shop.details.get_parsed_text().contains(shop.rows[1].item.display_name), "Keyboard selection updates correct details")
	await shot("cards_top")
	for page in ceili(shop.rows.size() / 4.0):
		await key(KEY_PAGEDOWN)
	var last := shop.rows.size() - 1
	check(shop.item_list.get_selected_items() == PackedInt32Array([last]) and shop.item_list.get_v_scroll_bar().value > 0, "Native PageDown scrolls to last card")
	await shot("cards_magic")
	var target := last - 1
	var rect := shop.item_list.card_rect(target)
	await click(shop.item_list, rect.position + Vector2(30, rect.size.y / 2))
	check(shop.item_list.get_selected_items() == PackedInt32Array([target]), "Scrolled glyph hit selects correct item")
	check(shop.details.get_parsed_text().contains(shop.rows[target].item.display_name), "Scrolled item metadata matches details")
	var index := 12
	shop.item_list.select(index)
	shop.item_list.item_selected.emit(index)
	shop.item_list.ensure_current_is_visible()
	await shot("cards_talismans")
	main.state.storage.add(ItemCatalog.POTION, 999)
	var long_item := preload("res://data/items/leather_armor.tres").duplicate() as ItemData
	long_item.display_name = "Z [b]長いアイテム名を省略表示するための防具・価格と重ならないことを確認[/b]"
	main.state.storage.add(long_item, 3)
	hub.refresh(main.state)
	await click(shop.sell_tab)
	shop.item_list.grab_focus()
	var search := InputEventKey.new()
	search.keycode = KEY_Z
	search.unicode = 90
	search.pressed = true
	Input.parse_input_event(search)
	var release := search.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	await settle()
	check(shop.item_list.get_selected_items() == PackedInt32Array([1]), "Native incremental search still uses full card name")
	check(shop.details.get_parsed_text().contains(long_item.display_name), "Full name remains available in details as literal text")
	check(shop.item_list.get_item_metadata(0).count == 999 and shop.item_list.get_item_metadata(1).count == 3, "Card quantity reflects grouped inventory")
	await shot("cards_long_name")
	root.size = Vector2i(1152, 720)
	await shot("cards_720")
	var before: int = main.state.gold
	await click(shop.sell_button)
	check(main.state.gold == before + long_item.sell_price and shop.rows[1].count == 2, "Card selection sells the intended group")
	check(shop.item_list.get_selected_items().is_empty(), "Refresh clears stale selection after sale")
	await key(KEY_ESCAPE)
	check(hub.page == "home", "Esc still returns home")
	main.free()
	print("Item card render/input checks: ", "passed" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
