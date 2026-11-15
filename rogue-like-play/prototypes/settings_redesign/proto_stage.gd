class_name ProtoStage
extends ProtoScreen

# B, the list and the stage: every setting in one list down the left, under
# the names of their groups, and on the right a stage that shows what the
# one under the cursor does, moving as it would in play. A volume is rings
# of sound from a bell beside the four levels; the shake is a struck frame
# that shakes as hard as it is set; the screen is a window on a monitor or
# the whole of it; the language is a line of the game in it; the controls
# guide is the fight's foot with or without its keys; the help is its
# topics; the end of the game is what is kept.
# Up and down go through the list, left and right change the one under the
# cursor, Q and E jump from group to group, Enter takes an action.

const PALE := Color(0.95, 0.93, 0.88)
const DIM := Color(0.68, 0.65, 0.60)
const GOLD := Color(1.0, 0.82, 0.46)
const RED := Color(0.92, 0.45, 0.36)
const INK := Color(0.035, 0.035, 0.04)
const LINE := Color(0.85, 0.72, 0.45)
const LIST := Rect2(96.0, 140.0, 640.0, 660.0)
const STAGE := Rect2(816.0, 140.0, 688.0, 430.0)
const ROW := 48.0
const HEAD := 54.0


func _key(action: StringName) -> void:
	match action:
		&"up":
			step(-1)
		&"down":
			step(1)
		&"left":
			change(-1)
		&"right":
			change(1)
		&"prev":
			turn(-1)
		&"next":
			turn(1)
		&"accept":
			accept()


func _wheel(by: int) -> void:
	step(by)


func _paint() -> void:
	hall(0.80)
	shade_across(Rect2(0.0, 0.0, 900.0, VIEW.y), Color(0.0, 0.0, 0.0, 0.55), Color(0.0, 0.0, 0.0, 0.0))
	spaced(Vector2(96.0, 78.0), "設定", MINCHO_B, 34, PALE, 6.0)
	var places := {}
	var y := LIST.position.y
	for group in ProtoSettings.groups():
		var here := ProtoSettings.group_of(focus) == group
		spaced(Vector2(LIST.position.x, y + 30.0), ProtoSettings.group_name(group), MINCHO_B, 19, GOLD if here else DIM, 4.0)
		draw_line(Vector2(LIST.position.x, y + 42.0), Vector2(LIST.end.x, y + 42.0), Color(LINE, 0.6 if here else 0.25), 1.0)
		y += HEAD
		for row in ProtoSettings.rows(group):
			places[row] = y
			y += ROW
		y += 16.0
	# The cursor's bar slides from the row it left.
	var bar := lerpf(places[from], places[focus], moved())
	shade_across(Rect2(LIST.position.x - 24.0, bar, LIST.size.x + 48.0, ROW), Color(LINE, 0.20), Color(LINE, 0.0))
	draw_rect(Rect2(LIST.position.x - 24.0, bar, 3.0, ROW), GOLD)
	for row: int in places:
		_row(row, Rect2(LIST.position.x, places[row], LIST.size.x, ROW))
	_stage()


