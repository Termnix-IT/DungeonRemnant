class_name HubDeparture
extends Control

signal confirm_requested
signal equipment_requested
signal departure_requested

var stages: Array[StageData] = []
var state: RunCarryover
var start_choice: OptionButton
var starting_floor := 1
var selected_stage: StageData
var stage_list: StageCardList
var stage_details: ItemDetails
var stage_art: TextureRect
var equipment_label: Label
var equipment_rows: HudEquipment
var stage_banner: TextureRect
var carried_count: Label
var empty_carried: PanelContainer
var inventory_list: ItemList
var selection_page: Control
var confirmation_page: Control
var next_button: Button
var confirm_button: Button
var review_button: Button


func _ready() -> void:
	selection_page = Control.new()
	add_child(selection_page)
	selection_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var columns := HubUI.columns(selection_page)
	var destinations := HubUI.section(columns, 1.1)
	HubUI.label(destinations, "冒険先を選ぶ", &"HeadingLabel")
	stage_list = StageCardList.new()
	stage_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	destinations.add_child(stage_list)
	stage_list.item_selected.connect(_select_stage)
	# Enter or double-click on a stage goes straight to its sortie check.
	stage_list.item_activated.connect(func(_index: int):
		if not next_button.disabled:
			confirm_requested.emit())
	HubUI.label(destinations, "選択後、装備を確認して出撃します。", &"MutedLabel")
	var detail := HubUI.section(columns)
	stage_art = TextureRect.new()
	stage_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	stage_art.custom_minimum_size.y = 150
	detail.add_child(stage_art)
	stage_details = ItemDetails.new()
	stage_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(stage_details)
	next_button = HubUI.button(detail, "このステージの出撃準備へ", func(): confirm_requested.emit(), &"GoldButton")
	next_button.custom_minimum_size.y = 54
	confirmation_page = Control.new()
	add_child(confirmation_page)
	confirmation_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var review_columns := HubUI.columns(confirmation_page)
	var equipment := HubUI.section(review_columns, 0.85)
	HubUI.label(equipment, "出撃する冒険者", &"HeadingLabel")
	var party := HBoxContainer.new()
	party.size_flags_vertical = Control.SIZE_EXPAND_FILL
	party.alignment = BoxContainer.ALIGNMENT_CENTER
	equipment.add_child(party)
	var portrait := CharacterPreview.new()
	portrait.custom_minimum_size = Vector2(150, 230)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	party.add_child(portrait)
	var loadout := VBoxContainer.new()
	loadout.theme_type_variation = &"DetailStack"
	loadout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	party.add_child(loadout)
	# Short fixed lines: wrapping would let a zero-width first layout grow them tall.
	HubUI.label(loadout, "装備", &"MutedLabel").autowrap_mode = TextServer.AUTOWRAP_OFF
	equipment_rows = HudEquipment.new()
	equipment_rows.custom_minimum_size = Vector2(220, 150)
	loadout.add_child(equipment_rows)
	HubUI.label(loadout, "出発時の能力", &"MutedLabel").autowrap_mode = TextServer.AUTOWRAP_OFF
	equipment_label = HubUI.label(loadout, "", &"ValueLabel")
	equipment_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	review_button = HubUI.button(equipment, "装備・持ち込みを見直す", func(): equipment_requested.emit())
	var departure := HubUI.section(review_columns, 1.15)
	stage_banner = TextureRect.new()
	stage_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	stage_banner.custom_minimum_size.y = 96
	departure.add_child(stage_banner)
	var carried_heading := HBoxContainer.new()
	departure.add_child(carried_heading)
	var carried_title := HubUI.label(carried_heading, "持ち込みアイテム", &"HeadingLabel")
	carried_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carried_count = HubUI.label(carried_heading, "", &"MutedLabel")
	carried_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	carried_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inventory_list = ItemCardList.new()
	inventory_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	departure.add_child(inventory_list)
	# An empty loadout is a valid choice, so it reads as a note rather than a
	# disabled row in an otherwise blank list.
	empty_carried = PanelContainer.new()
	empty_carried.theme_type_variation = &"InsetPanel"
	empty_carried.size_flags_vertical = Control.SIZE_EXPAND_FILL
	departure.add_child(empty_carried)
	var empty_text := VBoxContainer.new()
	empty_text.alignment = BoxContainer.ALIGNMENT_CENTER
	empty_carried.add_child(empty_text)
	for line: Array in [["持ち込みアイテムはありません", &"ItemNameLabel"], ["装備のみで出撃します。回復薬は倉庫・ショップから用意できます。", &"MutedLabel"]]:
		HubUI.label(empty_text, line[0], line[1]).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_choice = OptionButton.new()
	start_choice.custom_minimum_size.y = 40
	departure.add_child(start_choice)
	start_choice.item_selected.connect(func(index: int): starting_floor = start_choice.get_item_id(index); _update_start_label())
	confirm_button = HubUI.button(departure, "挑戦する", func(): departure_requested.emit(), &"GoldButton")
	confirm_button.custom_minimum_size.y = 54


