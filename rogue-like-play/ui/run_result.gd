extends CanvasLayer

signal retry_requested
signal abort_confirmed
signal abort_cancelled

# After a defeat the dungeon darkens slowly before the panel rises, so the
# fall registers. Input waits for the panel; the result is already saved.
const DEFEAT_BEAT := 0.7
# Results sit on an illustration of how the run ended; the shade over it is
# lighter than the plain veil so the scene shows around the panel.
const CLEAR_ART := preload("res://art/results/clear.png")
const DEFEAT_ART := preload("res://art/results/defeat.png")
# Lost items show as their icons in a faint red cast.
const LOST_COLUMNS := 5
const LOST_TINT := Color(1.0, 0.72, 0.68)
const VEIL := Color(0.01, 0.02, 0.04, 0.9)
const SCENE_VEIL := Color(0.01, 0.02, 0.04, 0.42)

var confirming := false
var return_to_hub := false
var title_label: Label
var cause_label: Label
var shade: ColorRect
var backdrop: TextureRect
var _accept_after_msec := 0
var details: Label
var accept: Button
var cancel: Button
var key_guide: KeyGuide
var back_hint: Button
var save_label: Label
var presentation_panel: PanelContainer
var details_scroll: ScrollContainer
# Result-only sections. The abort confirmation shows `details` alone.
var summary: VBoxContainer
var stat_rows: Array[Control] = []
var floor_value: Label
var earned_value: Label
var lost_value: Label
var balance_value: Label
var level_value: Label
var kills_value: Label
var turns_value: Label
var kept_box: VBoxContainer
var kept_equipment: HudEquipment
var lost_box: VBoxContainer
var lost_grid: IconGrid
var lost_none: Label


