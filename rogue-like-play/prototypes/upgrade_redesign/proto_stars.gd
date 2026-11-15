class_name ProtoStars
extends ProtoScreen

# Prototype C, the echo's star chart: the whole tree on one sheet of night
# sky, read like an astrolabe. The lantern is the pole; every upgrade is a
# star on the ring of its generation (how many steps it stands from the
# lantern), and each branch is a constellation in its own part of the sky.
# Nothing is dragged or zoomed: all of it is in sight at once. The stars of
# the constellation the cursor is in carry their names; a star held burns
# gold with rays, one the echo held can light breathes blue, one that waits
# is dark. The cartouche on the right is the chosen star in full. Arrows go
# to the nearest star that way, Q/E to the next constellation.

const SKY := """
shader_type canvas_item;
%s
void fragment() {
	vec2 p = UV * vec2(1600.0, 900.0);
	float cloud = fbm(p * 0.0035 + vec2(3.0, 1.0));
	vec3 col = mix(vec3(0.016, 0.022, 0.046), vec3(0.050, 0.070, 0.135), cloud * cloud * 1.6);
	col += vec3(0.20, 0.12, 0.30) * pow(fbm(p * 0.006 + vec2(11.0, 7.0)), 3.0) * 0.5;
	vec2 cell = floor(p / 11.0);
	vec2 in_cell = fract(p / 11.0) - 0.5 + (vec2(hash(cell + 1.0), hash(cell + 2.0)) - 0.5) * 0.6;
	float speck = step(0.985, hash(cell)) * smoothstep(0.16, 0.0, length(in_cell));
	float twinkle = 0.6 + 0.4 * sin(TIME * (0.6 + hash(cell + 3.0) * 1.6) + hash(cell + 9.0) * 6.28);
	col += vec3(0.75, 0.82, 1.0) * speck * twinkle * (0.25 + 0.5 * hash(cell + 5.0));
	float lamp = exp(-length(p - vec2(590.0, 452.0)) / 210.0);
	col += vec3(1.0, 0.78, 0.42) * lamp * 0.16;
	col *= smoothstep(1.4, 0.4, length((UV - 0.5) * vec2(1.1, 1.4)));
	COLOR = vec4(col, 1.0);
}
""" % NOISE

const POLE := Vector2(590.0, 452.0)
const RINGS := [0.0, 106.0, 180.0, 254.0, 328.0]
const STAR := 20.0
const POLE_STAR := 30.0
# The constellations, clockwise from the top.
const ORDER: Array[StringName] = [&"skill", &"weapon", &"growth", &"special", &"body"]
const AIM_CONE := PI / 3.0
const CARD := Rect2(1130.0, 126.0, 420.0, 668.0)
const PALE := Color("e3e9f7")
const DIM := Color("94a0bd")
const BRASS := Color("c9a45c")
const GOLD := Color("ffdc92")
const BLUE := Color("8cc6ff")
const DARK := Color("3f4962")
const RED := Color("f39584")
const PANEL := Color(0.035, 0.050, 0.095, 0.90)

# Upgrade id -> where its star stands, and at what angle from the pole.
var _places: Dictionary = {}
var _angles: Dictionary = {}
# Branch -> [first angle, last angle] of its part of the sky.
var _parts: Dictionary = {}


func _init(of: ProtoTree) -> void:
	super(of)
	backdrop(SKY)
	_lay_out()


# A leaf to a slot of sky, an upgrade at the middle of what grows from it,
# each on its generation's ring.
func _lay_out() -> void:
	var leaves := 0
	for branch in ORDER:
		for upgrade in tree.members(branch):
			leaves += 1 if tree.children(upgrade).is_empty() else 0
	var slot := TAU / leaves
	var first := 0
	for upgrade in tree.members(ORDER[0]):
		first += 1 if tree.children(upgrade).is_empty() else 0
	var next := [-PI * 0.5 - slot * first * 0.5]
	for branch in ORDER:
		var from: float = next[0]
		_place(tree.members(branch)[0], slot, next)
		_parts[branch] = [from, next[0]]
	_places[MetaProgress.ROOT] = POLE
	_angles[MetaProgress.ROOT] = 0.0


