class_name ProtoLedger
extends ProtoScreen

# Prototype A, the hunters' ledger: every foe is a line in one ruled table,
# its figures in columns, so the eye runs down a column to compare and the
# whole record is seen at a glance. The index tabs above the sheet are the
# kinds (Q/E), each with its tally; R (or a click on a column's head) sorts
# the table by that figure. A foe not met is a line of "？？？" with its
# figures struck out and no stamp; it sorts after the foes met, so the order
# gives nothing away. The line under the cursor is run through with a
# highlighter, and its survey sheet lies at the right: a print of the foe,
# its figures as gauges against the strongest met, and what was noted of it.

const DESK := """
shader_type canvas_item;
%s
void fragment() {
	vec2 p = UV * vec2(1600.0, 900.0);
	float hide = fbm(p * 0.02) * 0.6 + noise(p * 0.6) * 0.4;
	vec3 col = mix(vec3(0.050, 0.062, 0.070), vec3(0.092, 0.110, 0.120), hide);
	float lamp = exp(-length((p - vec2(1250.0, 40.0)) / vec2(1100.0, 800.0)) * 1.8);
	col += vec3(1.0, 0.82, 0.55) * lamp * 0.10;
	col *= smoothstep(1.3, 0.3, length((UV - 0.5) * vec2(1.2, 1.5)));
	COLOR = vec4(col, 1.0);
}
""" % NOISE

const PAPER := Color("e8e4d7")
const PAPER_DIM := Color("cfc9b6")
const CARD := Color("efe9d8")
const INK := Color("1d2735")
const INK_DIM := Color("56606e")
const INK_FAINT := Color("8f96a0")
const RULE := Color("8aa0b8")
const MARK := Color("f2d34a")
const STAMP := Color("b3261e")
const GAUGE := Color("2f5d8c")
const SHEET := Rect2(48.0, 96.0, 1000.0, 772.0)
const FORM := Rect2(1076.0, 96.0, 476.0, 772.0)
const ROW := 40.0
const ROWS_TOP := 200.0
const VISIBLE := 16
# Column: [name, left, right, the figure it sorts by ("" for none)].
const COLUMNS := [
	["No.", 66.0, 118.0, ""], ["名称", 176.0, 470.0, ""], ["分類", 480.0, 560.0, ""],
	["HP", 570.0, 668.0, "hp"], ["ぶつかる力", 678.0, 792.0, "contact"], ["速さ", 802.0, 896.0, "speed"], ["記録", 912.0, 1032.0, ""],
]
const SORTS := ["", "hp", "contact", "speed"]
const SORT_NAMES := ["番号順", "HPの高い順", "ぶつかる力の高い順", "速さの高い順"]

var kind := 0
var sort := 0
var row := 0
var top := 0
var listed: Array[FoeData] = []


func _init(of: ProtoCodex) -> void:
	super(of)
	backdrop(DESK)
	_list()


func title() -> String:
	return "A　調査台帳"


func hints() -> Array:
	return [["↑ ↓", "敵を選ぶ"], ["Q / E", "分類"], ["R", "並べ替え"], ["Esc", "戻る"]]


func _value(foe: FoeData, key: String) -> float:
	for stat: Array in codex.stats(foe):
		if stat[0] == key:
			return float(stat[2])
	return -1.0


# The table's lines: the kind's foes in the chosen order, those not met last.
func _list() -> void:
	listed = codex.foes(kind)
	var key: String = SORTS[sort]
	if not key.is_empty():
		listed.sort_custom(func(a: FoeData, b: FoeData) -> bool:
			var va := _value(a, key)
			var vb := _value(b, key)
			return codex.number(a) < codex.number(b) if va == vb else va > vb)
	row = clampi(row, 0, maxi(0, listed.size() - 1))
	_follow()


func _follow() -> void:
	top = clampi(top, maxi(0, row - VISIBLE + 2), maxi(0, row - 1))
	top = clampi(top, 0, maxi(0, listed.size() - VISIBLE))


func _key(action: StringName) -> void:
	match action:
		&"up":
			row = maxi(0, row - 1)
		&"down":
			row = mini(listed.size() - 1, row + 1)
		&"prev", &"left":
			_turn(kind - 1)
		&"next", &"right":
			_turn(kind + 1)
		&"details":
			_sort((sort + 1) % SORTS.size())
	_follow()
	kick(&"move")


func _turn(to: int) -> void:
	to = clampi(to, 0, 3)
	if to == kind:
		return
	kind = to
	row = 0
	top = 0
	_list()
	kick(&"turn")


