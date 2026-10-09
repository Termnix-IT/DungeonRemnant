class_name SkillTreePanel
extends Control

# The upgrade page, in the shared grammar: its two modes (能力の成長 and
# 開始地点) switch at the header's title place, like the shop's buying and
# selling. Both are wired trees on a slab from the screen's left edge, laid
# out like a folder tree and read left to right, with no words on them.
# Growth: base HP at the far left, and four branches wired out of it, one row
# each, running to the right as a chain of tiers that opens when the one
# before it is capped. A wire lights from its source as that node grows, so
# how far the next tier is reads on the wire. Start floors: each stage's
# island heads a row (a stage opens below the one it follows), and its start
# floors run to the right, each shown by the guardian whose defeat opens it.
# The right column says what the chosen node is and does, and holds the one
# primary action.

signal hp_requested
signal skill_requested(id: StringName)
signal entry_requested(stage: StageData, floor_number: int)
signal mode_changed

const EFFECT_NAMES := {&"hp": "最大HP", &"attack": "攻撃力", &"defense": "防御力", &"mp": "最大MP"}
const TOTALS := [[&"hp", "最大HP"], [&"attack", "攻撃力"], [&"defense", "防御力"], [&"mp", "最大MP"]]
# The widest step between columns and between branch rows, so the tree stays
# compact on a wide slab.
const COLUMN_STEP := 190.0
const ROW_STEP := 140.0
const CENTRE_EMBLEM := 96.0
const TIER_EMBLEM := 48.0
const ENTRY_FLOORS := [11, 21, 31, 41]
# A start floor's guardian stands larger than a tier's emblem, so the
# portrait reads; the stages sit further apart than the branches.
const ENTRY_EMBLEM := 64.0
const STAGE_ROW_STEP := 220.0

var state: RunCarryover
var stages: Array[StageData] = [preload("res://data/stages/ancient_ruins.tres"), preload("res://data/stages/forest.tres")]
var selected_id: StringName = &"hp"
var selected_entry := 0
var entries_shown := false
var mode_tabs: HBoxContainer
var growth_tab: Button
var entry_tab: Button
var canvas: Control
var root_button: SkillNodeButton
# Every node by id, base HP included under &"hp".
var buttons: Dictionary = {}
# The tiers only, as the branch nodes.
var nodes: Dictionary = {}
var upgrade_button: Button
var detail_emblem: Control
var detail_title: Label
var detail_rank: Label
var current_value: Label
var next_value: Label
var benefit_label: Label
var requirement: Label
var totals: StatBars
var price_label: Label
var after_label: Label
var stage_status: Label
var entry_canvas: Control
# Each stage's island, heading its row; it is read, not chosen.
var stage_nodes: Array[SkillNodeButton] = []
# Per stage, its start floors' nodes in ENTRY_FLOORS order.
var entry_nodes: Array = []
var selected_stage := 0
var growth_rule: HintMark
var entry_rule: HintMark
# Each wire's lit share as drawn: from, to, and the blend between them.
var blend := 1.0:
	set(value):
		blend = value
		if canvas != null:
			canvas.queue_redraw()
var _lit_from: Dictionary = {}
var _lit_to: Dictionary = {}
var _flow := 0.0
var _growth: VBoxContainer
var _entries: VBoxContainer
var _growth_detail: VBoxContainer
var _entry_detail: VBoxContainer
var _entry_title: Label
var _entry_condition: Label
var _stage_text: Label
var _detail_column: VBoxContainer
var _increased: Array[StringName] = []
var _ranks_shown: Dictionary = {}


func _ready() -> void:
	_build_mode_tabs()
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var left := HubUI.open_column(columns, 2.1, &"SlabSolid")
	_growth = VBoxContainer.new()
	_growth.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_growth)
	_build_tree(_growth)
	_entries = VBoxContainer.new()
	_entries.theme_type_variation = &"DetailStack"
	_entries.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_entries)
	_build_entries(_entries)
	_detail_column = HubUI.open_column(columns, 1.0, &"SlabSolidEnd")
	_build_detail(_detail_column)
	set_entries(false)
	set_process(false)
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))


