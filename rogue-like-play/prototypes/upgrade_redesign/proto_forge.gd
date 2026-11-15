class_name ProtoForge
extends ProtoScreen

# Prototype A, the forge's ledger: the upgrades as a list, for finding one
# and buying it quickly. Iron plates down the left are the branches (and one
# for all of them); the list beside them is the branch's upgrades, each one
# row, set in under the one it grows from so the order to buy them in reads
# down the page, with its ranks as notches and its price at the row's end. R
# keeps only what the echo held can buy. The plate on the right is the
# chosen upgrade in full, a gauge of the echo held against its price, and
# the one action. Iron and embers: what can be bought glows.

const WALL := """
shader_type canvas_item;
%s
void fragment() {
	vec2 p = UV * vec2(1600.0, 900.0);
	float soot = fbm(p * 0.006) * 0.6 + fbm(p * 0.03) * 0.4;
	vec3 col = mix(vec3(0.035, 0.037, 0.043), vec3(0.085, 0.088, 0.098), soot);
	float fire = exp(-length((p - vec2(120.0, 980.0)) / vec2(900.0, 620.0)) * 2.2);
	col += vec3(1.0, 0.42, 0.12) * fire * (0.30 + 0.05 * sin(TIME * 2.3) * sin(TIME * 3.7));
	col *= smoothstep(1.35, 0.35, length((UV - 0.5) * vec2(1.1, 1.4)));
	COLOR = vec4(col, 1.0);
}
""" % NOISE

const IRON := Color("1f2227")
const IRON_LIT := Color("2c3038")
const EDGE := Color("474c56")
const STEEL := Color("d6dae0")
const DIM := Color("8f96a1")
const ASH := Color("4d525b")
const EMBER := Color("ffa448")
const EMBER_DEEP := Color("b3481a")
const RED := Color("ec7a62")
const RAIL := Rect2(60.0, 120.0, 240.0, 78.0)
const RAIL_STEP := 88.0
const LIST := Rect2(330.0, 120.0, 680.0, 670.0)
const ROW := 48.0
const ROWS_TOP := 166.0
const VISIBLE := 13
const SHEET := Rect2(1040.0, 120.0, 500.0, 670.0)

# 0: every branch; then ProtoTree.BRANCHES in turn.
var tab := 0
var only_open := false
var rows: Array[MetaUpgrade] = []
var place := 0


func _init(of: ProtoTree) -> void:
	super(of)
	backdrop(WALL)
	_list()


func _list() -> void:
	rows.clear()
	var all: Array[MetaUpgrade] = []
	if tab == 0:
		all.append(ProtoTree.root())
		for branch in ProtoTree.BRANCHES:
			all.append_array(tree.members(branch))
	else:
		all = tree.members(ProtoTree.BRANCHES[tab - 1])
	for upgrade in all:
		if not only_open or tree.state(upgrade) == ProtoTree.State.BUY:
			rows.append(upgrade)
	var at := rows.find(chosen)
	place = at if at >= 0 else clampi(place, 0, maxi(0, rows.size() - 1))
	if not rows.is_empty():
		chosen = rows[place]


func choose(upgrade: MetaUpgrade) -> void:
	chosen = upgrade
	_list()
	if rows.find(upgrade) < 0:
		tab = 0
		only_open = false
		chosen = upgrade
		_list()


func pose(state: StringName) -> void:
	tab = 0
	only_open = false
	super(state)
	if state == &"branch":
		tab = ProtoTree.BRANCHES.find(&"growth") + 1
		_list()
	elif state == &"short":
		tab = ProtoTree.BRANCHES.find(&"skill") + 1
		_list()


func _move(to: int) -> void:
	if rows.is_empty():
		return
	to = clampi(to, 0, rows.size() - 1)
	if to != place:
		place = to
		chosen = rows[place]
		kick(&"move")


func _turn(to: int) -> void:
	to = clampi(to, 0, ProtoTree.BRANCHES.size())
	if to == tab:
		return
	tab = to
	place = 0
	_list()
	if not rows.is_empty():
		chosen = rows[0]
		place = 0
	kick(&"move")


func _key(action: StringName) -> void:
	match action:
		&"up":
			_move(place - 1)
		&"down":
			_move(place + 1)
		&"left", &"prev":
			_turn(tab - 1)
		&"right", &"next":
			_turn(tab + 1)
		&"details":
			only_open = not only_open
			_list()
		&"accept":
			_buy()


func _buy() -> void:
	if rows.is_empty():
		kick(&"refuse")
		return
	if buy():
		_list()


func _click(id: Variant) -> void:
	var what: Array = id
	match what[0]:
		&"tab":
			_turn(what[1])
		&"row":
			_move(what[1])
		&"filter":
			_key(&"details")
		&"buy":
			_buy()


func _wheel(step: int) -> void:
	_move(place + step)