func _row(row: int, rect: Rect2) -> void:
	var lit := row == focus
	var ink := (PALE if lit else (PALE if hovered(row) else DIM))
	var base := rect.position.y + 31.0
	zone(rect, [&"item", row])
	text(Vector2(rect.position.x, base), ProtoSettings.caption(row), GOTHIC_B if lit else GOTHIC, 19, GOLD if lit else ink)
	var right := rect.end.x
	match ProtoSettings.kind(row):
		&"slider":
			var track := Rect2(rect.position.x + 220.0, rect.get_center().y - 2.0, 300.0, 4.0)
			var level := model.percent(row) / 100.0
			draw_rect(track, Color(1.0, 1.0, 1.0, 0.16))
			draw_rect(Rect2(track.position, Vector2(track.size.x * level, 4.0)), GOLD if lit else Color(LINE, 0.8))
			var knob := Vector2(track.position.x + track.size.x * level, rect.get_center().y)
			if lit:
				glow(knob, 22.0, Color(GOLD, 0.4))
			diamond(knob, 8.0 * (pop() if lit else 1.0), GOLD if lit else LINE)
			text(Vector2(rect.position.x, base), model.value(row), MINCHO_B, 22, ink, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x)
			for mark in 21:
				zone(Rect2(track.position.x + track.size.x * (mark - 0.5) / 20.0, rect.position.y, track.size.x / 20.0, ROW), [&"set", row, mark * 5])
		&"cycle":
			var words := model.value(row)
			var wide := maxf(110.0, width_of(words, GOTHIC_B, 19))
			text(Vector2(right - wide - 30.0, base), words, GOTHIC_B, 19, ink, HORIZONTAL_ALIGNMENT_CENTER, wide)
			text(Vector2(right - wide - 62.0, base), "〈", GOTHIC, 19, GOLD if lit else Color(DIM, 0.6))
			text(Vector2(right - 22.0, base), "〉", GOTHIC, 19, GOLD if lit else Color(DIM, 0.6))
			zone(Rect2(right - wide - 70.0, rect.position.y, 44.0, ROW), [&"step", row, -1])
			zone(Rect2(right - 34.0, rect.position.y, 44.0, ROW), [&"step", row, 1])
		&"action":
			text(Vector2(rect.position.x, base), model.value(row) + "　›", GOTHIC_B, 19, (RED if row == ProtoSettings.QUIT else GOLD) if lit else ink, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x)
			zone(Rect2(right - 160.0, rect.position.y, 160.0, ROW), [&"act", row])


# The stage: what the setting under the cursor does, shown.
func _stage() -> void:
	plate(STAGE, Color(INK, 0.86), Color(LINE, 0.5), 4.0, 1.0)
	draw_rect(STAGE.grow(-7.0), Color(LINE, 0.18), false, 1.0)
	text(STAGE.position + Vector2(22.0, 32.0), "実演", GOTHIC, 14, DIM)
	var centre := STAGE.get_center() + Vector2(0.0, 10.0)
	match focus:
		0, 1, 2, 3:
			_show_sound(centre)
		4:
			_show_shake(centre)
		5:
			_show_screen(centre)
		ProtoSettings.LANGUAGE:
			_show_language(centre)
		6:
			_show_guide(centre)
		ProtoSettings.HELP:
			_show_help()
		_:
			_show_quit(centre)
	var fade := 0.3 + 0.7 * moved()
	var y := STAGE.end.y + 62.0
	text(Vector2(STAGE.position.x, y), ProtoSettings.caption(focus), MINCHO_B, 36, Color(PALE, fade))
	text(Vector2(STAGE.position.x, y), model.value(focus), MINCHO_B, int(36.0 * pop()), Color(GOLD, fade), HORIZONTAL_ALIGNMENT_RIGHT, STAGE.size.x)
	draw_line(Vector2(STAGE.position.x, y + 20.0), Vector2(STAGE.end.x, y + 20.0), Color(LINE, 0.4), 1.0)
	paragraph(Vector2(STAGE.position.x, y + 56.0), ProtoSettings.note(focus), GOTHIC, 19, Color(PALE, 0.92 * fade), STAGE.size.x, 8.0, 3)


