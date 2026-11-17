class_name ProtoPlates
extends ProtoScreen

# C, the pictured plates: the help shown before it is told. The topics stand
# down the left; the open one fills the rest with plates. The controls are
# drawn as the hand finds them: the keys of the left hand laid out as on a
# keyboard and the mouse beside them, each tagged with what it does, over
# the pad's buttons in a row. The flow of a run is a chain of five stations
# from setting out to the boss. Every topic's points are plates of their
# own, two across, numbered with stars, so each rule is a thing to look at
# and not a line in a paragraph.
# Up and down go from topic to topic; Esc closes.

const LIST_X := 96.0
const LIST_TOP := 190.0
const LIST_STEP := 76.0
const LEFT := 420.0
const RIGHT := 1510.0
const TOP := 110.0
# The stations of a run, for its chain.
const STATIONS := ["出撃", "分岐マップ", "エリアを制圧", "報酬と強化", "ボス"]
# The left hand's keys as they lie on a keyboard: [key, column, row, the
# controls' row that names what it does (HubSettings.HELP_KEYS), or -1].
const BOARD := [["Esc", 0.0, 0, 7], ["Q", 1.3, 1, 4], ["W", 2.3, 1, 0], ["E", 3.3, 1, 4], ["R", 4.3, 1, 5], ["A", 1.6, 2, 0], ["S", 2.6, 2, 0], ["D", 3.6, 2, 0], ["Space", 2.4, 3, 3]]
const KEY := 62.0


func _key(action: StringName) -> void:
	match action:
		&"up", &"left":
			open(topic - 1)
		&"down", &"right":
			open(topic + 1)
		_:
			super(action)


func _wheel(by: int) -> void:
	open(topic + by)


func _paint() -> void:
	heading()
	var first := Vector2(LIST_X, LIST_TOP)
	var bar := first.y + LIST_STEP * lerpf(from, topic, moved())
	shade_across(Rect2(first.x - 30.0, bar - LIST_STEP * 0.5 + 6.0, 300.0, LIST_STEP - 12.0), Color(GOLD, 0.18), Color(GOLD, 0.0))
	draw_rect(Rect2(first.x - 30.0, bar - LIST_STEP * 0.5 + 6.0, 3.0, LIST_STEP - 12.0), GOLD)
	for index in count():
		var at := first + Vector2(0.0, LIST_STEP * index)
		var here := index == topic
		var over := hovered([&"topic", index])
		HubUI.star(self, at, 12.0 if here else 8.0, GOLD if here else (PALE if over else BRASS))
		text(at + Vector2(30.0, 9.0), title_of(index), MINCHO_B, 24 if here else 20, GOLD if here else (PALE if over else DIM))
		zone(Rect2(at.x - 30.0, at.y - LIST_STEP * 0.5, 300.0, LIST_STEP), [&"topic", index])
	draw_line(Vector2(LEFT - 46.0, TOP), Vector2(LEFT - 46.0, 820.0), Color(BRASS, 0.2), 1.0)
	var fade := 0.2 + 0.8 * moved()
	var y := TOP + 46.0
	text(Vector2(LEFT, y), title_of(topic), MINCHO_B, 38, Color(PALE, fade))
	HubUI.trail(self, Vector2(LEFT, y + 20.0), Vector2(LEFT + 520.0, y + 20.0), Color(BRASS, 0.8 * fade))
	y += 52.0
	if topic == HubSettings.TOPIC_CONTROLS:
		y = _hand(y, fade)
	elif topic == HubSettings.TOPIC_RUN:
		y = _chain(y, fade)
	_cards(y, fade)
	keys([["↑ / ↓", "話題"], ["Esc", "閉じる"]])