func _sort(to: int) -> void:
	var held := listed[row]
	sort = to
	_list()
	row = maxi(0, listed.find(held))
	_follow()
	kick(&"sort")


func _click(id: Variant) -> void:
	var what: Array = id
	match what[0]:
		&"tab":
			_turn(what[1])
		&"row":
			row = what[1]
			kick(&"move")
		&"sort":
			_sort(what[1] if sort != what[1] else 0)


func _wheel(step: int) -> void:
	top = clampi(top + step * 2, 0, maxi(0, listed.size() - VISIBLE))
	row = clampi(row, top, top + VISIBLE - 1)


func pose(state: StringName) -> void:
	kind = 0
	sort = 0
	row = 0
	top = 0
	_list()
	match state:
		&"browse":
			row = 6
		&"category":
			kind = 2
			_list()
			row = 1
		&"unknown":
			row = 7
		&"detail":
			sort = 1
			_list()
			row = 0
	_follow()
	_kicks.clear()


# --- Drawing ---

func _paint() -> void:
	_paint_tabs()
	_paint_sheet()
	_paint_form()
	var x := 60.0
	for pair: Array in hints():
		var width := maxf(28.0, GOTHIC_B.get_string_size(pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0)
		plate(Rect2(x, 874.0, width, 22.0), Color(PAPER, 0.1), Color(PAPER, 0.5), 3.0)
		text(Vector2(x, 890.0), pair[0], GOTHIC_B, 13, PAPER, HORIZONTAL_ALIGNMENT_CENTER, width)
		x += width + 8.0
		text(Vector2(x, 890.0), pair[1], GOTHIC, 14, Color(PAPER, 0.7))
		x += GOTHIC.get_string_size(pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 24.0


func _paint_tabs() -> void:
	spaced(Vector2(60.0, 58.0), "討伐記録簿", MINCHO_B, 28, PAPER, 8.0)
	for index in 4:
		var here := index == kind
		var rect := Rect2(360.0 + 166.0 * index, 52.0 if here else 60.0, 158.0, 48.0 if here else 40.0)
		var tally := codex.tally(index)
		draw_rect(Rect2(rect.position + Vector2(2.0, 3.0), rect.size), Color(0.0, 0.0, 0.0, 0.35))
		draw_rect(rect, PAPER if here else (PAPER_DIM.lightened(0.1) if hovered(&"tab", index) else PAPER_DIM))
		text(Vector2(rect.position.x + 14.0, rect.position.y + 28.0), FoeCatalog.KINDS[index], GOTHIC_B, 17, INK if here else INK_DIM)
		text(Vector2(rect.position.x, rect.position.y + 28.0), "%d / %d" % tally, GOTHIC, 14, INK_DIM, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 14.0)
		zone(rect, [&"tab", index])


func _paint_sheet() -> void:
	draw_rect(Rect2(SHEET.position + Vector2(5.0, 8.0), SHEET.size), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(SHEET, PAPER)
	shade(Rect2(SHEET.position, Vector2(SHEET.size.x, 40.0)), Color(1.0, 1.0, 1.0, 0.25), Color(1.0, 1.0, 1.0, 0.0))
	# The sheet's head: what is listed, how, and how much of it is filled.
	var tally := codex.tally(kind)
	text(Vector2(SHEET.position.x + 24.0, 132.0), "%s　%d体のうち %d体を記録" % [FoeCatalog.KINDS[kind], tally[1], tally[0]], GOTHIC_B, 16, INK)
	text(Vector2(SHEET.position.x, 132.0), "並び：%s" % SORT_NAMES[sort], GOTHIC, 14, INK_DIM, HORIZONTAL_ALIGNMENT_RIGHT, SHEET.size.x - 24.0)
	var bar := Rect2(SHEET.position.x + 24.0, 144.0, SHEET.size.x - 48.0, 4.0)
	draw_rect(bar, Color(RULE, 0.35))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * tally[0] / maxf(1.0, tally[1]), bar.size.y)), STAMP)
	# The columns' heads.
	draw_rect(Rect2(SHEET.position.x, 160.0, SHEET.size.x, 34.0), Color(RULE, 0.22))
	for index in COLUMNS.size():
		var column: Array = COLUMNS[index]
		var numeric: bool = not (column[3] as String).is_empty()
		var sorted: bool = numeric and SORTS[sort] == column[3]
		var words: String = column[0] + (" ▼" if sorted else "")
		text(Vector2(column[1], 183.0), words, GOTHIC_B, 14, STAMP if sorted else INK, HORIZONTAL_ALIGNMENT_RIGHT if numeric else HORIZONTAL_ALIGNMENT_LEFT, column[2] - column[1])
		if numeric:
			zone(Rect2(column[1], 160.0, column[2] - column[1], 34.0), [&"sort", SORTS.find(column[3])])
		if index > 1:
			draw_line(Vector2(column[1] - 6.0, 160.0), Vector2(column[1] - 6.0, ROWS_TOP + ROW * VISIBLE), Color(RULE, 0.45), 1.0)
	draw_line(Vector2(SHEET.position.x, 194.0), Vector2(SHEET.end.x, 194.0), INK, 1.5)
	for place in mini(VISIBLE, listed.size() - top):
		_paint_row(top + place, place)
	# Where the window stands in a longer list.
	if listed.size() > VISIBLE:
		var rail := Rect2(SHEET.end.x - 8.0, ROWS_TOP, 4.0, ROW * VISIBLE)
		draw_rect(rail, Color(RULE, 0.3))
		draw_rect(Rect2(rail.position.x, rail.position.y + rail.size.y * top / listed.size(), 4.0, rail.size.y * VISIBLE / listed.size()), INK_DIM)


