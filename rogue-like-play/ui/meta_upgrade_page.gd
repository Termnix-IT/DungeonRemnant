class_name MetaUpgradePage
extends Control

# The lasting upgrades (MetaProgress.UPGRADES) as a star chart: the whole
# tree on a night sky that fills the screen, all of it in sight at once,
# nothing dragged or zoomed. The lantern (the tree's root) is the pole. Every
# upgrade is a star on the ring of its generation (how many steps it stands
# from the lantern); the rings grow wider and squarer outward, so the last
# one reaches toward the screen's corners. Each branch is a constellation in
# its own part of the sky, named past its last stars with the ranks held in
# it, and spaces its own rings so that its last generation stands on the
# last ring: a branch of three generations fills its sky as one of four does.
# A line joins a star to the one it grows from. A star held burns gold with
# rays, one the echo held can light breathes blue, one that waits on another
# is dark; its ranks are points of light under it. The stars of the
# constellation the cursor is in carry their names.
#
# The card on the right is the chosen star in full: its emblem, name and
# ranks, its figure now and next with what the next rank adds, what it does
# (unless that only says the figure again), what it waits for, the price
# beside the echo held and how much is missing, and the one action, a crest
# button (CrestButton) with the price, that asks to buy (buy_requested; the
# hub saves, then calls present_purchase). Enter (A) asks the same.
#
# Arrows go to the nearest star that way (one joined to this one first),
# Q/E (LB/RB) and the wheel to the next constellation, C (Y) back to the
# lantern. The pointer chooses a star by clicking it or a constellation by
# its name, and buys only by the button.
#
# The page is one focusable control that draws itself in a design space of
# 1520x686 scaled to its rect, in the colours and faces of the theme's
# StarChart type. The sky is a shader (ui/star_chart/star_sky.gdshader) on a
# rect that covers the whole screen, behind the hub's title and keys; the
# button is a node laid over the card. The pointer acts through zones named
# while drawing.

signal buy_requested(id: StringName)

enum State { FULL, BUY, SHORT, LOCKED }

const SKY := preload("res://ui/star_chart/star_sky.gdshader")
const DESIGN := Vector2(1520.0, 686.0)
const POLE := Vector2(552.0, 343.0)
# The chart is wider than it is tall: every distance across it is this much
# longer than the same distance up it.
const STRETCH := 1.6
# The rings of the first and the last generation. The first is an oval; the
# last is squared off (a superellipse of this power), to fill the screen.
const FIRST_RING := 92.0
const LAST_RING := 292.0
const SQUARE := 3.6
# A constellation of fewer generations than this reaches only part of the
# way out, so that a branch of two stars is not pulled across the sky.
const FULL_REACH := 3
const SHORT_REACH := 0.6
# The sky runs this far past the screen's edges, to cover it as the page
# slides in.
const SKY_MARGIN := 240.0
const STAR := 18.0
const POLE_STAR := 27.0
# The constellations, clockwise from the top.
const ORDER: Array[StringName] = [&"skill", &"weapon", &"growth", &"special", &"body"]
const BRANCH_NAMES := {&"": "中央", &"body": "身体", &"growth": "成長", &"skill": "スキル", &"special": "必殺技", &"weapon": "武器"}
# A move goes to a star within this angle of the direction pressed.
const AIM_CONE := PI / 3.0
const CARD := Rect2(1104.0, 14.0, 396.0, 658.0)
# The button's room: a crest button is 84 tall, its plate in the middle.
const BUTTON := Rect2(1132.0, 584.0, 340.0, 84.0)
const MOMENT_TIME := UIMotion.MOMENT_TIME + UIMotion.GOLD_TIME
const MOVE_TIME := UIMotion.SELECT_TIME
const BREATH := 3.0

var meta: MetaProgress
var selected: StringName = MetaProgress.ROOT
# What the card tells of the chosen star: {id, name, part, rank, ranks,
# figure, note, waits, price, held, missing, state}.
var told := {}
var buy_button: Button
var _sky: ColorRect
# Upgrade id -> where its star stands (design space), its angle from the
# pole, its ring's size, its generation, and the upgrades that grow from it.
var _places: Dictionary = {}
var _rings: Dictionary = {}
var _angles: Dictionary = {}
var _depths: Dictionary = {}
var _grown: Dictionary = {}
# Branch -> [first angle, last angle] of its part of the sky.
var _parts: Dictionary = {}
# A constellation's name as written -> the room found for it.
var _spots: Dictionary = {}
var _clock := 0.0
var _kicks := {}
var _zones: Array = []
var _hover: Variant = null
var _origin := Vector2.ZERO
var _zoom := 1.0
# Where the cursor's ring comes from as it moves, and the star last bought.
var _from := POLE
var _bought: StringName = &""
var _quiet := true


