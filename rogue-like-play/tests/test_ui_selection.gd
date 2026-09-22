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
	check(shop.showcase.visual.item == shop.rows[0].item and shop.details.get_parsed_text().contains(shop.rows[0].item.label()), "Shop content updates before fade")
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
	check(equipment.candidate_list.selection_strength == 0.0, "Slot change animates automatic candidate selection")
	check_alpha([equipment.showcase, equipment.comparison], 0.65, "Equipment details start together")
	check(equipment.showcase.visual.item == equipment.candidates[0].item and not equipment.equip_button.disabled, "Candidate and equip action update immediately")
	equipment.select_slot(Equipment.Slot.ACCESSORY_1)
	check(equipment.candidate_list.get_selected_items().is_empty() and equipment.equip_button.disabled, "Empty slot has no actionable stale candidate")
	check(equipment.showcase.visual.item == null, "Empty slot clears previous art")
	hub.show_page("home")
	check_alpha([equipment.showcase, equipment.comparison], 1.0, "Leaving equipment resets fades")
	hub.open_warehouse()
	var warehouse: WarehousePanel = hub.warehouse_panel
	var inventory_list: ItemCardList = warehouse.get_node("%InventoryList")
	var storage_list: ItemCardList = warehouse.get_node("%StorageList")
	var help: ItemDetails = warehouse.get_node("%Help")
	var visual: ItemVisual = warehouse.get_node("%Visual")
	var direction: Label = warehouse.get_node("%Direction")
	select(storage_list, 0)
	check_alpha([help, visual, direction], 0.65, "Warehouse details and direction start together")
	check(direction.text == "倉庫 → 所持品" and visual.item == main.state.storage.entries[0].item, "Storage selection immediately shows matching content")
	select(inventory_list, 0)
	check(storage_list.get_selected_items().is_empty() and storage_list.selection_strength == 1.0, "Changing source clears old selection and motion")
	check(direction.text == "所持品 → 倉庫" and visual.item == ItemCatalog.POTION, "Inventory selection immediately changes art and direction")
	check(not warehouse.get_node("%Deposit").disabled and warehouse.get_node("%Withdraw").disabled, "Only matching transfer action is enabled")
	check_alpha([help, visual, direction], 0.65, "New source starts synchronized fade")
	warehouse.close()
	check_alpha([help, visual, direction], 1.0, "Closing warehouse resets fades")
	check(inventory_list.selection_strength == 1.0, "Closing resets accent")
	check(SaveCodec.encode(main.state) == before, "Selection never trades, equips, or changes persisted data")
	main.free()
	await process_frame
	check(get_processed_tweens().is_empty(), "Selection tweens are released with UI")
	print("UI selection: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
