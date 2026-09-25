extends SceneTree

var failures := 0
var checks := 0
var chosen: Array[StringName] = []
var accepted := 0
var cancelled := 0
var retried := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func defeat_summary() -> Dictionary:
	var sword := ItemCatalog.floor_item(6)
	var armor := ItemCatalog.floor_item(1)
	return {"cleared": false, "floor": 7, "earned_gold": 30, "gold_lost": 50, "gold": 50, "item_count_lost": 4,
		"items_lost": {ItemCatalog.POTION.display_name: 3, armor.display_name: 1},
		"lost_entries": [{"item": ItemCatalog.POTION, "count": 3}, {"item": armor, "count": 1}],
		"equipment": [sword, null, null, preload("res://data/items/vital_charm.tres"), null]}


func ignores_pointer(node: Node) -> bool:
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not ignores_pointer(child):
			return false
	return true


func snapshot(label: String, size: Vector2i) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.godot/journey_%s_%dx%d.png" % [label, size.x, size.y]) == OK, "Capture " + label)


func run_tests() -> void:
	var banner := preload("res://ui/journey_banner.gd").new()
	root.add_child(banner)
	banner.present("地下 2F", "新しい階層へ")
	check(banner.visible and banner.title_label.text == "地下 2F", "Floor cue appears immediately")
	check(banner.panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Floor cue never captures pointer input")
	banner.present("モンスターハウス", "周囲の敵に注意")
	check(banner.title_label.text == "モンスターハウス" and banner.get_child_count() == 2, "Repeated cues replace existing display without stacking")
	banner.clear()
	check(not banner.visible and banner.lifetime.is_stopped(), "Clear removes timer and cue immediately")
	check(banner.panel.modulate.a == 1.0 and banner.title_label.scale == Vector2.ONE, "Clear restores animated properties")
	var choice := preload("res://ui/ability_choice.tscn").instantiate()
	root.add_child(choice)
	choice.selected.connect(func(id: StringName): chosen.append(id))
	var abilities := AbilitySystem.new()
	var offers := abilities.offer()
	choice.present(offers, abilities, 2, 1)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_2
	key.pressed = true
	choice._unhandled_input(key)
	check(chosen == [offers[1].id] and not choice.visible, "Keyboard choice works during opening animation")
	check(abilities.levels.is_empty(), "Choice presentation never changes progression directly")
	choice._select(0)
	check(chosen.size() == 1, "Dismissed choice cannot emit twice")
	check(choice.afterglow != null and choice.afterglow.get_parent() == choice.get_parent(), "Chosen moment plays outside the closed dialog")
	check(ignores_pointer(choice.afterglow), "Chosen moment never captures pointer input")
	var first_glow: CanvasLayer = choice.afterglow
	abilities.levels[offers[0].id] = 1
	choice.present(offers, abilities, 2, 1)
	check(not is_instance_valid(first_glow) or first_glow.is_queued_for_deletion(), "A new offer replaces the previous chosen moment")
	check(choice.cards[0].key_label.text == "1" and choice.cards[0].status_label.text == "Lv 1 → 2", "Owned ability card shows its shortcut and next rank")
	check(choice.cards[1].status_label.text == "新規習得" and choice.cards[1].name_label.text == offers[1].display_name, "New ability card shows its name and status")
	choice.dismiss()
	check(choice.cards[2].position == Vector2.ZERO and choice.cards[2].modulate.a == 1.0, "Dismiss restores card entrance motion")
	choice.present(offers, abilities, 2, 1)
	choice._select(2)
	var second_glow: CanvasLayer = choice.afterglow
	await create_timer(UIMotion.MOMENT_TIME + 0.15).timeout
	check(not is_instance_valid(second_glow), "Chosen moment frees itself after playing")
	abilities.levels.clear()
	var result := preload("res://ui/run_result.gd").new()
	root.add_child(result)
	result.abort_confirmed.connect(func(): accepted += 1)
	result.abort_cancelled.connect(func(): cancelled += 1)
	result.retry_requested.connect(func(): retried += 1)
	result.confirm_abort()
	result.cancel.pressed.emit()
	check(cancelled == 1 and accepted == 0, "Cancel only requests return to exploration")
	result.accept.pressed.emit()
	check(accepted == 1 and retried == 0, "Abort remains usable during opening motion")
	var summary := {"cleared": true, "floor": 10, "earned_gold": 130, "gold_lost": 0, "gold": 330, "item_count_lost": 0, "items_lost": {}}
	result.return_to_hub = true
	result.present(summary)
	result.show_save_status("保存に失敗しました。再試行してください。")
	check(not result.confirming and not result.cancel.visible and result.save_label.text.contains("失敗"), "Result preserves save failure status and hides abort cancel")
	result.accept.pressed.emit()
	check(retried == 1, "Result action is immediate")
	result.details.text = "長い損失明細\n".repeat(60)
	await process_frame
	await process_frame
	result.details_scroll.scroll_vertical = 100
	check(result.details_scroll.scroll_vertical > 0 and root.get_visible_rect().encloses(result.accept.get_global_rect()), "Long result details scroll while primary action remains visible")
	result.confirm_abort()
	check(result.details_scroll.scroll_vertical == 0, "Repeated presentation starts details at the beginning")
	result.hide()
	check(result.presentation_panel.modulate.a == 1.0 and result.title_label.scale == Vector2.ONE, "CanvasLayer result hide resets motion immediately")
	result.present(summary)
	check(result.title_label.theme_type_variation == &"VictoryTitle" and result.lost_none.visible and result.lost_none.text == "なし", "Clear result uses victory tone and reports no losses")
	check(not result.kept_box.visible, "Kept equipment hides when the result carries none")
	var defeat := defeat_summary()
	result.present(defeat)
	check(result.title_label.theme_type_variation == &"DefeatTitle" and result.lost_value.text == "−50 G", "Defeat result uses loss tone and signed Gold loss")
	check(result.lost_list.item_count == 2 and not result.lost_none.visible and result.kept_box.visible, "Lost items are listed as cards beside kept equipment")
	check(result.balance_value.text == "70 G", "Balance replays from the run's starting Gold")
	result.hide()
	check(result.balance_value.text == "50 G" and result.stat_rows[3].modulate.a == 1.0, "Hiding mid-sequence settles final values and visibility")
	result.confirm_abort()
	check(not result.summary.visible and not result.lost_box.visible and result.details.visible, "Abort confirmation shows only its explanation")
	result.hide()
	var player := preload("res://actors/player/player.tscn").instantiate()
	root.add_child(player)
	player.inventory.add(ItemCatalog.POTION, 3)
	var inventory := preload("res://ui/inventory_panel.tscn").instantiate()
	root.add_child(inventory)
	inventory.present(player)
	inventory.get_node("Panel/List").select(0)
	inventory._select_item(0)
	check(inventory.selected_index == 0 and player.inventory.entries[0].count == 3, "Inventory can select immediately without consuming items")
	check(inventory.list is ItemCardList and inventory.list.item_count == 1 and inventory.showcase.title.text == ItemCatalog.POTION.label(), "Inventory lists glyph cards and showcases the selection")
	var charm := preload("res://data/items/vital_charm.tres")
	player.inventory.add(charm, 1)
	inventory.refresh()
	inventory.list.select(1)
	inventory._select_item(1)
	check(not inventory.details.get_parsed_text().contains(ItemGlyph.main_effect(charm)), "Details do not repeat the showcased main effect")
	check(inventory.details.get_parsed_text().contains(charm.label()), "Details keep the full item name for truncated cards")
	check(not inventory.remove_buttons[Equipment.Slot.ARMOR].visible and inventory.remove_buttons[Equipment.Slot.MAIN].disabled, "Empty slots hide removal and Main stays non-removable")
	check(inventory.details.get_parsed_text().contains("装飾 1に装備した場合") and inventory.details.get_parsed_text().contains("最大HP"), "Accessory compares against the first empty slot")
	inventory._preview(Equipment.Slot.ACCESSORY_2)
	check(inventory.details.get_parsed_text().contains("装飾 2に装備した場合"), "Hovering an equip action previews that slot")
	player.inventory.remove(1, 1)
	var armor := ItemCatalog.floor_item(1)
	player.inventory.add(armor, 1)
	inventory.refresh()
	var armor_index: int = player.inventory.entries.size() - 1
	inventory.list.select(armor_index)
	inventory._select_item(armor_index)
	check(inventory.details.get_parsed_text().contains("防御") and not inventory.details.get_parsed_text().contains("攻撃"), "Comparison lists only changed values")
	var gear := Equipment.new()
	gear.slots.assign(player.equipment.slots)
	gear.slots[Equipment.Slot.ARMOR] = armor
	var predicted: Dictionary = player.stats_with(gear)
	player.equipment.equip(player.inventory, armor_index, Equipment.Slot.ARMOR)
	player.refresh_equipment_effects()
	var actual := {"hp": player.stats.max_hp, "attack": player.stats.attack + player.effective_weapon().damage_bonus, "defense": player.stats.defense, "reach": player.effective_weapon().reach, "vision": player.vision_range}
	check(predicted == actual, "Previewed stats match the stats after equipping: %s vs %s" % [predicted, actual])
	player.equipment.unequip(player.inventory, Equipment.Slot.ARMOR)
	player.refresh_equipment_effects()
	player.inventory.remove(player.inventory.entries.size() - 1, 1)
	inventory.refresh()
	inventory._select_item(0)
	inventory.hide()
	check(inventory.get_node("Panel").modulate.a == 1.0 and inventory.get_node("Panel/Description").modulate.a == 1.0, "CanvasLayer inventory hide resets both reveal targets immediately")
	await create_timer(0.3).timeout
	check(inventory.get_node("Panel").modulate.a == 1.0, "Hidden inventory restores reveal alpha")
	if "--capture" in OS.get_cmdline_user_args():
		for size in [Vector2i(1440, 900), Vector2i(1152, 720), Vector2i(1920, 1080)]:
			root.size = size
			root.content_scale_size = size
			choice.present(offers, abilities, 2, 1)
			await create_timer(0.08).timeout
			await snapshot("ability_entering", size)
			await create_timer(0.4).timeout
			choice._hover(0, true)
			await create_timer(0.15).timeout
			await snapshot("ability", size)
			choice._select(1)
			await create_timer(0.18).timeout
			await snapshot("ability_chosen", size)
			choice.clear_afterglow()
			result.present(summary)
			await create_timer(1.0).timeout
			await snapshot("result", size)
			result.present(defeat_summary())
			await create_timer(0.2).timeout
			await snapshot("result_defeat_sequence", size)
			await create_timer(0.9).timeout
			await snapshot("result_defeat", size)
			result.hide()
			inventory.present(player)
			inventory.get_node("Panel/List").select(0)
			inventory._select_item(0)
			await snapshot("inventory", size)
			inventory.hide()
			banner.present("地下 2F", "新しい階層へ")
			await snapshot("banner", size)
			banner.clear()
	banner.present("地下 3F")
	banner.lifetime.start(0.01)
	await create_timer(0.05).timeout
	check(not banner.visible, "Floor cue expires without blocking game actions")
	banner.queue_free()
	choice.queue_free()
	result.queue_free()
	inventory.queue_free()
	player.queue_free()
	await process_frame
	print("Journey UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
