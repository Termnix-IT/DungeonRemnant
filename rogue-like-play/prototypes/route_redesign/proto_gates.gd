class_name ProtoGates
extends ProtoScreen

# Prototype B, the three gates: no map at all at the middle of the screen.
# She stands at a fork with her back to the player, and each way open now is
# a gate before her, lit from within in the colour of what it gives (a
# boon's gold, a heal's crimson, the echo's blue, an event's violet) with
# what leads it standing in the light: a dark shape until the cursor turns to
# its gate, and then it is seen. The gate under the cursor grows and its
# light runs down the floor to her feet; what waits there is told at her left
# and what it gives at her right, so the two are weighed across her. The
# chapter's whole route is kept as one thin thread across the top, the ways
# a pick would close going dark on it. Enter asks: the other gates go dark.
# Enter again: she walks into the light.

const VOID := Color(0.02, 0.02, 0.03)
const STONE := Color("2c2b33")
const STONE_DARK := Color("121217")
const PALE := Color("ece6da")
const DIM := Color("9a958c")
const FAINT := Color("5f5c58")
const GOLD := Color("ffcf7a")
const CRIMSON := Color("ff6b62")
const AZURE := Color("7cc4ff")
const VIOLET := Color("b89bff")
const BLOOD := Color("e0453a")
const FLOOR := 548.0
const GATE := Vector2(236.0, 350.0)
const FRAME := 20.0
const HERO := Vector2(800.0, 800.0)
const HERO_HEIGHT := 150.0
const LEFT := Rect2(70.0, 664.0, 520.0, 180.0)
const RIGHT := Rect2(1010.0, 664.0, 520.0, 180.0)
const THREAD_FROM := 566.0
const THREAD_TO := 1034.0
const THREAD_Y := 60.0

var hero: DirectionalRig
# How far each gate is turned to (0 to 1), eased every frame.
var _lit: Array[float] = []


func _build() -> void:
	hero = MIO_RIG.instantiate()
	hero.world_height = HERO_HEIGHT
	add_child(hero)
	hero.facing = Vector2i.UP


func go_time() -> float:
	return 1.1


func _laid() -> void:
	_lit.clear()
	for index in model.open.size():
		_lit.append(1.0 if index == model.cursor else 0.0)
	if hero != null:
		hero.position = HERO
		hero.scale = Vector2.ONE
		hero.modulate = Color.WHITE
		hero.facing = Vector2i.UP
		hero.idle()


func light_of(told: Dictionary) -> Color:
	if told.boss:
		return BLOOD
	return {AreaData.Reward.BOON: GOLD, AreaData.Reward.HEAL: CRIMSON, AreaData.Reward.ECHO: AZURE}.get(told.reward, VIOLET)


# Where a gate stands: its foot's middle.
func gate_x(index: int) -> float:
	var count := model.open.size()
	var gap := 400.0 if count >= 3 else 480.0
	return 800.0 + (index - (count - 1) * 0.5) * gap


# --- Input ---

func _key(action: StringName) -> void:
	match action:
		&"left":
			choose(maxi(0, model.cursor - 1))
		&"right":
			choose(mini(model.open.size() - 1, model.cursor + 1))
		_:
			super(action)


func _point(id: Variant) -> void:
	peek = null
	if not id is Array:
		return
	match id[0]:
		&"open":
			if id[1] != model.cursor and not model.armed:
				choose(id[1])
		&"node":
			var point: RouteMap.Waypoint = id[1]
			if model.open.has(point):
				if not model.armed:
					choose(model.open.find(point))
			else:
				peek = point


func _click(id: Variant) -> void:
	var what: Array = id
	if what[0] == &"node":
		if model.open.has(what[1]):
			common_click([&"open", model.open.find(what[1])])
	else:
		common_click(id)


func _pose_detail() -> void:
	model.cursor = 2
	_laid()
	var last := model.route.nodes(model.route.size() - 2)
	peek = last[last.size() - 1]


# --- Painting ---

func _process(delta: float) -> void:
	super(delta)
	for index in _lit.size():
		var want := 1.0 if index == model.cursor else 0.0
		_lit[index] = move_toward(_lit[index], want, delta / 0.18)


