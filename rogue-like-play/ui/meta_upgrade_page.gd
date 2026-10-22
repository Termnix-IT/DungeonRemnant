class_name MetaUpgradePage
extends Control

# The lasting upgrades (MetaProgress.UPGRADES) as an upgrade tree, the
# common form: on the slab, a board larger than its window, the root in the
# middle and the branches growing out of it (the body's to the left, growth's
# to the right; the skill and special-move branches above and below, sealed
# for now). Each node is its emblem, with sockets under it when it has
# ranks; a line joins it to the node it grows from, brighter once it can be
# bought and brightest once held. The board lies in an opaque well of its
# own inside the slab; it is dragged with the pointer or moved with the
# right stick, zoomed with the wheel (LT / RT), follows the focus, and C (Y)
# brings the root back at its first size. In the column on the right, the chosen node's emblem, name, branch
# and rank, its figure now and next, what it does and what it waits for,
# and the one action: its next rank's price on a button that asks to buy
# (buy_requested; the hub saves, then calls present_purchase). Enter (A) on
# a node asks the same. The pointer chooses a node by resting on it or
# clicking it, never buys by it, and a press that moves is a drag.

signal buy_requested(id: StringName)

const CELL := Vector2(108, 92)
const NODE_SIZE := 60.0
const ROOT_SIZE := 84.0
const PIP_SIZE := 9.0
const DETAIL_EMBLEM := 150.0
const LINE_WIDTH := 2.5
const RING_WIDTH := 2.5
# Room past the outermost nodes, as a share of the window, so the board
# never drifts off into nothing.
const BOARD_MARGIN := 0.5
# The focus is kept this far inside the window; past it the board follows.
const FOLLOW_MARGIN := 90.0
const FOLLOW_TIME := 0.22
# A press that moves this far is a drag, not a click.
const DRAG_THRESHOLD := 8.0
const PAN_SPEED := 900.0
# How near and far the board zooms, a wheel notch's step, and how fast the
# triggers zoom (per second, held fully).
const ZOOM_MIN := 0.7
const ZOOM_MAX := 1.8
const ZOOM_STEP := 1.15
const ZOOM_RATE := 2.2
# A focus move goes to a node within this angle of the direction pressed:
# one it is joined to first, then the nearest, then the upper.
const AIM_CONE := PI / 3.0
const BRANCH_NAMES := {&"": "中央", &"body": "身体", &"growth": "成長", &"skill": "スキル", &"special": "必殺技"}
# Branches to come, sealed for now: the branch, its cell, its emblem.
const SEALS := [[&"special", Vector2i(0, 2), "seal_special"]]
const SEAL_NOTE := "この枝はまだ開放されていない"

