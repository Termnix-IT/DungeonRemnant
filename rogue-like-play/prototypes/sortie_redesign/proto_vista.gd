class_name ProtoVista
extends ProtoScreen

# B, the vista: the chosen chapter's painting is the whole screen, as if she
# stood at its gate. Turning to another chapter fades one place into the
# next. The name stands large at the lower left over a dark fall; a row of
# small views along the top tells where in the four she is; along the foot
# run the way, the record and the boss, the foes and what she carries, and
# at the right the step and the one action.
# Left and right turn from chapter to chapter, Q and E change the step,
# Enter sets out.

const PALE := Color(0.96, 0.94, 0.89)
const DIM := Color(0.74, 0.71, 0.66)
const GOLD := Color(1.0, 0.82, 0.45)
const WARN := Color(0.95, 0.52, 0.42)
const NIGHT := Color(0.02, 0.02, 0.025)
const THUMB := Vector2(168.0, 84.0)
const THUMB_GAP := 14.0
const PAL := {
	dim = DIM, value = PALE, accent = GOLD, warn = WARN, under = Color(1.0, 1.0, 1.0, 0.17), rule = Color(1.0, 1.0, 1.0, 0.25),
	ground = Color(0.05, 0.05, 0.055), go = Color(0.50, 0.33, 0.10), go_edge = GOLD, go_text = Color(1.0, 0.95, 0.82),
	off = Color(0.10, 0.10, 0.11, 0.9), off_text = Color(0.58, 0.55, 0.52),
}


func _key(action: StringName) -> void:
	match action:
		&"left":
			choose(chosen - 1)
		&"right":
			choose(chosen + 1)
		_:
			common_key(action)


func _wheel(step: int) -> void:
	choose(chosen + step)


# A chapter's painting over the whole view, slowly drifting.
func _place(index: int, share: float, closer: float) -> void:
	var open := model.open(index)
	var bright := 0.92 if open else 0.20
	var drift := Vector2(0.5 + 0.06 * sin(clock * 0.11 + index), 0.5 + 0.05 * cos(clock * 0.09))
	picture(Rect2(Vector2.ZERO, VIEW), model.chapter(index).illustration, Color(bright, bright, bright, share), drift, 1.05 + closer)


func _paint() -> void:
	var share := moved()
	var leaving := 1.0 - departing() if model.departed == chosen else 0.0
	draw_rect(Rect2(Vector2.ZERO, VIEW), NIGHT)
	if from != chosen and share < 1.0:
		_place(from, 1.0, 0.0)
	_place(chosen, share if from != chosen else 1.0, 0.10 * (1.0 - leaving) if model.departed == chosen else 0.0)
	shade(Rect2(0.0, 380.0, VIEW.x, 520.0), Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.94))
	shade_across(Rect2(0.0, 0.0, 820.0, VIEW.y), Color(0.0, 0.0, 0.0, 0.55), Color(0.0, 0.0, 0.0, 0.0))
	shade(Rect2(0.0, 0.0, VIEW.x, 150.0), Color(0.0, 0.0, 0.0, 0.7), Color(0.0, 0.0, 0.0, 0.0))
	spaced(Vector2(64.0, 62.0), "出撃", MINCHO_B, 34, PALE, 6.0)
	_views()
	_turns()
	_name(share)
	_foot(share)
	if leaving > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(1.0, 0.96, 0.86, 0.6 * leaving * leaving))


# The four places as small views along the top.
func _views() -> void:
	var total := model.count() * THUMB.x + (model.count() - 1) * THUMB_GAP
	var x := (VIEW.x - total) * 0.5
	for index in model.count():
		var rect := Rect2(Vector2(x + index * (THUMB.x + THUMB_GAP), 30.0), THUMB)
		var open := model.open(index)
		var here := index == chosen
		var bright := (1.0 if here else (0.75 if hovered(&"chapter", index) else 0.5)) * (1.0 if open else 0.35)
		picture(rect, model.chapter(index).illustration, Color(bright, bright, bright), focus_of(index))
		draw_rect(rect, Color(GOLD, 1.0) if here else Color(1.0, 1.0, 1.0, 0.3), false, 2.0 if here else 1.0)
		if here:
			draw_rect(rect.grow(4.0), Color(GOLD, 0.35), false, 1.0)
			diamond(Vector2(rect.get_center().x, rect.end.y + 12.0), 5.0, GOLD)
		if not open:
			emblem(rect.get_center(), 20.0, "seal_chapter")
		elif model.cleared(index):
			diamond(rect.position + Vector2(14.0, 14.0), 6.0, GOLD)
		text(Vector2(rect.position.x, rect.end.y + 34.0), Chapters.short_name(model.chapter(index)), GOTHIC, 14, GOLD if here else DIM, HORIZONTAL_ALIGNMENT_CENTER, THUMB.x)
		zone(rect.grow_individual(0.0, 0.0, 0.0, 40.0), [&"chapter", index])