func _ready() -> void:
	theme_type_variation = &"StarChart"
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sky = ColorRect.new()
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.show_behind_parent = true
	var night := ShaderMaterial.new()
	night.shader = SKY
	_sky.material = night
	add_child(_sky)
	# Buying is this screen's moment: the crest with the lobby's mark for it.
	# The focus stays on the chart, so Enter there and the button are one.
	var button := CrestButton.new()
	button.name = "Buy"
	button.kind = &"upgrade"
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(request_buy)
	add_child(button)
	buy_button = button
	UIMotion.bind_buttons(self)
	_lay_out()
	resized.connect(_fit)
	theme_changed.connect(_fit)
	visibility_changed.connect(_fit)
	get_viewport().size_changed.connect(_fit.call_deferred)
	_fit()


# Places the design space in the rect, and the sky and the button with it.
func _fit() -> void:
	if _sky == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_zoom = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_origin = ((size - DESIGN * _zoom) * 0.5).round()
	# The sky covers the screen, wherever in it the page stands.
	var screen := Rect2(Vector2.ZERO, size)
	if is_inside_tree():
		screen = get_global_transform().affine_inverse() * get_viewport_rect()
	_sky.position = screen.position - Vector2.ONE * SKY_MARGIN
	_sky.size = screen.size + Vector2.ONE * SKY_MARGIN * 2.0
	var night := _sky.material as ShaderMaterial
	night.set_shader_parameter(&"extent", _sky.size)
	night.set_shader_parameter(&"origin", _origin - _sky.position)
	night.set_shader_parameter(&"zoom", _zoom)
	night.set_shader_parameter(&"pole", POLE)
	night.set_shader_parameter(&"centre", (screen.get_center() - _origin) / _zoom)
	night.set_shader_parameter(&"reach", screen.size * 0.5 / _zoom)
	for item: StringName in [&"sky_deep", &"sky_light", &"sky_haze", &"lamp", &"speck"]:
		night.set_shader_parameter(item, get_theme_color(item))
	buy_button.position = _origin + BUTTON.position * _zoom
	buy_button.size = BUTTON.size * _zoom
	queue_redraw()


# --- The chart ---

# A point of the chart: at `angle` on the ring of `radius` (its reach up the
# chart from the pole). The rings past the first are squared off.
func _at(angle: float, radius: float) -> Vector2:
	var power := lerpf(2.0, SQUARE, clampf((radius - FIRST_RING) / (LAST_RING - FIRST_RING), 0.0, 1.0))
	var way := Vector2(cos(angle), sin(angle))
	var reach := radius * pow(pow(absf(way.x), power) + pow(absf(way.y), power), -1.0 / power)
	return POLE + Vector2(way.x * STRETCH, way.y) * reach


# A leaf to a slot of sky, an upgrade at the middle of what grows from it,
# each on its generation's ring.
func _lay_out() -> void:
	var deepest := 1
	# Branch -> its last generation.
	var depths := {}
	for upgrade in MetaProgress.UPGRADES:
		_grown[upgrade.id] = []
	for upgrade in MetaProgress.UPGRADES:
		if not upgrade.parent.is_empty():
			(_grown[upgrade.parent] as Array).append(upgrade.id)
	for upgrade in MetaProgress.UPGRADES:
		var steps := 0
		var at := upgrade
		while at != null and not at.parent.is_empty():
			steps += 1
			at = MetaProgress.find(at.parent)
		_depths[upgrade.id] = steps
		deepest = maxi(deepest, steps)
		depths[upgrade.branch] = maxi(depths.get(upgrade.branch, 1), steps)
	var slot := TAU / maxf(1.0, _leaves(MetaProgress.ROOT))
	var next := [-PI * 0.5 - slot * _leaves(first_of(ORDER[0])) * 0.5]
	for branch in ORDER:
		var first := first_of(branch)
		if first.is_empty():
			continue
		var from: float = next[0]
		_place(first, slot, next)
		_parts[branch] = [from, next[0]]
	_angles[MetaProgress.ROOT] = 0.0
	for id: StringName in _angles:
		var steps: int = _depths[id]
		var radius := 0.0
		if steps > 0:
			var most: int = depths.get(MetaProgress.find(id).branch, deepest)
			var reach := 1.0 if most >= FULL_REACH else SHORT_REACH
			radius = lerpf(FIRST_RING, LAST_RING, reach * float(steps - 1) / maxf(1.0, most - 1.0))
		_rings[id] = radius
		_places[id] = _at(_angles[id], radius)


func _leaves(id: StringName) -> int:
	var grown: Array = _grown.get(id, [])
	if grown.is_empty():
		return 1
	var count := 0
	for child: StringName in grown:
		count += _leaves(child)
	return count


