class_name RouteMapView
extends CanvasLayer

# The run's route between areas: the chapter's layers left to right, each
# a column of cards (area name, its kind and difficulty, the reward it
# offers and the time it takes, its condition, its foes), the boss last.
# Only the current layer's cards can be chosen (mouse, the 1-3 keys, or the
# focused card); a past layer shows the card taken, the others dimmed. Above
# them, the run so far: level, health, echo and the boons held, and what
# the last area gave. Every line is one line, so the panel's size is known
# before it is laid out; a CenterContainer keeps it in the middle.

signal chosen(waypoint: RouteMap.Waypoint)

const CARD_SIZE := Vector2(292, 168)
const PAST_DIM := Color(1, 1, 1, 0.35)
const AHEAD_DIM := Color(1, 1, 1, 0.7)
const BACKDROP := Color(0.03, 0.035, 0.045, 1.0)
const FOCUS_DELAY := 0.25
const ECHO_NOTE := "残響は、拠点で永続強化に使う通貨です"

var route: RouteMap
# The layer to choose from now.
var route_layer := 0
var current: Array = []
var buttons: Array[Button] = []
var _title: Label
var _status: Label
var _boons: Label
var _note: Label
var _columns: HBoxContainer
var _panel: PanelContainer


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"MainPanel"
	center.add_child(_panel)
	var margin := MarginContainer.new()
	_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	_title = _line(stack, &"TitleLabel")
	_status = _line(stack, &"BodyLabel")
	_boons = _line(stack, &"MutedLabel")
	_note = _line(stack, &"GoldLabel")
	_columns = HBoxContainer.new()
	_columns.alignment = BoxContainer.ALIGNMENT_CENTER
	_columns.add_theme_constant_override("separation", 16)
	stack.add_child(_columns)
	_line(stack, &"MutedLabel").text = ECHO_NOTE
	var guide := KeyGuide.new()
	guide.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(guide)
	guide.add_hint("1・2・3", "A", "エリアを選ぶ")
	hide()


# Shows the route at `at_layer` (the next to choose), with the run's state
# and a note (what the last area gave).
func present(route_map: RouteMap, at_layer: int, run: RunState, max_hp: int, note: String = "") -> void:
	route = route_map
	route_layer = at_layer
	_title.text = route.chapter.display_name
	var hp := run.hp if run.hp > 0 else max_hp
	_status.text = "Lv %d　　HP %d / %d　　残響 %d　　撃破 %d" % [run.progression.level, hp, max_hp, run.echo, run.kills]
	var held: Array[String] = []
	for boon in run.build.owned():
		held.append(boon.display_name if boon.max_level == 1 else "%s %d" % [boon.display_name, run.build.rank(boon.id)])
	_boons.text = "強化：" + ("　".join(held) if not held.is_empty() else "なし")
	_note.text = note
	_note.visible = not note.is_empty()
	for child in _columns.get_children():
		child.free()
	buttons.clear()
	current = route.nodes(route_layer)
	for index in route.size():
		_columns.add_child(_column(index, run))
	show()
	UIMotion.bind_buttons(_panel)
	get_tree().create_timer(FOCUS_DELAY).timeout.connect(_focus_first)


func _line(parent: Node, role: StringName) -> Label:
	var label := HubUI.label(parent, "", role)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _column(index: int, run: RunState) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	var last := index == route.size() - 1
	_line(column, &"HeadingLabel").text = "ボス" if last else "第%d層" % (index + 1)
	var chosen_here: RouteMap.Waypoint = run.taken[index] if index < run.taken.size() else null
	for waypoint: RouteMap.Waypoint in route.nodes(index):
		var card := _card(waypoint)
		column.add_child(card)
		if index == route_layer:
			card.pressed.connect(_choose.bind(waypoint))
			buttons.append(card)
		else:
			card.disabled = true
			card.focus_mode = Control.FOCUS_NONE
			card.modulate = AHEAD_DIM if index > route_layer else (Color.WHITE if waypoint == chosen_here else PAST_DIM)
	return column


func _card(waypoint: RouteMap.Waypoint) -> Button:
	var area := waypoint.area
	var card := Button.new()
	card.theme_type_variation = &"HomeCard"
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_ALL
	card.tooltip_text = "%s\n%s\n%s" % [area.display_name, area.condition, area.foe_summary]
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	card.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 2)
	margin.add_child(lines)
	for pair: Array in [[area.display_name, &"HeadingLabel"],
			["%s　%s　目安%d分%02d秒" % [area.kind_name(), area.stars(), area.expected_time / 60, area.expected_time % 60], &"MutedLabel"],
			["報酬：%s" % AreaData.reward_name(waypoint.reward), &"GoldLabel"],
			[area.condition, &"BodyLabel"], [area.foe_summary, &"MutedLabel"]]:
		var label := HubUI.label(lines, pair[0], pair[1])
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true
	return card


func _focus_first() -> void:
	if visible and not buttons.is_empty():
		buttons[0].grab_focus()


func _choose(waypoint: RouteMap.Waypoint) -> void:
	if not visible:
		return
	hide()
	chosen.emit(waypoint)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var index: int = [KEY_1, KEY_2, KEY_3].find(event.physical_keycode)
	if index >= 0 and index < current.size():
		get_viewport().set_input_as_handled()
		_choose(current[index])
