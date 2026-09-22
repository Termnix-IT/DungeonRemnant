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
	var player := preload("res://actors/player/player.tscn").instantiate()
	root.add_child(player)
	player.inventory.add(ItemCatalog.POTION, 3)
	var inventory := preload("res://ui/inventory_panel.tscn").instantiate()
	root.add_child(inventory)
	inventory.present(player)
	inventory.get_node("Panel/List").select(0)
	inventory._select_item(0)
	check(inventory.selected_index == 0 and player.inventory.entries[0].count == 3, "Inventory can select immediately without consuming items")
	inventory.hide()
	check(inventory.get_node("Panel").modulate.a == 1.0 and inventory.get_node("Panel/Description").modulate.a == 1.0, "CanvasLayer inventory hide resets both reveal targets immediately")
	await create_timer(0.3).timeout
	check(inventory.get_node("Panel").modulate.a == 1.0, "Hidden inventory restores reveal alpha")
	if "--capture" in OS.get_cmdline_user_args():
		for size in [Vector2i(1440, 900), Vector2i(1152, 720), Vector2i(1920, 1080)]:
			root.size = size
			root.content_scale_size = size
			choice.present(offers, abilities, 2, 1)
			await snapshot("ability", size)
			choice.dismiss()
			result.present(summary)
			await snapshot("result", size)
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
