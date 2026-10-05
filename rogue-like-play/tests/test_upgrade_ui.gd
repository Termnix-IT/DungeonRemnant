extends SceneTree

var checks := 0
var failures := 0
const RUINS := preload("res://data/stages/ancient_ruins.tres")
const FOREST := preload("res://data/stages/forest.tres")


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func settle() -> void:
	for frame in 5:
		await process_frame


func check_actions(panel: SkillTreePanel) -> void:
	panel.set_entries(false)
	for node in SkillCatalog.NODES:
		panel.select_upgrade(node.id)
		check(panel.upgrade_button.disabled == not panel.state.can_purchase_skill(node.id), "Selected skill eligibility matches domain: " + node.id)
		check(not panel.nodes[node.id].disabled, "Locked and capped abilities remain inspectable")
		check(panel.nodes[node.id].open == (panel.state.skill_rank(node.prerequisite) >= node.prerequisite_rank), "A node is open exactly when its source is capped: " + node.id)
	panel.set_entries(true)
	for index in panel.entry_rows.size():
		panel.select_entry(index)
		check(panel.upgrade_button.disabled == not panel.state.can_unlock_entry(panel.stages[panel.stage_choice.selected], 11 + index * 10), "Entry eligibility matches domain: %d" % index)
	panel.set_entries(false)


func purchase(panel: SkillTreePanel, id: StringName) -> void:
	panel.set_entries(false)
	panel.select_upgrade(id)
	panel.upgrade_button.pressed.emit()


func unlock(panel: SkillTreePanel, index: int) -> void:
	panel.set_entries(true)
	panel.select_entry(index)
	panel.upgrade_button.pressed.emit()


func check_layout(panel: SkillTreePanel) -> void:
	var screen := panel.get_viewport().get_visible_rect().grow(1)
	panel.set_entries(false)
	await settle()
	var placed: Array[Rect2] = []
	for id: StringName in panel.buttons:
		var rect: Rect2 = panel.buttons[id].get_global_rect()
		check(panel.canvas.get_global_rect().grow(1).encloses(rect), "Node %s fits the tree" % id)
		for other in placed:
			check(not other.intersects(rect.grow(-2)), "Nodes do not overlap: %s" % id)
		placed.append(rect)
	check(screen.encloses(panel.upgrade_button.get_global_rect()), "Primary action fits the screen")
	check(not panel.canvas.get_global_rect().intersects(panel.upgrade_button.get_global_rect()), "The tree leaves the action clear")
	panel.set_entries(true)
	await settle()
	for row in panel.entry_rows:
		check(screen.encloses(row.get_global_rect()), "Entry row fits the screen")
	panel.set_entries(false)


