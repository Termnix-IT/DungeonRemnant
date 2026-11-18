class_name ProtoBoard
extends ProtoScreen

# Prototype C, the war table: the ways open now laid side by side as
# dossiers, every row of one level with the same row of the next (danger,
# time, reward, echo, goal, foes, the ways on), so they are compared across
# without pointing at anything; the longest time and the richest echo set
# the measure their bars are drawn to. The chapter's whole route stands at
# the left as a march plan, the boss at its head and the start at its foot,
# each area a piece marked with its kind, danger and reward; the ways the
# cursor's pick would close go dark on it, and a piece pointed at is told of
# beside it. Under the table her state is read against the pick: what the
# echo would come to, and a word where her health and the pick's danger or
# reward meet. Enter asks (a seal is struck on the dossier), Enter again goes.

const TABLE := Color(0.035, 0.042, 0.06)
const PANEL := Color(0.06, 0.07, 0.1)
const RAISED := Color(0.095, 0.105, 0.14)
const PALE := Color("e6e9f2")
const DIM := Color("98a0b4")
const FAINT := Color("5d6579")
const LINE := Color("2a3040")
const BRASS := Color("c9a45c")
const GOLD := Color("ffd88a")
const RED := Color("e2574c")
const BLUE := Color("86c2ff")
const VIOLET := Color("b9a0ff")
const PLAN := Rect2(48.0, 104.0, 404.0, 606.0)
const SHEETS := Rect2(572.0, 104.0, 988.0, 606.0)
const LABELS := 484.0
const STATE := Rect2(48.0, 726.0, 1512.0, 112.0)
# The rows of a dossier: [label, top, height].
const ROWS := [["脅威", 150.0, 44.0], ["目安", 194.0, 44.0], ["報酬", 238.0, 52.0], ["残響", 290.0, 44.0], ["目的", 334.0, 56.0], ["敵", 390.0, 96.0], ["その先", 486.0, 54.0]]
const FOOT := 540.0

# The piece on the plan the pointer reads.
var _marker := Vector2.ZERO


func go_time() -> float:
	return 0.85


func tint_of(told: Dictionary) -> Color:
	if told.boss:
		return RED
	return {AreaData.Reward.BOON: GOLD, AreaData.Reward.HEAL: RED, AreaData.Reward.ECHO: BLUE}.get(told.reward, VIOLET)


func _laid() -> void:
	_marker = plan_spot(model.here())


# --- Input ---

func _key(action: StringName) -> void:
	match action:
		&"left":
			choose(maxi(0, model.cursor - 1))
		&"right":
			choose(mini(model.open.size() - 1, model.cursor + 1))
		_:
			super(action)


func _point(id: Variant) -> void:
	peek = null
	if not id is Array:
		return
	match id[0]:
		&"open":
			if id[1] != model.cursor and not model.armed:
				choose(id[1])
		&"node":
			var point: RouteMap.Waypoint = id[1]
			if model.open.has(point):
				if not model.armed:
					choose(model.open.find(point))
			else:
				peek = point


func _click(id: Variant) -> void:
	var what: Array = id
	if what[0] == &"node":
		if model.open.has(what[1]):
			common_click([&"open", model.open.find(what[1])])
	else:
		common_click(id)


func _pose_detail() -> void:
	peek = model.route.nodes(model.route.size() - 2)[0]


# --- Painting ---

func _paint() -> void:
	_table()
	_plan()
	_sheets()
	_state()
	_keys()
	if peek != null:
		_slip(peek)


