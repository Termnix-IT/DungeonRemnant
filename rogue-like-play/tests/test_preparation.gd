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
	enter(hub, hub.prepare_button)
	hub.prepare_page.swap_requested.emit()
	check(main.state.equipment.slots[0].weapon.kind == WeaponData.Kind.SPEAR, "Initial weapons can be exchanged without inventory detour")
	hub.prepare_page.swap_requested.emit()
	hub.go_back()
	enter(hub, hub.start_button)
	check(hub.page == "stages" and main.active_run == null, "Home departure opens the departure screen without entering the dungeon")
	check(hub.departure_page.confirm_button.has_focus(), "The lobby's shortcut waits on the departure's action")
	hub.go_back()
	check(hub.page == "home", "The departure returns home")
	main.state.inventory.add(ItemCatalog.POTION, 4)
	main.state.storage.add(ARMOR)
	main.state.storage.add(ItemCatalog.floor_item(0))
	hub.refresh(main.state)
	enter(hub, hub.prepare_button)
	var page: HubPrepare = hub.prepare_page
	var armor_at: int = page.storage.entries.find_custom(func(entry: Dictionary): return entry.item == ARMOR)
	check(armor_at >= 0, "The warehouse's gear shows beside what she carries")
	check(page.carried.entries.any(func(entry: Dictionary): return entry.item == ItemCatalog.POTION), "Supplies show too, to move them")
	page.storage.filter_tabs.select(2, true)
	check(not page.storage.entries.is_empty() and page.storage.entries.all(func(entry: Dictionary): return entry.item.kind == ItemData.Kind.ARMOR), "The armor filter shows armor only")
	page.storage.filter_tabs.select(0, true)
	page.storage.sort_cycler.select(1)
	page.storage.sort_cycler.item_selected.emit(1)
	var stored_names: Array = page.storage.entries.map(func(entry: Dictionary): return entry.item.label())
	var ordered_names := stored_names.duplicate()
	ordered_names.sort()
	check(stored_names == ordered_names, "Sorting by name orders the stored goods")
	page.storage.sort_cycler.select(0)
	page.storage.sort_cycler.item_selected.emit(0)
	armor_at = page.storage.entries.find_custom(func(entry: Dictionary): return entry.item == ARMOR)
	var bare := RunCarryover.new()
	page.refresh(bare)
	check(bare.storage.entries.is_empty() and page.storage.count_label.text == "0 / 120 枠", "An empty warehouse says nothing more than its count")
	page.refresh(main.state)
	page.storage.cells[armor_at].pressed.emit()
	check(page.slots[Equipment.Slot.MAIN].dimmed and not page.slots[Equipment.Slot.ARMOR].dimmed, "Choosing gear dims the slots it does not fit")
	check(page.detail_name.text == ARMOR.label() and page.primary_button.text == "防具に装備" and not page.primary_button.disabled, "The column names the chosen gear and the slot it would take")
	check(page.hero_stats.swap_label.visible and page.hero_stats.swap_label.text.begins_with("防具") and page.hero_stats.specs.visible, "The column compares her stats before and after wearing it")
	check(main.state.equipment.slots[Equipment.Slot.ARMOR] == null, "Choosing wears nothing")
	check(page._slot_accepts(page.storage.cells[armor_at], Equipment.Slot.ARMOR) and not page._slot_accepts(page.storage.cells[armor_at], Equipment.Slot.MAIN), "Only a fitting slot takes the dragged gear")
	check(page._slot_accepts(page.slots[Equipment.Slot.MAIN], Equipment.Slot.SUB) and not page._slot_accepts(page.slots[Equipment.Slot.MAIN], Equipment.Slot.ARMOR), "The weapons can be dragged onto each other to swap")
	check(page.slots[Equipment.Slot.ARMOR]._can_drop_data(Vector2.ZERO, page.storage.cells[armor_at]) and not page.slots[Equipment.Slot.MAIN]._can_drop_data(Vector2.ZERO, page.storage.cells[armor_at]), "Gear can be dropped on a fitting slot only")
	page.slots[Equipment.Slot.ARMOR]._drop_data(Vector2.ZERO, page.storage.cells[armor_at])
	check(page.primary_button.has_focus() and main.state.equipment.slots[Equipment.Slot.ARMOR] == null, "Dropping gear on its slot waits on the action before wearing it")
	var weapon_at: int = page.storage.entries.find_custom(func(entry: Dictionary): return entry.item.kind == ItemData.Kind.WEAPON)
	check(page.stock_menu(page.storage, armor_at).map(func(entry: Array): return entry[0]) == ["防具に装備", "持ち込みへ移す"], "Right-clicking armor offers the armor slot and the move")
	check(page.stock_menu(page.storage, weapon_at).map(func(entry: Array): return entry[0]) == ["主武器に装備", "副武器に装備", "持ち込みへ移す"], "Right-clicking a weapon offers the main and the sub slot")
	check(page.slot_menu(Equipment.Slot.ARMOR).is_empty() and page.slot_menu(Equipment.Slot.SUB).map(func(entry: Array): return entry[0]) == ["外す", "主武器と副武器を入れ替え"] and page.slot_menu(Equipment.Slot.MAIN).map(func(entry: Array): return entry[0]) == ["主武器と副武器を入れ替え"], "Right-clicking a worn icon offers taking it off, never for the main weapon")
	page.menu.open(Vector2(300, 300), page.stock_menu(page.storage, armor_at))
	check(page.menu.is_open(), "The menu opens at the pointer")
	page.menu.close()
	page.storage.cells[armor_at].pressed.emit()
	page.primary_button.pressed.emit()
	var flying: Array = page.get_children().filter(func(child: Node): return child is Control and child.top_level)
	check(flying.size() == 1 and page.equipped_item == null, "Equipping sends one glyph to its slot and clears the pending item")
	await create_timer(UIMotion.TRAVEL_TIME + 0.1).timeout
	check(page.get_children().filter(func(child: Node): return child is Control and child.top_level).is_empty(), "Equip glyph frees itself on landing")
	# Check that the acknowledgement started, not a timing-dependent sample.
	check(UIMotion.of(page.slots[2]).scale_tween != null, "Landing makes the slot acknowledge it")
	check(main.state.equipment.slots[2] == ARMOR and main.state.storage.entries.size() == 1, "Equip directly from warehouse without transfer detour")
	check(page.slot_menu(Equipment.Slot.ARMOR).map(func(entry: Array): return entry[0]) == ["外す"], "A worn armor icon offers taking it off")
	check(page.slots[Equipment.Slot.ARMOR].item == ARMOR and page.storage.can_receive.call(page.slots[Equipment.Slot.ARMOR]) and not page.carried.can_receive.call(page.slots[Equipment.Slot.MAIN]), "The worn icon can be taken off by dragging it out, except the main weapon")
	page.select_slot(Equipment.Slot.MAIN)
	check(page.primary_button.disabled and page.detail_name.text == main.state.equipment.slots[0].label(), "The main weapon's slot names it and cannot be emptied")
	check(not main.unequip_item(0), "Main weapon cannot be removed")
	check(main.unequip_item(2) and main.state.inventory.entries.size() == 2, "Unequip returns item to carried inventory")
	check(main.equip_item(false, 1, 2), "Re-equip from carried inventory")
	var snapshot := SaveCodec.encode(main.state)
	check(not main.equip_item(false, 0, 2) and snapshot == SaveCodec.encode(main.state), "Consumable cannot enter armor slot or mutate items")
	hub.back_button.pressed.emit()
	check(hub.page == "home", "The preparation from the lobby returns to the lobby")
	main.state.storage.add(ItemCatalog.POTION, 70)
	check(main.transfer_storage(true, 1) and main.state.inventory.entries[0].count == 50 and main.state.storage.entries[1].count == 24, "Taking supplies respects stack limit and preserves leftovers")
	hub.show_page("sell")
	hub.sell_page.pick(1)
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
	hub.departure_page.confirm_button.pressed.emit()
	check(main.active_run == null and hub.page == "stages" and hub.save_label.text.contains("保存失敗"), "Failed departure save stays at the departure")
	var test_path := "res://.godot/preparation-%s.json" % Time.get_ticks_usec()
	main.save_store.path = test_path
	check(main.sell_item(true, 1, 2), "Sale successfully persists")
	check(SaveCodec.encode(main.save_store.load_state()) == SaveCodec.encode(main.state), "Disk reload matches exact preparation state")
	check(main.equip_item(true, 0, 0), "Warehouse swap successfully persists")
	check(SaveCodec.encode(main.save_store.load_state()) == SaveCodec.encode(main.state), "Disk reload preserves exchanged weapons")
	main.saving_enabled = false
	# Verify a newly authored stage drives both the departure and runtime floor count.
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
	check(hub.departure_page.stage_facts.text.contains("全2階") and hub.departure_page.confirm_button.text.begins_with("検証用の短い遺跡"), "Selected stage floor count and name appear beside the action")
	hub.departure_page.equipment_requested.emit()
	check(hub.page == "prepare" and hub.prepare_return == "stages", "The preparation shortcut remembers the departure")
	# Leaving is the back key; from the shortcut it returns to the departure.
	hub.back_button.pressed.emit()
	check(hub.page == "stages" and hub.departure_page.selected_stage == short_stage, "Preparation returns to the same stage")
	hub.departure_page.confirm_button.pressed.emit()
	var run = main.active_run
	check(run != null and run.final_floor == 2 and run.dungeon_settings == short_stage.settings, "Confirmed stage config reaches Run")
	check(run.hud.floor_value.text == "1 / 2", "Dungeon HUD uses selected stage total")
	var stats: Dictionary = main.state.preparation_stats()
	check(run.turns.player.stats.max_hp == stats.hp and run.turns.player.stats.defense == stats.defense, "Preparation HP and DEF agree with runtime")
	check(run.turns.player.stats.attack + run.turns.player.weapon.damage_bonus == stats.attack, "Preparation ATK agrees with runtime attack")
	check(not main.sell_item(true, 1, 1) and not main.unequip_item(2), "Preparation mutations blocked during run")
	run.floor_number = 2
	run.boss_hall = true
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
	check(hub.departure_page.confirm_button.disabled, "Unavailable stage cannot be started")
	main.start_run()
	check(main.active_run == null, "Unavailable stage also rejected at runtime boundary")
	# Moving items mutates the warehouse, so this runs after every other check.
	main.state.inventory.add(ItemCatalog.POTION, 1)
	hub.show_page("home")
	hub.show_page("prepare")
	await create_timer(0.1).timeout
	var shelf: HubPrepare = hub.prepare_page
	shelf.carried.cells[0].pressed.emit()
	var stored_before: int = main.state.storage.entries.size()
	check(shelf.primary_button.text == "倉庫へ預ける", "Supplies have one action: crossing to the other side")
	shelf.primary_button.pressed.emit()
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