func _ready() -> void:
	layer = 12
	backdrop = TextureRect.new()
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	shade = ColorRect.new()
	shade.color = VEIL
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
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title_label)
	cause_label = HubUI.label(panel, "", &"DescriptionLabel")
	cause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_scroll = ScrollContainer.new()
	# Tall enough for the stats, kept slots and two lost cards without scrolling.
	details_scroll.custom_minimum_size.y = 440
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(details_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.add_child(body)
	# The outcome reads as a few large figures in two rows (the journey, then
	# the Gold) rather than a column of caption-and-value lines, with what came
	# home and what was lost side by side beneath.
	summary = VBoxContainer.new()
	summary.theme_type_variation = &"DetailStack"
	body.add_child(summary)
	var journey := _tile_row(summary)
	floor_value = _stat(journey, "到達階")
	level_value = _stat(journey, "到達Lv")
	kills_value = _stat(journey, "倒した敵")
	turns_value = _stat(journey, "経過ターン")
	var purse := _tile_row(summary)
	earned_value = _stat(purse, "今回獲得")
	earned_value.theme_type_variation = &"MoneyValueLabel"
	lost_value = _stat(purse, "失ったGold")
	balance_value = _stat(purse, "残高")
	balance_value.theme_type_variation = &"MoneyValueLabel"
	var goods := HBoxContainer.new()
	goods.theme_type_variation = &"DetailStack"
	body.add_child(goods)
	kept_box = VBoxContainer.new()
	kept_box.theme_type_variation = &"DetailStack"
	goods.add_child(kept_box)
	HubUI.label(kept_box, "持ち帰る装備", &"MutedLabel")
	kept_equipment = HudEquipment.new()
	kept_equipment.custom_minimum_size = Vector2(260, 150)
	kept_box.add_child(kept_equipment)
	lost_box = VBoxContainer.new()
	lost_box.theme_type_variation = &"DetailStack"
	lost_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goods.add_child(lost_box)
	HubUI.label(lost_box, "失ったアイテム", &"MutedLabel")
	lost_grid = IconGrid.new()
	lost_grid.read_only = true
	lost_grid.columns = LOST_COLUMNS
	lost_grid.custom_minimum_size.y = 150
	lost_grid.modulate = LOST_TINT
	lost_box.add_child(lost_grid)
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
	cancel.text = "探索に戻る"
	cancel.custom_minimum_size.y = 44
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(func(): abort_cancelled.emit())
	panel.add_child(cancel)
	# Keys show as caps under the buttons instead of "(R)" in their labels.
	key_guide = KeyGuide.new()
	key_guide.alignment = BoxContainer.ALIGNMENT_END
	panel.add_child(key_guide)
	key_guide.add_hint("R", "Start", "決定")
	back_hint = key_guide.add_hint("Esc", "B", "戻る")
	save_label = Label.new()
	save_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_label.theme_type_variation = &"MutedLabel"
	panel.add_child(save_label)
	UIMotion.bind_buttons(panel)
	hide()


func _tile_row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	return row


# One figure: a small caption above a large value, centred in an equal share
# of its row.
func _stat(parent: Node, caption: String) -> Label:
	var tile := VBoxContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(tile)
	var caption_label := HubUI.label(tile, caption, &"MutedLabel")
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var value := HubUI.label(tile, "", &"ValueLabel")
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_rows.append(tile)
	return value


func show_save_status(message: String) -> void:
	save_label.text = message


func present(result: Dictionary) -> void:
	# The save status may arrive before a deferred present (after a defeat
	# presentation); keep it. retry_run clears it for the next result.
	confirming = false
	var returned_well: bool = result.cleared or result.get("safe_return", false)
	title_label.text = "冒険クリア" if result.cleared else ("無事に帰還" if result.get("safe_return", false) else ("滞在上限：強制帰還" if result.get("forced_return", false) else "冒険終了"))
	title_label.theme_type_variation = &"VictoryTitle" if returned_well else &"DefeatTitle"
	backdrop.texture = CLEAR_ART if returned_well else DEFEAT_ART
	backdrop.show()
	shade.color = SCENE_VEIL
	var gold_lost := int(result.gold_lost)
	floor_value.text = "%dF" % result.floor
	earned_value.text = _gold(result.earned_gold, "+")
	lost_value.text = _gold(gold_lost, "−") if gold_lost > 0 else "なし"
	lost_value.theme_type_variation = &"LossValueLabel" if gold_lost > 0 else &"ValueLabel"
	balance_value.text = _gold(result.gold)
	level_value.text = "Lv %d" % int(result.get("level", 1))
	kills_value.text = "%d体" % int(result.get("kills", 0))
	turns_value.text = str(int(result.get("turns", 0)))
	cause_label.text = _cause(result)
	cause_label.visible = not cause_label.text.is_empty()
	var equipment: Array = result.get("equipment", [])
	kept_box.visible = not equipment.is_empty()
	kept_equipment.show_slots(equipment)
	_show_losses(result)
	details.text = ""
	summary.show()
	lost_box.show()
	accept.text = "拠点へ戻る" if return_to_hub else "Lv1から再挑戦"
	cancel.hide()
	back_hint.hide()
	var beat := DEFEAT_BEAT if result.get("defeated", false) else 0.0
	_accept_after_msec = Time.get_ticks_msec() + int(beat * 1000)
	show()
	if beat > 0.0:
		details_scroll.scroll_vertical = 0
		UIMotion.of(shade).appear(0.0, beat)
		UIMotion.of(backdrop).appear(0.0, beat)
		UIMotion.of(presentation_panel).appear(beat, UIMotion.WINDOW_TIME)
	else:
		_reveal()
	_play_sequence(result, beat)


# Whether confirm keys and the accept button act yet (false during the beat).
func ready_for_input() -> bool:
	return Time.get_ticks_msec() >= _accept_after_msec


func _cause(result: Dictionary) -> String:
	if result.cleared:
		return "最深部の主を討ち果たした。"
	if result.get("safe_return", false):
		return "%dFの脱出口から拠点へ帰還した。" % result.floor
	if result.get("forced_return", false):
		return "%dFで滞在の限界を迎え、拠点へ引き戻された。" % result.floor
	if result.get("defeated", false):
		var by: String = result.get("defeated_by", "")
		return "%dFで%sに倒された。" % [result.floor, by] if not by.is_empty() else "%dFで力尽きた。" % result.floor
	return "%dFで冒険を中断した。" % result.floor if result.has("level") else ""


func _show_losses(result: Dictionary) -> void:
	var rows: Array[Dictionary] = []
	for entry: Dictionary in result.get("lost_entries", []):
		rows.append({"index": rows.size(), "item": entry.item, "count": entry.count})
	lost_grid.show_rows(rows)
	lost_grid.visible = not rows.is_empty()
	lost_none.visible = rows.is_empty()
	# Results without item identity still list every loss by name.
	var names: PackedStringArray = []
	for label: String in result.items_lost:
		names.append("%s ×%d" % [label, result.items_lost[label]])
	lost_none.text = "、".join(names) if rows.is_empty() and not names.is_empty() else "なし"


# Values are final before this runs; the sequence only replays them in order.
func _play_sequence(result: Dictionary, delay: float = 0.0) -> void:
	var steps: Array[Control] = []
	steps.append_array(stat_rows)
	if kept_box.visible:
		steps.append(kept_box)
	steps.append(lost_box)
	for index in steps.size():
		UIMotion.of(steps[index]).appear(delay + index * UIMotion.SEQUENCE_STEP_TIME)
	var earned := int(result.earned_gold)
	var gold := int(result.gold)
	UIMotion.of(earned_value).count(0, earned, _gold.bind("+"), delay + UIMotion.SEQUENCE_STEP_TIME)
	var starting_gold := gold + int(result.gold_lost) - earned
	UIMotion.of(balance_value).count(starting_gold, gold, _gold.bind(""), delay + UIMotion.SEQUENCE_STEP_TIME * 3)


func _gold(amount: int, prefix: String = "") -> String:
	return "%s%d G" % [prefix, amount]


func confirm_abort() -> void:
	save_label.text = ""
	confirming = true
	_accept_after_msec = 0
	cause_label.hide()
	title_label.text = "冒険を中断しますか？"
	# The question is not an outcome yet: no scene, the plain dark veil.
	backdrop.hide()
	shade.color = VEIL
	title_label.theme_type_variation = &"TitleLabel"
	summary.hide()
	lost_box.hide()
	details.text = "死亡時と同じペナルティが適用されます。\n\n・所持Goldの50%を失います。\n・非装備の所持枠の半数をランダムに失います（切り上げ）。\n・装備中の5枠は保持されます。\n\nGoldの端数は切り捨て。Lv・EXP・能力は再挑戦時にリセットされます。"
	accept.text = "中断してリザルトへ"
	cancel.show()
	back_hint.show()
	show()
	_reveal()


func _reveal() -> void:
	details_scroll.scroll_vertical = 0
	UIMotion.of(presentation_panel).reveal(UIMotion.WINDOW_TIME)
	UIMotion.of(title_label).pulse(1.025, UIMotion.WINDOW_TIME)


func _accept() -> void:
	if not ready_for_input():
		return
	if confirming:
		abort_confirmed.emit()
	else:
		retry_requested.emit()
