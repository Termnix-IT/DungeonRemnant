class_name RouteMapView
extends CanvasLayer

# The run's route between areas, as roguelites commonly show it: a node map.
# The chapter's illustration, darkened, lies behind a framed panel; along
# its top the run so far (the chapter, health, level, echo, the boons as
# emblems) and what the last area gave. On the left the map: the layers from
# left to right, each a column of RouteNodes (what clearing it gives, its
# kind and difficulty), joined by lines (the way already taken bright, the
# ways open now gold, the rest faint), the boss last. On the right the
# selected node's account (area, kind, time, reward, goal, foes) and the
# button that enters it. Only the current layer's nodes can be chosen; the
# others can still be pointed at to read them. Mouse: pointing reads a
# node, a click enters an open one. Keys and pad: the arrows move between the
# open nodes, Enter (A) or the button enters; 1-3 enter one at once.

signal chosen(waypoint: RouteMap.Waypoint)

const BACKDROP := Color(0.02, 0.025, 0.035, 0.78)
const FOCUS_DELAY := 0.25
const MAP_SIZE := Vector2(900, 560)
const DETAIL_WIDTH := 400.0
# Spacing between the nodes of a layer, and the map's side margins.
const NODE_GAP := 170.0
const MAP_MARGIN := 70.0
const PATH_TAKEN := Color(0.84, 0.72, 0.48, 0.95)
const PATH_OPEN := Color(0.84, 0.72, 0.48, 0.7)
const PATH_FAINT := Color(0.6, 0.6, 0.58, 0.22)
const EMBLEM_SIZE := 32.0
# Her token on the map: her face in a gold ring, standing where she is.
# Opening, the paths open to her draw out from it (DRAW_TIME); a pick asks
# first whether to go there (the area, its reward and goal), and once it is
# answered yes, sends the token along the path to it (TRAVEL_TIME) before it
# is entered.
const TOKEN := preload("res://art/ui/route/token.png")
const TOKEN_SIZE := 46.0
const DRAW_TIME := 0.45
const TRAVEL_TIME := 0.5
const ARRIVE_TIME := 0.14

var route: RouteMap
# The layer to choose from now.
var route_layer := 0
var current: Array = []
var buttons: Array[Button] = []
var nodes_by_point: Dictionary = {}
var selected: RouteMap.Waypoint
var _run: RunState
var _art: TextureRect
var _title: Label
var _hp: Label
var _level: Label
var _echo: Label
var _boons: HBoxContainer
var _note: Label
var _map: Control
var _detail_name: Label
var _detail_kind: Label
var _detail_reward: Label
var _detail_goal: Label
var _detail_foes: Label
var _enter: Button
var _panel: PanelContainer
var token: Control
# How far the paths open to her have drawn out (0 to 1), and whether her
# token is travelling to a pick (nothing else is taken meanwhile).
var draw_progress := 1.0
var traveling := false
# The question asked before a pick is gone ahead with, and the area it asks about.
var prompt: ChoicePrompt
var asked: RouteMap.Waypoint


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_art)
	var shade := ColorRect.new()
	shade.color = BACKDROP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"QuietWindow"
	center.add_child(_panel)
	var margin := MarginContainer.new()
	_panel.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	_build_status(stack)
	_note = _line(stack, &"GoldLabel")
	var body := HBoxContainer.new()
	stack.add_child(body)
	_map = Control.new()
	_map.custom_minimum_size = MAP_SIZE
	_map.draw.connect(_draw_paths)
	body.add_child(_map)
	_build_detail(body)
	var guide := KeyGuide.new()
	guide.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(guide)
	guide.add_hint("←→↑↓", "十字", "エリアを選ぶ")
	guide.add_hint("Enter", "A", "進む")
	hide()


