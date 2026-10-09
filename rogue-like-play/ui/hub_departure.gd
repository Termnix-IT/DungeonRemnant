class_name HubDeparture
extends Control

# Departure, in the shared grammar, on one screen: the stages on the left and
# everything about setting out in the right column, so choosing where to go
# and starting the run are one place instead of two steps.
# The stages are a map on a dark slab from the screen's left edge: each stage
# a diorama (its dungeon on an oval island) set off the straight line, the
# second higher than the first, joined by a dotted road that is lit as far
# as the stages are open; a stage not yet open stands smaller and dark, so
# the eye goes to the ones that can be played. The slab is dark enough that
# the hall's weapon racks and candles do not show between the islands.
# The right column reads top to bottom in the order of the decision: the
# chosen stage (its facts, description and guardians), what she takes (the
# five equipment slots and how much she carries, with a way to the
# preparation screen), her stats for the run, the start floor, and the one
# primary action.

signal equipment_requested
signal departure_requested

# Each stage's height on the map, as a share of it; stages alternate so the
# road never runs straight.
const MAP_ROWS := [0.62, 0.3, 0.58, 0.34]
const ROAD_DOT_GAP := 16.0
# The five slots in a row under the stage, small enough to share the column.
const SLOT_SIZE := 64.0
const SLOT_ICON := 48.0
# A stage not yet open, against an open one.
const LOCKED_SCALE := 0.74

var stages: Array[StageData] = []
var state: RunCarryover
var start_choice: SegmentedChoice
# The start floor when there is only one: a choice of one is not a choice.
var start_only: Label
var starting_floor := 1
var selected_stage: StageData
var map: Control
var stage_nodes: Array[StageMapNode] = []
var stage_details: ItemDetails
var stage_title: Label
var stage_facts: Label
var slot_cells: Array[ItemCell] = []
var carried_rule: HintMark
var start_rule: HintMark
var carried_count: Label
var hero_stats: HeroStats
var confirm_button: Button
var review_button: Button
var _selection_detail: VBoxContainer
var _start_row: HBoxContainer


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var left := HubUI.open_column(columns, 2.1, &"SlabSolid")
	map = Control.new()
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(map)
	map.draw.connect(_draw_road)
	map.resized.connect(_place_stages)
	_selection_detail = HubUI.open_column(columns, 1.0, &"SlabSolidEnd")
	_build_detail(_selection_detail)


func _build_detail(column: VBoxContainer) -> void:
	column.theme_type_variation = &"DetailStack"
	stage_title = HubUI.label(column, "", &"HeadingLabel")
	var facts_row := HBoxContainer.new()
	facts_row.theme_type_variation = &"CompactRow"
	column.add_child(facts_row)
	stage_facts = HubUI.label(facts_row, "", &"NoteLabel")
	stage_facts.autowrap_mode = TextServer.AUTOWRAP_OFF
	stage_facts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	HintMark.make(facts_row, "10階ごとに中ボス、50階に主がいる。中ボスを倒すと脱出口から帰れる。", HubSettings.TOPIC_RUN)
	stage_details = ItemDetails.new()
	# Long guardian lists scroll from the keyboard too.
	stage_details.focus_mode = Control.FOCUS_ALL
	column.add_child(stage_details)
	var gap := HubUI.space(column)
	stage_details.fit_lines(gap, 60.0)
	HubUI.rule(column)
	# What she takes: the five slots, how much she carries, and the way to
	# change either.
	var kit_heading := HBoxContainer.new()
	kit_heading.theme_type_variation = &"CompactRow"
	column.add_child(kit_heading)
	var kit_title := HubUI.label(kit_heading, "持ち込む装備", &"NoteLabel")
	kit_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	kit_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kit_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	review_button = HubUI.button(kit_heading, "準備を開く  ›", func(): equipment_requested.emit(), &"TextAction")
	_build_slots(column)
	var carried_row := HBoxContainer.new()
	carried_row.theme_type_variation = &"CompactRow"
	column.add_child(carried_row)
	var carried_title := HubUI.label(carried_row, "持ち込み", &"NoteLabel")
	carried_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	carried_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	carried_rule = HintMark.make(carried_row, "倒れたり中断したりすると、持ち込みのおよそ半分を失う。装備中の5枠は失わない。", HubSettings.TOPIC_LOSS)
	var carried_gap := Control.new()
	carried_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carried_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carried_row.add_child(carried_gap)
	carried_count = HubUI.label(carried_row, "", &"BodyLabel")
	carried_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	HubUI.rule(column)
	# Her stats for this run, all four rows, above the floor choice.
	hero_stats = HeroStats.new()
	hero_stats.visible = false
	add_child(hero_stats)
	# The unlocked start floors as text tabs; what every start shares is said
	# once beside them.
	_start_row = HBoxContainer.new()
	_start_row.theme_type_variation = &"CompactRow"
	column.add_child(_start_row)
	var start_caption := HubUI.label(_start_row, "開始階", &"NoteLabel")
	start_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	start_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	start_rule = HintMark.make(_start_row, "どの階から始めてもLv 1。永久強化と装備・持ち込みは引き継ぐ。", HubSettings.TOPIC_GROWTH)
	start_choice = SegmentedChoice.new()
	start_choice.option_role = &"CategoryTab"
	_start_row.add_child(start_choice)
	start_only = HubUI.label(_start_row, "", &"BodyLabel")
	start_only.autowrap_mode = TextServer.AUTOWRAP_OFF
	start_only.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	start_choice.item_selected.connect(func(index: int): starting_floor = start_choice.get_item_id(index); _update_action())
	hero_stats.move_stats_to(column, _start_row.get_index(), true)
	confirm_button = HubUI.primary_action(column, "挑戦する", func(): departure_requested.emit())


