class_name SkillTreePanel
extends Control

# The upgrade page, in the shared grammar: its two modes (能力の成長 and
# 開始地点) switch at the header's title place, like the shop's buying and
# selling. Growth is a wired tree on a slab from the screen's left edge:
# base HP at its centre, and four branches wired out of it, each a chain of
# tiers that opens when the one before it is capped. A wire lights from its
# source as that node grows, so how far the next tier is reads on the wire.
# The right column says what the chosen node is and does, and holds the one
# primary action. Start floors are rows chosen the same way.

signal hp_requested
signal skill_requested(id: StringName)
signal entry_requested(stage: StageData, floor_number: int)
signal mode_changed

const EFFECT_NAMES := {&"hp": "最大HP", &"attack": "攻撃力", &"defense": "防御力", &"mp": "最大MP"}
const TOTALS := [[&"hp", "最大HP"], [&"attack", "攻撃力"], [&"defense", "防御力"], [&"mp", "最大MP"]]
# Every other tier steps this far further out, so the wires between tiers
# bend like traces and stay long enough to show how far they are lit.
const TIER_STAGGER := 64.0
# Where each branch runs from the centre: across (-1 left, 1 right) and the
# row above or below it. The order follows SkillCatalog.BRANCHES.
const BRANCH_SIDES := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
const CENTRE_EMBLEM := 96.0
const TIER_EMBLEM := 48.0
const ENTRY_FLOORS := [11, 21, 31, 41]
const ENTRY_HEIGHT := 72.0
const BAND_TIP := 18.0
const EDGE_FADE := preload("res://ui/edge_fade.gdshader")

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
# Every node by id, the centre included under &"hp".
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
var stage_choice: SegmentedChoice
var stage_status: Label
var entry_rows: Array[Button] = []
var entry_list: VBoxContainer
var stage_art: TextureRect
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
	var left := HubUI.open_column(columns, 2.1, &"SlabVeilWide")
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
	visibility_changed.connect(func(): set_process(is_visible_in_tree() and not entries_shown))


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
	HubUI.label(parent, "中央の基礎HPを上限まで育てると4つの枝が開き、各段を上限まで育てると次の段へつながる。", &"NoteLabel")
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


func _node_button(id: StringName, key: String, extent: float) -> SkillNodeButton:
	var button := SkillNodeButton.new()
	canvas.add_child(button)
	button.setup(id, key, extent)
	# Moving to a node chooses it; Enter on the chosen node goes to the
	# action, so choosing never spends Gold by itself.
	button.focus_entered.connect(select_upgrade.bind(id))
	button.pressed.connect(select_upgrade.bind(id))
	button.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("ui_accept") and not event.is_echo():
			button.accept_event()
			select_upgrade(id)
			if not upgrade_button.disabled:
				upgrade_button.grab_focus())
	buttons[id] = button
	return button


# The centre in the middle of the canvas; each branch's tiers on its row
# above or below, stepping outwards.
func _place_nodes() -> void:
	var middle := canvas.size * 0.5
	var longest := 0
	for branch: Array in SkillCatalog.BRANCHES:
		longest = maxi(longest, branch.size())
	var sample: SkillNodeButton = nodes[SkillCatalog.NODES[0].id]
	var across := minf(122.0, (canvas.size.x * 0.5 - sample.size.x * 0.5) / longest)
	# The outer tiers' names end at the canvas's foot.
	var down := minf(170.0, middle.y - TIER_STAGGER - sample.foot() - 4.0)
	_put(root_button, middle)
	for index in SkillCatalog.BRANCHES.size():
		var side: Vector2 = BRANCH_SIDES[index]
		var branch: Array = SkillCatalog.BRANCHES[index]
		for tier in branch.size():
			_put(nodes[branch[tier].id], middle + Vector2(side.x * across * (tier + 1), side.y * (down + TIER_STAGGER * (tier % 2))))
	canvas.queue_redraw()


