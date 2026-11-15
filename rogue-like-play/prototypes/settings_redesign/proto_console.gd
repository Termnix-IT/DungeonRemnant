class_name ProtoConsole
extends ProtoScreen

# A, the tuning board: every setting on one bronze board, each as the thing
# a hand would move. The four volumes are faders side by side, the shake a
# dial of three marks, the screen a lever, the language and the controls
# guide pairs of plates, the help and the end of the game two buttons. No
# tabs: all ten are in sight at once, under the names of their groups, and
# a plaque at the board's foot says what the one under the cursor does.
# Left and right go from control to control, up and down move the one under
# the cursor (a fader up, a dial round), Enter presses a button.

const WOOD := Color(0.075, 0.058, 0.045)
const BOARD := Color(0.115, 0.095, 0.075)
const BRASS := Color(0.74, 0.58, 0.32)
const GOLD := Color(1.0, 0.82, 0.46)
const PALE := Color(0.94, 0.90, 0.82)
const DIM := Color(0.66, 0.60, 0.52)
const SLOT := Color(0.03, 0.025, 0.02)
const RED := Color(0.86, 0.36, 0.28)
const PANEL := Rect2(110.0, 120.0, 1380.0, 680.0)
# Where each row's control stands on the board.
const ROOMS := {
	0: Rect2(170.0, 220.0, 120.0, 430.0), 1: Rect2(300.0, 220.0, 120.0, 430.0),
	2: Rect2(430.0, 220.0, 120.0, 430.0), 3: Rect2(560.0, 220.0, 120.0, 430.0),
	4: Rect2(760.0, 220.0, 170.0, 300.0), 5: Rect2(940.0, 220.0, 150.0, 300.0),
	9: Rect2(1150.0, 220.0, 290.0, 96.0), 6: Rect2(1150.0, 326.0, 290.0, 96.0),
	7: Rect2(1150.0, 432.0, 290.0, 88.0), 8: Rect2(1150.0, 530.0, 290.0, 88.0),
}
const GROUP_LEFT: Array[float] = [170.0, 760.0, 1150.0]
const GROUP_RIGHT: Array[float] = [680.0, 1090.0, 1440.0]
const PLAQUE := Rect2(760.0, 640.0, 680.0, 110.0)


func _init(of: ProtoSettings) -> void:
	super(of)
	backdrop("shader_type canvas_item;\n" + NOISE + """
void fragment() {
	vec2 p = UV * vec2(1600.0, 900.0);
	float grain = fbm(p * vec2(0.003, 0.05));
	vec3 colour = mix(vec3(0.045, 0.032, 0.024), vec3(0.105, 0.075, 0.05), grain);
	colour *= 1.0 - 0.5 * smoothstep(0.3, 0.9, length(UV - 0.5));
	COLOR = vec4(colour, 1.0);
}
""")


func _key(action: StringName) -> void:
	match action:
		&"left":
			step(-1)
		&"right":
			step(1)
		&"up":
			change(1 if ProtoSettings.kind(focus) == &"slider" else -1)
		&"down":
			change(-1 if ProtoSettings.kind(focus) == &"slider" else 1)
		&"prev":
			turn(-1)
		&"next":
			turn(1)
		&"accept":
			accept()


func _wheel(by: int) -> void:
	change(-by)


func _paint() -> void:
	spaced(Vector2(120.0, 78.0), "設定", MINCHO_B, 34, PALE, 6.0)
	plate(PANEL, BOARD, Color(BRASS, 0.8), 6.0, 2.0)
	draw_rect(PANEL.grow(-8.0), Color(BRASS, 0.25), false, 1.0)
	for corner: Vector2 in [PANEL.position + Vector2(22.0, 22.0), Vector2(PANEL.end.x - 22.0, PANEL.position.y + 22.0), PANEL.end - Vector2(22.0, 22.0), Vector2(PANEL.position.x + 22.0, PANEL.end.y - 22.0)]:
		draw_circle(corner, 7.0, Color(BRASS, 0.9))
		draw_line(corner - Vector2(4.0, 0.0), corner + Vector2(4.0, 0.0), SLOT, 1.5)
	for group in ProtoSettings.groups():
		var here := ProtoSettings.group_of(focus) == group
		var left := GROUP_LEFT[group]
		spaced(Vector2(left, 190.0), ProtoSettings.group_name(group), MINCHO_B, 20, GOLD if here else DIM, 4.0)
		var from_x := left + width_of(ProtoSettings.group_name(group), MINCHO_B, 20) + 4.0 * ProtoSettings.group_name(group).length() + 14.0
		draw_line(Vector2(from_x, 183.0), Vector2(GROUP_RIGHT[group], 183.0), Color(BRASS, 0.5 if here else 0.25), 1.0)
	for row: int in ProtoSettings.ORDER:
		var room: Rect2 = ROOMS[row]
		zone(room, [&"item", row])
		match row:
			0, 1, 2, 3:
				_fader(row, room)
			4:
				_dial(row, room)
			5:
				_lever(row, room)
			6, 9:
				_plates(row, room)
			_:
				_push(row, room)
	_cursor()
	_plaque()


