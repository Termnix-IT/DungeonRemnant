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
	for page in ["home", "prepare", "sell", "upgrade", "stages"]:
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
	check(page.confirm_button.disabled and page.stage_nodes[locked_index].button_pressed, "A locked stage can be read but not started")
	check(page.confirm_button.text.ends_with("未解放"), "A locked stage's action says why")
	page.confirm_button.pressed.emit()
	check(hub.page == "stages" and main.active_run == null, "A locked stage stays on the departure")
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
	check(not page.confirm_button.disabled and page.confirm_button.text == "%s・1Fから挑戦する" % ruins.display_name, "An open stage's action names where and from which floor")
	check(page.slot_cells.size() == 5 and page.slot_cells[0].item == main.state.equipment.slots[0], "The column shows what she takes beside the action")


func check_details(hub, main) -> void:
	hub.show_page("sell")
	var shop: HubSell = hub.sell_page
	shop.set_buying(true)
	shop.pick(0)
	# Owned copies read once in the counter (and in the row), not again in the details.
	check(shop.possession.text.contains("倉庫") and shop.possession.text.contains("→"), "The shop counter says where the copies go")
	hub.show_page("prepare")
	var warehouse: HubPrepare = hub.prepare_page
	var spelled := false
	for label in warehouse.find_children("*", "Label", true, false):
		spelled = spelled or (label as Label).text == HubPrepare.STORAGE_NOTE
	check(not spelled and warehouse.storage.rule.tooltip_text == HubPrepare.STORAGE_NOTE and not warehouse.result_label.visible, "The warehouse rule waits behind a ? by its name; no result before a move")
	var side: StockGrid = warehouse.storage if main.state.inventory.entries.is_empty() else warehouse.carried
	var other: StockGrid = warehouse.carried if side == warehouse.storage else warehouse.storage
	check(not side.cells.is_empty(), "The polish fixture has goods to move")
	if not side.cells.is_empty():
		side.cells[0].pressed.emit()
		check(warehouse.detail_name.text == side.entries[0].item.label() and side.cells[0].button_pressed, "Choosing an icon names it in the column")
		check(warehouse.stock_menu(side, 0)[-1][0] == ("持ち込みへ移す" if side == warehouse.storage else "倉庫へ預ける"), "The right-click menu offers the other side")
		check(other.can_receive.call(side.cells[0]) and not side.can_receive.call(side.cells[0]), "A stock takes only what is dragged from the other")
	# The filter and the order apply to each stock alone.
	var stored: StockGrid = warehouse.storage
	stored.filter_tabs.select(5, true)
	check(not stored.entries.is_empty() and stored.entries.all(func(entry: Dictionary): return entry.item.kind == ItemData.Kind.CONSUMABLE), "The consumables tab shows only consumables")
	check(warehouse.carried.filter_index == 0, "The other stock keeps its own filter")
	stored.filter_tabs.select(2, true)
	check(stored.entries.all(func(entry: Dictionary): return entry.item.kind == ItemData.Kind.ARMOR) and not stored.entries.is_empty(), "The armor tab shows only armor")
	stored.filter_tabs.select(0, true)
	stored.sort_cycler.step(1)
	var names: Array = stored.entries.map(func(entry: Dictionary): return entry.item.label())
	var sorted_names := names.duplicate()
	sorted_names.sort()
	check(names == sorted_names, "Sorting by name orders the icons")
	stored.sort_cycler.step(-1)
	hub.go_back()