func _paint() -> void:
	_backdrop()
	for index in model.open.size():
		_path(index)
	for index in model.open.size():
		if index != model.cursor:
			_gate(index)
	if model.selected() != null:
		_gate(model.cursor)
	_thread()
	_top()
	_weigh()
	_prompt()
	_walk()


# The chapter's own painting, far back in the dark, and the floor she stands on.
func _backdrop() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), VOID)
	picture(Rect2(0.0, 0.0, VIEW.x, 620.0), model.chapter.illustration, Color(0.2, 0.2, 0.24), Vector2(0.5, 0.25))
	shade(Rect2(0.0, 0.0, VIEW.x, 150.0), Color(VOID, 0.92), Color(VOID, 0.35))
	shade(Rect2(0.0, 150.0, VIEW.x, 300.0), Color(VOID, 0.35), Color(VOID, 0.62))
	shade(Rect2(0.0, 450.0, VIEW.x, 170.0), Color(VOID, 0.62), VOID)
	shade_across(Rect2(0.0, 0.0, 300.0, 620.0), Color(VOID, 0.9), Color(VOID, 0.0))
	shade_across(Rect2(1300.0, 0.0, 300.0, 620.0), Color(VOID, 0.0), Color(VOID, 0.9))
	# The floor: a few flagstone lines running to where the gates stand.
	for index in 9:
		var x := 800.0 + (index - 4) * 210.0
		draw_line(Vector2(800.0 + (index - 4) * 120.0, FLOOR + 6.0), Vector2(x, 900.0), Color(1.0, 1.0, 1.0, 0.025), 1.0, true)
	for index in 5:
		var y := FLOOR + 14.0 + index * index * 16.0
		draw_line(Vector2(0.0, y), Vector2(VIEW.x, y), Color(1.0, 1.0, 1.0, 0.02), 1.0)


# How open a gate is: 1, or going dark while the question is asked of another.
func _open_share(index: int) -> float:
	return 1.0 if index == model.cursor else 1.0 - arming()


# The light a gate throws down the floor to her feet.
func _path(index: int) -> void:
	var told := model.tell(model.open[index])
	var colour := light_of(told)
	var lit := _lit[index]
	var x := gate_x(index)
	var strength := (0.07 + 0.3 * lit) * _open_share(index) * eased(&"open", OPEN_TIME)
	var half := GATE.x * 0.42
	draw_polygon(
		PackedVector2Array([Vector2(x - half, FLOOR + 4.0), Vector2(x + half, FLOOR + 4.0), Vector2(HERO.x + 44.0, HERO.y + 6.0), Vector2(HERO.x - 44.0, HERO.y + 6.0)]),
		PackedColorArray([Color(colour, strength), Color(colour, strength), Color(colour, strength * 0.12), Color(colour, strength * 0.12)]))
	glow(Vector2(x, FLOOR + 10.0), 230.0, Color(colour, strength * 0.8), 0.16)


# The pointed arch of a gate `wide` across and `high` to its tip, standing
# on (0, 0).
func _arch(wide: float, high: float) -> PackedVector2Array:
	var spring := -(high - wide * 0.866)
	var points := PackedVector2Array([Vector2(-wide * 0.5, 0.0)])
	for step in 13:
		var turn := PI - PI / 3.0 * step / 12.0
		points.append(Vector2(wide * 0.5 + cos(turn) * wide, spring - sin(turn) * wide))
	for step in range(11, -1, -1):
		var turn := PI - PI / 3.0 * step / 12.0
		points.append(Vector2(-wide * 0.5 - cos(turn) * wide, spring - sin(turn) * wide))
	points.append(Vector2(wide * 0.5, 0.0))
	return points


