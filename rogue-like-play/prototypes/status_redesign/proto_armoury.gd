class_name ProtoArmoury
extends ProtoScreen

# Prototype A, the armoury: everything she owns hangs on a wall rack in
# three rails (weapons, skills, specials), seen all at once, and what she
# carries into the fight sits in four mounts on the bench below, in the
# order the fight's HUD shows them. The player works from the thing, not
# from the slot: point at a piece on the rack and take it. A weapon or a
# special has one mount, so it goes straight there; a skill is taken in hand
# (`carried`) and the two skill mounts light up as the places it can go.
# Her five main figures are stamped on a plate under her, and R lays the
# full inspection sheet over the rack.

enum Area { RACK, BENCH }

const WALL := """
shader_type canvas_item;
%s
void fragment() {
	vec2 p = UV * vec2(1600.0, 900.0);
	float panel = floor(p.x / 200.0);
	float seam = smoothstep(0.0, 2.0, abs(mod(p.x, 200.0) - 1.0));
	float brushed = fbm(vec2(p.x * 0.012 + panel * 7.0, p.y * 0.9)) * 0.5 + fbm(p * 0.01) * 0.5;
	vec3 steel = mix(vec3(0.060, 0.070, 0.085), vec3(0.135, 0.150, 0.172), brushed);
	steel *= 0.82 + 0.18 * hash(vec2(panel, 3.0));
	steel *= mix(0.55, 1.0, seam);
	float lamp = exp(-length((p - vec2(240.0, 60.0)) / vec2(760.0, 620.0)) * 1.9);
	steel += vec3(1.0, 0.52, 0.2) * lamp * 0.16;
	float edge = smoothstep(1.25, 0.35, length((UV - 0.5) * vec2(1.25, 1.5)));
	COLOR = vec4(steel * mix(0.45, 1.0, edge), 1.0);
}
""" % NOISE

const TEXT := Color("e9e6df")
const TEXT_DIM := Color("98a1ab")
const TEXT_FAINT := Color("5d6670")
const STEEL := Color("38414b")
const STEEL_HI := Color("7a8693")
const STEEL_DARK := Color("1b2026")
const HEAT := Color("ff8a3c")
const HEAT_PALE := Color("ffd2a8")
const WOOD := Color("4a3423")
const WOOD_DARK := Color("2a1c12")

const HERO := preload("res://art/characters/mio_lobby.png")
const RAIL_Y := [196.0, 344.0, 492.0]
const RAIL_NAMES := ["武器", "スキル", "必殺技"]
const RAIL_SLOTS := [ProtoBuild.ATTACK, ProtoBuild.SKILL_1, ProtoBuild.SPECIAL]
const RACK_LEFT := 604.0
const RACK_STEP := 106.0
const PIECE := 44.0
const BENCH_TOP := 626.0
const MOUNT_X := [600.0, 874.0, 1148.0, 1422.0]
const MOUNT_Y := 742.0
const CARD := Rect2(1212.0, 104.0, 348.0, 488.0)

var area := Area.RACK
var rail := 1
var column := 0
var mount := 1
var carried: StringName = &""
var target := ProtoBuild.SKILL_1
var sheet_open := false
var _refused := false


func _init(of: ProtoBuild) -> void:
	super(of)
	backdrop(WALL)


func title() -> String:
	return "A　武具庫"


func hints() -> Array:
	if sheet_open:
		return [["R / Esc", "装備に戻る"]]
	if not carried.is_empty():
		return [["← →", "付ける場所"], ["Enter", "ここに付ける"], ["Esc", "棚に戻す"]]
	if area == Area.BENCH:
		return [["← →", "装備を選ぶ"], ["Enter", "手に取る"], ["X", "外す"], ["↑", "棚へ"], ["R", "検分"]]
	return [["矢印", "選ぶ"], ["Enter", "手に取る / 持ち替える"], ["↓", "装備へ"], ["R", "検分"], ["Esc", "戻る"]]


func _pieces(row: int) -> Array:
	return build.choices(RAIL_SLOTS[row])


func _piece_at(row: int, index: int) -> Vector2:
	return Vector2(RACK_LEFT + RACK_STEP * index, RAIL_Y[row])


