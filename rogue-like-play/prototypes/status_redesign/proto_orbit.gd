class_name ProtoOrbit
extends ProtoScreen

# A, the orbits: her own constellation. She is the pole, her face in a ring
# of light at the middle of the sky, and her four slots are four stars
# joined to her: the attack, the two skills, the special move. The star of
# the open slot is ringed by the things it can hold, small stars on an arc
# on its far side, each joined to it by a line: gold for what it holds now,
# blue for what could be set, a dark shape for what is not learned. A fifth
# star under her opens her figures. The card at the right tells the one
# under the cursor.
# Left and right go from slot to slot round her, up and down along the arc,
# Enter sets, X empties, R opens her figures.

const POLE := Vector2(548.0, 462.0)
const REACH := 196.0
const SLOT_STAR := 40.0
const ARC := 128.0
const SMALL := 21.0
# The way from her to each slot's star: the attack at her left, the skills
# over her shoulders, the special move at her right.
const WAYS: Array[float] = [PI, -PI * 0.70, -PI * 0.30, 0.0]
const FIGURES_AT := Vector2(548.0, 730.0)


func _key(action: StringName) -> void:
	match action:
		&"left":
			slot_to(model.slot - 1)
		&"right":
			slot_to(model.slot + 1)
		&"up":
			row_to(model.row - 1)
		&"down":
			row_to(model.row + 1)
		_:
			common_key(action)


func _wheel(by: int) -> void:
	row_to(model.row + by)


func _spot(index: int) -> Vector2:
	return POLE + Vector2.from_angle(WAYS[index]) * REACH * Vector2(1.25, 1.0)


func _paint() -> void:
	title("ステータス")
	# The rings she stands in, and the lines to her slots.
	ring(POLE, REACH, Color(BRASS, 0.14), 1.0)
	ring(POLE, REACH + ARC, Color(BRASS, 0.08), 1.0)
	for index in ProtoStatus.SLOT_COUNT:
		var open := index == model.slot and not model.figures_open
		draw_line(POLE, _spot(index), Color(GOLD, 0.8 if open else 0.3), 2.0 if open else 1.0, true)
	draw_dashed_line(POLE, FIGURES_AT, Color(BRASS, 0.5), 1.0, 6.0)
	# She, at the pole.
	glow(POLE, 150.0, Color(1.0, 0.82, 0.5, 0.20))
	draw_circle(POLE, 66.0, VOID)
	var full := HERO.get_size()
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for step in 64:
		var turn := Vector2.from_angle(TAU * step / 64.0)
		points.append(POLE + turn * 62.0)
		uvs.append(HubLobby.FACE + Vector2(0.01, 0.01) + turn * Vector2(0.105, 0.105 * full.x / full.y))
	draw_polygon(points, PackedColorArray([Color(0.95, 0.93, 0.92)]), uvs, HERO)
	ring(POLE, 64.0, GOLD, 2.0)
	rays(POLE, 64.0, Color(GOLD, 0.8))
	if model.figures_open:
		for index in ProtoStatus.SLOT_COUNT:
			_slot_star(index)
		_figures_star()
		figures(Rect2(880.0, 110.0, 664.0, 700.0))
	else:
		_arc()
		for index in ProtoStatus.SLOT_COUNT:
			_slot_star(index)
		_figures_star()
		card()
	keys([["← / →", "枠"], ["↑ / ↓", "選ぶ"], ["Enter", "装備"], ["X", "外す"], ["R", "能力"]])


# A slot's star: what it holds, its name and its key.
func _slot_star(index: int) -> void:
	var at := _spot(index)
	var open := index == model.slot and not model.figures_open
	var holds := model.slot_holds(index)
	var lit := 1.0 - sealing() if model.changed.has(index) else 0.0
	glow(at, SLOT_STAR * (2.4 + 2.0 * lit), Color(GOLD, (0.30 if open else 0.14) + 0.5 * lit))
	draw_circle(at, SLOT_STAR + 3.0, VOID)
	medal(at, SLOT_STAR, holds[0])
	ring(at, SLOT_STAR + 2.0, GOLD if open else BRASS, 2.5 if open else 1.5)
	if open:
		rays(at, SLOT_STAR + 2.0, GOLD)
	if lit > 0.0:
		ring(at, SLOT_STAR + 10.0 + 60.0 * (1.0 - lit), Color(GOLD, lit), 2.5)
	# Its name stands on her side of the star, clear of its arc.
	var inward := (POLE - at).normalized()
	var label := at + inward * 4.0 + Vector2(0.0, SLOT_STAR + 26.0) if absf(inward.y) < 0.5 else at + Vector2(0.0, SLOT_STAR + 26.0)
	text(Vector2(label.x - 90.0, label.y), "%s　%s" % [model.slot_name(index), model.slot_key(index)], GOTHIC_B if open else GOTHIC, 15, GOLD if open else DIM, HORIZONTAL_ALIGNMENT_CENTER, 180.0)
	text(Vector2(label.x - 110.0, label.y + 22.0), holds[1], MINCHO_B, 18, PALE if open else DIM, HORIZONTAL_ALIGNMENT_CENTER, 220.0)
	zone(Rect2(at - Vector2.ONE * (SLOT_STAR + 8.0), Vector2.ONE * (SLOT_STAR + 8.0) * 2.0), [&"slot", index])