func _place(id: StringName, slot: float, next: Array) -> float:
	var grown: Array = _grown[id]
	var angle := 0.0
	if grown.is_empty():
		angle = next[0] + slot * 0.5
		next[0] += slot
	else:
		for child: StringName in grown:
			angle += _place(child, slot, next)
		angle /= grown.size()
	_angles[id] = angle
	return angle


# The star a constellation grows from the lantern by, or none.
func first_of(branch: StringName) -> StringName:
	for id: StringName in _grown[MetaProgress.ROOT]:
		if MetaProgress.find(id).branch == branch:
			return id
	return &""


# Where a star stands in the page's own rect.
func place_of(id: StringName) -> Vector2:
	return _origin + (_places[id] as Vector2) * _zoom


func state_of(id: StringName) -> State:
	var upgrade := MetaProgress.find(id)
	if meta == null or upgrade == null or not meta.unlocked(id):
		return State.LOCKED
	if upgrade.price(meta.rank(id)) < 0:
		return State.FULL
	return State.BUY if meta.can_buy(id) else State.SHORT


# [ranks held, ranks in all] of a constellation.
func tally(branch: StringName) -> Array[int]:
	var held := 0
	var all := 0
	for upgrade in MetaProgress.UPGRADES:
		if upgrade.branch == branch and not upgrade.parent.is_empty():
			held += meta.rank(upgrade.id) if meta != null else 0
			all += upgrade.max_rank()
	return [held, all]


func refresh(current: MetaProgress) -> void:
	meta = current
	_tell()
	queue_redraw()


# The card and the button for the chosen star.
func _tell() -> void:
	var upgrade := MetaProgress.find(selected)
	if meta == null or upgrade == null or buy_button == null:
		return
	var rank := meta.rank(upgrade.id)
	var price := upgrade.price(rank)
	var waiting := not meta.unlocked(upgrade.id)
	var parent := MetaProgress.find(upgrade.parent)
	told = {
		id = upgrade.id, name = tr(upgrade.display_name), part = tr(BRANCH_NAMES.get(upgrade.branch, "")),
		rank = rank, ranks = upgrade.max_rank(), figure = upgrade.figure_line(rank),
		# A description that only says the figure again is left off.
		note = "" if upgrade.description_restates_figure(rank) else tr(upgrade.description),
		waits = tr("「%s」を習得すると解放") % tr(parent.display_name) if waiting else "",
		price = price, held = meta.echo, missing = maxi(0, price - meta.echo) if price >= 0 else 0,
		state = state_of(upgrade.id),
	}
	if price < 0:
		buy_button.text = tr("習得済み")
		buy_button.disabled = true
		buy_button.tooltip_text = ""
		return
	buy_button.text = tr("残響 %s で%s") % [UIFormat.amount(price), tr("習得") if rank == 0 else tr("強化")]
	buy_button.disabled = not meta.can_buy(upgrade.id)
	if waiting:
		buy_button.tooltip_text = tr("先に「%s」を習得する") % tr(parent.display_name)
	elif meta.echo < price:
		buy_button.tooltip_text = tr("残響が%s足りない") % UIFormat.amount(price - meta.echo)
	else:
		buy_button.tooltip_text = ""


# Moves the cursor to a star.
func choose(id: StringName) -> void:
	if not _places.has(id) or id == selected:
		return
	_from = _cursor()
	selected = id
	_tell()
	_kick(&"move")
	_sound(&"ui_move")
	queue_redraw()


# The star a direction leads to: within the cone, one joined to this one
# first, then the nearest. Distances are judged as the chart is drawn.
func neighbour(direction: Vector2) -> StringName:
	var from: Vector2 = _places[selected]
	var here := MetaProgress.find(selected)
	var best: StringName = &""
	var best_score := Vector2.INF
	for other in MetaProgress.UPGRADES:
		var offset: Vector2 = _places[other.id] - from
		if other.id == selected or absf(offset.angle_to(direction)) > AIM_CONE + 0.001:
			continue
		var joined := other.parent == selected or here.parent == other.id
		var score := Vector2(0.0 if joined else 1.0, offset.length())
		if score < best_score:
			best_score = score
			best = other.id
	return best


func step(direction: Vector2) -> void:
	choose(neighbour(direction))


# Goes to the next constellation's first star (the previous with -1).
func turn(by: int) -> void:
	var parts: Array[StringName] = []
	for branch in ORDER:
		if _parts.has(branch):
			parts.append(branch)
	if parts.is_empty():
		return
	var at := parts.find(MetaProgress.find(selected).branch)
	var to := posmod(at + by, parts.size()) if at >= 0 else (0 if by > 0 else parts.size() - 1)
	choose(first_of(parts[to]))