# Two title-sized tabs the hub shows in its header in place of the title.
func _build_mode_tabs() -> void:
	mode_tabs = HBoxContainer.new()
	mode_tabs.theme_type_variation = &"ModeTabs"
	TabUnderline.attach(mode_tabs)
	var group := ButtonGroup.new()
	growth_tab = HubUI.button(mode_tabs, "能力の成長", set_entries.bind(false), &"ModeTab")
	entry_tab = HubUI.button(mode_tabs, "開始地点", set_entries.bind(true), &"ModeTab")
	for tab in [growth_tab, entry_tab]:
		tab.custom_minimum_size.y = 0
		tab.toggle_mode = true
		tab.button_group = group
	growth_tab.button_pressed = true


func _build_tree(parent: VBoxContainer) -> void:
	# The rule's mark beside a caption, so it reads as about the tree.
	var heading := HBoxContainer.new()
	heading.theme_type_variation = &"CompactRow"
	parent.add_child(heading)
	var caption := HubUI.label(heading, "ツリーの開き方", &"NoteLabel")
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	growth_rule = HintMark.make(heading, "基礎HPを上限まで上げると4本の枝が開き、各段を上限まで上げると次の段が開く。", HubSettings.TOPIC_GROWTH)
	canvas = Control.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(canvas)
	canvas.draw.connect(_draw_wires)
	canvas.resized.connect(_place_nodes)
	root_button = _node_button(&"hp", EmblemIcons.upgrade_key(&"hp", false), CENTRE_EMBLEM)
	for branch: Array in SkillCatalog.BRANCHES:
		for node: SkillNode in branch:
			nodes[node.id] = _node_button(node.id, EmblemIcons.upgrade_key(node.effect, true), TIER_EMBLEM)
	_link_focus()


func _node_button(id: StringName, key: String, extent: float) -> SkillNodeButton:
	var button := SkillNodeButton.new()
	canvas.add_child(button)
	button.setup(id, key, extent)
	_choose_on(button, select_upgrade.bind(id))
	buttons[id] = button
	return button


# Moving to a node or clicking it chooses it; Enter on the chosen node goes
# to the action, so choosing never spends Gold by itself.
func _choose_on(button: SkillNodeButton, choose: Callable) -> void:
	button.focus_entered.connect(choose)
	button.pressed.connect(choose)
	button.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("ui_accept") and not event.is_echo():
			button.accept_event()
			choose.call()
			if not upgrade_button.disabled:
				upgrade_button.grab_focus())


# Base HP at the far left, level with the middle of the branches; each
# branch on its own row, its tiers in columns to the right, so the same tier
# of every branch lines up.
func _place_nodes() -> void:
	var rows := SkillCatalog.BRANCHES.size()
	var longest := 0
	for branch: Array in SkillCatalog.BRANCHES:
		longest = maxi(longest, branch.size())
	var sample: SkillNodeButton = nodes[SkillCatalog.NODES[0].id]
	var start := Vector2(root_button.size.x * 0.5, canvas.size.y * 0.5)
	var across := minf(COLUMN_STEP, (canvas.size.x - start.x - sample.size.x * 0.5) / longest)
	var down := minf(ROW_STEP, (canvas.size.y - sample.size.y) / maxf(rows - 1, 1))
	_put(root_button, start)
	for row in rows:
		var branch: Array = SkillCatalog.BRANCHES[row]
		var y := start.y + (row - (rows - 1) * 0.5) * down
		for tier in branch.size():
			_put(nodes[branch[tier].id], Vector2(start.x + across * (tier + 1), y))
	canvas.queue_redraw()


