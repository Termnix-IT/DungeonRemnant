class_name ProtoGrimoire
extends ProtoScreen

# Prototype B, the grimoire: an open book whose chapters are her four slots
# and her figures. The tabs at the book's edge are the chapters (Q/E or
# left/right turn to the next); the left page is the chapter: what the slot
# holds now, sealed in red wax, over an index of everything it can hold. The
# right page is the entry under the cursor, read as a page: its picture, its
# account in prose, and a ledger setting its figures beside those of what the
# slot holds now, so a change is compared before it is made. Enter presses
# the seal on the entry. The last chapter is her figures, written in full
# across both pages. The look is ink on parchment: light, quiet, and read.

const DESK := """
shader_type canvas_item;
%s
float box(vec2 p, vec2 a, vec2 b) {
	vec2 d = max(a - p, p - b);
	return max(d.x, d.y);
}
void fragment() {
	vec2 p = UV * vec2(1600.0, 900.0);
	// The desk: dark wood under a candle at the upper right.
	float grain = fbm(vec2(p.x * 0.004, p.y * 0.06)) * 0.6 + fbm(p * 0.02) * 0.4;
	vec3 col = mix(vec3(0.045, 0.035, 0.030), vec3(0.120, 0.085, 0.060), grain);
	float candle = exp(-length((p - vec2(1380.0, 40.0)) / vec2(900.0, 700.0)) * 2.0);
	col += vec3(1.0, 0.62, 0.28) * candle * 0.22;
	col *= smoothstep(1.3, 0.3, length((UV - 0.5) * vec2(1.2, 1.5)));
	// The book's shadow and its leather cover.
	float cover = box(p, vec2(112.0, 58.0), vec2(1488.0, 846.0));
	col *= mix(0.35, 1.0, smoothstep(0.0, 46.0, cover));
	if (cover < 0.0) {
		float hide = fbm(p * 0.05);
		col = mix(vec3(0.20, 0.07, 0.06), vec3(0.30, 0.11, 0.08), hide);
		col *= 0.75 + 0.25 * smoothstep(0.0, 10.0, -cover);
	}
	// The pages: parchment, mottled, browner at their edges, shaded into the gutter.
	float page = box(p, vec2(132.0, 74.0), vec2(1468.0, 830.0));
	if (page < 0.0) {
		float mottle = fbm(p * 0.006) * 0.65 + fbm(p * 0.05) * 0.35;
		vec3 paper = mix(vec3(0.800, 0.720, 0.560), vec3(0.930, 0.880, 0.760), mottle);
		paper *= 0.86 + 0.14 * smoothstep(0.0, 70.0, -page);
		float gutter = abs(p.x - 800.0);
		paper *= 0.62 + 0.38 * smoothstep(0.0, 90.0, gutter);
		paper += vec3(0.05, 0.04, 0.02) * smoothstep(240.0, 60.0, gutter) * smoothstep(0.0, 60.0, gutter);
		paper *= 0.94 + 0.06 * noise(p * 0.9);
		paper += vec3(1.0, 0.75, 0.45) * candle * 0.05;
		col = paper;
	}
	COLOR = vec4(col, 1.0);
}
""" % NOISE

const INK := Color("2a2018")
const SEPIA := Color("7a6046")
const FAINT := Color("ab9774")
const RED := Color("9e2a20")
const RED_DARK := Color("6d1711")
const BLUE := Color("2c4c70")
const PAPER := Color("efe4c8")
const LEFT := 186.0
const RIGHT_PAGE := 850.0
const PAGE_WIDTH := 564.0
const ROW := 50.0
const LIST_TOP := 416.0
const CHAPTERS := ["攻撃", "スキル1", "スキル2", "必殺技", "能力"]
const ORDINALS := ["第一章", "第二章", "第三章", "第四章", "第五章"]
const CHAPTER_LINES := ["左クリックで振るう武器", "Q で放つ技", "E で放つ技", "R で解き放つ必殺技", "ミオの力のすべて"]
const STATS := 4

var chapter := 1
var row := 0
var _last_chapter := 1
var _sealed_slot := -1


func _init(of: ProtoBuild) -> void:
	super(of)
	backdrop(DESK)
	row = _held_row()


func title() -> String:
	return "B　魔導書"


func hints() -> Array:
	if chapter == STATS:
		return [["Q / E", "章をめくる"], ["R", "前の章へ"], ["Esc", "本を閉じる"]]
	return [["↑ ↓", "技を選ぶ"], ["Q / E", "章をめくる"], ["Enter", "封を押す"], ["X", "外す"], ["R", "能力"], ["Esc", "本を閉じる"]]