var meta: MetaProgress
# Node id (an upgrade's, or a seal's branch) -> its focusable Button.
var nodes: Dictionary = {}
var selected: StringName = MetaProgress.ROOT
var buy_button: Button
var name_label: Label
var rank_label: Label
var figure_label: Label
var description_label: Label
var requirement_label: Label
var picture: Control
var board: Control
var canvas: Control
var zoom := 1.0
var _edges: Control
var _tree_column: VBoxContainer
var _info: VBoxContainer
var _pips: Control
# Node id -> its centre on the canvas, and the id it grows from.
var _centers: Dictionary = {}
var _parents: Dictionary = {}
var _placed := false
var _board_size := Vector2.ZERO
var _pan_tween: Tween
var _press_at := Vector2.INF
var _press_node: StringName = &""
var _dragging := false
var _hover_node: StringName = &""
# A focus the pointer gave leaves the board where it is.
var _pointer_focus := false
var _shown: StringName = &""
# The triggers' pull (LT, RT), read from their motion.
var _triggers := Vector2.ZERO


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tree_column = HubUI.open_column(columns, 2.1, &"SlabSolid")
	# The tree's own opaque well, so the moving board never runs over the slab.
	var well := PanelContainer.new()
	well.theme_type_variation = &"TreeWell"
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree_column.add_child(well)
	board = Control.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.clip_contents = true
	board.gui_input.connect(_board_input)
	board.mouse_exited.connect(func(): _hover_node = &"")
	board.resized.connect(_on_board_resized)
	well.add_child(board)
	# The canvas is the moving layer: no Container lays it out.
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_lines)
	board.add_child(canvas)
	for upgrade in MetaProgress.UPGRADES:
		_add_node(upgrade.id, upgrade.cell, upgrade.parent, ROOT_SIZE if upgrade.parent.is_empty() else NODE_SIZE)
	for seal: Array in SEALS:
		_add_node(seal[0], seal[1], MetaProgress.ROOT, NODE_SIZE)
	_link_focus()
	_edges = Control.new()
	_edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edges.draw.connect(_draw_edges)
	board.add_child(_edges)
	_edges.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_info = HubUI.open_column(columns, 1.0, &"SlabSolidEnd")
	# The account slides in from the right edge, kept inside its column.
	(_info.get_parent() as Control).clip_contents = true
	_info.theme_type_variation = &"DetailStack"
	picture = Control.new()
	picture.custom_minimum_size = Vector2.ONE * DETAIL_EMBLEM
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.draw.connect(func(): EmblemIcons.paint(picture, Rect2(Vector2.ZERO, picture.size), _emblem(selected)))
	_info.add_child(picture)
	name_label = _centered(HubUI.label(_info, "", &"HeadingLabel"))
	rank_label = _centered(HubUI.label(_info, "", &"MutedLabel"))
	_pips = Control.new()
	_pips.custom_minimum_size.y = PIP_SIZE + 6
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.draw.connect(func():
		var upgrade := MetaProgress.find(selected)
		if upgrade != null and meta != null:
			_paint_pips(_pips, Vector2(_pips.size.x * 0.5, 0), upgrade, meta.rank(upgrade.id)))
	_info.add_child(_pips)
	HubUI.rule(_info)
	figure_label = _centered(HubUI.label(_info, "", &"ValueLabel"))
	description_label = HubUI.label(_info, "", &"DescriptionLabel")
	requirement_label = HubUI.label(_info, "", &"MutedLabel")
	HubUI.space(_info)
	buy_button = HubUI.primary_action(_info, "", _buy)
	UIMotion.bind_buttons(_info)


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _add_node(id: StringName, cell: Vector2i, parent: StringName, extent: float) -> void:
	var node := Button.new()
	node.theme_type_variation = &"UpgradeNode"
	node.focus_mode = Control.FOCUS_ALL
	# The board reads the pointer itself, to tell a click from a drag.
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	canvas.add_child(node)
	node.size = Vector2.ONE * extent
	var center := Vector2(cell) * CELL
	node.position = center - node.size * 0.5
	node.pivot_offset = node.size * 0.5
	node.draw.connect(_draw_node.bind(node, id))
	node.focus_entered.connect(_on_node_focused.bind(id))
	node.focus_exited.connect(node.queue_redraw)
	node.pressed.connect(_buy)
	nodes[id] = node
	_centers[id] = center
	_parents[id] = parent


# Each direction from a node leads to the one _neighbor picks, or nowhere.
func _link_focus() -> void:
	var sides := [[SIDE_LEFT, Vector2.LEFT], [SIDE_RIGHT, Vector2.RIGHT], [SIDE_TOP, Vector2.UP], [SIDE_BOTTOM, Vector2.DOWN]]
	for id: StringName in nodes:
		var node: Button = nodes[id]
		for side: Array in sides:
			var target := _neighbor(id, side[1])
			node.set_focus_neighbor(side[0], (nodes[target] as Button).get_path() if not target.is_empty() else node.get_path())


