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


# The everyday motion of the screens in the grammar: marks slide, rows
# arrive, bars move, the goods on display drift. None of it holds input.
func check_screen_motion(hub) -> void:
	var host := Control.new()
	hub.add_child(host)
	var mark := UIMotion.of(host)
	var first := Rect2(0, 0, 100, 40)
	var second := Rect2(0, 80, 100, 40)
	check(mark.follow_mark(first) == first, "A first mark is placed at once")
	check(mark.follow_mark(second) == first, "A new place starts from the shown mark")
	await create_timer(UIMotion.SLIDE_TIME * 0.5).timeout
	var halfway := mark.mark()
	check(halfway.position.y > first.position.y and halfway.position.y < second.position.y, "The mark slides between places")
	await settle(UIMotion.SLIDE_TIME)
	check(mark.mark() == second, "The mark settles on its place")
	host.hide()
	host.show()
	check(not mark.has_mark() and mark.follow_mark(first) == first, "Hiding drops the mark so it does not slide in from a stale place")
	host.free()
	check(UIMotion.row_arrival(0.0, 0, 6) == 0.0 and UIMotion.row_arrival(1.0, 5, 6) == 1.0, "Rows arrive from nothing to settled")
	check(UIMotion.row_arrival(0.3, 0, 6) > UIMotion.row_arrival(0.3, 3, 6), "Upper rows arrive first")
	hub.show_page("sell")
	var shop: HubSell = hub.sell_page
	check(shop._catalog.modulate.a < 1.0, "Opening the shop brings its icons in")
	check(shop.grid.cells.all(func(cell: ItemCell): return cell.focus_mode != Control.FOCUS_NONE and cell.mouse_filter == Control.MOUSE_FILTER_STOP), "Arriving icons still take input")
	await settle(UIMotion.rows_time(10) + UIMotion.ENTER_TIME + UIMotion.STAGGER_TIME * 3)
	check(is_equal_approx(shop._catalog.modulate.a, 1.0), "The entrance settles")
	shop.step_category(1)
	check(shop.grid.scroll.modulate.a < 1.0, "Another category brings its icons in")
	hub.show_page("home")
	check(is_equal_approx(shop.grid.scroll.modulate.a, 1.0), "Leaving resets arriving icons")
	var bars := StatBars.new()
	hub.add_child(bars)
	bars.show_rows([["攻撃力", 4, 4, 10]])
	await process_frame
	bars.show_rows([["攻撃力", 4, 8, 10]])
	check(bars.blend == 0.0 and bars._shown()[0][1] < bars._to[0][1], "A bar starts its move from what it showed")
	await settle(UIMotion.BLEND_TIME)
	check(bars.blend == 1.0 and is_equal_approx(bars._shown()[0][1], bars._to[0][1]), "A bar settles on the new value")
	bars.free()
	hub.show_page("home")


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
	shop.pick(0)
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
	check(hub.feedback.text.contains("-40 G"), "Purchase feedback includes signed amount")
	await settle(0.08)
	check(hub.gold_label.scale.x > 1.02 and hub.gold_label.scale.x <= 1.081, "Gold pulses within bounded scale")
	check(main.sell_item(true, 0, 1), "Sale can interrupt purchase feedback")
	check(completions.back().kind == &"sell" and completions.back().delta == 5 and hub.feedback.text.contains("+5 G"), "Sale has distinct positive feedback")
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
	hub.show_page("prepare")
	await settle()
	check(main.equip_item(true, 1, 2), "Armor equips while UI remains interactive")
	check(completions.back().slots == [2] and completions.back().kind == &"equip", "Equipment completion identifies changed slot")
	await settle(0.06)
	check(hub.prepare_page.slots[2].scale.x > 1.01, "Changed equipment slot pulses")
	hub.show_page("home")
	check(near_scale(hub.prepare_page.slots[2], 1.0), "Hidden slot cancels pulse immediately")
	hub.show_page("prepare")
	check(hub.prepare_page.visible, "The preparation opens synchronously")
	check(main.transfer_storage(false, 0) == false, "Empty carried source does not transfer")
	check(main.transfer_storage(true, 0), "Warehouse transfer remains synchronous")
	check(completions.back().kind == &"withdraw", "Transfer completion identifies destination")
	hub.go_back()
	check(not hub.prepare_page.visible, "Leaving the preparation has no animation delay")
	hub.show_page("upgrade")
	var tree: SkillTreePanel = hub.upgrade_page
	tree.select_upgrade(&"hp")
	tree.root_button.release_focus()
	await settle()
	check(near_scale(tree.root_button, 1.0), "Selecting an upgrade is not success feedback")
	check(main.purchase_upgrade(), "Base HP upgrade succeeds without animation wait")
	check(main.state.hp_upgrade_level == 1 and tree.detail_rank.text.contains("Lv 1") and tree.current_value.text.contains("+1"), "Rank and current bonus update synchronously")
	check(completions.back().kind == &"upgrade" and hub.feedback.text.contains("-30 G"), "Upgrade uses persisted completion and signed cost")
	await settle(0.08)
	check(tree.root_button.scale.x > 1.015 and tree.current_value.scale.x > 1.02, "Purchased card and current bonus pulse")
	check(near_scale(tree.nodes[&"attack"], 1.0), "Unchanged upgrade does not pulse")
	tree.select_upgrade(&"attack")
	check(near_scale(tree.current_value, 1.0), "Changing selection clears previous bonus pulse")
	# The branches open at base HP's cap.
	main.state.hp_upgrade_level = main.state.upgrade.costs.size()
	hub.refresh(main.state)
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
	await check_screen_motion(hub)
	for index in 20:
		hub.show_page("sell")
		hub.show_page("prepare")
		hub.show_page("home")
	await settle()
	for page: Control in [hub.home_page, hub.sell_page, hub.prepare_page]:
		check(is_equal_approx(page.modulate.a, 1.0) and near_scale(page, 1.0), "Rapid navigation restores page alpha and scale")
	for part: Control in [hub.sell_page._catalog, hub.sell_page._info, hub.prepare_page._slab] + hub.prepare_page.slots:
		check(is_equal_approx(part.modulate.a, 1.0), "Rapid navigation settles every arriving part")
	check(is_zero_approx(hub._page_background.modulate.a) and is_equal_approx(hub._ambience.lights_mix, 1.0), "The lobby shows its own hall and its lamps")
	hub.show_page("prepare")
	await settle(UIMotion.WINDOW_TIME + 0.1)
	check(hub._page_background.texture == hub.PAGE_BACKGROUNDS["prepare"] and is_equal_approx(hub._page_background.modulate.a, 1.0) and is_zero_approx(hub._ambience.lights_mix), "The preparation fades its own painting in and the lobby's lamps out")
	hub.show_page("sell")
	await settle(UIMotion.WINDOW_TIME + 0.1)
	check(is_zero_approx(hub._page_background.modulate.a) and is_equal_approx(hub._ambience.lights_mix, 1.0), "A page without a painting of its own returns to the hall")
	hub.show_page("home")
	check(not motion.is_processing(), "Helper has no idle per-frame polling")
	# The hall light fades between lobby entries after a page change.
	await settle(HubAmbience.FOCUS_TIME * 1.5 + 0.05)
	# The heroine's idle runs in her own process, not in a tween.
	check(get_processed_tweens().is_empty(), "Completed and cancelled UI tweens do not accumulate")
	main.free()
	await process_frame
	check(get_processed_tweens().is_empty(), "Freeing UI releases all bound tweens")
	print("UI motion: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