# --- Drawing ---

func _paint() -> void:
	spaced(Vector2(60.0, 72.0), "強化", MINCHO_B, 38, STEEL, 6.0)
	text(Vector2(170.0, 70.0), "鍛冶場の台帳", GOTHIC, 16, DIM)
	_paint_purse()
	_paint_rail()
	_paint_list()
	_paint_sheet()
	_paint_foot()


func _paint_purse() -> void:
	var held := UIFormat.amount(tree.meta.echo)
	var wide := width_of(held, MINCHO_B, 38)
	text(Vector2(1540.0 - wide, 74.0), held, MINCHO_B, 38, EMBER)
	_coin(Vector2(1540.0 - wide - 26.0, 60.0), 12.0, EMBER)
	text(Vector2(1540.0 - wide - 110.0, 70.0), "残響", GOTHIC, 16, DIM)


func _coin(centre: Vector2, radius: float, colour: Color) -> void:
	draw_circle(centre, radius, Color(colour, 0.25))
	ring(centre, radius, colour, 2.0)
	ring(centre, radius * 0.45, colour, 1.5)


func _paint_rail() -> void:
	for index in ProtoTree.BRANCHES.size() + 1:
		var rect := Rect2(RAIL.position + Vector2(0.0, RAIL_STEP * index), RAIL.size)
		var here := index == tab
		plate(rect, IRON_LIT if here or hovered(&"tab", index) else IRON, EMBER if here else EDGE, 4.0, 2.0 if here else 1.0)
		for corner: Vector2 in [Vector2(10.0, 10.0), Vector2(rect.size.x - 10.0, 10.0), Vector2(10.0, rect.size.y - 10.0), Vector2(rect.size.x - 10.0, rect.size.y - 10.0)]:
			draw_circle(rect.position + corner, 2.5, EDGE)
		var name := "すべて" if index == 0 else str(ProtoTree.BRANCH_NAMES[ProtoTree.BRANCHES[index - 1]])
		text(rect.position + Vector2(26.0, 36.0), name, GOTHIC_B, 24, STEEL if here else DIM)
		var held := 0
		var all := 0
		var open := 0
		for branch in ProtoTree.BRANCHES:
			if index == 0 or branch == ProtoTree.BRANCHES[index - 1]:
				var tally := tree.tally(branch)
				held += tally[0]
				all += tally[1]
				open += tree.open_count(branch)
		text(rect.position + Vector2(26.0, 62.0), "%d / %d 段" % [held, all], GOTHIC, 15, DIM)
		if open > 0:
			var mark := rect.position + Vector2(rect.size.x - 44.0, 39.0)
			glow(mark, 26.0, Color(EMBER, 0.35))
			draw_circle(mark, 13.0, EMBER_DEEP)
			text(mark + Vector2(-13.0, 6.0), str(open), GOTHIC_B, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 26.0)
		zone(rect, [&"tab", index])


func _paint_list() -> void:
	plate(LIST, Color(IRON, 0.92), EDGE, 4.0)
	var head := "すべての強化" if tab == 0 else "%sの枝" % ProtoTree.BRANCH_NAMES[ProtoTree.BRANCHES[tab - 1]]
	text(LIST.position + Vector2(20.0, 31.0), head, GOTHIC_B, 18, STEEL)
	var filter := Rect2(LIST.end.x - 214.0, LIST.position.y + 9.0, 200.0, 30.0)
	plate(filter, EMBER_DEEP if only_open else IRON_LIT, EMBER if only_open or hovered(&"filter") else EDGE, 15.0)
	text(filter.position + Vector2(0.0, 21.0), "R　買えるものだけ", GOTHIC_B if only_open else GOTHIC, 15, Color.WHITE if only_open else DIM, HORIZONTAL_ALIGNMENT_CENTER, filter.size.x)
	zone(filter, [&"filter"])
	draw_line(LIST.position + Vector2(0.0, 46.0), LIST.position + Vector2(LIST.size.x, 46.0), EDGE, 1.0)
	if rows.is_empty():
		text(Vector2(LIST.position.x, 330.0), "今の残響で買えるものはない", GOTHIC, 20, DIM, HORIZONTAL_ALIGNMENT_CENTER, LIST.size.x)
		return
	var top := clampi(place - VISIBLE / 2, 0, maxi(0, rows.size() - VISIBLE))
	for index in range(top, mini(rows.size(), top + VISIBLE)):
		_paint_row(index, Rect2(LIST.position.x + 8.0, ROWS_TOP + ROW * (index - top), LIST.size.x - 16.0, ROW - 2.0))
	if top > 0:
		text(Vector2(LIST.position.x + LIST.size.x * 0.5 - 6.0, ROWS_TOP - 4.0), "▲", GOTHIC, 12, DIM)
	if top + VISIBLE < rows.size():
		text(Vector2(LIST.position.x + LIST.size.x * 0.5 - 6.0, LIST.end.y - 4.0), "▼", GOTHIC, 12, DIM)