# A bell whose rings carry as far as the volume under the cursor (under the
# volume of everything), beside the four levels.
func _show_sound(centre: Vector2) -> void:
	var bell := centre - Vector2(150.0, 0.0)
	var loud := model.percent(focus) / 100.0 * (model.percent(0) / 100.0 if focus != 0 else 1.0)
	for index in 5:
		var out := fmod(clock * 0.6 + index / 5.0, 1.0)
		if loud > 0.0:
			ring(bell, 30.0 + 150.0 * out * loud, Color(GOLD, (1.0 - out) * (0.25 + 0.75 * loud)), 2.0, -PI * 0.42, PI * 0.42)
	draw_circle(bell, 24.0, GOLD if loud > 0.0 else DIM)
	draw_circle(bell, 15.0, INK)
	if loud == 0.0:
		draw_line(bell + Vector2(-34.0, 34.0), bell + Vector2(34.0, -34.0), RED, 4.0, true)
		text(bell + Vector2(-60.0, 70.0), "消音", GOTHIC_B, 18, RED, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	for index in ProtoSettings.SLIDERS.size():
		var row := ProtoSettings.SLIDERS[index]
		var x := centre.x + 90.0 + index * 52.0
		var level := model.percent(row) / 100.0
		draw_rect(Rect2(x, centre.y - 110.0, 22.0, 220.0), Color(1.0, 1.0, 1.0, 0.10))
		draw_rect(Rect2(x, centre.y + 110.0 - 220.0 * level, 22.0, 220.0 * level), GOLD if row == focus else Color(LINE, 0.55))
		text(Vector2(x - 20.0, centre.y + 134.0), ProtoSettings.caption(row).left(2), GOTHIC, 14, GOLD if row == focus else DIM, HORIZONTAL_ALIGNMENT_CENTER, 62.0)


# A frame struck every second or so, shaking as hard as the shake is set.
func _show_shake(centre: Vector2) -> void:
	var beat := fmod(clock, 1.3)
	var force := GameSettings.SHAKE_SCALES[model.chosen(4)] * maxf(0.0, 1.0 - beat / 0.35)
	var shift := Vector2(sin(clock * 71.0), cos(clock * 53.0)) * 16.0 * force
	var frame := Rect2(centre - Vector2(210.0, 120.0) + shift, Vector2(420.0, 240.0))
	draw_rect(frame, Color(0.10, 0.11, 0.14))
	draw_rect(frame, Color(LINE, 0.7), false, 2.0)
	draw_rect(Rect2(frame.position.x, frame.end.y - 60.0, frame.size.x, 60.0), Color(0.16, 0.15, 0.14))
	var hero := frame.position + Vector2(150.0, 158.0)
	draw_circle(hero, 18.0, PALE)
	draw_rect(Rect2(hero + Vector2(-12.0, 16.0), Vector2(24.0, 34.0)), PALE)
	var foe := frame.position + Vector2(290.0, 150.0)
	draw_rect(Rect2(foe - Vector2(26.0, 26.0), Vector2(52.0, 62.0)), Color(0.55, 0.25, 0.22))
	if beat < 0.22:
		var cut := 1.0 - beat / 0.22
		draw_arc(hero + Vector2(40.0, 6.0), 86.0, -0.9, 0.7, 20, Color(1.0, 0.95, 0.8, cut), 6.0, true)
		draw_circle(foe, 40.0 * (1.0 - cut) + 12.0, Color(1.0, 0.85, 0.5, 0.6 * cut))


# A monitor: a window on it, or the whole of it.
func _show_screen(centre: Vector2) -> void:
	var monitor := Rect2(centre - Vector2(200.0, 130.0), Vector2(400.0, 230.0))
	draw_rect(monitor.grow(8.0), Color(0.16, 0.16, 0.18))
	draw_rect(monitor, Color(0.05, 0.07, 0.11))
	draw_rect(Rect2(centre.x - 30.0, monitor.end.y + 8.0, 60.0, 26.0), Color(0.16, 0.16, 0.18))
	draw_rect(Rect2(centre.x - 80.0, monitor.end.y + 34.0, 160.0, 8.0), Color(0.16, 0.16, 0.18))
	var full := model.chosen(5) == 1
	var grow := eased(&"change", CHANGE_TIME) if focus == 5 else 1.0
	var small := Rect2(monitor.position + Vector2(70.0, 44.0), Vector2(260.0, 150.0))
	var a := monitor if not full else small
	var b := small if not full else monitor
	var game := Rect2(a.position.lerp(b.position, grow), a.size.lerp(b.size, grow))
	picture(game, HALL, Color(0.8, 0.8, 0.8))
	if not full:
		draw_rect(Rect2(game.position - Vector2(0.0, 16.0), Vector2(game.size.x, 16.0)), Color(0.85, 0.85, 0.87))
		draw_circle(game.position + Vector2(game.size.x - 12.0, -8.0), 4.0, RED)
	draw_rect(game, Color(GOLD, 0.8), false, 2.0)


# A line of the game in the language chosen.
func _show_language(centre: Vector2) -> void:
	var japanese := model.chosen(ProtoSettings.LANGUAGE) == 0
	var names := model.choices(ProtoSettings.LANGUAGE)
	for index in names.size():
		var on := index == model.chosen(ProtoSettings.LANGUAGE)
		text(Vector2(centre.x - 200.0 + index * 200.0, centre.y - 96.0), names[index], MINCHO_B, 26, GOLD if on else Color(DIM, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		if on:
			draw_line(Vector2(centre.x - 160.0 + index * 200.0, centre.y - 82.0), Vector2(centre.x - 40.0 + index * 200.0, centre.y - 82.0), GOLD, 2.0)
	text(Vector2(STAGE.position.x, centre.y), "第1章　灰の回廊" if japanese else "Chapter 1: The Ash Corridor", MINCHO_B, 38, PALE, HORIZONTAL_ALIGNMENT_CENTER, STAGE.size.x)
	text(Vector2(STAGE.position.x, centre.y + 50.0), "灰に沈んだ回廊を抜け、その奥の守護者の間に待つ者を討つ。" if japanese else "Cross the ash-choked corridor and slay what waits beyond.", GOTHIC, 18, DIM, HORIZONTAL_ALIGNMENT_CENTER, STAGE.size.x)


# The fight's foot, with its line of keys or without.
func _show_guide(centre: Vector2) -> void:
	var frame := Rect2(centre - Vector2(230.0, 130.0), Vector2(460.0, 250.0))
	draw_rect(frame, Color(0.10, 0.11, 0.14))
	draw_rect(frame, Color(LINE, 0.6), false, 1.5)
	draw_circle(frame.get_center() - Vector2(0.0, 20.0), 16.0, PALE)
	draw_rect(Rect2(frame.position + Vector2(18.0, 16.0), Vector2(150.0, 12.0)), Color(0.75, 0.2, 0.18))
	var shown := model.chosen(6) == 0
	var y := frame.end.y - 34.0
	if shown:
		var x := frame.position.x + 22.0
		for pair: Array in [["WASD", "移動"], ["左クリック", "攻撃"], ["Space", "回避"], ["Q / E", "スキル"]]:
			var wide := width_of(pair[0], GOTHIC_B, 12) + 12.0
			plate(Rect2(x, y, wide, 20.0), Color(0.2, 0.2, 0.22), Color(1.0, 1.0, 1.0, 0.4), 3.0)
			text(Vector2(x + 6.0, y + 15.0), pair[0], GOTHIC_B, 12, PALE)
			text(Vector2(x + wide + 6.0, y + 15.0), pair[1], GOTHIC, 12, DIM)
			x += wide + width_of(pair[1], GOTHIC, 12) + 22.0
		draw_rect(Rect2(frame.position.x + 12.0, y - 8.0, frame.size.x - 24.0, 36.0), Color(GOLD, 0.8), false, 1.5)
	else:
		draw_dashed_line(Vector2(frame.position.x + 12.0, y + 10.0), Vector2(frame.end.x - 12.0, y + 10.0), Color(DIM, 0.6), 1.5, 8.0)


# The help's topics.
func _show_help() -> void:
	var y := STAGE.position.y + 86.0
	for index in HubSettings.HELP.size():
		var at := Vector2(STAGE.position.x + 80.0 + (index % 2) * 290.0, y + (index / 2) * 92.0)
		diamond(at + Vector2(0.0, -8.0), 6.0, GOLD)
		text(at + Vector2(22.0, 0.0), tr(HubSettings.HELP[index][0]), MINCHO_B, 24, PALE)
		text(at + Vector2(22.0, 28.0), "%d項目" % (HubSettings.HELP[index][1] as Array).size(), GOTHIC, 14, DIM)
	if since(&"act") < 1.2:
		text(Vector2(STAGE.position.x, STAGE.end.y - 28.0), "（ヘルプの窓が開く）", GOTHIC, 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER, STAGE.size.x)


# Ending the game: what is kept, and that it asks first.
func _show_quit(centre: Vector2) -> void:
	var door := Rect2(centre - Vector2(46.0, 120.0), Vector2(92.0, 150.0))
	draw_rect(door, Color(0.03, 0.03, 0.035))
	draw_rect(door, Color(RED, 0.8), false, 2.0)
	draw_circle(door.position + Vector2(74.0, 80.0), 5.0, RED)
	text(Vector2(STAGE.position.x, centre.y + 80.0), tr(HubSettings.QUIT_BODY), GOTHIC, 19, PALE, HORIZONTAL_ALIGNMENT_CENTER, STAGE.size.x)
	text(Vector2(STAGE.position.x, centre.y + 114.0), "確認の窓を出してから終了します。" if since(&"act") > 1.2 else "（確認の窓が開く）", GOTHIC, 16, DIM if since(&"act") > 1.2 else GOLD, HORIZONTAL_ALIGNMENT_CENTER, STAGE.size.x)
