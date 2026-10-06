extends SceneTree

var checks := 0
var failures := 0
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
	check(hub.page == "home" and hub.home_page.visible, "Boot presents home")
	enter(hub, hub.equipment_button)
	hub.equipment_page.swap_requested.emit()
	check(main.state.equipment.slots[0].weapon.kind == WeaponData.Kind.SPEAR, "Initial weapons can be exchanged without inventory detour")
	hub.equipment_page.swap_requested.emit()
	hub.go_back()
	enter(hub, hub.start_button)
	check(hub.page == "stages" and main.active_run == null, "Home departure opens selection without entering dungeon")
	hub.departure_page.next_button.pressed.emit()
	check(hub.page == "confirm" and main.active_run == null, "Stage selection requires final confirmation")
	hub.go_back()
	check(hub.page == "stages", "Confirmation returns to selected stage")
	hub.go_back()
	check(hub.page == "home", "Selection returns home")
	main.state.inventory.add(ItemCatalog.POTION, 4)
	main.state.storage.add(ARMOR)
	main.state.storage.add(ItemCatalog.floor_item(0))
	hub.refresh(main.state)
	enter(hub, hub.equipment_button)
	var page: HubEquipment = hub.equipment_page
	var armor_at := page.candidates.find_custom(func(candidate: Dictionary): return candidate.item == ARMOR)
	check(armor_at >= 0 and page.candidates[armor_at].from_storage, "Wearable gear lists matching warehouse gear with the carried")
	check(not page.candidates.any(func(candidate: Dictionary): return candidate.item == ItemCatalog.POTION), "Supplies are not gear")
	page.filter_tabs.select(2, true)
	check(not page.candidates.is_empty() and page.candidates.all(func(candidate: Dictionary): return candidate.item.kind == ItemData.Kind.ARMOR), "The armor filter shows armor only")
	page.filter_tabs.select(0, true)
	page.sort_cycler.select(1)
	page.sort_cycler.item_selected.emit(1)
	var stored_names: Array = page.candidates.filter(func(candidate: Dictionary): return candidate.from_storage).map(func(candidate: Dictionary): return candidate.item.label())
	var ordered_names := stored_names.duplicate()
	ordered_names.sort()
	check(stored_names == ordered_names, "Sorting by name orders the stored gear")
	page.sort_cycler.select(0)
	page.sort_cycler.item_selected.emit(0)
	armor_at = page.candidates.find_custom(func(candidate: Dictionary): return candidate.item == ARMOR)
	var bare := RunCarryover.new()
	page.refresh(bare)
	check(bare.storage.entries.is_empty() and not page._storage_heading.text.contains("はない"), "An empty block says nothing more than its count")
	page.refresh(main.state)
	check(page._storage_heading.text.contains("倉庫") and page._storage_heading.text.contains("120"), "The stored block shows its count")
	page.cells[armor_at].pressed.emit()
	check((page.slots[Equipment.Slot.MAIN] as ItemCell).dimmed and not (page.slots[Equipment.Slot.ARMOR] as ItemCell).dimmed, "Choosing gear dims the slots it does not fit")
	check(page.detail_name.text == ARMOR.label(), "The chosen gear is named once, in one line under the icons")
	check(page._slot_accepts(page.cells[armor_at], Equipment.Slot.ARMOR) and not page._slot_accepts(page.cells[armor_at], Equipment.Slot.MAIN), "Only a fitting slot takes the dragged gear")
	check(page._slot_accepts(page.slots[Equipment.Slot.MAIN], Equipment.Slot.SUB) and not page._slot_accepts(page.slots[Equipment.Slot.MAIN], Equipment.Slot.ARMOR), "The weapons can be dragged onto each other to swap")
	check(page.slots[Equipment.Slot.ARMOR]._can_drop_data(Vector2.ZERO, page.cells[armor_at]) and not page.slots[Equipment.Slot.MAIN]._can_drop_data(Vector2.ZERO, page.cells[armor_at]), "Gear can be dropped on a fitting slot only")
	page.slots[Equipment.Slot.ARMOR]._drop_data(Vector2.ZERO, page.cells[armor_at])
	check(page.prompt.visible and main.state.equipment.slots[Equipment.Slot.ARMOR] == null, "Dropping gear on its slot asks before wearing it")
	page.prompt.cancel_button.pressed.emit()
	var weapon_at := page.candidates.find_custom(func(candidate: Dictionary): return candidate.item.kind == ItemData.Kind.WEAPON)
	check(page.gear_menu(armor_at).map(func(entry: Array): return entry[0]) == ["防具に装備"], "Right-clicking armor offers the armor slot")
	check(page.gear_menu(weapon_at).map(func(entry: Array): return entry[0]) == ["主武器に装備", "副武器に装備"], "Right-clicking a weapon offers the main and the sub slot")
	check(page.slot_menu(Equipment.Slot.ARMOR).is_empty() and page.slot_menu(Equipment.Slot.SUB).map(func(entry: Array): return entry[0]) == ["外す", "主武器と副武器を入れ替え"] and page.slot_menu(Equipment.Slot.MAIN).map(func(entry: Array): return entry[0]) == ["主武器と副武器を入れ替え"], "Right-clicking a worn icon offers taking it off, never for the main weapon")
	page.show_menu(Vector2(300, 300), page.gear_menu(armor_at))
	check(page.menu_open(), "The menu opens at the pointer")
	(page._menu_items.get_child(0) as Button).pressed.emit()
	check(not page.menu_open() and page.prompt.visible and main.state.equipment.slots[Equipment.Slot.ARMOR] == null, "Choosing a menu entry asks before wearing")
	page.prompt.cancel_button.pressed.emit()
	page.slots[Equipment.Slot.ARMOR].pressed.emit()
	check(page.prompt.visible and page.prompt.title_label.text.contains(ARMOR.label()) and page.prompt.stat_box.get_child_count() == 1 and (page.prompt.stat_box.get_child(0).get_child(0) as Label).text == "防御力" and page.prompt.caption_label.text.begins_with("防具"), "Choosing the slot asks first, naming the change to her stats")
	check(main.state.equipment.slots[Equipment.Slot.ARMOR] == null, "Asking wears nothing")
	page.prompt.cancel_button.pressed.emit()
	check(not page.prompt.visible and main.state.equipment.slots[Equipment.Slot.ARMOR] == null, "Declining leaves the slot as it was")
	page.slots[Equipment.Slot.ARMOR].pressed.emit()
	page.equip_button.pressed.emit()
	var flying: Array = page.get_children().filter(func(child: Node): return child is Control and child.top_level)
	check(flying.size() == 1 and page.equipped_item == null, "Equipping sends one glyph to its slot and clears the pending item")
	await create_timer(UIMotion.TRAVEL_TIME + 0.1).timeout
	check(page.get_children().filter(func(child: Node): return child is Control and child.top_level).is_empty(), "Equip glyph frees itself on landing")
	# Check that the acknowledgement started, not a timing-dependent sample.
	check(UIMotion.of(page.slots[2]).scale_tween != null, "Landing makes the slot acknowledge it")
	check(main.state.equipment.slots[2] == ARMOR and main.state.storage.entries.size() == 1, "Equip directly from warehouse without transfer detour")
	check(page.slot_menu(Equipment.Slot.ARMOR).map(func(entry: Array): return entry[0]) == ["外す"], "A worn armor icon offers taking it off")
	check((page.slots[Equipment.Slot.ARMOR] as ItemCell).item == ARMOR and page._can_drop_on_gear(Vector2.ZERO, page.slots[Equipment.Slot.ARMOR]) and not page._can_drop_on_gear(Vector2.ZERO, page.slots[Equipment.Slot.MAIN]), "The worn icon can be taken off by dragging it out, except the main weapon")
	check(not main.unequip_item(0), "Main weapon cannot be removed")
	check(main.unequip_item(2) and main.state.inventory.entries.size() == 2, "Unequip returns item to carried inventory")
	check(main.equip_item(false, 1, 2), "Re-equip from carried inventory")
	var snapshot := SaveCodec.encode(main.state)
	check(not main.equip_item(false, 0, 2) and snapshot == SaveCodec.encode(main.state), "Consumable cannot enter armor slot or mutate items")
	hub.open_warehouse()
	check(hub.warehouse_page.visible and not hub.equipment_page.visible and hub.page == "warehouse", "Warehouse opens as a page in place of equipment")
	hub.back_button.pressed.emit()
	check(hub.page == "home" and hub.warehouse_page.get("equipment_link") == null, "The warehouse leads nowhere but back to the lobby")
	main.state.storage.add(ItemCatalog.POTION, 70)
	check(main.transfer_storage(true, 1) and main.state.inventory.entries[0].count == 50 and main.state.storage.entries[1].count == 24, "Taking supplies respects stack limit and preserves leftovers")
	hub.show_page("sell")
	hub.sell_page.item_list.select(1)
	hub.sell_page.item_list.item_selected.emit(1)
	hub.sell_page.quantity.value = 3
	check(hub.sell_page.total_label.text.contains(str(ItemCatalog.POTION.sell_price * 3)), "Sale quote uses selected quantity")
	hub.sell_page.sell_button.pressed.emit()
	check(main.state.gold == ItemCatalog.POTION.sell_price * 3 and main.state.storage.entries[1].count == 21, "Sale updates Gold and removes exact warehouse quantity")
	check(hub.sell_page.sell_button.disabled, "Selection clears after sale to prevent accidental repeated sale")
	snapshot = SaveCodec.encode(main.state)
	check(not main.sell_item(true, 1, 22) and not main.sell_item(true, 1, 0) and not main.sell_item(false, -1, 1), "Invalid sale quantities and indices rejected")
	check(snapshot == SaveCodec.encode(main.state), "Rejected sales preserve all data")
	main.state.gold = SaveCodec.MAX_GOLD
	check(not main.sell_item(true, 1, 1), "Sale cannot overflow saved Gold limit")
	main.state.gold = 20
	main.state.inventory.add(ARMOR, 39)
	check(not main.unequip_item(2), "Full carry inventory blocks unequip without losing equipment")
	check(main.equip_item(false, 1, 2), "Replacement in full inventory succeeds by freeing candidate slot first")
	main.saving_enabled = true
	main.save_store.path = "res://.godot/preparation-missing-%s/save.json" % Time.get_ticks_usec()
	snapshot = SaveCodec.encode(main.state)
	check(not main.equip_item(true, 0, 0) and SaveCodec.encode(main.state) == snapshot, "Failed save rolls warehouse equipment swap back")
	check(not main.swap_weapons() and SaveCodec.encode(main.state) == snapshot, "Failed save rolls Main/Sub swap back")
	check(not main.sell_item(true, 1, 3) and SaveCodec.encode(main.state) == snapshot, "Failed save rolls sale quantity and Gold back")
	main.state.inventory.remove(1)
	snapshot = SaveCodec.encode(main.state)
	check(not main.unequip_item(2) and SaveCodec.encode(main.state) == snapshot, "Failed save rolls unequip back")
	hub.show_page("stages")
	hub.departure_page.next_button.pressed.emit()
	hub.departure_page.confirm_button.pressed.emit()
	check(main.active_run == null and hub.page == "confirm" and hub.save_label.text.contains("保存失敗"), "Failed departure save stays at confirmation")
	var test_path := "res://.godot/preparation-%s.json" % Time.get_ticks_usec()
	main.save_store.path = test_path
	check(main.sell_item(true, 1, 2), "Sale successfully persists")
	check(SaveCodec.encode(main.save_store.load_state()) == SaveCodec.encode(main.state), "Disk reload matches exact preparation state")
	check(main.equip_item(true, 0, 0), "Warehouse swap successfully persists")
	check(SaveCodec.encode(main.save_store.load_state()) == SaveCodec.encode(main.state), "Disk reload preserves exchanged weapons")
	main.saving_enabled = false
	# Verify a newly authored stage drives both the confirmation and runtime floor count.
	var short_stage := StageData.new()
	short_stage.id = &"test_stage"
	short_stage.display_name = "検証用の短い遺跡"
	short_stage.floor_count = 2
	short_stage.settings = DungeonSettings.new()
	short_stage.settings.enemy_count = 0
	short_stage.settings.item_count = 0
	hub.stages.append(short_stage)
	hub.show_page("stages")
	hub.departure_page._select_stage(hub.stages.size() - 1)
	hub.departure_page.next_button.pressed.emit()
	check(hub.departure_page.banner_title.text.contains("全2階"), "Selected stage floor count appears in confirmation")
	hub.departure_page.equipment_requested.emit()
	check(hub.page == "equipment" and hub.equipment_return == "confirm", "Review shortcut preserves confirmation destination")
	# Leaving is the back key; from the review it returns to the confirmation.
	hub.back_button.pressed.emit()
	check(hub.page == "confirm" and hub.departure_page.selected_stage == short_stage, "Preparation returns to same stage confirmation")
	hub.departure_page.confirm_button.pressed.emit()
	var run = main.active_run
	check(run != null and run.final_floor == 2 and run.dungeon_settings == short_stage.settings, "Confirmed stage config reaches Run")
	check(run.hud.floor_value.text == "1 / 2", "Dungeon HUD uses selected stage total")
	var stats: Dictionary = main.state.preparation_stats()
	check(run.turns.player.stats.max_hp == stats.hp and run.turns.player.stats.defense == stats.defense, "Preparation HP and DEF agree with runtime")
	check(run.turns.player.stats.attack + run.turns.player.weapon.damage_bonus == stats.attack, "Preparation ATK agrees with runtime attack")
	check(not main.sell_item(true, 1, 1) and not main.unequip_item(2), "Preparation mutations blocked during run")
	run.floor_number = 2
	run._load_floor()
	var bosses := 0
	for enemy in run.turns.enemies:
		if enemy.stats == preload("res://data/enemies/boss.tres"):
			bosses += 1
	check(bosses == 1 and not run.dungeon.has_stairs, "Selected final floor has boss and no next-floor stairs")
	run.finish_run(true)
	run.retry_run()
	check(main.active_run == null and hub.visible and hub.page == "home", "Run returns directly to home")
	short_stage.available = false
	hub.show_page("stages")
	hub.departure_page._select_stage(hub.stages.size() - 1)
	check(hub.departure_page.next_button.disabled, "Unavailable stage cannot be confirmed")
	main.start_run()
	check(main.active_run == null, "Unavailable stage also rejected at runtime boundary")
	# Moving items mutates the warehouse, so this runs after every other check.
	main.state.inventory.add(ItemCatalog.POTION, 1)
	hub.show_page("home")
	hub.open_warehouse()
	await create_timer(0.1).timeout
	var shelf: HubWarehouse = hub.warehouse_page
	shelf.inventory_list.select(0)
	shelf.inventory_list.item_selected.emit(0)
	var stored_before: int = main.state.storage.entries.size()
	shelf.move_button.pressed.emit()
	var moving: Array = shelf.get_children().filter(func(child: Node): return child is Control and child.top_level)
	check(main.state.storage.entries.size() >= stored_before and moving.size() == 1 and shelf.moved_item == null, "Deposit sends one glyph toward the storage list")
	await create_timer(UIMotion.TRAVEL_TIME + 0.1).timeout
	check(shelf.get_children().filter(func(child: Node): return child is Control and child.top_level).is_empty(), "Moved glyph frees itself on landing")
	main.free()
	print("Preparation tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


# One press on a lobby entry enters it.
func enter(_hub: Node, button: Button) -> void:
	button.pressed.emit()