func _neighbor(id: StringName, direction: Vector2) -> StringName:
	var from: Vector2 = _centers[id]
	var best: StringName = &""
	var best_score := Vector3.INF
	for other: StringName in nodes:
		var offset: Vector2 = _centers[other] - from
		if other == id or absf(offset.angle_to(direction)) > AIM_CONE + 0.001:
			continue
		var joined: bool = _parents[other] == id or _parents[id] == other
		var score := Vector3(0.0 if joined else 1.0, snappedf(offset.length(), 0.1), _centers[other].y)
		if score < best_score:
			best_score = score
			best = other
	return best


func refresh(current: MetaProgress) -> void:
	meta = current
	_tell()
	canvas.queue_redraw()
	for node: Button in nodes.values():
		node.queue_redraw()


func _on_node_focused(id: StringName) -> void:
	var animate := not _shown.is_empty() and id != _shown
	selected = id
	_shown = id
	_tell()
	for node: Button in nodes.values():
		node.queue_redraw()
	if animate:
		UIMotion.of(_info).slide_in()
	if not _pointer_focus:
		_follow(id)
	_pointer_focus = false


# The right column for the chosen node.
func _tell() -> void:
	if meta == null or name_label == null:
		return
	picture.queue_redraw()
	_pips.queue_redraw()
	var upgrade := MetaProgress.find(selected)
	if upgrade == null:
		name_label.text = BRANCH_NAMES.get(selected, "")
		rank_label.text = "未開放の枝"
		figure_label.hide()
		description_label.text = SEAL_NOTE
		requirement_label.hide()
		buy_button.hide()
		return
	var rank := meta.rank(upgrade.id)
	name_label.text = upgrade.display_name
	rank_label.text = "%s　段階 %d / %d" % [BRANCH_NAMES.get(upgrade.branch, ""), rank, upgrade.max_rank()]
	figure_label.text = upgrade.figure_line(rank)
	figure_label.visible = not figure_label.text.is_empty()
	description_label.text = upgrade.description
	var waiting := not meta.unlocked(upgrade.id)
	var parent := MetaProgress.find(upgrade.parent)
	requirement_label.text = "「%s」を習得すると解放" % parent.display_name if waiting else ""
	requirement_label.visible = waiting
	buy_button.show()
	var price := upgrade.price(rank)
	if price < 0:
		buy_button.text = "習得済み"
		buy_button.disabled = true
		buy_button.tooltip_text = ""
		return
	buy_button.text = "残響 %s で%s" % [UIFormat.amount(price), "習得" if rank == 0 else "強化"]
	buy_button.disabled = not meta.can_buy(upgrade.id)
	if waiting:
		buy_button.tooltip_text = "先に「%s」を習得する" % parent.display_name
	elif meta.echo < price:
		buy_button.tooltip_text = "残響が%s足りない" % UIFormat.amount(price - meta.echo)
	else:
		buy_button.tooltip_text = ""


func _buy() -> void:
	if meta != null and meta.can_buy(selected):
		buy_requested.emit(selected)
	else:
		GameAudio.play(self, &"ui_deny", -18.0)


# After a purchase has been saved: the node's moment, and the nodes it opens.
func present_purchase(id: StringName) -> void:
	if not nodes.has(id):
		return
	UIMotion.of(nodes[id]).pulse(1.03, UIMotion.GOLD_TIME)
	UIMotion.of(rank_label).reveal()
	for other: StringName in nodes:
		if _parents[other] == id and meta != null and meta.rank(other) == 0:
			UIMotion.of(nodes[other]).reveal(UIMotion.ROW_TIME)


func focus_first() -> void:
	if nodes.has(selected):
		(nodes[selected] as Button).grab_focus()


# The root chosen and the board brought back around it.
func center_view() -> void:
	_pointer_focus = true
	(nodes[MetaProgress.ROOT] as Button).grab_focus()
	_pointer_focus = false
	_stop_pan()
	_set_zoom(1.0, board.size * 0.5)
	_pan_to(board.size * 0.5 - _centers[MetaProgress.ROOT])


