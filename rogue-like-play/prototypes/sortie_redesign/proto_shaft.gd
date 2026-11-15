class_name ProtoShaft
extends ProtoScreen

# A, the shaft: the dungeon cut open from its side. The chapters are strata
# laid one under another, the first at the top and the abyss at the foot;
# the chosen stratum opens wide on its painting while the others close to
# strips, and a gauge down the left tells how deep she stands. The column on
# the right is what she readies: the way, the record and the boss, the foes,
# what she carries, the step, and the one action.
# Up and down go from stratum to stratum, Q and E change the step, Enter
# sets out.

const ROCK := Color(0.055, 0.050, 0.048)
const STONE := Color(0.105, 0.098, 0.092)
const EDGE := Color(0.42, 0.36, 0.27)
const PALE := Color(0.93, 0.90, 0.83)
const DIM := Color(0.62, 0.58, 0.52)
const GOLD := Color(0.95, 0.76, 0.38)
const WARN := Color(0.88, 0.45, 0.36)
const LEFT := 104.0
const RIGHT := 1010.0
const TOP := 96.0
const FOOT := 822.0
const GAP := 10.0
const OPEN_HEIGHT := 396.0
const COLUMN := Rect2(1048.0, 96.0, 496.0, 726.0)
const PAL := {
	dim = DIM, value = PALE, accent = GOLD, warn = WARN, under = Color(1.0, 1.0, 1.0, 0.07), rule = Color(0.42, 0.36, 0.27, 0.5),
	ground = STONE, go = Color(0.42, 0.29, 0.10), go_edge = GOLD, go_text = Color(1.0, 0.94, 0.80),
	off = Color(0.13, 0.12, 0.115), off_text = Color(0.50, 0.47, 0.43),
}


func _init(of: ProtoExpedition) -> void:
	super(of)
	backdrop("shader_type canvas_item;\n" + NOISE + """
void fragment() {
	vec2 p = UV * vec2(1600.0, 900.0);
	float rock = fbm(p * vec2(0.004, 0.016));
	float seam = smoothstep(0.50, 0.54, fbm(p * vec2(0.0015, 0.03) + 7.0));
	vec3 colour = mix(vec3(0.030, 0.027, 0.026), vec3(0.085, 0.074, 0.066), rock);
	colour *= 1.0 - 0.35 * seam;
	colour *= 1.0 - 0.55 * smoothstep(0.35, 1.0, UV.y);
	COLOR = vec4(colour, 1.0);
}
""")


func _key(action: StringName) -> void:
	match action:
		&"up":
			choose(chosen - 1)
		&"down":
			choose(chosen + 1)
		_:
			common_key(action)


func _wheel(step: int) -> void:
	choose(chosen + step)


# How open a stratum is (0 a strip, 1 wide open).
func _open_share(index: int) -> float:
	var share := moved()
	if index == chosen:
		return share if from != chosen else 1.0
	return 1.0 - share if index == from else 0.0


func _paint() -> void:
	spaced(Vector2(LEFT, 62.0), "出撃", MINCHO_B, 34, PALE, 6.0)
	text(Vector2(LEFT + 110.0, 60.0), "どの深さへ下りるか", GOTHIC, 16, DIM)
	var closed := (FOOT - TOP - OPEN_HEIGHT - GAP * (model.count() - 1)) / (model.count() - 1)
	var y := TOP
	var marks: Array[float] = []
	for index in model.count():
		var share := _open_share(index)
		var height := lerpf(closed, OPEN_HEIGHT, share)
		_stratum(index, Rect2(LEFT, y, RIGHT - LEFT, height), share)
		marks.append(y + height * 0.5)
		y += height + GAP
	_gauge(marks)
	_column()


# The gauge down the shaft's side: a tick for every stratum, and a lantern
# at the one she stands in.
func _gauge(marks: Array[float]) -> void:
	var x := 62.0
	draw_line(Vector2(x, TOP), Vector2(x, FOOT), Color(EDGE, 0.7), 1.5)
	text(Vector2(x - 22.0, TOP - 12.0), "地上", GOTHIC, 13, DIM)
	text(Vector2(x - 22.0, FOOT + 24.0), "深淵", GOTHIC, 13, DIM)
	for index in marks.size():
		var at := Vector2(x, marks[index])
		draw_line(at - Vector2(8.0, 0.0), at + Vector2(8.0, 0.0), Color(EDGE, 0.9), 1.5)
		draw_line(at + Vector2(8.0, 0.0), Vector2(LEFT, marks[index]), Color(EDGE, 0.25), 1.0)
		if model.cleared(index):
			diamond(at, 5.0, GOLD)
	var lantern := Vector2(x, marks[chosen])
	glow(lantern, 34.0, Color(GOLD, 0.35))
	diamond(lantern, 10.0, GOLD)
	diamond(lantern, 5.0, Color(1.0, 0.97, 0.86))