func _figures_star() -> void:
	var open := model.figures_open
	glow(FIGURES_AT, 60.0, Color(BLUE, 0.25 if open else 0.10))
	HubUI.star(self, FIGURES_AT, 22.0, GOLD if open else BRASS)
	ring(FIGURES_AT, 30.0, GOLD if open else Color(BRASS, 0.6), 1.5)
	text(Vector2(FIGURES_AT.x - 80.0, FIGURES_AT.y + 56.0), "能力　R", GOTHIC_B if open else GOTHIC, 15, GOLD if open else DIM, HORIZONTAL_ALIGNMENT_CENTER, 160.0)
	zone(Rect2(FIGURES_AT - Vector2(40.0, 40.0), Vector2(80.0, 100.0)), [&"figures"])


# The things the open slot can hold, on an arc on the star's far side.
func _arc() -> void:
	var centre := _spot(model.slot)
	var out := WAYS[model.slot]
	var listed := model.entries(model.slot)
	var spread := minf(PI * 1.15, 0.42 * maxf(1.0, listed.size() - 1.0))
	var come := eased(&"turn", 0.3) if since(&"turn") < 1.0 else 1.0
	var chosen_at := centre
	for index in listed.size():
		var entry: Dictionary = listed[index]
		var share := 0.5 if listed.size() == 1 else float(index) / (listed.size() - 1)
		var at := centre + Vector2.from_angle(out + lerpf(-spread * 0.5, spread * 0.5, share)) * ARC * come
		var known: bool = entry.state != HubStatus.State.UNKNOWN
		var held: bool = entry.state == HubStatus.State.HERE
		var chosen := index == model.row
		var line := GOLD if held else (Color(DARK, 0.9) if not known else Color(BLUE, 0.45 + 0.3 * breath() if chosen else 0.3))
		if known:
			draw_line(centre, at, line, 2.0 if held else 1.2, true)
		else:
			draw_dashed_line(centre, at, line, 1.2, 5.0)
		if held:
			glow(at, SMALL * 2.4, Color(GOLD, 0.3))
			rays(at, SMALL, Color(GOLD, 0.8))
		draw_circle(at, SMALL + 2.0, VOID)
		if entry.id == HubStatus.CLEAR_ID:
			ring(at, SMALL * 0.7, DIM, 1.5)
			draw_line(at - Vector2(6.0, 6.0), at + Vector2(6.0, 6.0), DIM, 1.5, true)
		else:
			medal(at, SMALL, entry.emblem, known)
		ring(at, SMALL + 1.0, GOLD if held else (BLUE if known and entry.state == HubStatus.State.FREE and entry.id != HubStatus.CLEAR_ID else (DIM if known else DARK)), 1.5)
		if chosen:
			chosen_at = at
		elif hovered([&"row", model.slot, index]):
			ring(at, SMALL + 7.0, Color(PALE, 0.6), 1.5)
		zone(Rect2(at - Vector2.ONE * (SMALL + 7.0), Vector2.ONE * (SMALL + 7.0) * 2.0), [&"row", model.slot, index])
	if not listed.is_empty():
		cursor(chosen_at, SMALL + 8.0)
		var entry: Dictionary = listed[clampi(model.row, 0, listed.size() - 1)]
		var words: String = entry.name
		var wide := width_of(words, GOTHIC_B, 15) + 16.0
		var away := (chosen_at - centre).normalized()
		var tag := chosen_at + away * (SMALL + 26.0) - Vector2(wide * 0.5, 11.0)
		tag.x = clampf(tag.x, 8.0, CARD.position.x - wide - 12.0)
		draw_rect(Rect2(tag, Vector2(wide, 22.0)), Color(VOID, 0.8))
		text(tag + Vector2(8.0, 16.0), words, GOTHIC_B, 15, PALE)