func _focused() -> Dictionary:
	var row := _pieces(rail)
	return row[clampi(column, 0, row.size() - 1)]


# The slot the stage tells for: the mount under the cursor, the mount a
# carried skill aims at, or the first mount of the focused piece's kind.
func _told_slot() -> int:
	if not carried.is_empty():
		return target
	if area == Area.BENCH:
		return mount
	var piece := _focused()
	if piece.state == ProtoBuild.State.HERE or piece.state == ProtoBuild.State.ELSEWHERE:
		return build.slot_holding(piece.id)
	if rail == 1:
		return ProtoBuild.SKILL_2 if build.content(ProtoBuild.SKILL_1) != &"" and build.content(ProtoBuild.SKILL_2) == &"" else ProtoBuild.SKILL_1
	return RAIL_SLOTS[rail]


func _key(action: StringName) -> void:
	if action == &"details":
		sheet_open = not sheet_open
		kick(&"sheet")
		return
	if sheet_open:
		if action == &"cancel":
			sheet_open = false
		return
	if not carried.is_empty():
		match action:
			&"left", &"right":
				target = ProtoBuild.SKILL_2 if target == ProtoBuild.SKILL_1 else ProtoBuild.SKILL_1
				kick(&"aim")
			&"accept":
				_mount_carried()
			&"cancel":
				carried = &""
		return
	if area == Area.RACK:
		match action:
			&"left":
				column = maxi(0, column - 1)
			&"right":
				column = mini(_pieces(rail).size() - 1, column + 1)
			&"up":
				if rail > 0:
					rail -= 1
					column = mini(column, _pieces(rail).size() - 1)
			&"down":
				if rail < 2:
					rail += 1
					column = mini(column, _pieces(rail).size() - 1)
				else:
					area = Area.BENCH
					mount = clampi(column + 1, 0, 3)
			&"accept":
				_take(_focused())
		kick(&"move")
		return
	match action:
		&"left":
			mount = maxi(0, mount - 1)
		&"right":
			mount = mini(3, mount + 1)
		&"up", &"cancel":
			area = Area.RACK
			rail = [0, 1, 1, 2][mount]
			var held := build.content(mount)
			var row := _pieces(rail)
			for index in row.size():
				if row[index].id == held:
					column = index
			column = mini(column, row.size() - 1)
		&"accept":
			var held := build.content(mount)
			if mount in [ProtoBuild.SKILL_1, ProtoBuild.SKILL_2] and not held.is_empty():
				carried = held
				target = ProtoBuild.SKILL_2 if mount == ProtoBuild.SKILL_1 else ProtoBuild.SKILL_1
				kick(&"lift")
			else:
				_key(&"up")
		&"clear":
			if build.can_clear(mount):
				build.equip(mount, ProtoBuild.CLEAR)
			else:
				_refuse()
	kick(&"move")


# Takes a piece from the rack: a weapon or special goes to its one mount, a
# skill into the hand.
func _take(piece: Dictionary) -> void:
	if piece.state == ProtoBuild.State.UNKNOWN:
		_refuse()
		return
	if rail != 1:
		if piece.state == ProtoBuild.State.HERE:
			_refuse()
		else:
			build.equip(RAIL_SLOTS[rail], piece.id)
		return
	carried = piece.id
	var at := build.slot_holding(piece.id)
	if at == ProtoBuild.SKILL_1:
		target = ProtoBuild.SKILL_2
	elif at == ProtoBuild.SKILL_2:
		target = ProtoBuild.SKILL_1
	else:
		target = ProtoBuild.SKILL_2 if build.content(ProtoBuild.SKILL_1) != &"" and build.content(ProtoBuild.SKILL_2) == &"" else ProtoBuild.SKILL_1
	kick(&"lift")


func _mount_carried() -> void:
	if build.content(target) == carried:
		_refuse()
		return
	build.equip(target, carried)
	area = Area.BENCH
	mount = target
	carried = &""


func _refuse() -> void:
	kick(&"refuse")


func _on_changed(slots: Array) -> void:
	for slot: int in slots:
		kick(StringName("slam%d" % slot))
	kick(&"slam")