# The chapter's entries: for a slot that can be emptied, "外す" first.
func _entries() -> Array:
	var rows := build.choices(chapter)
	if chapter != ProtoBuild.ATTACK:
		rows.push_front({id = ProtoBuild.CLEAR, emblem = "", name = "外す", note = "この欄を空ける", state = ProtoBuild.State.FREE, other = -1})
	return rows


func _held_row() -> int:
	var rows := _entries()
	for index in rows.size():
		if rows[index].state == ProtoBuild.State.HERE:
			return index
	return 1 if chapter != ProtoBuild.ATTACK else 0


func _turn(to: int) -> void:
	to = clampi(to, 0, STATS)
	if to == chapter:
		return
	if chapter != STATS:
		_last_chapter = chapter
	_kicks[&"way"] = 1.0 if to > chapter else -1.0
	chapter = to
	if chapter != STATS:
		row = _held_row()
	kick(&"turn")


func _key(action: StringName) -> void:
	match action:
		&"prev", &"left":
			_turn(chapter - 1)
		&"next", &"right":
			_turn(chapter + 1)
		&"details":
			_turn(_last_chapter if chapter == STATS else STATS)
		&"cancel":
			if chapter == STATS:
				_turn(_last_chapter)
	if chapter == STATS:
		return
	match action:
		&"up":
			row = maxi(0, row - 1)
			kick(&"move")
		&"down":
			row = mini(_entries().size() - 1, row + 1)
			kick(&"move")
		&"accept":
			_seal()
		&"clear":
			if build.can_clear(chapter):
				build.equip(chapter, ProtoBuild.CLEAR)
			else:
				kick(&"refuse")


func _seal() -> void:
	var entry: Dictionary = _entries()[row]
	var told := build.account(chapter, entry.id)
	if not told.can:
		kick(&"refuse")
		return
	build.equip(chapter, entry.id)
	row = _held_row() if entry.id != ProtoBuild.CLEAR else 0


func _on_changed(slots: Array) -> void:
	_sealed_slot = chapter if slots.has(chapter) else int(slots[0])
	kick(&"seal")


func _click(id: Variant) -> void:
	var what: Array = id
	if what[0] == &"tab":
		_turn(what[1])
	elif what[0] == &"row":
		if row == what[1]:
			_seal()
		row = mini(what[1], _entries().size() - 1)
		kick(&"move")
	elif what[0] == &"seal":
		_seal()


func _wheel(step: int) -> void:
	_key(&"down" if step > 0 else &"up")


func pose(state: StringName) -> void:
	chapter = 1
	row = _held_row()
	match state:
		&"browse":
			row = 3
		&"change":
			row = 2
		&"stats":
			chapter = STATS
	_kicks.clear()


# --- Drawing ---

func _paint() -> void:
	_paint_tabs()
	var fade := eased(&"turn", 0.28)
	var way := float(_kicks.get(&"way", 1.0)) if since(&"turn") < 0.3 else 0.0
	draw_set_transform(Vector2(18.0 * way * (1.0 - fade), 0.0))
	modulate_ink = fade
	if chapter == STATS:
		_paint_figures()
	else:
		_paint_chapter()
		_paint_entry()
	draw_set_transform(Vector2.ZERO)
	# The leaf turning: a shadow sweeping across the spread.
	if since(&"turn") < 0.28:
		var sweep := since(&"turn") / 0.28
		var x := lerpf(1468.0, 132.0, sweep) if way > 0.0 else lerpf(132.0, 1468.0, sweep)
		shade_across(Rect2(x - 120.0, 74.0, 120.0, 756.0), Color(0.2, 0.12, 0.05, 0.0), Color(0.2, 0.12, 0.05, 0.28 * (1.0 - sweep)))
		draw_line(Vector2(x, 74.0), Vector2(x, 830.0), Color(0.15, 0.1, 0.05, 0.4 * (1.0 - sweep)), 2.0)
	_paint_hints()


var modulate_ink := 1.0


func _ink(colour: Color, share := 1.0) -> Color:
	return Color(colour, colour.a * share * modulate_ink)


