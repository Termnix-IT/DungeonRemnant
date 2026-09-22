extends SceneTree

var failures := 0
var checks := 0
var completions: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func settle(seconds: float = 0.35) -> void:
	await create_timer(seconds).timeout
	await process_frame


func near_scale(control: Control, value: float) -> bool:
	return control.scale.distance_to(Vector2.ONE * value) < 0.002


func run_tests() -> void:
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.state.gold = 300
	main.state.storage.add(ItemCatalog.POTION, 5)
	main.state.storage.add(preload("res://data/items/leather_armor.tres"))
	root.add_child(main)
	main.preparation_completed.connect(func(kind: StringName, delta: int, slots: Array[int]): completions.append({"kind": kind, "delta": delta, "slots": slots}))
	var hub = main.get_node("Hub")
	hub.show_page("sell")
	var shop: HubSell = hub.sell_page
	shop.set_buying(true)
	shop.item_list.select(0)
	shop.item_list.item_selected.emit(0)
	var button := shop.sell_button
	var motion := UIMotion.of(button)
	await settle()
	var position_before := button.position
	var size_before := button.size
	var quote_before := shop.total_label.position
	button.release_focus()
	button.mouse_entered.emit()
	await settle(0.14)
	check(near_scale(button, 1.015), "Hover reaches restrained scale")
	check(button.pivot_offset.is_equal_approx(button.size * 0.5), "Scaling uses center pivot")
	button.mouse_exited.emit()
	await settle(0.14)
	check(near_scale(button, 1.0), "Mouse exit returns to base")
	button.grab_focus()
	await settle(0.14)
	check(near_scale(button, 1.015), "Keyboard/controller focus gets same response")
	button.mouse_entered.emit()
	button.mouse_exited.emit()
	await settle(0.14)
	check(near_scale(button, 1.015), "Mouse exit preserves active keyboard focus")
	button.release_focus()
	button.mouse_entered.emit()
	button.button_down.emit()
	await settle(0.09)
	check(near_scale(button, 0.98), "Holding press stays slightly compressed")
	button.button_up.emit()
	await settle(0.14)
	check(near_scale(button, 1.015), "Release returns to hovered state")
	for index in 60:
		button.mouse_entered.emit()
		button.button_down.emit()
		button.button_up.emit()
		button.mouse_exited.emit()
	await settle()
	check(near_scale(button, 1.0), "Rapid hover and clicks do not accumulate scale")
	check(button.position == position_before and button.size == size_before and shop.total_label.position == quote_before, "Animation leaves Container layout unchanged")
	button.mouse_entered.emit()
	await settle(0.14)
	button.disabled = true
	# Headless rendering has no draw signal; invoke the same redraw hook.
	motion._check_disabled()
	await settle(0.14)
	check(near_scale(button, 1.0), "Disabled hovered button resets")
	button.button_down.emit()
	await settle(0.1)
	check(near_scale(button, 1.0), "Disabled button ignores press feedback")
	button.disabled = false
	motion._check_disabled()
	button.mouse_exited.emit()
	var completed_before := completions.size()
	check(main.buy_item(true, ItemCatalog.POTION.id, 2), "Purchase succeeds without animation wait")
	check(main.state.gold == 260 and hub.gold_label.text.contains("260"), "Gold model and text update synchronously")
	check(completions.size() == completed_before + 1 and completions.back().kind == &"buy" and completions.back().delta == -40, "Only finalized purchase emits exact negative delta")
	check(hub.feedback.text.contains("-40 Gold"), "Purchase feedback includes signed amount")
	await settle(0.08)
	check(hub.gold_label.scale.x > 1.02 and hub.gold_label.scale.x <= 1.081, "Gold pulses within bounded scale")
	check(main.sell_item(true, 0, 1), "Sale can interrupt purchase feedback")
	check(completions.back().kind == &"sell" and completions.back().delta == 5 and hub.feedback.text.contains("+5 Gold"), "Sale has distinct positive feedback")
	await settle()
	check(near_scale(hub.gold_label, 1.0), "Repeated transactions settle Gold scale")
	completed_before = completions.size()
	var before := SaveCodec.encode(main.state)
	check(not main.buy_item(true, ItemCatalog.POTION.id, 999), "Rejected purchase remains rejected")
	check(completions.size() == completed_before and SaveCodec.encode(main.state) == before, "Rejected action emits no success or mutation")
	main.saving_enabled = true
	main.save_store.path = "res://.godot/motion-missing-%d/save.json" % Time.get_ticks_usec()
	check(not main.buy_item(true, ItemCatalog.POTION.id, 1), "Save failure rolls back purchase")
	check(completions.size() == completed_before and SaveCodec.encode(main.state) == before, "Save failure cannot animate a successful purchase")
	main.saving_enabled = false
	hub.show_page("equipment")
	await settle()
	check(main.equip_item(true, 1, 2), "Armor equips while UI remains interactive")
	check(completions.back().slots == [2] and completions.back().kind == &"equip", "Equipment completion identifies changed slot")
	await settle(0.06)
	check(hub.equipment_page.slots[2].scale.x > 1.01, "Changed equipment slot pulses")
	hub.show_page("home")
	check(near_scale(hub.equipment_page.slots[2], 1.0), "Hidden slot cancels pulse immediately")
	hub.open_warehouse()
	check(hub.warehouse_panel.visible, "Warehouse opens synchronously")
	check(main.transfer_storage(false, 0) == false, "Empty carried source does not transfer")
	check(main.transfer_storage(true, 0), "Warehouse transfer remains synchronous")
	check(completions.back().kind == &"withdraw", "Transfer completion identifies destination")
	hub.warehouse_panel.close()
	check(not hub.warehouse_panel.visible, "Closing modal has no animation delay")
	hub.show_page("upgrade")
	var tree: SkillTreePanel = hub.upgrade_page
	tree.select_upgrade(&"hp")
	tree.root_button.release_focus()
	await settle()
	check(near_scale(tree.root_button, 1.0), "Selecting an upgrade is not success feedback")
	check(main.purchase_upgrade(), "Base HP upgrade succeeds without animation wait")
	check(main.state.hp_upgrade_level == 1 and tree.current_value.text.contains("Lv1"), "Rank and current bonus update synchronously")
	check(completions.back().kind == &"upgrade" and hub.feedback.text.contains("-30 Gold"), "Upgrade uses persisted completion and signed cost")
	await settle(0.08)
	check(tree.root_button.scale.x > 1.015 and tree.current_value.scale.x > 1.02, "Purchased card and current bonus pulse")
	check(near_scale(tree.nodes[&"attack"], 1.0), "Unchanged upgrade does not pulse")
	tree.select_upgrade(&"attack")
	check(near_scale(tree.current_value, 1.0), "Changing selection clears previous bonus pulse")
	await settle()
	check(main.purchase_skill(&"attack"), "Branch upgrade succeeds")
	await settle(0.08)
	check(tree.nodes[&"attack"].scale.x > 1.015 and near_scale(tree.root_button, 1.0), "Only the changed branch pulses")
	hub.show_page("home")
	check(near_scale(tree.nodes[&"attack"], 1.0) and near_scale(tree.current_value, 1.0), "Leaving upgrade resets success motion")
	hub.show_page("upgrade")
	tree.select_upgrade(&"hp")
	tree.root_button.release_focus()
	await settle()
	main.saving_enabled = true
	before = SaveCodec.encode(main.state)
	completed_before = completions.size()
	check(not main.purchase_upgrade(), "Failed save rejects base HP upgrade")
	check(not main.purchase_skill(&"mana"), "Failed save rejects branch upgrade")
	check(SaveCodec.encode(main.state) == before and completions.size() == completed_before, "Failed upgrades restore state and emit no success")
	await settle(0.08)
	check(near_scale(tree.root_button, 1.0) and near_scale(tree.nodes[&"mana"], 1.0) and near_scale(tree.current_value, 1.0), "Failed saves cannot pulse upgrades")
	main.saving_enabled = false
	for index in 20:
		hub.show_page("sell")
		hub.show_page("equipment")
		hub.show_page("home")
	await settle()
	for page: Control in [hub.home_page, hub.sell_page, hub.equipment_page]:
		check(is_equal_approx(page.modulate.a, 1.0) and near_scale(page, 1.0), "Rapid navigation restores page alpha and scale")
	check(not motion.is_processing(), "Helper has no idle per-frame polling")
	# The only perpetual tween is the existing hero breathing animation.
	check(get_processed_tweens().size() == 1, "Completed and cancelled UI tweens do not accumulate")
	main.free()
	await process_frame
	check(get_processed_tweens().is_empty(), "Freeing UI releases all bound tweens")
	print("UI motion: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
