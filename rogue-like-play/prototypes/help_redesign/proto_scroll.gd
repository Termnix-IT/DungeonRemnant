class_name ProtoScroll
extends ProtoScreen

# B, the one scroll: every topic written one after another down a single
# long column, so the whole help can be read through without opening
# anything. An index stands at the left, a star a topic on a line, with a
# marker showing where in the scroll the reader is; choosing a topic there
# rolls the scroll to its heading. The words fade toward the top and the
# foot of the screen.
# Up and down go to the next topic's heading, the wheel rolls freely; Esc
# closes.

const INDEX_X := 110.0
const INDEX_TOP := 230.0
const INDEX_STEP := 70.0
const LEFT := 430.0
const WIDE := 900.0
const TOP := 120.0
const FOOT := 820.0
const ROLL_TIME := 0.35

# How far the scroll is rolled, where it is rolling to and from, and where
# each topic's heading stands in it.
var rolled := 0.0
var _rolled_from := 0.0
var _rolled_to := 0.0
var _heads: Array[float] = []
var _length := 0.0


func _key(action: StringName) -> void:
	match action:
		&"up", &"left":
			open(topic - 1)
		&"down", &"right":
			open(topic + 1)
		_:
			super(action)


func open(index: int) -> void:
	var before := topic
	super(index)
	if topic != before:
		_roll_to(_heads[topic] if not _heads.is_empty() else 0.0)


func _posed() -> void:
	_measure()
	rolled = _limit(_heads[topic])
	_rolled_from = rolled
	_rolled_to = rolled


func _wheel(by: int) -> void:
	_roll_to(_rolled_to + by * 110.0)
	# The index follows the scroll.
	for index in range(count() - 1, -1, -1):
		if _rolled_to + 80.0 >= _heads[index]:
			topic = index
			from = index
			break


func _limit(to: float) -> float:
	return clampf(to, 0.0, maxf(0.0, _length - (FOOT - TOP)))


func _roll_to(to: float) -> void:
	_rolled_from = rolled
	_rolled_to = _limit(to)
	kick(&"roll")


# Where each topic's heading stands, and how long the scroll is.
func _measure() -> void:
	_heads.clear()
	var y := 0.0
	for index in count():
		_heads.append(y)
		y += 96.0
		if index == HubSettings.TOPIC_CONTROLS:
			y += 38.0 + key_rows().size() * 40.0 + 24.0
		for words in points_of(index):
			y += tall(words, GOTHIC, 19, WIDE - 26.0) + 18.0
		y += 56.0
	_length = y


# How clearly something at a height on the screen shows: it fades toward
# the top and the foot.
func _clear(y: float) -> float:
	return clampf((y - TOP) / 60.0, 0.0, 1.0) * clampf((FOOT - y) / 60.0, 0.0, 1.0)


func _paint() -> void:
	if _heads.is_empty():
		_measure()
	if since(&"roll") < ROLL_TIME:
		rolled = lerpf(_rolled_from, _rolled_to, eased(&"roll", ROLL_TIME))
	else:
		rolled = _rolled_to
	heading()
	_index()
	draw_line(Vector2(LEFT - 50.0, TOP), Vector2(LEFT - 50.0, FOOT), Color(BRASS, 0.18), 1.0)
	var y := TOP - rolled
	for index in count():
		y = _topic(index, y)
	keys([["↑ / ↓", "話題"], ["ホイール", "送る"], ["Esc", "閉じる"]])


func _index() -> void:
	var first := Vector2(INDEX_X, INDEX_TOP)
	draw_line(first, first + Vector2(0.0, INDEX_STEP * (count() - 1)), Color(BRASS, 0.4), 1.0)
	# Where in the scroll the reader is, along the index's line.
	var share := 0.0
	for index in count():
		var next: float = _heads[index + 1] if index + 1 < count() else _length
		if rolled + 80.0 >= _heads[index]:
			share = index + clampf((rolled + 80.0 - _heads[index]) / maxf(1.0, next - _heads[index]), 0.0, 1.0) * (1.0 if index + 1 < count() else 0.0)
	var marker := first + Vector2(0.0, INDEX_STEP * minf(share, count() - 1.0))
	glow(marker, 46.0, Color(GOLD, 0.3))
	for index in count():
		var at := first + Vector2(0.0, INDEX_STEP * index)
		var here := index == topic
		var over := hovered([&"topic", index])
		draw_circle(at, 12.0, VOID)
		HubUI.star(self, at, 13.0 if here else 8.0, GOLD if here else (PALE if over else BRASS))
		text(at + Vector2(34.0, 8.0), title_of(index), MINCHO_B, 22 if here else 19, GOLD if here else (PALE if over else DIM))
		zone(Rect2(at.x - 20.0, at.y - INDEX_STEP * 0.5, 280.0, INDEX_STEP), [&"topic", index])
	ring(marker, 20.0, GOLD, 1.5)


# One topic in the scroll, from `y` down; returns where the next begins.
func _topic(index: int, y: float) -> float:
	var head := y + 56.0
	var alpha := _clear(head - 20.0)
	if alpha > 0.0:
		HubUI.mark(self, Vector2(LEFT - 50.0, head - 12.0), 7.0, Color(GOLD, alpha))
		text(Vector2(LEFT, head), title_of(index), MINCHO_B, 34, Color(PALE if index == topic else DIM, alpha))
		HubUI.trail(self, Vector2(LEFT, head + 18.0), Vector2(LEFT + 520.0, head + 18.0), Color(BRASS, 0.8 * alpha))
	y += 96.0
	if index == HubSettings.TOPIC_CONTROLS:
		var height := 38.0 + key_rows().size() * 40.0
		if y + height > TOP and y < FOOT:
			key_table(Vector2(LEFT, y + 12.0), 760.0, minf(_clear(y + 20.0), _clear(y + height)))
		y += height + 24.0
	for words in points_of(index):
		var height := tall(words, GOTHIC, 19, WIDE - 26.0)
		var shown := minf(_clear(y), _clear(y + height))
		if shown > 0.0:
			point(Vector2(LEFT, y + 16.0), words, WIDE, 19, shown)
		y += height + 18.0
	return y + 56.0
