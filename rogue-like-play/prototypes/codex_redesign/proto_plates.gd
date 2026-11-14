class_name ProtoPlates
extends ProtoScreen

# Prototype B, the naturalist's plates: one foe to a plate, as a folio of
# natural history gives one creature to a sheet. The foe stands large on the
# plate, and what is known of it is written round it as a naturalist's notes:
# marks set on the figure, each led by a line to its note in the margin (its
# figures), and beside them the account of how it behaves and where it is
# found. Left and right turn to the next plate; the tray under the folio
# holds every plate of the kind as a small specimen, so any can be reached
# at once, and the ribbons at the folio's head are the kinds (Q/E). A foe not
# met is a plate not yet drawn: its shape washed in sepia, no name, no notes.

const DESK := """
shader_type canvas_item;
uniform sampler2D grain : filter_linear_mipmap, repeat_disable;
%s
float box(vec2 p, vec2 a, vec2 b) {
	vec2 d = max(a - p, p - b);
	return max(d.x, d.y);
}
void fragment() {
	vec2 p = UV * vec2(1600.0, 900.0);
	float wood = fbm(vec2(p.x * 0.004, p.y * 0.07)) * 0.6 + fbm(p * 0.02) * 0.4;
	vec3 col = mix(vec3(0.055, 0.040, 0.032), vec3(0.135, 0.095, 0.066), wood);
	float lamp = exp(-length((p - vec2(300.0, 20.0)) / vec2(1100.0, 800.0)) * 1.9);
	col += vec3(1.0, 0.7, 0.4) * lamp * 0.16;
	col *= smoothstep(1.3, 0.3, length((UV - 0.5) * vec2(1.2, 1.5)));
	vec2 from = vec2(110.0, 34.0);
	vec2 to = vec2(1490.0, 756.0);
	float sheet = box(p, from, to);
	float tone = texture(grain, clamp((p - from) / (to - from), 0.0, 1.0)).r;
	col *= mix(0.4, 1.0, smoothstep(0.0, 40.0, sheet));
	if (sheet < 0.0) {
		vec3 paper = mix(vec3(0.83, 0.76, 0.61), vec3(0.95, 0.90, 0.79), tone);
		paper *= 0.88 + 0.12 * smoothstep(0.0, 90.0, -sheet);
		col = paper;
	}
	COLOR = vec4(col, 1.0);
}
""" % NOISE

const INK := Color("2a2018")
const SEPIA := Color("634a32")
const FAINT := Color("93805f")
const RED := Color("8d2318")
const WASH := Color(0.36, 0.27, 0.17, 0.55)
const TRAY := Color("241811")
const RIBBONS := [Color("6b5238"), Color("48603a"), Color("38507a"), Color("8d2318")]
const SHEET := Rect2(110.0, 34.0, 1380.0, 722.0)
const STAGE := Rect2(170.0, 210.0, 640.0, 470.0)
const NOTES_LEFT := 880.0
const NOTES_WIDTH := 540.0
const TRAY_Y := 826.0
const SPECIMEN := 26.0
const SPECIMEN_STEP := 74.0

var kind := 0
var place := 0
var listed: Array[FoeData] = []
var _slide := 0.0


func _init(of: ProtoCodex) -> void:
	super(of)
	backdrop(DESK, {"grain": load("res://art/ui/grimoire/paper.png")})
	listed = codex.foes(kind)


func title() -> String:
	return "B　魔物図譜"


func hints() -> Array:
	return [["← →", "図版をめくる"], ["Q / E", "分類"], ["Esc", "戻る"]]


func _go(to: int) -> void:
	to = clampi(to, 0, listed.size() - 1)
	if to == place:
		return
	_kicks[&"way"] = 1.0 if to > place else -1.0
	place = to
	kick(&"turn")


func _turn(to: int) -> void:
	to = clampi(to, 0, 3)
	if to == kind:
		return
	kind = to
	listed = codex.foes(kind)
	place = 0
	_kicks[&"way"] = 0.0
	kick(&"turn")
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
		&"ribbon":
			_turn(what[1])
		&"specimen":
			_go(what[1])
		&"step":
			_go(place + int(what[1]))


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
	_kicks.clear()
	_slide = place


func _process(delta: float) -> void:
	_slide = lerpf(_slide, float(place), minf(1.0, delta * 12.0))
	super(delta)


# --- Drawing ---

func _paint() -> void:
	_paint_ribbons()
	# The plate's ruled border.
	var border := SHEET.grow(-18.0)
	draw_rect(border, Color(SEPIA, 0.7), false, 1.0)
	draw_rect(border.grow(-5.0), Color(SEPIA, 0.35), false, 1.0)
	var fade := eased(&"turn", 0.26)
	var way := float(_kicks.get(&"way", 0.0)) if since(&"turn") < 0.3 else 0.0
	draw_set_transform(Vector2(26.0 * way * (1.0 - fade), 0.0))
	_alpha = fade
	_paint_plate(listed[place])
	_alpha = 1.0
	draw_set_transform(Vector2.ZERO)
	_paint_steps()
	_paint_tray()


var _alpha := 1.0


