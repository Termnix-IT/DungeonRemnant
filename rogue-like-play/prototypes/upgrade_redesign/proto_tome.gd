class_name ProtoTome
extends ProtoScreen

# Prototype B, the tome of training: the same book as the status page and
# the bestiary's paper (the shipped book's shader and painted parchment),
# with a chapter to a branch. The left page draws the branch as a lineage in
# ink, as a family tree is drawn: the lantern at its head, each upgrade a
# painted miniature under the one it grows from, its name written beneath
# and its ranks as small lozenges. The right page is the chosen upgrade as
# an entry: its figure now and next, what it does, its price, and a seal of
# red wax pressed to buy it. Up and down follow the lineage, left and right
# go between upgrades of one generation, Q/E turn the chapters.

const BOOK := preload("res://ui/grimoire/grimoire_book.gdshader")
const DESK := """
shader_type canvas_item;
void fragment() {
	vec2 p = UV - vec2(0.5, 0.45);
	float light = exp(-dot(p * vec2(1.3, 1.8), p * vec2(1.3, 1.8)) * 2.2);
	COLOR = vec4(mix(vec3(0.030, 0.026, 0.024), vec3(0.115, 0.085, 0.060), light), 1.0);
}
"""
const AT := Vector2(40.0, 110.0)
const DESIGN := Vector2(1520.0, 686.0)
const LEFT := 116.0
const RIGHT := 784.0
const PAGE_WIDTH := 560.0
const TAB_LEFT := 1400.0
const TAB_HEIGHT := 104.0
const TAB_STEP := 114.0
const TAB_TOP := 44.0
const HEAD_Y := 182.0
const LEVEL_TOP := 278.0
const LEVEL_STEP := 108.0
const NODE := 27.0
const SEAL_AT := Vector2(RIGHT + PAGE_WIDTH - 74.0, 590.0)
const INK := Color("2a2018")
const SEPIA := Color("5f4630")
const FAINT := Color("7a6647")
const SEAL := Color("8d2218")
const SEAL_DARK := Color("6d1711")
const SEAL_LIGHT := Color("f1e6cc")
const PAGE_DARK := Color("d6c49e")
const TAB := Color("b8a88a")
const TAB_LIT := Color("d4c4a3")
const SHADOW := Color(0.36, 0.28, 0.2, 0.55)
const PALE := Color("d9cfbb")
const ORDINALS := ["第一章", "第二章", "第三章", "第四章", "第五章"]

var chapter := 0
# Upgrade id -> its place on the left page, for the chapter shown.
var _places: Dictionary = {}


func _init(of: ProtoTree) -> void:
	super(of)
	backdrop(DESK)
	var paper := ColorRect.new()
	paper.position = AT
	paper.size = DESIGN
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.show_behind_parent = true
	var material := ShaderMaterial.new()
	material.shader = BOOK
	material.set_shader_parameter(&"extent", DESIGN)
	material.set_shader_parameter(&"paper_grain", load("res://art/ui/grimoire/paper.png"))
	material.set_shader_parameter(&"leather_grain", load("res://art/ui/grimoire/leather.png"))
	paper.material = material
	add_child(paper)
	_lay_out()


func choose(upgrade: MetaUpgrade) -> void:
	chosen = upgrade
	if not upgrade.branch.is_empty():
		chapter = ProtoTree.BRANCHES.find(upgrade.branch)
	_lay_out()


func _branch() -> StringName:
	return ProtoTree.BRANCHES[chapter]


# Where each upgrade of the chapter stands: a generation to a row, a leaf to
# a column, an upgrade over the middle of what grows from it.
func _lay_out() -> void:
	_places.clear()
	var members := tree.members(_branch())
	var leaves := 0
	for upgrade in members:
		leaves += 1 if tree.children(upgrade).is_empty() else 0
	var step := minf(180.0, PAGE_WIDTH / leaves)
	var next := [LEFT + (PAGE_WIDTH - step * (leaves - 1)) * 0.5]
	_place(members[0], step, next)
	_places[MetaProgress.ROOT] = Vector2(LEFT + PAGE_WIDTH * 0.5, HEAD_Y)


func _place(upgrade: MetaUpgrade, step: float, next: Array) -> float:
	var grown := tree.children(upgrade)
	var x := 0.0
	if grown.is_empty():
		x = next[0]
		next[0] += step
	else:
		for child in grown:
			x += _place(child, step, next)
		x /= grown.size()
	_places[upgrade.id] = Vector2(x, LEVEL_TOP + LEVEL_STEP * (tree.depth(upgrade) - 1))
	return x


