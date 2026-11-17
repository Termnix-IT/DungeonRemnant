class_name ProtoMirror
extends ProtoScreen

# C, the stargazer's glass: she stands whole under the night sky, and what
# she carries is set about her as stars joined to her by lines, where it
# belongs: the attack by her sword hand, the two skills at her shoulders,
# the special move by her head. Her five main figures stand under her
# feet, always in sight. Beside her is the index of the open slot, a row a
# thing, and at the right the card of the one under the cursor. So the
# screen answers "what is she carrying" before "what could she carry".
# Left and right go from slot to slot, up and down through the index,
# Enter sets, X empties, R opens her figures in full.

const FEET := Vector2(330.0, 762.0)
const TALL := 660.0
const STAR := 38.0
# Where each slot's star stands about her, and the point on her it is tied to.
const SPOTS: Array[Vector2] = [Vector2(110.0, 540.0), Vector2(104.0, 280.0), Vector2(566.0, 350.0), Vector2(560.0, 150.0)]
const TIES: Array[Vector2] = [Vector2(254.0, 560.0), Vector2(272.0, 322.0), Vector2(402.0, 330.0), Vector2(352.0, 152.0)]
const LIST := Rect2(660.0, 122.0, 410.0, 600.0)
const ROW := 62.0


func _pole() -> Vector2:
	return Vector2(330.0, 430.0)


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


func _paint() -> void:
	title("ステータス")
	# She, under the sky.
	glow(Vector2(FEET.x, 420.0), 330.0, Color(1.0, 0.82, 0.5, 0.10))
	var extent := Vector2(HERO.get_size().aspect(), 1.0) * TALL
	for index in ProtoStatus.SLOT_COUNT:
		var open := index == model.slot and not model.figures_open
		draw_line(SPOTS[index], TIES[index], Color(GOLD, 0.85 if open else 0.3), 2.0 if open else 1.0, true)
	draw_texture_rect(HERO, Rect2(FEET - extent * HubLobby.FEET, extent), false, Color(0.93, 0.92, 0.95))
	for index in ProtoStatus.SLOT_COUNT:
		_slot_star(index)
		draw_circle(TIES[index], 4.0, GOLD if index == model.slot else BRASS)
	_main_figures()
	if model.figures_open:
		figures(Rect2(660.0, 110.0, 884.0, 700.0))
	else:
		_index()
		card()
	keys([["← / →", "枠"], ["↑ / ↓", "選ぶ"], ["Enter", "装備"], ["X", "外す"], ["R", "能力"]])


func _slot_star(index: int) -> void:
	var at := SPOTS[index]
	var open := index == model.slot and not model.figures_open
	var holds := model.slot_holds(index)
	var lit := 1.0 - sealing() if model.changed.has(index) else 0.0
	glow(at, STAR * (2.3 + 2.0 * lit), Color(GOLD, (0.30 if open else 0.12) + 0.5 * lit))
	draw_circle(at, STAR + 3.0, VOID)
	medal(at, STAR, holds[0])
	ring(at, STAR + 2.0, GOLD if open else BRASS, 2.5 if open else 1.5)
	if open:
		rays(at, STAR + 2.0, GOLD)
	if lit > 0.0:
		ring(at, STAR + 10.0 + 60.0 * (1.0 - lit), Color(GOLD, lit), 2.5)
	var y := at.y + STAR + 26.0
	text(Vector2(at.x - 90.0, y), "%s　%s" % [model.slot_name(index), model.slot_key(index)], GOTHIC_B if open else GOTHIC, 14, GOLD if open else DIM, HORIZONTAL_ALIGNMENT_CENTER, 180.0)
	text(Vector2(at.x - 100.0, y + 22.0), holds[1], MINCHO_B, 17, PALE if open else DIM, HORIZONTAL_ALIGNMENT_CENTER, 200.0)
	zone(Rect2(at - Vector2(60.0, STAR + 8.0), Vector2(120.0, STAR * 2.0 + 64.0)), [&"slot", index])


# Her five main figures, under her feet.
func _main_figures() -> void:
	var main := model.stats().filter(func(stat: Array) -> bool: return stat[4])
	var wide := 600.0 / main.size()
	draw_line(Vector2(30.0, 776.0), Vector2(630.0, 776.0), Color(BRASS, 0.35), 1.0)
	for index in main.size():
		var x := 30.0 + index * wide
		text(Vector2(x, 796.0), main[index][0], GOTHIC, 13, DIM, HORIZONTAL_ALIGNMENT_CENTER, wide)
		draw_string(MINCHO_B, Vector2(x, 822.0), main[index][1], HORIZONTAL_ALIGNMENT_CENTER, wide, 19, GOLD)
	zone(Rect2(30.0, 776.0, 600.0, 52.0), [&"figures"])


# The open slot's index: a row a thing.
func _index() -> void:
	var listed := model.entries(model.slot)
	var come := eased(&"turn", 0.25) if since(&"turn") < 1.0 else 1.0
	text(LIST.position + Vector2(0.0, 26.0), "%s に付けられるもの" % model.slot_name(model.slot), MINCHO_B, 22, GOLD)
	HubUI.trail(self, LIST.position + Vector2(0.0, 40.0), LIST.position + Vector2(LIST.size.x, 40.0), Color(BRASS, 0.7))
	for place in listed.size():
		var entry: Dictionary = listed[place]
		var rect := Rect2(LIST.position.x + 24.0 * (1.0 - come), LIST.position.y + 54.0 + place * ROW, LIST.size.x, ROW)
		var at := Vector2(rect.position.x + 32.0, rect.get_center().y)
		var known: bool = entry.state != HubStatus.State.UNKNOWN
		var held: bool = entry.state == HubStatus.State.HERE
		var chosen := place == model.row
		if chosen:
			shade_across(rect.grow_individual(8.0, -3.0, 0.0, -3.0), Color(PALE, 0.12), Color(PALE, 0.0))
		if held:
			glow(at, 50.0, Color(GOLD, 0.3))
			rays(at, 21.0, Color(GOLD, 0.8))
		draw_circle(at, 23.0, VOID)
		if entry.id == HubStatus.CLEAR_ID:
			ring(at, 14.0, DIM, 1.5)
			draw_line(at - Vector2(6.0, 6.0), at + Vector2(6.0, 6.0), DIM, 1.5, true)
		else:
			medal(at, 21.0, entry.emblem, known, come)
		var free: bool = known and entry.state == HubStatus.State.FREE and entry.id != HubStatus.CLEAR_ID
		ring(at, 22.0, GOLD if held else (BLUE if free else (DIM if known else DARK)), 1.5)
		text(Vector2(at.x + 40.0, at.y + 7.0), entry.name, GOTHIC_B if chosen or held else GOTHIC, 18, Color((GOLD if held else PALE) if known else FAINT, come))
		var note: String = entry.note
		if entry.state == HubStatus.State.ELSEWHERE:
			note = "%s に装備中" % model.slot_key(entry.other)
		elif held:
			note = "装備中"
		text(Vector2(rect.position.x, at.y + 6.0), note, GOTHIC, 14, Color(GOLD if held else (BLUE if entry.state == HubStatus.State.ELSEWHERE else FAINT), come), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 8.0)
		if chosen:
			cursor(at, 29.0)
		elif hovered([&"row", model.slot, place]):
			ring(at, 28.0, Color(PALE, 0.6), 1.5)
		zone(rect, [&"row", model.slot, place])
