class_name ProtoChart
extends ProtoScreen

# C, the expedition chart: a map inked on vellum, spread on the table before
# she leaves. A road winds from the base down through the four chapters,
# each a round view of its place; along each stretch of road stand a mark
# for every layer and a diamond for its boss, inked in as far as she has
# gone. The road to a sealed chapter is only dotted and its view is dark
# under the seal. A note pinned at the right tells the chosen chapter: what
# it is, its record and boss, the foes, what she carries, the step, and the
# one action.
# Left and right (or up and down) go along the road, Q and E change the
# step, Enter sets out.

const PAPER := Color(0.80, 0.72, 0.57)
const NOTE := Color(0.87, 0.80, 0.66)
const INK := Color(0.17, 0.12, 0.08)
const FADED := Color(0.40, 0.31, 0.22)
const RED := Color(0.58, 0.15, 0.10)
const GILT := Color(0.66, 0.44, 0.08)
const MAP := Rect2(48.0, 92.0, 968.0, 746.0)
const SHEET := Rect2(1052.0, 92.0, 500.0, 746.0)
const BASE := Vector2(150.0, 206.0)
const PLACES: Array[Vector2] = [Vector2(318.0, 330.0), Vector2(520.0, 560.0), Vector2(726.0, 306.0), Vector2(884.0, 612.0)]
const NODE := 66.0
const PAL := {
	dim = FADED, value = INK, accent = RED, warn = RED, under = Color(0.0, 0.0, 0.0, 0.0), rule = Color(0.17, 0.12, 0.08, 0.35),
	ground = NOTE, go = Color(0.50, 0.13, 0.09), go_edge = Color(0.30, 0.07, 0.05), go_text = Color(0.98, 0.92, 0.80),
	off = Color(0.74, 0.67, 0.54), off_text = Color(0.40, 0.31, 0.22),
}


func _init(of: ProtoExpedition) -> void:
	super(of)
	backdrop("shader_type canvas_item;\n" + NOISE + """
void fragment() {
	vec2 p = UV * vec2(1600.0, 900.0);
	// The table's dark wood round the vellum.
	float grain = fbm(p * vec2(0.002, 0.03));
	vec3 wood = mix(vec3(0.07, 0.045, 0.03), vec3(0.14, 0.09, 0.055), grain);
	vec2 inset = min(p - vec2(24.0, 70.0), vec2(1576.0, 862.0) - p);
	float on = smoothstep(0.0, 2.0, min(inset.x, inset.y) + 6.0 * (fbm(p * 0.02) - 0.5));
	float stain = fbm(p * 0.004 + 3.0);
	vec3 vellum = mix(vec3(0.70, 0.61, 0.46), vec3(0.84, 0.77, 0.62), stain);
	vellum *= 0.94 + 0.06 * noise(p * 0.9);
	vellum *= 1.0 - 0.25 * smoothstep(120.0, 0.0, min(inset.x, inset.y));
	COLOR = vec4(mix(wood, vellum, on), 1.0);
}
""")


func _key(action: StringName) -> void:
	match action:
		&"left", &"up":
			choose(chosen - 1)
		&"right", &"down":
			choose(chosen + 1)
		_:
			common_key(action)


func _wheel(step: int) -> void:
	choose(chosen + step)


func _paint() -> void:
	spaced(Vector2(72.0, 58.0), "出撃", MINCHO_B, 34, Color(0.93, 0.88, 0.78), 6.0)
	_map()
	for index in model.count():
		_road(index)
	_camp()
	for index in model.count():
		_place(index)
	_marker()
	_sheet()