func _paint_row(index: int, place: int) -> void:
	var foe := listed[index]
	var known := codex.known(foe)
	var y := ROWS_TOP + ROW * place
	var base := y + 27.0
	var rect := Rect2(SHEET.position.x, y, SHEET.size.x - 12.0, ROW)
	zone(rect, [&"row", index])
	if index == row:
		# Run through with a highlighter, a tab at the sheet's edge.
		var sweep := eased(&"move", 0.14)
		draw_rect(Rect2(rect.position.x, y + 4.0, rect.size.x * (0.5 + 0.5 * sweep), ROW - 8.0), Color(MARK, 0.55))
		draw_colored_polygon(PackedVector2Array([Vector2(SHEET.position.x - 14.0, y + 8.0), Vector2(SHEET.position.x, y + ROW * 0.5), Vector2(SHEET.position.x - 14.0, y + ROW - 8.0)]), MARK)
	elif hovered(&"row", index):
		draw_rect(Rect2(rect.position.x, y + 4.0, rect.size.x, ROW - 8.0), Color(MARK, 0.18))
	draw_line(Vector2(SHEET.position.x, y + ROW), Vector2(SHEET.end.x, y + ROW), Color(RULE, 0.5), 1.0)
	var ink := INK if known else INK_FAINT
	text(Vector2(COLUMNS[0][1], base), "%02d" % codex.number(foe), GOTHIC_B, 15, INK_DIM)
	icon(Vector2(146.0, y + ROW * 0.5), 15.0, foe)
	ring(Vector2(146.0, y + ROW * 0.5), 15.0, Color(INK, 0.7), 1.2)
	text(Vector2(COLUMNS[1][1], base), codex.name_of(foe), GOTHIC_B if index == row else GOTHIC, 17, ink, HORIZONTAL_ALIGNMENT_LEFT, COLUMNS[1][2] - COLUMNS[1][1])
	text(Vector2(COLUMNS[2][1], base), codex.kind_name(foe), GOTHIC, 14, INK_DIM)
	for column in range(3, 6):
		var left: float = COLUMNS[column][1]
		var right: float = COLUMNS[column][2]
		if not known:
			# Struck out: the ledger holds no figure for a foe not met.
			draw_rect(Rect2(right - 46.0, y + 13.0, 46.0, 14.0), Color(INK, 0.78))
			continue
		var key: String = COLUMNS[column][3]
		var value := _value(foe, key)
		text(Vector2(left, base - 3.0), str(int(value)), GOTHIC_B, 16, INK, HORIZONTAL_ALIGNMENT_RIGHT, right - left)
		var share := sqrt(value / codex.most(key))
		draw_rect(Rect2(right - 60.0 * share, y + 31.0, 60.0 * share, 3.0), Color(GAUGE, 0.75))
	var centre := Vector2((COLUMNS[6][1] + COLUMNS[6][2]) * 0.5 - 8.0, y + ROW * 0.5)
	if known:
		draw_set_transform(centre, -0.12 + 0.05 * sin(index * 2.1))
		plate(Rect2(-36.0, -13.0, 72.0, 26.0), Color.TRANSPARENT, STAMP, 4.0, 2.0)
		text(Vector2(-36.0, 6.0), "遭遇", GOTHIC_B, 15, STAMP, HORIZONTAL_ALIGNMENT_CENTER, 72.0)
		draw_set_transform(Vector2.ZERO)
	else:
		text(Vector2(centre.x - 40.0, base), "未確認", GOTHIC, 14, INK_FAINT, HORIZONTAL_ALIGNMENT_CENTER, 80.0)


