class_name HubUI
extends RefCounted

# Structure only: appearance and spacing are owned by dungeon_theme.tres.
const PRIMARY_ACTION_HEIGHT := 60.0
# How the game draws its gilt lines and small marks: &"plain" (hairlines of
# one width and diamonds) or &"star" (four-pointed stars, and lines that
# taper). On trial: a run started with `-- --ornaments=star` shows the star
# style; the game ships plain until one is chosen.
static var ornaments: StringName = &"star" if OS.get_cmdline_user_args().has("--ornaments=star") else &"plain"
# A star stands this much wider than the diamond it replaces, its waist this
# share of its reach; a line keeps this far clear of a star, and a needle is
# this thick at its middle.
const STAR_SCALE := 1.5
const STAR_WAIST := 0.3
const STAR_WAIST_SMALL := 0.46
const STAR_ROOM := 14.0
const NEEDLE := 2.6


static func columns(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return row


static func section(parent: Node, ratio: float = 1.0, role: StringName = &"MainPanel") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = role
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	parent.add_child(panel)
	var margin := MarginContainer.new()
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	return stack


static func label(parent: Node, text: String, role: StringName = &"BodyLabel") -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = role
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


static func button(parent: Node, text: String, action: Callable, role: StringName = &"SecondaryButton") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = role
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button


# The screen's one primary action (docs/画面とUI.md, 個別画面のUI文法): the
# same plate as the lobby's decide button, full width at the foot of the
# right panel. Other actions are SecondaryButton above it.
static func primary_action(parent: Node, text: String, action: Callable) -> Button:
	var button := button(parent, text, action, &"PrimaryAction")
	button.custom_minimum_size.y = PRIMARY_ACTION_HEIGHT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


# Enter (A) on a chosen row moves to the screen's primary action, and the
# next press acts there: choosing never acts by itself (docs/画面とUI.md,
# 個別画面のUI文法). A double click lands there too.
static func accept_to_action(list: ItemList, action: Button) -> void:
	list.item_activated.connect(func(_index: int):
		if action.is_visible_in_tree() and not action.disabled:
			action.grab_focus())


# A column laid on the hall without a framed box: a dark slab whose right
# edge melts into the background, like the lobby menu (SlabColumn), or only
# a soft shade behind the text (ShadeColumn).
static func open_column(parent: Node, ratio: float, role: StringName) -> VBoxContainer:
	var column := PanelContainer.new()
	column.theme_type_variation = role
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = ratio
	parent.add_child(column)
	var stack := VBoxContainer.new()
	column.add_child(stack)
	return stack


# A gilt hairline fading at both ends with a diamond in the middle, to part
# what a box used to.
static func rule(parent: Node) -> Control:
	var rule := Control.new()
	rule.custom_minimum_size.y = 12
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.draw.connect(func():
		var rail := rule.get_theme_color(&"rail", &"HubLobby")
		var y := rule.size.y * 0.5
		var w := rule.size.x
		var c := Vector2(w * 0.5, y)
		if starred():
			trail(rule, c - Vector2(STAR_ROOM, 0), Vector2(0, y), Color(rail, 0.7))
			trail(rule, c + Vector2(STAR_ROOM, 0), Vector2(w, y), Color(rail, 0.7))
		else:
			rule.draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(w * 0.5, y), Vector2(w, y)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.55), Color(rail, 0.0)]), 1.0, true)
		diamond(rule, c, 4.0, Color(rail, 0.85)))
	parent.add_child(rule)
	return rule


# The same hairline standing upright, width wide, to part two columns that
# sit side by side on one slab (the preparation's warehouse and carried goods).
static func column_rule(parent: Node, width: float) -> Control:
	var rule := Control.new()
	rule.custom_minimum_size.x = width
	rule.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.draw.connect(func():
		var rail := rule.get_theme_color(&"rail", &"HubLobby")
		var x := rule.size.x * 0.5
		var h := rule.size.y
		var c := Vector2(x, h * 0.5)
		if starred():
			trail(rule, c - Vector2(0, STAR_ROOM), Vector2(x, 0), Color(rail, 0.7))
			trail(rule, c + Vector2(0, STAR_ROOM), Vector2(x, h), Color(rail, 0.7))
		else:
			rule.draw_polyline_colors(PackedVector2Array([Vector2(x, 0), Vector2(x, h * 0.12), Vector2(x, h * 0.88), Vector2(x, h)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.55), Color(rail, 0.55), Color(rail, 0.0)]), 1.0, true)
		diamond(rule, c, 4.0, Color(rail, 0.85)))
	parent.add_child(rule)
	return rule