func _gate(index: int) -> void:
	var point: RouteMap.Waypoint = model.open[index]
	var told := model.tell(point)
	var colour := light_of(told)
	var lit := _lit[index]
	var open := _open_share(index)
	var boss: bool = told.boss
	var rise := eased(&"open", OPEN_TIME + index * 0.12)
	var size := (1.0 + 0.13 * lit - 0.03 * (1.0 - lit)) * (1.1 if boss else 1.0)
	var foot := Vector2(gate_x(index), FLOOR + (1.0 - rise) * 26.0)
	var wide := GATE.x * size
	var high := GATE.y * size
	zone(Rect2(foot.x - wide * 0.5 - FRAME, foot.y - high - FRAME, wide + FRAME * 2.0, high + FRAME + 96.0), [&"open", index])
	draw_set_transform(foot)
	# The glow round it, and its stone.
	glow(Vector2(0.0, -high * 0.5), wide * 1.5, Color(colour, (0.05 + 0.2 * lit) * open * rise))
	var outer := _arch(wide + FRAME * 2.0, high + FRAME * 1.6)
	var stone := PackedColorArray()
	for at in outer:
		stone.append(STONE.lerp(STONE_DARK, clampf(-at.y / high, 0.0, 1.0) * 0.8).lerp(colour, 0.06 * lit * open))
	draw_polygon(outer, stone)
	outer.append(outer[0])
	draw_polyline(outer, Color(1.0, 1.0, 1.0, 0.1 + 0.12 * lit), 1.0, true)
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(side * (wide * 0.5 + FRAME * 0.5) - FRAME * 0.75, -10.0, FRAME * 1.5, 16.0), STONE.lightened(0.06))
	# The light within: brightest at the threshold.
	var inner := _arch(wide, high)
	var light := PackedColorArray()
	var strength := (0.42 + 0.58 * lit) * open * rise
	for at in inner:
		var up := clampf(-at.y / high, 0.0, 1.0)
		light.append(Color(0.03, 0.03, 0.04).lerp(colour.lerp(Color.WHITE, 0.25 * (1.0 - up)), strength * pow(1.0 - up, 1.4) * 0.95))
	draw_polygon(inner, light)
	glow(Vector2(0.0, -8.0), wide * 0.66, Color(colour.lerp(Color.WHITE, 0.4), 0.55 * strength), 0.55)
	# What leads it, standing in the light: a dark shape until it is turned to.
	var art := figure_of(point, true)
	if art != null:
		var room := Rect2(-wide * 0.47, -high * 0.8, wide * 0.94, high * 0.8 - 2.0)
		var seen := Color(0.03, 0.025, 0.04, 0.94).lerp(Color.WHITE, lit)
		fit(room, art, Color(seen, seen.a * rise * (0.25 + 0.75 * open)), true)
		# The light catching its feet.
		glow(Vector2(0.0, -4.0), wide * 0.5, Color(colour.lerp(Color.WHITE, 0.5), 0.34 * strength), 0.3)
	inner.append(inner[0])
	draw_polyline(inner, Color(colour, (0.3 + 0.7 * lit) * open), 1.5 + 1.5 * lit, true)
	# Its key on the keystone.
	var tip := Vector2(0.0, -high - FRAME * 1.6 + 8.0)
	diamond(tip, 20.0, STONE_DARK)
	ring_of(tip, 20.0, Color(colour, (0.4 + 0.6 * lit) * open + 0.15), 4, 1.5, PI * 0.5)
	text(Vector2(tip.x - 14.0, tip.y + 7.0), NUMERALS[index], MINCHO_B, 19, Color(PALE, 0.5 + 0.5 * lit), HORIZONTAL_ALIGNMENT_CENTER, 28.0)
	# Its name and signs under the threshold.
	var fade := (0.55 + 0.45 * lit) * (0.3 + 0.7 * open) * rise
	text(Vector2(-190.0, 46.0), told.name, MINCHO_B, 24 + roundi(4.0 * lit), Color(PALE, fade), HORIZONTAL_ALIGNMENT_CENTER, 380.0)
	_signs(Vector2(0.0, 72.0), told, colour, fade)
	draw_set_transform(Vector2.ZERO)