func _turn(to: int) -> void:
	to = clampi(to, 0, ProtoTree.BRANCHES.size() - 1)
	if to == chapter:
		return
	_kicks[&"way"] = 1.0 if to > chapter else -1.0
	chapter = to
	chosen = tree.members(_branch())[0]
	_lay_out()
	kick(&"turn")


func _go(upgrade: MetaUpgrade) -> void:
	if upgrade != null and upgrade != chosen:
		chosen = upgrade
		kick(&"move")


# The upgrades of the chosen one's generation, left to right.
func _generation() -> Array[MetaUpgrade]:
	var row: Array[MetaUpgrade] = []
	for upgrade in tree.members(_branch()):
		if tree.depth(upgrade) == tree.depth(chosen):
			row.append(upgrade)
	row.sort_custom(func(a: MetaUpgrade, b: MetaUpgrade): return _places[a.id].x < _places[b.id].x)
	return row


func _key(action: StringName) -> void:
	var at_head := chosen.id == MetaProgress.ROOT
	match action:
		&"up":
			if not at_head:
				_go(tree.parent(chosen))
		&"down":
			if at_head:
				_go(tree.members(_branch())[0])
			else:
				var grown := tree.children(chosen)
				if not grown.is_empty():
					_go(grown[0])
		&"left", &"right":
			if not at_head:
				var row := _generation()
				var to := row.find(chosen) + (1 if action == &"right" else -1)
				if to >= 0 and to < row.size():
					_go(row[to])
		&"prev":
			_turn(chapter - 1)
		&"next":
			_turn(chapter + 1)
		&"accept":
			buy()


func _click(id: Variant) -> void:
	var what: Array = id
	match what[0]:
		&"tab":
			_turn(what[1])
		&"node":
			_go(MetaProgress.find(what[1]))
		&"seal":
			buy()


func _wheel(step: int) -> void:
	_turn(chapter + step)


# --- Drawing ---

func _zone_on_book(rect: Rect2, id: Variant) -> void:
	zone(Rect2(rect.position + AT, rect.size), id)


func _paint() -> void:
	spaced(Vector2(60.0, 72.0), "強化", MINCHO_B, 38, PALE, 6.0)
	text(Vector2(170.0, 70.0), "修練の書", GOTHIC, 16, Color(PALE, 0.6))
	var held := UIFormat.amount(tree.meta.echo)
	var wide := width_of(held, MINCHO_B, 38)
	text(Vector2(1540.0 - wide, 74.0), held, MINCHO_B, 38, Color("e8c98a"))
	ring(Vector2(1540.0 - wide - 26.0, 60.0), 12.0, Color("e8c98a"), 2.0)
	ring(Vector2(1540.0 - wide - 26.0, 60.0), 5.0, Color("e8c98a"), 1.5)
	text(Vector2(1540.0 - wide - 110.0, 70.0), "残響", GOTHIC, 16, Color(PALE, 0.6))
	var x := 60.0
	for pair: Array in [["Esc", "戻る"], ["Enter", "封を押す"], ["↑ ↓", "系譜をたどる"], ["← →", "同じ代"], ["Q / E", "章"]]:
		text(Vector2(x, 852.0), pair[0], GOTHIC_B, 16, PALE)
		x += width_of(pair[0], GOTHIC_B, 16) + 12.0
		text(Vector2(x, 852.0), pair[1], GOTHIC, 16, Color(PALE, 0.6))
		x += width_of(pair[1], GOTHIC, 16) + 40.0
	draw_set_transform(AT)
	_paint_tabs()
	var fade := eased(&"turn", 0.24)
	var way := float(_kicks.get(&"way", 0.0))
	draw_set_transform(AT + Vector2(16.0 * way * (1.0 - fade), 0.0))
	modulate_ink = fade
	_paint_lineage()
	_paint_entry()
	draw_set_transform(Vector2.ZERO)


# How far the pages' ink has come in after a chapter was turned.
var modulate_ink := 1.0


func _ink(colour: Color, share := 1.0) -> Color:
	return Color(colour, colour.a * share * modulate_ink)