func _paint_tabs() -> void:
	for index in CHAPTERS.size():
		var here := index == chapter
		var top := 118.0 + 122.0 * index
		var rect := Rect2(1468.0, top, 62.0 if here else 46.0, 108.0)
		var hot := hovered(&"tab", index)
		draw_rect(Rect2(rect.position + Vector2(0.0, 4.0), rect.size), Color(0.0, 0.0, 0.0, 0.35))
		draw_rect(rect, RED if here else (PAPER.darkened(0.12) if hot else PAPER.darkened(0.24)))
		draw_rect(Rect2(rect.position, Vector2(6.0, rect.size.y)), Color(0.0, 0.0, 0.0, 0.18))
		var label: String = CHAPTERS[index]
		var size := 17
		var y := top + (108.0 - label.length() * 21.0) * 0.5 + 17.0
		for letter in label.length():
			text(Vector2(rect.position.x + 6.0, y), label[letter], MINCHO_B, size, PAPER if here else INK, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 6.0)
			y += 21.0
		zone(rect, [&"tab", index])


func _rule(y: float, left: float, width: float) -> void:
	var mid := left + width * 0.5
	draw_line(Vector2(left, y), Vector2(mid - 12.0, y), _ink(SEPIA, 0.7), 1.0)
	draw_line(Vector2(mid + 12.0, y), Vector2(left + width, y), _ink(SEPIA, 0.7), 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(mid, y - 5.0), Vector2(mid + 5.0, y), Vector2(mid, y + 5.0), Vector2(mid - 5.0, y)]), _ink(SEPIA))


# A row of dots between a name and its figure.
func _leader(from: float, to: float, y: float, colour: Color) -> void:
	var x := from
	while x < to:
		draw_circle(Vector2(x, y), 1.0, colour)
		x += 7.0


# An emblem as a painted miniature: the picture in a double ring of ink.
func _miniature(centre: Vector2, radius: float, key: String, known := true) -> void:
	draw_circle(centre + Vector2(1.5, 2.5), radius + 3.0, _ink(Color(0.2, 0.12, 0.05, 0.3)))
	if key.is_empty():
		draw_circle(centre, radius, _ink(Color(PAPER.darkened(0.1), 0.8)))
		for step in 18:
			ring(centre, radius - 3.0, _ink(SEPIA, 0.8), 1.2, TAU * step / 18.0, TAU * (step + 0.5) / 18.0)
	elif known:
		emblem(centre, radius, key, Color(1.0, 1.0, 1.0, modulate_ink))
	else:
		emblem(centre, radius, key, _ink(Color(0.36, 0.28, 0.2, 0.55)))
	ring(centre, radius, _ink(INK), 2.0)
	ring(centre, radius + 4.5, _ink(SEPIA, 0.8), 1.0)


# A seal of red wax, a letter pressed into it.
func _wax(centre: Vector2, radius: float, letter: String, scale := 1.0, alpha := 1.0) -> void:
	var points := PackedVector2Array()
	for index in 40:
		var wobble := 1.0 + 0.045 * sin(index * 2.3 + radius) + 0.03 * sin(index * 5.1)
		points.append(centre + Vector2.from_angle(TAU * index / 40.0) * radius * scale * wobble)
	draw_colored_polygon(PackedVector2Array(Array(points).map(func(point: Vector2) -> Vector2: return point + Vector2(1.5, 3.0))), Color(0.2, 0.05, 0.03, 0.35 * alpha))
	draw_colored_polygon(points, Color(RED, alpha))
	ring(centre, radius * scale * 0.72, Color(RED_DARK, alpha), 2.0)
	ring(centre - Vector2(1.0, 1.5), radius * scale * 0.9, Color(1.0, 0.7, 0.6, 0.25 * alpha), 1.5, PI * 1.1, PI * 1.7)
	var size := int(radius * scale * 0.72)
	text(Vector2(centre.x - radius, centre.y + size * 0.36), letter, MINCHO_B, size, Color(PAPER, 0.92 * alpha), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0)


func _seal_letter(slot: int) -> String:
	return ["剣", "Q", "E", "R"][slot]