# The chart's frame, its lines and its rose.
func _map() -> void:
	draw_rect(MAP, Color(INK, 0.75), false, 2.0)
	draw_rect(MAP.grow(-7.0), Color(INK, 0.35), false, 1.0)
	for index in range(1, 8):
		var x := MAP.position.x + MAP.size.x * index / 8.0
		draw_line(Vector2(x, MAP.position.y + 7.0), Vector2(x, MAP.end.y - 7.0), Color(INK, 0.07), 1.0)
	for index in range(1, 6):
		var y := MAP.position.y + MAP.size.y * index / 6.0
		draw_line(Vector2(MAP.position.x + 7.0, y), Vector2(MAP.end.x - 7.0, y), Color(INK, 0.07), 1.0)
	spaced(Vector2(MAP.end.x - 40.0 - 4.0 * 34.0, MAP.position.y + 54.0), "遠征図", MINCHO_B, 30, Color(INK, 0.8), 14.0)
	# The rose: north is the way back up.
	var rose := Vector2(MAP.position.x + 96.0, MAP.end.y - 96.0)
	ring(rose, 46.0, Color(INK, 0.5), 1.0)
	ring(rose, 40.0, Color(INK, 0.25), 1.0)
	for index in 8:
		var way := Vector2.from_angle(TAU * index / 8.0 - PI * 0.5)
		var side := way.orthogonal() * (7.0 if index % 2 == 0 else 4.0)
		var reach := 56.0 if index % 2 == 0 else 30.0
		draw_colored_polygon(PackedVector2Array([rose + way * reach, rose + side, rose - side]), Color(INK, 0.75 if index == 0 else 0.4))
	text(Vector2(rose.x - 30.0, rose.y - 62.0), "地上", GOTHIC, 13, FADED, HORIZONTAL_ALIGNMENT_CENTER, 60.0)
	text(Vector2(rose.x - 30.0, rose.y + 76.0), "深淵", GOTHIC, 13, FADED, HORIZONTAL_ALIGNMENT_CENTER, 60.0)


func _camp() -> void:
	draw_rect(Rect2(BASE - Vector2(13.0, 13.0), Vector2(26.0, 26.0)), NOTE)
	draw_rect(Rect2(BASE - Vector2(13.0, 13.0), Vector2(26.0, 26.0)), INK, false, 2.0)
	diamond(BASE, 6.0, INK)
	text(BASE + Vector2(-50.0, -24.0), "旅支度の間", GOTHIC, 14, FADED, HORIZONTAL_ALIGNMENT_CENTER, 100.0)


# The road into a chapter, bending a little, with its layers and its boss
# marked along it.
func _road(index: int) -> void:
	var start := BASE if index == 0 else PLACES[index - 1]
	var end := PLACES[index]
	var bend := (end - start).orthogonal().normalized() * (-34.0 if index == 1 else 34.0)
	var open := model.open(index)
	var points := PackedVector2Array()
	for part in 41:
		var share := part / 40.0
		points.append(start.lerp(end, share) + bend * sin(share * PI))
	if open:
		draw_polyline(points, Color(INK, 0.85), 2.5, true)
	else:
		for part in range(0, 40, 2):
			draw_line(points[part], points[part + 1], Color(INK, 0.4), 2.0, true)
	# The marks stand between the two views' edges.
	var layers := model.chapter(index).layers
	var reached := model.best(index)
	for mark in layers + 1:
		var share := lerpf(0.30 if index > 0 else 0.22, 0.70, float(mark) / layers)
		var at := start.lerp(end, share) + bend * sin(share * PI)
		var gone := reached > mark if mark < layers else model.cleared(index)
		var ink := Color(INK, 1.0 if open else 0.4)
		if mark < layers:
			draw_circle(at, 7.0, PAPER)
			if gone:
				draw_circle(at, 7.0, ink)
			else:
				ring(at, 7.0, ink, 1.5)
		else:
			diamond(at, 11.0, ink)
			diamond(at, 7.0, Color(RED if open else FADED, 1.0) if gone else PAPER)


func _place(index: int) -> void:
	var chapter := model.chapter(index)
	var open := model.open(index)
	var here := index == chosen
	var at := PLACES[index]
	var grown := moved() if here else (1.0 - moved() if index == from and from != chosen else 0.0)
	if here and from == chosen:
		grown = 1.0
	var radius := NODE + 14.0 * grown
	var lit := hovered(&"chapter", index) and not here
	var bright := (1.0 if here else (0.92 if lit else 0.80)) if open else 0.24
	draw_circle(at + Vector2(3.0, 5.0), radius + 5.0, Color(0.0, 0.0, 0.0, 0.25))
	draw_circle(at, radius + 5.0, INK)
	picture_round(at, radius, chapter.illustration, Color(bright, bright, bright), focus_of(index))
	ring(at, radius + 8.0, Color(INK, 0.5), 1.0)
	if grown > 0.0:
		ring(at, radius + 13.0, Color(GILT, grown), 3.0)
		for tick in 12:
			var way := Vector2.from_angle(TAU * tick / 12.0 + clock * 0.25)
			draw_line(at + way * (radius + 18.0), at + way * (radius + (28.0 if tick % 3 == 0 else 23.0)), Color(GILT, grown), 2.0, true)
	if not open:
		emblem(at, 30.0, "seal_chapter")
	# The setting out: a ring of ink running out from the place.
	if index == model.departed and departing() < 1.0:
		var out := departing()
		ring(at, radius + 20.0 + 150.0 * out, Color(RED, 1.0 - out), 4.0)
		draw_circle(at, radius, Color(1.0, 0.95, 0.85, 0.5 * (1.0 - out)))
	var y := at.y + radius + 34.0
	text(Vector2(at.x - 130.0, y), Chapters.short_name(chapter), GOTHIC, 14, RED if here else FADED, HORIZONTAL_ALIGNMENT_CENTER, 260.0)
	text(Vector2(at.x - 130.0, y + 28.0), Chapters.title(chapter), MINCHO_B, 24, INK if open else FADED, HORIZONTAL_ALIGNMENT_CENTER, 260.0)
	text(Vector2(at.x - 130.0, y + 50.0), model.state(index), MINCHO_M, 16, RED if not open else FADED, HORIZONTAL_ALIGNMENT_CENTER, 260.0)
	zone(Rect2(at - Vector2(radius + 10.0, radius + 10.0), Vector2(radius * 2.0 + 20.0, radius * 2.0 + 70.0)), [&"chapter", index])


