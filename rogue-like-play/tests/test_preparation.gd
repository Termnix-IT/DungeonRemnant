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
	main.saving_enabled = false
	root.add_child(main)
	var hub = main.get_node("Hub")
	check(hub.page == "home" and hub.home_page.visible, "Boot presents home")
	hub.equipment_button.pressed.emit()
	hub.equipment_page.swap_button.pressed.emit()
	check(main.state.equipment.slots[0].weapon.kind == WeaponData.Kind.SPEAR, "Initial weapons can be exchanged without inventory detour")
	hub.equipment_page.swap_button.pressed.emit()
	hub.go_back()
	hub.start_button.pressed.emit()
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
	hub.equipment_button.pressed.emit()
	hub.equipment_page.select_slot(Equipment.Slot.ARMOR)
	check(hub.equipment_page.candidates.size() == 1 and hub.equipment_page.candidates[0].from_storage, "Equipment candidates include matching warehouse gear")
	hub.equipment_page.equip_button.pressed.emit()
	check(main.state.equipment.slots[2] == ARMOR and main.state.storage.entries.size() == 1, "Equip directly from warehouse without transfer detour")
	check(hub.equipment_page.stats_label.text.contains(str(ARMOR.defense_bonus)), "Equipment preview reflects defense")
	check(not main.unequip_item(0), "Main weapon cannot be removed")
	check(main.unequip_item(2) and main.state.inventory.entries.size() == 2, "Unequip returns item to carried inventory")
	check(main.equip_item(false, 1, 2), "Re-equip from carried inventory")
	var snapshot := SaveCodec.encode(main.state)
	check(not main.equip_item(false, 0, 2) and snapshot == SaveCodec.encode(main.state), "Consumable cannot enter armor slot or mutate items")
	hub.open_warehouse()
	check(hub.warehouse_panel.visible and not hub._content.visible, "Warehouse isolates underlying controls")
	hub.warehouse_panel.close()
	check(hub.equipment_page.visible and hub.page == "equipment" and hub._content.visible, "Warehouse close returns to equipment")
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
	hub.departure_page._select_stage(1)
	hub.departure_page.next_button.pressed.emit()
	check(hub.title_label.text.contains("全2階"), "Selected stage floor count appears in confirmation")
	hub.departure_page.equipment_requested.emit()
	check(hub.page == "equipment" and hub.equipment_return == "confirm", "Review shortcut preserves confirmation destination")
	hub.equipment_page.done_button.pressed.emit()
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
	hub.open_warehouse()
	hub.warehouse_panel.get_node("Panel/Equipment").pressed.emit()
	check(hub.page == "equipment" and hub.equipment_return == "stages", "Home warehouse equipment shortcut does not return to stale confirmation")
	hub.equipment_page.done_button.pressed.emit()
	check(hub.page == "stages", "Warehouse preparation continues to stage selection")
	short_stage.available = false
	hub.show_page("stages")
	hub.departure_page._select_stage(1)
	check(hub.departure_page.next_button.disabled, "Unavailable stage cannot be confirmed")
	main.start_run()
	check(main.active_run == null, "Unavailable stage also rejected at runtime boundary")
	main.free()
	print("Preparation tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