# A gate's signs in a row: its kind, its danger, what it gives.
func _signs(centre: Vector2, told: Dictionary, colour: Color, fade: float, small := false) -> void:
	var size := 13 if small else 15
	var kind: String = told.kind
	var gives: String = "" if told.boss else ("取引" if told.event else told.reward_words)
	var danger: int = told.danger
	var wide := width_of(kind, GOTHIC, size) + (16.0 + danger * 15.0 if danger > 0 else 0.0) + (40.0 + width_of(gives, GOTHIC_B, size) if not gives.is_empty() else 0.0)
	var x := centre.x - wide * 0.5
	text(Vector2(x, centre.y + 5.0), kind, GOTHIC, size, Color(DIM, fade))
	x += width_of(kind, GOTHIC, size) + 16.0
	for index in danger:
		diamond(Vector2(x + 5.0, centre.y), 5.5, Color(BLOOD, fade))
		x += 15.0
	if not gives.is_empty():
		x += 10.0
		sign_of(Vector2(x + 7.0, centre.y), 7.0, told.reward, Color(colour, fade))
		text(Vector2(x + 22.0, centre.y + 5.0), gives, GOTHIC_B, size, Color(colour, fade))


# The chapter's whole route as one thread across the top: the way walked in
# gold, the ways open as rings, the ways the cursor's pick would close gone
# dark, the boss a lozenge at its end.
func thread_spot(point: RouteMap.Waypoint) -> Vector2:
	var route := model.route
	var gap := (THREAD_TO - THREAD_FROM) / route.size()
	if point == null:
		return Vector2(THREAD_FROM, THREAD_Y)
	var row := route.nodes(point.layer).find(point)
	return Vector2(THREAD_FROM + gap * (point.layer + 1), THREAD_Y + (row - (route.nodes(point.layer).size() - 1) * 0.5) * 19.0)


func _thread() -> void:
	var route := model.route
	var chosen := model.selected()
	var kept := model.reach_from([chosen]) if chosen != null else {}
	var colour := light_of(model.tell(chosen)) if chosen != null else PALE
	var walked := model.run.taken
	for point: RouteMap.Waypoint in route.nodes(0):
		_strand(null, point, walked, kept, colour)
	for index in route.size() - 1:
		for from: RouteMap.Waypoint in route.nodes(index):
			for to: RouteMap.Waypoint in from.next:
				_strand(from, to, walked, kept, colour)
	draw_circle(thread_spot(null), 3.0, GOLD if not walked.is_empty() else PALE)
	for index in route.size():
		for point: RouteMap.Waypoint in route.nodes(index):
			var at := thread_spot(point)
			var state := model.mark(point)
			zone(Rect2(at - Vector2(16.0, 9.5), Vector2(32.0, 19.0)), [&"node", point])
			if point.area.boss != null:
				diamond(at, 9.0, BLOOD if not model.veiled(point) else Color(BLOOD, 0.45))
				ring_of(at, 12.0, Color(BLOOD, 0.5 + 0.3 * breath(1.6)), 4, 1.0, PI * 0.5)
				continue
			match state:
				ProtoRoute.Mark.TAKEN:
					draw_circle(at, 4.5, GOLD)
				ProtoRoute.Mark.OPEN:
					var mine := point == chosen
					draw_circle(at, 6.5 if mine else 5.0, VOID)
					if mine:
						draw_circle(at, 4.0, colour)
						ring(at, 8.5 + breath() * 1.5, colour, 1.5)
					else:
						ring(at, 5.0, Color(PALE, 0.9 - 0.6 * arming()), 1.5)
				ProtoRoute.Mark.AHEAD:
					var stays := kept.has(point)
					if point.area.is_event():
						diamond(at, 4.5, Color(VIOLET, 0.85 if stays else 0.22))
					else:
						draw_circle(at, 3.5, Color(PALE, 0.75 if stays else 0.2))
				_:
					draw_circle(at, 2.5, Color(PALE, 0.16))
			if peek == point:
				ring(at, 9.0, PALE, 1.0)
	if peek != null:
		_whisper(peek)


func _strand(from: RouteMap.Waypoint, to: RouteMap.Waypoint, walked: Array, kept: Dictionary, colour: Color) -> void:
	var a := thread_spot(from)
	var b := thread_spot(to)
	var at := walked.find(to)
	if at >= 0 and (from == null and at == 0 or at > 0 and walked[at - 1] == from):
		draw_line(a, b, GOLD, 2.0, true)
	elif from == model.here() and model.open.has(to):
		var mine := to == model.selected()
		draw_line(a, b, colour if mine else Color(PALE, 0.5 - 0.35 * arming()), 2.0 if mine else 1.0, true)
	elif from != null and model.reach.has(from) and from.layer >= model.run.layer:
		draw_line(a, b, Color(colour, 0.55) if kept.has(from) else Color(PALE, 0.1), 1.0, true)
	else:
		draw_line(a, b, Color(PALE, 0.07), 1.0, true)