func _table() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), TABLE)
	# The chapter's painting, all but lost in the table's dark.
	picture(Rect2(Vector2.ZERO, VIEW), model.chapter.illustration, Color(0.11, 0.12, 0.15, 1.0))
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(TABLE, 0.55))
	glow(Vector2(1000.0, 300.0), 900.0, Color(0.5, 0.42, 0.28, 0.07))
	# The table's engraved field: fine rings round the march plan's head.
	for index in 7:
		ring(Vector2(250.0, 160.0), 120.0 + index * 90.0, Color(1.0, 1.0, 1.0, 0.018), 1.0)
	text(Vector2(52.0, 66.0), Chapters.title(model.chapter), MINCHO_B, 32, PALE)
	var after := 52.0 + width_of(Chapters.title(model.chapter), MINCHO_B, 32) + 22.0
	text(Vector2(after, 50.0), Chapters.short_name(model.chapter), GOTHIC, 13, DIM)
	text(Vector2(after, 68.0), "%s　／　%s" % [layer_words(), span_words()], GOTHIC, 13, DIM)
	if not model.note.is_empty():
		text(Vector2(480.0, 62.0), model.note, MINCHO_M, 16, Color(GOLD, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 760.0)
	spaced(Vector2(1470.0, 62.0), "作戦盤", GOTHIC_B, 13, BRASS, 6.0)
	HubUI.trail(self, Vector2(1456.0, 57.0), Vector2(1300.0, 57.0), Color(BRASS, 0.6))


# --- The march plan ---

# Where a piece stands on the plan: the boss at its head, the start at its foot.
func plan_spot(point: RouteMap.Waypoint) -> Vector2:
	var route := model.route
	var top := PLAN.position.y + 76.0
	var foot := PLAN.end.y - 56.0
	var gap := (foot - top) / route.size()
	var middle := PLAN.position.x + PLAN.size.x * 0.5 + 24.0
	if point == null:
		return Vector2(middle, foot)
	var row := route.nodes(point.layer).find(point)
	return Vector2(middle + (row - (route.nodes(point.layer).size() - 1) * 0.5) * 104.0, foot - gap * (point.layer + 1))


func _plan() -> void:
	var route := model.route
	plate(PLAN, PANEL, LINE, 4.0)
	spaced(Vector2(PLAN.position.x + 20.0, PLAN.position.y + 30.0), "行軍図", GOTHIC_B, 13, BRASS, 5.0)
	HubUI.trail(self, Vector2(PLAN.position.x + 92.0, PLAN.position.y + 25.0), Vector2(PLAN.end.x - 20.0, PLAN.position.y + 25.0), Color(BRASS, 0.5))
	var chosen := model.selected()
	var kept := model.reach_from([chosen]) if chosen != null else {}
	var walked := model.run.taken
	var tint := tint_of(model.tell(chosen)) if chosen != null else PALE
	# The layers' names down the side.
	for index in route.size():
		var y := plan_spot(route.nodes(index)[0]).y
		var named := "ボス" if index == route.size() - 1 else "第%d層" % (index + 1)
		var now := index == model.run.layer
		text(Vector2(PLAN.position.x + 18.0, y + 5.0), named, GOTHIC_B if now else GOTHIC, 12, PALE if now else FAINT)
		draw_line(Vector2(PLAN.position.x + 64.0, y), Vector2(PLAN.end.x - 16.0, y), Color(1.0, 1.0, 1.0, 0.05 if now else 0.025), 1.0)
	text(Vector2(PLAN.position.x + 18.0, plan_spot(null).y + 5.0), "出発", GOTHIC, 12, FAINT)
	# The ways.
	for point: RouteMap.Waypoint in route.nodes(0):
		_march(null, point, walked, kept, tint)
	for index in route.size() - 1:
		for from: RouteMap.Waypoint in route.nodes(index):
			for to: RouteMap.Waypoint in from.next:
				_march(from, to, walked, kept, tint)
	# The pieces.
	diamond(plan_spot(null), 7.0, GOLD if not walked.is_empty() else PALE)
	for index in route.size():
		for point: RouteMap.Waypoint in route.nodes(index):
			_piece(point, kept, tint)
	# Her own piece: beside where she stands, sliding to the pick as it is gone to.
	var stand := plan_spot(model.here())
	if going and chosen != null:
		stand = stand.lerp(plan_spot(chosen), smoothstep(0.0, 0.7, since(&"go") / go_time()))
	_marker = stand
	var flag := stand + Vector2(-34.0, 0.0)
	draw_colored_polygon(PackedVector2Array([flag + Vector2(0.0, -9.0), flag + Vector2(10.0, 0.0), flag + Vector2(0.0, 9.0)]), PALE)
	draw_line(flag + Vector2(-10.0, 0.0), flag, PALE, 2.0)
	# The key to the pieces.
	var x := PLAN.position.x + 20.0
	var y := PLAN.end.y - 16.0
	for entry: Array in [[AreaData.Kind.FIELD, "フィールド"], [AreaData.Kind.ARENA, "アリーナ"], [AreaData.Kind.EVENT, "イベント"], [AreaData.Kind.BOSS, "ボス"]]:
		_kind_mark(Vector2(x + 6.0, y - 5.0), 5.5, entry[0], DIM)
		text(Vector2(x + 18.0, y), entry[1], GOTHIC, 12, FAINT)
		x += 30.0 + width_of(entry[1], GOTHIC, 12)


func _march(from: RouteMap.Waypoint, to: RouteMap.Waypoint, walked: Array, kept: Dictionary, tint: Color) -> void:
	var a := plan_spot(from)
	var b := plan_spot(to)
	var heading := (b - a).normalized()
	a += heading * (10.0 if from == null else 22.0)
	b -= heading * (30.0 if to.area.boss != null else 22.0)
	var at := walked.find(to)
	if at >= 0 and (from == null and at == 0 or at > 0 and walked[at - 1] == from):
		draw_line(a, b, GOLD, 3.0, true)
	elif from == model.here() and model.open.has(to):
		var mine := to == model.selected()
		draw_line(a, b, tint if mine else Color(PALE, 0.55 - 0.4 * arming()), 3.0 if mine else 1.5, true)
	elif from != null and model.reach.has(from) and from.layer >= model.run.layer:
		draw_line(a, b, Color(tint, 0.6) if kept.has(from) else Color(PALE, 0.09), 1.5, true)
	else:
		draw_line(a, b, Color(PALE, 0.06), 1.0, true)


func _piece(point: RouteMap.Waypoint, kept: Dictionary, tint: Color) -> void:
	var at := plan_spot(point)
	var told := model.tell(point)
	var state: ProtoRoute.Mark = told.mark
	var boss: bool = told.boss
	var radius := 28.0 if boss else 20.0
	zone(Rect2(at - Vector2.ONE * (radius + 6.0), Vector2.ONE * (radius + 6.0) * 2.0), [&"node", point])
	var mine := point == model.selected()
	var alpha := 1.0
	match state:
		ProtoRoute.Mark.AHEAD:
			alpha = 0.85 if kept.has(point) else 0.22
		ProtoRoute.Mark.SHUT, ProtoRoute.Mark.PASSED:
			alpha = 0.2
		ProtoRoute.Mark.OPEN:
			alpha = 1.0 if mine else 1.0 - 0.6 * arming()
	var own := tint_of(told)
	if mine:
		glow(at, radius * 2.6, Color(tint, 0.3 + 0.1 * breath()))
	draw_circle(at, radius, RAISED if state == ProtoRoute.Mark.OPEN else PANEL)
	var edge := Color(FAINT, alpha)
	if state == ProtoRoute.Mark.TAKEN:
		edge = GOLD
	elif state == ProtoRoute.Mark.OPEN:
		edge = tint if mine else Color(PALE, alpha)
	elif boss:
		edge = Color(RED, 0.5 + 0.3 * breath(1.6))
	ring(at, radius, edge, 2.5 if mine or state == ProtoRoute.Mark.TAKEN else 1.5)
	if mine:
		ring(at, radius + 5.0, Color(tint, 0.7), 1.0)
	if told.veiled:
		text(Vector2(at.x - 14.0, at.y + 9.0), "？", MINCHO_B, 24, Color(RED, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 28.0)
		return
	_kind_mark(at, radius * 0.42, point.area.kind, Color(GOLD if state == ProtoRoute.Mark.TAKEN else PALE, alpha))
	if state == ProtoRoute.Mark.TAKEN:
		return
	# Its danger over it, what it gives at its shoulder.
	for index in told.danger:
		draw_rect(Rect2(at.x - told.danger * 4.5 + index * 9.0 + 1.0, at.y - radius - 9.0, 7.0, 4.0), Color(RED, alpha))
	if told.reward >= 0 or told.event:
		var badge := at + Vector2(radius * 0.8, radius * 0.72)
		draw_circle(badge, 8.5, PANEL)
		sign_of(badge, 5.5, told.reward, Color(own, maxf(alpha, 0.35)))
	if state == ProtoRoute.Mark.OPEN:
		var key := at + Vector2(-radius * 0.86, -radius * 0.86)
		draw_circle(key, 9.0, tint if mine else PALE)
		text(Vector2(key.x - 9.0, key.y + 5.0), NUMERALS[model.open.find(point)], GOTHIC_B, 13, TABLE, HORIZONTAL_ALIGNMENT_CENTER, 18.0)
	if peek == point:
		ring(at, radius + 9.0, PALE, 1.0)


# An area's kind as a mark: a field's crowd, an arena's ring of walls, an
# event's lozenge, the boss's crown.
func _kind_mark(at: Vector2, size: float, kind: int, colour: Color) -> void:
	match kind:
		AreaData.Kind.FIELD:
			for index in 3:
				draw_circle(at + Vector2.from_angle(TAU * index / 3.0 - PI * 0.5) * size * 0.72, size * 0.36, colour)
		AreaData.Kind.ARENA:
			draw_rect(Rect2(at - Vector2.ONE * size * 0.82, Vector2.ONE * size * 1.64), colour, false, maxf(1.5, size * 0.28))
		AreaData.Kind.EVENT:
			ring_of(at, size, colour, 4, maxf(1.5, size * 0.26), PI * 0.5)
		_:
			draw_colored_polygon(PackedVector2Array([at + Vector2(-size, size * 0.7), at + Vector2(-size, -size * 0.5), at + Vector2(-size * 0.45, 0.0), at + Vector2(0.0, -size * 0.9), at + Vector2(size * 0.45, 0.0), at + Vector2(size, -size * 0.5), at + Vector2(size, size * 0.7)]), colour)


# A piece pointed at, told of beside it.
func _slip(point: RouteMap.Waypoint) -> void:
	var told := model.tell(point)
	var at := plan_spot(point)
	var rect := Rect2(at.x + 40.0, clampf(at.y - 70.0, PLAN.position.y + 8.0, PLAN.end.y - 168.0), 330.0, 160.0)
	plate(Rect2(rect.position + Vector2(4.0, 6.0), rect.size), Color(0.0, 0.0, 0.0, 0.5), Color.TRANSPARENT, 4.0)
	plate(rect, Color(0.085, 0.095, 0.13), Color(BRASS, 0.7), 4.0)
	draw_line(at + Vector2(30.0, 0.0), Vector2(rect.position.x, at.y), Color(BRASS, 0.7), 1.0)
	var left := rect.position.x + 18.0
	var wide := rect.size.x - 36.0
	text(Vector2(left, rect.position.y + 28.0), told.kind, GOTHIC, 13, DIM)
	text(Vector2(left, rect.position.y + 28.0), told.state, GOTHIC_B, 13, BRASS, HORIZONTAL_ALIGNMENT_RIGHT, wide)
	text(Vector2(left, rect.position.y + 62.0), told.name, MINCHO_B, 24, PALE)
	draw_line(Vector2(left, rect.position.y + 76.0), Vector2(left + wide, rect.position.y + 76.0), LINE, 1.0)
	if told.veiled:
		paragraph(Vector2(left, rect.position.y + 102.0), told.goal, GOTHIC, 14, DIM, wide)
		return
	var own := tint_of(told)
	if told.event:
		paragraph(Vector2(left, rect.position.y + 102.0), told.reward_words, GOTHIC_B, 15, own, wide)
		return
	for index in 3:
		draw_rect(Rect2(left + index * 16.0, rect.position.y + 92.0, 12.0, 6.0), RED if index < told.danger else LINE)
	text(Vector2(left + 60.0, rect.position.y + 101.0), told.time, GOTHIC, 13, DIM)
	if told.reward >= 0:
		var words: String = "残響 %s" % UIFormat.amount(told.echo) if told.reward == AreaData.Reward.ECHO else "%s　＋残響 %s" % [told.reward_words, UIFormat.amount(told.echo)]
		text(Vector2(left, rect.position.y + 101.0), words, GOTHIC_B, 14, own, HORIZONTAL_ALIGNMENT_RIGHT, wide)
	paragraph(Vector2(left, rect.position.y + 128.0), told.goal, GOTHIC, 14, PALE, wide, 4.0, 1)
	text(Vector2(left, rect.position.y + 148.0), told.summary, GOTHIC, 12, DIM, HORIZONTAL_ALIGNMENT_LEFT, wide)


# --- The dossiers ---

func sheet_rect(index: int) -> Rect2:
	var count := model.open.size()
	var gap := 16.0
	var wide := minf(440.0, (SHEETS.size.x - gap * (count - 1)) / count)
	return Rect2(SHEETS.position.x + index * (wide + gap), SHEETS.position.y, wide, SHEETS.size.y)


func _sheets() -> void:
	var count := model.open.size()
	if count == 0:
		return
	# The rows' names, and the lines every dossier shares.
	var top := SHEETS.position.y
	var right := sheet_rect(count - 1).end.x
	for row: Array in ROWS:
		text(Vector2(LABELS, top + row[1] + row[2] * 0.5 + 5.0), row[0], GOTHIC_B, 13, BRASS, HORIZONTAL_ALIGNMENT_RIGHT, 72.0)
	# What the bars are measured against.
	var longest := 1
	var richest := 1
	for point: RouteMap.Waypoint in model.open:
		if not point.area.is_event():
			longest = maxi(longest, point.area.expected_time)
			richest = maxi(richest, model.echo_of(point))
	for index in count:
		_sheet(index, longest, richest)
	for row: Array in ROWS:
		draw_line(Vector2(LABELS + 6.0, top + row[1]), Vector2(right, top + row[1]), Color(1.0, 1.0, 1.0, 0.07), 1.0)


func _sheet(index: int, longest: int, richest: int) -> void:
	var point: RouteMap.Waypoint = model.open[index]
	var told := model.tell(point)
	var own := tint_of(told)
	var mine := index == model.cursor
	var rise := eased(&"open", OPEN_TIME + index * 0.1)
	var lit := (1.0 if mine else 0.0)
	var dim := (1.0 if mine else 1.0 - 0.62 * arming()) * rise
	var rect := sheet_rect(index)
	rect.position.y += (1.0 - rise) * 18.0
	zone(rect, [&"open", index])
	if mine:
		glow(Vector2(rect.get_center().x, rect.position.y + 40.0), rect.size.x * 0.8, Color(own, 0.16), 0.5)
	plate(rect, Color(RAISED if mine else PANEL, rise), Color(own if mine else LINE, rise), 5.0, 2.0 if mine else 1.0)
	# Its head: a little stage in its own light, where what leads it stands.
	shade(Rect2(rect.position.x + 2.0, rect.position.y + 2.0, rect.size.x - 4.0, 146.0), Color(own, (0.2 if mine else 0.08) * dim), Color(own, 0.0))
	glow(Vector2(rect.position.x + 70.0, rect.position.y + 138.0), 84.0, Color(own, (0.34 if mine else 0.14) * dim), 0.3)
	if mine:
		draw_rect(Rect2(rect.position.x + 2.0, rect.position.y + 2.0, rect.size.x - 4.0, 4.0), own)
	var left := rect.position.x + 20.0
	var wide := rect.size.x - 40.0
	var top := rect.position.y
	# Its head: its key, what leads it, its name and kind.
	var art := figure_of(point)
	fit(Rect2(left - 4.0, top + 34.0, 108.0, 104.0), art, Color(1.0, 1.0, 1.0, dim), true)
	draw_line(Vector2(left - 6.0, top + 139.0), Vector2(left + 106.0, top + 139.0), Color(own, 0.5 * dim), 1.0)
	var key := Vector2(rect.end.x - 30.0, top + 34.0)
	draw_circle(key, 15.0, Color(own if mine else PANEL, dim))
	ring(key, 15.0, Color(own, dim), 1.5)
	text(Vector2(key.x - 15.0, key.y + 7.0), NUMERALS[index], MINCHO_B, 19, Color(TABLE if mine else own, dim), HORIZONTAL_ALIGNMENT_CENTER, 30.0)
	_kind_mark(Vector2(left + 126.0, top + 60.0), 6.0, point.area.kind, Color(DIM, dim))
	text(Vector2(left + 140.0, top + 65.0), told.kind, GOTHIC, 13, Color(DIM, dim))
	paragraph(Vector2(left + 118.0, top + 100.0), told.name, MINCHO_B, 25, Color(PALE, dim), wide - 118.0, 0.0, 2)
	# Its rows.
	var y: float = top + ROWS[0][1] + 27.0
	if told.event:
		text(Vector2(left, y), "戦闘なし", GOTHIC_B, 15, Color(VIOLET, dim))
	else:
		for pip in 3:
			draw_rect(Rect2(left + pip * 30.0, y - 12.0, 26.0, 9.0), Color(RED, dim) if pip < told.danger else Color(LINE, dim))
		text(Vector2(left, y), ["", "低い", "並", "高い"][told.danger], GOTHIC_B, 14, Color(RED if told.danger >= 3 else PALE, dim), HORIZONTAL_ALIGNMENT_RIGHT, wide)
	y = top + ROWS[1][1] + 27.0
	if told.event:
		text(Vector2(left, y), "—", GOTHIC, 15, Color(FAINT, dim))
	else:
		var time := point.area.expected_time
		draw_rect(Rect2(left, y - 10.0, (wide - 96.0) * time / longest, 5.0), Color(PALE, 0.75 * dim))
		draw_rect(Rect2(left, y - 10.0, wide - 96.0, 5.0), Color(LINE, dim), false, 1.0)
		text(Vector2(left, y), told.time, GOTHIC_B, 14, Color(PALE, dim), HORIZONTAL_ALIGNMENT_RIGHT, wide)
	y = top + ROWS[2][1] + 33.0
	if told.boss:
		text(Vector2(left, y), "この章の踏破", MINCHO_B, 22, Color(own, dim))
	elif told.event:
		sign_of(Vector2(left + 10.0, y - 8.0), 9.0, -1, Color(own, dim))
		paragraph(Vector2(left + 30.0, y - 12.0), told.reward_words, MINCHO_B, 17, Color(own, dim), wide - 30.0, 0.0, 2)
	else:
		sign_of(Vector2(left + 11.0, y - 9.0), 10.0, told.reward, Color(own, dim))
		text(Vector2(left + 32.0, y), "%sを得る" % told.reward_words, MINCHO_B, 22, Color(own, dim))
	y = top + ROWS[3][1] + 27.0
	if told.echo > 0:
		draw_rect(Rect2(left, y - 10.0, (wide - 96.0) * told.echo / richest, 5.0), Color(BLUE, 0.85 * dim))
		draw_rect(Rect2(left, y - 10.0, wide - 96.0, 5.0), Color(LINE, dim), false, 1.0)
		text(Vector2(left, y), "+%s" % UIFormat.amount(told.echo), MINCHO_B, 20, Color(BLUE, dim), HORIZONTAL_ALIGNMENT_RIGHT, wide)
	else:
		text(Vector2(left, y), "—", GOTHIC, 15, Color(FAINT, dim))
	y = top + ROWS[4][1] + 24.0
	paragraph(Vector2(left, y), told.goal if not told.event else told.summary, GOTHIC, 15, Color(PALE, dim), wide, 0.0, 2)
	y = top + ROWS[5][1] + 10.0
	if told.event:
		text(Vector2(left, y + 26.0), "なし", GOTHIC, 15, Color(FAINT, dim))
	else:
		var foes: Array = told.foes
		var each := minf(46.0, wide / maxf(1.0, foes.size()))
		for at in foes.size():
			var tile := foe_tile(foes[at][0], foes[at][1])
			if tile != null:
				if not foes[at][1]:
					draw_circle(Vector2(left + at * each + (each - 4.0) * 0.5, y + 22.0), (each - 4.0) * 0.5, Color(1.0, 1.0, 1.0, 0.06 * dim))
				draw_texture_rect(tile, Rect2(left + at * each, y + 44.0 - (each - 4.0), each - 4.0, each - 4.0), false, Color(1.0, 1.0, 1.0, dim))
		paragraph(Vector2(left, y + 66.0), told.summary, GOTHIC, 12, Color(DIM, dim), wide, 0.0, 2)
	y = top + ROWS[6][1] + 32.0
	if told.boss:
		text(Vector2(left, y), "最奥", GOTHIC, 14, Color(FAINT, dim))
	else:
		var leads := point.next
		if (leads[0] as RouteMap.Waypoint).area.boss != null:
			_kind_mark(Vector2(left + 9.0, y - 6.0), 8.0, AreaData.Kind.BOSS, Color(RED, dim))
			text(Vector2(left + 28.0, y), "ボスへ", GOTHIC_B, 14, Color(RED, dim))
		else:
			var x := left
			for next_point: RouteMap.Waypoint in leads:
				var next := model.tell(next_point)
				draw_circle(Vector2(x + 13.0, y - 6.0), 13.0, Color(TABLE, dim))
				ring(Vector2(x + 13.0, y - 6.0), 13.0, Color(FAINT, dim), 1.0)
				_kind_mark(Vector2(x + 13.0, y - 6.0), 5.5, next_point.area.kind, Color(PALE, dim))
				for pip in next.danger:
					draw_rect(Rect2(x + 30.0, y - 2.0 - pip * 6.0, 6.0, 4.0), Color(RED, dim))
				if next.reward >= 0 or next.event:
					sign_of(Vector2(x + 46.0, y - 6.0), 5.5, next.reward, Color(tint_of(next), dim))
				x += 70.0
			text(Vector2(left, y), "%dつの道" % leads.size(), GOTHIC_B, 14, Color(PALE, dim), HORIZONTAL_ALIGNMENT_RIGHT, wide)
	# Going there.
	var button := Rect2(left, top + FOOT + 8.0, wide, 46.0)
	if mine:
		var asked := arming()
		plate(button, Color(own, 0.12 + 0.8 * asked), Color(own, rise), 4.0, 2.0)
		text(Vector2(button.position.x, button.get_center().y + 8.0), "Enter でもう一度：出発" if model.armed else "ここへ進む　Enter", MINCHO_B, 19, PALE.lerp(TABLE, asked), HORIZONTAL_ALIGNMENT_CENTER, wide)
		zone(button, [&"go"])
		if asked > 0.0:
			_seal(Vector2(rect.end.x - 74.0, top + 108.0), asked)
	else:
		plate(button, Color.TRANSPARENT, Color(LINE, dim), 4.0)
		text(Vector2(button.position.x, button.get_center().y + 6.0), "%s　で選ぶ" % NUMERALS[index], GOTHIC, 13, Color(FAINT, dim), HORIZONTAL_ALIGNMENT_CENTER, wide)


# The seal struck on a dossier once the question is asked.
func _seal(centre: Vector2, share: float) -> void:
	draw_set_transform(centre, -0.2, Vector2.ONE * lerpf(1.8, 1.0, share))
	var colour := Color(RED, share)
	draw_circle(Vector2.ZERO, 30.0, Color(RED, 0.16 * share))
	ring(Vector2.ZERO, 30.0, colour, 2.5)
	ring(Vector2.ZERO, 24.0, Color(colour, 0.6 * share), 1.0)
	text(Vector2(-30.0, 8.0), "決行", MINCHO_B, 21, colour, HORIZONTAL_ALIGNMENT_CENTER, 60.0)
	draw_set_transform(Vector2.ZERO)


# --- Her state, read against the pick ---

func _state() -> void:
	plate(STATE, PANEL, LINE, 4.0)
	var point := model.selected()
	var told := model.tell(point) if point != null else {}
	var x := STATE.position.x + 24.0
	var y := STATE.position.y
	spaced(Vector2(x, y + 30.0), "現在の状態", GOTHIC_B, 13, BRASS, 4.0)
	# Her health.
	var hp := model.hp()
	var full := model.max_hp()
	text(Vector2(x, y + 72.0), "HP", GOTHIC_B, 14, RED)
	text(Vector2(x + 34.0, y + 74.0), str(hp), MINCHO_B, 30, PALE)
	text(Vector2(x + 34.0 + width_of(str(hp), MINCHO_B, 30) + 6.0, y + 74.0), "/ %d" % full, MINCHO_M, 16, DIM)
	var bar := Rect2(x + 150.0, y + 54.0, 300.0, 12.0)
	draw_rect(bar, Color(1.0, 1.0, 1.0, 0.07))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp / float(full), bar.size.y)), RED)
	for index in range(1, 4):
		draw_line(Vector2(bar.position.x + bar.size.x * index / 4.0, bar.position.y), Vector2(bar.position.x + bar.size.x * index / 4.0, bar.end.y), TABLE, 1.0)
	# A word where her health and the pick meet.
	var word := advice(told)
	if not word.is_empty():
		HubUI.star(self, Vector2(bar.position.x + 6.0, y + 88.0), 6.0, GOLD)
		text(Vector2(bar.position.x + 20.0, y + 93.0), word, GOTHIC, 14, GOLD)
	# The echo, and what the pick would bring it to.
	x = STATE.position.x + 540.0
	draw_line(Vector2(x - 28.0, y + 20.0), Vector2(x - 28.0, STATE.end.y - 20.0), LINE, 1.0)
	text(Vector2(x, y + 44.0), "残響", GOTHIC, 13, DIM)
	sign_of(Vector2(x + 9.0, y + 68.0), 8.0, AreaData.Reward.ECHO, BLUE)
	text(Vector2(x + 26.0, y + 76.0), UIFormat.amount(model.run.echo), MINCHO_B, 26, PALE)
	var gain: int = told.get("echo", 0)
	if gain > 0:
		var after := x + 26.0 + width_of(UIFormat.amount(model.run.echo), MINCHO_B, 26) + 14.0
		text(Vector2(after, y + 74.0), "→", GOTHIC, 16, DIM)
		text(Vector2(after + 26.0, y + 76.0), UIFormat.amount(model.run.echo + gain), MINCHO_B, 26, BLUE)
	x += 250.0
	draw_line(Vector2(x - 28.0, y + 20.0), Vector2(x - 28.0, STATE.end.y - 20.0), LINE, 1.0)
	text(Vector2(x, y + 44.0), "レベル", GOTHIC, 13, DIM)
	text(Vector2(x, y + 76.0), str(model.run.progression.level), MINCHO_B, 26, PALE)
	x += 120.0
	draw_line(Vector2(x - 28.0, y + 20.0), Vector2(x - 28.0, STATE.end.y - 20.0), LINE, 1.0)
	text(Vector2(x, y + 44.0), "強化", GOTHIC, 13, DIM)
	for held: Array in boons():
		emblem(Vector2(x + 18.0, y + 70.0), 18.0, held[0])
		if held[2]:
			text(Vector2(x + 26.0, y + 90.0), str(held[1]), GOTHIC_B, 12, PALE)
		x += 44.0
	if not model.run.curses.is_empty():
		text(Vector2(STATE.position.x, y + 44.0), "呪い：" + model.run.curse_names(), GOTHIC_B, 13, RED, HORIZONTAL_ALIGNMENT_RIGHT, STATE.size.x - 24.0)


# What her state says of the pick, from what both already show: nothing new
# is worked out but which of them stand together.
func advice(told: Dictionary) -> String:
	if told.is_empty() or told.veiled:
		return ""
	var hurt := model.hp() < model.max_hp()
	var low := model.hp() * 2 < model.max_hp()
	if told.event:
		return ""
	if told.reward == AreaData.Reward.HEAL:
		return "回復の報酬：減ったHPを戻せる" if hurt else "HPは満タン：回復の報酬は活かせない"
	if told.danger >= 3 and low:
		return "HPが半分を切っている。脅威の高い相手"
	if told.danger >= 3 and hurt:
		return "HPが減っている。脅威の高い相手"
	return ""


func _keys() -> void:
	var x := 52.0
	for pair: Array in [["← / →", "比べる"], ["Enter", "進む"], ["1〜3", "すぐ選ぶ"], ["Esc", "やめる" if model.armed else "メニュー"]]:
		text(Vector2(x, 872.0), pair[0], GOTHIC, 15, FAINT)
		x += width_of(pair[0], GOTHIC, 15) + 12.0
		text(Vector2(x, 872.0), pair[1], GOTHIC, 15, DIM)
		x += width_of(pair[1], GOTHIC, 15) + 34.0