# A plaque at the foot of a hall that is left open to its painting: a slab
# with an item's name and, beneath, a line of what it is. Returns the name
# and the note, for the page to fill.
static func plaque(hall: VBoxContainer, width: float) -> Array[Label]:
	space(hall)
	var plate := PanelContainer.new()
	plate.theme_type_variation = &"SlabPlaque"
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.custom_minimum_size.x = width
	hall.add_child(plate)
	var stack := VBoxContainer.new()
	stack.theme_type_variation = &"CompactStack"
	plate.add_child(stack)
	# The plate keeps its width whatever it says: a long name is trimmed and a
	# long line wraps, so the hall's other parts never move for it.
	var name_label := label(stack, "", &"TitleLabel")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var note := label(stack, "", &"PlaqueNote")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var floor_gap := Control.new()
	floor_gap.custom_minimum_size.y = 14
	floor_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hall.add_child(floor_gap)
	return [name_label, note]


# The plaque's second line: the parts parted by a diamond, or one to a line
# when together they would be too long for the plate.
static func plaque_note(parts: Array[String]) -> String:
	var joined := "　◆　".join(parts)
	return joined if joined.length() <= 22 else "\n".join(parts)


# The lobby's ornate frame, laid over a panel (the lobby's panel, the
# departure's band): a gilt line round the edge with a fainter one inside,
# brackets at the corners and a diamond at the middle of the top and the
# foot. Returns the frame, which draws over what the panel holds.
static func ornate_frame(panel: Control) -> Control:
	var frame := Control.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(func():
		var rail := frame.get_theme_color(&"rail", &"HubLobby")
		var rect := Rect2(Vector2.ZERO, frame.size)
		if starred():
			# A faint edge, and at each corner a star with a line running out
			# from it along both sides; a star at the middle of the top and foot.
			frame.draw_rect(rect.grow(-1), Color(rail, 0.3), false, 1.0)
			for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
				var inward := Vector2(signf(rect.get_center().x - corner.x), signf(rect.get_center().y - corner.y))
				var at: Vector2 = corner + inward
				trail(frame, at + Vector2(inward.x * STAR_ROOM, 0), at + Vector2(inward.x * minf(170.0, rect.size.x * 0.4), 0), rail)
				trail(frame, at + Vector2(0, inward.y * STAR_ROOM), at + Vector2(0, inward.y * minf(70.0, rect.size.y * 0.4)), rail)
				star(frame, at, 9.0, rail)
			for center in [Vector2(rect.get_center().x, 1), Vector2(rect.get_center().x, rect.end.y - 1)]:
				star(frame, center, 7.0, Color(rail, 0.85))
			return
		frame.draw_rect(rect.grow(-1), Color(rail, 0.55), false, 1.0)
		frame.draw_rect(rect.grow(-6), Color(rail, 0.18), false, 1.0)
		var arm := 26.0
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var inward := Vector2(signf(rect.get_center().x - corner.x), signf(rect.get_center().y - corner.y))
			var at: Vector2 = corner + inward * 3.0
			frame.draw_polyline(PackedVector2Array([at + Vector2(inward.x * arm, 0), at, at + Vector2(0, inward.y * arm)]), rail, 2.0, true)
		for center in [Vector2(rect.get_center().x, 1), Vector2(rect.get_center().x, rect.end.y - 1)]:
			diamond(frame, center, 6.0, rail))
	panel.add_child(frame)
	return frame