func present_selection(available_stages: Array[StageData], progress: RunCarryover = null) -> void:
	state = progress if progress != null else RunCarryover.new()
	stages = available_stages
	selection_page.show()
	confirmation_page.hide()
	stage_list.clear()
	var selected_index := 0
	for index in stages.size():
		var stage := stages[index]
		stage_list.add_stage(stage, state.stage_available(stage), _unlock_hint(stage))
		if stage == selected_stage:
			selected_index = index
	if not stages.is_empty():
		stage_list.select(selected_index)
		_select_stage(selected_index)
	else:
		selected_stage = null
		stage_art.texture = null
		stage_details.text = "挑戦できるステージはありません。"
		next_button.disabled = true
	stage_list.grab_focus()


func _unlock_hint(stage: StageData) -> String:
	for other in stages:
		if other.id == stage.previous_stage:
			return "%sを踏破で解放" % other.display_name
	return ""


func _select_stage(index: int) -> void:
	if selected_stage != stages[index]:
		starting_floor = 1
	selected_stage = stages[index]
	var stage := selected_stage
	stage_art.texture = stage.illustration
	stage_art.visible = stage.illustration != null
	stage_details.reset()
	stage_details.line(stage.display_name, &"HeadingLabel")
	stage_details.line(stage.description)
	if stage.available:
		stage_details.line("全%d階  /  難易度：%s" % [stage.floor_count, stage.difficulty], &"GoldLabel")
		if not stage.features.is_empty():
			stage_details.line("探索の特徴", &"ItemNameLabel")
			stage_details.line(stage.features)
		if not stage.enemy_summary.is_empty():
			stage_details.line("主な敵の傾向", &"ItemNameLabel")
			stage_details.line(stage.enemy_summary, &"MutedLabel")
		if not stage.bosses.is_empty():
			var defeated: Array = state.defeated_bosses.get(String(stage.id), [])
			var guardians: Array[String] = []
			for guardian in stage.bosses.size():
				var floor_number := mini((guardian + 1) * 10, stage.floor_count)
				guardians.append("%dF %s" % [floor_number, stage.bosses[guardian].display_name if floor_number in defeated else "？？？"])
			stage_details.line("守護者　" + "　／　".join(guardians), &"MutedLabel")
	UIMotion.of(stage_details).reveal()
	UIMotion.of(stage_art).reveal()

	next_button.disabled = not state.stage_available(stage) or stage.settings == null


func present_confirmation(current: RunCarryover) -> void:
	state = current
	selection_page.hide()
	confirmation_page.show()
	equipment_rows.show_equipment(state.equipment)
	var stats := state.preparation_stats()
	equipment_label.text = "HP %d  /  攻撃力 %d\n防御力 %d  /  射程 %d" % [stats.hp, stats.attack, stats.defense, stats.reach]
	stage_banner.texture = selected_stage.illustration
	stage_banner.visible = stage_banner.texture != null
	inventory_list.clear()
	for entry in state.inventory.entries:
		(inventory_list as ItemCardList).add_card(entry.item, entry.count)
	var carried := inventory_list.item_count > 0
	inventory_list.visible = carried
	empty_carried.visible = not carried
	carried_count.text = "%d / %d 枠" % [state.inventory.entries.size(), state.inventory.max_entries] if carried else ""
	start_choice.clear()
	for floor_number in [1, 11, 21, 31, 41]:
		if state.can_start(selected_stage, floor_number):
			start_choice.add_item("%dFから開始（Lv1・永久強化適用）" % floor_number, floor_number)
			if floor_number == starting_floor:
				start_choice.select(start_choice.item_count - 1)
	starting_floor = start_choice.get_selected_id() if start_choice.item_count > 0 else 1
	_update_start_label()
	# Focus on review rather than the destructive-to-preparation transition.
	if carried:
		inventory_list.grab_focus()
	else:
		review_button.grab_focus()


func _update_start_label() -> void:
	confirm_button.text = "%s・%dFから挑戦する" % [selected_stage.display_name, starting_floor]
