class_name ProtoMemory
extends ProtoScreen

# Prototype C, the altar of memories: a dark hall where what she has met is
# kept as shards of memory on a ring round a dais. The shard at the front of
# the ring is called up: the foe rises over the dais as an apparition, large,
# in a column of light, and what is remembered of it is cut in light beside
# it (its figures as rings filled by how strong it is among those met). Left
# and right turn the ring; the seal stones at the head of the hall are the
# kinds (Q/E), each with a point of light for every foe of the kind, lit for
# those met, so what is still missing shows at a glance. A foe not met is a
# sealed shard: its shade stands chained over the dais, nameless.

const HALL := """
shader_type canvas_item;
%s
void fragment() {
	vec2 p = UV * vec2(1600.0, 900.0);
	vec3 col = mix(vec3(0.030, 0.030, 0.062), vec3(0.070, 0.062, 0.130), fbm(p * 0.006));
	// The floor's slabs, seen at a slant, below the horizon of the hall.
	float floor_share = smoothstep(430.0, 900.0, p.y);
	vec2 slab = vec2((p.x - 560.0) / (0.4 + floor_share * 1.6), 3000.0 / max(p.y - 380.0, 1.0));
	float seam = smoothstep(0.0, 0.06, abs(fract(slab.x / 220.0) - 0.5)) * smoothstep(0.0, 0.08, abs(fract(slab.y * 0.5) - 0.5));
	col *= mix(1.0, mix(0.72, 1.0, seam), floor_share);
	// The dais' light, and mist drifting through it.
	vec2 dais = vec2(560.0, 650.0);
	float d = length((p - dais) / vec2(1.0, 0.42));
	col += vec3(0.42, 0.34, 0.85) * exp(-d / 330.0) * 0.36;
	float column = exp(-abs(p.x - dais.x) / 150.0) * smoothstep(dais.y + 30.0, 80.0, p.y);
	col += vec3(0.50, 0.42, 0.95) * column * 0.20;
	float mist = fbm(vec2(p.x * 0.004 + TIME * 0.02, p.y * 0.008 - TIME * 0.012));
	col += vec3(0.30, 0.26, 0.55) * mist * 0.16 * smoothstep(250.0, 800.0, p.y);
	col *= smoothstep(1.35, 0.25, length((UV - vec2(0.42, 0.52)) * vec2(1.15, 1.5)));
	COLOR = vec4(col, 1.0);
}
""" % NOISE

const PALE := Color("ece9fa")
const DIM := Color("9a94bd")
const FAINT := Color("56527a")
const LIGHT := Color("b9a6ff")
const LIGHT_DEEP := Color("6a54c8")
const EMBER := Color("ffcf8a")
const SHADE := Color(0.035, 0.03, 0.08, 0.92)
const DAIS := Vector2(560.0, 650.0)
const RING := Vector2(500.0, 118.0)
const STEP := 0.235
const STAGE := Rect2(290.0, 150.0, 540.0, 486.0)
const WORDS_LEFT := 990.0
const WORDS_WIDTH := 540.0

var kind := 0
var place := 0
var listed: Array[FoeData] = []
var _spin := 0.0


func _init(of: ProtoCodex) -> void:
	super(of)
	backdrop(HALL)
	listed = codex.foes(kind)


func title() -> String:
	return "C　追憶の祭壇"


func hints() -> Array:
	return [["← →", "記憶を巡る"], ["Q / E", "分類"], ["Esc", "戻る"]]


func _go(to: int) -> void:
	to = clampi(to, 0, listed.size() - 1)
	if to == place:
		return
	place = to
	kick(&"call")


func _turn(to: int) -> void:
	to = clampi(to, 0, 3)
	if to == kind:
		return
	kind = to
	listed = codex.foes(kind)
	place = 0
	_spin = 0.0
	kick(&"call")
	kick(&"kind")


func _key(action: StringName) -> void:
	match action:
		&"left":
			_go(place - 1)
		&"right":
			_go(place + 1)
		&"prev", &"up":
			_turn(kind - 1)
		&"next", &"down":
			_turn(kind + 1)