# C (Y): back to the lantern.
func return_to_root() -> void:
	choose(MetaProgress.ROOT)


# Enter (A) and the button: asks to buy the chosen star's next rank.
func request_buy() -> void:
	if meta != null and meta.can_buy(selected):
		buy_requested.emit(selected)
	else:
		_kick(&"refuse")
		GameAudio.play(self, &"ui_deny", -18.0)


# After a purchase has been saved: the star's moment.
func present_purchase(id: StringName) -> void:
	if not _places.has(id):
		return
	_bought = id
	_kick(&"buy")
	queue_redraw()


# How far through its moment a star just bought is (0 to 1; 1 once over, and
# for every other star).
func moment(id: StringName) -> float:
	if id != _bought:
		return 1.0
	return clampf(_since(&"buy") / MOMENT_TIME, 0.0, 1.0)


func focus_first() -> void:
	grab_focus()


# Opening the page: the stars come out ring by ring.
func play_entrance() -> void:
	_kick(&"open")


func _sound(cue: StringName) -> void:
	if not _quiet and is_visible_in_tree():
		GameAudio.play(self, cue, -22.0)


# --- Clock ---

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_quiet = false
	_clock += delta
	queue_redraw()


func _kick(what: StringName) -> void:
	_kicks[what] = _clock


func _since(what: StringName) -> float:
	return _clock - float(_kicks.get(what, -1000.0))


func _eased(what: StringName, time: float) -> float:
	var share := clampf(_since(what) / time, 0.0, 1.0)
	return 1.0 - pow(1.0 - share, 3.0)


# Where the cursor's ring is now, on its way to the chosen star.
func _cursor() -> Vector2:
	return _from.lerp(_places[selected], _eased(&"move", MOVE_TIME))


# --- Input ---

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _zone_at(event.position)
		return
	if event is InputEventMouseButton:
		if not event.pressed:
			return
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				grab_focus()
				var id: Variant = _zone_at(event.position)
				if id != null:
					_press(id)
				accept_event()
			MOUSE_BUTTON_WHEEL_UP:
				turn(-1)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				turn(1)
				accept_event()
		return
	var handled := true
	if event.is_action_pressed(&"ui_left", true):
		step(Vector2.LEFT)
	elif event.is_action_pressed(&"ui_right", true):
		step(Vector2.RIGHT)
	elif event.is_action_pressed(&"ui_up", true):
		step(Vector2.UP)
	elif event.is_action_pressed(&"ui_down", true):
		step(Vector2.DOWN)
	elif event.is_action_pressed(&"ui_accept"):
		request_buy()
	elif _pressed(event, KEY_Q, JOY_BUTTON_LEFT_SHOULDER):
		turn(-1)
	elif _pressed(event, KEY_E, JOY_BUTTON_RIGHT_SHOULDER):
		turn(1)
	elif _pressed(event, KEY_C, JOY_BUTTON_Y):
		return_to_root()
	else:
		handled = false
	if handled:
		accept_event()


func _pressed(event: InputEvent, key: Key, button: int) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode == key
	return event is InputEventJoypadButton and event.pressed and event.button_index == button


func _press(id: Variant) -> void:
	var what: Array = id
	match what[0]:
		&"star":
			choose(what[1])
		&"part":
			choose(first_of(what[1]))


func _zone(rect: Rect2, id: Variant) -> void:
	_zones.append([rect, id])


func _zone_at(point: Vector2) -> Variant:
	var at := (point - _origin) / _zoom
	for index in range(_zones.size() - 1, -1, -1):
		if (_zones[index][0] as Rect2).has_point(at):
			return _zones[index][1]
	return null


func _hovered(kind: StringName, what: StringName) -> bool:
	if not _hover is Array:
		return false
	var held: Array = _hover
	return held[0] == kind and held[1] == what


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = null


# --- Drawing ---

func _colour(item: StringName, share := 1.0) -> Color:
	var colour := get_theme_color(item)
	return Color(colour, colour.a * share)


func _face(item: StringName) -> Font:
	return get_theme_font(item)


func _size(item: StringName) -> int:
	return get_theme_font_size(item)


func _words(at: Vector2, words: String, face: StringName, size: StringName, colour: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(_face(face), at, words, align, width, _size(size), colour)


func _width(words: String, face: StringName, size: StringName) -> float:
	return _face(face).get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, _size(size)).x


# Japanese breaks between any two letters; a script with spaces, at them.
func _breaks() -> int:
	return TextServer.BREAK_MANDATORY | (TextServer.BREAK_GRAPHEME_BOUND if TranslationServer.get_locale().begins_with("ja") else TextServer.BREAK_WORD_BOUND)