# Opening the page: the tree first, the column a beat later.
func play_entrance() -> void:
	UIMotion.of(_tree_column).appear(0.0, UIMotion.WINDOW_TIME)
	UIMotion.of(_info).appear(UIMotion.STAGGER_TIME)


func _emblem(id: StringName) -> String:
	var upgrade := MetaProgress.find(id)
	if upgrade != null:
		return upgrade.emblem
	for seal: Array in SEALS:
		if seal[0] == id:
			return seal[2]
	return ""


func _branch(id: StringName) -> StringName:
	var upgrade := MetaProgress.find(id)
	return upgrade.branch if upgrade != null else id


# --- The board's position ---

func _on_board_resized() -> void:
	if board.size.x <= 0.0:
		return
	# The point in the window's middle stays there as the window settles.
	if not _placed:
		_placed = true
		_place(board.size * 0.5 - _centers[MetaProgress.ROOT] * zoom)
	else:
		_place(canvas.position + (board.size - _board_size) * 0.5)
	_board_size = board.size


func _place(at: Vector2) -> void:
	canvas.position = _clamp(at)
	_edges.queue_redraw()


# The canvas kept where the window stays over the nodes and their margin.
func _clamp(at: Vector2) -> Vector2:
	var bounds := Rect2(_centers[MetaProgress.ROOT], Vector2.ZERO)
	for id: StringName in nodes:
		bounds = bounds.merge(Rect2(_centers[id], Vector2.ZERO).grow((nodes[id] as Button).size.x * 0.5 + PIP_SIZE * 2.0))
	bounds = Rect2(bounds.position * zoom, bounds.size * zoom)
	bounds = bounds.grow_individual(board.size.x * BOARD_MARGIN, board.size.y * BOARD_MARGIN, board.size.x * BOARD_MARGIN, board.size.y * BOARD_MARGIN)
	var result := at
	for axis in 2:
		var low: float = board.size[axis] - bounds.end[axis]
		var high: float = -bounds.position[axis]
		result[axis] = (low + high) * 0.5 if low > high else clampf(at[axis], low, high)
	return result


# Brings a node inside the window's margin, if it is out of it.
func _follow(id: StringName) -> void:
	if board.size.x <= 0.0:
		return
	var center := _on_board(id)
	var inner := Rect2(Vector2.ZERO, board.size).grow(-FOLLOW_MARGIN)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0 or inner.has_point(center):
		return
	var kept := Vector2(clampf(center.x, inner.position.x, inner.end.x), clampf(center.y, inner.position.y, inner.end.y))
	_pan_to(canvas.position + kept - center)


func _pan_to(at: Vector2) -> void:
	_stop_pan()
	if not is_visible_in_tree():
		_place(at)
		return
	_pan_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pan_tween.tween_method(_place, canvas.position, _clamp(at), FOLLOW_TIME)


func _stop_pan() -> void:
	if _pan_tween != null:
		_pan_tween.kill()
		_pan_tween = null


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
	if stick != Vector2.ZERO:
		_stop_pan()
		_place(canvas.position - stick * PAN_SPEED * delta)
	var pull := _triggers.y - _triggers.x
	if absf(pull) > 0.1:
		_stop_pan()
		_set_zoom(zoom * pow(ZOOM_RATE, pull * delta), board.size * 0.5)


# A node's centre in the window.
func _on_board(id: StringName) -> Vector2:
	return canvas.position + _centers[id] * zoom


# Zooms to `value`, keeping the board's point under `anchor` where it is.
func _set_zoom(value: float, anchor: Vector2) -> void:
	var under := (anchor - canvas.position) / zoom
	zoom = clampf(value, ZOOM_MIN, ZOOM_MAX)
	canvas.scale = Vector2.ONE * zoom
	_place(anchor - under * zoom)


# --- The pointer ---