func _place(upgrade: MetaUpgrade, slot: float, next: Array) -> float:
	var grown := tree.children(upgrade)
	var angle := 0.0
	if grown.is_empty():
		angle = next[0] + slot * 0.5
		next[0] += slot
	else:
		for child in grown:
			angle += _place(child, slot, next)
		angle /= grown.size()
	_angles[upgrade.id] = angle
	_places[upgrade.id] = POLE + Vector2.from_angle(angle) * float(RINGS[tree.depth(upgrade)])
	return angle


func _go(upgrade: MetaUpgrade) -> void:
	if upgrade != null and upgrade != chosen:
		chosen = upgrade
		kick(&"move")


# The star a direction leads to: within the cone, one joined to this one
# first, then the nearest.
func _neighbour(direction: Vector2) -> MetaUpgrade:
	var from: Vector2 = _places[chosen.id]
	var best: MetaUpgrade = null
	var best_score := Vector2.INF
	for other in MetaProgress.UPGRADES:
		var offset: Vector2 = _places[other.id] - from
		if other == chosen or absf(offset.angle_to(direction)) > AIM_CONE + 0.001:
			continue
		var joined := other.parent == chosen.id or chosen.parent == other.id
		var score := Vector2(0.0 if joined else 1.0, offset.length())
		if score < best_score:
			best_score = score
			best = other
	return best


func _constellation(step: int) -> void:
	var at := ORDER.find(chosen.branch)
	var to := posmod(at + step, ORDER.size()) if at >= 0 else (0 if step > 0 else ORDER.size() - 1)
	_go(tree.members(ORDER[to])[0])


func _key(action: StringName) -> void:
	match action:
		&"up":
			_go(_neighbour(Vector2.UP))
		&"down":
			_go(_neighbour(Vector2.DOWN))
		&"left":
			_go(_neighbour(Vector2.LEFT))
		&"right":
			_go(_neighbour(Vector2.RIGHT))
		&"prev":
			_constellation(-1)
		&"next":
			_constellation(1)
		&"details":
			_go(ProtoTree.root())
		&"accept":
			buy()


func _click(id: Variant) -> void:
	var what: Array = id
	match what[0]:
		&"star":
			_go(MetaProgress.find(what[1]))
		&"part":
			_go(tree.members(what[1])[0])
		&"light":
			buy()


func _wheel(step: int) -> void:
	_constellation(step)


# --- Drawing ---

func _paint() -> void:
	spaced(Vector2(60.0, 72.0), "強化", MINCHO_B, 38, PALE, 6.0)
	text(Vector2(170.0, 70.0), "残響の星図", GOTHIC, 16, DIM)
	var held := UIFormat.amount(tree.meta.echo)
	var wide := width_of(held, MINCHO_B, 38)
	text(Vector2(1540.0 - wide, 74.0), held, MINCHO_B, 38, GOLD)
	_spark(Vector2(1540.0 - wide - 24.0, 60.0), 13.0, GOLD)
	text(Vector2(1540.0 - wide - 106.0, 70.0), "残響", GOTHIC, 16, DIM)
	_paint_instrument()
	_paint_lines()
	_paint_stars()
	_paint_card()
	var x := 60.0
	for pair: Array in [["Esc", "戻る"], ["Enter", "星を灯す"], ["矢印", "近くの星へ"], ["Q / E", "星座"], ["R", "灯へ戻る"]]:
		text(Vector2(x, 884.0), pair[0], GOTHIC_B, 16, PALE)
		x += width_of(pair[0], GOTHIC_B, 16) + 12.0
		text(Vector2(x, 884.0), pair[1], GOTHIC, 16, DIM)
		x += width_of(pair[1], GOTHIC, 16) + 40.0


# A four-pointed star.
func _spark(centre: Vector2, radius: float, colour: Color, turn := 0.0) -> void:
	var points := PackedVector2Array()
	for index in 8:
		points.append(centre + Vector2.from_angle(turn + TAU * index / 8.0 - PI * 0.5) * (radius if index % 2 == 0 else radius * 0.32))
	draw_colored_polygon(points, colour)