func _paint_tabs() -> void:
	for index in ProtoTree.BRANCHES.size():
		var here := index == chapter
		var rect := Rect2(TAB_LEFT, TAB_TOP + TAB_STEP * index, 64.0 if here else 48.0, TAB_HEIGHT)
		draw_rect(Rect2(rect.position + Vector2(0.0, 4.0), rect.size), Color(INK, 0.35))
		draw_rect(rect, SEAL if here else (TAB_LIT if hovered(&"tab", index) else TAB))
		draw_rect(Rect2(rect.position, Vector2(6.0, rect.size.y)), Color(INK, 0.16))
		var label: String = ProtoTree.BRANCH_NAMES[ProtoTree.BRANCHES[index]]
		var y := rect.position.y + (TAB_HEIGHT - label.length() * 21.0) * 0.5 + 17.0
		for letter in label.length():
			draw_string(MINCHO_B, Vector2(rect.position.x + 6.0, y), label[letter], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 6.0, 17, SEAL_LIGHT if here else INK)
			y += 21.0
		# A drop of wax on a chapter the echo held can buy from.
		if tree.open_count(ProtoTree.BRANCHES[index]) > 0 and not here:
			draw_circle(rect.position + Vector2(rect.size.x - 12.0, 12.0), 5.0, SEAL)
		_zone_on_book(rect, [&"tab", index])


func _rule(y: float, left: float, wide: float) -> void:
	var mid := left + wide * 0.5
	draw_line(Vector2(left, y), Vector2(mid - 12.0, y), _ink(SEPIA, 0.7), 1.0)
	draw_line(Vector2(mid + 12.0, y), Vector2(left + wide, y), _ink(SEPIA, 0.7), 1.0)
	diamond(Vector2(mid, y), 5.0, _ink(SEPIA))


# An emblem as a painted miniature in a double ring of ink; one that still
# waits on another as its faded shadow.
func _miniature(centre: Vector2, radius: float, key: String, known: bool) -> void:
	draw_circle(centre + Vector2(1.5, 2.5), radius + 3.0, _ink(INK, 0.22))
	if known:
		emblem(centre, radius, key, Color(1.0, 1.0, 1.0, modulate_ink))
	else:
		draw_circle(centre, radius, _ink(PAGE_DARK))
		emblem(centre, radius, key, _ink(SHADOW))
	ring(centre, radius, _ink(INK), 2.0)
	ring(centre, radius + 4.5, _ink(SEPIA, 0.8), 1.0)


# An upgrade's ranks as lozenges, centred on `at`.
func _lozenges(at: Vector2, upgrade: MetaUpgrade, size: float) -> void:
	var count := upgrade.max_rank()
	var step := size * 2.0 + 5.0
	for index in count:
		var centre := Vector2(at.x - step * (count - 1) * 0.5 + step * index, at.y)
		if index < tree.rank(upgrade):
			diamond(centre, size, _ink(SEAL))
		else:
			diamond(centre, size, _ink(SEPIA, 0.9))
			diamond(centre, size - 1.6, _ink(PAGE_DARK.lightened(0.3)))


func _wax(centre: Vector2, radius: float, letter: String, press := 1.0, alpha := 1.0) -> void:
	var points := PackedVector2Array()
	var under := PackedVector2Array()
	for index in 40:
		var wobble := 1.0 + 0.045 * sin(index * 2.3 + radius) + 0.03 * sin(index * 5.1)
		var point := centre + Vector2.from_angle(TAU * index / 40.0) * radius * press * wobble
		points.append(point)
		under.append(point + Vector2(1.5, 3.0))
	draw_colored_polygon(under, _ink(INK, 0.3 * alpha))
	draw_colored_polygon(points, _ink(SEAL, alpha))
	ring(centre, radius * press * 0.72, _ink(SEAL_DARK, alpha), 2.0)
	ring(centre - Vector2(1.0, 1.5), radius * press * 0.9, _ink(SEAL_LIGHT, 0.3 * alpha), 1.5, PI * 1.1, PI * 1.7)
	var size := int(radius * press * 0.72)
	draw_string(MINCHO_B, Vector2(centre.x - radius, centre.y + size * 0.36), letter, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, size, _ink(SEAL_LIGHT, 0.95 * alpha))


func _dashes(from: Vector2, to: Vector2, colour: Color, wide: float) -> void:
	draw_dashed_line(from, to, colour, wide, 6.0)