func _click(id: Variant) -> void:
	var what: Array = id
	match what[0]:
		&"stone":
			_turn(what[1])
		&"shard":
			_go(what[1])


func _wheel(step: int) -> void:
	_go(place + step)


func pose(state: StringName) -> void:
	kind = 0
	listed = codex.foes(kind)
	place = 0
	match state:
		&"browse":
			place = 5
		&"category":
			kind = 2
			listed = codex.foes(kind)
			place = 1
		&"unknown":
			place = 7
		&"detail":
			kind = 3
			listed = codex.foes(kind)
			place = 1
	_spin = place
	_kicks.clear()


func _process(delta: float) -> void:
	_spin = lerpf(_spin, float(place), minf(1.0, delta * 10.0))
	super(delta)


# --- Drawing ---

func _paint() -> void:
	spaced(Vector2(56.0, 66.0), "追憶の祭壇", MINCHO_B, 28, PALE, 10.0)
	_paint_stones()
	_paint_dais()
	_paint_ring(false)
	_paint_apparition(listed[place])
	_paint_ring(true)
	_paint_words(listed[place])
	var x := 56.0
	for pair: Array in hints():
		var width := maxf(28.0, GOTHIC_B.get_string_size(pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0)
		plate(Rect2(x, 866.0, width, 22.0), Color(0.0, 0.0, 0.0, 0.4), Color(DIM, 0.7), 3.0)
		text(Vector2(x, 882.0), pair[0], GOTHIC_B, 13, PALE, HORIZONTAL_ALIGNMENT_CENTER, width)
		x += width + 8.0
		text(Vector2(x, 883.0), pair[1], MINCHO_M, 15, DIM)
		x += MINCHO_M.get_string_size(pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 24.0


func _ellipse(centre: Vector2, radii: Vector2, colour: Color, width := 1.0, from := 0.0, to := TAU) -> void:
	var points := PackedVector2Array()
	for step in 97:
		var angle := lerpf(from, to, step / 96.0)
		points.append(centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_polyline(points, colour, width, true)


# The seal stones: the kinds, a point of light for every foe of each.
func _paint_stones() -> void:
	for index in 4:
		var here := index == kind
		var rect := Rect2(330.0 + 172.0 * index, 28.0, 160.0, 74.0)
		var listed_here := codex.foes(index)
		zone(rect, [&"stone", index])
		plate(rect, Color(LIGHT_DEEP, 0.28) if here else Color(0.0, 0.0, 0.0, 0.35 if not hovered(&"stone", index) else 0.2), Color(LIGHT, 0.95) if here else Color(FAINT, 0.9), 4.0, 2.0 if here else 1.0)
		text(Vector2(rect.position.x + 12.0, rect.position.y + 27.0), FoeCatalog.KINDS[index], MINCHO_B, 18, PALE if here else DIM)
		var tally := codex.tally(index)
		text(Vector2(rect.position.x, rect.position.y + 27.0), "%d / %d" % tally, MINCHO_M, 14, LIGHT if here else FAINT, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 12.0)
		# One point for each foe: lit when met.
		var per_row := 17
		for at in listed_here.size():
			var dot := Vector2(rect.position.x + 14.0 + 8.2 * (at % per_row), rect.position.y + 46.0 + 12.0 * (at / per_row))
			if codex.known(listed_here[at]):
				draw_circle(dot, 3.0, LIGHT if here else Color(LIGHT, 0.6))
			else:
				ring(dot, 2.4, Color(FAINT, 0.9), 1.0)


func _paint_dais() -> void:
	var pulse := since(&"call")
	for band in 3:
		_ellipse(DAIS, Vector2(300.0 - 46.0 * band, 72.0 - 11.0 * band), Color(LIGHT, 0.5 - 0.12 * band), 2.0 if band == 0 else 1.0)
	for tick in 24:
		var angle := TAU * tick / 24.0 + clock * 0.05
		var out := Vector2(cos(angle) * 300.0, sin(angle) * 72.0)
		draw_line(DAIS + out * 0.93, DAIS + out, Color(LIGHT, 0.6), 1.5, true)
	if pulse < 0.7:
		var spread := pulse / 0.7
		_ellipse(DAIS, Vector2(300.0, 72.0) * (0.3 + 1.1 * spread), Color(PALE, 0.9 * (1.0 - spread)), 3.0)


# The ring of shards: the back half first, the front half over the apparition.
func _paint_ring(front: bool) -> void:
	for index in listed.size():
		var offset := index - _spin
		var angle := PI * 0.5 - offset * STEP
		if absf(offset) * STEP > PI:
			continue
		var depth := sin(angle)
		# Only the near half of the ring is shown: the far shards are lost in the dark.
		if depth < 0.12 or not front:
			continue
		var centre := DAIS + Vector2(cos(angle) * RING.x, sin(angle) * RING.y + 36.0)
		var scale := 0.55 + 0.45 * (depth * 0.5 + 0.5)
		var near := clampf(1.0 - absf(offset) * STEP / PI, 0.0, 1.0)
		var alpha := (0.25 + 0.75 * near) * (1.0 if front else 0.45)
		var here := index == place
		var radius := 30.0 * scale * (1.35 if here else 1.0)
		var foe := listed[index]
		var known := codex.known(foe)
		zone_round(centre, radius + 8.0, [&"shard", index])
		if here:
			glow(centre, radius * 2.8, Color(LIGHT, 0.45))
		elif hovered(&"shard", index):
			glow(centre, radius * 2.2, Color(LIGHT, 0.2))
		# A shard: a lozenge of crystal holding the foe's face.
		var lozenge := PackedVector2Array([centre + Vector2(0.0, -radius * 1.55), centre + Vector2(radius * 1.15, 0.0), centre + Vector2(0.0, radius * 1.55), centre + Vector2(-radius * 1.15, 0.0)])
		draw_colored_polygon(lozenge, Color(0.10, 0.09, 0.2, 0.92 * alpha) if known else Color(0.03, 0.03, 0.06, 0.92 * alpha))
		icon(centre, radius * 0.86, foe, alpha if known else alpha * 0.8)
		var loop := lozenge.duplicate()
		loop.append(lozenge[0])
		draw_polyline(loop, Color(PALE if here else (LIGHT if known else FAINT), alpha), 2.5 if here else 1.2, true)
		if not known:
			# Sealed: a band across the shard.
			draw_line(centre + Vector2(-radius * 0.9, radius * 0.5), centre + Vector2(radius * 0.9, -radius * 0.5), Color(FAINT, alpha), 2.0, true)


# The foe called up over the dais.
func _paint_apparition(foe: FoeData) -> void:
	var known := codex.known(foe)
	var rise := eased(&"call", 0.35)
	var bob := sin(clock * 1.4) * 4.0
	var rect := Rect2(STAGE.position + Vector2(0.0, 18.0 * (1.0 - rise) + bob), STAGE.size)
	glow(Vector2(DAIS.x, DAIS.y - 220.0), 330.0, Color(LIGHT, 0.10 * rise))
	if known:
		# A rim of light: the figure once more, larger and faint, behind it.
		var halo := rect.grow(10.0)
		var picture := codex.portrait(foe)
		var fit := minf(halo.size.x / picture.get_width(), halo.size.y / picture.get_height())
		var held := Vector2(picture.get_width(), picture.get_height()) * fit
		draw_texture_rect(picture, Rect2(halo.position.x + (halo.size.x - held.x) * 0.5, halo.end.y - held.y, held.x, held.y), false, Color(LIGHT.r, LIGHT.g, LIGHT.b, 0.28 * rise))
	var at := figure(rect, foe, SHADE, rise)
	if not known:
		# Chained: the memory is not hers yet.
		for chain in 2:
			var from := Vector2(at.position.x - 30.0, at.position.y + at.size.y * (0.2 if chain == 0 else 0.85))
			var to := Vector2(at.end.x + 30.0, at.position.y + at.size.y * (0.85 if chain == 0 else 0.2))
			draw_line(from, to, Color(FAINT, 0.9 * rise), 5.0, true)
			for link in 14:
				var point := from.lerp(to, (link + 0.5) / 14.0)
				ring(point, 7.0, Color(DIM, 0.9 * rise), 2.0)
		var seal := at.get_center()
		draw_circle(seal, 34.0, Color(0.03, 0.03, 0.07, 0.95 * rise))
		ring(seal, 34.0, Color(LIGHT, rise), 2.0)
		text(Vector2(seal.x - 34.0, seal.y + 13.0), "封", MINCHO_B, 34, Color(PALE, rise), HORIZONTAL_ALIGNMENT_CENTER, 68.0)


# A figure as a ring filled by how strong it is among those met.
func _gauge(centre: Vector2, label: String, value: int, share: float, known: bool) -> void:
	var radius := 46.0
	ring(centre, radius, Color(FAINT, 0.9), 2.0)
	if known:
		ring(centre, radius, LIGHT, 4.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(share, 0.02, 1.0) * eased(&"call", 0.5))
		var words := str(value)
		text(Vector2(centre.x - radius, centre.y + 10.0), words, MINCHO_B, 28 if words.length() < 4 else 22, PALE, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0)
	else:
		for step in 18:
			ring(centre, radius - 8.0, Color(FAINT, 0.8), 1.2, TAU * step / 18.0, TAU * (step + 0.5) / 18.0)
		text(Vector2(centre.x - radius, centre.y + 10.0), "？", MINCHO_B, 26, FAINT, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0)
	text(Vector2(centre.x - 80.0, centre.y + radius + 28.0), label, MINCHO_M, 16, DIM, HORIZONTAL_ALIGNMENT_CENTER, 160.0)


# What is remembered of it, cut in light beside the dais.
func _paint_words(foe: FoeData) -> void:
	var known := codex.known(foe)
	var fade := eased(&"call", 0.4)
	var left := WORDS_LEFT + 14.0 * (1.0 - fade)
	shade_across(Rect2(WORDS_LEFT - 60.0, 130.0, WORDS_WIDTH + 130.0, 700.0), Color(0.0, 0.0, 0.0, 0.0), Color(0.01, 0.01, 0.03, 0.55))
	draw_line(Vector2(WORDS_LEFT - 26.0, 160.0), Vector2(WORDS_LEFT - 26.0, 790.0), Color(LIGHT, 0.35), 1.0)
	text(Vector2(left, 178.0), "記憶 %02d　%s" % [codex.number(foe), codex.kind_name(foe)], MINCHO_M, 17, Color(LIGHT, fade))
	text(Vector2(left, 246.0), codex.name_of(foe), MINCHO_B, 54, Color(PALE if known else FAINT, fade), HORIZONTAL_ALIGNMENT_LEFT, WORDS_WIDTH)
	var epithet := codex.epithet(foe)
	if not epithet.is_empty():
		text(Vector2(left, 284.0), epithet, MINCHO_M, 19, Color(EMBER, fade))
	elif not known:
		text(Vector2(left, 284.0), "封じられた記憶", MINCHO_M, 19, Color(DIM, fade))
	draw_line(Vector2(left, 306.0), Vector2(left + WORDS_WIDTH, 306.0), Color(PALE, 0.16), 1.0)
	draw_line(Vector2(left, 306.0), Vector2(left + 70.0, 306.0), LIGHT, 2.0)
	var stats := codex.stats(foe)
	var names := [["hp", "HP"], ["contact", "ぶつかる力"], ["speed", "速さ"]]
	for index in 3:
		var centre := Vector2(left + 80.0 + 190.0 * index, 388.0)
		if known:
			var stat: Array = stats[index]
			_gauge(centre, stat[1], stat[2], sqrt(float(stat[2]) / codex.most(stat[0])), true)
		else:
			_gauge(centre, names[index][1], 0, 0.0, false)
	var notes := codex.account(foe)
	var y := 520.0
	y += paragraph(Vector2(left, y), notes[0], MINCHO_M, 20, Color(PALE if known else DIM, 0.92 * fade), WORDS_WIDTH, 24.0, 6)
	if not notes[1].is_empty():
		text(Vector2(left, y + 6.0), "現れる所", MINCHO_B, 16, Color(LIGHT, fade))
		paragraph(Vector2(left + 86.0, y + 6.0), notes[1], MINCHO_M, 18, Color(DIM, fade), WORDS_WIDTH - 86.0, 10.0, 2)
