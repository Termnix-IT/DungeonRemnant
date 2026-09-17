class_name HubDeparture
extends Control

signal confirm_requested
signal equipment_requested
signal departure_requested

var stages: Array[StageData] = []
var selected_stage: StageData
var stage_list: ItemList
var stage_details: Label
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
	HubTheme.panel(selection_page, Vector2.ZERO, Vector2(440, 560))
	HubTheme.label(selection_page, "挑戦する場所", Vector2(24, 20), Vector2(390, 40), 25)
	stage_art = TextureRect.new()
	stage_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	HubTheme.place(stage_art, selection_page, Vector2(24, 82), Vector2(392, 230))
	stage_list = ItemList.new()
	stage_list.max_text_lines = 2
	HubTheme.place(stage_list, selection_page, Vector2(24, 330), Vector2(392, 142))
	stage_list.item_selected.connect(_select_stage)
	HubTheme.label(selection_page, "選択後、装備を確認して出撃します。", Vector2(24, 490), Vector2(392, 48), 17)
	HubTheme.panel(selection_page, Vector2(460, 0), Vector2(820, 560))
	var detail_scroll := ScrollContainer.new()
	HubTheme.place(detail_scroll, selection_page, Vector2(492, 24), Vector2(756, 442))
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stage_details = HubTheme.label(detail_scroll, "", Vector2.ZERO, Vector2(732, 442), 20)
	stage_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button = HubTheme.button(selection_page, "このステージの出撃準備へ", Vector2(492, 484), Vector2(756, 52), func(): confirm_requested.emit())
	confirmation_page = Control.new()
	add_child(confirmation_page)
	HubTheme.panel(confirmation_page, Vector2.ZERO, Vector2(550, 560))
	equipment_label = HubTheme.label(confirmation_page, "", Vector2(24, 20), Vector2(502, 436), 21)
	review_button = HubTheme.button(confirmation_page, "装備・持ち込みを見直す", Vector2(24, 486), Vector2(502, 50), func(): equipment_requested.emit())
	HubTheme.panel(confirmation_page, Vector2(570, 0), Vector2(710, 560))
	HubTheme.label(confirmation_page, "持ち込みアイテム", Vector2(594, 20), Vector2(662, 40), 25)
	inventory_list = ItemList.new()
	HubTheme.place(inventory_list, confirmation_page, Vector2(594, 80), Vector2(662, 264))
	HubTheme.label(confirmation_page, "このダンジョンに挑戦しますか？\n装備と持ち込みを確認してください。", Vector2(594, 367), Vector2(662, 86), 23)
	confirm_button = HubTheme.button(confirmation_page, "挑戦する", Vector2(594, 486), Vector2(662, 50), func(): departure_requested.emit())


func present_selection(available_stages: Array[StageData]) -> void:
	stages = available_stages
	selection_page.show()
	confirmation_page.hide()
	stage_list.clear()
	var selected_index := 0
	for index in stages.size():
		var stage := stages[index]
		stage_list.add_item("%s  /  全%d階  /  %s%s" % [stage.display_name, stage.floor_count, stage.difficulty, "" if stage.available else "  /  未開放"])
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
	selected_stage = stages[index]
	var stage := selected_stage
	stage_art.texture = stage.illustration
	stage_details.text = "%s\n\n%s\n\n全 %d 階     難易度：%s\n\n%s\n\n主な敵の傾向\n%s" % [stage.display_name, stage.description, stage.floor_count, stage.difficulty, stage.features, stage.enemy_summary]
	next_button.disabled = not stage.available or stage.settings == null


func present_confirmation(state: RunCarryover) -> void:
	selection_page.hide()
	confirmation_page.show()
	equipment_label.text = "現在の装備\n\n" + HubTheme.equipment_text(state)
	HubTheme.fill_inventory(inventory_list, state.inventory)
	if inventory_list.item_count == 0:
		inventory_list.add_item("持ち込みなし  /  装備のみで出撃")
		inventory_list.set_item_disabled(0, true)
	confirm_button.text = "%s・全%d階に挑戦する" % [selected_stage.display_name, selected_stage.floor_count]
	# Focus on review rather than the destructive-to-preparation transition.
	inventory_list.grab_focus()