# The left page: the chapter's head and the branch's lineage.
func _paint_lineage() -> void:
	var branch := _branch()
	var tally := tree.tally(branch)
	text(Vector2(LEFT, 54.0), ORDINALS[chapter], MINCHO_M, 16, _ink(SEPIA), HORIZONTAL_ALIGNMENT_CENTER, PAGE_WIDTH)
	text(Vector2(LEFT, 98.0), str(ProtoTree.BRANCH_NAMES[branch]), MINCHO_B, 40, _ink(INK), HORIZONTAL_ALIGNMENT_CENTER, PAGE_WIDTH)
	text(Vector2(LEFT, 124.0), "修めた段　%d / %d" % [tally[0], tally[1]], MINCHO_M, 16, _ink(SEPIA), HORIZONTAL_ALIGNMENT_CENTER, PAGE_WIDTH)
	_rule(142.0, LEFT, PAGE_WIDTH)
	# The lines first, each from an upgrade down to what grows from it.
	var members := tree.members(branch)
	for upgrade in members:
		var from: Vector2 = _places[upgrade.parent]
		var to: Vector2 = _places[upgrade.id]
		var reach := 20.0 if upgrade.parent == MetaProgress.ROOT else NODE + 38.0
		var bend := to.y - NODE - 12.0
		var points := [Vector2(from.x, from.y + reach), Vector2(from.x, bend), Vector2(to.x, bend), Vector2(to.x, to.y - NODE - 6.0)]
		var state := tree.state(upgrade)
		for index in 3:
			if tree.rank(upgrade) > 0:
				draw_line(points[index], points[index + 1], _ink(INK), 2.0)
			elif state == ProtoTree.State.LOCKED:
				_dashes(points[index], points[index + 1], _ink(FAINT, 0.8), 1.2)
			else:
				draw_line(points[index], points[index + 1], _ink(SEPIA), 1.4)
	# The lantern at the lineage's head.
	var head: Vector2 = _places[MetaProgress.ROOT]
	var root := ProtoTree.root()
	_miniature(head, 16.0, root.emblem, true)
	text(Vector2(head.x + 30.0, head.y + 6.0), tr(root.display_name), MINCHO_M, 15, _ink(SEPIA))
	if chosen == root:
		ring(head, 25.0, _ink(SEAL), 2.5)
	_zone_on_book(Rect2(head - Vector2.ONE * 22.0, Vector2.ONE * 44.0), [&"node", root.id])
	for upgrade in members:
		var at: Vector2 = _places[upgrade.id]
		var state := tree.state(upgrade)
		var locked := state == ProtoTree.State.LOCKED
		_miniature(at, NODE, upgrade.emblem, not locked)
		var here := upgrade == chosen
		if here:
			ring(at, NODE + 7.5, _ink(SEAL), 3.0)
		elif hovered(&"node", upgrade.id):
			ring(at, NODE + 7.5, _ink(SEPIA, 0.7), 1.5)
		if state == ProtoTree.State.BUY:
			var breath := 0.5 + 0.5 * sin(clock * 3.0)
			draw_circle(at + Vector2(NODE * 0.78, -NODE * 0.78), 6.5 + breath, _ink(SEAL))
			ring(at + Vector2(NODE * 0.78, -NODE * 0.78), 6.5 + breath, _ink(SEAL_DARK), 1.2)
		var name := tr(upgrade.display_name)
		text(Vector2(at.x - 90.0, at.y + NODE + 22.0), name, MINCHO_B if here else MINCHO_M, 15, _ink(FAINT if locked else INK), HORIZONTAL_ALIGNMENT_CENTER, 180.0)
		_lozenges(Vector2(at.x, at.y + NODE + 31.0), upgrade, 3.5)
		_zone_on_book(Rect2(at.x - 60.0, at.y - NODE - 8.0, 120.0, NODE * 2.0 + 50.0), [&"node", upgrade.id])