# A small word under the thread on the area pointed at there.
func _whisper(point: RouteMap.Waypoint) -> void:
	var told := model.tell(point)
	var at := thread_spot(point)
	var rect := Rect2(clampf(at.x - 170.0, 420.0, 1180.0 - 340.0), 112.0, 340.0, 84.0)
	plate(rect, Color(0.03, 0.03, 0.045, 0.94), Color(PALE, 0.22), 3.0)
	draw_line(at + Vector2(0.0, 12.0), Vector2(at.x, rect.position.y), Color(PALE, 0.3), 1.0)
	text(Vector2(rect.position.x + 18.0, rect.position.y + 34.0), told.name, MINCHO_B, 20, PALE)
	text(Vector2(rect.position.x, rect.position.y + 32.0), told.state, GOTHIC, 13, DIM, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 18.0)
	if told.veiled:
		text(Vector2(rect.position.x + 18.0, rect.position.y + 62.0), told.goal, GOTHIC, 13, DIM)
		return
	var wide := _signs_width(told)
	_signs(Vector2(rect.position.x + 18.0 + wide * 0.5, rect.position.y + 58.0), told, light_of(told), 1.0, true)


func _signs_width(told: Dictionary) -> float:
	var gives: String = "" if told.boss else ("取引" if told.event else told.reward_words)
	var danger: int = told.danger
	return width_of(told.kind, GOTHIC, 13) + (16.0 + danger * 15.0 if danger > 0 else 0.0) + (40.0 + width_of(gives, GOTHIC_B, 13) if not gives.is_empty() else 0.0)


# The chapter at the top left; her health, level, echo and boons at the top right.
func _top() -> void:
	text(Vector2(52.0, 44.0), Chapters.short_name(model.chapter), GOTHIC, 14, DIM)
	text(Vector2(52.0, 78.0), Chapters.title(model.chapter), MINCHO_B, 28, PALE)
	text(Vector2(52.0, 104.0), "%s　／　%s" % [layer_words(), span_words()], GOTHIC, 14, DIM)
	if not model.note.is_empty():
		text(Vector2(52.0, 134.0), model.note, MINCHO_M, 15, Color(GOLD, 0.9))
	var right := 1548.0
	text(Vector2(right - 300.0, 44.0), "HP", GOTHIC_B, 13, CRIMSON)
	text(Vector2(right - 270.0, 46.0), "%d" % model.hp(), MINCHO_B, 24, PALE)
	text(Vector2(right - 270.0 + width_of("%d" % model.hp(), MINCHO_B, 24) + 6.0, 46.0), "/ %d" % model.max_hp(), MINCHO_M, 15, DIM)
	text(Vector2(right - 120.0, 46.0), "Lv %d" % model.run.progression.level, MINCHO_B, 18, PALE, HORIZONTAL_ALIGNMENT_RIGHT, 120.0)
	var bar := Rect2(right - 300.0, 56.0, 300.0, 6.0)
	draw_rect(bar, Color(1.0, 1.0, 1.0, 0.1))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * model.hp() / float(model.max_hp()), bar.size.y)), CRIMSON)
	sign_of(Vector2(right - 292.0, 86.0), 7.0, AreaData.Reward.ECHO, AZURE)
	text(Vector2(right - 276.0, 92.0), "残響", GOTHIC, 13, DIM)
	text(Vector2(right - 240.0, 93.0), UIFormat.amount(model.run.echo), MINCHO_B, 20, PALE)
	var x := right - 30.0
	var held := boons()
	for index in range(held.size() - 1, -1, -1):
		emblem(Vector2(x + 15.0, 86.0), 15.0, held[index][0])
		x -= 36.0
	if not model.run.curses.is_empty():
		text(Vector2(right - 300.0, 120.0), "呪い：" + model.run.curse_names(), GOTHIC_B, 13, BLOOD, HORIZONTAL_ALIGNMENT_RIGHT, 300.0)