func _paint_row(index: int, rect: Rect2) -> void:
	var upgrade := rows[index]
	var state := tree.state(upgrade)
	var here := index == place
	var flash := 1.0 - buying(upgrade)
	if here:
		plate(rect, IRON_LIT.lerp(EMBER_DEEP, flash * 0.7), Color.TRANSPARENT, 3.0)
		draw_rect(Rect2(rect.position, Vector2(4.0, rect.size.y)), EMBER)
	elif hovered(&"row", index):
		plate(rect, Color(IRON_LIT, 0.6), Color.TRANSPARENT, 3.0)
	# Set in under the upgrade it grows from, with an elbow to it.
	var steps := 0 if only_open else maxi(0, tree.depth(upgrade) - 1)
	var x := rect.position.x + 20.0 + steps * 24.0
	var mid := rect.position.y + rect.size.y * 0.5
	if steps > 0:
		draw_line(Vector2(x - 14.0, rect.position.y), Vector2(x - 14.0, mid), ASH, 1.5)
		draw_line(Vector2(x - 14.0, mid), Vector2(x - 2.0, mid), ASH, 1.5)
	var locked := state == ProtoTree.State.LOCKED
	medallion(Vector2(x + 18.0, mid), 19.0, upgrade.emblem, Color(0.45, 0.47, 0.52, 0.7) if locked else Color.WHITE)
	var ink := ASH.lightened(0.25) if locked else (STEEL if here or state != ProtoTree.State.FULL else DIM)
	text(Vector2(x + 46.0, mid + 7.0), tr(upgrade.display_name), GOTHIC_B if here else GOTHIC, 20, ink)
	var after := x + 46.0 + width_of(tr(upgrade.display_name), GOTHIC_B, 20) + 14.0
	_notches(Vector2(after, mid - 7.0), upgrade, 7.0, 14.0)
	if tab == 0 and not only_open and tree.depth(upgrade) == 1:
		text(Vector2(rect.end.x - 250.0, mid + 5.0), str(ProtoTree.BRANCH_NAMES[upgrade.branch]), GOTHIC, 14, ASH.lightened(0.2), HORIZONTAL_ALIGNMENT_RIGHT, 80.0)
	var right := rect.end.x - 18.0
	match state:
		ProtoTree.State.FULL:
			text(Vector2(right - 120.0, mid + 6.0), "習得済み", GOTHIC, 16, DIM, HORIZONTAL_ALIGNMENT_RIGHT, 120.0)
		ProtoTree.State.LOCKED:
			text(Vector2(right - 120.0, mid + 6.0), "未開放", GOTHIC, 16, ASH.lightened(0.25), HORIZONTAL_ALIGNMENT_RIGHT, 120.0)
		_:
			var able := state == ProtoTree.State.BUY
			var cost := UIFormat.amount(tree.price(upgrade))
			text(Vector2(right - 120.0, mid + 7.0), cost, GOTHIC_B, 20, EMBER if able else DIM, HORIZONTAL_ALIGNMENT_RIGHT, 120.0)
			_coin(Vector2(right - width_of(cost, GOTHIC_B, 20) - 16.0, mid), 7.0, EMBER if able else ASH)
	zone(rect, [&"row", index])


# An upgrade's ranks as notches cut in iron, the held ones glowing.
func _notches(at: Vector2, upgrade: MetaUpgrade, wide: float, tall: float) -> void:
	var held := tree.rank(upgrade)
	for index in upgrade.max_rank():
		var rect := Rect2(at.x + index * (wide + 4.0), at.y, wide, tall)
		if index < held:
			var fresh := index == held - 1 and buying(upgrade) < 1.0
			if fresh:
				glow(rect.get_center(), tall * 2.2 * (1.0 - buying(upgrade)) + tall, Color(EMBER, 0.6))
			draw_rect(rect, Color.WHITE.lerp(EMBER, buying(upgrade)) if fresh else EMBER)
		else:
			draw_rect(rect, ASH, false, 1.5)