# The top bar: the chapter on the left, the run's state on the right.
func _build_status(stack: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	stack.add_child(bar)
	_title = HubUI.label(bar, "", &"TitleLabel")
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	_boons = HBoxContainer.new()
	_boons.alignment = BoxContainer.ALIGNMENT_END
	bar.add_child(_boons)
	_hp = HubUI.label(bar, "", &"ValueLabel")
	_level = HubUI.label(bar, "", &"ValueLabel")
	_echo = HubUI.label(bar, "", &"GoldLabel")
	for label: Label in [_title, _hp, _level, _echo]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	HubUI.rule(stack)


# The selected node's account and the button that enters it.
func _build_detail(body: HBoxContainer) -> void:
	var detail := PanelContainer.new()
	detail.theme_type_variation = &"QuietSection"
	detail.custom_minimum_size.x = DETAIL_WIDTH
	body.add_child(detail)
	var lines := VBoxContainer.new()
	detail.add_child(lines)
	_detail_name = HubUI.label(lines, "", &"HeadingLabel")
	_detail_kind = HubUI.label(lines, "", &"MutedLabel")
	for label: Label in [_detail_name, _detail_kind]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
	HubUI.rule(lines)
	_detail_reward = HubUI.label(lines, "", &"GoldLabel")
	_detail_goal = HubUI.label(lines, "", &"BodyLabel")
	_detail_foes = HubUI.label(lines, "", &"DescriptionLabel")
	for label: Label in [_detail_goal, _detail_foes]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lines.add_child(gap)
	_enter = HubUI.primary_action(lines, "このエリアへ進む", func(): pick(selected))


# Shows the route at `at_layer` (the next to choose), with the run's state
# and a note (what the last area gave).
func present(route_map: RouteMap, at_layer: int, run: RunState, max_hp: int, note: String = "") -> void:
	route = route_map
	route_layer = at_layer
	_run = run
	_art.texture = route.chapter.illustration
	_title.text = route.chapter.display_name
	var hp := run.hp if run.hp > 0 else max_hp
	_hp.text = "HP %d / %d" % [hp, max_hp]
	_level.text = "Lv %d" % run.progression.level
	_echo.text = "残響 %s" % UIFormat.amount(run.echo)
	_show_boons(run)
	_note.text = note
	_note.visible = not note.is_empty()
	traveling = false
	_lay_nodes()
	_select(current[0] if not current.is_empty() else null)
	show()
	draw_progress = 0.0
	create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_method(_draw_out, 0.0, 1.0, DRAW_TIME)
	UIMotion.bind_buttons(_panel)
	get_tree().create_timer(FOCUS_DELAY).timeout.connect(_focus_first)


func _line(parent: Node, role: StringName) -> Label:
	var label := HubUI.label(parent, "", role)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _show_boons(run: RunState) -> void:
	for child in _boons.get_children():
		child.free()
	for boon in run.build.owned():
		var icon := TextureRect.new()
		icon.texture = EmblemIcons.texture(boon.emblem)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(EMBLEM_SIZE, EMBLEM_SIZE)
		icon.tooltip_text = boon.display_name if boon.max_level == 1 else "%s %d" % [boon.display_name, run.build.rank(boon.id)]
		_boons.add_child(icon)


# Every layer's nodes, placed in columns across the map.
func _lay_nodes() -> void:
	for child in _map.get_children():
		child.free()
	buttons.clear()
	nodes_by_point.clear()
	current = route.nodes(route_layer)
	for index in route.size():
		var taken_here: RouteMap.Waypoint = _run.taken[index] if index < _run.taken.size() else null
		var points := route.nodes(index)
		for row in points.size():
			var point: RouteMap.Waypoint = points[row]
			var mark := RouteNode.Mark.AHEAD
			if index == route_layer:
				mark = RouteNode.Mark.OPEN
			elif index < route_layer:
				mark = RouteNode.Mark.TAKEN if point == taken_here else RouteNode.Mark.PASSED
			var node := RouteNode.new()
			_map.add_child(node)
			node.setup(point, mark)
			node.position = _spot(index, row, points.size()) - node.size * 0.5
			nodes_by_point[point] = node
			node.mouse_entered.connect(_show_detail.bind(point))
			node.mouse_exited.connect(_show_detail.bind(null))
			if mark == RouteNode.Mark.OPEN:
				node.pressed.connect(_on_node_pressed.bind(point))
				node.focus_entered.connect(_select.bind(point))
				buttons.append(node)
			else:
				node.disabled = true
	# The open nodes are walked with the arrows, top to bottom and round.
	for row in buttons.size():
		var path := buttons[row].get_path_to(buttons[(row + 1) % buttons.size()])
		var back := buttons[row].get_path_to(buttons[(row - 1 + buttons.size()) % buttons.size()])
		buttons[row].focus_neighbor_bottom = path
		buttons[row].focus_neighbor_right = path
		buttons[row].focus_neighbor_top = back
		buttons[row].focus_neighbor_left = back
	# Her token, above the nodes, where she stands: the area last taken, or
	# the start, left of the first layer.
	token = Control.new()
	token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token.size = Vector2.ONE * TOKEN_SIZE
	token.pivot_offset = token.size * 0.5
	token.draw.connect(_draw_token)
	_map.add_child(token)
	token.position = token_spot() - token.size * 0.5
	_map.queue_redraw()


# Where her token stands before this layer's pick.
func token_spot() -> Vector2:
	if route_layer > 0 and route_layer - 1 < _run.taken.size():
		return _center(_run.taken[route_layer - 1])
	return Vector2(MAP_MARGIN * 0.35, MAP_SIZE.y * 0.5 - 12.0)


func _draw_out(value: float) -> void:
	draw_progress = value
	_map.queue_redraw()


func _draw_token() -> void:
	var middle := token.size * 0.5
	var radius := TOKEN_SIZE * 0.5
	token.draw_circle(middle, radius + 3.0, Color(0, 0, 0, 0.5))
	token.draw_texture_rect(TOKEN, Rect2(middle - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false)
	token.draw_arc(middle, radius, 0.0, TAU, 48, PATH_TAKEN, 2.5, true)


# Where a layer's row sits on the map.
func _spot(index: int, row: int, count: int) -> Vector2:
	var span := MAP_SIZE.x - MAP_MARGIN * 2.0
	var x := MAP_MARGIN + span * index / maxf(1.0, route.size() - 1)
	var y := MAP_SIZE.y * 0.5 + (row - (count - 1) * 0.5) * NODE_GAP - 12.0
	return Vector2(x, y)


func _draw_paths() -> void:
	if route == null:
		return
	for index in route.size() - 1:
		var taken_here: RouteMap.Waypoint = _run.taken[index] if index < _run.taken.size() else null
		for from: RouteMap.Waypoint in route.nodes(index):
			for to: RouteMap.Waypoint in route.nodes(index + 1):
				var color := PATH_FAINT
				var width := 2.0
				if index < route_layer and from == taken_here:
					var next: RouteMap.Waypoint = _run.taken[index + 1] if index + 1 < _run.taken.size() else null
					if to == next:
						color = PATH_TAKEN
						width = 4.0
					elif index + 1 == route_layer:
						color = PATH_OPEN
						width = 3.0
						# Drawn out from her as the map opens.
						_map.draw_line(_center(from), _center(from).lerp(_center(to), draw_progress), color, width, true)
						continue
				_map.draw_line(_center(from), _center(to), color, width, true)
	# From the start to the first layer, before any area is taken.
	if route_layer == 0:
		for to: RouteMap.Waypoint in route.nodes(0):
			_map.draw_line(token_spot(), token_spot().lerp(_center(to), draw_progress), PATH_OPEN, 3.0, true)


func _center(point: RouteMap.Waypoint) -> Vector2:
	var node: RouteNode = nodes_by_point[point]
	return node.position + node.size * 0.5


func _select(point: RouteMap.Waypoint) -> void:
	selected = point
	for node: RouteNode in nodes_by_point.values():
		node.selected = node.waypoint == point
	_show_detail(point)


func _show_detail(point: RouteMap.Waypoint) -> void:
	var shown := point if point != null else selected
	if shown == null:
		return
	var area := shown.area
	_detail_name.text = area.display_name
	_detail_kind.text = "%s　%s　目安 %d分%02d秒" % [area.kind_name(), area.stars(), area.expected_time / 60, area.expected_time % 60]
	_detail_reward.text = "報酬：%s" % AreaData.reward_name(shown.reward)
	_detail_goal.text = area.condition
	_detail_foes.text = area.foe_summary
	_enter.disabled = not current.has(shown)


func _on_node_pressed(point: RouteMap.Waypoint) -> void:
	if selected == point:
		pick(point)
	else:
		_select(point)
		nodes_by_point[point].grab_focus()


func _focus_first() -> void:
	if visible and not buttons.is_empty():
		buttons[current.find(selected) if current.has(selected) else 0].grab_focus()


# A pick from the player: first the question whether to go there.
func pick(waypoint: RouteMap.Waypoint) -> void:
	if not visible or traveling or waypoint == null or not current.has(waypoint) or (prompt != null and prompt.visible):
		return
	if prompt == null:
		prompt = ChoicePrompt.new()
		add_child(prompt)
		prompt.confirmed.connect(_on_go)
		prompt.canceled.connect(_on_stay)
	asked = waypoint
	var area := waypoint.area
	prompt.ask("%s　%s" % [area.kind_name(), area.stars()], "「%s」に進みますか？" % area.display_name, "報酬：%s　%s" % [AreaData.reward_name(waypoint.reward), area.condition], "進む", "やめる")


func _on_go() -> void:
	prompt.hide()
	if asked != null:
		travel(asked)


func _on_stay() -> void:
	prompt.hide()
	if asked != null and nodes_by_point.has(asked):
		nodes_by_point[asked].grab_focus()
	asked = null


# The pick gone ahead with: her token travels the path to it, the node
# answers, and then it is chosen. Nothing else is taken on the way.
func travel(waypoint: RouteMap.Waypoint) -> void:
	if not visible or traveling or waypoint == null or not current.has(waypoint):
		return
	traveling = true
	for button in buttons:
		button.release_focus()
	GameAudio.play(self, &"step", -16.0)
	var journey := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	journey.tween_property(token, "position", _center(waypoint) - token.size * 0.5, TRAVEL_TIME)
	journey.tween_callback(func():
		UIMotion.of(nodes_by_point[waypoint]).pulse(1.08, ARRIVE_TIME)
		GameAudio.play(self, &"confirm", -16.0))
	journey.tween_interval(ARRIVE_TIME)
	journey.tween_callback(_choose.bind(waypoint))


# The pick taken at once (tests, and the end of a token's journey).
func _choose(waypoint: RouteMap.Waypoint) -> void:
	if not visible or waypoint == null or not current.has(waypoint):
		return
	traveling = false
	hide()
	chosen.emit(waypoint)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or traveling or (prompt != null and prompt.visible) or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var index: int = [KEY_1, KEY_2, KEY_3].find(event.physical_keycode)
	if index >= 0 and index < current.size():
		get_viewport().set_input_as_handled()
		pick(current[index])
