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
	for frame in 4:
		await process_frame


func check_actions(panel: SkillTreePanel) -> void:
	for node in SkillCatalog.NODES:
		check(panel.nodes[node.id].disabled == not panel.state.can_purchase_skill(node.id), "Skill eligibility matches domain: " + node.id)
	for index in panel.entry_buttons.size():
		check(panel.entry_buttons[index].disabled == not panel.state.can_unlock_entry(panel.stages[panel.stage_choice.selected], 11 + index * 10), "Entry eligibility matches domain: %d" % index)


func check_layout(panel: SkillTreePanel) -> void:
	var rows: Array = panel.skill_rows.values() + panel.entry_rows
	for row: Dictionary in rows:
		check(panel.get_global_rect().grow(1).encloses(row.control.get_global_rect()), "Upgrade row fits panel")
		for key in ["title", "effect", "condition"]:
			check(not row[key].get_global_rect().intersects(row.button.get_global_rect()), "Description leaves purchase button clear: " + key)


func run_tests() -> void:
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	root.add_child(main)
	var hub = main.get_node("Hub")
	var panel: SkillTreePanel = hub.upgrade_page
	var state: RunCarryover = main.state
	hub.show_page("upgrade")
	await settle()
	check(panel.root_button.text.contains("あと30 Gold"), "Base upgrade explains Gold shortage")
	check(panel.skill_rows[&"vitality"].condition.text.contains("基礎HP Lv3"), "Vitality shows actual HP prerequisite")
	check(panel.skill_rows[&"defense"].condition.text.contains("攻撃力 Lv1"), "Defense shows actual attack prerequisite")
	check_actions(panel)
	state.gold = 300
	hub.refresh(state)
	panel.root_button.pressed.emit()
	check(state.hp_upgrade_level == 1 and state.gold == 270, "Base button retains transaction wiring")
	check(not panel.nodes[&"attack"].disabled and panel.nodes[&"vitality"].disabled, "HP rank 1 unlocks attack but not vitality")
	panel.nodes[&"attack"].pressed.emit()
	check(state.skill_rank(&"attack") == 1 and state.gold == 170, "Attack button purchases correct branch")
	check(not panel.nodes[&"defense"].disabled, "Attack unlocks defense immediately")
	panel.nodes[&"defense"].pressed.emit()
	check(state.skill_rank(&"defense") == 1 and state.gold == 20, "Defense purchase updates rank and Gold")
	check(panel.nodes[&"mana"].text.contains("あと60 Gold"), "Unlocked mana reports exact shortfall")
	check(panel.root_label.text.contains("ATK +1 / DEF +1"), "Permanent summary updates after purchase")
	state.gold = 1000
	state.record_boss(RUINS.id, 10, false)
	hub.refresh(state)
	check(not panel.entry_buttons[0].disabled and panel.entry_buttons[1].disabled, "Boss victory unlocks only corresponding entry")
	panel.entry_buttons[0].pressed.emit()
	check(state.gold == 850 and state.can_start(RUINS, 11), "Entry button purchases corresponding floor")
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
	panel.nodes[&"mana"].pressed.emit()
	check(SaveCodec.encode(state) == before and panel.skill_rows[&"mana"].title.text.contains("Lv0"), "Failed save restores displayed rank and Gold")
	main.saving_enabled = false
	state.hp_upgrade_level = state.upgrade.costs.size()
	for node in SkillCatalog.NODES:
		state.skill_levels[String(node.id)] = node.max_rank
	hub.refresh(state)
	check(panel.root_button.disabled and panel.root_button.text.contains("上限"), "Base cap remains explicit")
	for node in SkillCatalog.NODES:
		check(panel.nodes[node.id].disabled and not panel.skill_rows[node.id].effect.text.contains("→"), "Capped upgrade does not promise another bonus")
	check_actions(panel)
	for resolution in [Vector2i(1440, 900), Vector2i(1152, 720)]:
		root.size = resolution
		await settle()
		check_layout(panel)
	main.free()
	print("Upgrade UI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