# Wrapped words in the card; returns the height they took.
func _lines(at: Vector2, words: String, face: StringName, size: StringName, colour: Color, width: float, align := HORIZONTAL_ALIGNMENT_LEFT, most := 6) -> float:
	if words.is_empty():
		return 0.0
	draw_multiline_string(_face(face), at, words, align, width, _size(size), most, colour, _breaks())
	return _face(face).get_multiline_string_size(words, align, width, _size(size), most, _breaks()).y


func _ring(centre: Vector2, radius: float, colour: Color, width := 1.5) -> void:
	draw_arc(centre, radius, 0.0, TAU, maxi(24, int(radius * 0.9)), colour, width, true)


# A ring of the chart round the pole, or a part of one.
func _oval(radius: float, colour: Color, width := 1.0, from := 0.0, to := TAU) -> void:
	var count := maxi(8, int(128.0 * (to - from) / TAU))
	var points := PackedVector2Array()
	for index in count + 1:
		points.append(_at(lerpf(from, to, float(index) / count), radius))
	draw_polyline(points, colour, width, true)


# A soft round light.
func _glow(centre: Vector2, radius: float, colour: Color) -> void:
	var points := PackedVector2Array([centre])
	var colours := PackedColorArray([colour])
	for index in 33:
		points.append(centre + Vector2.from_angle(TAU * index / 32.0) * radius)
		colours.append(Color(colour, 0.0))
	for index in 32:
		draw_polygon(PackedVector2Array([points[0], points[index + 1], points[index + 2]]), PackedColorArray([colours[0], colours[index + 1], colours[index + 2]]))


# A four-pointed star.
func _spark(centre: Vector2, radius: float, colour: Color) -> void:
	var points := PackedVector2Array()
	for index in 8:
		points.append(centre + Vector2.from_angle(TAU * index / 8.0 - PI * 0.5) * (radius if index % 2 == 0 else radius * 0.32))
	draw_colored_polygon(points, colour)


# The picture inside a medallion, without its bronze rim, as a disc.
func _picture(centre: Vector2, radius: float, key: String, tint: Color) -> void:
	var picture := EmblemIcons.texture(key)
	if picture == null:
		return
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for index in 48:
		var way := Vector2.from_angle(TAU * index / 48.0)
		points.append(centre + way * radius)
		uvs.append(Vector2(0.5, 0.5) + way * 0.36)
	draw_polygon(points, PackedColorArray([tint]), uvs, picture)


func _draw() -> void:
	_zones.clear()
	if meta == null or told.is_empty():
		return
	draw_set_transform(_origin, 0.0, Vector2.ONE * _zoom)
	_draw_instrument()
	_draw_lines()
	for upgrade in MetaProgress.UPGRADES:
		_draw_star(upgrade)
	_draw_names()
	_draw_cursor()
	_draw_card()
	draw_set_transform(Vector2.ZERO)


# The rings of the generations, the parts of the sky and their names.
func _draw_instrument() -> void:
	_oval(FIRST_RING, _colour(&"brass", 0.12))
	var chosen_part := MetaProgress.find(selected).branch
	for branch in ORDER:
		if not _parts.has(branch):
			continue
		var part: Array = _parts[branch]
		var from: float = part[0]
		var to: float = part[1]
		var here := chosen_part == branch
		draw_line(_at(from, FIRST_RING * 0.6), _at(from, LAST_RING), _colour(&"brass", 0.1), 1.0)
		# A constellation's own rings, which glow where the cursor is in it.
		var rings := {}
		for upgrade in MetaProgress.UPGRADES:
			if upgrade.branch == branch and not upgrade.parent.is_empty():
				rings[_rings[upgrade.id]] = true
		for radius: float in rings:
			if here:
				_oval(radius, _colour(&"gold", 0.42), 1.5, from + 0.03, to - 0.03)
			elif radius > FIRST_RING:
				_oval(radius, _colour(&"brass", 0.12), 1.0, from, to)
		var count := tally(branch)
		var name := "%s　%d / %d" % [tr(BRANCH_NAMES[branch]), count[0], count[1]]
		if not _spots.has(name):
			_spots[name] = _part_spot(branch, _width(name, &"title_font", &"part_size"))
		var room: Rect2 = _spots[name]
		var colour := _colour(&"gold") if here else (_colour(&"pale") if _hovered(&"part", branch) else _colour(&"dim"))
		_words(room.position + Vector2(0.0, 20.0), name, &"title_font", &"part_size", colour)
		_zone(room.grow_individual(6.0, 2.0, 6.0, 2.0), [&"part", branch])


# The ring of a constellation's farthest stars.
func _last_ring(branch: StringName) -> float:
	var last := FIRST_RING
	for upgrade in MetaProgress.UPGRADES:
		if upgrade.branch == branch and not upgrade.parent.is_empty():
			last = maxf(last, _rings[upgrade.id])
	return last