# Arrows follow the grid: along a branch left and right, base HP at the left
# end; up and down to the same tier of the next branch, or its last tier.
func _link_focus() -> void:
	var branches := SkillCatalog.BRANCHES
	var first: SkillNodeButton = nodes[branches[0][0].id]
	root_button.focus_neighbor_right = root_button.get_path_to(first)
	for row in branches.size():
		var branch: Array = branches[row]
		for tier in branch.size():
			var button: SkillNodeButton = nodes[branch[tier].id]
			var left: Control = root_button if tier == 0 else nodes[branch[tier - 1].id]
			var right: Control = nodes[branch[tier + 1].id] if tier + 1 < branch.size() else button
			var up: Array = branches[maxi(row - 1, 0)]
			var down: Array = branches[mini(row + 1, branches.size() - 1)]
			button.focus_neighbor_left = button.get_path_to(left)
			button.focus_neighbor_right = button.get_path_to(right)
			button.focus_neighbor_top = button.get_path_to(nodes[up[mini(tier, up.size() - 1)].id])
			button.focus_neighbor_bottom = button.get_path_to(nodes[down[mini(tier, down.size() - 1)].id])


func _put(button: SkillNodeButton, point: Vector2) -> void:
	button.position = (point - button.centre()).round()


func _point(id: StringName) -> Vector2:
	return _middle(buttons[id])


func _middle(button: SkillNodeButton) -> Vector2:
	return button.position + button.centre()


# A straight wire between two nodes in a row or a column, edge to edge.
func _span(from: SkillNodeButton, to: SkillNodeButton) -> PackedVector2Array:
	var start := _middle(from)
	var end := _middle(to)
	var way := start.direction_to(end)
	return PackedVector2Array([start + way * from.radius(), end - way * to.radius()])


# A wire from the right edge of one disc to the left edge of the next, like
# the lines of a folder tree: along a branch it runs straight; from base HP
# it runs out to a trunk halfway, along the trunk to the branch's row, and on
# into the first tier at right angles.
func _route(source: StringName, target: StringName) -> PackedVector2Array:
	var from := _point(source) + Vector2((buttons[source] as SkillNodeButton).radius(), 0)
	var to := _point(target) - Vector2((buttons[target] as SkillNodeButton).radius(), 0)
	if absf(to.y - from.y) < 1.0:
		return PackedVector2Array([from, to])
	var trunk := roundf((from.x + to.x) * 0.5)
	return PackedVector2Array([from, Vector2(trunk, from.y), Vector2(trunk, to.y), to])


func _draw_wires() -> void:
	if state == null:
		return
	for node in SkillCatalog.NODES:
		var lit := lerpf(_lit_from.get(node.id, 0.0), _lit_to.get(node.id, 0.0), blend)
		_draw_wire(canvas, _route(node.prerequisite, node.id), lit, buttons[node.prerequisite], buttons[node.id])


# A stage opens below the one it follows; a start floor's wire lights once
# that floor is unlocked.
func _draw_entry_wires() -> void:
	if state == null:
		return
	for row in stages.size():
		for parent in stages.size():
			if stages[parent].id == stages[row].previous_stage:
				_draw_wire(entry_canvas, _span(stage_nodes[parent], stage_nodes[row]), 1.0 if state.stage_available(stages[row]) else 0.0, stage_nodes[parent], stage_nodes[row])
		var previous: SkillNodeButton = stage_nodes[row]
		for index in ENTRY_FLOORS.size():
			var node: SkillNodeButton = entry_nodes[row][index]
			_draw_wire(entry_canvas, _span(previous, node), 1.0 if _entry(index, row).unlocked else 0.0, previous, node)
			previous = node


# One wire: a faint rail, and the lit share drawn over it from the source.
func _draw_wire(target: Control, path: PackedVector2Array, lit: float, source: SkillNodeButton, sink: SkillNodeButton) -> void:
	# A wire arrives with the later of its two nodes on the page's entrance.
	var shown := minf(source.modulate.a, sink.modulate.a)
	if shown <= 0.0:
		return
	var rail := target.get_theme_color(&"rail", &"HubLobby")
	var muted := target.get_theme_color(&"font_color", &"MutedLabel")
	rail.a = shown
	target.draw_polyline(path, Color(muted, 0.28 * shown), 2.0, true)
	if lit <= 0.0:
		return
	var part := _part(path, lit)
	if lit >= 1.0:
		# An opened wire glows a little, and a spark runs along it.
		target.draw_polyline(part, Color(rail, 0.22 * shown), 6.0, true)
	target.draw_polyline(part, rail, 2.0, true)
	if lit >= 1.0:
		var spark := _part(path, fposmod(_flow + sink.id.hash() % 97 / 97.0, 1.0))
		target.draw_circle(spark[spark.size() - 1], 2.5, Color(rail.lerp(Color.WHITE, 0.5), 0.8 * shown))


