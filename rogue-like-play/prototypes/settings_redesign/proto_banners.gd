class_name ProtoBanners
extends ProtoScreen

# C, the three banners: the groups hang side by side in the hall as banners
# of dark blue cloth edged in gilt, each with its name at its head and its
# settings down its length, all ten in sight. The banner the cursor is in
# hangs forward, lit and a little longer; the others hang back, dim. A
# setting is its name over its control: a bar for a volume, its choice
# between two marks, or the word of its action. What the one under the
# cursor does is said along the screen's foot.
# Up and down go through a banner, Q and E (and left and right past a
# setting that has nothing to change) turn to the next, left and right
# change the one under the cursor, Enter takes an action.

const CLOTH := Color(0.060, 0.085, 0.165)
const CLOTH_DARK := Color(0.030, 0.040, 0.080)
const GILT := Color(0.86, 0.70, 0.40)
const GOLD := Color(1.0, 0.84, 0.50)
const PALE := Color(0.94, 0.93, 0.90)
const DIM := Color(0.62, 0.64, 0.72)
const RED := Color(0.95, 0.50, 0.40)
const RAIL := 118.0
const WIDE := 400.0
const GAP := 60.0
const LENGTH := 560.0
const TAIL := 56.0
const ROW := 104.0


func _key(action: StringName) -> void:
	match action:
		&"up":
			step_in_group(-1)
		&"down":
			step_in_group(1)
		&"left":
			if ProtoSettings.kind(focus) == &"action":
				turn(-1)
			else:
				change(-1)
		&"right":
			if ProtoSettings.kind(focus) == &"action":
				turn(1)
			else:
				change(1)
		&"prev":
			turn(-1)
		&"next":
			turn(1)
		&"accept":
			accept()


func _wheel(by: int) -> void:
	step_in_group(by)


# How far forward a banner hangs (0 back, 1 forward).
func _forward(group: int) -> float:
	var now := ProtoSettings.group_of(focus)
	var before := ProtoSettings.group_of(from)
	if now == before:
		return 1.0 if group == now else 0.0
	var share := moved()
	return share if group == now else (1.0 - share if group == before else 0.0)


func _paint() -> void:
	hall(0.62)
	shade(Rect2(0.0, 0.0, VIEW.x, 200.0), Color(0.0, 0.0, 0.0, 0.7), Color(0.0, 0.0, 0.0, 0.0))
	shade(Rect2(0.0, 640.0, VIEW.x, 260.0), Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.9))
	spaced(Vector2(96.0, 78.0), "設定", MINCHO_B, 34, PALE, 6.0)
	var count := ProtoSettings.groups()
	var left := (VIEW.x - count * WIDE - (count - 1) * GAP) * 0.5
	# The rail the banners hang from.
	draw_line(Vector2(left - 40.0, RAIL), Vector2(VIEW.x - left + 40.0, RAIL), GILT.darkened(0.3), 6.0)
	for knob: float in [left - 40.0, VIEW.x - left + 40.0]:
		draw_circle(Vector2(knob, RAIL), 10.0, GILT)
	for group in count:
		_banner(group, left + group * (WIDE + GAP))
	var fade := 0.3 + 0.7 * moved()
	diamond(Vector2(VIEW.x * 0.5, 792.0), 5.0, Color(GILT, fade))
	text(Vector2(0.0, 836.0), ProtoSettings.note(focus), GOTHIC, 20, Color(PALE, fade), HORIZONTAL_ALIGNMENT_CENTER, VIEW.x)


# A colour as it shows on a banner hanging back: darker, as solid as before.
func _dimmed(colour: Color, bright: float) -> Color:
	return Color(colour.r * bright, colour.g * bright, colour.b * bright, colour.a)