# The room a constellation's name is written in: past its farthest stars,
# over the chart's head, under its foot or beside it. The first place along
# its part of the sky, from the middle outward, that stands clear of the
# card and every star: first one that needs no pulling in from the page's
# edges, then one pulled in.
func _part_spot(branch: StringName, wide: float) -> Rect2:
	var part: Array = _parts[branch]
	var mid: float = (part[0] + part[1]) * 0.5
	var half: float = (part[1] - part[0]) * 0.5
	var last := _last_ring(branch)
	# The sky runs past the page, so a name may stand in the bands over and
	# under it, between the hub's title and its keys.
	var field := Rect2(6.0, -40.0, CARD.position.x - 22.0, DESIGN.y + 72.0)
	for pulled: bool in [false, true]:
		for index in 61:
			var angle := mid + half * ceilf(index * 0.5) / 30.0 * (1.0 if index % 2 == 1 else -1.0)
			var room := _part_room(angle, last, wide)
			if pulled:
				room.position = room.position.clamp(field.position, field.end - room.size)
			elif not field.encloses(room):
				continue
			if not _places.values().any(func(at: Vector2) -> bool: return Rect2(at - Vector2(34.0, 34.0), Vector2(68.0, 76.0)).intersects(room)):
				return room
	var kept := _part_room(mid, last, wide)
	kept.position = kept.position.clamp(field.position, field.end - kept.size)
	return kept


func _part_room(angle: float, last: float, wide: float) -> Rect2:
	var way := Vector2(cos(angle), sin(angle))
	var lean := clampf(way.x * 2.0, -1.0, 1.0)
	var centre := _at(angle, last + 26.0) + Vector2(lean * (wide * 0.5 + 14.0), way.y * 44.0)
	return Rect2(centre - Vector2(wide * 0.5, 13.0), Vector2(wide, 26.0))


func _radius(id: StringName) -> float:
	return POLE_STAR if id == MetaProgress.ROOT else STAR


# A line's two ends: clear of the star it grows from and of its own.
func _segment(upgrade: MetaUpgrade) -> PackedVector2Array:
	var from: Vector2 = _places[upgrade.parent]
	var to: Vector2 = _places[upgrade.id]
	var along := (to - from).normalized()
	return PackedVector2Array([from + along * (_radius(upgrade.parent) + 5.0), to - along * (STAR + 5.0)])


func _draw_lines() -> void:
	var breath := 0.5 + 0.5 * sin(_clock * BREATH)
	for upgrade in MetaProgress.UPGRADES:
		if upgrade.parent.is_empty():
			continue
		var ends := _segment(upgrade)
		var state := state_of(upgrade.id)
		if meta.rank(upgrade.id) > 0:
			draw_line(ends[0], ends[1], _colour(&"gold", 0.85), 2.0, true)
			# The light that runs out to a star just lit.
			var lit := moment(upgrade.id)
			if lit < 1.0:
				var head := ends[0].lerp(ends[1], clampf(lit * 2.5, 0.0, 1.0))
				draw_line(ends[0], head, _colour(&"pale", 1.0 - lit), 5.0, true)
				_glow(head, 24.0, _colour(&"gold", 0.8 * (1.0 - lit)))
		elif state == State.LOCKED:
			draw_dashed_line(ends[0], ends[1], _colour(&"dark", 0.9), 1.2, 6.0)
		else:
			draw_line(ends[0], ends[1], _colour(&"blue", (0.35 + 0.35 * breath) if state == State.BUY else 0.3), 1.5, true)