func _lit(row: int) -> bool:
	return row == focus


func _name(row: int, at: Vector2, wide: float) -> void:
	text(at, ProtoSettings.caption(row), GOTHIC_B if _lit(row) else GOTHIC, 16, GOLD if _lit(row) else (PALE if hovered(row) else DIM), HORIZONTAL_ALIGNMENT_CENTER, wide)


# A volume: a slot with a mark every tenth, the level filled from its foot,
# and a knob.
func _fader(row: int, room: Rect2) -> void:
	var x := room.get_center().x
	var top := room.position.y + 62.0
	var foot := room.end.y - 62.0
	var level := model.percent(row) / 100.0
	var knob := lerpf(foot, top, level)
	var size := int(26.0 * (pop() if _lit(row) else 1.0))
	text(Vector2(room.position.x, room.position.y + 34.0), model.value(row), MINCHO_B, size, PALE if _lit(row) else DIM, HORIZONTAL_ALIGNMENT_CENTER, room.size.x)
	draw_rect(Rect2(x - 4.0, top, 8.0, foot - top), SLOT)
	draw_rect(Rect2(x - 4.0, top, 8.0, foot - top), Color(BRASS, 0.5), false, 1.0)
	draw_rect(Rect2(x - 3.0, knob, 6.0, foot - knob), GOLD if _lit(row) else Color(BRASS, 0.8))
	for mark in 11:
		var y := lerpf(foot, top, mark / 10.0)
		var reach := 14.0 if mark % 5 == 0 else 8.0
		draw_line(Vector2(x - 12.0 - reach, y), Vector2(x - 12.0, y), Color(BRASS, 0.55), 1.0)
		draw_line(Vector2(x + 12.0, y), Vector2(x + 12.0 + reach, y), Color(BRASS, 0.55), 1.0)
		zone(Rect2(room.position.x, y - (foot - top) / 20.0, room.size.x, (foot - top) / 10.0), [&"set", row, mark * 10])
	if _lit(row):
		glow(Vector2(x, knob), 44.0, Color(GOLD, 0.35))
	plate(Rect2(x - 30.0, knob - 12.0, 60.0, 24.0), BRASS.lightened(0.25) if _lit(row) else BRASS, Color(0.2, 0.14, 0.06), 4.0, 1.0)
	draw_line(Vector2(x - 20.0, knob), Vector2(x + 20.0, knob), SLOT, 2.0)
	_name(row, Vector2(room.position.x, room.end.y - 22.0), room.size.x)


# The shake: a dial whose pointer turns to one of its marks.
func _dial(row: int, room: Rect2) -> void:
	var centre := Vector2(room.get_center().x, room.position.y + 150.0)
	var names := model.choices(row)
	var chosen := model.chosen(row)
	var angles: Array[float] = []
	for index in names.size():
		angles.append(lerpf(-PI * 0.85, -PI * 0.15, float(index) / (names.size() - 1)))
	for index in names.size():
		var way := Vector2.from_angle(angles[index])
		var on := index == chosen
		draw_line(centre + way * 58.0, centre + way * 70.0, GOLD if on else Color(BRASS, 0.6), 2.0, true)
		text(centre + way * 92.0 - Vector2(40.0, -6.0), names[index], GOTHIC_B if on else GOTHIC, 15, (GOLD if _lit(row) else PALE) if on else DIM, HORIZONTAL_ALIGNMENT_CENTER, 80.0)
		zone(Rect2(centre + way * 92.0 - Vector2(40.0, 16.0), Vector2(80.0, 30.0)), [&"set", row, index])
	if _lit(row):
		glow(centre, 80.0, Color(GOLD, 0.22))
	draw_circle(centre, 50.0, SLOT)
	draw_circle(centre, 46.0, BRASS.darkened(0.25))
	ring(centre, 46.0, BRASS.lightened(0.2) if _lit(row) else BRASS, 2.0)
	var turn_to := angles[chosen]
	if _lit(row) and since(&"change") < CHANGE_TIME:
		turn_to += 0.25 * (1.0 - eased(&"change", CHANGE_TIME))
	var hand := Vector2.from_angle(turn_to)
	draw_line(centre + hand * 8.0, centre + hand * 42.0, GOLD if _lit(row) else PALE, 4.0, true)
	draw_circle(centre, 9.0, SLOT)
	_name(row, Vector2(room.position.x, room.end.y - 22.0), room.size.x)