# The first share of a path's length.
func _part(path: PackedVector2Array, share: float) -> PackedVector2Array:
	var total := 0.0
	for index in path.size() - 1:
		total += path[index].distance_to(path[index + 1])
	var left := total * clampf(share, 0.0, 1.0)
	var part := PackedVector2Array([path[0]])
	for index in path.size() - 1:
		var length := path[index].distance_to(path[index + 1])
		if left >= length:
			part.append(path[index + 1])
			left -= length
		else:
			part.append(path[index].lerp(path[index + 1], left / maxf(length, 0.001)))
			break
	return part


func _process(delta: float) -> void:
	_flow = fmod(_flow + delta / UIMotion.IDLE_PERIOD, 1.0)
	(entry_canvas if entries_shown else canvas).queue_redraw()


func _build_detail(column: VBoxContainer) -> void:
	column.theme_type_variation = &"DetailStack"
	_growth_detail = VBoxContainer.new()
	_growth_detail.theme_type_variation = &"DetailStack"
	_growth_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_growth_detail)
	var heading := HBoxContainer.new()
	heading.theme_type_variation = &"CompactRow"
	_growth_detail.add_child(heading)
	detail_emblem = Control.new()
	detail_emblem.custom_minimum_size = Vector2.ONE * CENTRE_EMBLEM
	detail_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_emblem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail_emblem.draw.connect(func(): EmblemIcons.paint(detail_emblem, Rect2(Vector2.ZERO, detail_emblem.size), (buttons[selected_id] as SkillNodeButton).emblem))
	heading.add_child(detail_emblem)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(names)
	detail_title = HubUI.label(names, "", &"HeadingLabel")
	detail_rank = HubUI.label(names, "", &"NoteLabel")
	current_value = HubUI.label(_growth_detail, "", &"BodyLabel")
	next_value = HubUI.label(_growth_detail, "", &"ValueLabel")
	benefit_label = HubUI.label(_growth_detail, "", &"NoteLabel")
	requirement = HubUI.label(_growth_detail, "", &"NoteLabel")
	HubUI.rule(_growth_detail)
	HubUI.label(_growth_detail, "永久補正の合計", &"NoteLabel")
	totals = StatBars.new()
	_growth_detail.add_child(totals)
	_entry_detail = VBoxContainer.new()
	_entry_detail.theme_type_variation = &"DetailStack"
	_entry_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_entry_detail)
	_entry_title = HubUI.label(_entry_detail, "", &"HeadingLabel")
	_entry_condition = HubUI.label(_entry_detail, "", &"NoteLabel")
	stage_status = HubUI.label(_entry_detail, "", &"NoteLabel")
	HubUI.rule(_entry_detail)
	_stage_text = HubUI.label(_entry_detail, "", &"NoteLabel")
	# The counter, as in the shop: the price large, what is left after it.
	HubUI.rule(column)
	var counter := VBoxContainer.new()
	counter.theme_type_variation = &"CompactStack"
	column.add_child(counter)
	var price_row := HBoxContainer.new()
	counter.add_child(price_row)
	var caption := HubUI.label(price_row, "必要なGold", &"NoteLabel")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label = HubUI.label(price_row, "", &"PriceLabel")
	price_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	after_label = HubUI.label(counter, "", &"NoteLabel")
	after_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	upgrade_button = HubUI.primary_action(column, "強化する", _act)


