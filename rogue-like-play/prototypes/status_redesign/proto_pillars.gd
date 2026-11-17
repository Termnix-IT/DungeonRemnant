class_name ProtoPillars
extends ProtoScreen

# B, the four pillars: every slot and everything it can hold in sight at
# once, as the upgrades' chart shows its whole tree. The four slots stand
# side by side as pillars of light; at the head of each is the star of what
# it holds now, and down it hang the things it can hold, stars on a line,
# each with its name: gold for what is held, blue for what could be set, a
# mark for one another slot holds, a dark shape for one not learned. The
# pillar the cursor is in is lit. The card at the right tells the one under
# the cursor; her figures open over the pillars.
# Left and right go from pillar to pillar, up and down along it, Enter
# sets, X empties, R opens her figures.

const LEFT := 64.0
const WIDE := 244.0
const GAP := 12.0
const TOP := 122.0
const HEAD := 176.0
const STEP := 66.0
const SMALL := 20.0


func _pole() -> Vector2:
	return Vector2(560.0, 240.0)


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
	if model.figures_open:
		figures(Rect2(LEFT, 110.0, 1480.0, 700.0))
		keys([["R", "戻る"], ["← / →", "枠"]])
		return
	for index in ProtoStatus.SLOT_COUNT:
		_pillar(index, LEFT + index * (WIDE + GAP))
	card()
	text(Vector2(LEFT, 836.0), "R　能力を見る", GOTHIC, 15, DIM)
	zone(Rect2(LEFT, 816.0, 160.0, 28.0), [&"figures"])
	keys([["← / →", "枠"], ["↑ / ↓", "選ぶ"], ["Enter", "装備"], ["X", "外す"], ["R", "能力"]])


func _pillar(index: int, x: float) -> void:
	var open := index == model.slot
	var forward := (eased(&"turn", MOVE_TIME) if since(&"turn") < 1.0 else 1.0) if open else 0.0
	var mid := x + WIDE * 0.5
	var foot := 800.0
	# The pillar: a fall of light, brighter where the cursor is.
	shade(Rect2(x, TOP, WIDE, foot - TOP), Color(BLUE if open else DIM, 0.10 * forward + 0.03), Color(BLUE, 0.0))
	draw_line(Vector2(x, TOP), Vector2(x + WIDE, TOP), Color(GOLD if open else BRASS, 0.9 if open else 0.4), 2.0 if open else 1.0)
	HubUI.mark(self, Vector2(mid, TOP), 6.0, GOLD if open else BRASS)
	text(Vector2(x, TOP + 36.0), model.slot_name(index), MINCHO_B, 22, GOLD if open else DIM, HORIZONTAL_ALIGNMENT_CENTER, WIDE)
	text(Vector2(x, TOP + 58.0), model.slot_key(index), GOTHIC, 14, DIM, HORIZONTAL_ALIGNMENT_CENTER, WIDE)
	# What it holds, at its head.
	var holds := model.slot_holds(index)
	var head := Vector2(mid, TOP + 116.0)
	var lit := 1.0 - sealing() if model.changed.has(index) else 0.0
	glow(head, 92.0 + 60.0 * lit, Color(GOLD, (0.24 if open else 0.10) + 0.5 * lit))
	draw_circle(head, 43.0, VOID)
	medal(head, 40.0, holds[0])
	ring(head, 42.0, GOLD if open else BRASS, 2.0)
	if open:
		rays(head, 42.0, GOLD)
	if lit > 0.0:
		ring(head, 50.0 + 70.0 * (1.0 - lit), Color(GOLD, lit), 2.5)
	text(Vector2(x, head.y + 70.0), holds[1], MINCHO_B, 19, PALE if open else DIM, HORIZONTAL_ALIGNMENT_CENTER, WIDE)
	zone(Rect2(x, TOP, WIDE, HEAD + 20.0), [&"slot", index])
	# The things it can hold, down a line.
	var listed := model.entries(index)
	var first := Vector2(x + 40.0, TOP + HEAD + 66.0)
	if listed.size() > 1:
		draw_line(first, first + Vector2(0.0, STEP * (listed.size() - 1)), Color(BRASS, 0.3 if open else 0.15), 1.0)
	draw_line(head + Vector2(0.0, 44.0), Vector2(first.x, first.y - STEP * 0.5), Color(BRASS, 0.25), 1.0)
	for place in listed.size():
		var entry: Dictionary = listed[place]
		var at := first + Vector2(0.0, STEP * place)
		var known: bool = entry.state != HubStatus.State.UNKNOWN
		var held: bool = entry.state == HubStatus.State.HERE
		var chosen: bool = open and place == model.row
		var dimmed := 1.0 if open else 0.55
		if held:
			glow(at, SMALL * 2.4, Color(GOLD, 0.3 * dimmed))
			rays(at, SMALL, Color(GOLD, 0.8 * dimmed))
		draw_circle(at, SMALL + 2.0, VOID)
		if entry.id == HubStatus.CLEAR_ID:
			ring(at, SMALL * 0.7, Color(DIM, dimmed), 1.5)
			draw_line(at - Vector2(6.0, 6.0), at + Vector2(6.0, 6.0), Color(DIM, dimmed), 1.5, true)
		else:
			medal(at, SMALL, entry.emblem, known, dimmed)
		var free: bool = known and entry.state == HubStatus.State.FREE and entry.id != HubStatus.CLEAR_ID
		ring(at, SMALL + 1.0, Color(GOLD if held else (BLUE if free else (DIM if known else DARK)), dimmed), 1.5)
		var name_colour := (GOLD if held else PALE) if known else FAINT
		text(Vector2(at.x + 34.0, at.y - 2.0), entry.name, GOTHIC_B if chosen or held else GOTHIC, 16, Color(name_colour, dimmed))
		var note: String = entry.note
		if entry.state == HubStatus.State.ELSEWHERE:
			note = "%s に装備中" % model.slot_key(entry.other)
		elif held:
			note = "装備中"
		text(Vector2(at.x + 34.0, at.y + 18.0), note, GOTHIC, 13, Color(GOLD if held else (BLUE if entry.state == HubStatus.State.ELSEWHERE else FAINT), dimmed))
		if chosen:
			shade_across(Rect2(x + 6.0, at.y - STEP * 0.5 + 4.0, WIDE - 12.0, STEP - 8.0), Color(PALE, 0.10), Color(PALE, 0.0))
			cursor(at, SMALL + 8.0)
		elif hovered([&"row", index, place]):
			ring(at, SMALL + 7.0, Color(PALE, 0.6), 1.5)
		zone(Rect2(x, at.y - STEP * 0.5, WIDE, STEP), [&"row", index, place])