func _click(id: Variant) -> void:
	var what: Array = id
	if what[0] == &"sheet":
		_key(&"details")
	elif sheet_open:
		return
	elif what[0] == &"piece":
		if not carried.is_empty():
			carried = &""
		var again: bool = area == Area.RACK and rail == what[1] and column == what[2]
		area = Area.RACK
		rail = what[1]
		column = what[2]
		kick(&"move")
		if again:
			_take(_focused())
	elif what[0] == &"mount":
		if not carried.is_empty():
			if what[1] in [ProtoBuild.SKILL_1, ProtoBuild.SKILL_2]:
				target = what[1]
				_mount_carried()
			return
		var again: bool = area == Area.BENCH and mount == what[1]
		area = Area.BENCH
		mount = what[1]
		kick(&"move")
		if again:
			_key(&"accept")
	elif what[0] == &"clear":
		mount = what[1]
		_key(&"clear")


func pose(state: StringName) -> void:
	area = Area.RACK
	carried = &""
	sheet_open = false
	rail = 1
	column = 0
	match state:
		&"browse":
			column = 2
		&"change":
			column = 2
			_take(_focused())
		&"stats":
			sheet_open = true
	_kicks.clear()


# --- Drawing ---

func _paint() -> void:
	_paint_header()
	_paint_hero()
	_paint_bench()
	if sheet_open:
		_paint_sheet()
	else:
		_paint_rack()
		_paint_card()
	if not carried.is_empty():
		_paint_carry()
	_paint_hints()


func _paint_header() -> void:
	spaced(Vector2(48.0, 62.0), "武具庫", GOTHIC_B, 30, TEXT, 10.0)
	text(Vector2(210.0, 60.0), "戦いに持っていくものを、棚から選んで付ける", GOTHIC, 16, TEXT_DIM)
	draw_line(Vector2(48.0, 80.0), Vector2(1552.0, 80.0), Color(STEEL_HI, 0.25), 1.0)
	var tab := Rect2(1404.0, 34.0, 148.0, 36.0)
	plate(tab, Color(HEAT, 0.16) if sheet_open else Color(STEEL, 0.8), Color(HEAT, 0.9) if sheet_open or _is_hover(&"sheet") else Color(STEEL_HI, 0.5), 3.0)
	_cap(Vector2(tab.position.x + 12.0, tab.position.y + 6.0), "R", sheet_open)
	text(Vector2(tab.position.x + 50.0, tab.position.y + 24.0), "装備に戻る" if sheet_open else "検分する", GOTHIC_B, 15, TEXT)
	zone(tab, [&"sheet"])


func _is_hover(kind: StringName, a: Variant = null, b: Variant = null) -> bool:
	if not hover is Array or (hover as Array)[0] != kind:
		return false
	var what: Array = hover
	return (a == null or what[1] == a) and (b == null or what[2] == b)


# A key on a small steel cap; returns its width.
func _cap(at: Vector2, key: String, hot := false) -> float:
	var width := maxf(26.0, GOTHIC_B.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0)
	plate(Rect2(at, Vector2(width, 24.0)), Color(HEAT, 0.9) if hot else Color("0e1115"), Color(HEAT_PALE, 0.9) if hot else Color(STEEL_HI, 0.7), 4.0)
	text(Vector2(at.x, at.y + 17.0), key, GOTHIC_B, 13, STEEL_DARK if hot else TEXT, HORIZONTAL_ALIGNMENT_CENTER, width)
	return width


