class_name ProtoDeck
extends ProtoScreen

# C, the journey's table: the lobby is for setting out, so the departure is
# the screen's one large card, the chapter it opens on painted across it
# with its record and its action always there, and the other four entries
# are small cards in a row under it, each telling its two facts without
# being chosen. Nothing is hidden behind the cursor: what can be bought,
# what she carries, what has been met and how loud the game is are all in
# sight at once. She stands where she does now.
# Left and right go along the row, up goes to the departure and down back
# to the row, Enter opens the one under the cursor.

const CARD := Rect2(72.0, 132.0, 960.0, 400.0)
const ROW_TOP := 566.0
const TILE := Vector2(228.0, 236.0)
const TILE_GAP := 16.0

# The small card the cursor was on last, to come back down to.
var _last_tile := 1


func choose(index: int) -> void:
	super(index)
	if chosen > 0:
		_last_tile = chosen


func _key(action: StringName) -> void:
	match action:
		&"left":
			choose(maxi(1, chosen - 1) if chosen > 0 else 0)
		&"right":
			choose(mini(model.count() - 1, chosen + 1) if chosen > 0 else 1)
		&"up":
			choose(0)
		&"down":
			if chosen == 0:
				choose(_last_tile)
		&"accept":
			enter()


func _wheel(by: int) -> void:
	choose(chosen + by)


func _paint() -> void:
	hall(0.50)
	shade_across(Rect2(0.0, 0.0, 1150.0, VIEW.y), Color(0.0, 0.0, 0.0, 0.55), Color(0.0, 0.0, 0.0, 0.0))
	spaced(Vector2(72.0, 84.0), "旅支度の間", MINCHO_B, 34, PALE, 4.0)
	purse()
	var face := heroine(VIEW * Vector2(0.845, 0.965), VIEW.y * 0.8)
	_departure()
	for index in range(1, model.count()):
		_tile(index, Rect2(Vector2(CARD.position.x + (index - 1) * (TILE.x + TILE_GAP), ROW_TOP), TILE))
	speech(face)
	keys([["← / → / ↑ / ↓", "選ぶ"], ["Enter", "決定"], ["Esc", "終了"]])


func _frame(rect: Rect2, forward: float, over: bool) -> void:
	draw_rect(rect, Color(GILT, 0.55 if over else 0.35), false, 1.0)
	if forward > 0.0:
		draw_rect(rect.grow(3.0), Color(GOLD, forward), false, 2.5)
		draw_rect(rect.grow(9.0), Color(GOLD, 0.25 * forward), false, 1.0)
		for x: float in [rect.position.x - 3.0, rect.end.x + 3.0]:
			for y: float in [rect.position.y - 3.0, rect.end.y + 3.0]:
				diamond(Vector2(x, y), 6.0 * forward, GOLD)


# The departure: the chapter it opens on, painted across the card.
func _departure() -> void:
	var forward := stand(0)
	var bright := lerpf(0.62, 0.95, forward)
	picture(CARD, model.art(0), Color(bright, bright, bright), Vector2(0.8, 0.5))
	shade_across(Rect2(CARD.position, Vector2(CARD.size.x * 0.75, CARD.size.y)), Color(0.0, 0.0, 0.0, 0.88), Color(0.0, 0.0, 0.0, 0.0))
	shade(Rect2(CARD.position.x, CARD.end.y - 150.0, CARD.size.x, 150.0), Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.8))
	_frame(CARD, forward, hovered(0))
	var x := CARD.position.x + 40.0
	icon(model.kind(0), Vector2(x + 20.0, CARD.position.y + 56.0), 40.0)
	text(Vector2(x + 50.0, CARD.position.y + 64.0), model.name(0), MINCHO_B, 24, GOLD)
	text(Vector2(x - 2.0, CARD.position.y + 150.0), model.title(0), MINCHO_B, 54, PALE)
	paragraph(Vector2(x, CARD.position.y + 192.0), model.description(0), GOTHIC, 18, Color(PALE, 0.92), 600.0, 6.0, 2)
	facts(0, Vector2(x, CARD.position.y + 262.0), 420.0)
	zone(CARD, [&"entry", 0])
	action(0, Rect2(x, CARD.end.y - 80.0, 420.0, 52.0), true)


# One of the other four: its mark and name, its picture, and its two facts.
func _tile(index: int, rect: Rect2) -> void:
	var forward := stand(index)
	var bright := lerpf(0.42, 0.75, forward)
	draw_rect(rect, Color(INK, 0.92))
	picture(Rect2(rect.position, Vector2(rect.size.x, 84.0)), model.art(index), Color(bright, bright, bright))
	shade(Rect2(rect.position.x, rect.position.y + 30.0, rect.size.x, 54.0), Color(INK, 0.0), Color(INK, 0.92))
	_frame(rect, forward, hovered(index))
	var lit := forward > 0.5
	icon(model.kind(index), Vector2(rect.position.x + 34.0, rect.position.y + 74.0), 36.0, Color.WHITE if lit else Color(1.0, 1.0, 1.0, 0.75))
	text(Vector2(rect.position.x + 60.0, rect.position.y + 84.0), model.name(index), MINCHO_B, 24, GOLD if lit else PALE)
	var listed := model.facts(index)
	for place in listed.size():
		var y := rect.position.y + 128.0 + place * 44.0
		var marked: bool = model.waiting(index) and place == 1
		text(Vector2(rect.position.x + 18.0, y), listed[place][0], GOTHIC, 14, Color(1.0, 0.75, 0.55) if marked else DIM)
		text(Vector2(rect.position.x, y + 4.0), listed[place][1], MINCHO_B, 22, Color(1.0, 0.82, 0.6) if marked else PALE, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 18.0)
		draw_line(Vector2(rect.position.x + 18.0, y + 16.0), Vector2(rect.end.x - 18.0, y + 16.0), Color(GILT, 0.18), 1.0)
	if model.waiting(index):
		draw_circle(rect.position + Vector2(rect.size.x - 16.0, 16.0), 7.0, Color(1.0, 0.55, 0.3))
		draw_circle(rect.position + Vector2(rect.size.x - 16.0, 16.0), 3.0, PALE)
	if entering() > 0.0 and index == chosen:
		draw_rect(rect, Color(1.0, 0.9, 0.7, 0.35 * entering()))
	zone(rect, [&"entry", index])