# Her marker: a pin over the place she will set out for.
func _marker() -> void:
	var at := PLACES[from].lerp(PLACES[chosen], moved()) - Vector2(0.0, NODE + 40.0 + 3.0 * sin(clock * 2.4))
	draw_line(at, at + Vector2(0.0, 22.0), INK, 2.0, true)
	draw_circle(at, 10.0, INK)
	draw_circle(at, 7.0, RED)
	draw_circle(at + Vector2(-2.0, -2.0), 2.0, Color(1.0, 0.8, 0.7))


# The note pinned beside the chart.
func _sheet() -> void:
	draw_rect(Rect2(SHEET.position + Vector2(5.0, 7.0), SHEET.size), Color(0.0, 0.0, 0.0, 0.22))
	draw_rect(SHEET, NOTE)
	draw_rect(SHEET, Color(INK, 0.6), false, 1.5)
	draw_circle(Vector2(SHEET.get_center().x, SHEET.position.y + 16.0), 7.0, RED)
	draw_circle(Vector2(SHEET.get_center().x - 2.0, SHEET.position.y + 14.0), 2.0, Color(1.0, 0.8, 0.7))
	var x := SHEET.position.x + 34.0
	var wide := SHEET.size.x - 68.0
	var chapter := model.chapter(chosen)
	var open := model.open(chosen)
	var fade := 0.25 + 0.75 * moved()
	var y := SHEET.position.y + 62.0
	text(Vector2(x, y), Chapters.short_name(chapter), GOTHIC_B, 16, Color(RED, fade))
	text(Vector2(x, y), model.state(chosen), MINCHO_M, 18, Color(RED if not open else FADED, fade), HORIZONTAL_ALIGNMENT_RIGHT, wide)
	y += 48.0
	text(Vector2(x - 2.0, y), Chapters.title(chapter), MINCHO_B, 40, Color(INK, fade))
	y += 18.0
	draw_line(Vector2(x, y), Vector2(x + wide, y), Color(INK, 0.6), 1.5)
	draw_line(Vector2(x, y + 4.0), Vector2(x + wide, y + 4.0), Color(INK, 0.25), 1.0)
	y += 34.0
	y += paragraph(Vector2(x, y), model.description(chosen), GOTHIC, 17, Color(INK, fade), wide, 6.0, 3) + 6.0
	for fact: Array in [[tr("道のり"), model.route(chosen)], [tr("記録"), model.record(chosen)], [tr("ボス"), model.boss_name(chosen)]]:
		text(Vector2(x, y + 24.0), fact[0], GOTHIC, 15, FADED)
		text(Vector2(x + 96.0, y + 26.0), fact[1], MINCHO_B, 22, Color(INK, fade))
		draw_line(Vector2(x, y + 36.0), Vector2(x + wide, y + 36.0), Color(INK, 0.15), 1.0)
		y += 38.0
	y += 30.0
	text(Vector2(x, y), tr("現れる敵"), GOTHIC, 15, FADED)
	y += 12.0
	y += foe_tiles(Vector2(x, y), wide, 44.0, PAL) + 30.0
	text(Vector2(x, y), tr("装備", "gear"), GOTHIC, 15, FADED)
	gear_tiles(Vector2(x + 96.0, y - 28.0), 42.0)
	y += 30.0
	if model.steps_open() > 0:
		draw_line(Vector2(x, y), Vector2(x + wide, y), PAL.rule, 1.0)
		step_block(Vector2(x, y + 10.0), wide, PAL)
	go_button(Rect2(x, SHEET.end.y - 96.0, wide, 66.0), PAL)
