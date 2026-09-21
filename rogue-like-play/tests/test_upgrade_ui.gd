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
	for node in SkillCatalog.NODES:
		panel.select_upgrade(node.id)
		check(panel.upgrade_button.disabled == not panel.state.can_purchase_skill(node.id), "Selected skill eligibility matches domain: " + node.id)
		check(not panel.nodes[node.id].disabled, "Locked and capped abilities remain inspectable")
	for index in panel.entry_buttons.size():
		check(panel.entry_buttons[index].disabled == not panel.state.can_unlock_entry(panel.stages[panel.stage_choice.selected], 11 + index * 10), "Entry eligibility matches domain: %d" % index)


func purchase(panel: SkillTreePanel, id: StringName) -> void:
	panel.select_upgrade(id)
	panel.upgrade_button.pressed.emit()


func check_layout(panel: SkillTreePanel) -> void:
	panel._show_tab(0)
	await settle()
	for row: Dictionary in panel.skill_rows.values():
		check(panel.get_global_rect().grow(1).encloses(row.control.get_global_rect()), "Ability card fits panel")
		check(row.control.get_global_rect().grow(1).encloses(row.control.cost_label.get_global_rect()), "Card price fits card")
	check(panel.get_global_rect().grow(1).encloses(panel.upgrade_button.get_global_rect()), "Primary action fits panel")
	panel._show_tab(1)
	await settle()
	for row: Dictionary in panel.entry_rows:
		check(panel.get_global_rect().grow(1).encloses(row.control.get_global_rect()), "Entry card fits panel")
		for key in ["title", "condition"]:
			check(not row[key].get_global_rect().intersects(row.button.get_global_rect()), "Entry description leaves action clear: " + key)


func run_tests() -> void:
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	root.add_child(main)
	var hub = main.get_node("Hub")
	var panel: SkillTreePanel = hub.upgrade_page
	var state: RunCarryover = main.state
	hub.show_page("upgrade")
	await settle()
	check(panel.upgrade_button.text.contains("あと30 Gold"), "Base upgrade explains exact Gold shortage")
	panel.select_upgrade(&"vitality")
	check(panel.requirement.text.contains("基礎HP Lv3"), "Vitality shows actual HP prerequisite")
	panel.select_upgrade(&"defense")
	check(panel.requirement.text.contains("攻撃力 Lv1"), "Defense shows actual attack prerequisite")
	check_actions(panel)
	state.gold = 300
	hub.refresh(state)
	panel.root_button.pressed.emit()
	check(state.hp_upgrade_level == 0 and state.gold == 300, "Selecting a card never purchases")
	check(panel.current_value.text.contains("Lv0") and panel.next_value.text.contains("+1"), "Selected detail shows actual current and next benefit")
	purchase(panel, &"hp")
	check(state.hp_upgrade_level == 1 and state.gold == 270, "Primary button retains HP transaction wiring")
	check(panel.skill_rows[&"hp"].control.progress.value == 1, "Purchase advances growth progress")
	purchase(panel, &"attack")
	check(state.skill_rank(&"attack") == 1 and state.gold == 170, "Primary action purchases selected branch")
	purchase(panel, &"defense")
	check(state.skill_rank(&"defense") == 1 and state.gold == 20, "Defense purchase updates rank and Gold")
	panel.select_upgrade(&"mana")
	check(panel.upgrade_button.text.contains("あと60 Gold"), "Unlocked mana reports exact shortfall")
	check(panel.root_label.text.contains("ATK +1") and panel.root_label.text.contains("DEF +1"), "Permanent summary updates after purchase")
	state.gold = 1000
	state.record_boss(RUINS.id, 10, false)
	hub.refresh(state)
	panel._show_tab(1)
	check(not panel.entry_buttons[0].disabled and panel.entry_buttons[1].disabled, "Boss victory unlocks only corresponding entry")
	panel.entry_buttons[0].grab_focus()
	panel.entry_buttons[0].pressed.emit()
	check(state.gold == 850 and state.can_start(RUINS, 11), "Entry button purchases corresponding floor")
	check(panel.stage_choice.has_focus(), "Completed entry action returns keyboard focus to stage choice")
	check(panel.entry_buttons[0].disabled and panel.entry_buttons[0].text == "解放済み", "Owned entry cannot be purchased again")
	panel.stage_choice.select(1)
	panel.stage_choice.item_selected.emit(1)
	check(panel.stage_status.text.contains("古代遺跡をクリア"), "Locked stage explains prerequisite dungeon")
	check_actions(panel)
	state.record_boss(RUINS.id, 50, true)
	state.record_boss(FOREST.id, 10, false)
	state.gold = 149
	hub.refresh(state)
	check(panel.entry_buttons[0].text.contains("あと1 Gold"), "Stage switch uses independent unlock and price")
	state.gold = 150
	hub.refresh(state)
	panel.entry_buttons[0].pressed.emit()
	check(state.gold == 0 and state.can_start(FOREST, 11), "Stage choice routes purchase to selected dungeon")
	state.gold = 9999
	main.saving_enabled = true
	main.save_store.path = "res://.godot/nonexistent-upgrade-ui-directory/save.json"
	hub.refresh(state)
	var before := SaveCodec.encode(state)
	purchase(panel, &"mana")
	check(SaveCodec.encode(state) == before and panel.detail_rank.text.contains("Lv 0"), "Failed save restores displayed rank and Gold")
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
	check_actions(panel)
	for resolution in [Vector2i(1440, 900), Vector2i(1152, 720)]:
		root.size = resolution
		await settle()
		await check_layout(panel)
	main.free()
	print("Upgrade UI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