# The lobby's strip of facts: a dark band whose ends melt into the panel,
# between faint gilt hairlines, instead of a sunken box. Returns the row the
# facts go in.
static func fact_strip(parent: Node, height: float) -> HBoxContainer:
	var band := Control.new()
	band.custom_minimum_size.y = height
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.draw.connect(func():
		var rail := band.get_theme_color(&"rail", &"HubLobby")
		var dark := band.get_theme_color(&"fact_band", &"HubLobby")
		var clear := Color(dark, 0.0)
		var w := band.size.x
		var h := band.size.y
		band.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.5, 0), Vector2(w * 0.5, h), Vector2(0, h)]), PackedColorArray([clear, dark, dark, clear]))
		band.draw_polygon(PackedVector2Array([Vector2(w * 0.5, 0), Vector2(w, 0), Vector2(w, h), Vector2(w * 0.5, h)]), PackedColorArray([dark, clear, clear, dark]))
		for y in [0.5, h - 0.5]:
			band.draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(w * 0.5, y), Vector2(w, y)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.45), Color(rail, 0.0)]), 1.0, true))
	parent.add_child(band)
	var row := HBoxContainer.new()
	row.theme_type_variation = &"LobbyFactRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return row


# One fact on a strip: a small kicker above its value, both centred.
static func strip_fact(row: HBoxContainer, caption: String, value_role: StringName = &"LobbyFactValue", caption_role: StringName = &"LobbyFactCaption") -> Label:
	var cell := VBoxContainer.new()
	cell.theme_type_variation = &"LobbyFact"
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cell)
	var kicker := label(cell, caption, caption_role)
	kicker.autowrap_mode = TextServer.AUTOWRAP_OFF
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var value := label(cell, "", value_role)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return value


# A gilt diamond between the facts on a strip, with hairlines fading above
# and below.
static func strip_divider(row: HBoxContainer) -> void:
	var mark := Control.new()
	mark.custom_minimum_size.x = 24
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(func():
		var rail := mark.get_theme_color(&"rail", &"HubLobby")
		var middle := mark.size * 0.5
		mark.draw_polyline_colors(PackedVector2Array([middle + Vector2(0, -22), middle + Vector2(0, -8)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.6)]), 1.0, true)
		mark.draw_polyline_colors(PackedVector2Array([middle + Vector2(0, 8), middle + Vector2(0, 22)]), PackedColorArray([Color(rail, 0.6), Color(rail, 0.0)]), 1.0, true)
		diamond(mark, middle, 5.0, Color(rail, 0.9)))
	row.add_child(mark)


# The game's small mark: a diamond or, in the star style, a four-pointed
# star standing a little wider, as its points are thin.
static func diamond(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	if starred():
		star(canvas, center, radius * STAR_SCALE, color)
		return
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)


static func starred() -> bool:
	return ornaments == &"star"


# A four-pointed star, as the lobby's crest and the upgrades' chart draw
# theirs: long points up, down and to the sides, pinched in between.
static func star(canvas: CanvasItem, center: Vector2, radius: float, color: Color, turn := 0.0) -> void:
	# A small star keeps a fuller waist, or its thin points read as a plus sign.
	var waist := lerpf(STAR_WAIST_SMALL, STAR_WAIST, clampf((radius - 6.0) / 8.0, 0.0, 1.0))
	var points := PackedVector2Array()
	for step in 8:
		points.append(center + Vector2.from_angle(turn + TAU * step / 8.0 - PI * 0.5) * (radius if step % 2 == 0 else radius * waist))
	canvas.draw_colored_polygon(points, color)


# A diamond in either style: the knob of a bar, which is a thing to hold
# and not a mark.
static func lozenge(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)


# A gilt line between two points: a hairline or, in the star style, a
# needle, thickest in its middle and running out to nothing at both ends.
static func hairline(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, width := 1.0) -> void:
	if not starred():
		canvas.draw_line(from, to, color, width, true)
		return
	var middle := (from + to) * 0.5
	var side := (to - from).orthogonal().normalized() * maxf(NEEDLE, width * 2.2) * 0.5
	canvas.draw_polygon(PackedVector2Array([from, middle - side, to, middle + side]), PackedColorArray([Color(color, 0.0), color, Color(color, 0.0), color]))


# A gilt line that starts at `from` and runs out toward `to`: a hairline or,
# in the star style, a point drawn out from a star or a heading.
static func trail(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, width := 1.0) -> void:
	if not starred():
		canvas.draw_line(from, to, color, width, true)
		return
	var side := (to - from).orthogonal().normalized() * maxf(NEEDLE, width * 1.5) * 0.5
	canvas.draw_polygon(PackedVector2Array([from - side, to, from + side]), PackedColorArray([color, Color(color, 0.0), color]))


static func space(parent: Node) -> Control:
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(space)
	return space
