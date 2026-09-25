extends CanvasLayer

signal retry_requested
signal abort_confirmed
signal abort_cancelled

const KEPT_NOTE := "装備中の5枠は保持されます。"

var confirming := false
var return_to_hub := false
var title_label: Label
var details: Label
var accept: Button
var cancel: Button
var save_label: Label
var presentation_panel: PanelContainer
var details_scroll: ScrollContainer
# Result-only sections. The abort confirmation shows `details` alone.
var summary: HBoxContainer
var stat_rows: Array[Control] = []
var floor_value: Label
var earned_value: Label
var lost_value: Label
var balance_value: Label
var kept_box: VBoxContainer
var kept_equipment: HudEquipment
var lost_box: VBoxContainer
var lost_list: ItemCardList
var lost_none: Label


func _ready() -> void:
	layer = 12
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	presentation_panel = PanelContainer.new()
	presentation_panel.theme = preload("res://ui/theme/dungeon_theme.tres")
	presentation_panel.theme_type_variation = &"MainPanel"
	presentation_panel.custom_minimum_size.x = 760
	center.add_child(presentation_panel)
	var margin := MarginContainer.new()
	presentation_panel.add_child(margin)
	var panel := VBoxContainer.new()
	panel.name = "Panel"
	margin.add_child(panel)
	title_label = Label.new()
	title_label.theme_type_variation = &"TitleLabel"
	panel.add_child(title_label)
	details_scroll = ScrollContainer.new()
	# Tall enough for the stats, kept slots and two lost cards without scrolling.
	details_scroll.custom_minimum_size.y = 440
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(details_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.add_child(body)
	summary = HBoxContainer.new()
	body.add_child(summary)
	var stats := VBoxContainer.new()
	stats.theme_type_variation = &"DetailStack"
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_child(stats)
	floor_value = _stat(stats, "到達階")
	earned_value = _stat(stats, "今回獲得")
	lost_value = _stat(stats, "失ったGold")
	balance_value = _stat(stats, "残高")
	kept_box = VBoxContainer.new()
	kept_box.theme_type_variation = &"DetailStack"
	summary.add_child(kept_box)
	HubUI.label(kept_box, "持ち帰る装備", &"MutedLabel")
	kept_equipment = HudEquipment.new()
	kept_equipment.custom_minimum_size = Vector2(260, 150)
	kept_box.add_child(kept_equipment)
	lost_box = VBoxContainer.new()
	lost_box.theme_type_variation = &"DetailStack"
	body.add_child(lost_box)
	HubUI.label(lost_box, "失ったアイテム", &"MutedLabel")
	lost_list = ItemCardList.new()
	lost_list.auto_height = true
	lost_list.focus_mode = Control.FOCUS_NONE
	lost_box.add_child(lost_list)
	lost_none = HubUI.label(lost_box, "なし", &"DescriptionLabel")
	details = Label.new()
	details.theme_type_variation = &"DescriptionLabel"
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(details)
	accept = Button.new()
	accept.theme_type_variation = &"PrimaryButton"
	accept.custom_minimum_size.y = 44
	accept.focus_mode = Control.FOCUS_NONE
	accept.pressed.connect(_accept)
	panel.add_child(accept)
	cancel = Button.new()
	cancel.theme_type_variation = &"SecondaryButton"
	cancel.text = "探索に戻る（Esc）"
	cancel.custom_minimum_size.y = 44
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(func(): abort_cancelled.emit())
	panel.add_child(cancel)
	save_label = Label.new()
	save_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_label.theme_type_variation = &"MutedLabel"
	panel.add_child(save_label)
	UIMotion.bind_buttons(panel)
	hide()


func _stat(parent: Node, caption: String) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var caption_label := HubUI.label(row, caption, &"MutedLabel")
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value := HubUI.label(row, "", &"ValueLabel")
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stat_rows.append(row)
	return value


func show_save_status(message: String) -> void:
	save_label.text = message


func present(result: Dictionary) -> void:
	save_label.text = ""
	confirming = false
	var returned_well: bool = result.cleared or result.get("safe_return", false)
	title_label.text = "冒険クリア" if result.cleared else ("無事に帰還" if result.get("safe_return", false) else ("滞在上限：強制帰還" if result.get("forced_return", false) else "冒険終了"))
	title_label.theme_type_variation = &"VictoryTitle" if returned_well else &"DefeatTitle"
	var gold_lost := int(result.gold_lost)
	floor_value.text = "%dF" % result.floor
	earned_value.text = _gold(result.earned_gold, "+")
	lost_value.text = _gold(gold_lost, "−") if gold_lost > 0 else "なし"
	lost_value.theme_type_variation = &"LossValueLabel" if gold_lost > 0 else &"ValueLabel"
	balance_value.text = _gold(result.gold)
	var equipment: Array = result.get("equipment", [])
	kept_box.visible = not equipment.is_empty()
	kept_equipment.show_slots(equipment)
	_show_losses(result)
	details.text = KEPT_NOTE
	summary.show()
	lost_box.show()
	accept.text = "拠点へ戻る（R）" if return_to_hub else "Lv1から再挑戦（R）"
	cancel.hide()
	show()
	_reveal()
	_play_sequence(result)


func _show_losses(result: Dictionary) -> void:
	lost_list.clear()
	for entry: Dictionary in result.get("lost_entries", []):
		var index := lost_list.item_count
		lost_list.add_card(entry.item, entry.count, -1, "消失")
		lost_list.set_item_selectable(index, false)
	lost_list.visible = lost_list.item_count > 0
	lost_none.visible = lost_list.item_count == 0
	# Results without item identity still list every loss by name.
	var names: PackedStringArray = []
	for label: String in result.items_lost:
		names.append("%s ×%d" % [label, result.items_lost[label]])
	lost_none.text = "、".join(names) if lost_list.item_count == 0 and not names.is_empty() else "なし"


# Values are final before this runs; the sequence only replays them in order.
func _play_sequence(result: Dictionary) -> void:
	var steps: Array[Control] = []
	steps.append_array(stat_rows)
	if kept_box.visible:
		steps.append(kept_box)
	steps.append(lost_box)
	for index in steps.size():
		UIMotion.of(steps[index]).appear(index * UIMotion.SEQUENCE_STEP_TIME)
	var earned := int(result.earned_gold)
	var gold := int(result.gold)
	UIMotion.of(earned_value).count(0, earned, _gold.bind("+"), UIMotion.SEQUENCE_STEP_TIME)
	var starting_gold := gold + int(result.gold_lost) - earned
	UIMotion.of(balance_value).count(starting_gold, gold, _gold.bind(""), UIMotion.SEQUENCE_STEP_TIME * 3)


func _gold(amount: int, prefix: String = "") -> String:
	return "%s%d G" % [prefix, amount]


func confirm_abort() -> void:
	save_label.text = ""
	confirming = true
	title_label.text = "冒険を中断しますか？"
	title_label.theme_type_variation = &"TitleLabel"
	summary.hide()
	lost_box.hide()
	details.text = "死亡時と同じペナルティが適用されます。\n\n・所持Goldの50%を失います。\n・非装備の所持枠の半数をランダムに失います（切り上げ）。\n・装備中の5枠は保持されます。\n\nGoldの端数は切り捨て。Lv・EXP・能力は再挑戦時にリセットされます。"
	accept.text = "中断してリザルトへ"
	cancel.show()
	show()
	_reveal()


func _reveal() -> void:
	details_scroll.scroll_vertical = 0
	UIMotion.of(presentation_panel).reveal(UIMotion.WINDOW_TIME)
	UIMotion.of(title_label).pulse(1.025, UIMotion.WINDOW_TIME)


func _accept() -> void:
	if confirming:
		abort_confirmed.emit()
	else:
		retry_requested.emit()
