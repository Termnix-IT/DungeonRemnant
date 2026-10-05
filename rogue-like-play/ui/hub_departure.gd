class_name HubDeparture
extends Control

# Departure, in the shared grammar, in two steps.
# Stage selection is a map on a slab from the screen's left edge: each stage
# a diorama (its dungeon on an oval island) set off the straight line, the
# second higher than the first, joined by a dotted road that is lit as far
# as the stages are open; a stage not yet open stands smaller and dark, so
# the eye goes to the ones that can be played. The right column shows the
# chosen stage's painting (what lies inside, where the map shows it from
# outside), describes it and holds the one primary action.
# The sortie check shows what she takes (equipment and carried goods) on the
# left, the chosen stage and its start floor with the one action in the
# middle, and the heroine with her stats for the run on the right.

signal confirm_requested
signal equipment_requested
signal departure_requested

# Each stage's height on the map, as a share of it; stages alternate so the
# road never runs straight.
const MAP_ROWS := [0.62, 0.3, 0.58, 0.34]
const ROAD_DOT_GAP := 16.0
const BANNER_SIZE := 220.0
# A stage not yet open, against an open one.
const LOCKED_SCALE := 0.74
const EDGE_FADE := preload("res://ui/edge_fade.gdshader")

var stages: Array[StageData] = []
var state: RunCarryover
var start_choice: SegmentedChoice
var starting_floor := 1
var selected_stage: StageData
var map: Control
var stage_nodes: Array[StageMapNode] = []
var stage_details: ItemDetails
var stage_title: Label
var stage_facts: Label
var stage_art: TextureRect
var equipment_rows: HudEquipment
var stage_banner: TextureRect
var banner_title: Label
var carried_rule: HintMark
var start_rule: HintMark
var carried_count: Label
var inventory_list: ItemCardList
var hero_stats: HeroStats
var selection_page: Control
var confirmation_page: Control
var next_button: Button
var confirm_button: Button
var review_button: Button
var _selection_detail: VBoxContainer
var _flow := 0.0


func _ready() -> void:
	selection_page = Control.new()
	add_child(selection_page)
	selection_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	selection_page.add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var left := HubUI.open_column(columns, 2.1, &"SlabVeilWide")
	map = Control.new()
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(map)
	map.draw.connect(_draw_road)
	map.resized.connect(_place_stages)
	_selection_detail = HubUI.open_column(columns, 1.0, &"SlabSolidEnd")
	_build_stage_detail(_selection_detail)
	confirmation_page = Control.new()
	add_child(confirmation_page)
	confirmation_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_confirmation(confirmation_page)


func _build_stage_detail(column: VBoxContainer) -> void:
	column.theme_type_variation = &"DetailStack"
	stage_title = HubUI.label(column, "", &"HeadingLabel")
	var facts_row := HBoxContainer.new()
	facts_row.theme_type_variation = &"CompactRow"
	column.add_child(facts_row)
	stage_facts = HubUI.label(facts_row, "", &"NoteLabel")
	stage_facts.autowrap_mode = TextServer.AUTOWRAP_OFF
	stage_facts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	HintMark.make(facts_row, "10階ごとに中ボス、50階に主がいる。中ボスを倒すと脱出口から帰れる。", HubSettings.TOPIC_RUN)
	HubUI.rule(column)
	# The painting melts into the slab instead of reading as a framed picture.
	stage_art = TextureRect.new()
	stage_art.material = ShaderMaterial.new()
	(stage_art.material as ShaderMaterial).shader = EDGE_FADE
	stage_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	stage_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_art.size_flags_stretch_ratio = 1.4
	stage_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stage_art)
	stage_details = ItemDetails.new()
	stage_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Long guardian lists scroll from the keyboard too.
	stage_details.focus_mode = Control.FOCUS_ALL
	column.add_child(stage_details)
	next_button = HubUI.primary_action(column, "出撃準備へ", func(): confirm_requested.emit())


