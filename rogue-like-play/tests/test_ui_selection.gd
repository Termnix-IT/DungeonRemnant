extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func select(list: ItemList, index: int) -> void:
	list.select(index)
	list.item_selected.emit(index)


func press_enter() -> void:
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	var release := enter.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	for frame in 2:
		await process_frame


# Enter on a chosen row goes to the screen's primary action without acting;
# on an equipment slot it goes on to the slot's candidates.
func check_enter_to_action(hub, main) -> void:
	main.state.gold = 300
	hub.refresh(main.state)
	hub.show_page("sell")
	var shop: HubSell = hub.sell_page
	shop.set_buying(true)
	shop.item_list.grab_focus()
	select(shop.item_list, 0)
	var gold: int = main.state.gold
	await press_enter()
	check(shop.sell_button.has_focus() and main.state.gold == gold, "Enter on a shop row goes to the trade without trading")
	hub.show_page("equipment")
	var equipment: HubEquipment = hub.equipment_page
	var armor_at := equipment.candidates.find_custom(func(candidate: Dictionary): return candidate.item.kind == ItemData.Kind.ARMOR)
	var worn: ItemData = main.state.equipment.slots[Equipment.Slot.ARMOR]
	equipment.cells[armor_at].grab_focus()
	await press_enter()
	check(equipment.slots[Equipment.Slot.ARMOR].has_focus() and main.state.equipment.slots[Equipment.Slot.ARMOR] == worn, "Enter on gear moves to the slot it would take, wearing nothing")
	await press_enter()
	check(equipment.prompt.visible and equipment.equip_button.has_focus() and main.state.equipment.slots[Equipment.Slot.ARMOR] == worn, "Enter on the slot asks first, with the answer in reach")
	equipment.prompt.cancel_button.pressed.emit()
	check(not equipment.prompt.visible and equipment.cells[armor_at].has_focus(), "Declining returns to the gear")
	hub.open_warehouse()
	var warehouse: HubWarehouse = hub.warehouse_page
	warehouse.carried.cells[0].grab_focus()
	warehouse.carried.cells[0].pressed.emit()
	var carried: int = main.state.inventory.entries.size()
	check(warehouse.carried.cells[0].button_pressed and main.state.inventory.entries.size() == carried, "Choosing an icon moves nothing")
	hub.show_page("home")
	main.state.gold = 300


func check_alpha(targets: Array[Control], value: float, message: String) -> void:
	for target in targets:
		check(is_equal_approx(target.modulate.a, value), message + ": " + target.name)


func run_tests() -> void:
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.state.gold = 300
	main.state.inventory.add(ItemCatalog.POTION, 2)
	main.state.storage.add(preload("res://data/items/leather_armor.tres"))
	main.state.storage.add(ItemCatalog.POTION, 4)
	root.add_child(main)
	var hub = main.get_node("Hub")
	var before := SaveCodec.encode(main.state)
	hub.show_page("sell")
	var shop: HubSell = hub.sell_page
	shop.set_buying(true)
	await create_timer(0.3).timeout
	select(shop.item_list, 0)
	check(shop.item_list.selection_strength == 0.0, "Native selection starts accent")
	check_alpha([shop.showcase, shop.details, shop.possession], 0.65, "Shop details start together")
	check(shop.showcase.visual.item == shop.rows[0].item and shows_name(shop.showcase, shop.details, shop.rows[0].item), "Shop content updates before fade")
	var old_tween := UIMotion.of(shop.details).alpha_tween
	for index in 20:
		select(shop.item_list, index % 2)
	check(not old_tween.is_valid(), "Rapid selection cancels old fade")
	check(shop.showcase.visual.item == shop.rows[1].item and not shop.sell_button.disabled, "Final selection is immediately usable")
	await create_timer(0.2).timeout
	check_alpha([shop.showcase, shop.details, shop.possession], 1.0, "Shop fades settle")
	check(shop.item_list.selection_strength == 1.0, "Accent settles")
	select(shop.item_list, 0)
	shop.refresh(main.state)
	check_alpha([shop.showcase, shop.details, shop.possession], 1.0, "Ordinary refresh resets without replay")
	check(shop.item_list.get_selected_items().is_empty() and shop.showcase.visual.item == null, "Shop refresh clears stale selected content")
	hub.show_page("equipment")
	var equipment: HubEquipment = hub.equipment_page
	equipment.select_slot(Equipment.Slot.ARMOR)
	check(equipment.selected_candidate == -1 and equipment.slots[Equipment.Slot.ARMOR].button_pressed, "Choosing a slot holds no gear")
	equipment.cells[0].pressed.emit()
	check(equipment.selected_candidate == 0 and equipment.cells[0].button_pressed and not equipment.slots[Equipment.Slot.ARMOR].button_pressed, "One thing is chosen at a time: the gear, not the slot")
	equipment.select_slot(Equipment.Slot.ACCESSORY_1)
	check(equipment.selected_candidate == -1 and equipment.slot_menu(Equipment.Slot.ACCESSORY_1).is_empty() and not equipment.cells[0].button_pressed, "An empty slot holds no stale gear and has nothing to take off")
	hub.show_page("home")
	hub.open_warehouse()
	var warehouse: HubWarehouse = hub.warehouse_page
	var stored := warehouse.storage
	var held := warehouse.carried
	stored.cells[0].pressed.emit()
	check(stored.cells[0].button_pressed and warehouse.detail_name.text == main.state.storage.entries[0].item.label(), "Storage selection immediately names the icon")
	held.cells[0].pressed.emit()
	check(stored.selected == -1 and not stored.cells[0].button_pressed and held.cells[0].button_pressed, "Choosing on the other side clears the old choice")
	check(warehouse.detail_name.text == ItemCatalog.POTION.label(), "Inventory selection immediately changes the plaque")
	hub.go_back()
	await check_enter_to_action(hub, main)
	check(SaveCodec.encode(main.state) == before, "Selection never trades, equips, or changes persisted data")
	main.free()
	await process_frame
	check(get_processed_tweens().is_empty(), "Selection tweens are released with UI")
	print("UI selection: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


# The full name must be readable in the detail area: the showcase title wraps
# without a limit, and details name the item when there is no showcase.
func shows_name(showcase: ItemShowcase, details: ItemDetails, item: ItemData) -> bool:
	return showcase.title.text == item.label() or details.get_parsed_text().contains(item.label())