# The five slots as a row of lit squares, named by their tooltips.
func _build_slots(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"CompactRow"
	column.add_child(row)
	for slot in Equipment.SLOT_NAMES.size():
		var cell := ItemCell.new()
		cell.theme_type_variation = &"SlotCell"
		cell.custom_minimum_size = Vector2.ONE * SLOT_SIZE
		cell.icon_size = SLOT_ICON
		cell.symbol = ItemGlyph.slot_symbol(slot)
		cell.draggable = false
		cell.toggle_mode = false
		cell.focus_mode = Control.FOCUS_NONE
		row.add_child(cell)
		slot_cells.append(cell)


# Shows the stages and what she takes; with to_action, the chosen stage is the
# last one and focus waits on the primary action (the lobby's shortcut).
func present_selection(available_stages: Array[StageData], progress: RunCarryover = null, to_action := false) -> void:
	state = progress if progress != null else RunCarryover.new()
	stages = available_stages
	for node in stage_nodes:
		map.remove_child(node)
		node.queue_free()
	stage_nodes.clear()
	var selected_index := 0
	for index in stages.size():
		var node := StageMapNode.new()
		map.add_child(node)
		node.show_stage(stages[index], state.stage_available(stages[index]), _unlock_hint(stages[index]))
		node.focus_entered.connect(_select_stage.bind(index))
		node.pressed.connect(_select_stage.bind(index))
		# Enter on the chosen stage goes to the action (個別画面のUI文法).
		node.gui_input.connect(func(event: InputEvent):
			if event.is_action_pressed("ui_accept") and not event.is_echo():
				node.accept_event()
				_select_stage(index)
				if not confirm_button.disabled:
					confirm_button.grab_focus())
		stage_nodes.append(node)
		if stages[index] == selected_stage:
			selected_index = index
	_place_stages()
	refresh_kit(state)
	if not stages.is_empty():
		_select_stage(selected_index)
		if to_action and not confirm_button.disabled:
			confirm_button.grab_focus()
		else:
			stage_nodes[selected_index].grab_focus()
	else:
		selected_stage = null
		stage_title.text = ""
		stage_details.reset()
		stage_details.line("挑戦できるステージはありません。", &"NoteLabel")
		confirm_button.disabled = true


# What she takes and her stats, again after the preparation screen changed them.
func refresh_kit(current: RunCarryover) -> void:
	state = current
	for slot in slot_cells.size():
		var worn := state.equipment.slots[slot]
		slot_cells[slot].show_item(worn)
		slot_cells[slot].tooltip_text = ItemTooltipList.description(worn) if worn != null else Equipment.SLOT_NAMES[slot]
	carried_count.text = "%d / %d 枠" % [state.inventory.entries.size(), state.inventory.max_entries]
	hero_stats.show_stats(state.preparation_stats())


func _unlock_hint(stage: StageData) -> String:
	for other in stages:
		if other.id == stage.previous_stage:
			return "%sを踏破で解放" % other.display_name
	return ""


# Stages spread across the map from left to right, each on its own height.
func _place_stages() -> void:
	if stage_nodes.is_empty():
		return
	var count := stage_nodes.size()
	var width := map.size.x / count
	# Islands a little wider than their share: their squares may overlap,
	# their heights never line up.
	var extent := minf(width * 1.15, map.size.y * 0.66)
	for index in count:
		var node := stage_nodes[index]
		var share := 1.0 if node.unlocked else LOCKED_SCALE
		node.size = Vector2(extent, extent / StageMapNode.ART_SHARE * 0.98) * share
		var centre := Vector2(width * (index + 0.5), map.size.y * MAP_ROWS[index % MAP_ROWS.size()])
		node.position = (centre - node.size * 0.5).round()
	map.queue_redraw()


# A dotted road from each stage's foot to the next, bending between their
# heights; lit up to the last open stage.
func _draw_road() -> void:
	var rail := map.get_theme_color(&"rail", &"HubLobby")
	var muted := map.get_theme_color(&"font_color", &"MutedLabel")
	for index in stage_nodes.size() - 1:
		var from := stage_nodes[index].position + stage_nodes[index].foot()
		var to := stage_nodes[index + 1].position + stage_nodes[index + 1].foot()
		var bend := (from + to) * 0.5 + Vector2(0, maxf(from.y, to.y) - (from.y + to.y) * 0.5 + 40.0)
		var open := stage_nodes[index + 1].unlocked
		var length := from.distance_to(to) * 1.2
		var dots := int(length / ROAD_DOT_GAP)
		for dot in range(2, dots - 1):
			var t := float(dot) / dots
			var point := from.lerp(bend, t).lerp(bend.lerp(to, t), t)
			var tone := Color(rail, 0.85) if open else Color(muted, 0.35)
			map.draw_circle(point, 2.5 if open else 2.0, tone)


func _select_stage(index: int) -> void:
	if index < 0 or index >= stages.size():
		return
	if selected_stage != stages[index]:
		starting_floor = 1
	selected_stage = stages[index]
	for other in stage_nodes.size():
		stage_nodes[other].set_pressed_no_signal(other == index)
		stage_nodes[other].queue_redraw()
	var stage := selected_stage
	stage_title.text = stage.display_name
	stage_facts.text = "全%d階　·　難易度 %s" % [stage.floor_count, stage.difficulty] if stage.available else "未解放"
	stage_details.reset()
	stage_details.line(stage.description, &"BodyLabel")
	if stage.available:
		stage_details.line("\n".join(guardian_lines(stage)))
	_fill_start_floors()
	UIMotion.reveal_selection([_selection_detail])


# The start floors the chosen stage has opened, and the action's words.
func _fill_start_floors() -> void:
	var open := state.stage_available(selected_stage) and selected_stage.settings != null
	start_choice.clear()
	if open:
		for floor_number in [1, 11, 21, 31, 41]:
			if state.can_start(selected_stage, floor_number):
				start_choice.add_item("%dF" % floor_number, floor_number)
				if floor_number == starting_floor:
					start_choice.select(start_choice.item_count - 1)
	starting_floor = start_choice.get_selected_id() if start_choice.item_count > 0 else 1
	start_choice.visible = start_choice.item_count > 1
	start_only.visible = not start_choice.visible
	start_only.text = "%dF" % starting_floor if open else "—"
	confirm_button.disabled = not open
	_update_action()


# The guardians in a few lines: how many have fallen, those by name, and the
# next one still unknown. A line per unknown floor would only repeat that
# one stands every tenth floor.
func guardian_lines(stage: StageData) -> Array[String]:
	var lines: Array[String] = []
	if stage.bosses.is_empty():
		return lines
	var defeated: Array = state.defeated_bosses.get(String(stage.id), [])
	var fallen: Array[String] = []
	var next := ""
	for guardian in stage.bosses.size():
		var floor_number := mini((guardian + 1) * 10, stage.floor_count)
		if floor_number in defeated:
			fallen.append("%dF %s" % [floor_number, stage.bosses[guardian].display_name])
		elif next.is_empty():
			next = "次　%dF ？？？" % floor_number
	lines.append("守護者　%d / %d 撃破" % [fallen.size(), stage.bosses.size()])
	lines.append_array(fallen)
	if not next.is_empty():
		lines.append(next)
	return lines


func _update_action() -> void:
	if selected_stage == null:
		return
	if confirm_button.disabled:
		confirm_button.text = "%sは未解放" % selected_stage.display_name
	else:
		confirm_button.text = "%s・%dFから挑戦する" % [selected_stage.display_name, starting_floor]


# Opening the screen: the stages arrive one by one, the column a beat later.
func play_entrance() -> void:
	for index in stage_nodes.size():
		UIMotion.of(stage_nodes[index]).appear(UIMotion.STAGGER_TIME * index, UIMotion.ENTER_TIME)
	UIMotion.of(_selection_detail).appear(UIMotion.STAGGER_TIME)
	for index in slot_cells.size():
		UIMotion.of(slot_cells[index]).appear(UIMotion.STAGGER_TIME + UIMotion.ROW_STAGGER * index, UIMotion.ROW_TIME)


# R (Y on a gamepad) opens the preparation screen, as the key guide says.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R
	var pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y
	if key or pad:
		get_viewport().set_input_as_handled()
		equipment_requested.emit()