func run_tests() -> void:
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	root.add_child(main)
	var hub = main.get_node("Hub")
	var panel: SkillTreePanel = hub.upgrade_page
	var state: RunCarryover = main.state
	hub.show_page("upgrade")
	await settle()
	check(panel.selected_id == &"hp" and panel.root_button.has_focus(), "The page opens on the centre")
	check(panel.upgrade_button.text.contains("あと30 G"), "Base upgrade explains exact Gold shortage")
	check(panel.root_button.emblem_size > panel.nodes[&"attack"].emblem_size, "The centre stands larger than the tiers")
	panel.select_upgrade(&"vitality")
	check(panel.requirement.text.contains("基礎HP を上限（Lv 3）") and panel.requirement.text.contains("生命力 II"), "A node says what opens it and what it opens")
	panel.select_upgrade(&"defense_2")
	check(panel.requirement.text.contains("防御力 I を上限（Lv 4）"), "A tier waits for the cap of the one before it")
	check_actions(panel)
	state.gold = 300
	hub.refresh(state)
	panel.root_button.pressed.emit()
	check(state.hp_upgrade_level == 0 and state.gold == 300, "Choosing a node never purchases")
	check(panel.current_value.text.contains("+0") and panel.next_value.text.contains("+1"), "The detail shows the current and next bonus")
	check(panel.root_button.growable and not panel.nodes[&"attack"].open and not panel.nodes[&"attack"].growable, "Only the node Gold can grow now carries the ready mark; a shut one is locked")
	panel.select_upgrade(&"attack")
	check(panel.price_label.theme_type_variation == &"PriceLabelLocked", "A price behind an unmet condition stays out of gold")
	panel.select_upgrade(&"hp")
	check(panel.price_label.theme_type_variation == &"PriceLabel", "A price that can be paid now is gold")
	check(panel._lit_to[&"attack"] == 0.0, "A wire from an ungrown source is dark")
	purchase(panel, &"hp")
	check(state.hp_upgrade_level == 1 and state.gold == 270, "Primary action buys base HP")
	check(is_equal_approx(panel._lit_to[&"attack"], 1.0 / 3.0), "A wire lights by its source's share of the cap")
	check(panel.root_button.rank == 1 and UIMotion.of(panel.root_button).glow_tween != null and UIMotion.of(panel.root_button).flash_tween != null, "Purchase lights the gained mark and brightens the node")
	check(UIMotion.of(panel.nodes[&"attack"]).glow_tween == null, "Only the grown node plays the gain")
	check(panel.blend < 1.0, "The wires replay their new share")
	purchase(panel, &"attack")
	check(state.skill_rank(&"attack") == 0 and state.gold == 270, "A branch stays shut before base HP's cap")
	state.gold = 1000
	hub.refresh(state)
	purchase(panel, &"hp")
	purchase(panel, &"hp")
	check(state.hp_upgrade_level == 3 and panel.nodes[&"attack"].open and panel.nodes[&"mana"].open, "Capping the centre opens all four branches")
	check(panel.upgrade_button.text.contains("上限"), "The capped centre says so")
	purchase(panel, &"attack")
	check(state.skill_rank(&"attack") == 1 and state.gold == 1000 - 60 - 90 - 100, "Primary action buys the chosen branch")
	panel.select_upgrade(&"attack")
	check(panel.totals.rows[1][1] == 1 and panel.totals.rows[1][2] == 2, "Permanent totals show before and after the next rank")
	# Attack's four tiers of five ranks at +1 each: the bar measures against
	# the whole branch, not against her current bonus.
	check(panel.totals.rows[1][3] == 20 and panel.totals.rows[0][3] == panel.ceiling(&"hp") and panel.ceiling(&"hp") > 3, "Permanent total bars measure against the fully grown tree")
	state.gold = 0
	hub.refresh(state)
	panel.select_upgrade(&"mana")
	check(panel.upgrade_button.text.contains("あと80 G"), "An open node reports the exact shortfall")
	check(panel.nodes[&"mana"].open and not panel.nodes[&"mana"].growable, "An open node short of Gold carries no ready mark")
	state.gold = 1000
	state.record_boss(RUINS.id, 10, false)
	hub.refresh(state)
	panel.set_entries(true)
	panel.select_entry(0)
	check(not panel.upgrade_button.disabled and panel.upgrade_button.text == "解放する", "Boss victory opens the matching start floor")
	panel.select_entry(1)
	check(panel.upgrade_button.disabled, "Only the matching start floor opens")
	check(panel.price_label.theme_type_variation == &"PriceLabelLocked", "A start floor whose boss still stands shows its price out of gold")
	unlock(panel, 0)
	check(state.gold == 850 and state.can_start(RUINS, 11), "The primary action unlocks the chosen floor")
	check(panel.upgrade_button.disabled and panel.upgrade_button.text == "解放済み", "An owned floor cannot be bought again")
	panel.stage_choice.select(1)
	panel.stage_choice.item_selected.emit(1)
	check(panel.stage_status.text.contains("古代遺跡をクリア"), "Locked stage explains prerequisite dungeon")
	check_actions(panel)
	state.record_boss(RUINS.id, 50, true)
	state.record_boss(FOREST.id, 10, false)
	state.gold = 149
	hub.refresh(state)
	panel.set_entries(true)
	panel.select_entry(0)
	check(panel.upgrade_button.text.contains("あと1 G"), "Stage switch uses independent unlock and price")
	state.gold = 150
	hub.refresh(state)
	unlock(panel, 0)
	check(state.gold == 0 and state.can_start(FOREST, 11), "Stage choice routes purchase to selected dungeon")
	state.gold = 9999
	main.saving_enabled = true
	main.save_store.path = "res://.godot/nonexistent-upgrade-ui-directory/save.json"
	hub.refresh(state)
	var before := SaveCodec.encode(state)
	purchase(panel, &"mana")
	check(SaveCodec.encode(state) == before and panel.nodes[&"mana"].rank == 0 and panel.detail_rank.text.contains("Lv 0"), "Failed save restores displayed rank and Gold")
	main.saving_enabled = false
	state.hp_upgrade_level = state.upgrade.costs.size()
	for node in SkillCatalog.NODES:
		state.skill_levels[String(node.id)] = node.max_rank
	hub.refresh(state)
	panel.select_upgrade(&"hp")
	check(panel.upgrade_button.disabled and panel.upgrade_button.text.contains("上限"), "Base cap remains explicit")
	for node in SkillCatalog.NODES:
		panel.select_upgrade(node.id)
		check(panel.upgrade_button.disabled and panel.benefit_label.text.contains("最大まで"), "Capped upgrade does not promise another bonus")
		check(panel._lit_to[node.id] == 1.0, "Every wire is lit when the tree is full")
	check_actions(panel)
	# R switches the mode, as the shop's buying and selling.
	var swap := InputEventKey.new()
	swap.keycode = KEY_R
	swap.pressed = true
	Input.parse_input_event(swap)
	await settle()
	check(panel.entries_shown and panel.entry_tab.button_pressed, "R switches to the start floors")
	panel.set_entries(false)
	for resolution in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		root.size = resolution
		await settle()
		await check_layout(panel)
	main.free()
	print("Upgrade UI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
