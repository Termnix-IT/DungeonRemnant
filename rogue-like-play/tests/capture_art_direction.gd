extends "res://tests/capture_preparation.gd"

# Pages bring their parts in one by one (the upgrade tree's fifteen nodes
# take the longest); shots wait until all have arrived, so the images show
# each screen as the player reads it, not mid-entrance.
const ENTRANCE_SETTLE := 1.2


func shot(name: String) -> void:
	await create_timer(ENTRANCE_SETTLE).timeout
	await super(name)


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
	for resolution in [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		await settle()
		hub.show_page("home")
		await shot("art_home_%d" % resolution.y)
		for button: Control in [hub.start_button, hub.prepare_button, hub.sell_button, hub.upgrade_button, hub.hero_button, hub.decide_button, hub.home_page.panel]:
			fits(button, "Home navigation")
		hub.show_page("sell")
		var shop: HubSell = hub.sell_page
		for buying in [true, false]:
			shop.set_buying(buying)
			shop.pick(0)
			await shot("art_%s_%d" % ["buy" if buying else "sell", resolution.y])
			for control: Control in [shop.grid, shop.showcase, shop.possession, shop.quantity, shop.total_label, shop.sell_button, shop.sell_all_button]:
				if control.is_visible_in_tree():
					fits(control, "Shop")
		hub.show_page("prepare")
		var prepare: HubPrepare = hub.prepare_page
		# The hammer: worn gear, so the column compares it with the sword.
		prepare.storage.cells[1].pressed.emit()
		await shot("art_prepare_%d" % resolution.y)
		for control: Control in [prepare.carried, prepare.storage, prepare.detail_name, prepare.primary_button, prepare.storage.filter_tabs, prepare.carried.filter_tabs]:
			fits(control, "Preparation")
		for slot: Button in prepare.slots:
			fits(slot, "Preparation slot")
		check(prepare.detail_name.text == prepare.storage.entries[1].item.label(), "The column names the chosen icon")
		hub.show_page("upgrade")
		await shot("art_upgrade_%d" % resolution.y)
		fits(hub.purchase_button, "Upgrade action")
		hub.show_page("stages")
		await shot("art_stages_%d" % resolution.y)
		var nodes: Array = hub.departure_page.stage_nodes
		for control: Control in [hub.departure_page.map, hub.departure_page.stage_details, hub.departure_page.confirm_button, hub.departure_page.review_button] + nodes:
			fits(control, "Departure")
		for cell: Control in hub.departure_page.slot_cells:
			fits(cell, "Departure slot")
		# The road never runs straight: the second stage stands higher.
		check(nodes.size() >= 2 and nodes[1].position.y < nodes[0].position.y - 40, "Stages are set off a straight line")
		hub.departure_page._select_stage(1)
		check(hub.departure_page.confirm_button.disabled, "Locked destination cannot be started")
		hub.departure_page._select_stage(0)
	check(SaveCodec.encode(main.state) == before, "Browsing every screen never changes gameplay state")
	main.free()
	print("Art direction render/layout checks: ", "passed" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)


func fits(control: Control, context: String) -> void:
	check(root.get_visible_rect().grow(1).encloses(control.get_global_rect()), "%s remains inside viewport at %s: %s" % [context, root.size, control.get_path()])