# The right page: the chosen upgrade as an entry, and its seal.
func _paint_entry() -> void:
	var upgrade := chosen
	var state := tree.state(upgrade)
	var locked := state == ProtoTree.State.LOCKED
	var branch_name: String = ProtoTree.BRANCH_NAMES[upgrade.branch]
	text(Vector2(RIGHT, 54.0), branch_name if upgrade.branch.is_empty() else "%sの系譜" % branch_name, MINCHO_M, 16, _ink(SEPIA), HORIZONTAL_ALIGNMENT_CENTER, PAGE_WIDTH)
	_miniature(Vector2(RIGHT + 58.0, 124.0), 50.0, upgrade.emblem, not locked)
	text(Vector2(RIGHT + 132.0, 122.0), tr(upgrade.display_name), MINCHO_B, 40, _ink(INK))
	var count := upgrade.max_rank()
	_lozenges(Vector2(RIGHT + 132.0 + (count * 21.0 - 5.0) * 0.5, 152.0), upgrade, 8.0)
	text(Vector2(RIGHT + 132.0 + count * 21.0 + 10.0, 158.0), "%d / %d 段" % [tree.rank(upgrade), count], MINCHO_M, 16, _ink(SEPIA))
	_rule(200.0, RIGHT, PAGE_WIDTH)
	var y := 248.0
	var figure := tree.figure(upgrade)
	if not figure.is_empty():
		y += paragraph(Vector2(RIGHT, y), figure, MINCHO_B, 24, _ink(INK), PAGE_WIDTH, 18.0)
	y += paragraph(Vector2(RIGHT, y), tree.note(upgrade), MINCHO_M, 20, _ink(INK), PAGE_WIDTH, 16.0)
	var waits := tree.waits(upgrade)
	if not waits.is_empty():
		paragraph(Vector2(RIGHT, y), waits, MINCHO_M, 18, _ink(SEAL), PAGE_WIDTH)
	# The price, the echo held, and the seal.
	draw_line(Vector2(RIGHT, 520.0), Vector2(RIGHT + PAGE_WIDTH, 520.0), _ink(INK, 0.8), 1.5)
	var cost := tree.price(upgrade)
	var seal := SEAL_AT + Vector2(refusal(), 0.0)
	if cost >= 0:
		text(Vector2(RIGHT, 562.0), "必要", MINCHO_M, 16, _ink(SEPIA))
		text(Vector2(RIGHT + 46.0, 566.0), UIFormat.amount(cost), MINCHO_B, 34, _ink(INK if state == ProtoTree.State.BUY else FAINT))
		text(Vector2(RIGHT + 190.0, 562.0), "所持", MINCHO_M, 16, _ink(SEPIA))
		text(Vector2(RIGHT + 236.0, 566.0), UIFormat.amount(tree.meta.echo), MINCHO_B, 34, _ink(INK))
	var line := ""
	match state:
		ProtoTree.State.FULL:
			line = "この頁は修め終えた"
		ProtoTree.State.LOCKED:
			line = "まだ封を押せない"
		ProtoTree.State.SHORT:
			line = "残響があと%s足りない" % UIFormat.amount(tree.missing(upgrade))
		_:
			line = "Enter　封を押して%sする" % tree.verb(upgrade)
	text(Vector2(RIGHT, 612.0), line, MINCHO_B if state == ProtoTree.State.BUY else MINCHO_M, 20, _ink(SEAL if state in [ProtoTree.State.BUY, ProtoTree.State.SHORT] else SEPIA))
	var pressed := buying(upgrade)
	if pressed < 1.0:
		var share := clampf(pressed * BUY_TIME / 0.2, 0.0, 1.0)
		_wax(seal, 44.0, "得", lerpf(2.4, 1.0, 1.0 - pow(1.0 - share, 3.0)), share)
		if pressed * BUY_TIME > 0.18:
			var spread := clampf((pressed * BUY_TIME - 0.18) / (BUY_TIME - 0.18), 0.0, 1.0)
			ring(seal, 52.0 + 44.0 * spread, _ink(SEAL, 0.55 * (1.0 - spread)), 2.0)
	elif state == ProtoTree.State.FULL:
		_wax(seal, 44.0, "済")
	else:
		var able := state == ProtoTree.State.BUY
		var colour := SEAL if able else FAINT
		if able:
			draw_circle(seal, 44.0, _ink(SEAL, 0.10 + (0.10 if hovered(&"seal") else 0.0) + 0.05 * sin(clock * 3.0)))
		dashed_ring(seal, 44.0, _ink(colour), 2.0 if able else 1.4, 22)
		text(Vector2(seal.x - 44.0, seal.y + 8.0), "封" if able else "―", MINCHO_B, 26, _ink(colour, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 88.0)
	_zone_on_book(Rect2(SEAL_AT - Vector2.ONE * 50.0, Vector2.ONE * 100.0), [&"seal"])
