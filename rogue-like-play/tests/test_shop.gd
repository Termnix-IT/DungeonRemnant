extends SceneTree

var failures := 0
var checks := 0
const ARMOR := preload("res://data/items/leather_armor.tres")


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func run_tests() -> void:
	var main := preload("res://game/main.tscn").instantiate()
	main.run_seed = 47
	main.saving_enabled = false
	root.add_child(main)
	var hub = main.get_node("Hub")
	var shop: HubSell = hub.sell_page
	main.state.storage.add(ARMOR, 5)
	main.state.storage.add(ItemCatalog.POTION, 7)
	main.state.inventory.add(ARMOR, 2)
	main.state.equipment.slots[2] = ARMOR
	enter(hub, hub.sell_button)
	check(hub.title_label.text == "ショップ", "Home opens shop")
	check(shop.rows.size() == 2 and shop.rows[0].count == 5, "Five separate armor entries become one shop row")
	check(shop.item_list.get_item_text(0).contains("×5"), "Grouped row shows aggregate quantity")
	shop.item_list.select(0)
	shop.item_list.item_selected.emit(0)
	check(shop.quantity.max_value == 5, "Quantity upper bound uses whole item group")
	shop.quantity.value = 3
	shop.sell_button.pressed.emit()
	check(main.state.gold == 15 and main.state.storage.entries.size() == 3, "Partial grouped sale removes exactly three equipment entries")
	check(shop.rows[0].count == 2, "Grouped count refreshes after partial sale")
	shop.item_list.select(0)
	shop.item_list.item_selected.emit(0)
	shop.sell_all_button.pressed.emit()
	check(main.state.gold == 25 and main.state.storage.entries.size() == 1 and main.state.storage.entries[0].count == 7, "Sell all only sells selected item type")
	check(main.state.inventory.entries.size() == 2 and main.state.equipment.slots[2] == ARMOR, "Other source and equipped armor are preserved")
	check(shop.sell_button.disabled and shop.sell_all_button.disabled, "Both sale actions require new selection after mutation")
	shop.source_choice.select(1)
	shop.source_choice.item_selected.emit(1)
	check(shop.rows.size() == 1 and shop.rows[0].count == 2, "Carried equipment also groups")
	shop.item_list.select(0)
	shop.item_list.item_selected.emit(0)
	shop.sell_all_button.pressed.emit()
	check(main.state.inventory.entries.is_empty() and main.state.gold == 35, "Sell all works on carried source")
	main.state.gold = 100
	shop.buy_tab.pressed.emit()
	check(shop.buying and not shop.sell_all_button.visible and shop.rows.size() == ItemCatalog.shop_items().size(), "Purchase tab exposes catalog and hides sell-all")
	shop.item_list.select(0)
	shop.item_list.item_selected.emit(0)
	var selector_size := shop.quantity.get_combined_minimum_size()
	shop.quantity.plus.pressed.emit()
	check(shop.quantity.value == 2 and not shop.quantity.minus.disabled, "Plus steps the quantity")
	shop.quantity.value = 999
	check(shop.quantity.value == shop.quantity.max_value and shop.quantity.plus.disabled, "Quantity clamps at the purchase limit")
	# The arrows stay under the pointer while the limit disables them.
	check(shop.quantity.get_combined_minimum_size() == selector_size, "Quantity selector keeps its size at the limit")
	check(shop.quantity_label.text.contains("最大 %d" % int(shop.quantity.max_value)), "Quantity caption states the limit")
	shop.quantity.value = 3
	shop.sell_button.pressed.emit()
	check(main.state.gold == 40 and main.state.inventory.entries[0].count == 3, "Purchase charges price times quantity into selected destination")
	check(shop.item_list.get_selected_items() == PackedInt32Array([0]) and shop.showcase.visual.item == shop.rows[0].item, "Purchase keeps its item selected for another purchase")
	await create_timer(UIMotion.TRAVEL_TIME + 0.15).timeout
	check(shop.get_children().filter(func(child: Node): return child is Control and child.top_level).is_empty(), "Travelling glyph frees itself after arriving")
	for index in shop.rows.size():
		if shop.rows[index].item.id == ARMOR.id:
			shop.item_list.select(index)
			shop.item_list.item_selected.emit(index)
	# She already wears this armor, so the slot is named and nothing changes.
	check(shop.swap_label.visible and shop.swap_label.text == "防具と入れ替え（今：革の防具）" and shop.hero_specs.rows.all(func(row: Array): return row[1] == row[2]), "Equipment in the shop names its slot and what she wears there")
	shop.set_buying(false)
	shop.item_list.select(0)
	shop.item_list.item_selected.emit(0)
	check(not shop.swap_label.visible and shop.hero_specs.rows.all(func(row: Array): return row[1] == row[2]), "Selling shows her stats as they are")
	# Gear has no fixed ceiling, so her stats carry no bar to misread.
	check(not shop.hero_specs.bars, "Her stats are numbers without bars")
	shop.set_buying(true)
	var before := SaveCodec.encode(main.state)
	check(not main.buy_item(false, ItemCatalog.POTION.id, 3) and before == SaveCodec.encode(main.state), "Insufficient Gold changes nothing")
	check(not main.buy_item(false, &"missing", 1) and not main.buy_item(false, ItemCatalog.POTION.id, 0), "Unknown item and zero quantity rejected")
	main.state.gold = 1000
	main.state.inventory.add(ARMOR, 39)
	before = SaveCodec.encode(main.state)
	check(not main.buy_item(false, ARMOR.id, 1) and before == SaveCodec.encode(main.state), "Full inventory blocks new equipment without charging")
	check(main.buy_item(false, ItemCatalog.POTION.id, 2), "Existing consumable stack can grow even when slots are full")
	before = SaveCodec.encode(main.state)
	check(not main.buy_item(false, ItemCatalog.POTION.id, 46) and before == SaveCodec.encode(main.state), "Partial fit is rejected atomically")
	main.state.storage.add(ARMOR, 3)
	main.saving_enabled = true
	main.save_store.path = "res://.godot/shop-missing-%s/save.json" % Time.get_ticks_usec()
	before = SaveCodec.encode(main.state)
	check(not main.sell_item(true, 1, 3) and before == SaveCodec.encode(main.state), "Failed save restores all grouped entries and Gold")
	check(not main.buy_item(true, ARMOR.id, 2) and before == SaveCodec.encode(main.state), "Failed save restores purchase and Gold")
	main.save_store.path = "res://.godot/shop-%s.json" % Time.get_ticks_usec()
	check(main.buy_item(true, ARMOR.id, 2), "Purchase can persist")
	check(SaveCodec.encode(main.save_store.load_state()) == SaveCodec.encode(main.state), "Purchased goods survive save reload")
	check(main.sell_item(true, 1, 5), "Whole group sale can persist")
	check(SaveCodec.encode(main.save_store.load_state()) == SaveCodec.encode(main.state), "Grouped sale survives reload")
	main.saving_enabled = false
	main.start_run()
	check(not main.buy_item(true, ARMOR.id, 1), "Purchases blocked during Run")
	main.free()
	print("Shop tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


# A lobby entry is chosen by its first press and entered by the next.
func enter(hub: Node, button: Button) -> void:
	if hub.home_page.buttons[hub.home_page.selected] != button:
		button.pressed.emit()
	button.pressed.emit()