func _put(button: SkillNodeButton, point: Vector2) -> void:
	button.position = (point - button.centre()).round()


func _point(id: StringName) -> Vector2:
	var button: SkillNodeButton = buttons[id]
	return button.position + button.centre()


# A wire as a circuit trace from the edge of one disc to the edge of the
# next: straight out of its source, then the last stretch on a 45° bend. A
# wire running mostly up or down meets a node under its name instead, so it
# never crosses the words.
func _route(source: StringName, target: StringName) -> PackedVector2Array:
	var from_node: SkillNodeButton = buttons[source]
	var to_node: SkillNodeButton = buttons[target]
	var from := _point(source)
	var to := _point(target)
	var vertical := absf(to.y - from.y) > absf(to.x - from.x)
	var leave_foot := vertical and to.y > from.y
	var reach_foot := vertical and to.y < from.y
	if leave_foot:
		from.y += from_node.foot()
	if reach_foot:
		to.y += to_node.foot()
	var delta := to - from
	var bend := minf(absf(delta.x), absf(delta.y))
	var straight := delta - Vector2(signf(delta.x), signf(delta.y)) * bend
	var path := PackedVector2Array([from, from + straight, to])
	if not leave_foot:
		path[0] = path[0].move_toward(path[1] if path[0].distance_to(path[1]) > 1.0 else path[2], from_node.radius())
	if not reach_foot:
		path[2] = path[2].move_toward(path[1] if path[1].distance_to(path[2]) > 1.0 else path[0], to_node.radius())
	return path


func _draw_wires() -> void:
	if state == null:
		return
	var rail := canvas.get_theme_color(&"rail", &"HubLobby")
	var muted := canvas.get_theme_color(&"font_color", &"MutedLabel")
	for node in SkillCatalog.NODES:
		var path := _route(node.prerequisite, node.id)
		var lit := lerpf(_lit_from.get(node.id, 0.0), _lit_to.get(node.id, 0.0), blend)
		# A wire arrives with the later of its two nodes on the page's entrance.
		var shown := minf((buttons[node.prerequisite] as Control).modulate.a, (buttons[node.id] as Control).modulate.a)
		if shown <= 0.0:
			continue
		rail.a = shown
		canvas.draw_polyline(path, Color(muted, 0.28 * shown), 2.0, true)
		if lit <= 0.0:
			continue
		var part := _part(path, lit)
		if lit >= 1.0:
			# An opened wire glows a little, and a spark runs along it.
			canvas.draw_polyline(part, Color(rail, 0.22 * shown), 6.0, true)
		canvas.draw_polyline(part, rail, 2.0, true)
		if lit >= 1.0:
			var spark := _part(path, fposmod(_flow + node.id.hash() % 97 / 97.0, 1.0))
			canvas.draw_circle(spark[spark.size() - 1], 2.5, Color(rail.lerp(Color.WHITE, 0.5), 0.8 * shown))


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
	canvas.queue_redraw()


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
	HubUI.label(parent, "中ボスを倒した階の次から、Goldで冒険を始められるようにする。開始時はLv 1で、永久強化は引き継ぐ。", &"NoteLabel")
	stage_choice = SegmentedChoice.new()
	stage_choice.option_role = &"CategoryTab"
	parent.add_child(stage_choice)
	for stage in stages:
		stage_choice.add_item(stage.display_name)
	stage_choice.item_selected.connect(func(_index: int):
		_refresh_entries()
		UIMotion.reveal_selection([_entry_detail]))
	# The rows on the left half, the dungeon's picture faint beside them.
	var split := HBoxContainer.new()
	split.theme_type_variation = &"ShopColumns"
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(split)
	entry_list = VBoxContainer.new()
	entry_list.theme_type_variation = &"SlotRows"
	entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(entry_list)
	stage_art = TextureRect.new()
	# Its edges melt into the slab instead of reading as a framed picture.
	stage_art.material = ShaderMaterial.new()
	(stage_art.material as ShaderMaterial).shader = EDGE_FADE
	stage_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stage_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stage_art.custom_minimum_size.y = ENTRY_HEIGHT * ENTRY_FLOORS.size()
	stage_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	split.add_child(stage_art)
	UIMotion.of(entry_list)
	entry_list.draw.connect(_draw_entry_band)
	for index in ENTRY_FLOORS.size():
		var row := HubUI.button(entry_list, "", select_entry.bind(index), &"SlotRow")
		row.custom_minimum_size.y = ENTRY_HEIGHT
		row.toggle_mode = true
		row.focus_entered.connect(select_entry.bind(index))
		row.draw.connect(_draw_entry_row.bind(row, index))
		entry_rows.append(row)