func _banner(group: int, x: float) -> void:
	var forward := _forward(group)
	var sway := sin(clock * 0.9 + group * 1.7) * 3.0 * (1.0 - forward * 0.6)
	var length := LENGTH + 24.0 * forward
	var top := RAIL + 6.0
	var bright := lerpf(0.55, 1.0, forward)
	# The cloth: a long field with a swallow's tail, a little aslant as it sways.
	var cloth := PackedVector2Array([
		Vector2(x, top), Vector2(x + WIDE, top), Vector2(x + WIDE + sway, top + length + TAIL),
		Vector2(x + WIDE * 0.5 + sway, top + length), Vector2(x + sway, top + length + TAIL),
	])
	draw_colored_polygon(PackedVector2Array([cloth[0] + Vector2(8.0, 10.0), cloth[1] + Vector2(8.0, 10.0), cloth[2] + Vector2(8.0, 10.0), cloth[3] + Vector2(8.0, 10.0), cloth[4] + Vector2(8.0, 10.0)]), Color(0.0, 0.0, 0.0, 0.35))
	draw_polygon(cloth, PackedColorArray([_dimmed(CLOTH, bright), _dimmed(CLOTH, bright), _dimmed(CLOTH_DARK, bright), _dimmed(CLOTH_DARK, bright), _dimmed(CLOTH_DARK, bright)]))
	var edge := PackedVector2Array(cloth)
	edge.append(cloth[0])
	draw_polyline(edge, Color(GOLD if forward > 0.5 else GILT, lerpf(0.45, 1.0, forward)), 2.0 + forward, true)
	for ring_x: float in [x + 50.0, x + WIDE * 0.5, x + WIDE - 50.0]:
		ring(Vector2(ring_x, RAIL), 9.0, GILT, 2.5)
	# Its name at its head.
	var name := ProtoSettings.group_name(group)
	spaced(Vector2(x + WIDE * 0.5, top + 52.0), name, MINCHO_B, 28, Color(GOLD if forward > 0.5 else DIM, 1.0), 6.0, true)
	draw_line(Vector2(x + 60.0, top + 72.0), Vector2(x + WIDE - 60.0, top + 72.0), Color(GILT, 0.3 + 0.4 * forward), 1.0)
	diamond(Vector2(x + WIDE * 0.5, top + 72.0), 5.0, Color(GILT, 0.5 + 0.5 * forward))
	zone(Rect2(x, top, WIDE, length), [&"item", ProtoSettings.rows(group)[0] if ProtoSettings.group_of(focus) != group else focus])
	var rows := ProtoSettings.rows(group)
	for place in rows.size():
		_setting(rows[place], Rect2(x + 36.0 + sway * (place + 1) / 6.0, top + 92.0 + place * ROW, WIDE - 72.0, ROW), bright)


func _setting(row: int, rect: Rect2, bright: float) -> void:
	var lit := row == focus
	var ink := _dimmed(PALE if lit or hovered(row) else DIM, bright)
	zone(rect, [&"item", row])
	if lit:
		shade_across(Rect2(rect.position.x - 20.0, rect.position.y + 4.0, rect.size.x + 40.0, rect.size.y - 12.0), Color(GOLD, 0.16), Color(GOLD, 0.02))
		draw_rect(Rect2(rect.position.x - 20.0, rect.position.y + 4.0, 3.0, rect.size.y - 12.0), GOLD)
	text(rect.position + Vector2(0.0, 34.0), ProtoSettings.caption(row), GOTHIC_B if lit else GOTHIC, 18, GOLD if lit else ink)
	var base := rect.position.y + 74.0
	match ProtoSettings.kind(row):
		&"slider":
			text(rect.position + Vector2(0.0, 34.0), model.value(row), MINCHO_B, int(22.0 * (pop() if lit else 1.0)), ink, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x)
			var track := Rect2(rect.position.x, base - 10.0, rect.size.x, 4.0)
			var level := model.percent(row) / 100.0
			draw_rect(track, Color(1.0, 1.0, 1.0, 0.14 * bright))
			draw_rect(Rect2(track.position, Vector2(track.size.x * level, 4.0)), GOLD if lit else Color(GILT, 0.75 * bright))
			var knob := Vector2(track.position.x + track.size.x * level, track.position.y + 2.0)
			if lit:
				glow(knob, 22.0, Color(GOLD, 0.4))
			diamond(knob, 8.0, GOLD if lit else _dimmed(GILT, bright))
			for mark in 21:
				zone(Rect2(track.position.x + track.size.x * (mark - 0.5) / 20.0, base - 26.0, track.size.x / 20.0, 36.0), [&"set", row, mark * 5])
		&"cycle":
			text(Vector2(rect.position.x, base), model.value(row), GOTHIC_B, 20, ink, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
			text(Vector2(rect.position.x + 6.0, base), "〈", GOTHIC, 20, GOLD if lit else Color(DIM, 0.5 * bright))
			text(Vector2(rect.end.x - 26.0, base), "〉", GOTHIC, 20, GOLD if lit else Color(DIM, 0.5 * bright))
			zone(Rect2(rect.position.x - 6.0, base - 30.0, 60.0, 42.0), [&"step", row, -1])
			zone(Rect2(rect.end.x - 54.0, base - 30.0, 60.0, 42.0), [&"step", row, 1])
		&"action":
			var word := RED if row == ProtoSettings.QUIT else GOLD
			var box := Rect2(rect.position.x, base - 30.0, rect.size.x, 42.0)
			plate(box, Color(0.0, 0.0, 0.0, 0.25), Color(word, 0.9 if lit else 0.3 * bright), 3.0, 1.0)
			text(Vector2(rect.position.x, base), model.value(row), GOTHIC_B, 19, word if lit else ink, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
			zone(box, [&"act", row])
