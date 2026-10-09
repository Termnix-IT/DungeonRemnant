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
	shop.grid.cells[0].grab_focus()
	check(shop.chosen_place() == 0, "Reaching an icon with the focus chooses it")
	var gold: int = main.state.gold
	await press_enter()
	check(shop.sell_button.has_focus() and main.state.gold == gold, "Enter on a shop icon goes to the trade without trading")
	hub.show_page("prepare")
	var equipment: HubPrepare = hub.prepare_page
	var armor_at: int = equipment.storage.entries.find_custom(func(entry: Dictionary): return entry.item.kind == ItemData.Kind.ARMOR)
	var worn: ItemData = main.state.equipment.slots[Equipment.Slot.ARMOR]
	equipment.storage.cells[armor_at].grab_focus()
	await press_enter()
	check(equipment.primary_button.has_focus() and equipment.primary_button.text == "防具に装備" and main.state.equipment.slots[Equipment.Slot.ARMOR] == worn, "Enter on gear moves to the action for the slot it would take, wearing nothing")
	equipment.slots[Equipment.Slot.MAIN].grab_focus()
	await press_enter()
	check(equipment.slots[Equipment.Slot.MAIN].button_pressed and main.state.equipment.slots[Equipment.Slot.ARMOR] == worn, "Enter on a slot the gear does not fit chooses the slot instead")
	equipment.carried.cells[0].grab_focus()
	equipment.carried.cells[0].pressed.emit()
	var carried: int = main.state.inventory.entries.size()
	check(equipment.carried.cells[0].button_pressed and main.state.inventory.entries.size() == carried, "Choosing an icon moves nothing")
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
	shop.pick(0)
	check_alpha([shop.showcase, shop.possession], 0.65, "Shop details start together")
	check(shop.showcase.visual.item == shop.rows[0].item and shop.showcase.title.text == shop.rows[0].item.label(), "Shop content updates before fade")
	var old_tween := UIMotion.of(shop.possession).alpha_tween
	for index in 20:
		shop.pick(index % 2)
	check(not old_tween.is_valid(), "Rapid selection cancels old fade")
	check(shop.showcase.visual.item == shop.rows[1].item and not shop.sell_button.disabled, "Final selection is immediately usable")
	await create_timer(0.2).timeout
	check_alpha([shop.showcase, shop.possession], 1.0, "Shop fades settle")
	shop.pick(0)
	shop.refresh(main.state)
	check_alpha([shop.showcase, shop.possession], 1.0, "Ordinary refresh resets without replay")
	check(shop.chosen_place() == -1 and shop.showcase.visual.item == null, "Shop refresh clears stale selected content")
	hub.show_page("prepare")
	var equipment: HubPrepare = hub.prepare_page
	equipment.select_slot(Equipment.Slot.ARMOR)
	check(equipment._chosen().is_empty() and equipment.slots[Equipment.Slot.ARMOR].button_pressed, "Choosing a slot holds no gear")
	equipment.storage.cells[0].pressed.emit()
	check(equipment.storage.cells[0].button_pressed and not equipment.slots[Equipment.Slot.ARMOR].button_pressed, "One thing is chosen at a time: the gear, not the slot")
	equipment.select_slot(Equipment.Slot.ACCESSORY_1)
	check(equipment._chosen().is_empty() and equipment.slot_menu(Equipment.Slot.ACCESSORY_1).is_empty() and not equipment.storage.cells[0].button_pressed and equipment.primary_button.disabled, "An empty slot holds no stale gear and has nothing to take off")
	var warehouse: HubPrepare = equipment
	var stored := warehouse.storage
	var held := warehouse.carried
	stored.cells[0].pressed.emit()
	check(stored.cells[0].button_pressed and warehouse.detail_name.text == main.state.storage.entries[0].item.label(), "Storage selection immediately names the icon")
	held.cells[0].pressed.emit()
	check(stored.selected == -1 and not stored.cells[0].button_pressed and held.cells[0].button_pressed, "Choosing on the other side clears the old choice")
	check(warehouse.detail_name.text == ItemCatalog.POTION.label(), "Inventory selection immediately changes the column")
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
