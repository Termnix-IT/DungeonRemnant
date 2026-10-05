extends SceneTree

# Hub polish: Japanese terms, balanced line breaks, proportional kana,
# upgrade lock tone, stage selection behaviour and filled detail panes.
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func texts(node: Node, found: Array[String]) -> void:
	if node is Label or node is Button:
		found.append(node.text)
	elif node is RichTextLabel:
		found.append(node.get_parsed_text())
	for child in node.get_children():
		texts(child, found)


func run_tests() -> void:
	check_wrapping()
	var theme: Theme = preload("res://ui/theme/dungeon_theme.tres")
	var display := theme.get_font(&"font", &"TitleLabel") as FontVariation
	check(display != null and display.opentype_features.get(TextServerManager.get_primary_interface().name_to_tag("palt"), 0) == 1, "Display face sets kana proportionally")
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.state.gold = 300
	for item in ItemCatalog.shop_items():
		main.state.storage.add(item, 3 if item.stackable() else 1)
	root.add_child(main)
	var hub = main.get_node("Hub")
	check(Equipment.SLOT_NAMES[0] == "主武器" and HudEquipment.CAPTIONS == Equipment.SLOT_NAMES, "Slot names are Japanese and shared")
	var english := ["ATK", "DEF", "Run", "Main", "Sub", "Armor", "Accessory", "DungeonRemnant"]
	for page in ["home", "equipment", "sell", "upgrade", "stages", "confirm"]:
		hub.show_page(page)
		await process_frame
		var found: Array[String] = []
		texts(hub, found)
		for text in found:
			for word in english:
				check(not text.contains(word), "%s shows Japanese terms, found %s in %s" % [page, word, text])
	hub.show_page("home")
	var logo_found: Array[String] = []
	texts(hub, logo_found)
	# The hub's screens carry no logo (docs/MVP_SPEC.md, 個別画面のUI文法).
	check(not "Dungeon Remnant" in logo_found, "The hub shows no logo")
	check_upgrade(hub)
	await check_stages(hub, main)
	check_details(hub, main)
	main.free()
	await process_frame
	print("Hub polish tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check_wrapping() -> void:
	var font: Font = ThemeDB.fallback_font
	var text := "最大HPと現在HPが3増加する"
	var width := font.get_string_size(text.substr(0, text.length() - 2), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 2
	var wrapped := TextWrap.balanced(text, font, 18, width)
	var lines := wrapped.split("\n")
	check(lines.size() == 2 and lines[1].length() > 2, "Two-line text is split near the middle, not before the last characters: " + wrapped)
	check(lines[0].ends_with("が") or lines[0].ends_with("と"), "Break falls after a particle: " + wrapped)
	check(TextWrap.balanced("短い説明", font, 18, 400) == "短い説明", "Short text is left alone")


func check_upgrade(hub) -> void:
	hub.show_page("upgrade")
	var tree: SkillTreePanel = hub.upgrade_page
	check(tree.root_button.open and not tree.nodes[&"attack"].open, "Fresh save shows the centre open and the branches shut")
	tree.select_upgrade(&"attack")
	check(tree.upgrade_button.disabled and tree.upgrade_button.text == "条件未達", "A shut node's action says why")
	tree.select_upgrade(&"hp")


func check_stages(hub, main) -> void:
	hub.show_page("stages")
	var page: HubDeparture = hub.departure_page
	# Details stay focusable: long guardian lists scroll from the keyboard.
	check(page.stage_details.focus_mode != Control.FOCUS_NONE, "Stage details remain keyboard scrollable")
	var locked_index := -1
	for index in page.stage_nodes.size():
		var node: StageMapNode = page.stage_nodes[index]
		check(node.stage.diorama != null, "Every stage stands on its diorama: " + node.stage.display_name)
		if node.stage.available and not node.unlocked:
			locked_index = index
			check(node.hint.contains("踏破で解放"), "Locked stage explains how to open it")
	check(locked_index >= 0, "A locked stage is on the map")
	check(page.stage_nodes[locked_index].size.x < page.stage_nodes[0].size.x, "A locked stage stands smaller than an open one")
	var descriptions := {}
	for node: StageMapNode in page.stage_nodes:
		var stage := node.stage
		check(not descriptions.has(stage.description), "Stage descriptions differ: " + stage.display_name)
		descriptions[stage.description] = true
		check(not (stage.description.contains("今後追加予定") and not stage.available), "Upcoming stage does not repeat its status")
	page._select_stage(locked_index)
	check(page.next_button.disabled and page.stage_nodes[locked_index].button_pressed, "A locked stage can be read but not started")
	page.next_button.pressed.emit()
	check(hub.page == "stages", "A locked stage stays on selection")
	page._select_stage(0)
	page.stage_nodes[0].grab_focus()
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.physical_keycode = KEY_RIGHT
	right.pressed = true
	Input.parse_input_event(right)
	await process_frame
	await process_frame
	check(page.selected_stage == page.stages[1] and page.stage_nodes[1].has_focus(), "Right moves to the next stage on the map and chooses it")
	page._select_stage(0)
	check(page.stage_details.get_parsed_text().contains("守護者"), "Stage details list guardians by floor")
	var ruins: StageData = page.stages[0]
	check("|".join(page.guardian_lines(ruins)) == "守護者　0 / 5 撃破|次　10F ？？？", "Unknown guardians fold into a count and the next floor")
	main.state.record_boss(ruins.id, 10, false)
	check("|".join(page.guardian_lines(ruins)) == "守護者　1 / 5 撃破|10F %s|次　20F ？？？" % ruins.bosses[0].display_name, "A fallen guardian is named; the next stays unknown")
	main.state.defeated_bosses.erase(String(ruins.id))
	check(page.stage_art.texture == ruins.illustration, "The right column shows the chosen stage's painting")
	page.next_button.pressed.emit()
	await process_frame
	check(hub.page == "confirm", "The action on an open stage goes to the sortie check")


func check_details(hub, main) -> void:
	hub.show_page("sell")
	var shop: HubSell = hub.sell_page
	shop.set_buying(true)
	shop.item_list.select(0)
	shop.item_list.item_selected.emit(0)
	# Owned copies read once in the counter (and in the row), not again in the details.
	check(shop.possession.text.contains("倉庫") and shop.possession.text.contains("→") and not shop.details.get_parsed_text().contains("手元に"), "The shop counter says where the copies go")
	hub.open_warehouse()
	var warehouse: HubWarehouse = hub.warehouse_page
	var visual: ItemVisual = warehouse.showcase.visual
	check(visual.custom_minimum_size == Vector2.ONE * HubWarehouse.SHOWCASE_SIZE and not visual.framed and visual.idle, "The middle shows the goods large, unframed, drifting")
	check(warehouse.details.centered, "The middle centres the item's lines under its art")
	check(warehouse.move_button.tooltip_text.contains("1") and warehouse.move_button.theme_type_variation == &"PrimaryAction", "One primary move action carries the one-stack rule")
	check(warehouse.storage_list.points_left and not warehouse.inventory_list.points_left, "Both stocks' bands point at the middle")
	var spelled := false
	for label in warehouse.find_children("*", "Label", true, false):
		spelled = spelled or (label as Label).text == HubWarehouse.STORAGE_NOTE
	check(not spelled and warehouse.storage_rule.tooltip_text == HubWarehouse.STORAGE_NOTE and not warehouse.result_label.visible, "The warehouse rule waits behind a ? by its name; no result before a move")
	var stock := warehouse.storage_list if main.state.inventory.entries.is_empty() else warehouse.inventory_list
	var entries: Array[InventoryEntry] = main.state.storage.entries if main.state.inventory.entries.is_empty() else main.state.inventory.entries
	check(not entries.is_empty(), "The polish fixture has goods to move")
	if not entries.is_empty():
		stock.item_selected.emit(0)
		check(warehouse.amount_label.text == "×%d" % entries[0].count and warehouse.change_label.text.contains("→"), "The counter says how many go and what it does to both stocks")
	hub.go_back()