func _paint_hero() -> void:
	glow(Vector2(226.0, 380.0), 330.0, Color(1.0, 0.55, 0.22, 0.10))
	var tall := 520.0
	var wide := tall * HERO.get_width() / HERO.get_height()
	draw_texture_rect(HERO, Rect2(226.0 - wide * 0.5, 96.0, wide, tall), false)
	# Her main figures, stamped on a plate.
	var card := Rect2(40.0, BENCH_TOP + 4.0, 376.0, 208.0)
	_steel(card)
	spaced(Vector2(card.position.x + 20.0, card.position.y + 30.0), "主な能力", GOTHIC_B, 13, TEXT_DIM, 4.0)
	var y := card.position.y + 60.0
	for row: Array in build.main_stats():
		text(Vector2(card.position.x + 20.0, y), row[0], GOTHIC, 15, TEXT_DIM)
		var value: String = row[1]
		var added: String = row[2]
		var right := card.end.x - 20.0
		if not added.is_empty():
			var width := GOTHIC.get_string_size(added, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			text(Vector2(right - width, y), added, GOTHIC, 13, HEAT)
			right -= width + 8.0
		text(Vector2(card.position.x + 20.0, y), value, GOTHIC_B, 17, TEXT, HORIZONTAL_ALIGNMENT_RIGHT, right - card.position.x - 20.0)
		draw_line(Vector2(card.position.x + 20.0, y + 9.0), Vector2(card.end.x - 20.0, y + 9.0), Color(STEEL_HI, 0.16), 1.0)
		y += 30.0


# A steel plate: a face lit from above, a bright top edge, rivets in its corners.
func _steel(rect: Rect2, lit := 0.0) -> void:
	draw_rect(Rect2(rect.position + Vector2(0.0, 5.0), rect.size), Color(0.0, 0.0, 0.0, 0.45))
	shade(rect, STEEL.lerp(HEAT, lit * 0.25).lightened(0.05), STEEL_DARK.lerp(HEAT, lit * 0.12))
	draw_rect(rect, Color(STEEL_HI, 0.35).lerp(HEAT, lit), false, 1.0)
	draw_line(rect.position + Vector2(1.0, 1.0), Vector2(rect.end.x - 1.0, rect.position.y + 1.0), Color(1.0, 1.0, 1.0, 0.16), 1.0)
	for corner: Vector2 in [Vector2(9.0, 9.0), Vector2(rect.size.x - 9.0, 9.0), Vector2(9.0, rect.size.y - 9.0), rect.size - Vector2(9.0, 9.0)]:
		draw_circle(rect.position + corner, 2.6, Color(0.0, 0.0, 0.0, 0.55))
		draw_circle(rect.position + corner - Vector2(0.6, 0.6), 1.6, Color(STEEL_HI, 0.8))


func _octagon(centre: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in 8:
		points.append(centre + Vector2.from_angle(TAU * (index + 0.5) / 8.0) * radius)
	return points


func _paint_rack() -> void:
	var dim := 0.35 if not carried.is_empty() else 1.0
	for row in 3:
		var y: float = RAIL_Y[row]
		# The rail and its nameplate.
		draw_line(Vector2(452.0, y - 66.0), Vector2(1186.0, y - 66.0), Color(0.0, 0.0, 0.0, 0.5 * dim), 7.0)
		draw_line(Vector2(452.0, y - 68.0), Vector2(1186.0, y - 68.0), Color(STEEL_HI, 0.55 * dim), 3.0)
		var label := Rect2(452.0, y - 22.0, 92.0, 44.0)
		plate(label, Color(STEEL_DARK, 0.9 * dim), Color(STEEL_HI, 0.4 * dim), 2.0)
		text(Vector2(label.position.x, label.position.y + 29.0), RAIL_NAMES[row], GOTHIC_B, 16, Color(TEXT, dim), HORIZONTAL_ALIGNMENT_CENTER, label.size.x)
		var pieces := _pieces(row)
		for index in pieces.size():
			_paint_piece(row, index, pieces[index], dim)


func _paint_piece(row: int, index: int, piece: Dictionary, dim: float) -> void:
	var at := _piece_at(row, index)
	var focused := area == Area.RACK and carried.is_empty() and rail == row and column == index
	var unknown: bool = piece.state == ProtoBuild.State.UNKNOWN
	var taken: bool = piece.id == carried
	var lift := 0.0
	if focused:
		lift = -8.0 * eased(&"move", 0.16)
		if since(&"refuse") < 0.3:
			at.x += sin(since(&"refuse") * 60.0) * 5.0 * (1.0 - since(&"refuse") / 0.3)
	zone_round(at, PIECE + 12.0, [&"piece", row, index])
	# The hook from the rail.
	draw_line(Vector2(at.x, at.y - 66.0), Vector2(at.x, at.y - PIECE - 6.0 + lift), Color(STEEL_HI, 0.5 * dim), 2.0)
	at.y += lift
	if taken:
		# Its place on the rack, empty while it is in the hand.
		for step in 16:
			ring(at, PIECE + 6.0, Color(HEAT, 0.5), 1.5, TAU * step / 16.0, TAU * (step + 0.5) / 16.0)
		return
	if focused:
		glow(at, PIECE * 2.3, Color(HEAT, 0.34))
	elif _is_hover(&"piece", row, index) and carried.is_empty():
		glow(at, PIECE * 1.9, Color(HEAT, 0.14))
	draw_colored_polygon(_octagon(at + Vector2(0.0, 4.0), PIECE + 10.0), Color(0.0, 0.0, 0.0, 0.5 * dim))
	if unknown:
		draw_colored_polygon(_octagon(at, PIECE + 10.0), Color(STEEL_DARK, 0.75 * dim))
		draw_polyline(_closed(_octagon(at, PIECE + 10.0)), Color(TEXT_FAINT, 0.7 * dim), 1.0, true)
		emblem(at, PIECE, piece.emblem, Color(0.10, 0.12, 0.14, dim))
		ring(at, PIECE, Color(TEXT_FAINT, 0.6 * dim), 1.0)
		text(Vector2(at.x - 60.0, at.y + PIECE + 30.0), "未習得", GOTHIC, 13, Color(TEXT_FAINT, dim), HORIZONTAL_ALIGNMENT_CENTER, 120.0)
		if focused:
			draw_polyline(_closed(_octagon(at, PIECE + 13.0)), Color(HEAT, 0.9), 2.0, true)
		return
	draw_colored_polygon(_octagon(at, PIECE + 10.0), STEEL.lerp(STEEL_HI, 0.25 if focused else 0.0) * Color(1.0, 1.0, 1.0, dim))
	draw_polyline(_closed(_octagon(at, PIECE + 10.0)), Color(HEAT if focused else STEEL_HI, (1.0 if focused else 0.55) * dim), 2.5 if focused else 1.0, true)
	emblem(at, PIECE, piece.emblem, Color(1.0, 1.0, 1.0, dim))
	ring(at, PIECE, Color(0.0, 0.0, 0.0, 0.7 * dim), 2.0)
	text(Vector2(at.x - 70.0, at.y + PIECE + 30.0), piece.name, GOTHIC_B, 15, Color(HEAT_PALE if focused else TEXT, dim), HORIZONTAL_ALIGNMENT_CENTER, 140.0)
	# What she carries wears the tag of its mount's key.
	if piece.state == ProtoBuild.State.HERE or piece.state == ProtoBuild.State.ELSEWHERE:
		var key: String = ProtoBuild.SLOT_KEYS[build.slot_holding(piece.id)]
		var width := maxf(30.0, GOTHIC_B.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0)
		var tag := Rect2(at.x + 52.0 - width, at.y - PIECE - 14.0, width, 22.0)
		plate(tag, Color(HEAT, dim), Color(HEAT_PALE, dim), 2.0)
		text(Vector2(tag.position.x, tag.position.y + 16.0), key, GOTHIC_B, 12, Color(STEEL_DARK, dim), HORIZONTAL_ALIGNMENT_CENTER, width)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var loop := points.duplicate()
	loop.append(points[0])
	return loop


func _paint_bench() -> void:
	var bump := 0.0
	if since(&"slam") < 0.25:
		bump = 5.0 * (1.0 - since(&"slam") / 0.25) * cos(since(&"slam") * 40.0)
	var top := BENCH_TOP + bump
	shade(Rect2(436.0, top, 1164.0, 232.0), WOOD, WOOD_DARK)
	for plank in 5:
		draw_line(Vector2(436.0, top + 46.0 * plank + 18.0), Vector2(1600.0, top + 46.0 * plank + 18.0), Color(0.0, 0.0, 0.0, 0.16), 1.0)
	draw_line(Vector2(436.0, top), Vector2(1600.0, top), Color(1.0, 0.8, 0.6, 0.22), 2.0)
	text(Vector2(456.0, top + 30.0), "装備", GOTHIC_B, 14, Color(TEXT, 0.6))
	text(Vector2(500.0, top + 30.0), "戦いの画面と同じ並び", GOTHIC, 13, Color(TEXT, 0.35))
	for slot in 4:
		_paint_mount(slot, bump)


func _paint_mount(slot: int, bump: float) -> void:
	var centre := Vector2(MOUNT_X[slot], MOUNT_Y + bump)
	var rect := Rect2(centre.x - 126.0, centre.y - 78.0, 252.0, 156.0)
	var carrying := not carried.is_empty()
	var skill_mount := slot in [ProtoBuild.SKILL_1, ProtoBuild.SKILL_2]
	var aimed := carrying and target == slot
	var open := carrying and skill_mount
	var focused := area == Area.BENCH and not carrying and mount == slot
	var told := not carrying and area == Area.RACK and not sheet_open and _told_slot() == slot
	var dim := 0.4 if carrying and not skill_mount else 1.0
	zone(rect, [&"mount", slot])
	_steel(rect, 1.0 if aimed or focused else (0.35 if open or told else 0.0))
	if dim < 1.0:
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.5))
	var socket := Vector2(rect.position.x + 70.0, centre.y - 6.0)
	var held := build.content(slot)
	var radius := 46.0
	draw_circle(socket, radius + 7.0, Color(0.0, 0.0, 0.0, 0.6))
	ring(socket, radius + 7.0, Color(HEAT if aimed or focused else STEEL_HI, 0.9 * dim), 2.5 if aimed or focused else 1.5)
	var slam := since(StringName("slam%d" % slot))
	if held.is_empty():
		for step in 14:
			ring(socket, radius - 4.0, Color(TEXT_FAINT, dim), 1.5, TAU * step / 14.0, TAU * (step + 0.5) / 14.0)
	else:
		var drop := 1.0 + 0.35 * maxf(0.0, 1.0 - slam / 0.14)
		emblem(socket, radius * drop, ProtoBuild.emblem_of(held), Color(1.0, 1.0, 1.0, dim))
	if slam < 0.5:
		var fade := 1.0 - slam / 0.5
		ring(socket, radius + 8.0 + 46.0 * (1.0 - fade), Color(HEAT_PALE, fade), 3.0)
		for spark in 10:
			var way := Vector2.from_angle(TAU * spark / 10.0 + slot)
			draw_line(socket + way * (radius + 12.0 + 40.0 * (1.0 - fade)), socket + way * (radius + 26.0 + 70.0 * (1.0 - fade)), Color(HEAT_PALE, fade), 2.0, true)
		draw_circle(socket, radius, Color(1.0, 0.9, 0.75, 0.5 * fade * fade))
	# The key that uses the mount, on its cap under the socket.
	var key: String = ProtoBuild.SLOT_KEYS[slot]
	var width := maxf(26.0, GOTHIC_B.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0)
	_cap(Vector2(socket.x - width * 0.5, socket.y + radius - 4.0), key, aimed or focused)
	var left := socket.x + radius + 22.0
	text(Vector2(left, rect.position.y + 44.0), ProtoBuild.SLOT_NAMES[slot], GOTHIC, 14, Color(TEXT_DIM, dim))
	var name := build.name_of(held) if not held.is_empty() else "空き"
	if slot == ProtoBuild.SPECIAL and not build.meta.owns_any_special():
		name = "封印"
	text(Vector2(left, rect.position.y + 78.0), name, GOTHIC_B, 22, Color(TEXT if not held.is_empty() else TEXT_FAINT, dim), HORIZONTAL_ALIGNMENT_LEFT, rect.end.x - left - 10.0)
	if aimed:
		text(Vector2(left, rect.position.y + 108.0), "ここに付ける", GOTHIC_B, 13, HEAT_PALE)
	elif open:
		text(Vector2(left, rect.position.y + 108.0), "ここにも付けられる", GOTHIC, 13, Color(HEAT_PALE, 0.6))
	elif focused and build.can_clear(slot):
		var cap := Vector2(left, rect.position.y + 96.0)
		var used := _cap(cap, "X")
		text(Vector2(cap.x + used + 8.0, cap.y + 17.0), "外す", GOTHIC, 13, TEXT_DIM)
		zone(Rect2(cap, Vector2(90.0, 24.0)), [&"clear", slot])