func _node_at(at: Vector2) -> StringName:
	var point := (at - canvas.position) / zoom
	for id: StringName in nodes:
		if point.distance_to(_centers[id]) <= (nodes[id] as Button).size.x * 0.5:
			return id
	return &""


func _board_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if event.pressed:
			_stop_pan()
			_set_zoom(zoom * (ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP), event.position)
		board.accept_event()
	elif event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if event.pressed:
			_press_at = event.position
			_press_node = _node_at(event.position)
			_dragging = false
		elif _press_at != Vector2.INF:
			if not _dragging and event.button_index == MOUSE_BUTTON_LEFT and not _press_node.is_empty() and _press_node == _node_at(event.position):
				_choose_by_pointer(_press_node)
			_press_at = Vector2.INF
			_dragging = false
		board.accept_event()
	elif event is InputEventMouseMotion:
		if _press_at != Vector2.INF:
			if not _dragging and event.position.distance_to(_press_at) >= DRAG_THRESHOLD:
				_dragging = true
				_hover_node = &""
				_stop_pan()
			if _dragging:
				_place(canvas.position + event.relative)
			board.accept_event()
			return
		var under := _node_at(event.position)
		if under != _hover_node:
			_hover_node = under
			if not under.is_empty():
				_rest_on(under)


# Resting the pointer on a node a moment chooses it.
func _rest_on(id: StringName) -> void:
	await get_tree().create_timer(HubLobby.HOVER_INTENT).timeout
	if _hover_node == id and not _dragging and _press_at == Vector2.INF and is_visible_in_tree():
		_choose_by_pointer(id)


func _choose_by_pointer(id: StringName) -> void:
	var node: Button = nodes[id]
	if node.has_focus():
		return
	_pointer_focus = true
	node.grab_focus()
	_pointer_focus = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		_triggers[0 if event.axis == JOY_AXIS_TRIGGER_LEFT else 1] = event.axis_value
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C
	var pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y
	if key or pad:
		center_view()
		get_viewport().set_input_as_handled()


# --- Drawing ---

func _state_color(id: StringName) -> Color:
	if MetaProgress.find(id) == null or meta == null:
		return get_theme_color(&"line_closed", &"UpgradeTree")
	if meta.rank(id) > 0:
		return get_theme_color(&"line_held", &"UpgradeTree")
	return get_theme_color(&"line_open" if meta.unlocked(id) else &"line_closed", &"UpgradeTree")


func _draw_lines() -> void:
	for id: StringName in nodes:
		var parent: StringName = _parents[id]
		if parent.is_empty():
			continue
		var from: Vector2 = _centers[parent]
		var to: Vector2 = _centers[id]
		var along := (to - from).normalized()
		var start := from + along * (nodes[parent] as Button).size.x * 0.5
		var end := to - along * ((nodes[id] as Button).size.x * 0.5 + 4.0)
		if MetaProgress.find(id) == null:
			canvas.draw_dashed_line(start, end, _state_color(id), LINE_WIDTH, 10.0)
		else:
			canvas.draw_line(start, end, _state_color(id), LINE_WIDTH, true)
	# Each branch's name by its first node: above it, or below the lower seal,
	# whose line comes in from above.
	var font := get_theme_font(&"font", &"MutedLabel")
	var font_size := get_theme_font_size(&"font_size", &"MutedLabel")
	var color := get_theme_color(&"font_color", &"MutedLabel")
	for id: StringName in nodes:
		if _parents[id] != MetaProgress.ROOT:
			continue
		var text: String = BRANCH_NAMES.get(_branch(id), "")
		var radius := (nodes[id] as Button).size.x * 0.5
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var center: Vector2 = _centers[id]
		var at := center + Vector2(-width * 0.5, -radius - 10.0)
		if center.y > _centers[MetaProgress.ROOT].y:
			at.y = center.y + radius + 10.0 + font.get_ascent(font_size)
		canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_node(node: Button, id: StringName) -> void:
	var middle := node.size * 0.5
	var radius := node.size.x * 0.5
	var upgrade := MetaProgress.find(id)
	node.draw_circle(middle, radius, get_theme_color(&"disc", &"UpgradeTree"))
	var closed := upgrade == null or (meta != null and not meta.unlocked(id))
	var emblem := EmblemIcons.texture(_emblem(id))
	if emblem != null:
		node.draw_texture_rect(emblem, Rect2(Vector2.ZERO, node.size), false, get_theme_color(&"closed_tint", &"UpgradeTree") if closed else Color.WHITE)
	if upgrade == null:
		node.draw_arc(middle, radius + 2.0, 0.0, TAU, 48, get_theme_color(&"seal", &"UpgradeTree"), 2.0, true)
	elif meta != null and meta.rank(id) > 0:
		node.draw_arc(middle, radius + 2.0, 0.0, TAU, 48, get_theme_color(&"line_held", &"UpgradeTree"), 2.0, true)
	if node.has_focus():
		node.draw_arc(middle, radius + 5.0, 0.0, TAU, 64, get_theme_color(&"focus", &"UpgradeTree"), RING_WIDTH, true)
	if upgrade != null and meta != null:
		_paint_pips(node, Vector2(middle.x, node.size.y + 5.0), upgrade, meta.rank(id))