func _stratum(index: int, rect: Rect2, share: float) -> void:
	var chapter := model.chapter(index)
	var open := model.open(index)
	var lit := hovered(&"chapter", index) and index != chosen
	var bright := lerpf(0.42 if open else 0.16, 1.0 if open else 0.30, share) + (0.12 if lit else 0.0)
	var leaving := 1.0 - departing() if index == model.departed else 0.0
	picture(rect, chapter.illustration, Color(bright, bright, bright), focus_of(index), 1.0 + 0.10 * leaving)
	# Words stand on a dark fall from the left and, when open wide, the foot.
	shade_across(Rect2(rect.position, Vector2(rect.size.x * 0.55, rect.size.y)), Color(0.0, 0.0, 0.0, 0.78), Color(0.0, 0.0, 0.0, 0.0))
	if share > 0.0:
		shade(Rect2(rect.position.x, rect.end.y - 170.0 * share, rect.size.x, 170.0 * share), Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.85 * share))
	draw_rect(rect, Color(EDGE, 0.55), false, 1.0)
	if index == chosen:
		draw_rect(rect.grow(2.0), Color(GOLD, 0.9), false, 2.0)
		draw_rect(rect.grow(-5.0), Color(GOLD, 0.30), false, 1.0)
	var name_size := int(lerpf(30.0, 54.0, share))
	var base := lerpf(rect.get_center().y + 12.0, rect.end.y - 92.0, share)
	var ink := PALE if open else DIM
	text(Vector2(rect.position.x + 34.0, base - name_size * 0.9 - 8.0), Chapters.short_name(chapter), GOTHIC, 16, GOLD if index == chosen else DIM)
	text(Vector2(rect.position.x + 32.0, base), Chapters.title(chapter), MINCHO_B, name_size, ink)
	# How far it has been taken, at the strip's right; under the name once open.
	var state := model.state(index)
	var state_colour := WARN if not open else (GOLD if model.cleared(index) else PALE)
	if share < 0.5:
		text(Vector2(rect.position.x, rect.get_center().y + 8.0), state, MINCHO_M, 20, Color(state_colour, 1.0 - share * 2.0), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 36.0 - (56.0 if not open else 0.0))
		if not open:
			emblem(Vector2(rect.end.x - 52.0, rect.get_center().y), 24.0, "seal_chapter", Color(1.0, 1.0, 1.0, 1.0 - share * 2.0))
	else:
		var fade := share * 2.0 - 1.0
		text(Vector2(rect.position.x + 34.0, base + 30.0), state, MINCHO_M, 20, Color(state_colour, fade))
		paragraph(Vector2(rect.position.x + 34.0, base + 62.0), model.description(index), GOTHIC, 18, Color(PALE if open else DIM, fade), rect.size.x - 120.0, 6.0, 2)
		if not open:
			emblem(rect.get_center() - Vector2(0.0, 50.0), 62.0 * fade, "seal_chapter", Color(1.0, 1.0, 1.0, fade))
	if leaving > 0.0:
		draw_rect(rect, Color(1.0, 0.95, 0.82, 0.55 * leaving))
		var line := rect.position.y + rect.size.y * (1.0 - leaving)
		draw_line(Vector2(rect.position.x, line), Vector2(rect.end.x, line), Color(GOLD, leaving), 3.0)
	zone(rect, [&"chapter", index])


# The column: what she readies for the chosen chapter.
func _column() -> void:
	plate(COLUMN, STONE, Color(EDGE, 0.8), 0.0, 1.0)
	draw_rect(COLUMN.grow(-6.0), Color(EDGE, 0.28), false, 1.0)
	var x := COLUMN.position.x + 34.0
	var wide := COLUMN.size.x - 68.0
	var fade := 0.3 + 0.7 * moved()
	var y := COLUMN.position.y + 46.0
	text(Vector2(x, y), "遠征の支度", GOTHIC, 15, DIM)
	y += 44.0
	text(Vector2(x, y), "%s　%s" % [Chapters.short_name(model.chapter(chosen)), Chapters.title(model.chapter(chosen))], MINCHO_B, 28, Color(PALE, fade))
	y += 22.0
	draw_line(Vector2(x, y), Vector2(x + wide, y), PAL.rule, 1.0)
	y += 12.0
	for fact: Array in [[tr("道のり"), model.route(chosen)], [tr("記録"), model.record(chosen)], [tr("ボス"), model.boss_name(chosen)]]:
		text(Vector2(x, y + 26.0), fact[0], GOTHIC, 15, DIM)
		text(Vector2(x + 96.0, y + 28.0), fact[1], MINCHO_B, 24, Color(PALE, fade))
		y += 40.0
	y += 14.0
	draw_line(Vector2(x, y), Vector2(x + wide, y), PAL.rule, 1.0)
	y += 28.0
	text(Vector2(x, y), tr("現れる敵"), GOTHIC, 15, DIM)
	y += 14.0
	y += foe_tiles(Vector2(x, y), wide, 46.0, PAL) + 30.0
	text(Vector2(x, y), tr("装備", "gear"), GOTHIC, 15, DIM)
	gear_tiles(Vector2(x + 96.0, y - 28.0), 44.0)
	y += 34.0
	if model.steps_open() > 0:
		draw_line(Vector2(x, y), Vector2(x + wide, y), PAL.rule, 1.0)
		step_block(Vector2(x, y + 14.0), wide, PAL)
	go_button(Rect2(x, COLUMN.end.y - 98.0, wide, 68.0), PAL)