func _draw_star(upgrade: MetaUpgrade) -> void:
	var id := upgrade.id
	var at: Vector2 = _places[id]
	var radius := _radius(id)
	var state := state_of(id)
	var rank := meta.rank(id)
	var held := rank > 0
	var pole := upgrade.parent.is_empty()
	var near := pole or MetaProgress.find(selected).branch == upgrade.branch
	var breath := 0.5 + 0.5 * sin(_clock * BREATH + at.x * 0.01)
	# The stars come out ring by ring as the page opens.
	var out := clampf((_since(&"open") - 0.04 * (_depths[id] as int)) / UIMotion.ENTER_TIME, 0.0, 1.0)
	out = 1.0 - pow(1.0 - out, 3.0)
	radius *= 0.6 + 0.4 * out
	if held:
		_glow(at, radius * 2.6, _colour(&"gold", 0.32 * out))
		for index in 4:
			var way := Vector2.from_angle(TAU * index / 4.0 + PI * 0.25)
			draw_line(at + way * (radius + 4.0), at + way * (radius + 12.0 + 3.0 * breath), _colour(&"gold", 0.8 * out), 1.5, true)
	elif state == State.BUY:
		_glow(at, radius * (2.2 + 0.5 * breath), _colour(&"blue", (0.30 + 0.15 * breath) * out))
	draw_circle(at, radius + 2.0, _colour(&"void"))
	var tint := Color.WHITE
	if state == State.LOCKED:
		tint = _colour(&"veil")
	elif not held:
		tint = _colour(&"pale")
	_picture(at, radius, upgrade.emblem, Color(tint, tint.a * out * (1.0 if near else 0.8)))
	var edge := &"gold" if held else (&"blue" if state == State.BUY else (&"dim" if state == State.SHORT else &"dark"))
	_ring(at, radius + 1.0, _colour(edge, out), 2.0)
	# Its ranks as points of light on an arc under it.
	var count := upgrade.max_rank()
	if count > 1:
		for index in count:
			var spot := at + Vector2.from_angle(PI * 0.5 + (index - (count - 1) * 0.5) * 0.44) * (radius + 8.0)
			draw_circle(spot, 2.8, _colour(&"gold") if index < rank else _colour(&"void"))
			_ring(spot, 2.8, _colour(&"gold") if index < rank else _colour(&"dim"), 1.0)
	if id != selected and _hovered(&"star", id):
		_ring(at, radius + 7.0, _colour(&"pale", 0.6), 1.5)
	# The moment a star is lit.
	var lit := moment(id)
	if lit < 1.0:
		var spread := 1.0 - pow(1.0 - lit, 3.0)
		_glow(at, radius * 5.0 * (0.4 + spread), _colour(&"lamp", 0.7 * (1.0 - lit)))
		_ring(at, radius + 10.0 + 64.0 * spread, _colour(&"gold", 1.0 - lit), 2.5)
		for index in 8:
			var way := Vector2.from_angle(TAU * index / 8.0)
			draw_line(at + way * (radius + 12.0 + 36.0 * spread), at + way * (radius + 24.0 + 70.0 * spread), _colour(&"gold", 1.0 - lit), 2.0, true)
	_zone(Rect2(at - Vector2.ONE * (radius + 7.0), Vector2.ONE * (radius + 7.0) * 2.0), [&"star", id])


# The names of the stars in the cursor's constellation: each under its star,
# or over it in the upper sky, where under would run into the star it grows
# from. The chosen star's is written last and in full; another's is left
# off where it would run into the cursor or the chosen star's name. In a
# script written with spaces the names run long, so only the chosen star
# carries its own.
func _draw_names() -> void:
	var chosen := MetaProgress.find(selected)
	var all := TranslationServer.get_locale().begins_with("ja")
	var taken: Array[Rect2] = [Rect2(_places[selected] as Vector2 - Vector2.ONE * (_radius(selected) + 16.0), Vector2.ONE * (_radius(selected) + 16.0) * 2.0)]
	if not chosen.parent.is_empty():
		taken.append(_name_rect(chosen, true))
	for upgrade in MetaProgress.UPGRADES:
		if not all or upgrade == chosen or upgrade.parent.is_empty() or upgrade.branch != chosen.branch:
			continue
		var rect := _name_rect(upgrade, false)
		if taken.any(func(other: Rect2) -> bool: return other.intersects(rect)):
			continue
		draw_rect(rect, _colour(&"void", 0.78))
		_words(rect.position + Vector2(4.0, 15.0), tr(upgrade.display_name), &"font", &"star_size", _colour(&"faint") if state_of(upgrade.id) == State.LOCKED else _colour(&"dim"))
	if not chosen.parent.is_empty():
		draw_rect(taken[1], _colour(&"void", 0.78))
		_words(taken[1].position + Vector2(4.0, 15.0), tr(chosen.display_name), &"bold_font", &"star_size", _colour(&"pale"))


# The plate a star's name is written on.
func _name_rect(upgrade: MetaUpgrade, bold: bool) -> Rect2:
	var at: Vector2 = _places[upgrade.id]
	var wide := _width(tr(upgrade.display_name), &"bold_font" if bold else &"font", &"star_size")
	# The chosen star's stands clear of the cursor's ring.
	var top := at.y + STAR + (18.0 if bold else (14.0 if upgrade.max_rank() > 1 else 7.0))
	if sin(float(_angles[upgrade.id])) < -0.5:
		top = at.y - STAR - (38.0 if bold else 27.0)
	return Rect2(clampf(at.x - wide * 0.5 - 4.0, 0.0, CARD.position.x - wide - 16.0), top, wide + 8.0, 20.0)