func _ink(colour: Color, share := 1.0) -> Color:
	return Color(colour, colour.a * share * _alpha)


func _paint_ribbons() -> void:
	for index in 4:
		var here := index == kind
		var tall := 92.0 if here else 64.0
		var rect := Rect2(1010.0 + 108.0 * index, 22.0, 96.0, tall)
		var colour: Color = RIBBONS[index]
		if hovered(&"ribbon", index) and not here:
			colour = colour.lightened(0.15)
		draw_rect(Rect2(rect.position + Vector2(2.0, 3.0), rect.size), Color(0.0, 0.0, 0.0, 0.3))
		draw_colored_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.get_center().x, rect.end.y - 14.0), Vector2(rect.position.x, rect.end.y)]), colour if here else colour.darkened(0.25))
		var tally := codex.tally(index)
		text(Vector2(rect.position.x, rect.position.y + 30.0), FoeCatalog.KINDS[index], MINCHO_B, 17, Color("f3e9d2"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
		text(Vector2(rect.position.x, rect.position.y + 52.0), "%d / %d" % tally, MINCHO_M, 14, Color("f3e9d2", 0.85), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
		zone(rect, [&"ribbon", index])


# One foe's plate: its figure with marks led to notes, and its account.
func _paint_plate(foe: FoeData) -> void:
	var known := codex.known(foe)
	text(Vector2(176.0, 96.0), "図版　第 %02d" % codex.number(foe), MINCHO_M, 17, _ink(SEPIA))
	text(Vector2(176.0, 96.0), "%sの類" % codex.kind_name(foe), MINCHO_M, 17, _ink(SEPIA), HORIZONTAL_ALIGNMENT_RIGHT, 640.0)
	text(Vector2(176.0, 158.0), codex.name_of(foe), MINCHO_B, 52, _ink(INK if known else FAINT), HORIZONTAL_ALIGNMENT_LEFT, 640.0)
	var epithet := codex.epithet(foe)
	if not epithet.is_empty():
		text(Vector2(180.0, 192.0), "— %s" % epithet, MINCHO_M, 18, _ink(RED))
	draw_line(Vector2(176.0, 204.0), Vector2(816.0, 204.0), _ink(SEPIA, 0.6), 1.0)
	# The ground it stands on, hatched as an engraver shades it.
	var ground := Vector2(STAGE.get_center().x, STAGE.end.y - 6.0)
	for stroke in 34:
		var x := ground.x - 250.0 + 500.0 * stroke / 33.0
		var reach := 1.0 - absf(x - ground.x) / 250.0
		draw_line(Vector2(x, ground.y + 2.0), Vector2(x - 16.0, ground.y + 2.0 + 20.0 * sqrt(reach)), _ink(SEPIA, 0.45 * reach), 1.0, true)
	var at := figure(STAGE, foe, WASH, _alpha)
	var left := NOTES_LEFT
	var y := 158.0
	if known:
		# Marks on the figure, each led to its note in the margin.
		var stats := codex.stats(foe)
		var marks := [Vector2(at.position.x + at.size.x * 0.62, at.position.y + at.size.y * 0.2), Vector2(at.end.x - at.size.x * 0.14, at.position.y + at.size.y * 0.52), Vector2(at.position.x + at.size.x * 0.56, at.end.y - at.size.y * 0.1)]
		text(Vector2(left, y), "記", MINCHO_B, 17, _ink(INK))
		draw_line(Vector2(left, y + 10.0), Vector2(left + NOTES_WIDTH, y + 10.0), _ink(INK, 0.8), 1.5)
		y += 48.0
		for index in stats.size():
			var stat: Array = stats[index]
			var letter := "abc"[index]
			var note := Vector2(left, y - 7.0)
			var mark: Vector2 = marks[index]
			var bend := Vector2(left - 26.0, note.y)
			draw_polyline(PackedVector2Array([mark, bend, note + Vector2(-6.0, 0.0)]), _ink(SEPIA, 0.8), 1.0, true)
			draw_circle(mark, 9.0, _ink(Color("f1e6cc")))
			ring(mark, 9.0, _ink(INK), 1.2)
			text(Vector2(mark.x - 9.0, mark.y + 5.0), letter, MINCHO_B, 14, _ink(INK), HORIZONTAL_ALIGNMENT_CENTER, 18.0)
			text(Vector2(left, y), "%s." % letter, MINCHO_B, 17, _ink(RED))
			text(Vector2(left + 28.0, y), stat[1], MINCHO_M, 20, _ink(SEPIA))
			var value := str(stat[2])
			var value_width := MINCHO_B.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			text(Vector2(left + NOTES_WIDTH - value_width, y + 2.0), value, MINCHO_B, 30, _ink(INK))
			# A measure: ticks up to the strongest met, filled to this one.
			var from := left + 150.0
			var span := NOTES_WIDTH - 150.0 - value_width - 24.0
			var share := sqrt(float(stat[2]) / codex.most(stat[0]))
			draw_line(Vector2(from, y - 6.0), Vector2(from + span, y - 6.0), _ink(SEPIA, 0.5), 1.0)
			for tick in 11:
				var x := from + span * tick / 10.0
				draw_line(Vector2(x, y - 6.0), Vector2(x, y - (14.0 if tick % 5 == 0 else 10.0)), _ink(SEPIA, 0.6), 1.0)
			draw_line(Vector2(from, y - 6.0), Vector2(from + span * share, y - 6.0), _ink(RED), 3.0)
			y += 52.0
		y += 8.0
	else:
		text(Vector2(STAGE.position.x, STAGE.get_center().y + 10.0), "いまだ観察されず", MINCHO_B, 30, _ink(Color("f1e6cc")), HORIZONTAL_ALIGNMENT_CENTER, STAGE.size.x)
		y = 158.0
	var notes := codex.account(foe)
	text(Vector2(left, y), "観察記" if known else "覚え書き", MINCHO_B, 17, _ink(INK))
	draw_line(Vector2(left, y + 10.0), Vector2(left + NOTES_WIDTH, y + 10.0), _ink(INK, 0.8), 1.5)
	y += 46.0
	y += paragraph(Vector2(left, y), notes[0], MINCHO_M, 20, _ink(INK if known else SEPIA), NOTES_WIDTH, 22.0, 7)
	if not notes[1].is_empty():
		text(Vector2(left, y + 6.0), "棲息", MINCHO_B, 17, _ink(RED))
		paragraph(Vector2(left + 52.0, y + 6.0), notes[1], MINCHO_M, 18, _ink(SEPIA), NOTES_WIDTH - 52.0, 10.0, 2)


# The plate's turning marks at its two edges.
func _paint_steps() -> void:
	for side: int in [-1, 1]:
		var able: bool = (side < 0 and place > 0) or (side > 0 and place < listed.size() - 1)
		var centre := Vector2(SHEET.position.x - 34.0 if side < 0 else SHEET.end.x + 34.0, SHEET.get_center().y)
		var colour := Color("f3e9d2", 0.85 if able else 0.2)
		if able and hovered(&"step", side):
			colour.a = 1.0
		draw_colored_polygon(PackedVector2Array([centre + Vector2(12.0 * side, 0.0), centre + Vector2(-8.0 * side, -18.0), centre + Vector2(-8.0 * side, 18.0)]), colour)
		if able:
			zone(Rect2(centre - Vector2(30.0, 50.0), Vector2(60.0, 100.0)), [&"step", side])


# The tray of specimens under the folio: every plate of the kind, the open
# one lifted on its pin.
func _paint_tray() -> void:
	var rect := Rect2(110.0, TRAY_Y - 50.0, 1380.0, 98.0)
	draw_rect(Rect2(rect.position + Vector2(0.0, 5.0), rect.size), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(rect, TRAY)
	draw_rect(rect, Color("5a4030"), false, 2.0)
	var tally := codex.tally(kind)
	text(Vector2(rect.position.x + 20.0, TRAY_Y - 6.0), FoeCatalog.KINDS[kind], MINCHO_B, 20, Color("f3e9d2"))
	text(Vector2(rect.position.x + 20.0, TRAY_Y + 22.0), "%d / %d を観察" % tally, MINCHO_M, 14, Color("f3e9d2", 0.7))
	var from := rect.position.x + 200.0
	var room := rect.end.x - 40.0 - from
	var shown := int(room / SPECIMEN_STEP)
	var first := clampf(_slide - shown * 0.5 + 0.5, 0.0, maxf(0.0, listed.size() - shown))
	for index in listed.size():
		var x := from + SPECIMEN_STEP * (index - first) + SPECIMEN_STEP * 0.5
		if x < from - 4.0 or x > rect.end.x - 36.0:
			continue
		var here := index == place
		var foe := listed[index]
		var centre := Vector2(x, TRAY_Y + 4.0 - (10.0 * eased(&"turn", 0.2) if here else 0.0))
		zone_round(centre, SPECIMEN + 8.0, [&"specimen", index])
		if here:
			glow(centre, SPECIMEN * 2.4, Color(1.0, 0.85, 0.6, 0.3))
			draw_line(centre + Vector2(0.0, SPECIMEN), Vector2(centre.x, rect.end.y - 8.0), Color("f3e9d2", 0.8), 1.5)
		elif hovered(&"specimen", index):
			glow(centre, SPECIMEN * 2.0, Color(1.0, 0.85, 0.6, 0.14))
		draw_circle(centre, SPECIMEN + 3.0, Color("f1e6cc") if codex.known(foe) else Color("57493a"))
		icon(centre, SPECIMEN, foe)
		ring(centre, SPECIMEN + 3.0, RED if here else Color("8a7458"), 3.0 if here else 1.5)
		text(Vector2(centre.x - 30.0, rect.end.y - 6.0), "%02d" % codex.number(foe), MINCHO_M, 12, Color("f3e9d2", 0.95 if here else 0.5), HORIZONTAL_ALIGNMENT_CENTER, 60.0)
	text(Vector2(124.0, 894.0), "← → 図版をめくる　　Q / E 分類　　Esc 戻る", GOTHIC, 13, Color("f3e9d2", 0.6))