func _build_confirmation(parent: Control) -> void:
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	parent.add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Left: what she takes.
	var kit := HubUI.open_column(columns, 0.95, &"SlabSolid")
	kit.theme_type_variation = &"DetailStack"
	HubUI.label(kit, "装備", &"NoteLabel")
	equipment_rows = HudEquipment.new()
	kit.add_child(equipment_rows)
	HubUI.rule(kit)
	var carried_heading := HBoxContainer.new()
	carried_heading.theme_type_variation = &"CompactRow"
	kit.add_child(carried_heading)
	var carried_title := HubUI.label(carried_heading, "持ち込み", &"NoteLabel")
	carried_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	carried_rule = HintMark.make(carried_heading, "倒れたり中断したりすると、持ち込みのおよそ半分を失う。装備中の5枠は失わない。", HubSettings.TOPIC_LOSS)
	var carried_gap := Control.new()
	carried_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carried_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carried_heading.add_child(carried_gap)
	carried_count = HubUI.label(carried_heading, "", &"NoteLabel")
	carried_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	inventory_list = ItemCardList.new()
	inventory_list.theme_type_variation = &"OpenCardList"
	inventory_list.empty_text = "持ち込みの品はない"
	inventory_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kit.add_child(inventory_list)
	HubUI.rule(kit)
	review_button = HubUI.button(kit, "装備・持ち込みを見直す", func(): equipment_requested.emit(), &"TextAction")
	review_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# Middle: where she goes, from which floor, and the one action.
	var trip := HubUI.open_column(columns, 1.1, &"SlabVeil")
	trip.theme_type_variation = &"DetailStack"
	stage_banner = TextureRect.new()
	stage_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# The island takes the column's spare height.
	stage_banner.custom_minimum_size = Vector2.ONE * BANNER_SIZE
	stage_banner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trip.add_child(stage_banner)
	banner_title = HubUI.label(trip, "", &"HeadingLabel")
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HubUI.rule(trip)
	# The unlocked start floors as text tabs; what every start shares is said
	# once beside them.
	var start_row := HBoxContainer.new()
	start_row.theme_type_variation = &"CompactRow"
	trip.add_child(start_row)
	var start_caption := HubUI.label(start_row, "開始階", &"NoteLabel")
	start_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	start_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	start_choice = SegmentedChoice.new()
	start_choice.option_role = &"CategoryTab"
	start_row.add_child(start_choice)
	start_rule = HintMark.make(start_row, "どの階から始めてもLv 1。永久強化と装備・持ち込みは引き継ぐ。", HubSettings.TOPIC_GROWTH)
	start_row.move_child(start_rule, 1)
	start_choice.item_selected.connect(func(index: int): starting_floor = start_choice.get_item_id(index); _update_start_label())
	confirm_button = HubUI.primary_action(trip, "挑戦する", func(): departure_requested.emit())
	# Right: the heroine, and her stats for this run.
	hero_stats = HeroStats.new()
	hero_stats.size_flags_stretch_ratio = 0.95
	columns.add_child(hero_stats)


func present_selection(available_stages: Array[StageData], progress: RunCarryover = null) -> void:
	state = progress if progress != null else RunCarryover.new()
	stages = available_stages
	selection_page.show()
	confirmation_page.hide()
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
				if not next_button.disabled:
					next_button.grab_focus())
		stage_nodes.append(node)
		if stages[index] == selected_stage:
			selected_index = index
	_place_stages()
	if not stages.is_empty():
		_select_stage(selected_index)
		stage_nodes[selected_index].grab_focus()
	else:
		selected_stage = null
		stage_title.text = ""
		stage_details.reset()
		stage_details.line("挑戦できるステージはありません。", &"NoteLabel")
		next_button.disabled = true


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
	stage_facts.text = "全%d階　·　難易度 %s" % [stage.floor_count, stage.difficulty] if stage.available else "まだ道は開いていない"
	stage_art.texture = stage.illustration
	stage_art.modulate.a = 0.7 if state.stage_available(stage) else 0.3
	stage_details.reset()
	stage_details.line(stage.description, &"BodyLabel")
	if stage.available:
		stage_details.line("
".join(guardian_lines(stage)))
	UIMotion.reveal_selection([_selection_detail])
	next_button.disabled = not state.stage_available(stage) or stage.settings == null


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


func present_confirmation(current: RunCarryover) -> void:
	state = current
	selection_page.hide()
	confirmation_page.show()
	equipment_rows.show_equipment(state.equipment)
	hero_stats.show_stats(state.preparation_stats())
	stage_banner.texture = selected_stage.diorama if selected_stage.diorama != null else selected_stage.illustration
	banner_title.text = "%s　全%d階" % [selected_stage.display_name, selected_stage.floor_count]
	inventory_list.clear()
	for entry in state.inventory.entries:
		inventory_list.add_card(entry.item, entry.count)
	carried_count.text = "%d / %d 枠" % [state.inventory.entries.size(), state.inventory.max_entries]
	start_choice.clear()
	for floor_number in [1, 11, 21, 31, 41]:
		if state.can_start(selected_stage, floor_number):
			start_choice.add_item("%dF" % floor_number, floor_number)
			if floor_number == starting_floor:
				start_choice.select(start_choice.item_count - 1)
	starting_floor = start_choice.get_selected_id() if start_choice.item_count > 0 else 1
	_update_start_label()
	confirm_button.grab_focus()


func _update_start_label() -> void:
	confirm_button.text = "%s・%dFから挑戦する" % [selected_stage.display_name, starting_floor]


# Opening a step: the stages (or what she takes) arrive one by one, the
# detail a beat later.
func play_entrance() -> void:
	if selection_page.visible:
		for index in stage_nodes.size():
			UIMotion.of(stage_nodes[index]).appear(UIMotion.STAGGER_TIME * index, UIMotion.ENTER_TIME)
		UIMotion.of(_selection_detail).appear(UIMotion.STAGGER_TIME)
	else:
		inventory_list.play_intro()
		hero_stats.play_entrance(UIMotion.STAGGER_TIME * 2)
