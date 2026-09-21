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
	HubUI.label(destinations, "選択後、装備を確認して出撃します。", &"MutedLabel")
	var detail := HubUI.section(columns)
	stage_art = TextureRect.new()
	stage_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	stage_art.custom_minimum_size.y = 174
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
	equipment_label = HubUI.label(equipment, "", &"BodyLabel")
	equipment_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	review_button = HubUI.button(equipment, "装備・持ち込みを見直す", func(): equipment_requested.emit())
	var departure := HubUI.section(review_columns, 1.15)
	HubUI.label(departure, "持ち込みアイテム", &"HeadingLabel")
	inventory_list = ItemCardList.new()
	inventory_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	departure.add_child(inventory_list)
	HubUI.label(departure, "装備と持ち込みを確認して、冒険へ。", &"HeadingLabel")
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
		stage_list.add_stage(stage, state.stage_available(stage))
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
		stage_details.line("全 %d 階  /  難易度：%s" % [stage.floor_count, stage.difficulty], &"GoldLabel")
		if not stage.features.is_empty():
			stage_details.line("探索の特徴", &"ItemNameLabel")
			stage_details.line(stage.features)
		if not stage.enemy_summary.is_empty():
			stage_details.line("主な敵の傾向", &"ItemNameLabel")
			stage_details.line(stage.enemy_summary, &"MutedLabel")
	UIMotion.of(stage_details).reveal()
	UIMotion.of(stage_art).reveal()

	next_button.disabled = not state.stage_available(stage) or stage.settings == null


func present_confirmation(current: RunCarryover) -> void:
	state = current
	selection_page.hide()
	confirmation_page.show()
	equipment_label.text = "現在の装備\n\n" + HubTheme.equipment_text(state)
	inventory_list.clear()
	for entry in state.inventory.entries:
		(inventory_list as ItemCardList).add_card(entry.item, entry.count)
	if inventory_list.item_count == 0:
		inventory_list.add_item("持ち込みなし  /  装備のみで出撃")
		inventory_list.set_item_disabled(0, true)
	start_choice.clear()
	for floor_number in [1, 11, 21, 31, 41]:
		if state.can_start(selected_stage, floor_number):
			start_choice.add_item("%dFから開始（Lv1・永久強化適用）" % floor_number, floor_number)
			if floor_number == starting_floor:
				start_choice.select(start_choice.item_count - 1)
	starting_floor = start_choice.get_selected_id() if start_choice.item_count > 0 else 1
	_update_start_label()
	# Focus on review rather than the destructive-to-preparation transition.
	inventory_list.grab_focus()


func _update_start_label() -> void:
	confirm_button.text = "%s・%dFから挑戦する" % [selected_stage.display_name, starting_floor]