# An upgrade's ranks as sockets, centred on `top`; one rank shows none.
func _paint_pips(target: CanvasItem, top: Vector2, upgrade: MetaUpgrade, held: int) -> void:
	var count := upgrade.max_rank()
	if count <= 1:
		return
	var empty := get_theme_icon(&"pip_empty", &"AbilityCard")
	var full := get_theme_icon(&"pip_full", &"AbilityCard")
	var width := PIP_SIZE * full.get_width() / full.get_height()
	var gap := 2.0
	var start := top.x - (width * count + gap * (count - 1)) * 0.5
	for index in count:
		var rect := Rect2(start + index * (width + gap), top.y, width, PIP_SIZE)
		target.draw_texture_rect(empty, rect, false)
		if index < held:
			target.draw_texture_rect(full, rect, false)


# Arrows at the window's edge toward the branches wholly out of sight, the
# names outlined in the well's colour rather than set on a plate, so the
# lines running to the edge stay in view.
func _draw_edges() -> void:
	var window := Rect2(Vector2.ZERO, board.size)
	var inset := window.grow(-26.0)
	if inset.size.x <= 0.0 or inset.size.y <= 0.0:
		return
	var font := get_theme_font(&"font", &"MutedLabel")
	var font_size := get_theme_font_size(&"font_size", &"MutedLabel")
	var color := get_theme_color(&"font_color", &"MutedLabel")
	var outline := get_theme_color(&"well", &"UpgradeTree")
	for id: StringName in nodes:
		if _parents[id] != MetaProgress.ROOT:
			continue
		var center := _on_board(id)
		var extent := (nodes[id] as Button).size * zoom
		if window.intersects(Rect2(center - extent * 0.5, extent)):
			continue
		var at := Vector2(clampf(center.x, inset.position.x, inset.end.x), clampf(center.y, inset.position.y, inset.end.y))
		var toward := (center - at).normalized()
		var side := toward.orthogonal()
		var text: String = BRANCH_NAMES.get(_branch(id), "")
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		# The name runs along the edge beside the arrow, off the nodes inside.
		var label := at + Vector2(14.0, font.get_ascent(font_size) * 0.4) if absf(toward.y) > absf(toward.x) else at + Vector2(-width * 0.5, -14.0)
		label.x = clampf(label.x, 6.0, board.size.x - width - 6.0)
		_edges.draw_colored_polygon(PackedVector2Array([at + toward * 9.0, at - toward * 3.0 + side * 7.0, at - toward * 3.0 - side * 7.0]), color)
		_edges.draw_string_outline(font, label, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, outline)
		_edges.draw_string(font, label, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
