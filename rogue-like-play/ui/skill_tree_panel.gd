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
var detail_emblem: Control
var current_value: Label
var next_value: Label
var benefit_label: Label
var requirement: Label
var price_label: Label
var _displayed_ranks: Dictionary = {}
var cards: VBoxContainer
# Child cards are indented by depth and joined to their prerequisite.
const TREE_INDENT := 28.0
var _increased_skills: Array[StringName] = []


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
	# The tree sits in the same framed panel as the detail, so its summary and
	# cards read over a surface instead of the hall background.
	var skill_list := HubUI.section(abilities, 1.15, &"MainPanel")
	# Heading and the permanent total share one line, leaving the height to
	# the five cards inside the frame.
	var header := HBoxContainer.new()
	header.theme_type_variation = &"CompactRow"
	skill_list.add_child(header)
	HubUI.label(header, "冒険を重ね、力を残す", &"HeadingLabel").autowrap_mode = TextServer.AUTOWRAP_OFF
	root_label = HubUI.label(header, "", &"MutedLabel")
	root_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	root_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root_label.size_flags_vertical = Control.SIZE_SHRINK_END
	# Should a narrow window run out of room, the total trims and keeps its
	# full text in the tooltip.
	root_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root_label.mouse_filter = Control.MOUSE_FILTER_PASS
	cards = VBoxContainer.new()
	cards.theme_type_variation = &"UpgradeList"
	skill_list.add_child(cards)
	cards.draw.connect(_draw_tree)
	cards.sort_children.connect(cards.queue_redraw)
	for id: StringName in [&"hp", &"vitality", &"attack", &"defense", &"mana"]:
		var card := UpgradeCard.new()
		card.effect = &"hp" if id == &"hp" else SkillCatalog.find(id).effect
		card.branch = id != &"hp"
		card.pressed.connect(select_upgrade.bind(id))
		var depth := _depth(id)
		if depth == 0:
			cards.add_child(card)
		else:
			var row := HBoxContainer.new()
			row.theme_type_variation = &"CompactRow"
			cards.add_child(row)
			var indent := Control.new()
			indent.custom_minimum_size.x = TREE_INDENT * depth - row.get_theme_constant(&"separation")
			indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(indent)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(card)
		skill_rows[id] = {"control": card, "button": card, "title": card.caption, "effect": card.benefit}
		if id == &"hp":
			root_button = card
		else:
			nodes[id] = card
	_build_detail()
	_build_entries(layout)
	_show_tab(0)


func _prerequisite(id: StringName) -> StringName:
	return &"" if id == &"hp" else SkillCatalog.find(id).prerequisite


func _depth(id: StringName) -> int:
	var depth := 0
	var current := _prerequisite(id)
	while not current.is_empty():
		depth += 1
		current = _prerequisite(current)
	return depth


# Elbow lines from each prerequisite down to its children, drawn behind the
# cards. A met prerequisite is gold; an unmet one stays muted.
func _draw_tree() -> void:
	if state == null:
		return
	var gold := cards.get_theme_color(&"font_color", &"GoldLabel")
	var muted := cards.get_theme_color(&"font_color", &"MutedLabel")
	muted.a = 0.45
	for id: StringName in skill_rows:
		var parent_id := _prerequisite(id)
		if parent_id.is_empty():
			continue
		var parent: Control = skill_rows[parent_id].control
		var child: Control = skill_rows[id].control
		var parent_rect := Rect2(parent.global_position - cards.global_position, parent.size)
		var child_rect := Rect2(child.global_position - cards.global_position, child.size)
		var x := parent_rect.position.x + TREE_INDENT * 0.5
		var y := child_rect.get_center().y
		var color := gold if _info(id).met else muted
		cards.draw_polyline(PackedVector2Array([Vector2(x, parent_rect.end.y), Vector2(x, y), Vector2(child_rect.position.x, y)]), color, 1.5, true)