func _paint_chapter() -> void:
	text(Vector2(LEFT, 128.0), ORDINALS[chapter], MINCHO_M, 16, _ink(SEPIA), HORIZONTAL_ALIGNMENT_CENTER, PAGE_WIDTH)
	text(Vector2(LEFT, 180.0), CHAPTERS[chapter], MINCHO_B, 44, _ink(INK), HORIZONTAL_ALIGNMENT_CENTER, PAGE_WIDTH)
	text(Vector2(LEFT, 212.0), CHAPTER_LINES[chapter], MINCHO_M, 16, _ink(SEPIA), HORIZONTAL_ALIGNMENT_CENTER, PAGE_WIDTH)
	_rule(236.0, LEFT, PAGE_WIDTH)
	# What the chapter holds now, under its seal.
	var held := build.content(chapter)
	var centre := Vector2(LEFT + 62.0, 308.0)
	text(Vector2(LEFT + 134.0, 286.0), "いま記されている技", MINCHO_M, 15, _ink(SEPIA))
	_miniature(centre, 48.0, ProtoBuild.emblem_of(held))
	var sealed_now := _sealed_slot == chapter and since(&"seal") < 0.6
	if held.is_empty():
		var sealed_special := chapter == ProtoBuild.SPECIAL and not build.meta.owns_any_special()
		text(Vector2(LEFT + 134.0, 328.0), "封印" if sealed_special else "空欄", MINCHO_B, 32, _ink(FAINT))
	else:
		text(Vector2(LEFT + 134.0, 328.0), build.name_of(held), MINCHO_B, 32, _ink(INK))
		var press := 1.0
		var alpha := 1.0
		if sealed_now:
			var share := clampf(since(&"seal") / 0.22, 0.0, 1.0)
			press = lerpf(2.4, 1.0, 1.0 - pow(1.0 - share, 3.0))
			alpha = share
			if since(&"seal") > 0.2:
				var spread := (since(&"seal") - 0.2) / 0.4
				ring(Vector2(LEFT + PAGE_WIDTH - 52.0, 308.0), 40.0 + 46.0 * spread, Color(RED, 0.5 * (1.0 - spread)), 2.0)
		_wax(Vector2(LEFT + PAGE_WIDTH - 52.0, 308.0), 34.0, _seal_letter(chapter), press, alpha * modulate_ink)
	# The index.
	var rows := _entries()
	var known := 0
	var total := 0
	for entry: Dictionary in rows:
		if entry.id != ProtoBuild.CLEAR:
			total += 1
			known += 0 if entry.state == ProtoBuild.State.UNKNOWN else 1
	text(Vector2(LEFT, 390.0), "目録", MINCHO_B, 18, _ink(INK))
	text(Vector2(LEFT, 390.0), "習得 %d / %d" % [known, total], MINCHO_M, 15, _ink(SEPIA), HORIZONTAL_ALIGNMENT_RIGHT, PAGE_WIDTH)
	draw_line(Vector2(LEFT, 400.0), Vector2(LEFT + PAGE_WIDTH, 400.0), _ink(INK, 0.8), 1.5)
	for index in rows.size():
		_paint_row(index, rows[index])


