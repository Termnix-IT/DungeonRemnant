class_name ProtoIndex
extends ProtoScreen

# A, the row of stars: the topics stand across the top of the sky as six
# stars on one line, each with its name, and the whole width under them is
# the open topic's page: its name large, and its points in two columns so
# that a long topic fits without scrolling. The controls set their table of
# keys in the left column and their points in the right.
# Left and right go from topic to topic; Esc closes.

const ROW_Y := 150.0
const LEFT := 150.0
const RIGHT := 1450.0
const PAGE := Rect2(110.0, 250.0, 1380.0, 560.0)


func _key(action: StringName) -> void:
	match action:
		&"left", &"up":
			open(topic - 1)
		&"right", &"down":
			open(topic + 1)
		_:
			super(action)


func _wheel(by: int) -> void:
	open(topic + by)


func _spot(index: int) -> Vector2:
	return Vector2(lerpf(LEFT, RIGHT, float(index) / (count() - 1)), ROW_Y)


func _paint() -> void:
	heading()
	# The line the stars stand on, gold as far as the open one.
	HubUI.hairline(self, _spot(0) - Vector2(60.0, 0.0), _spot(count() - 1) + Vector2(60.0, 0.0), Color(BRASS, 0.6))
	var at := _spot(from).lerp(_spot(topic), moved())
	glow(at, 70.0, Color(GOLD, 0.25))
	for index in count():
		var spot := _spot(index)
		var here := index == topic
		var over := hovered([&"topic", index])
		draw_circle(spot, 16.0, VOID)
		HubUI.star(self, spot, 16.0 if here else 10.0, GOLD if here else (PALE if over else BRASS))
		if here:
			ring(spot, 24.0, GOLD, 1.5)
		text(Vector2(spot.x - 130.0, spot.y + 52.0), title_of(index), MINCHO_B, 22 if here else 19, GOLD if here else (PALE if over else DIM), HORIZONTAL_ALIGNMENT_CENTER, 260.0)
		zone(Rect2(spot.x - 120.0, spot.y - 30.0, 240.0, 96.0), [&"topic", index])
	_page()
	keys([["← / →", "話題"], ["Esc", "閉じる"]])


func _page() -> void:
	var fade := 0.25 + 0.75 * moved()
	var slide := 24.0 * (1.0 - moved()) * signf(topic - from)
	plate(PAGE, Color(PANEL, 0.86), Color(BRASS, 0.5), 4.0, 1.0)
	for corner: Vector2 in [PAGE.position, Vector2(PAGE.end.x, PAGE.position.y), PAGE.end, Vector2(PAGE.position.x, PAGE.end.y)]:
		HubUI.mark(self, corner, 6.0, BRASS)
	var x := PAGE.position.x + 56.0 + slide
	var half := (PAGE.size.x - 168.0) * 0.5
	text(Vector2(x, PAGE.position.y + 70.0), title_of(topic), MINCHO_B, 40, Color(PALE, fade))
	HubUI.trail(self, Vector2(x, PAGE.position.y + 92.0), Vector2(x + 520.0, PAGE.position.y + 92.0), Color(BRASS, 0.8 * fade))
	var top := PAGE.position.y + 144.0
	var listed := points_of(topic)
	var column := 0
	var y := top
	if topic == HubSettings.TOPIC_CONTROLS:
		key_table(Vector2(x, top - 8.0), half, fade)
		column = 1
	# The points fill the left column to its half, then the right.
	var total := 0.0
	for words in listed:
		total += tall(words, GOTHIC, 19, half - 26.0) + 18.0
	var spent := 0.0
	for words in listed:
		var height := tall(words, GOTHIC, 19, half - 26.0) + 18.0
		if column == 0 and spent > 0.0 and spent + height * 0.5 > total * 0.5:
			column = 1
			y = top
		point(Vector2(x + column * (half + 56.0), y), words, half, 19, fade)
		y += height
		spent += height