func _build_detail() -> void:
	detail = HubUI.section(abilities, 1.0, &"DetailPanel")
	detail.theme_type_variation = &"UpgradeList"
	HubUI.label(detail, "選択中の永久強化", &"MutedLabel")
	# The selected upgrade's emblem heads the detail at its stored 96px.
	var heading := HBoxContainer.new()
	heading.theme_type_variation = &"CompactRow"
	detail.add_child(heading)
	detail_emblem = Control.new()
	detail_emblem.custom_minimum_size = Vector2(96, 96)
	detail_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_emblem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail_emblem.draw.connect(func(): EmblemIcons.paint(detail_emblem, Rect2(Vector2.ZERO, detail_emblem.size), _emblem_key()))
	heading.add_child(detail_emblem)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(names)
	detail_title = HubUI.label(names, "", &"TitleLabel")
	detail_rank = HubUI.label(names, "", &"MutedLabel")
	var change := HubUI.section(detail, 1.0, &"InsetPanel")
	change.theme_type_variation = &"CompactStack"
	HubUI.label(change, "この能力による永久補正", &"MutedLabel")
	current_value = HubUI.label(change, "", &"BodyLabel")
	var arrow := Control.new()
	arrow.custom_minimum_size = Vector2(24, 18)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.draw.connect(func():
		var tone := arrow.get_theme_color(&"font_color", &"MutedLabel")
		arrow.draw_polyline(PackedVector2Array([Vector2(4, 5), Vector2(12, 13), Vector2(20, 5)]), tone, 2.0, true))
	change.add_child(arrow)
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
		# Tabs stay flat; the ornate plate is kept for actions.
		tabs[i].theme_type_variation = &"TabActive" if i == index else &"SecondaryButton"
	if state != null:
		UIMotion.of(abilities if index == 0 else entries).reveal()


func select_upgrade(id: StringName) -> void:
	UIMotion.of(current_value).reset()
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
	return {"name": node.display_name, "rank": rank, "max": node.max_rank, "amount": node.amount, "effect": {&"hp": "最大HP", &"attack": "攻撃力", &"defense": "防御力", &"mp": "最大MP"}[node.effect], "cost": node.price(rank), "met": met, "condition": "条件%s：%s Lv %d（現在 Lv %d）" % ["達成" if met else "未達", prerequisite, node.prerequisite_rank, prerequisite_rank]}


func refresh(current: RunCarryover) -> void:
	var action_had_focus := upgrade_button.has_focus()
	_increased_skills.clear()
	state = current
	root_label.text = "永久補正　HP +%d　攻撃力 +%d　防御力 +%d　MP +%d" % [state.upgrade.hp_bonus(state.hp_upgrade_level) + state.skill_bonus(&"hp"), state.skill_bonus(&"attack"), state.skill_bonus(&"defense"), state.skill_bonus(&"mp")]
	root_label.tooltip_text = root_label.text
	for id: StringName in skill_rows:
		var data := _info(id)
		if _displayed_ranks.has(id) and data.rank > _displayed_ranks[id]:
			_increased_skills.append(id)
		_displayed_ranks[id] = data.rank
		var card = skill_rows[id].control
		card.caption.text = data.name
		card.rank_label.text = "Lv %d / %d" % [data.rank, data.max]
		card.benefit.text = "%s +%d" % [data.effect, data.rank * data.amount]
		card.cost_label.text = "上限" if data.cost < 0 else ("条件未達  ·  %d G" % data.cost if not data.met else "%d G" % data.cost)
		# A locked price must not look purchasable, so it drops the gold tone.
		card.cost_label.theme_type_variation = &"MutedLabel" if data.cost >= 0 and not data.met else &"GoldLabel"
		card.progress.max_value = data.max
		card.progress.value = data.rank
		card.tooltip_text = data.condition
		card.set_pressed_no_signal(id == selected_id)
		card.queue_redraw()
		card.pips.queue_redraw()
	cards.queue_redraw()
	_refresh_detail()
	_refresh_entries()
	if upgrade_button.disabled and action_had_focus:
		skill_rows[selected_id].button.grab_focus()