# What waits behind the gate turned to, at her left; what it gives, at her
# right.
func _weigh() -> void:
	var point := model.selected()
	if point == null:
		return
	var told := model.tell(point)
	var colour := light_of(told)
	var fade := (0.25 + 0.75 * eased(&"move", MOVE_TIME) if since(&"move") < 0.6 else 1.0) * eased(&"open", OPEN_TIME)
	# Left: what waits.
	var x := LEFT.position.x
	var y := LEFT.position.y + 20.0
	spaced(Vector2(x, y), "待ち受けるもの", GOTHIC_B, 13, Color(BLOOD, fade), 4.0)
	HubUI.trail(self, Vector2(x + 150.0, y - 5.0), Vector2(LEFT.end.x, y - 5.0), Color(BLOOD, 0.5 * fade))
	y += 40.0
	if told.event:
		text(Vector2(x, y), "戦闘なし", MINCHO_B, 24, Color(PALE, fade))
		y += 34.0
		paragraph(Vector2(x, y), told.summary, GOTHIC, 15, Color(DIM, fade), LEFT.size.x)
	else:
		for index in 3:
			var at := Vector2(x + 10.0 + index * 24.0, y - 9.0)
			if index < told.danger:
				diamond(at, 9.0, Color(BLOOD, fade))
			else:
				ring_of(at, 9.0, Color(FAINT, fade), 4, 1.0, PI * 0.5)
		text(Vector2(x + 86.0, y), told.goal, MINCHO_B, 22, Color(PALE, fade))
		text(Vector2(x, y), "目安 " + told.time, GOTHIC, 14, Color(DIM, fade), HORIZONTAL_ALIGNMENT_RIGHT, LEFT.size.x)
		y += 16.0
		var tile_x := x
		for entry: Array in told.foes:
			var tile := foe_tile(entry[0], entry[1])
			if tile != null:
				if not entry[1]:
					draw_circle(Vector2(tile_x + 23.0, y + 23.0), 23.0, Color(1.0, 1.0, 1.0, 0.07 * fade))
				draw_texture_rect(tile, Rect2(tile_x, y, 46.0, 46.0), false, Color(1.0, 1.0, 1.0, fade))
			tile_x += 54.0
		y += 70.0
		text(Vector2(x, y), told.summary if not told.boss else "%s　%s" % [tr(point.area.boss.epithet), told.summary], GOTHIC, 15, Color(DIM, fade))
	# Right: what it gives, and where it leads.
	x = RIGHT.position.x
	y = RIGHT.position.y + 20.0
	var heading := spaced(Vector2(RIGHT.end.x - 76.0, y), "得るもの", GOTHIC_B, 13, Color(colour, fade), 4.0)
	HubUI.trail(self, Vector2(RIGHT.end.x - heading - 14.0, y - 5.0), Vector2(x, y - 5.0), Color(colour, 0.5 * fade))
	y += 44.0
	if told.boss:
		text(Vector2(x, y), "この章の踏破", MINCHO_B, 28, Color(colour, fade), HORIZONTAL_ALIGNMENT_RIGHT, RIGHT.size.x)
	elif told.event:
		paragraph(Vector2(x, y - 4.0), told.reward_words, MINCHO_B, 22, Color(colour, fade), RIGHT.size.x, 8.0, 2, HORIZONTAL_ALIGNMENT_RIGHT)
		sign_of(Vector2(RIGHT.end.x - width_of(told.reward_words, MINCHO_B, 22) - 22.0, y - 12.0), 9.0, -1, Color(colour, fade))
	else:
		var words: String = "残響 %s" % UIFormat.amount(told.echo) if told.reward == AreaData.Reward.ECHO else told.reward_words
		text(Vector2(x, y), words, MINCHO_B, 30, Color(colour, fade), HORIZONTAL_ALIGNMENT_RIGHT, RIGHT.size.x)
		sign_of(Vector2(RIGHT.end.x - width_of(words, MINCHO_B, 30) - 26.0, y - 11.0), 12.0, told.reward, Color(colour, fade))
		if told.reward != AreaData.Reward.ECHO and told.echo > 0:
			y += 30.0
			text(Vector2(x, y), "＋ 残響 %s" % UIFormat.amount(told.echo), GOTHIC, 15, Color(AZURE, fade), HORIZONTAL_ALIGNMENT_RIGHT, RIGHT.size.x)
	# Where the gate leads on.
	if not told.boss and told.ways > 0:
		y = RIGHT.position.y + 138.0
		var leads := point.next
		if (leads[0] as RouteMap.Waypoint).area.boss != null:
			text(Vector2(x, y), "その先　ボスへ", GOTHIC_B, 15, Color(BLOOD, fade), HORIZONTAL_ALIGNMENT_RIGHT, RIGHT.size.x)
		else:
			text(Vector2(x, y), "その先　%dつの道" % leads.size(), GOTHIC_B, 15, Color(PALE, fade), HORIZONTAL_ALIGNMENT_RIGHT, RIGHT.size.x)
			var closed := model.closes(point).size()
			if closed > 0:
				text(Vector2(x, y + 24.0), "選ぶと %dつの場所へは行けなくなる" % closed, GOTHIC, 14, Color(DIM, fade), HORIZONTAL_ALIGNMENT_RIGHT, RIGHT.size.x)
			var at := RIGHT.end.x - width_of("その先　%dつの道" % leads.size(), GOTHIC_B, 15) - 28.0
			for index in range(leads.size() - 1, -1, -1):
				var next := model.tell(leads[index])
				sign_of(Vector2(at, y - 5.0), 7.0, next.reward, Color(light_of(next), fade))
				for pip in next.danger:
					diamond(Vector2(at - 14.0 - pip * 9.0, y - 5.0), 3.5, Color(BLOOD, fade))
				at -= 26.0 + next.danger * 9.0 + 10.0