func _build_entries(parent: VBoxContainer) -> void:
	# The rule's mark beside a caption, as on the growth tree.
	var heading := HBoxContainer.new()
	heading.theme_type_variation = &"CompactRow"
	parent.add_child(heading)
	var caption := HubUI.label(heading, "開始地点の開き方", &"NoteLabel")
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	entry_rule = HintMark.make(heading, "中ボスを倒した階の次から始められる。どの階から始めてもLv 1。", HubSettings.TOPIC_GROWTH)
	entry_canvas = Control.new()
	entry_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entry_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(entry_canvas)
	entry_canvas.draw.connect(_draw_entry_wires)
	entry_canvas.resized.connect(_place_entries)
	for row in stages.size():
		var stage := stages[row]
		var island := SkillNodeButton.new()
		entry_canvas.add_child(island)
		island.setup(stage.id, "", CENTRE_EMBLEM)
		island.picture = stage.diorama
		# Clicking the island chooses its first floor; arrows pass it by.
		island.toggle_mode = false
		island.focus_mode = Control.FOCUS_NONE
		island.pressed.connect(func():
			select_entry(0, row)
			(entry_nodes[row][0] as Control).grab_focus())
		stage_nodes.append(island)
		var floors: Array[SkillNodeButton] = []
		for index in ENTRY_FLOORS.size():
			var node := SkillNodeButton.new()
			entry_canvas.add_child(node)
			node.setup(StringName("%s_%d" % [stage.id, ENTRY_FLOORS[index]]), "", ENTRY_EMBLEM)
			_show_guardian(node, stage.bosses[index] if index < stage.bosses.size() else null)
			_choose_on(node, select_entry.bind(index, row))
			floors.append(node)
		entry_nodes.append(floors)
	_link_entry_focus()


# The guardian's first idle frame, cropped to the body in the frame's lower
# part; the strip leaves room above it for the strike.
func _show_guardian(node: SkillNodeButton, stats: EnemyStats) -> void:
	var strip := EnemySprites.sheet_for(stats)
	if strip == null:
		return
	var frame := float(strip.get_height())
	node.picture = strip
	node.picture_region = Rect2(frame * 0.15, frame * 0.3, frame * 0.7, frame * 0.7)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


# Each stage's island at the far left of its row, the stages stacked down
# the left edge; its start floors in columns to the right.
func _place_entries() -> void:
	var island := stage_nodes[0]
	var sample: SkillNodeButton = entry_nodes[0][0]
	var start := Vector2(island.size.x * 0.5, entry_canvas.size.y * 0.5)
	var across := minf(COLUMN_STEP, (entry_canvas.size.x - start.x - sample.size.x * 0.5) / ENTRY_FLOORS.size())
	var down := minf(STAGE_ROW_STEP, (entry_canvas.size.y - island.size.y) / maxf(stages.size() - 1, 1))
	for row in stages.size():
		var y := start.y + (row - (stages.size() - 1) * 0.5) * down
		_put(stage_nodes[row], Vector2(start.x, y))
		for index in ENTRY_FLOORS.size():
			_put(entry_nodes[row][index], Vector2(start.x + across * (index + 1), y))
	entry_canvas.queue_redraw()


# Arrows follow the grid: left and right along a stage's floors, up and down
# to the same floor of the stage above or below.
func _link_entry_focus() -> void:
	for row in entry_nodes.size():
		for index in ENTRY_FLOORS.size():
			var node: SkillNodeButton = entry_nodes[row][index]
			node.focus_neighbor_left = node.get_path_to(entry_nodes[row][maxi(index - 1, 0)])
			node.focus_neighbor_right = node.get_path_to(entry_nodes[row][mini(index + 1, ENTRY_FLOORS.size() - 1)])
			node.focus_neighbor_top = node.get_path_to(entry_nodes[maxi(row - 1, 0)][index])
			node.focus_neighbor_bottom = node.get_path_to(entry_nodes[mini(row + 1, entry_nodes.size() - 1)][index])


func set_entries(value: bool) -> void:
	entries_shown = value
	growth_tab.set_pressed_no_signal(not value)
	entry_tab.set_pressed_no_signal(value)
	_growth.visible = not value
	_entries.visible = value
	_growth_detail.visible = not value
	_entry_detail.visible = value
	if state != null:
		_refresh_detail()
		UIMotion.reveal_selection([_detail_column])
		focus_first_action()
	mode_changed.emit()