# The survey sheet of the foe under the cursor.
func _paint_form() -> void:
	if listed.is_empty():
		return
	var foe := listed[row]
	var known := codex.known(foe)
	var slide := 10.0 * (1.0 - eased(&"move", 0.16))
	var rect := Rect2(FORM.position + Vector2(slide, 0.0), FORM.size)
	draw_rect(Rect2(rect.position + Vector2(5.0, 8.0), rect.size), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(rect, CARD)
	var left := rect.position.x + 28.0
	var width := rect.size.x - 56.0
	text(Vector2(left, 132.0), "調査票", GOTHIC_B, 14, INK_DIM)
	text(Vector2(left, 132.0), "No. %02d　%s" % [codex.number(foe), codex.kind_name(foe)], GOTHIC, 14, INK_DIM, HORIZONTAL_ALIGNMENT_RIGHT, width)
	draw_line(Vector2(left, 142.0), Vector2(left + width, 142.0), INK, 1.5)
	text(Vector2(left, 186.0), codex.name_of(foe), GOTHIC_B, 32, INK if known else INK_FAINT, HORIZONTAL_ALIGNMENT_LEFT, width)
	var epithet := codex.epithet(foe)
	text(Vector2(left, 212.0), epithet if not epithet.is_empty() else ("記録なし" if not known else ""), GOTHIC, 14, STAMP if not epithet.is_empty() else INK_FAINT)
	# The print: the foe on a dark ground, taped to the sheet.
	var print_rect := Rect2(left, 228.0, width, 286.0)
	draw_rect(Rect2(print_rect.position + Vector2(2.0, 3.0), print_rect.size), Color(0.0, 0.0, 0.0, 0.3))
	draw_rect(print_rect, Color.WHITE)
	var inner := print_rect.grow(-8.0)
	shade(inner, Color("3a4250"), Color("1d222b"))
	glow(Vector2(inner.get_center().x, inner.end.y - 40.0), 190.0, Color(1.0, 0.9, 0.7, 0.16))
	figure(inner.grow(-16.0), foe, Color(0.02, 0.03, 0.05, 0.92))
	for corner: Vector2 in [print_rect.position + Vector2(-8.0, -4.0), Vector2(print_rect.end.x - 44.0, print_rect.position.y - 4.0)]:
		draw_set_transform(corner + Vector2(26.0, 9.0), -0.5 if corner.x < print_rect.get_center().x else 0.5)
		draw_rect(Rect2(-26.0, -9.0, 52.0, 18.0), Color(0.95, 0.9, 0.7, 0.75))
		draw_set_transform(Vector2.ZERO)
	if not known:
		draw_set_transform(inner.get_center(), -0.2)
		plate(Rect2(-110.0, -30.0, 220.0, 60.0), Color.TRANSPARENT, Color(STAMP, 0.9), 6.0, 3.0)
		text(Vector2(-110.0, 13.0), "記録なし", GOTHIC_B, 34, Color(STAMP, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 220.0)
		draw_set_transform(Vector2.ZERO)
	# Its figures as gauges against the strongest foe met.
	var y := 548.0
	var names := [["hp", "HP"], ["contact", "ぶつかる力"], ["speed", "速さ"]]
	for pair: Array in names:
		text(Vector2(left, y), pair[1], GOTHIC, 15, INK_DIM)
		var gauge := Rect2(left + 110.0, y - 13.0, width - 190.0, 12.0)
		draw_rect(gauge, Color(RULE, 0.3))
		if known:
			var value := _value(foe, pair[0])
			draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * sqrt(value / codex.most(pair[0])), gauge.size.y)), GAUGE)
			text(Vector2(left, y + 2.0), str(int(value)), GOTHIC_B, 20, INK, HORIZONTAL_ALIGNMENT_RIGHT, width)
		else:
			draw_rect(Rect2(left + width - 54.0, y - 15.0, 54.0, 16.0), Color(INK, 0.78))
		y += 34.0
	draw_line(Vector2(left, y - 8.0), Vector2(left + width, y - 8.0), Color(RULE, 0.6), 1.0)
	# What was noted of it, and where it is found.
	var notes := codex.account(foe)
	text(Vector2(left, y + 18.0), "所見", GOTHIC_B, 14, INK_DIM)
	y += 44.0
	y += paragraph(Vector2(left, y), notes[0], GOTHIC, 16, INK if known else INK_DIM, width, 14.0, 5)
	if not notes[1].is_empty():
		text(Vector2(left, y + 8.0), "出没", GOTHIC_B, 14, INK_DIM)
		paragraph(Vector2(left + 46.0, y + 8.0), notes[1], GOTHIC, 15, INK, width - 46.0, 10.0, 2)
