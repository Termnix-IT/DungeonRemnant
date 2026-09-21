extends "res://tests/capture_preparation.gd"


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.state.gold = 300
	main.state.inventory.add(ItemCatalog.POTION, 6)
	for item in ItemCatalog.shop_items():
		main.state.storage.add(item, 3 if item.stackable() else 1)
	root.add_child(main)
	var hub = main.get_node("Hub")
	var before := SaveCodec.encode(main.state)
	for resolution in [Vector2i(1440, 900), Vector2i(1152, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		await settle()
		hub.show_page("home")
		await shot("art_home_%d" % resolution.y)
		for button: Control in [hub.start_button, hub.equipment_button, hub.warehouse_button, hub.sell_button, hub.upgrade_button, hub.hero_button]:
			fits(button, "Home navigation")
		hub.show_page("sell")
		var shop: HubSell = hub.sell_page
		for buying in [true, false]:
			shop.set_buying(buying)
			shop.item_list.select(0)
			shop.item_list.item_selected.emit(0)
			await shot("art_%s_%d" % ["buy" if buying else "sell", resolution.y])
			for control: Control in [shop.item_list, shop.showcase, shop.details, shop.possession, shop.quantity, shop.total_label, shop.sell_button, shop.sell_all_button]:
				if control.is_visible_in_tree():
					fits(control, "Shop")
			check(shop.details.size.y >= 64, "Shop keeps readable description height")
		hub.open_warehouse()
		var warehouse: WarehousePanel = hub.warehouse_panel
		warehouse.get_node("%StorageList").select(0)
		warehouse.get_node("%StorageList").item_selected.emit(0)
		await shot("art_warehouse_%d" % resolution.y)
		for key in ["%InventoryList", "%StorageList", "%Help", "%Deposit", "%Withdraw", "%Gold", "%Direction"]:
			fits(warehouse.get_node(key), "Warehouse")
		check(warehouse.get_node("%Direction").text == "倉庫 → 所持品", "Transfer direction matches selection")
		check(warehouse.get_node("%Deposit").disabled and not warehouse.get_node("%Withdraw").disabled, "Only the selected source can transfer")
		warehouse.close()
		hub.show_page("equipment")
		hub.equipment_page.select_slot(Equipment.Slot.ARMOR)
		await shot("art_equipment_%d" % resolution.y)
		for control: Control in [hub.equipment_page.candidate_list, hub.equipment_page.carried_list, hub.equipment_page.comparison, hub.equipment_page.equip_button, hub.equipment_page.done_button]:
			fits(control, "Equipment")
		for slot: Button in hub.equipment_page.slots:
			fits(slot, "Equipment slot")
		hub.show_page("upgrade")
		await shot("art_upgrade_%d" % resolution.y)
		fits(hub.purchase_button, "Upgrade action")
		hub.show_page("stages")
		await shot("art_stages_%d" % resolution.y)
		for control: Control in [hub.departure_page.stage_list, hub.departure_page.stage_art, hub.departure_page.stage_details, hub.departure_page.next_button]:
			fits(control, "Stage selection")
		hub.departure_page._select_stage(1)
		check(hub.departure_page.next_button.disabled, "Locked destination cannot be started")
		hub.departure_page._select_stage(0)
	check(SaveCodec.encode(main.state) == before, "Browsing all seven screens never changes gameplay state")
	main.free()
	print("Art direction render/layout checks: ", "passed" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)


func fits(control: Control, context: String) -> void:
	check(root.get_visible_rect().grow(1).encloses(control.get_global_rect()), "%s remains inside viewport at %s: %s" % [context, root.size, control.get_path()])