# The left hand's keys and the mouse, each tagged with what it does, and
# the pad's buttons in a row under them; returns where the plates begin.
func _hand(top: float, fade: float) -> float:
	var rows := key_rows()
	var origin := Vector2(LEFT + 20.0, top + 6.0)
	for entry: Array in BOARD:
		var wide := KEY * (3.2 if entry[0] == "Space" else 1.0)
		var rect := Rect2(origin + Vector2(entry[1] * (KEY + 8.0), entry[2] * (KEY + 8.0)), Vector2(wide, KEY))
		plate(rect, Color(PANEL, fade), Color(GOLD, fade), 6.0, 1.5)
		text(Vector2(rect.position.x, rect.position.y + 24.0), entry[0], GOTHIC_B, 16, Color(PALE, fade), HORIZONTAL_ALIGNMENT_CENTER, wide)
		var does: String = rows[entry[3]][0]
		text(Vector2(rect.position.x, rect.end.y - 10.0), does, GOTHIC, 13, Color(GOLD, fade), HORIZONTAL_ALIGNMENT_CENTER, wide)
	# The mouse: its left button attacks, moving it aims.
	var mouse := Rect2(origin + Vector2(470.0, 60.0), Vector2(120.0, 190.0))
	plate(mouse, Color(PANEL, fade), Color(BRASS, fade), 56.0, 1.5)
	draw_rect(Rect2(mouse.position + Vector2(8.0, 8.0), Vector2(50.0, 70.0)), Color(GOLD, 0.35 * fade))
	draw_line(mouse.position + Vector2(60.0, 6.0), mouse.position + Vector2(60.0, 84.0), Color(BRASS, fade), 1.5)
	draw_line(mouse.position + Vector2(8.0, 84.0), mouse.position + Vector2(112.0, 84.0), Color(BRASS, fade), 1.5)
	text(Vector2(mouse.position.x - 150.0, mouse.position.y + 44.0), rows[1][0], GOTHIC_B, 15, Color(GOLD, fade), HORIZONTAL_ALIGNMENT_RIGHT, 140.0)
	draw_line(mouse.position + Vector2(-6.0, 40.0), mouse.position + Vector2(20.0, 40.0), Color(GOLD, fade), 1.5)
	text(Vector2(mouse.position.x, mouse.end.y + 26.0), "%s　%s" % [rows[2][1][0], rows[2][0]], GOTHIC, 15, Color(PALE, fade), HORIZONTAL_ALIGNMENT_CENTER, mouse.size.x)
	# The pad: what each action is on it.
	var x := origin.x + 660.0
	var y := origin.y + 18.0
	text(Vector2(x, y), "ゲームパッド", GOTHIC, 14, Color(DIM, fade))
	y += 36.0
	for row: Array in rows:
		text(Vector2(x, y), row[0], GOTHIC, 15, Color(PALE, fade))
		var at := x + 130.0
		for name: String in row[2]:
			at += cap(Vector2(at, y), name, 13, fade) + 6.0
		y += 31.0
	return top + 4.0 * (KEY + 8.0) + 34.0


# A run as a chain of stations; returns where the plates begin.
func _chain(top: float, fade: float) -> float:
	var y := top + 56.0
	var first := LEFT + 70.0
	var step := (RIGHT - LEFT - 140.0) / (STATIONS.size() - 1)
	HubUI.hairline(self, Vector2(first - 40.0, y), Vector2(first + step * (STATIONS.size() - 1) + 40.0, y), Color(BRASS, 0.8 * fade))
	for index in STATIONS.size():
		var at := Vector2(first + step * index, y)
		var last := index == STATIONS.size() - 1
		glow(at, 56.0, Color(GOLD, 0.22 * fade))
		draw_circle(at, 30.0, Color(VOID, fade))
		ring(at, 30.0, Color(GOLD if last else BRASS, fade), 2.0)
		HubUI.star(self, at, 16.0 if last else 11.0, Color(GOLD, fade))
		text(Vector2(at.x - 110.0, at.y + 62.0), STATIONS[index], MINCHO_B, 20, Color(PALE, fade), HORIZONTAL_ALIGNMENT_CENTER, 220.0)
		if not last:
			text(Vector2(at.x + step * 0.5 - 12.0, at.y - 12.0), "›", GOTHIC_B, 22, Color(BRASS, fade))
	return top + 150.0


# The topic's points as plates, two across, from `top` down.
func _cards(top: float, fade: float) -> void:
	var listed := points_of(topic)
	var wide := (RIGHT - LEFT - 20.0) * 0.5
	var size := 17 if listed.size() > 6 or topic == HubSettings.TOPIC_CONTROLS else 18
	var heights: Array[float] = []
	for words in listed:
		heights.append(tall(words, GOTHIC, size, wide - 76.0) + 34.0)
	var y := top
	for index in range(0, listed.size(), 2):
		var height: float = maxf(heights[index], heights[index + 1] if index + 1 < listed.size() else 0.0)
		for side in 2:
			if index + side >= listed.size():
				continue
			var rect := Rect2(LEFT + side * (wide + 20.0), y, wide, height)
			plate(rect, Color(PANEL, 0.86 * fade), Color(BRASS, 0.4 * fade), 4.0, 1.0)
			HubUI.star(self, rect.position + Vector2(28.0, 30.0), 10.0, Color(GOLD, fade))
			text(Vector2(rect.position.x + 10.0, rect.position.y + 58.0), str(index + side + 1), GOTHIC, 13, Color(DIM, fade), HORIZONTAL_ALIGNMENT_CENTER, 36.0)
			draw_multiline_string(GOTHIC, rect.position + Vector2(56.0, 17.0 + size), listed[index + side], HORIZONTAL_ALIGNMENT_LEFT, wide - 76.0, size, -1, Color(PALE, fade), BREAKS)
		y += height + 12.0