# The question at her feet, and the keys.
func _prompt() -> void:
	var asked := arming()
	if asked > 0.0:
		var colour := light_of(model.tell(model.selected()))
		text(Vector2(500.0, 836.0), "この道を往く", MINCHO_B, 24, Color(PALE, asked), HORIZONTAL_ALIGNMENT_CENTER, 600.0)
		text(Vector2(500.0, 860.0), "Enter でもう一度　／　Esc で考え直す　　選ばなかった門は閉ざされる", GOTHIC, 13, Color(colour, asked), HORIZONTAL_ALIGNMENT_CENTER, 600.0)
		zone(Rect2(600.0, 812.0, 400.0, 56.0), [&"go"])
	var x := 52.0
	for pair: Array in [["← / →", "門を選ぶ"], ["Enter", "進む"], ["1〜3", "すぐ選ぶ"], ["Esc", "やめる" if model.armed else "メニュー"]]:
		text(Vector2(x, 880.0), pair[0], GOTHIC, 14, FAINT)
		x += width_of(pair[0], GOTHIC, 14) + 10.0
		text(Vector2(x, 880.0), pair[1], GOTHIC, 14, DIM)
		x += width_of(pair[1], GOTHIC, 14) + 28.0


# Her figure: at the fork, or walking into the gate's light once the pick is
# gone ahead with, the light flooding out over the screen.
func _walk() -> void:
	if hero == null or not going:
		return
	var share := clampf(since(&"go") / go_time(), 0.0, 1.0)
	var told := model.tell(model.selected())
	var gate := Vector2(gate_x(model.cursor), FLOOR)
	var along_way := smoothstep(0.0, 0.75, share)
	var next := HERO.lerp(gate, along_way)
	hero.step(next - hero.position)
	hero.position = next
	hero.scale = Vector2.ONE * lerpf(1.0, 0.62, along_way)
	hero.modulate = Color.WHITE.lerp(Color(0.05, 0.04, 0.06), along_way * 0.8)
	glow(gate + Vector2(0.0, -GATE.y * 0.4), 200.0 + 1700.0 * smoothstep(0.25, 0.9, share), Color(light_of(told).lerp(Color.WHITE, 0.5), 0.9 * smoothstep(0.2, 0.7, share)))