func _paint_row(index: int, entry: Dictionary) -> void:
	var top := LIST_TOP + ROW * index
	var rect := Rect2(LEFT - 16.0, top, PAGE_WIDTH + 32.0, ROW)
	var base := top + 33.0
	var here := index == row
	var unknown: bool = entry.state == ProtoBuild.State.UNKNOWN
	zone(rect, [&"row", index])
	if here:
		# The reader's place: a wash of ink and a mark in the margin.
		var slide := eased(&"move", 0.14)
		shade_across(Rect2(rect.position.x, top + 4.0, rect.size.x * (0.6 + 0.4 * slide), ROW - 8.0), _ink(Color(0.45, 0.3, 0.12, 0.2)), _ink(Color(0.45, 0.3, 0.12, 0.03)))
		draw_rect(Rect2(rect.position.x, top + 4.0, 4.0, ROW - 8.0), _ink(RED))
		if since(&"refuse") < 0.3:
			base += 0.0
	elif hovered(&"row", index):
		draw_rect(Rect2(rect.position.x, top + 4.0, rect.size.x, ROW - 8.0), _ink(Color(0.45, 0.3, 0.12, 0.07)))
	var name_colour := FAINT if unknown else INK
	if entry.id == ProtoBuild.CLEAR:
		_miniature(Vector2(LEFT + 18.0, top + ROW * 0.5), 14.0, "")
		name_colour = SEPIA if build.can_clear(chapter) else FAINT
	else:
		_miniature(Vector2(LEFT + 18.0, top + ROW * 0.5), 15.0, entry.emblem, not unknown)
	text(Vector2(LEFT + 48.0, base), entry.name, MINCHO_B if here else MINCHO_M, 23, _ink(name_colour))
	var name_end := LEFT + 48.0 + MINCHO_B.get_string_size(entry.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x + 12.0
	var right := LEFT + PAGE_WIDTH
	# Where it stands, in the margin at the right.
	if entry.state == ProtoBuild.State.HERE:
		_wax(Vector2(right - 14.0, top + ROW * 0.5), 13.0, _seal_letter(chapter))
		text(Vector2(right - 96.0, base - 2.0), "装備中", MINCHO_B, 15, _ink(RED), HORIZONTAL_ALIGNMENT_RIGHT, 64.0)
		right -= 100.0
	elif entry.state == ProtoBuild.State.ELSEWHERE:
		var mark := "%s に装備中" % ProtoBuild.SLOT_KEYS[entry.other]
		text(Vector2(right - 130.0, base - 2.0), mark, MINCHO_M, 15, _ink(BLUE), HORIZONTAL_ALIGNMENT_RIGHT, 130.0)
		right -= MINCHO_M.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 10.0
	var note: String = entry.note
	var note_width := MINCHO_M.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	text(Vector2(right - note_width, base - 2.0), note, MINCHO_M, 16, _ink(FAINT if unknown else SEPIA))
	_leader(name_end, right - note_width - 10.0, base - 6.0, _ink(FAINT if unknown else SEPIA, 0.7))


func _paint_entry() -> void:
	var entry: Dictionary = _entries()[row]
	var told := build.account(chapter, entry.id)
	var left := RIGHT_PAGE
	var centre := Vector2(left + 96.0, 200.0)
	# Rays behind the picture, as an illuminated initial has.
	if not told.unknown and not entry.emblem.is_empty():
		for ray in 24:
			var way := Vector2.from_angle(TAU * ray / 24.0)
			draw_line(centre + way * 104.0, centre + way * (116.0 if ray % 2 == 0 else 124.0), _ink(SEPIA, 0.6), 1.0, true)
	_miniature(centre, 92.0, entry.emblem, not told.unknown)
	var text_left := left + 226.0
	text(Vector2(text_left, 152.0), told.kind, MINCHO_M, 16, _ink(SEPIA))
	text(Vector2(text_left, 214.0), told.name, MINCHO_B, 50, _ink(FAINT if told.unknown else INK), HORIZONTAL_ALIGNMENT_LEFT, PAGE_WIDTH - 226.0)
	var where := ""
	var where_colour := SEPIA
	match entry.state:
		ProtoBuild.State.HERE:
			where = "この章に記されている"
			where_colour = RED
		ProtoBuild.State.ELSEWHERE:
			where = "「%s」の章に記されている" % CHAPTERS[entry.other]
			where_colour = BLUE
		ProtoBuild.State.UNKNOWN:
			where = "まだ記されていない"
			where_colour = FAINT
	text(Vector2(text_left, 250.0), where, MINCHO_M, 16, _ink(where_colour))
	_rule(326.0, left, PAGE_WIDTH)
	var y := 372.0
	y += paragraph(Vector2(left, y), told.description, MINCHO_M, 20, _ink(INK), PAGE_WIDTH, 26.0, 4)
	# The ledger: this entry's figures beside those of what the chapter holds.
	var held := build.content(chapter)
	var compare: bool = not told.unknown and not held.is_empty() and held != entry.id and entry.id != ProtoBuild.CLEAR
	var figures: Array = told.figures
	if entry.id == ProtoBuild.CLEAR and not held.is_empty():
		figures = []
	if not figures.is_empty():
		var now: Array = build.account(chapter, held).figures if compare else []
		var mine_x := left + PAGE_WIDTH - (190.0 if compare else 0.0)
		text(Vector2(left, y), "記録", MINCHO_B, 16, _ink(INK))
		if compare:
			text(Vector2(mine_x - 170.0, y), "この技", MINCHO_B, 15, _ink(INK), HORIZONTAL_ALIGNMENT_RIGHT, 170.0)
			text(Vector2(left + PAGE_WIDTH - 180.0, y), "いまの「%s」" % build.name_of(held), MINCHO_M, 15, _ink(SEPIA), HORIZONTAL_ALIGNMENT_RIGHT, 180.0)
		draw_line(Vector2(left, y + 10.0), Vector2(left + PAGE_WIDTH, y + 10.0), _ink(INK, 0.8), 1.5)
		y += 44.0
		for index in figures.size():
			var figure: Array = figures[index]
			var name_width := MINCHO_M.get_string_size(figure[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
			var value_width := MINCHO_B.get_string_size(figure[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
			text(Vector2(left, y), figure[0], MINCHO_M, 19, _ink(SEPIA))
			text(Vector2(mine_x - value_width, y), figure[1], MINCHO_B, 21, _ink(INK))
			_leader(left + name_width + 10.0, mine_x - value_width - 10.0, y - 6.0, _ink(SEPIA, 0.6))
			if compare and index < now.size():
				var other: Array = now[index]
				var words: String = other[1] if other[0] == figure[0] else "%s %s" % [other[0], other[1]]
				text(Vector2(left + PAGE_WIDTH - 180.0, y), words, MINCHO_M, 17, _ink(SEPIA), HORIZONTAL_ALIGNMENT_RIGHT, 180.0)
			y += 40.0
	# The foot of the page: what pressing the seal would do.
	var foot := 778.0
	draw_line(Vector2(left, foot - 46.0), Vector2(left + PAGE_WIDTH, foot - 46.0), _ink(SEPIA, 0.5), 1.0)
	if told.can:
		var beat := 1.0 + 0.04 * sin(clock * 3.0)
		_wax(Vector2(left + 30.0, foot - 6.0), 24.0, _seal_letter(chapter), beat, modulate_ink)
		text(Vector2(left + 72.0, foot - 10.0), "Enter で封を押す", MINCHO_B, 20, _ink(INK))
		text(Vector2(left + 72.0, foot + 16.0), told.outcome, MINCHO_M, 16, _ink(RED))
		zone(Rect2(left, foot - 40.0, PAGE_WIDTH, 70.0), [&"seal"])
	elif entry.state == ProtoBuild.State.HERE:
		text(Vector2(left, foot), "この技の封が、すでに押されている", MINCHO_M, 17, _ink(SEPIA))
	elif told.unknown:
		text(Vector2(left, foot), "まだ封を押せない", MINCHO_M, 17, _ink(FAINT))
	else:
		text(Vector2(left, foot), "外すものがない", MINCHO_M, 17, _ink(FAINT))
	if since(&"refuse") < 0.35:
		draw_line(Vector2(left, foot + 26.0), Vector2(left + PAGE_WIDTH * (1.0 - since(&"refuse") / 0.35), foot + 26.0), _ink(RED, 0.7), 2.0)


func _paint_figures() -> void:
	var rows := build.stats()
	for group in 2:
		var left := LEFT if group == 0 else RIGHT_PAGE
		text(Vector2(left, 128.0), ORDINALS[STATS] if group == 0 else "ミオの記録", MINCHO_M, 16, _ink(SEPIA), HORIZONTAL_ALIGNMENT_CENTER, PAGE_WIDTH)
		text(Vector2(left, 176.0), ["戦う力", "探索と成長"][group], MINCHO_B, 38, _ink(INK), HORIZONTAL_ALIGNMENT_CENTER, PAGE_WIDTH)
		_rule(204.0, left, PAGE_WIDTH)
		var y := 262.0
		for entry: Array in rows:
			if entry[5] != group:
				continue
			var name_width := MINCHO_M.get_string_size(entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
			var right := left + PAGE_WIDTH
			var added: String = entry[2]
			if not added.is_empty():
				var added_width := MINCHO_M.get_string_size(added, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
				text(Vector2(right - added_width, y), added, MINCHO_M, 16, _ink(RED))
				right -= added_width + 8.0
			var value_width := MINCHO_B.get_string_size(entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x
			text(Vector2(left, y), entry[0], MINCHO_M, 21, _ink(INK))
			text(Vector2(right - value_width, y), entry[1], MINCHO_B, 23, _ink(INK))
			_leader(left + name_width + 10.0, right - value_width - 10.0, y - 6.0, _ink(SEPIA, 0.6))
			text(Vector2(left + 16.0, y + 24.0), entry[3], MINCHO_M, 14, _ink(BLUE, 0.9), HORIZONTAL_ALIGNMENT_LEFT, PAGE_WIDTH - 16.0)
			y += 70.0


func _paint_hints() -> void:
	var x := 150.0
	for pair: Array in hints():
		var width := maxf(28.0, GOTHIC_B.get_string_size(pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0)
		plate(Rect2(x, 862.0, width, 24.0), Color(PAPER, 0.12), Color(PAPER, 0.5), 3.0)
		text(Vector2(x, 879.0), pair[0], GOTHIC_B, 13, PAPER, HORIZONTAL_ALIGNMENT_CENTER, width)
		x += width + 8.0
		text(Vector2(x, 880.0), pair[1], MINCHO_M, 15, Color(PAPER, 0.75))
		x += MINCHO_M.get_string_size(pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 26.0