func select_upgrade(id: StringName) -> void:
	if selected_id == id and (buttons[id] as Button).button_pressed:
		return
	UIMotion.of(current_value).reset()
	selected_id = id
	for key: StringName in buttons:
		(buttons[key] as Button).set_pressed_no_signal(key == id)
		(buttons[key] as Button).queue_redraw()
	if state != null:
		_refresh_detail()
	UIMotion.reveal_selection([_growth_detail])


# A start floor of the given stage's row, or else of the chosen stage's.
func select_entry(index: int, stage_index: int = -1) -> void:
	selected_entry = index
	if stage_index >= 0:
		selected_stage = stage_index
	for row in entry_nodes.size():
		for other in ENTRY_FLOORS.size():
			var node: SkillNodeButton = entry_nodes[row][other]
			node.set_pressed_no_signal(row == selected_stage and other == index)
			node.queue_redraw()
	if state != null:
		_refresh_detail()
	UIMotion.reveal_selection([_entry_detail])


func _act() -> void:
	if entries_shown:
		entry_requested.emit(stages[selected_stage], ENTRY_FLOORS[selected_entry])
	elif selected_id == &"hp":
		hp_requested.emit()
	else:
		skill_requested.emit(selected_id)


func _info(id: StringName) -> Dictionary:
	if id == &"hp":
		return {"name": "基礎HP", "rank": state.hp_upgrade_level, "max": state.upgrade.costs.size(), "amount": state.upgrade.hp_per_level, "effect": &"hp", "cost": state.upgrade.price(state.hp_upgrade_level), "met": true}
	var node := SkillCatalog.find(id)
	return {"name": node.display_name, "rank": state.skill_rank(id), "max": node.max_rank, "amount": node.amount, "effect": node.effect, "cost": node.price(state.skill_rank(id)), "met": state.skill_rank(node.prerequisite) >= node.prerequisite_rank, "prerequisite": node.prerequisite, "needed": node.prerequisite_rank}


func _name(id: StringName) -> String:
	return "基礎HP" if id == &"hp" else SkillCatalog.find(id).display_name


# What the permanent bonus of an effect would be with one more rank of id.
func _total(effect: StringName, plus: StringName = &"") -> int:
	var value := state.skill_bonus(effect)
	if effect == &"hp":
		value += state.upgrade.hp_bonus(state.hp_upgrade_level)
	if not plus.is_empty():
		var data := _info(plus)
		if data.effect == effect and data.cost >= 0:
			value += data.amount
	return value


# The permanent bonus of an effect with every node capped: the totals' bars
# are measured against it, so a bar reads as how far that growth has come.
func ceiling(effect: StringName) -> int:
	var value := state.upgrade.hp_bonus(state.upgrade.costs.size()) if effect == &"hp" else 0
	for node in SkillCatalog.NODES:
		if node.effect == effect:
			value += node.amount * node.max_rank
	return value


func refresh(current: RunCarryover) -> void:
	var action_had_focus := upgrade_button.has_focus()
	state = current
	_increased.clear()
	for id: StringName in buttons:
		var data := _info(id)
		if _ranks_shown.has(id) and data.rank > _ranks_shown[id]:
			_increased.append(id)
		_ranks_shown[id] = data.rank
		(buttons[id] as SkillNodeButton).show_rank(data.name, data.rank, data.max, data.met, data.cost >= 0 and state.gold >= data.cost)
	# Wires show their new share at once; a gain replays it (present_upgrade).
	for node in SkillCatalog.NODES:
		var source := _info(node.prerequisite)
		_lit_to[node.id] = clampf(float(source.rank) / node.prerequisite_rank, 0.0, 1.0)
	var motion := UIMotion.of(self)
	if motion.blend_tween != null:
		motion.blend_tween.kill()
	blend = 1.0
	_refresh_detail()
	_refresh_entries()
	if upgrade_button.disabled and action_had_focus:
		focus_first_action()


