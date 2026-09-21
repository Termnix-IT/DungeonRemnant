class_name SkillTreePanel
extends Control

signal hp_requested
signal skill_requested(id: StringName)
signal entry_requested(stage: StageData, floor_number: int)
const UpgradeCard := preload("res://ui/upgrade_card.gd")
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
var selected_id: StringName = &"hp"
var upgrade_button: Button
var abilities: HBoxContainer
var entries: PanelContainer
var tabs: Array[Button] = []
var detail: VBoxContainer
var detail_title: Label
var detail_rank: Label
var current_value: Label
var next_value: Label
var benefit_label: Label
var requirement: Label
var price_label: Label


func _ready() -> void:
	var layout := VBoxContainer.new()
	add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var navigation := HBoxContainer.new()
	layout.add_child(navigation)
	for index in 2:
		var tab := HubUI.button(navigation, ["能力の成長", "開始地点の解放"][index], _show_tab.bind(index))
		tab.toggle_mode = true
		tabs.append(tab)
	abilities = HBoxContainer.new()
	abilities.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(abilities)
	var skill_list := VBoxContainer.new()
	skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_list.size_flags_stretch_ratio = 1.15
	abilities.add_child(skill_list)
	HubUI.label(skill_list, "冒険を重ね、力を残す", &"HeadingLabel")
	root_label = HubUI.label(skill_list, "", &"MutedLabel")
	var cards := VBoxContainer.new()
	cards.theme_type_variation = &"UpgradeList"
	skill_list.add_child(cards)
	for id: StringName in [&"hp", &"vitality", &"attack", &"defense", &"mana"]:
		var card := UpgradeCard.new()
		card.effect = &"hp" if id == &"hp" else SkillCatalog.find(id).effect
		card.pressed.connect(select_upgrade.bind(id))
		cards.add_child(card)
		skill_rows[id] = {"control": card, "button": card, "title": card.caption, "effect": card.benefit}
		if id == &"hp":
			root_button = card
		else:
			nodes[id] = card
	_build_detail()
	_build_entries(layout)
	_show_tab(0)


func _build_detail() -> void:
	detail = HubUI.section(abilities, 1.0, &"DetailPanel")
	detail.theme_type_variation = &"UpgradeList"
	HubUI.label(detail, "選択中の永久強化", &"MutedLabel")
	detail_title = HubUI.label(detail, "", &"TitleLabel")
	detail_rank = HubUI.label(detail, "", &"MutedLabel")
	var change := HubUI.section(detail, 1.0, &"InsetPanel")
	change.theme_type_variation = &"CompactStack"
	HubUI.label(change, "この能力による永久補正", &"MutedLabel")
	current_value = HubUI.label(change, "", &"BodyLabel")
	HubUI.label(change, "↓", &"GoldLabel")
	next_value = HubUI.label(change, "", &"ValueLabel")
	benefit_label = HubUI.label(change, "", &"PositiveLabel")
	requirement = HubUI.label(detail, "", &"MutedLabel")
	HubUI.space(detail)
	HubUI.label(detail, "必要なGold", &"MutedLabel")
	price_label = HubUI.label(detail, "", &"GoldLabel")
	upgrade_button = HubUI.button(detail, "強化する", _purchase_selected, &"GoldButton")
	upgrade_button.custom_minimum_size.y = 54


func _build_entries(parent: Container) -> void:
	entries = PanelContainer.new()
	entries.theme_type_variation = &"MainPanel"
	entries.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(entries)
	var margin := MarginContainer.new()
	entries.add_child(margin)
	var layout := HBoxContainer.new()
	margin.add_child(layout)
	var introduction := VBoxContainer.new()
	introduction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(introduction)
	HubUI.label(introduction, "開いた道を、次の冒険へ", &"HeadingLabel")
	HubUI.label(introduction, "中ボス撃破 → Goldで解放\n出撃時に開始階を選べます。", &"BodyLabel")
	stage_choice = OptionButton.new()
	for stage in stages:
		stage_choice.add_item(stage.display_name)
	stage_choice.custom_minimum_size.y = 44
	introduction.add_child(stage_choice)
	stage_choice.item_selected.connect(func(_index: int): _refresh_entries())
	stage_status = HubUI.label(introduction, "", &"MutedLabel")
	var entry_list := VBoxContainer.new()
	entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_list.size_flags_stretch_ratio = 1.5
	entry_list.theme_type_variation = &"UpgradeList"
	layout.add_child(entry_list)
	for index in 4:
		var floor_number := 11 + index * 10
		var section := HubUI.section(entry_list, 1.0, &"InsetPanel")
		section.get_parent().theme_type_variation = &"CompactMargin"
		var row := HBoxContainer.new()
		section.add_child(row)
		var copy := VBoxContainer.new()
		copy.theme_type_variation = &"CompactStack"
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		var title := HubUI.label(copy, "", &"ItemNameLabel")
		var condition := HubUI.label(copy, "", &"MutedLabel")
		var button := HubUI.button(row, "", func(): entry_requested.emit(stages[stage_choice.selected], floor_number), &"GoldButton")
		button.custom_minimum_size.x = 160
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		entry_rows.append({"control": section.get_parent().get_parent(), "title": title, "condition": condition, "button": button})
		entry_buttons.append(button)


func _show_tab(index: int) -> void:
	abilities.visible = index == 0
	entries.visible = index == 1
	for i in tabs.size():
		tabs[i].set_pressed_no_signal(i == index)
		tabs[i].theme_type_variation = &"PrimaryButton" if i == index else &"SecondaryButton"
	if state != null:
		UIMotion.of(abilities if index == 0 else entries).reveal()