# Refresh observes the finalized state; only Main's persisted-success signal
# authorizes feedback. Selection alone must never look like a purchase.
func present_upgrade() -> void:
	UIMotion.of(root_label).reveal()
	if not _increased_skills.is_empty():
		UIMotion.of(root_label).pulse(1.04, UIMotion.GOLD_TIME)
	for id: StringName in _increased_skills:
		var card = skill_rows[id].control
		UIMotion.of(card).pulse(1.025, UIMotion.GOLD_TIME)
		# The gained pip fills while the card briefly brightens.
		UIMotion.of(card).glow_in()
		UIMotion.of(card).flash(1.25)
		if id == selected_id:
			UIMotion.of(current_value).pulse(1.04, UIMotion.GOLD_TIME)
			UIMotion.of(detail_rank).reveal()
	_increased_skills.clear()


func _refresh_detail() -> void:
	var data := _info(selected_id)
	detail_title.text = data.name
	detail_rank.text = "Lv %d / %d" % [data.rank, data.max]
	detail_emblem.visible = EmblemIcons.texture(_emblem_key()) != null
	detail_emblem.queue_redraw()
	current_value.text = "現在　Lv %d　%s +%d" % [data.rank, data.effect, data.rank * data.amount]
	next_value.text = "%s +%d" % [data.effect, (data.rank + 1) * data.amount] if data.cost >= 0 else "%s +%d" % [data.effect, data.rank * data.amount]
	benefit_label.text = "次は Lv %d　（+%d）" % [data.rank + 1, data.amount] if data.cost >= 0 else "この能力は最大まで成長しています"
	requirement.text = data.condition
	price_label.text = "%d G" % data.cost if data.cost >= 0 else "強化上限"
	var allowed: bool = data.cost >= 0 and data.met and state.gold >= data.cost
	if selected_id != &"hp":
		allowed = state.can_purchase_skill(selected_id)
	_action(upgrade_button, data.cost, data.met, allowed)


func _emblem_key() -> String:
	var card = skill_rows[selected_id].control if skill_rows.has(selected_id) else null
	return "" if card == null else EmblemIcons.upgrade_key(card.effect, card.branch)


func _action(button: Button, cost: int, prerequisite_met: bool, allowed: bool, verb: String = "強化する", complete: String = "強化上限") -> void:
	button.disabled = not allowed
	button.focus_mode = Control.FOCUS_ALL if allowed else Control.FOCUS_NONE
	if cost < 0:
		button.text = complete
	elif not prerequisite_met:
		button.text = "条件未達"
	elif state.gold < cost:
		button.text = "あと%d G" % (cost - state.gold)
	else:
		button.text = verb


func _refresh_entries() -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	var stage := stages[stage_choice.selected]
	var available := state.stage_available(stage)
	stage_status.text = "開始時はLv 1。\n永久強化は引き継がれます。" if available else "ステージ未解放：%sをクリア" % _stage_name(stage.previous_stage)
	for index in entry_rows.size():
		var row := entry_rows[index]
		var floor_number := 11 + index * 10
		var unlocked: bool = floor_number in state.unlocked_entries.get(String(stage.id), [])
		var defeated: bool = floor_number - 1 in state.defeated_bosses.get(String(stage.id), [])
		row.title.text = "%dFから開始　%s" % [floor_number, "解放済み" if unlocked else "%d G" % stage.entry_costs[index]]
		row.condition.text = "中ボス撃破済み" if defeated else "条件未達：%dFの中ボスを撃破" % (floor_number - 1)
		if not available:
			row.condition.text = "条件未達：ステージを解放"
		_action(row.button, -1 if unlocked else stage.entry_costs[index], defeated and available, state.can_unlock_entry(stage, floor_number), "解放する", "解放済み")
	if previous_focus is Button and previous_focus in entry_buttons and previous_focus.disabled:
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