# The screen: a lever up for a window, down for the whole screen.
func _lever(row: int, room: Rect2) -> void:
	var x := room.get_center().x
	var top := room.position.y + 90.0
	var foot := room.position.y + 190.0
	var names := model.choices(row)
	var chosen := model.chosen(row)
	draw_rect(Rect2(x - 9.0, top - 10.0, 18.0, foot - top + 20.0), SLOT)
	draw_rect(Rect2(x - 9.0, top - 10.0, 18.0, foot - top + 20.0), Color(BRASS, 0.6), false, 1.0)
	for index in names.size():
		var y := top if index == 0 else foot
		var on := index == chosen
		text(Vector2(room.position.x, y + (-28.0 if index == 0 else 42.0)), names[index], GOTHIC_B if on else GOTHIC, 15, (GOLD if _lit(row) else PALE) if on else DIM, HORIZONTAL_ALIGNMENT_CENTER, room.size.x)
		zone(Rect2(room.position.x, y - 44.0 if index == 0 else y - 10.0, room.size.x, 54.0), [&"set", row, index])
	var knob := Vector2(x, top if chosen == 0 else foot)
	if _lit(row):
		glow(knob, 46.0, Color(GOLD, 0.3))
	draw_line(Vector2(x, (top + foot) * 0.5), knob, BRASS.darkened(0.3), 8.0, true)
	draw_circle(knob, 17.0, BRASS.lightened(0.25) if _lit(row) else BRASS)
	ring(knob, 17.0, Color(0.2, 0.14, 0.06), 1.5)
	_name(row, Vector2(room.position.x, room.end.y - 22.0), room.size.x)


# A choice of a few: plates side by side, the one set lit.
func _plates(row: int, room: Rect2) -> void:
	text(Vector2(room.position.x + 4.0, room.position.y + 24.0), ProtoSettings.caption(row), GOTHIC_B if _lit(row) else GOTHIC, 16, GOLD if _lit(row) else (PALE if hovered(row) else DIM))
	var names := model.choices(row)
	var wide := (room.size.x - 10.0 * (names.size() - 1)) / names.size()
	for index in names.size():
		var rect := Rect2(room.position.x + index * (wide + 10.0), room.position.y + 38.0, wide, 46.0)
		var on := index == model.chosen(row)
		plate(rect, BRASS.darkened(0.55) if on else SLOT, (GOLD if _lit(row) else BRASS) if on else Color(BRASS, 0.35), 4.0, 2.0 if on else 1.0)
		text(Vector2(rect.position.x, rect.position.y + 30.0), names[index], GOTHIC_B if on else GOTHIC, 17, (GOLD if _lit(row) else PALE) if on else DIM, HORIZONTAL_ALIGNMENT_CENTER, wide)
		zone(rect, [&"set", row, index])


# An action: a button.
func _push(row: int, room: Rect2) -> void:
	var rect := room.grow_individual(0.0, -10.0, 0.0, -10.0)
	var edge := RED if row == ProtoSettings.QUIT else BRASS
	var pressed := _lit(row) and since(&"act") < 0.2
	plate(rect.grow(-2.0 if pressed else 0.0), BRASS.darkened(0.6 if not _lit(row) else 0.45), edge.lightened(0.25) if _lit(row) else Color(edge, 0.7), 6.0, 2.0)
	text(Vector2(rect.position.x + 22.0, rect.get_center().y + 7.0), ProtoSettings.caption(row), GOTHIC_B, 17, GOLD if _lit(row) else PALE)
	text(Vector2(rect.position.x, rect.get_center().y + 7.0), model.value(row), MINCHO_B, 20, (RED.lightened(0.3) if row == ProtoSettings.QUIT else GOLD) if _lit(row) else DIM, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 22.0)
	zone(rect, [&"act", row])


# The cursor: gilt corners round the control it is on, on their way from the last.
func _cursor() -> void:
	var a: Rect2 = ROOMS[from]
	var b: Rect2 = ROOMS[focus]
	var share := moved()
	var room := Rect2(a.position.lerp(b.position, share), a.size.lerp(b.size, share)).grow(6.0)
	for corner: Array in [[room.position, Vector2(1, 1)], [Vector2(room.end.x, room.position.y), Vector2(-1, 1)], [room.end, Vector2(-1, -1)], [Vector2(room.position.x, room.end.y), Vector2(1, -1)]]:
		var at: Vector2 = corner[0]
		var way: Vector2 = corner[1]
		draw_line(at, at + Vector2(way.x * 20.0, 0.0), GOLD, 2.5)
		draw_line(at, at + Vector2(0.0, way.y * 20.0), GOLD, 2.5)


# The plaque: what the control under the cursor does.
func _plaque() -> void:
	plate(PLAQUE, SLOT, Color(BRASS, 0.6), 4.0, 1.0)
	var fade := 0.3 + 0.7 * moved()
	text(PLAQUE.position + Vector2(26.0, 42.0), ProtoSettings.caption(focus), MINCHO_B, 24, Color(GOLD, fade))
	text(Vector2(PLAQUE.position.x, PLAQUE.position.y + 42.0), model.value(focus), MINCHO_B, 24, Color(PALE, fade), HORIZONTAL_ALIGNMENT_RIGHT, PLAQUE.size.x - 26.0)
	paragraph(PLAQUE.position + Vector2(26.0, 76.0), ProtoSettings.note(focus), GOTHIC, 17, Color(PALE, 0.9 * fade), PLAQUE.size.x - 52.0, 6.0, 2)