func set_entries(value: bool) -> void:
	entries_shown = value
	growth_tab.set_pressed_no_signal(not value)
	entry_tab.set_pressed_no_signal(value)
	_growth.visible = not value
	_entries.visible = value
	_growth_detail.visible = not value
	_entry_detail.visible = value
	set_process(is_visible_in_tree() and not value)
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


func select_entry(index: int) -> void:
	selected_entry = index
	for other in entry_rows.size():
		entry_rows[other].set_pressed_no_signal(other == index)
		entry_rows[other].queue_redraw()
	entry_list.queue_redraw()
	if state != null:
		_refresh_detail()
	UIMotion.reveal_selection([_entry_detail])


func _act() -> void:
	if entries_shown:
		entry_requested.emit(stages[stage_choice.selected], ENTRY_FLOORS[selected_entry])
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


func refresh(current: RunCarryover) -> void:
	var action_had_focus := upgrade_button.has_focus()
	state = current
	_increased.clear()
	for id: StringName in buttons:
		var data := _info(id)
		if _ranks_shown.has(id) and data.rank > _ranks_shown[id]:
			_increased.append(id)
		_ranks_shown[id] = data.rank
		(buttons[id] as SkillNodeButton).show_rank(data.name, data.rank, data.max, data.met)
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
	next_value.text = "%s +%d" % [effect, (data.rank + 1) * data.amount] if data.cost >= 0 else "%s +%d" % [effect, data.rank * data.amount]
	benefit_label.text = "次は Lv %d（+%d）" % [data.rank + 1, data.amount] if data.cost >= 0 else "この段は最大まで成長しています"
	requirement.text = _condition(selected_id, data)
	var shown := []
	for row: Array in TOTALS:
		var before := _total(row[0])
		var after := _total(row[0], selected_id)
		shown.append([row[1], before, after, maxi(before, after) * 1.25 + 1])
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
	var stage := stages[stage_choice.selected]
	var available := state.stage_available(stage)
	stage_status.text = "開始時はLv 1。永久強化は引き継がれます。" if available else "ステージ未解放：%sをクリア" % _stage_name(stage.previous_stage)
	stage_art.texture = stage.illustration
	_stage_text.text = "%s　全%d階　%s
%s" % [stage.display_name, stage.floor_count, stage.difficulty, stage.description]
	stage_art.modulate.a = 0.55 if available else 0.25
	for row in entry_rows:
		row.queue_redraw()
	entry_list.queue_redraw()
	if entries_shown:
		_refresh_entry_detail()


func _entry(index: int) -> Dictionary:
	var stage := stages[stage_choice.selected]
	var floor_number: int = ENTRY_FLOORS[index]
	var available := state.stage_available(stage)
	var unlocked: bool = floor_number in state.unlocked_entries.get(String(stage.id), [])
	var defeated: bool = floor_number - 1 in state.defeated_bosses.get(String(stage.id), [])
	var condition := "中ボス撃破済み" if defeated else "条件：%dFの中ボスを撃破" % (floor_number - 1)
	if not available:
		condition = "条件：ステージを解放"
	return {"floor": floor_number, "unlocked": unlocked, "met": defeated and available, "cost": -1 if unlocked else stage.entry_costs[index], "condition": condition, "allowed": state.can_unlock_entry(stage, floor_number)}