func _paint_sheet() -> void:
	plate(SHEET, Color(IRON, 0.94), EDGE, 4.0)
	if rows.is_empty():
		return
	var upgrade := chosen
	var state := tree.state(upgrade)
	var mid := SHEET.position.x + SHEET.size.x * 0.5
	var inner := SHEET.size.x - 64.0
	var left := SHEET.position.x + 32.0
	glow(Vector2(mid, 216.0), 150.0, Color(EMBER, 0.10 + 0.25 * (1.0 - buying(upgrade))))
	medallion(Vector2(mid, 216.0), 72.0, upgrade.emblem, Color(0.5, 0.52, 0.56) if state == ProtoTree.State.LOCKED else Color.WHITE)
	text(Vector2(SHEET.position.x, 336.0), tr(upgrade.display_name), MINCHO_B, 34, STEEL, HORIZONTAL_ALIGNMENT_CENTER, SHEET.size.x)
	var count := upgrade.max_rank()
	_notches(Vector2(mid - (count * 18.0 - 4.0) * 0.5, 354.0), upgrade, 14.0, 20.0)
	text(Vector2(SHEET.position.x, 396.0), "%d / %d 段" % [tree.rank(upgrade), count], GOTHIC, 14, DIM, HORIZONTAL_ALIGNMENT_CENTER, SHEET.size.x)
	draw_line(Vector2(left, 414.0), Vector2(left + inner, 414.0), EDGE, 1.0)
	var y := 452.0
	var figure := tree.figure(upgrade)
	if not figure.is_empty():
		draw_multiline_string(GOTHIC_B, Vector2(left, y), figure, HORIZONTAL_ALIGNMENT_CENTER, inner, 22, -1, EMBER if state != ProtoTree.State.FULL else STEEL)
		y += GOTHIC_B.get_multiline_string_size(figure, HORIZONTAL_ALIGNMENT_CENTER, inner, 22).y + 16.0
	y += paragraph(Vector2(left, y), tree.note(upgrade), GOTHIC, 18, STEEL, inner, 14.0)
	var waits := tree.waits(upgrade)
	if not waits.is_empty():
		paragraph(Vector2(left, y), waits, GOTHIC, 17, RED, inner)
	# The echo held against the price, and the one action.
	var bar := Rect2(left, 668.0, inner, 10.0)
	var button := Rect2(left, 704.0, inner, 62.0).grow_individual(0.0, 0.0, 0.0, 0.0)
	button.position.x += refusal()
	var cost := tree.price(upgrade)
	if cost >= 0:
		text(Vector2(left, 654.0), "所持 %s" % UIFormat.amount(tree.meta.echo), GOTHIC, 16, DIM)
		text(Vector2(left, 654.0), "必要 %s" % UIFormat.amount(cost), GOTHIC_B, 16, STEEL, HORIZONTAL_ALIGNMENT_RIGHT, inner)
		draw_rect(bar, ASH)
		var share := clampf(float(tree.meta.echo) / float(cost), 0.0, 1.0)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), EMBER if share >= 1.0 else DIM)
	var words := ""
	match state:
		ProtoTree.State.FULL:
			words = "習得済み"
		ProtoTree.State.LOCKED:
			words = "未開放"
		ProtoTree.State.SHORT:
			words = "残響があと%s足りない" % UIFormat.amount(tree.missing(upgrade))
		_:
			words = "Enter　残響 %s で%s" % [UIFormat.amount(cost), tree.verb(upgrade)]
	if state == ProtoTree.State.BUY:
		var breath := 0.5 + 0.5 * sin(clock * 3.0)
		glow(button.get_center(), 260.0, Color(EMBER, 0.10 + 0.08 * breath))
		plate(button, EMBER_DEEP.lerp(EMBER, 0.25 if hovered(&"buy") else 0.0), EMBER, 4.0, 2.0)
		text(Vector2(button.position.x, button.position.y + 40.0), words, GOTHIC_B, 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, button.size.x)
	else:
		plate(button, IRON_LIT, EDGE, 4.0)
		text(Vector2(button.position.x, button.position.y + 39.0), words, GOTHIC, 20, DIM, HORIZONTAL_ALIGNMENT_CENTER, button.size.x)
	zone(button, [&"buy"])
	# The moment: sparks struck from the plate.
	var struck := buying(upgrade)
	if struck < 1.0:
		for index in 22:
			var way := Vector2.from_angle(-PI * 0.5 + (hash(index * 7 + 3) % 1000 / 1000.0 - 0.5) * 2.6)
			var far := (90.0 + hash(index * 13 + 1) % 160) * (1.0 - pow(1.0 - struck, 2.0))
			var at := Vector2(mid, 354.0) + way * far + Vector2(0.0, 220.0 * struck * struck)
			draw_line(at, at - way * 12.0 * (1.0 - struck), Color(EMBER.lerp(Color.WHITE, 0.4), 1.0 - struck), 2.0)


func _paint_foot() -> void:
	var x := 60.0
	for pair: Array in [["Esc", "戻る"], ["Enter", "習得・強化"], ["↑ ↓", "選ぶ"], ["← →", "系統"], ["R", "買えるものだけ"]]:
		text(Vector2(x, 852.0), pair[0], GOTHIC_B, 16, STEEL)
		x += width_of(pair[0], GOTHIC_B, 16) + 12.0
		text(Vector2(x, 852.0), pair[1], GOTHIC, 16, DIM)
		x += width_of(pair[1], GOTHIC, 16) + 40.0