# The arrows at the screen's sides.
func _turns() -> void:
	for side: int in [-1, 1]:
		var to := chosen + side
		var there := to >= 0 and to < model.count()
		var rect := Rect2(Vector2(22.0 if side < 0 else VIEW.x - 78.0, 400.0), Vector2(56.0, 80.0))
		var lit := hovered(&"chapter", to) and (hover as Array).size() > 2
		text(rect.position + Vector2(8.0, 56.0), "◀" if side < 0 else "▶", GOTHIC, 40, Color(PALE, (0.95 if lit else 0.6) if there else 0.15))
		if there:
			zone(rect, [&"chapter", to, &"turn"])


# The chosen chapter's name, how far it has been taken and what it is.
func _name(share: float) -> void:
	var chapter := model.chapter(chosen)
	var open := model.open(chosen)
	var rise := 14.0 * (1.0 - share)
	var x := 96.0
	if not open:
		emblem(Vector2(VIEW.x * 0.5, 330.0), 78.0, "seal_chapter", Color(1.0, 1.0, 1.0, share))
	text(Vector2(x + 2.0, 508.0 + rise), Chapters.short_name(chapter), GOTHIC_B, 20, Color(GOLD, share))
	text(Vector2(x - 4.0, 590.0 + rise), Chapters.title(chapter), MINCHO_B, 78, Color(PALE if open else DIM, share))
	var state_colour := WARN if not open else (GOLD if model.cleared(chosen) else PALE)
	diamond(Vector2(x + 8.0, 624.0 + rise), 6.0, Color(state_colour, share))
	text(Vector2(x + 26.0, 632.0 + rise), model.state(chosen), MINCHO_M, 24, Color(state_colour, share))
	paragraph(Vector2(x, 672.0 + rise), model.description(chosen), GOTHIC, 19, Color(PALE, 0.92 * share), 760.0, 6.0, 2)


# The foot: the facts, the foes and what she carries, then the step and the action.
func _foot(share: float) -> void:
	var y := 762.0
	draw_line(Vector2(96.0, y - 22.0), Vector2(1504.0, y - 22.0), PAL.rule, 1.0)
	var x := 96.0
	for fact: Array in [[tr("道のり"), model.route(chosen)], [tr("記録"), model.record(chosen)], [tr("ボス"), model.boss_name(chosen)]]:
		text(Vector2(x, y), fact[0], GOTHIC, 14, DIM)
		text(Vector2(x, y + 36.0), fact[1], MINCHO_B, 24, Color(PALE, 0.4 + 0.6 * share))
		x += maxf(150.0, width_of(fact[1], MINCHO_B, 24) + 44.0)
	x = maxf(x + 10.0, 600.0)
	text(Vector2(x, y), tr("現れる敵"), GOTHIC, 14, DIM)
	foe_tiles(Vector2(x, y + 10.0), 480.0, 46.0, PAL)
	text(Vector2(1110.0, y), tr("装備", "gear"), GOTHIC, 14, DIM)
	gear_tiles(Vector2(1110.0, y + 10.0), 46.0)
	# The step and the action, over the foot's right end.
	var column := Rect2(1100.0, 520.0, 404.0, 190.0)
	if model.steps_open() > 0:
		plate(column.grow_individual(20.0, 6.0, 20.0, -8.0), Color(0.0, 0.0, 0.0, 0.62), Color(1.0, 1.0, 1.0, 0.12), 4.0)
	var held := step_block(Vector2(column.position.x, column.position.y + 8.0), column.size.x, PAL)
	if held == 0.0:
		go_button(Rect2(column.position.x, column.end.y - 70.0, column.size.x, 70.0), PAL)
	else:
		go_button(Rect2(column.position.x, column.position.y + 8.0 + held + 14.0, column.size.x, 70.0), PAL)