func select_upgrade(id: StringName) -> void:
	selected_id = id
	_refresh_detail()
	for key: StringName in skill_rows:
		skill_rows[key].button.set_pressed_no_signal(key == id)
		skill_rows[key].button.queue_redraw()
	UIMotion.of(skill_rows[id].control).reveal()
	UIMotion.of(detail).reveal()


func _purchase_selected() -> void:
	if selected_id == &"hp":
		hp_requested.emit()
	else:
		skill_requested.emit(selected_id)


func _info(id: StringName) -> Dictionary:
	if id == &"hp":
		return {"name": "基礎HP", "rank": state.hp_upgrade_level, "max": state.upgrade.costs.size(), "amount": state.upgrade.hp_per_level, "effect": "最大HP", "cost": state.upgrade.price(state.hp_upgrade_level), "met": true, "condition": "分岐の起点 / 前提条件なし"}
	var node := SkillCatalog.find(id)
	var rank := state.skill_rank(id)
	var prerequisite := "基礎HP" if node.prerequisite == &"hp" else SkillCatalog.find(node.prerequisite).display_name
	var prerequisite_rank := state.skill_rank(node.prerequisite)
	var met := prerequisite_rank >= node.prerequisite_rank
	return {"name": node.display_name, "rank": rank, "max": node.max_rank, "amount": node.amount, "effect": {&"hp": "最大HP", &"attack": "ATK", &"defense": "DEF", &"mp": "最大MP"}[node.effect], "cost": node.price(rank), "met": met, "condition": "条件%s：%s Lv%d（現在Lv%d）" % ["達成" if met else "未達", prerequisite, node.prerequisite_rank, prerequisite_rank]}


func refresh(current: RunCarryover) -> void:
	var action_had_focus := upgrade_button.has_focus()
	state = current
	root_label.text = "永久補正　HP +%d　ATK +%d　DEF +%d　MP +%d" % [state.upgrade.hp_bonus(state.hp_upgrade_level) + state.skill_bonus(&"hp"), state.skill_bonus(&"attack"), state.skill_bonus(&"defense"), state.skill_bonus(&"mp")]
	for id: StringName in skill_rows:
		var data := _info(id)
		var card = skill_rows[id].control
		card.caption.text = data.name
		card.rank_label.text = "Lv%d / %d" % [data.rank, data.max]
		card.benefit.text = "%s +%d" % [data.effect, data.rank * data.amount]
		card.cost_label.text = "上限" if data.cost < 0 else ("%d G / 条件未達" % data.cost if not data.met else "%d G" % data.cost)
		card.progress.max_value = data.max
		card.progress.value = data.rank
		card.tooltip_text = data.condition
		card.set_pressed_no_signal(id == selected_id)
		card.queue_redraw()
	_refresh_detail()
	_refresh_entries()
	if upgrade_button.disabled and action_had_focus:
		skill_rows[selected_id].button.grab_focus()


func _refresh_detail() -> void:
	var data := _info(selected_id)
	detail_title.text = data.name
	detail_rank.text = "Lv %d / %d" % [data.rank, data.max]
	current_value.text = "現在　Lv%d　%s +%d" % [data.rank, data.effect, data.rank * data.amount]
	next_value.text = "%s +%d" % [data.effect, (data.rank + 1) * data.amount] if data.cost >= 0 else "%s +%d" % [data.effect, data.rank * data.amount]
	benefit_label.text = "次は Lv%d　（+%d）" % [data.rank + 1, data.amount] if data.cost >= 0 else "この能力は最大まで成長しています"
	requirement.text = data.condition
	price_label.text = "%d Gold" % data.cost if data.cost >= 0 else "強化上限"
	var allowed: bool = data.cost >= 0 and data.met and state.gold >= data.cost
	if selected_id != &"hp":
		allowed = state.can_purchase_skill(selected_id)
	_action(upgrade_button, data.cost, data.met, allowed)


func _action(button: Button, cost: int, prerequisite_met: bool, allowed: bool, verb: String = "強化する", complete: String = "強化上限") -> void:
	button.disabled = not allowed
	button.focus_mode = Control.FOCUS_ALL if allowed else Control.FOCUS_NONE
	if cost < 0:
		button.text = complete
	elif not prerequisite_met:
		button.text = "条件未達"
	elif state.gold < cost:
		button.text = "あと%d Gold" % (cost - state.gold)
	else:
		button.text = verb


func _refresh_entries() -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	var stage := stages[stage_choice.selected]
	var available := state.stage_available(stage)
	stage_status.text = "開始時はLv1。\n永久強化は引き継がれます。" if available else "ステージ未解放：%sをクリア" % _stage_name(stage.previous_stage)
	for index in entry_rows.size():
		var row := entry_rows[index]
		var floor_number := 11 + index * 10
		var unlocked: bool = floor_number in state.unlocked_entries.get(String(stage.id), [])
		var defeated: bool = floor_number - 1 in state.defeated_bosses.get(String(stage.id), [])
		row.title.text = "%dFから開始　%s" % [floor_number, "解放済み" if unlocked else "%d Gold" % stage.entry_costs[index]]
		row.condition.text = "中ボス撃破済み" if defeated else "条件未達：%dFの中ボスを撃破" % (floor_number - 1)
		if not available:
			row.condition.text = "条件未達：ステージを解放"
		_action(row.button, -1 if unlocked else stage.entry_costs[index], defeated and available, state.can_unlock_entry(stage, floor_number), "解放する", "解放済み")
	if previous_focus in entry_buttons and previous_focus.disabled:
		stage_choice.grab_focus()


func _stage_name(id: StringName) -> String:
	for stage in stages:
		if stage.id == id:
			return stage.display_name
	return String(id)


func focus_first_action() -> void:
	if entries.visible:
		stage_choice.grab_focus()
	else:
		skill_rows[selected_id].button.grab_focus()