func _refresh_detail() -> void:
	if entries_shown:
		_refresh_entry_detail()
		return
	var data := _info(selected_id)
	var effect: String = EFFECT_NAMES[data.effect]
	detail_title.text = data.name
	detail_rank.text = "上限" if data.cost < 0 else "Lv %d / %d" % [data.rank, data.max]
	detail_emblem.queue_redraw()
	current_value.text = "今　%s +%d" % [effect, data.rank * data.amount]
	# The next rank's total, said as next like the current one is said as now.
	next_value.text = "次　%s +%d" % [effect, (data.rank + 1) * data.amount] if data.cost >= 0 else "%s +%d" % [effect, data.rank * data.amount]
	# The next value already says the gain; only a capped node needs a line.
	benefit_label.text = "" if data.cost >= 0 else "この段は最大まで成長しています"
	benefit_label.visible = data.cost < 0
	requirement.text = _condition(selected_id, data)
	var shown := []
	for row: Array in TOTALS:
		var before := _total(row[0])
		var after := _total(row[0], selected_id)
		shown.append([row[1], before, after, ceiling(row[0])])
	totals.show_rows(shown)
	var allowed: bool = data.cost >= 0 and data.met and state.gold >= data.cost
	_counter(data.cost, data.met, allowed, "強化する", "強化上限")


# What opens this node and what it opens.
func _condition(id: StringName, data: Dictionary) -> String:
	var lines := []
	if id != &"hp":
		var held := state.skill_rank(data.prerequisite)
		lines.append("開く条件：%s を上限（Lv %d）まで%s" % [_name(data.prerequisite), data.needed, "　達成" if data.met else "　あと Lv %d" % (data.needed - held)])
	var next := SkillCatalog.children(id)
	if not next.is_empty():
		var names := []
		for node in next:
			names.append(node.display_name)
		lines.append("上限で開く：%s" % "・".join(names))
	return "\n".join(lines)


func _counter(cost: int, met: bool, allowed: bool, verb: String, complete: String) -> void:
	price_label.text = "—" if cost < 0 else UIFormat.gold(cost)
	# Gold marks a price that bears on the choice now; one behind an unmet
	# condition cannot be paid yet, so it stays out of gold.
	price_label.theme_type_variation = &"PriceLabel" if met or cost < 0 else &"PriceLabelLocked"
	after_label.text = "" if cost < 0 or not allowed else "強化後 %s" % UIFormat.gold(state.gold - cost)
	upgrade_button.disabled = not allowed
	upgrade_button.focus_mode = Control.FOCUS_ALL if allowed else Control.FOCUS_NONE
	if cost < 0:
		upgrade_button.text = complete
	elif not met:
		upgrade_button.text = "条件未達"
	elif state.gold < cost:
		upgrade_button.text = "あと%d G" % (cost - state.gold)
	else:
		upgrade_button.text = verb


func _refresh_entries() -> void:
	for row in stages.size():
		var stage := stages[row]
		var available := state.stage_available(stage)
		var island_note := stage.display_name if available else "%s（%sを踏破で解放）" % [stage.display_name, _stage_name(stage.previous_stage)]
		stage_nodes[row].show_state(island_note, 1 if available else 0, 1, available, false)
		for index in ENTRY_FLOORS.size():
			var entry := _entry(index, row)
			var node: SkillNodeButton = entry_nodes[row][index]
			var note := "%s　%dFから開始\n%s" % [stage.display_name, entry.floor, "解放済み" if entry.unlocked else entry.condition]
			node.show_state(note, 1 if entry.unlocked else 0, 1, entry.met or entry.unlocked, entry.allowed)
			# A guardian not yet beaten stays a shadow, as it stays ？？？ on the map.
			node.picture_hidden = not entry.met and not entry.unlocked
	entry_canvas.queue_redraw()
	if entries_shown:
		_refresh_entry_detail()


