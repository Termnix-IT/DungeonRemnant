class_name ProtoMarquee
extends ProtoScreen

# B, the frontispiece: she stands large at the right, close enough that the
# hall is her backdrop, and the menu is words alone down the left, with no
# slab and no panel. The entry under the cursor is set large in gold and
# opens under its name: what it is, its two facts and the key that opens
# it, over a strip of its picture; the others close to their names. So the
# screen holds two things only, her and the words.
# Up and down go through the entries, Enter opens the one under the cursor.

const LEFT := 112.0
const WIDE := 620.0
const TOP := 176.0
const CLOSED := 70.0
const OPEN := 286.0


func _key(action: StringName) -> void:
	match action:
		&"up":
			choose(chosen - 1)
		&"down":
			choose(chosen + 1)
		&"accept", &"right":
			enter()


func _wheel(by: int) -> void:
	choose(chosen + by)


func _paint() -> void:
	hall(0.42)
	shade_across(Rect2(0.0, 0.0, 980.0, VIEW.y), Color(0.0, 0.0, 0.0, 0.82), Color(0.0, 0.0, 0.0, 0.0))
	shade(Rect2(0.0, 640.0, VIEW.x, 260.0), Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.85))
	# She stands close: taller than the screen, cut at the knee.
	var face := heroine(Vector2(1180.0, 1330.0), 1340.0, false)
	shade(Rect2(700.0, 700.0, 900.0, 200.0), Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.75))
	spaced(Vector2(LEFT, 84.0), "旅支度の間", MINCHO_B, 30, DIM, 6.0)
	draw_line(Vector2(LEFT, 106.0), Vector2(LEFT + 300.0, 106.0), Color(GILT, 0.5), 1.0)
	diamond(Vector2(LEFT + 300.0, 106.0), 5.0, GILT)
	purse()
	var y := TOP
	for index in model.count():
		var forward := stand(index)
		var tall := lerpf(CLOSED, OPEN, forward)
		_entry(index, Rect2(LEFT, y, WIDE, tall), forward)
		y += tall
	speech(face)
	keys([["↑ / ↓", "選ぶ"], ["Enter", "決定"], ["Esc", "終了"]])


func _entry(index: int, rect: Rect2, forward: float) -> void:
	var lit := forward > 0.0 or hovered(index)
	var size := int(lerpf(34.0, 60.0, forward))
	var base := rect.position.y + lerpf(48.0, 66.0, forward)
	var mark := lerpf(34.0, 52.0, forward)
	if forward > 0.0:
		# A strip of its picture under the words, fading to the left.
		var strip := Rect2(rect.position.x - 40.0, rect.position.y + 88.0, rect.size.x + 80.0, rect.size.y - 108.0)
		picture(strip, model.art(index), Color(0.55, 0.55, 0.55, 0.9 * forward))
		shade_across(strip, Color(0.0, 0.0, 0.0, 0.92), Color(0.0, 0.0, 0.0, 0.35))
		draw_rect(Rect2(rect.position.x - 40.0, rect.position.y + 6.0, 4.0, rect.size.y - 26.0), Color(GOLD, forward))
	icon(model.kind(index), Vector2(rect.position.x + mark * 0.5, base - size * 0.34), mark, Color(1.0, 1.0, 1.0, 1.0 if lit else 0.6))
	text(Vector2(rect.position.x + mark + 20.0, base), model.name(index), MINCHO_B, size, GOLD if forward > 0.5 else (PALE if lit else DIM))
	if model.waiting(index):
		var right := rect.position.x + mark + 20.0 + width_of(model.name(index), MINCHO_B, size) + 22.0
		draw_circle(Vector2(right, base - size * 0.36), 6.0, Color(1.0, 0.55, 0.3))
		text(Vector2(right + 14.0, base - size * 0.36 + 6.0), model.facts(index)[1][0] + "　" + model.facts(index)[1][1], GOTHIC, 15, Color(1.0, 0.75, 0.55))
	if forward > 0.0:
		var x := rect.position.x + 4.0
		var open := Color(1.0, 1.0, 1.0, forward)
		if index == 0:
			text(Vector2(x, rect.position.y + 122.0), model.title(index), MINCHO_B, 24, PALE * open)
		paragraph(Vector2(x, rect.position.y + (154.0 if index == 0 else 130.0)), model.description(index), GOTHIC, 17, Color(PALE, 0.92) * open, rect.size.x - 20.0, 6.0, 2)
		facts(index, Vector2(x, rect.position.y + 196.0), 360.0, forward)
		var key := Rect2(rect.end.x - 250.0, rect.position.y + 196.0, 250.0, 46.0)
		action(index, key)
	else:
		draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + 360.0, rect.end.y), Color(GILT, 0.14), 1.0)
	zone(Rect2(rect.position.x - 40.0, rect.position.y, rect.size.x + 80.0, minf(rect.size.y, 88.0)), [&"entry", index])