# The cursor: a ring with four ticks that turn, on its way to the chosen star.
func _draw_cursor() -> void:
	var at := _cursor()
	var radius := _radius(selected) + 8.0
	var colour := _colour(&"pale") if has_focus() else _colour(&"dim")
	_ring(at, radius, colour, 2.0)
	for index in 4:
		var way := Vector2.from_angle(TAU * index / 4.0 + _clock * 0.4)
		draw_line(at + way * radius, at + way * (radius + 8.0), colour, 2.0, true)


# The card: the chosen star in full. The button lies over its foot.
func _draw_card() -> void:
	var state: State = told.state
	draw_rect(CARD, _colour(&"panel"))
	draw_rect(CARD, _colour(&"brass", 0.8), false, 1.0)
	draw_rect(CARD.grow(-6.0), _colour(&"brass", 0.3), false, 1.0)
	for corner: Vector2 in [CARD.position, Vector2(CARD.end.x, CARD.position.y), CARD.end, Vector2(CARD.position.x, CARD.end.y)]:
		HubUI.diamond(self, corner, 6.0, _colour(&"brass"))
	var mid := CARD.get_center().x
	var left := CARD.position.x + 28.0
	var inner := CARD.size.x - 56.0
	var upgrade := MetaProgress.find(told.id)
	var fade := 0.35 + 0.65 * _eased(&"move", MOVE_TIME)
	var part: String = told.part
	_words(Vector2(CARD.position.x, 46.0), part if upgrade.branch.is_empty() else tr("%sの星座") % part, &"font", &"label_size", _colour(&"dim", fade), HORIZONTAL_ALIGNMENT_CENTER, CARD.size.x)
	var lit := 1.0 - moment(told.id)
	var rank: int = told.rank
	_glow(Vector2(mid, 128.0), 118.0, _colour(&"gold" if rank > 0 else &"blue", 0.12 + 0.4 * lit))
	var emblem := EmblemIcons.texture(upgrade.emblem)
	if emblem != null:
		var tint := _colour(&"veil") if state == State.LOCKED else Color.WHITE
		draw_texture_rect(emblem, Rect2(Vector2(mid - 60.0, 68.0), Vector2.ONE * 120.0), false, Color(tint, tint.a * fade))
	_words(Vector2(CARD.position.x + 12.0, 232.0), told.name, &"title_font", &"name_size", _colour(&"pale", fade), HORIZONTAL_ALIGNMENT_CENTER, CARD.size.x - 24.0)
	var ranks: int = told.ranks
	for index in ranks:
		var spot := Vector2(mid + (index - (ranks - 1) * 0.5) * 28.0, 258.0)
		if index < rank:
			_spark(spot, 10.0 + (9.0 * lit if index == rank - 1 else 0.0), _colour(&"gold"))
		else:
			_spark(spot, 10.0, _colour(&"dark"))
			_spark(spot, 6.0, _colour(&"panel"))
	draw_line(Vector2(left, 282.0), Vector2(left + inner, 282.0), _colour(&"brass", 0.4), 1.0)
	var y := 318.0
	var figure: String = told.figure
	if not figure.is_empty():
		y += _lines(Vector2(left, y), figure, &"bold_font", &"figure_size", _colour(&"gold", fade), inner, HORIZONTAL_ALIGNMENT_CENTER, 3) + 14.0
	var note: String = told.note
	if not note.is_empty():
		y += _lines(Vector2(left, y), note, &"font", &"body_size", _colour(&"pale", fade), inner) + 14.0
	_lines(Vector2(left, y), told.waits, &"font", &"body_size", _colour(&"warn", fade), inner, HORIZONTAL_ALIGNMENT_LEFT, 2)
	# The price beside the echo held, and how much is missing; once all its
	# ranks are held there is no price to set beside it.
	var price: int = told.price
	if price >= 0:
		draw_line(Vector2(left, 508.0), Vector2(left + inner, 508.0), _colour(&"brass", 0.4), 1.0)
		var needed := tr("必要")
		var kept := tr("所持")
		_words(Vector2(left, 542.0), needed, &"font", &"label_size", _colour(&"dim"))
		_words(Vector2(left + _width(needed, &"font", &"label_size") + 12.0, 546.0), UIFormat.amount(price), &"title_font", &"value_size", _colour(&"gold" if state == State.BUY else &"dim"))
		_words(Vector2(mid + 16.0, 542.0), kept, &"font", &"label_size", _colour(&"dim"))
		_words(Vector2(mid + 16.0 + _width(kept, &"font", &"label_size") + 12.0, 546.0), UIFormat.amount(told.held), &"title_font", &"value_size", _colour(&"pale"))
		var missing: int = told.missing
		if missing > 0:
			_words(Vector2(left, 574.0), tr("残響があと%s足りない") % UIFormat.amount(missing), &"font", &"label_size", _colour(&"warn"), HORIZONTAL_ALIGNMENT_CENTER, inner)