# The rings of the generations, the parts of the sky and their names.
func _paint_instrument() -> void:
	for index in range(1, RINGS.size()):
		ring(POLE, RINGS[index], Color(BRASS, 0.20), 1.0)
	var rim: float = RINGS[RINGS.size() - 1] + 34.0
	ring(POLE, rim, Color(BRASS, 0.55), 1.5)
	ring(POLE, rim + 7.0, Color(BRASS, 0.30), 1.0)
	for index in 120:
		var way := Vector2.from_angle(TAU * index / 120.0)
		draw_line(POLE + way * rim, POLE + way * (rim + (7.0 if index % 5 == 0 else 3.5)), Color(BRASS, 0.5), 1.0)
	for branch in ORDER:
		var part: Array = _parts[branch]
		var here := chosen.branch == branch
		var edge := Vector2.from_angle(part[0])
		draw_line(POLE + edge * 70.0, POLE + edge * rim, Color(BRASS, 0.16), 1.0)
		if here:
			draw_arc(POLE, rim + 3.5, part[0], part[1], 48, Color(GOLD, 0.85), 4.0, true)
		# Its name stands outside the rim, read level.
		var mid: float = (float(part[0]) + float(part[1])) * 0.5
		var way := Vector2.from_angle(mid)
		var tally := tree.tally(branch)
		var name := "%s　%d / %d" % [ProtoTree.BRANCH_NAMES[branch], tally[0], tally[1]]
		var size := 18
		var wide := width_of(name, MINCHO_B, size)
		var at := POLE + way * (rim + 24.0) + Vector2(wide * 0.5 * signf(way.x) * (1.0 if absf(way.x) > 0.5 else absf(way.x) * 2.0) - wide * 0.5, 6.0 + 12.0 * way.y)
		at.x = clampf(at.x, 24.0, CARD.position.x - wide - 16.0)
		at.y = clampf(at.y, 40.0, 858.0)
		text(at, name, MINCHO_B, size, GOLD if here else (PALE if hovered(&"part", branch) else DIM))
		zone(Rect2(at - Vector2(6.0, 22.0), Vector2(wide + 12.0, 30.0)), [&"part", branch])
	draw_line(POLE + Vector2.from_angle(float(_parts[ORDER[0]][0])) * 70.0, POLE + Vector2.from_angle(float(_parts[ORDER[0]][0])) * rim, Color(BRASS, 0.16), 1.0)


func _trimmed(upgrade: MetaUpgrade) -> PackedVector2Array:
	var from: Vector2 = _places[upgrade.parent]
	var to: Vector2 = _places[upgrade.id]
	var along := (to - from).normalized()
	return PackedVector2Array([from + along * ((POLE_STAR if upgrade.parent == MetaProgress.ROOT else STAR) + 5.0), to - along * (STAR + 5.0)])


func _paint_lines() -> void:
	for upgrade in MetaProgress.UPGRADES:
		if upgrade.parent.is_empty():
			continue
		var ends := _trimmed(upgrade)
		var state := tree.state(upgrade)
		if tree.rank(upgrade) > 0:
			draw_line(ends[0], ends[1], Color(GOLD, 0.85), 2.0, true)
			# The light that ran out to the star just lit.
			var lit := buying(upgrade)
			if lit < 1.0:
				var head := ends[0].lerp(ends[1], clampf(lit * 2.5, 0.0, 1.0))
				draw_line(ends[0], head, Color(1.0, 1.0, 1.0, 1.0 - lit), 5.0, true)
				glow(head, 26.0, Color(GOLD, 0.8 * (1.0 - lit)))
		elif state == ProtoTree.State.LOCKED:
			draw_dashed_line(ends[0], ends[1], Color(DARK, 0.9), 1.2, 6.0)
		else:
			var breath := 0.5 + 0.5 * sin(clock * 3.0)
			draw_line(ends[0], ends[1], Color(BLUE, (0.35 + 0.35 * breath) if state == ProtoTree.State.BUY else 0.3), 1.5, true)