func _refresh_entry_detail() -> void:
	var entry := _entry(selected_entry)
	_entry_title.text = "%dFから開始" % entry.floor
	_entry_condition.text = "解放済み" if entry.unlocked else entry.condition
	_counter(entry.cost, entry.met, entry.allowed, "解放する", "解放済み")


# A start floor's row: the floor, its condition, and its state at the right.
func _draw_entry_row(row: Button, index: int) -> void:
	if state == null:
		return
	var entry := _entry(index)
	var font := row.get_theme_font(&"font")
	var name_size := row.get_theme_font_size(&"font_size", &"ItemNameLabel")
	var note_size := row.get_theme_font_size(&"font_size", &"NoteLabel")
	var body := row.get_theme_color(&"font_color", &"Label")
	var muted := row.get_theme_color(&"font_color", &"MutedLabel")
	var chosen := row.button_pressed
	var title_tone := row.get_theme_color(&"font_color", &"GoldLabel") if chosen else (body if entry.met or entry.unlocked else muted)
	var width := row.size.x - BAND_TIP - 24.0
	draw_text(row, font, Vector2(16, 30), "%dFから開始" % entry.floor, width, name_size, title_tone, HORIZONTAL_ALIGNMENT_LEFT)
	draw_text(row, font, Vector2(16, 54), entry.condition, width, note_size, muted, HORIZONTAL_ALIGNMENT_LEFT)
	var tag := "解放済み" if entry.unlocked else UIFormat.gold(entry.cost)
	draw_text(row, font, Vector2(16, 30), tag, width, note_size + 2, body if entry.met or entry.unlocked else muted, HORIZONTAL_ALIGNMENT_RIGHT)
	if index < entry_rows.size() - 1 and not chosen:
		var rail := row.get_theme_color(&"rail", &"HubLobby")
		var y := row.size.y - 0.5
		row.draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(row.size.x * 0.5, y), Vector2(row.size.x, y)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.22), Color(rail, 0.0)]), 1.0, true)


func draw_text(canvas_item: CanvasItem, font: Font, at: Vector2, text: String, width: float, font_size: int, tone: Color, alignment: HorizontalAlignment) -> void:
	canvas_item.draw_string(font, at, text, alignment, width, font_size, tone)


# The chosen start floor's warm band, sliding between rows like the slots'.
func _draw_entry_band() -> void:
	var chosen := entry_rows[selected_entry]
	var rect := UIMotion.of(entry_list).follow_mark(Rect2(chosen.position + Vector2(0, 4), chosen.size - Vector2(0, 8)))
	var rail := entry_list.get_theme_color(&"rail", &"HubLobby")
	var band := entry_list.get_theme_color(&"band", &"HubLobby")
	var tip := rect.end.x
	var middle := rect.get_center().y
	var outline := PackedVector2Array([rect.position, Vector2(tip - BAND_TIP, rect.position.y), Vector2(tip, middle), Vector2(tip - BAND_TIP, rect.end.y), Vector2(rect.position.x, rect.end.y)])
	entry_list.draw_polygon(outline, PackedColorArray([Color(band, band.a * 0.5), Color(band, band.a * 1.6), Color(band, band.a * 1.8), Color(band, band.a * 1.6), Color(band, band.a * 0.5)]))
	entry_list.draw_polyline_colors(outline, PackedColorArray([Color(rail, 0.0), Color(rail, 0.85), rail, Color(rail, 0.85), Color(rail, 0.0)]), 1.5, true)


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
		order = entry_rows
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
		entry_rows[selected_entry].grab_focus()
	else:
		(buttons[selected_id] as Button).grab_focus()
