class_name SkillTreePanel
extends Control

signal hp_requested
signal skill_requested(id: StringName)
signal entry_requested(stage: StageData, floor_number: int)
var state: RunCarryover
var root_button: Button
var root_label: Label
var nodes: Dictionary = {}
var entry_buttons: Array[Button] = []
var stage_choice: OptionButton
var stages: Array[StageData] = [preload("res://data/stages/ancient_ruins.tres"), preload("res://data/stages/forest.tres")]
var skill_rows: Dictionary = {}
var entry_rows: Array[Dictionary] = []
var stage_status: Label


func _ready() -> void:
	var columns := HBoxContainer.new()
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var skills := _column(columns)
	_label(skills, "ステータス強化", &"HeadingLabel")
	root_label = _label(skills, "", &"MutedLabel")
	var skill_list := _list(skills)
	var base := _row(skill_list, func(): hp_requested.emit())
	skill_rows[&"hp"] = base
	root_button = base.button
	for node in SkillCatalog.NODES:
		var row := _row(skill_list, func(): skill_requested.emit(node.id))
		skill_rows[node.id] = row
		nodes[node.id] = row.button
	var entries := _column(columns)
	_label(entries, "ダンジョン途中解放", &"HeadingLabel")
	_label(entries, "中ボス撃破 → Goldで解放 → 出撃時に開始階を選択", &"MutedLabel")
	stage_choice = OptionButton.new()
	for stage in stages:
		stage_choice.add_item(stage.display_name)
	stage_choice.custom_minimum_size.y = 42
	entries.add_child(stage_choice)
	stage_choice.item_selected.connect(func(_index: int): refresh(state))
	stage_status = _label(entries, "", &"MutedLabel")
	var entry_list := _list(entries)
	for index in 4:
		var floor_number := 11 + index * 10
		var row := _row(entry_list, func(): entry_requested.emit(stages[stage_choice.selected], floor_number))
		entry_rows.append(row)
		entry_buttons.append(row.button)


func _column(parent: Container) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"MainPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var margin := MarginContainer.new()
	panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	return column


func _list(parent: Container) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.theme_type_variation = &"UpgradeList"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(list)
	return list


func _label(parent: Container, value: String, role: StringName) -> Label:
	var label := Label.new()
	label.text = value
	label.theme_type_variation = role
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _row(parent: Container, action: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var copy := VBoxContainer.new()
	copy.theme_type_variation = &"CompactStack"
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(copy)
	var title := _label(copy, "", &"BodyLabel")
	var effect := _label(copy, "", &"MutedLabel")
	var condition := _label(copy, "", &"MutedLabel")
	var button := Button.new()
	button.theme_type_variation = &"GoldButton"
	button.custom_minimum_size = Vector2(get_theme_constant(&"action_width", &"SkillTreePanel"), get_theme_constant(&"action_height", &"SkillTreePanel"))
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	row.add_child(button)
	return {"control": row, "title": title, "effect": effect, "condition": condition, "button": button}


func refresh(current: RunCarryover) -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	state = current
	root_label.text = "永久補正：HP +%d / ATK +%d / DEF +%d / MP +%d" % [state.upgrade.hp_bonus(state.hp_upgrade_level) + state.skill_bonus(&"hp"), state.skill_bonus(&"attack"), state.skill_bonus(&"defense"), state.skill_bonus(&"mp")]
	var hp_cost := state.upgrade.price(state.hp_upgrade_level)
	var base: Dictionary = skill_rows[&"hp"]
	base.title.text = "基礎HP　Lv%d / %d" % [state.hp_upgrade_level, state.upgrade.costs.size()]
	base.effect.text = _effect("最大HP", state.hp_upgrade_level, state.upgrade.hp_per_level, hp_cost)
	base.condition.text = "分岐の起点 / 前提条件なし"
	_action(root_button, hp_cost, true, hp_cost >= 0 and state.gold >= hp_cost)
	for node in SkillCatalog.NODES:
		var row: Dictionary = skill_rows[node.id]
		var rank := state.skill_rank(node.id)
		var cost := node.price(rank)
		var prerequisite := "基礎HP" if node.prerequisite == &"hp" else SkillCatalog.find(node.prerequisite).display_name
		var prerequisite_rank := state.skill_rank(node.prerequisite)
		var met := prerequisite_rank >= node.prerequisite_rank
		row.title.text = "%s　Lv%d / %d" % [node.display_name, rank, node.max_rank]
		var effect_name: String = {&"hp": "最大HP", &"attack": "ATK", &"defense": "DEF", &"mp": "最大MP"}.get(node.effect, node.display_name)
		row.effect.text = _effect(effect_name, rank, node.amount, cost)
		row.condition.text = "条件%s：%s Lv%d（現在Lv%d）" % ["達成" if met else "未達", prerequisite, node.prerequisite_rank, prerequisite_rank]
		row.condition.theme_type_variation = &"MutedLabel" if met else &"BodyLabel"
		_action(row.button, cost, met, state.can_purchase_skill(node.id))
	_refresh_entries()
	if is_visible_in_tree() and previous_focus is Button and is_ancestor_of(previous_focus) and previous_focus.disabled:
		stage_choice.grab_focus()


func _effect(caption: String, rank: int, amount: int, cost: int) -> String:
	return "この強化：%s +%d" % [caption, rank * amount] if cost < 0 else "この強化：%s +%d → +%d" % [caption, rank * amount, (rank + 1) * amount]


func _action(button: Button, cost: int, prerequisite_met: bool, allowed: bool, verb: String = "強化する", complete: String = "強化上限") -> void:
	button.disabled = not allowed
	button.focus_mode = Control.FOCUS_ALL if allowed else Control.FOCUS_NONE
	if cost < 0:
		button.text = complete
	elif not prerequisite_met:
		button.text = "%d Gold\n条件未達" % cost
	elif state.gold < cost:
		button.text = "%d Gold\nあと%d Gold" % [cost, cost - state.gold]
	else:
		button.text = "%d Gold\n%s" % [cost, verb]


func _refresh_entries() -> void:
	var stage := stages[stage_choice.selected]
	var available := state.stage_available(stage)
	stage_status.text = "開始時はLv1。永久強化は引き継がれます。" if available else "ステージ未解放：%sをクリア" % _stage_name(stage.previous_stage)
	for index in entry_rows.size():
		var row := entry_rows[index]
		var floor_number := 11 + index * 10
		var unlocked: bool = floor_number in state.unlocked_entries.get(String(stage.id), [])
		var defeated: bool = floor_number - 1 in state.defeated_bosses.get(String(stage.id), [])
		row.title.text = "%dFから開始　%s" % [floor_number, "解放済み" if unlocked else "未解放"]
		row.effect.text = "%dF 中ボス → %dF 開始地点" % [floor_number - 1, floor_number]
		row.condition.text = "中ボス撃破済み" if defeated else "条件未達：%dFの中ボスを撃破" % (floor_number - 1)
		if not available:
			row.condition.text = "条件未達：ステージを解放"
		row.condition.theme_type_variation = &"MutedLabel" if defeated and available else &"BodyLabel"
		_action(row.button, -1 if unlocked else stage.entry_costs[index], defeated and available, state.can_unlock_entry(stage, floor_number), "解放する", "解放済み")


func _stage_name(id: StringName) -> String:
	for stage in stages:
		if stage.id == id:
			return stage.display_name
	return String(id)


func focus_first_action() -> void:
	for row: Dictionary in skill_rows.values():
		if not row.button.disabled:
			row.button.grab_focus()
			return
	stage_choice.grab_focus()