func _paint_stars() -> void:
	for upgrade in MetaProgress.UPGRADES:
		var at: Vector2 = _places[upgrade.id]
		var pole := upgrade.parent.is_empty()
		var radius := POLE_STAR if pole else STAR
		var state := tree.state(upgrade)
		var held := tree.rank(upgrade) > 0
		var near := pole or chosen.branch == upgrade.branch
		var breath := 0.5 + 0.5 * sin(clock * 3.0 + at.x * 0.01)
		if held:
			glow(at, radius * 2.6, Color(GOLD, 0.32))
			for index in 4:
				var way := Vector2.from_angle(TAU * index / 4.0 + PI * 0.25)
				draw_line(at + way * (radius + 4.0), at + way * (radius + 13.0 + 3.0 * breath), Color(GOLD, 0.8), 1.5, true)
		elif state == ProtoTree.State.BUY:
			glow(at, radius * (2.2 + 0.5 * breath), Color(BLUE, 0.30 + 0.15 * breath))
		draw_circle(at, radius + 2.0, Color(0.02, 0.03, 0.06))
		var tint := Color.WHITE
		if state == ProtoTree.State.LOCKED:
			tint = Color(0.34, 0.38, 0.50, 0.75)
		elif not held:
			tint = Color(0.78, 0.84, 0.95)
		emblem(at, radius, upgrade.emblem, tint if near else Color(tint, tint.a * 0.78))
		var edge := GOLD if held else (BLUE if state == ProtoTree.State.BUY else (DIM if state == ProtoTree.State.SHORT else DARK))
		ring(at, radius + 1.0, edge, 2.0)
		# Its ranks as points of light on an arc under it.
		var count := upgrade.max_rank()
		if count > 1:
			for index in count:
				var spot := at + Vector2.from_angle(PI * 0.5 + (index - (count - 1) * 0.5) * 0.42) * (radius + 9.0)
				draw_circle(spot, 3.0, GOLD if index < tree.rank(upgrade) else Color(0.02, 0.03, 0.06))
				ring(spot, 3.0, GOLD if index < tree.rank(upgrade) else DIM, 1.0)
		if upgrade == chosen:
			ring(at, radius + 9.0, PALE, 2.0)
			for index in 4:
				var way := Vector2.from_angle(TAU * index / 4.0 + clock * 0.4)
				draw_line(at + way * (radius + 9.0), at + way * (radius + 17.0), PALE, 2.0, true)
		elif hovered(&"star", upgrade.id):
			ring(at, radius + 8.0, Color(PALE, 0.6), 1.5)
		# The moment a star is lit.
		var lit := buying(upgrade)
		if lit < 1.0:
			var spread := 1.0 - pow(1.0 - lit, 3.0)
			glow(at, radius * 5.0 * (0.4 + spread), Color(1.0, 0.95, 0.8, 0.7 * (1.0 - lit)))
			ring(at, radius + 10.0 + 70.0 * spread, Color(GOLD, 1.0 - lit), 2.5)
			for index in 8:
				var way := Vector2.from_angle(TAU * index / 8.0)
				draw_line(at + way * (radius + 12.0 + 40.0 * spread), at + way * (radius + 26.0 + 78.0 * spread), Color(GOLD, 1.0 - lit), 2.0, true)
		if near and not pole:
			_paint_name(upgrade, at, radius)
		zone_round(at, radius + 8.0, [&"star", upgrade.id])


# A star's name, on the side away from the pole.
func _paint_name(upgrade: MetaUpgrade, at: Vector2, radius: float) -> void:
	var name := tr(upgrade.display_name)
	var here := upgrade == chosen
	var font := GOTHIC_B if here else GOTHIC
	var wide := width_of(name, font, 14)
	# Under the star, or over it in the upper sky, where under would run
	# into the star it grows from.
	var spot := Vector2(at.x - wide * 0.5, at.y + radius + (31.0 if upgrade.max_rank() > 1 else 24.0))
	if sin(float(_angles[upgrade.id])) < -0.5:
		spot.y = at.y - radius - 13.0
	draw_rect(Rect2(spot + Vector2(-4.0, -15.0), Vector2(wide + 8.0, 20.0)), Color(0.02, 0.03, 0.06, 0.72))
	var locked := tree.state(upgrade) == ProtoTree.State.LOCKED
	text(spot, name, font, 14, PALE if here else (DIM.darkened(0.15) if locked else DIM.lightened(0.25)))