func _entry(index: int, stage_index: int = -1) -> Dictionary:
	var stage := stages[selected_stage if stage_index < 0 else stage_index]
	var floor_number: int = ENTRY_FLOORS[index]
	var available := state.stage_available(stage)
	var unlocked: bool = floor_number in state.unlocked_entries.get(String(stage.id), [])
	var defeated: bool = floor_number - 1 in state.defeated_bosses.get(String(stage.id), [])
	var condition := "中ボス撃破済み" if defeated else "条件：%dFの中ボスを撃破" % (floor_number - 1)
	if not available:
		condition = "条件：ステージを解放"
	return {"floor": floor_number, "unlocked": unlocked, "met": defeated and available, "cost": -1 if unlocked else stage.entry_costs[index], "condition": condition, "allowed": state.can_unlock_entry(stage, floor_number)}


func _refresh_entry_detail() -> void:
	var stage := stages[selected_stage]
	var available := state.stage_available(stage)
	var entry := _entry(selected_entry)
	_entry_title.text = "%dFから開始" % entry.floor
	_entry_condition.text = "解放済み" if entry.unlocked else entry.condition
	stage_status.text = "" if available else "ステージ未解放：%sをクリア" % _stage_name(stage.previous_stage)
	stage_status.visible = not available
	_stage_text.text = "%s　全%d階　%s\n%s" % [stage.display_name, stage.floor_count, stage.difficulty, stage.description]
	_counter(entry.cost, entry.met, entry.allowed, "解放する", "解放済み")


func _stage_name(id: StringName) -> String:
	for stage in stages:
		if stage.id == id:
			return stage.display_name
	return String(id)


# Success moment after saving: the grown node's ring brightens and pulses,
# its wires light up to their new share, and a node it opened flashes.
func present_upgrade() -> void:
	if not _increased.is_empty():
		UIMotion.of(totals).pulse(1.04, UIMotion.GOLD_TIME)
	for id: StringName in _increased:
		var button: SkillNodeButton = buttons[id]
		UIMotion.of(button).pulse(1.05, UIMotion.GOLD_TIME)
		UIMotion.of(button).glow_in()
		UIMotion.of(button).flash(1.25)
		if id == selected_id:
			UIMotion.of(current_value).pulse(1.04, UIMotion.GOLD_TIME)
			UIMotion.of(detail_rank).reveal()
		var info := _info(id)
		if info.rank >= info.max:
			for opened in SkillCatalog.children(id):
				UIMotion.of(buttons[opened.id]).flash(1.4, UIMotion.MOMENT_TIME)
	if not _increased.is_empty():
		_lit_from = _lit_shown_before()
		UIMotion.of(self).blend_in()
	_increased.clear()


# The wires as they were before the gain: the grown nodes one rank lower.
func _lit_shown_before() -> Dictionary:
	var before := _lit_to.duplicate()
	for node in SkillCatalog.NODES:
		if node.prerequisite in _increased:
			var source := _info(node.prerequisite)
			before[node.id] = clampf(float(source.rank - 1) / node.prerequisite_rank, 0.0, 1.0)
	return before


func play_entrance() -> void:
	var order := [root_button]
	for tier in 4:
		for branch: Array in SkillCatalog.BRANCHES:
			if tier < branch.size():
				order.append(nodes[branch[tier].id])
	if entries_shown:
		order = stage_nodes.duplicate()
		for index in ENTRY_FLOORS.size():
			for row in entry_nodes.size():
				order.append(entry_nodes[row][index])
	for index in order.size():
		UIMotion.of(order[index]).appear(UIMotion.ROW_STAGGER * index, UIMotion.ROW_TIME)
	UIMotion.of(_detail_column).appear(UIMotion.STAGGER_TIME)


# R (Y on a gamepad) switches between growth and start floors.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R
	var pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y
	if key or pad:
		set_entries(not entries_shown)
		get_viewport().set_input_as_handled()


func focus_first_action() -> void:
	if entries_shown:
		(entry_nodes[selected_stage][selected_entry] as Control).grab_focus()
	else:
		(buttons[selected_id] as Button).grab_focus()