func _paint_carry() -> void:
	# The skill in the hand hangs over the bench, a line down to where it aims.
	var rise := eased(&"lift", 0.2)
	var aim := Vector2(MOUNT_X[target] - 56.0, MOUNT_Y - 6.0)
	var held := Vector2(lerpf(aim.x, (MOUNT_X[1] + MOUNT_X[2]) * 0.5 - 56.0, 0.0), 520.0 - 24.0 * rise + sin(clock * 2.4) * 4.0)
	var slide := eased(&"aim", 0.16)
	var from_x: float = MOUNT_X[ProtoBuild.SKILL_2 if target == ProtoBuild.SKILL_1 else ProtoBuild.SKILL_1] - 56.0
	held.x = lerpf(from_x, aim.x, slide) if since(&"aim") < 0.2 else aim.x
	glow(held, 150.0, Color(HEAT, 0.3))
	for step in 9:
		var a := held.lerp(aim, (step + 0.15) / 9.0) + Vector2(0.0, 62.0 * (1.0 - step / 9.0))
		var b := held.lerp(aim, (step + 0.6) / 9.0) + Vector2(0.0, 62.0 * (1.0 - (step + 0.6) / 9.0))
		if a.y < aim.y - 50.0:
			draw_line(a, Vector2(b.x, minf(b.y, aim.y - 50.0)), Color(HEAT, 0.8), 2.0, true)
	draw_colored_polygon(_octagon(held + Vector2(0.0, 6.0), 72.0), Color(0.0, 0.0, 0.0, 0.5))
	draw_colored_polygon(_octagon(held, 72.0), STEEL.lerp(STEEL_HI, 0.3))
	draw_polyline(_closed(_octagon(held, 72.0)), HEAT, 3.0, true)
	emblem(held, 60.0, ProtoBuild.emblem_of(carried))
	ring(held, 60.0, Color(0.0, 0.0, 0.0, 0.7), 2.0)
	var label := "「%s」をどこに付ける？" % build.name_of(carried)
	var told := build.account(target, carried)
	var outcome: String = "%s　%s" % [ProtoBuild.SLOT_KEYS[target], told.outcome] if told.can else "%s　いま付けている" % ProtoBuild.SLOT_KEYS[target]
	var width := maxf(GOTHIC_B.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, GOTHIC.get_string_size(outcome, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x)
	var at := Vector2(clampf(held.x + 96.0, 460.0, 1190.0 - width), held.y - 14.0)
	plate(Rect2(at.x - 16.0, at.y - 30.0, width + 32.0, 70.0), Color(0.04, 0.05, 0.06, 0.94), Color(HEAT, 0.8), 3.0)
	text(at, label, GOTHIC_B, 20, TEXT)
	text(at + Vector2(0.0, 27.0), outcome, GOTHIC, 15, HEAT_PALE)


func _paint_card() -> void:
	var slot := _told_slot()
	var id: StringName = carried
	if id.is_empty():
		id = build.content(mount) if area == Area.BENCH else _focused().id
	var told := build.account(slot, id)
	_steel(CARD)
	var left := CARD.position.x + 26.0
	var width := CARD.size.x - 52.0
	var y := CARD.position.y + 44.0
	text(Vector2(left, y), told.kind, GOTHIC, 14, TEXT_DIM)
	# Where it stands: carried by a mount, on the rack, or not learned.
	var holder := build.slot_holding(id)
	var status := "未習得" if told.unknown else ("装備中" if holder >= 0 else "棚にある")
	var status_width := GOTHIC_B.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 18.0
	var chip := Rect2(CARD.end.x - 26.0 - status_width, y - 18.0, status_width, 24.0)
	plate(chip, Color(HEAT, 0.9) if holder >= 0 else Color(STEEL_DARK), Color(HEAT_PALE if holder >= 0 else STEEL_HI, 0.8), 2.0)
	text(Vector2(chip.position.x, chip.position.y + 17.0), status, GOTHIC_B, 13, STEEL_DARK if holder >= 0 else TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, status_width)
	if holder >= 0:
		var key: String = ProtoBuild.SLOT_KEYS[holder]
		var key_width := maxf(26.0, GOTHIC_B.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0)
		_cap(Vector2(chip.position.x - key_width - 6.0, chip.position.y), key)
	y += 50.0
	text(Vector2(left, y), told.name, GOTHIC_B, 34, TEXT, HORIZONTAL_ALIGNMENT_LEFT, width)
	y += 22.0
	draw_line(Vector2(left, y), Vector2(left + 44.0, y), HEAT, 3.0)
	y += 34.0
	y += paragraph(Vector2(left, y), told.description, GOTHIC, 16, Color(TEXT, 0.86), width, 18.0, 4)
	for row: Array in told.figures:
		text(Vector2(left, y + 6.0), row[0], GOTHIC, 15, TEXT_DIM)
		text(Vector2(left, y + 6.0), row[1], GOTHIC_B, 17, TEXT, HORIZONTAL_ALIGNMENT_RIGHT, width)
		draw_line(Vector2(left, y + 18.0), Vector2(left + width, y + 18.0), Color(STEEL_HI, 0.18), 1.0)
		y += 36.0
	# What Enter does now.
	var foot := CARD.end.y - 34.0
	var action := ""
	if not carried.is_empty():
		action = "付ける場所を選ぶ"
	elif area == Area.BENCH:
		action = "手に取って付け替える" if mount in [1, 2] and not id.is_empty() else "棚から選ぶ"
	elif told.unknown:
		action = ""
	elif rail == 1:
		action = "手に取る"
	elif holder >= 0:
		action = ""
	else:
		action = "持ち替える" if rail == 0 else "装備する"
	if not action.is_empty():
		var used := _cap(Vector2(left, foot - 17.0), "Enter", true)
		text(Vector2(left + used + 10.0, foot), action, GOTHIC_B, 16, TEXT)
	elif told.unknown:
		text(Vector2(left, foot), "まだ手に取れない", GOTHIC, 14, TEXT_FAINT)
	else:
		text(Vector2(left, foot), "いま付けている", GOTHIC, 14, TEXT_DIM)


func _paint_sheet() -> void:
	var rise := eased(&"sheet", 0.22)
	var rows := build.stats()
	for group in 2:
		var rect := Rect2(452.0 + 562.0 * group, 104.0 + 16.0 * (1.0 - rise), 546.0, 488.0)
		_steel(rect)
		spaced(Vector2(rect.position.x + 28.0, rect.position.y + 42.0), ["戦う力", "探索と成長"][group], GOTHIC_B, 18, TEXT, 6.0)
		draw_line(Vector2(rect.position.x + 28.0, rect.position.y + 56.0), Vector2(rect.position.x + 72.0, rect.position.y + 56.0), HEAT, 3.0)
		var y := rect.position.y + 96.0
		for row: Array in rows:
			if row[5] != group:
				continue
			var left := rect.position.x + 28.0
			var width := rect.size.x - 56.0
			text(Vector2(left, y), row[0], GOTHIC, 16, TEXT)
			var right := left + width
			var added: String = row[2]
			if not added.is_empty():
				var added_width := GOTHIC.get_string_size(added, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
				text(Vector2(right - added_width, y), added, GOTHIC, 14, HEAT)
				right -= added_width + 8.0
			text(Vector2(left, y), row[1], GOTHIC_B, 18, TEXT, HORIZONTAL_ALIGNMENT_RIGHT, right - left)
			text(Vector2(left, y + 21.0), row[3], GOTHIC, 13, TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, width)
			draw_line(Vector2(left, y + 31.0), Vector2(left + width, y + 31.0), Color(STEEL_HI, 0.16), 1.0)
			y += 54.0


func _paint_hints() -> void:
	var x := 452.0
	for pair: Array in hints():
		x += _cap(Vector2(x, 866.0), pair[0]) + 8.0
		text(Vector2(x, 883.0), pair[1], GOTHIC, 14, TEXT_DIM)
		x += GOTHIC.get_string_size(pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 26.0