func _paint_card() -> void:
	var upgrade := chosen
	var state := tree.state(upgrade)
	plate(CARD, PANEL, Color(BRASS, 0.8), 2.0, 1.0)
	plate(CARD.grow(-6.0), Color.TRANSPARENT, Color(BRASS, 0.3), 2.0, 1.0)
	for corner: Vector2 in [CARD.position, Vector2(CARD.end.x, CARD.position.y), CARD.end, Vector2(CARD.position.x, CARD.end.y)]:
		diamond(corner, 6.0, BRASS)
	var mid := CARD.position.x + CARD.size.x * 0.5
	var left := CARD.position.x + 32.0
	var inner := CARD.size.x - 64.0
	var branch_name: String = ProtoTree.BRANCH_NAMES[upgrade.branch]
	text(Vector2(CARD.position.x, 164.0), "天の極" if upgrade.branch.is_empty() else "%sの星座　%d番目の輪" % [branch_name, tree.depth(upgrade)], GOTHIC, 14, DIM, HORIZONTAL_ALIGNMENT_CENTER, CARD.size.x)
	var lit := 1.0 - buying(upgrade)
	glow(Vector2(mid, 250.0), 130.0, Color(GOLD if tree.rank(upgrade) > 0 else BLUE, 0.12 + 0.4 * lit))
	medallion(Vector2(mid, 250.0), 66.0, upgrade.emblem, Color(0.42, 0.46, 0.58) if state == ProtoTree.State.LOCKED else Color.WHITE)
	text(Vector2(CARD.position.x, 362.0), tr(upgrade.display_name), MINCHO_B, 32, PALE, HORIZONTAL_ALIGNMENT_CENTER, CARD.size.x)
	var count := upgrade.max_rank()
	for index in count:
		var spot := Vector2(mid + (index - (count - 1) * 0.5) * 30.0, 392.0)
		if index < tree.rank(upgrade):
			_spark(spot, 11.0 + (10.0 * lit if index == tree.rank(upgrade) - 1 else 0.0), GOLD)
		else:
			_spark(spot, 11.0, DARK)
			_spark(spot, 7.0, Color(0.035, 0.050, 0.095))
	draw_line(Vector2(left, 420.0), Vector2(left + inner, 420.0), Color(BRASS, 0.4), 1.0)
	var y := 456.0
	var figure := tree.figure(upgrade)
	if not figure.is_empty():
		draw_multiline_string(GOTHIC_B, Vector2(left, y), figure, HORIZONTAL_ALIGNMENT_CENTER, inner, 20, -1, GOLD)
		y += GOTHIC_B.get_multiline_string_size(figure, HORIZONTAL_ALIGNMENT_CENTER, inner, 20).y + 16.0
	y += paragraph(Vector2(left, y), tree.note(upgrade), GOTHIC, 17, PALE, inner, 14.0)
	var waits := tree.waits(upgrade)
	if not waits.is_empty():
		paragraph(Vector2(left, y), waits, GOTHIC, 16, RED, inner)
	var cost := tree.price(upgrade)
	if cost >= 0:
		draw_line(Vector2(left, 668.0), Vector2(left + inner, 668.0), Color(BRASS, 0.4), 1.0)
		text(Vector2(left, 700.0), "必要", GOTHIC, 15, DIM)
		text(Vector2(left + 44.0, 703.0), UIFormat.amount(cost), MINCHO_B, 28, GOLD if state == ProtoTree.State.BUY else DIM)
		text(Vector2(mid + 10.0, 700.0), "所持", GOTHIC, 15, DIM)
		text(Vector2(mid + 54.0, 703.0), UIFormat.amount(tree.meta.echo), MINCHO_B, 28, PALE)
	var button := Rect2(left + refusal(), 724.0, inner, 50.0)
	var words := ""
	match state:
		ProtoTree.State.FULL:
			words = "灯り終えた星"
		ProtoTree.State.LOCKED:
			words = "まだ灯せない"
		ProtoTree.State.SHORT:
			words = "残響があと%s足りない" % UIFormat.amount(tree.missing(upgrade))
		_:
			words = "Enter　星を灯す（%s）" % tree.verb(upgrade)
	if state == ProtoTree.State.BUY:
		plate(button, Color(BLUE, 0.22 + (0.12 if hovered(&"light") else 0.0) + 0.06 * sin(clock * 3.0)), BLUE, 25.0, 1.5)
		text(Vector2(button.position.x, button.position.y + 32.0), words, GOTHIC_B, 19, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, button.size.x)
	else:
		plate(button, Color(1.0, 1.0, 1.0, 0.04), Color(DIM, 0.4), 25.0, 1.0)
		text(Vector2(button.position.x, button.position.y + 32.0), words, GOTHIC, 17, DIM, HORIZONTAL_ALIGNMENT_CENTER, button.size.x)
	zone(button, [&"light"])
