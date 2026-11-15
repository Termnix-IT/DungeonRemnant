class_name ProtoPlaces
extends ProtoScreen

# A, the hall's own places: no menu. The five entries are places in the
# hall's painting, each named by a tag pinned over it: the stair to the
# dungeon is the departure, the crystal over the altar the upgrades, the
# rack of arms the status, the table of scales and flasks the encyclopedia,
# the lantern by the door the settings. The place under the cursor is lit
# in a pool of light and its tag stands large; a thin line runs from it to
# a plate on the floor that tells it and holds its one action. She stands
# where she does now.
# Left and right go from place to place across the hall, Enter opens the
# one under the cursor; the pointer chooses a place by its tag.

# Where each entry's place is in the 1600x900 view, by its id, and the
# order the places stand in from left to right.
const SPOTS := {
	&"settings": Vector2(290.0, 214.0), &"status": Vector2(420.0, 330.0), &"upgrade": Vector2(640.0, 268.0),
	&"departure": Vector2(872.0, 330.0), &"codex": Vector2(1090.0, 330.0),
}
const ACROSS: Array[StringName] = [&"settings", &"status", &"upgrade", &"departure", &"codex"]
const PLATE := Rect2(420.0, 596.0, 660.0, 244.0)


func _index_of(id: StringName) -> int:
	for index in model.count():
		if model.id(index) == id:
			return index
	return 0


func _key(action: StringName) -> void:
	var at := ACROSS.find(model.id(chosen))
	match action:
		&"left", &"up":
			choose(_index_of(ACROSS[maxi(0, at - 1)]))
		&"right", &"down":
			choose(_index_of(ACROSS[mini(ACROSS.size() - 1, at + 1)]))
		&"accept":
			enter()


func _wheel(by: int) -> void:
	_key(&"right" if by > 0 else &"left")


func _paint() -> void:
	hall(0.30)
	shade(Rect2(0.0, 0.0, VIEW.x, 150.0), Color(0.0, 0.0, 0.0, 0.6), Color(0.0, 0.0, 0.0, 0.0))
	# The pool of light on the place under the cursor, on its way from the last.
	var light := (SPOTS[model.id(from)] as Vector2).lerp(SPOTS[model.id(chosen)], moved())
	glow(light, 230.0, Color(1.0, 0.86, 0.6, 0.20))
	glow(light, 110.0, Color(1.0, 0.9, 0.7, 0.16 + 0.05 * sin(clock * 2.2)))
	spaced(Vector2(52.0, 62.0), "旅支度の間", MINCHO_B, 34, PALE, 4.0)
	purse()
	var face := heroine(VIEW * Vector2(0.835, 0.965), VIEW.y * 0.8)
	_plate()
	for index in model.count():
		if index != chosen:
			_tag(index)
	_tag(chosen)
	speech(face)
	keys([["← / →", "選ぶ"], ["Enter", "決定"], ["Esc", "終了"]])


# A place's tag: a pin on the place, and its mark and name on a small plate
# over it; the chosen one's larger, with a ring breathing on the place.
func _tag(index: int) -> void:
	var at: Vector2 = SPOTS[model.id(index)]
	var forward := stand(index)
	var lit := forward > 0.0 or hovered(index)
	var name := model.name(index)
	var size := int(lerpf(20.0, 30.0, forward))
	var mark := lerpf(30.0, 44.0, forward)
	var wide := width_of(name, MINCHO_B, size) + mark + 44.0
	var tall := lerpf(42.0, 60.0, forward)
	var rect := Rect2(at.x - wide * 0.5, at.y - 54.0 - tall - 10.0 * forward, wide, tall)
	if forward > 0.0:
		ring(at, 30.0 + 8.0 * sin(clock * 2.2), Color(GOLD, 0.7 * forward), 2.0)
		ring(at, 46.0 + 8.0 * sin(clock * 2.2), Color(GOLD, 0.3 * forward), 1.0)
	draw_line(at, Vector2(at.x, rect.end.y), Color(GOLD if lit else GILT, 0.9 if lit else 0.55), 1.5)
	diamond(at, lerpf(6.0, 9.0, forward), GOLD if lit else GILT)
	plate(rect, Color(INK, lerpf(0.78, 0.94, forward)), Color(GOLD if lit else GILT, lerpf(0.45, 1.0, forward)), 4.0, 1.0 + forward)
	icon(model.kind(index), Vector2(rect.position.x + 18.0 + mark * 0.5, rect.get_center().y), mark, Color.WHITE if lit else Color(1.0, 1.0, 1.0, 0.7))
	text(Vector2(rect.position.x + 28.0 + mark, rect.get_center().y + size * 0.36), name, MINCHO_B, size, GOLD if forward > 0.5 else (PALE if lit else DIM))
	if model.waiting(index):
		draw_circle(Vector2(rect.end.x - 2.0, rect.position.y + 2.0), 7.0, Color(1.0, 0.55, 0.3))
		draw_circle(Vector2(rect.end.x - 2.0, rect.position.y + 2.0), 3.0, PALE)
	zone(rect.grow(6.0), [&"entry", index])
	zone(Rect2(at - Vector2(40.0, 40.0), Vector2(80.0, 80.0)), [&"entry", index])


# The plate on the floor: what the chosen place is, its facts, its action.
func _plate() -> void:
	var fade := 0.25 + 0.75 * moved()
	var at: Vector2 = SPOTS[model.id(chosen)]
	draw_line(at + Vector2(0.0, 12.0), Vector2(clampf(at.x, PLATE.position.x + 40.0, PLATE.end.x - 40.0), PLATE.position.y), Color(GOLD, 0.35 * moved()), 1.0, true)
	draw_rect(PLATE, Color(INK, 0.90))
	picture(Rect2(PLATE.position.x + PLATE.size.x * 0.45, PLATE.position.y, PLATE.size.x * 0.55, PLATE.size.y), model.art(chosen), Color(0.6, 0.6, 0.6, fade))
	shade_across(Rect2(PLATE.position.x + PLATE.size.x * 0.45, PLATE.position.y, PLATE.size.x * 0.55, PLATE.size.y), Color(INK, 0.92), Color(INK, 0.15))
	draw_rect(PLATE, Color(GILT, 0.9), false, 1.5)
	draw_rect(PLATE.grow(-6.0), Color(GILT, 0.3), false, 1.0)
	for x: float in [PLATE.position.x, PLATE.end.x]:
		for y: float in [PLATE.position.y, PLATE.end.y]:
			diamond(Vector2(x, y), 6.0, GILT)
	var x := PLATE.position.x + 30.0
	icon(model.kind(chosen), Vector2(x + 22.0, PLATE.position.y + 46.0), 44.0, Color(1.0, 1.0, 1.0, fade))
	text(Vector2(x + 56.0, PLATE.position.y + 58.0), model.title(chosen), MINCHO_B, 32, Color(PALE, fade))
	text(Vector2(x, PLATE.position.y + 92.0), model.description(chosen), GOTHIC, 17, Color(PALE, 0.9 * fade), HORIZONTAL_ALIGNMENT_LEFT, PLATE.size.x - 60.0)
	draw_line(Vector2(x, PLATE.position.y + 108.0), Vector2(PLATE.end.x - 30.0, PLATE.position.y + 108.0), Color(GILT, 0.3), 1.0)
	facts(chosen, Vector2(x + 60.0, PLATE.position.y + 130.0), PLATE.size.x - 120.0, fade)
	action(chosen, Rect2(x, PLATE.end.y - 68.0, PLATE.size.x - 60.0, 48.0))
