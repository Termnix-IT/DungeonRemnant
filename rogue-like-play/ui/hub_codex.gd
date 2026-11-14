class_name HubCodex
extends Control

# The bestiary: a naturalist's folio, one foe to a plate. The foe stands
# large on the plate, and what is known of it is written round it as notes:
# marks set on the figure (a, b, c), each led by a line to its note in the
# margin (its HP, the force of its blow, its pace, each on a measure against
# the strongest foe met), and beside them the account of how it behaves and
# where it is found. Left and right turn to the next plate. The tray under
# the folio holds every plate of the kind as a small specimen, the open one
# lifted on its pin, so any is reached at once; R (Y) lays the tray out by
# number or by a figure, the foes not met always after those met, so the
# order gives nothing away. The ribbons at the folio's head are the kinds
# (Q/E, LB/RB), each with its tally.
#
# A foe not met is a plate not yet drawn: its shape in one flat wash, no
# name, no notes, only its kind and the note that it is yet to be met.
#
# The page is one focusable control that draws itself in a design space of
# 1520x686 scaled to its rect, in the ink and faces of the theme's Bestiary
# type (a Grimoire, as the status page's book is). The sheet is a shader
# (ui/grimoire/grimoire_plate.gdshader); the foe is a sprite laid under the
# page's own drawing, so the marks and their lines lie over it. The pointer
# acts through zones named while drawing.

const PLATE := preload("res://ui/grimoire/grimoire_plate.gdshader")
const FLAT := preload("res://ui/grimoire/flat_shape.gdshader")
const PAPER_GRAIN := preload("res://art/ui/grimoire/paper.png")
const UNKNOWN_NAME := "？？？"
const UNKNOWN_NOTE := "まだ出会っていない敵。探索で戦場に現れると記録される。"
# The shade of a foe not met where its picture is drawn small (tile_picture).
const SHADOW := Color(0.0, 0.0, 0.0, 0.85)
const DESIGN := Vector2(1520.0, 686.0)
const SHEET := Rect2(40.0, 4.0, 1440.0, 556.0)
const STAGE := Rect2(110.0, 158.0, 600.0, 380.0)
const TEXT_LEFT := 100.0
const TEXT_WIDTH := 620.0
const NOTES_LEFT := 800.0
const NOTES_WIDTH := 600.0
const TRAY := Rect2(40.0, 574.0, 1440.0, 106.0)
const SPECIMEN := 24.0
const SPECIMEN_STEP := 66.0
const SPECIMENS_LEFT := 262.0
const TURN_TIME := UIMotion.ENTER_TIME
# The stage's figure breathes: its height swells by this share, a breath
# lasting BREATH_TIME seconds.
const BREATH := 0.012
const BREATH_TIME := 3.2
# The tray's orders: by number, or by a figure from the strongest down.
const SORTS := ["", "hp", "contact", "speed"]
const SORT_NAMES := ["番号順", "HPの高い順", "ぶつかる力の高い順", "速さの高い順"]

var meta: MetaProgress
# The kind shown (FoeCatalog.KINDS), the tray's order (SORTS), the plate
# open (an index in `listed`), and the kind's foes in the tray's order.
var kind := 0
var sort := 0
var place := 0
var listed: Array[FoeData] = []
# What the open plate tells: {foe, known, name, epithet, kind, stats, account}
# (stats: [key, name, value] each; account: [how it behaves, where found]).
var told := {}
var _sheet: ColorRect
var _figure: Node2D
var _portrait: Sprite2D
var _flat: ShaderMaterial
var _clock := 0.0
var _kicks := {}
var _way := 0.0
var _zones: Array = []
var _hover: Variant = null
var _origin := Vector2.ZERO
var _zoom := 1.0
var _fade := 1.0
var _slide := 0.0
var _quiet := true


func _ready() -> void:
	theme_type_variation = &"Bestiary"
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sheet = ColorRect.new()
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.show_behind_parent = true
	var paper := ShaderMaterial.new()
	paper.shader = PLATE
	paper.set_shader_parameter(&"paper_grain", PAPER_GRAIN)
	_sheet.material = paper
	add_child(_sheet)
	# The foe: under the page's own drawing, over the sheet.
	_figure = Node2D.new()
	_figure.name = "Figure"
	_figure.show_behind_parent = true
	add_child(_figure)
	_portrait = Sprite2D.new()
	_portrait.name = "Portrait"
	_portrait.centered = false
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_figure.add_child(_portrait)
	_flat = ShaderMaterial.new()
	_flat.shader = FLAT
	resized.connect(_fit)
	theme_changed.connect(_fit)
	_fit()


# Places the design space in the rect, and the sheet's shader with it.
func _fit() -> void:
	if _sheet == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_zoom = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_origin = ((size - DESIGN * _zoom) * 0.5).round()
	var paper := _sheet.material as ShaderMaterial
	paper.set_shader_parameter(&"extent", size)
	paper.set_shader_parameter(&"origin", _origin)
	paper.set_shader_parameter(&"zoom", _zoom)
	for item: StringName in [&"page_dark", &"page_light"]:
		paper.set_shader_parameter(item, get_theme_color(item))
	_place_figure()
	queue_redraw()


func refresh(current: MetaProgress) -> void:
	meta = current
	_quiet = true
	_list()
	_tell()
	_quiet = false
	queue_redraw()


# --- The folio's state ---

func known(foe: FoeData) -> bool:
	return meta != null and meta.has_met(foe.id)


# [met, all] of a kind (0 for every kind).
func tally(of_kind: int) -> Array[int]:
	var met := 0
	var all := 0
	for foe in FoeCatalog.FOES:
		if of_kind == 0 or FoeCatalog.kind_of(foe) == of_kind:
			all += 1
			met += 1 if known(foe) else 0
	return [met, all]


# A figure of a foe met, or -1 for one not met: what the tray is ordered by.
func _value(foe: FoeData, key: String) -> float:
	if not known(foe):
		return -1.0
	match key:
		"hp":
			return foe.max_hp
		"contact":
			return foe.contact_damage
		"speed":
			return roundf(foe.speed)
	return 0.0


# The largest of a figure among the foes met, to measure one against.
func _most(key: String) -> float:
	var top := 1.0
	for foe in FoeCatalog.FOES:
		top = maxf(top, _value(foe, key))
	return top


# The tray: the kind's foes in the chosen order, keeping the open plate open.
func _list() -> void:
	var held: FoeData = listed[place] if place < listed.size() else null
	listed = []
	for foe in FoeCatalog.FOES:
		if kind == 0 or FoeCatalog.kind_of(foe) == kind:
			listed.append(foe)
	var key: String = SORTS[sort]
	if not key.is_empty():
		listed.sort_custom(func(a: FoeData, b: FoeData) -> bool:
			var va := _value(a, key)
			var vb := _value(b, key)
			return FoeCatalog.FOES.find(a) < FoeCatalog.FOES.find(b) if va == vb else va > vb)
	place = maxi(0, listed.find(held)) if held != null and listed.has(held) else 0


func _tell() -> void:
	if meta == null or listed.is_empty():
		told = {}
		return
	var foe := listed[clampi(place, 0, listed.size() - 1)]
	var met := known(foe)
	var stats := []
	var account: Array[String] = [tr(UNKNOWN_NOTE), ""]
	if met:
		stats = [["hp", "HP", foe.max_hp], ["contact", tr("ぶつかる力"), foe.contact_damage], ["speed", tr("速さ"), roundi(foe.speed)]]
		var parts := tr(foe.description).split("\n", false)
		account = [parts[0], parts[1] if parts.size() > 1 else ""]
	told = {
		foe = foe, known = met, kind = FoeCatalog.kind_name(foe), stats = stats, account = account,
		name = tr(foe.display_name) if met else tr(UNKNOWN_NAME),
		epithet = tr(foe.epithet) if met and not foe.epithet.is_empty() else "",
	}
	_stand(foe, met)


# Turns to a plate in the tray.
func go_to(to: int) -> void:
	to = clampi(to, 0, maxi(0, listed.size() - 1))
	if to == place:
		return
	_way = 1.0 if to > place else -1.0
	place = to
	_tell()
	_kick(&"turn")
	_sound(&"ui_move")
	queue_redraw()


# Changes the kind shown, opening its first plate.
func turn_kind(to: int) -> void:
	to = clampi(to, 0, FoeCatalog.KINDS.size() - 1)
	if to == kind:
		return
	kind = to
	listed = []
	place = 0
	_list()
	_tell()
	_way = 0.0
	_kick(&"turn")
	_sound(&"ui_open")
	queue_redraw()


# R (Y): lays the tray out in the next order.
func cycle_sort() -> void:
	sort = (sort + 1) % SORTS.size()
	_list()
	_tell()
	_kick(&"sort")
	_sound(&"ui_move")
	queue_redraw()


func focus_first() -> void:
	grab_focus()


func play_entrance() -> void:
	_way = 0.0
	_kick(&"turn")


func _sound(cue: StringName) -> void:
	if not _quiet and is_visible_in_tree():
		GameAudio.play(self, cue, -22.0)


# --- A foe's picture for the other screens ---

static var _tiles: Dictionary = {}


# The foe's picture for its tile, or its dark silhouette: always a square
# the figure fills, standing on its bottom edge, so every tile lays its picture
# and its name out alike whatever the figure's shape. A foe drawn in a tint
# of its own (a kin sharing another's rig) is shown in it. The departure's
# foes and the route map's are drawn with it.
static func tile_picture(visual_id: String, known: bool, tint: Color = Color.WHITE) -> Texture2D:
	var key := "%s:%s:%s" % [visual_id, known, tint.to_html()]
	if _tiles.has(key):
		return _tiles[key]
	var shown := EnemySprites.portrait(visual_id)
	if shown.is_empty():
		return null
	var image := (shown.texture as Texture2D).get_image()
	if image == null:
		return null
	image.decompress()
	image = image.get_region(Rect2i(shown.region))
	image.convert(Image.FORMAT_RGBA8)
	# Trimmed to the figure, so a small foe fills its tile as a large one does.
	var used := image.get_used_rect()
	if used.has_area():
		image = image.get_region(used)
	if not known:
		for y in image.get_height():
			for x in image.get_width():
				var alpha := image.get_pixel(x, y).a
				image.set_pixel(x, y, Color(SHADOW, alpha * SHADOW.a))
	elif tint != Color.WHITE:
		for y in image.get_height():
			for x in image.get_width():
				image.set_pixel(x, y, image.get_pixel(x, y) * tint)
	var side := maxi(image.get_width(), image.get_height())
	var square := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	square.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i((side - image.get_width()) / 2, side - image.get_height()))
	_tiles[key] = ImageTexture.create_from_image(square)
	return _tiles[key]


# --- The foe on the plate ---

# Stands a foe on the plate: its painted portrait, or its shape in one flat
# wash when it is not met.
func _stand(foe: FoeData, met: bool) -> void:
	if _portrait == null:
		return
	var picture := EnemySprites.codex_portrait(foe.visual_id)
	if picture == null:
		picture = HubCodex.tile_picture(foe.visual_id, true)
	_portrait.texture = picture
	if picture != null:
		_portrait.offset = Vector2(-picture.get_width() * 0.5, -picture.get_height())
	_portrait.material = null if met else _flat
	_portrait.modulate = foe.tint if met else Color.WHITE
	_place_figure()


# Where the figure stands in the design space: as large as the stage holds,
# on the middle of its foot.
func figure_rect() -> Rect2:
	if _portrait == null or _portrait.texture == null:
		return Rect2(STAGE.get_center().x, STAGE.end.y, 0.0, 0.0)
	var picture := _portrait.texture
	var fit := minf(STAGE.size.x / picture.get_width(), STAGE.size.y / picture.get_height())
	var held := Vector2(picture.get_width(), picture.get_height()) * fit
	return Rect2(STAGE.get_center().x - held.x * 0.5, STAGE.end.y - held.y, held.x, held.y)


func _place_figure() -> void:
	if _figure == null or _portrait == null or _portrait.texture == null:
		return
	var at := figure_rect()
	var fit := at.size.y / _portrait.texture.get_height()
	var breath := 1.0 + BREATH * (0.5 + 0.5 * sin(_clock * TAU / BREATH_TIME))
	_figure.position = _origin + Vector2(at.get_center().x + _slide, at.end.y) * _zoom
	_figure.scale = Vector2(1.0, breath) * fit * _zoom
	_figure.modulate.a = _fade
	var wash := get_theme_color(&"shadow")
	_flat.set_shader_parameter(&"tint", Color(wash, wash.a * _fade))


# --- Clock ---

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	_fade = _eased(&"turn", TURN_TIME)
	_slide = 24.0 * _way * (1.0 - _fade)
	_place_figure()
	queue_redraw()


func _kick(what: StringName) -> void:
	_kicks[what] = _clock


func _since(what: StringName) -> float:
	return _clock - float(_kicks.get(what, -1000.0))


func _eased(what: StringName, time: float) -> float:
	var share := clampf(_since(what) / time, 0.0, 1.0)
	return 1.0 - pow(1.0 - share, 3.0)


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
				go_to(place - 1)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				go_to(place + 1)
				accept_event()
		return
	var handled := true
	if event.is_action_pressed(&"ui_left", true):
		go_to(place - 1)
	elif event.is_action_pressed(&"ui_right", true):
		go_to(place + 1)
	elif event.is_action_pressed(&"ui_up") or _pressed(event, KEY_Q, JOY_BUTTON_LEFT_SHOULDER):
		turn_kind(kind - 1)
	elif event.is_action_pressed(&"ui_down") or _pressed(event, KEY_E, JOY_BUTTON_RIGHT_SHOULDER):
		turn_kind(kind + 1)
	elif _pressed(event, KEY_R, JOY_BUTTON_Y):
		cycle_sort()
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
		&"ribbon":
			turn_kind(what[1])
		&"specimen":
			go_to(what[1])
		&"step":
			go_to(place + int(what[1]))
		&"sort":
			cycle_sort()


func _zone(rect: Rect2, id: Variant) -> void:
	_zones.append([rect, id])


func _zone_at(point: Vector2) -> Variant:
	var at := (point - _origin) / _zoom
	for index in range(_zones.size() - 1, -1, -1):
		if (_zones[index][0] as Rect2).has_point(at):
			return _zones[index][1]
	return null


func _hovered(what_kind: StringName, index: int) -> bool:
	if not _hover is Array:
		return false
	var what: Array = _hover
	return what[0] == what_kind and what.size() > 1 and what[1] == index


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = null


# --- Drawing ---

func _colour(item: StringName, share := 1.0) -> Color:
	var colour := get_theme_color(item)
	return Color(colour, colour.a * share)


# A colour of the plate's own writing, which fades in as a plate is turned to.
func _ink(item: StringName, share := 1.0) -> Color:
	return _colour(item, share * _fade)


func _face(item: StringName) -> Font:
	return get_theme_font(item)


func _size(item: StringName) -> int:
	return get_theme_font_size(item)


func _words(at: Vector2, words: String, face: StringName, size: StringName, colour: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(_face(face), at, words, align, width, _size(size), colour)


func _width(words: String, face: StringName, size: StringName) -> float:
	return _face(face).get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, _size(size)).x


func _ring(centre: Vector2, radius: float, colour: Color, width := 1.5) -> void:
	draw_arc(centre, radius, 0.0, TAU, maxi(24, int(radius * 0.9)), colour, width, true)


func _draw() -> void:
	_zones.clear()
	if meta == null or told.is_empty():
		return
	draw_set_transform(_origin, 0.0, Vector2.ONE * _zoom)
	_draw_ribbons()
	# The plate's ruled border.
	var border := SHEET.grow(-16.0)
	draw_rect(border, _colour(&"sepia", 0.7), false, 1.0)
	draw_rect(border.grow(-5.0), _colour(&"sepia", 0.35), false, 1.0)
	draw_set_transform(_origin + Vector2(_slide, 0.0) * _zoom, 0.0, Vector2.ONE * _zoom)
	_draw_plate()
	draw_set_transform(_origin, 0.0, Vector2.ONE * _zoom)
	_draw_steps()
	_draw_tray()
	draw_set_transform(Vector2.ZERO)


# The kinds' ribbons at the folio's head; the open kind's hangs longer.
func _draw_ribbons() -> void:
	for index in FoeCatalog.KINDS.size():
		var here := index == kind
		var rect := Rect2(1000.0 + 108.0 * index, 0.0, 96.0, 86.0 if here else 62.0)
		var colour := get_theme_color(StringName("ribbon_%d" % index))
		if not here:
			colour = colour.darkened(0.1 if _hovered(&"ribbon", index) else 0.28)
		draw_rect(Rect2(rect.position + Vector2(2.0, 3.0), rect.size), _colour(&"ink", 0.3))
		draw_colored_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.get_center().x, rect.end.y - 13.0), Vector2(rect.position.x, rect.end.y)]), colour)
		var count := tally(index)
		_words(Vector2(rect.position.x, rect.position.y + 28.0), tr(FoeCatalog.KINDS[index]), &"title_font", &"tab_size", _colour(&"seal_light"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
		_words(Vector2(rect.position.x, rect.position.y + 48.0), "%d / %d" % count, &"font", &"small_size", _colour(&"seal_light", 0.85), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
		_zone(rect, [&"ribbon", index])


# The open plate: its head, the marks on the figure led to their notes, and
# the foe's account.
func _draw_plate() -> void:
	var foe: FoeData = told.foe
	var met: bool = told.known
	_words(Vector2(TEXT_LEFT, 52.0), tr("図版　第 %02d") % (FoeCatalog.FOES.find(foe) + 1), &"font", &"label_size", _ink(&"sepia"))
	_words(Vector2(TEXT_LEFT, 52.0), tr("%sの類") % told.kind, &"font", &"label_size", _ink(&"sepia"), HORIZONTAL_ALIGNMENT_RIGHT, TEXT_WIDTH)
	_words(Vector2(TEXT_LEFT, 106.0), told.name, &"title_font", &"name_size", _ink(&"ink" if met else &"faint"), HORIZONTAL_ALIGNMENT_LEFT, TEXT_WIDTH)
	var epithet: String = told.epithet
	if not epithet.is_empty():
		_words(Vector2(TEXT_LEFT + 4.0, 134.0), "— %s" % epithet, &"font", &"label_size", _ink(&"seal"))
	elif not met:
		_words(Vector2(TEXT_LEFT + 4.0, 134.0), tr("いまだ観察されず"), &"font", &"label_size", _ink(&"sepia"))
	draw_line(Vector2(TEXT_LEFT, 148.0), Vector2(TEXT_LEFT + TEXT_WIDTH, 148.0), _ink(&"sepia", 0.6), 1.0)
	# The ground it stands on, hatched as an engraver shades it.
	var ground := Vector2(STAGE.get_center().x, STAGE.end.y - 4.0)
	for stroke in 34:
		var x := ground.x - 240.0 + 480.0 * stroke / 33.0
		var reach := 1.0 - absf(x - ground.x) / 240.0
		draw_line(Vector2(x, ground.y + 2.0), Vector2(x - 14.0, ground.y + 2.0 + 16.0 * sqrt(reach)), _ink(&"sepia", 0.45 * reach), 1.0, true)
	var left := NOTES_LEFT
	var y := 124.0
	if met:
		var at := figure_rect()
		var marks := [Vector2(at.position.x + at.size.x * 0.62, at.position.y + at.size.y * 0.2), Vector2(at.end.x - at.size.x * 0.14, at.position.y + at.size.y * 0.52), Vector2(at.position.x + at.size.x * 0.56, at.end.y - at.size.y * 0.1)]
		_words(Vector2(left, y), tr("記", "notes"), &"title_font", &"label_size", _ink(&"ink"))
		draw_line(Vector2(left, y + 10.0), Vector2(left + NOTES_WIDTH, y + 10.0), _ink(&"ink", 0.8), 1.5)
		y += 52.0
		var stats: Array = told.stats
		for index in stats.size():
			var stat: Array = stats[index]
			var letter := "abc"[index]
			var mark: Vector2 = marks[index]
			draw_polyline(PackedVector2Array([mark, Vector2(left - 26.0, y - 7.0), Vector2(left - 6.0, y - 7.0)]), _ink(&"sepia", 0.8), 1.0, true)
			draw_circle(mark, 9.0, _ink(&"seal_light"))
			_ring(mark, 9.0, _ink(&"ink"), 1.2)
			_words(Vector2(mark.x - 9.0, mark.y + 5.0), letter, &"title_font", &"small_size", _ink(&"ink"), HORIZONTAL_ALIGNMENT_CENTER, 18.0)
			_words(Vector2(left, y), "%s." % letter, &"title_font", &"label_size", _ink(&"seal"))
			_words(Vector2(left + 28.0, y), stat[1], &"font", &"body_size", _ink(&"sepia"))
			var value := str(stat[2])
			var value_width := _width(value, &"title_font", &"held_size")
			_words(Vector2(left + NOTES_WIDTH - value_width, y + 3.0), value, &"title_font", &"held_size", _ink(&"ink"))
			# A measure: ticks up to the strongest met, filled to this one.
			var from := left + maxf(160.0, 28.0 + _width(stat[1], &"font", &"body_size") + 18.0)
			var span := left + NOTES_WIDTH - value_width - 24.0 - from
			var share := sqrt(float(stat[2]) / _most(stat[0]))
			draw_line(Vector2(from, y - 6.0), Vector2(from + span, y - 6.0), _ink(&"sepia", 0.5), 1.0)
			for tick in 11:
				var x := from + span * tick / 10.0
				draw_line(Vector2(x, y - 6.0), Vector2(x, y - (14.0 if tick % 5 == 0 else 10.0)), _ink(&"sepia", 0.6), 1.0)
			draw_line(Vector2(from, y - 6.0), Vector2(from + span * share, y - 6.0), _ink(&"seal"), 3.0)
			y += 46.0
		y += 12.0
	var account: Array = told.account
	_words(Vector2(left, y), tr("観察記") if met else tr("覚え書き"), &"title_font", &"label_size", _ink(&"ink"))
	draw_line(Vector2(left, y + 10.0), Vector2(left + NOTES_WIDTH, y + 10.0), _ink(&"ink", 0.8), 1.5)
	y += 44.0
	var body := _face(&"font")
	var body_size := _size(&"body_size")
	# Japanese breaks between any two letters; a script with spaces, at them.
	var breaks := TextServer.BREAK_MANDATORY | (TextServer.BREAK_GRAPHEME_BOUND if TranslationServer.get_locale().begins_with("ja") else TextServer.BREAK_WORD_BOUND)
	var words: String = account[0]
	draw_multiline_string(body, Vector2(left, y), words, HORIZONTAL_ALIGNMENT_LEFT, NOTES_WIDTH, body_size, 5, _ink(&"ink" if met else &"sepia"), breaks)
	y += body.get_multiline_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, NOTES_WIDTH, body_size, 5, breaks).y + 20.0
	var found: String = account[1]
	if not found.is_empty():
		var head := tr("棲息")
		_words(Vector2(left, y), head, &"title_font", &"label_size", _ink(&"seal"))
		var inset := _width(head, &"title_font", &"label_size") + 16.0
		draw_multiline_string(body, Vector2(left + inset, y), found, HORIZONTAL_ALIGNMENT_LEFT, NOTES_WIDTH - inset, _size(&"label_size") + 2, 2, _ink(&"sepia"), breaks)


# The marks at the sheet's two edges that turn the plate.
func _draw_steps() -> void:
	for side: int in [-1, 1]:
		var able: bool = (side < 0 and place > 0) or (side > 0 and place < listed.size() - 1)
		var centre := Vector2(SHEET.position.x - 20.0 if side < 0 else SHEET.end.x + 20.0, SHEET.get_center().y)
		var colour := _colour(&"seal_light", (1.0 if _hovered(&"step", side) else 0.8) if able else 0.2)
		draw_colored_polygon(PackedVector2Array([centre + Vector2(10.0 * side, 0.0), centre + Vector2(-7.0 * side, -16.0), centre + Vector2(-7.0 * side, 16.0)]), colour)
		if able:
			_zone(Rect2(centre - Vector2(20.0, 50.0), Vector2(40.0, 100.0)), [&"step", side])


# The tray of specimens under the folio: every plate of the kind in the
# chosen order, the open one lifted on its pin.
func _draw_tray() -> void:
	draw_rect(Rect2(TRAY.position + Vector2(0.0, 5.0), TRAY.size), _colour(&"ink", 0.45))
	draw_rect(TRAY, _colour(&"tray"))
	draw_rect(TRAY, _colour(&"tray_edge"), false, 2.0)
	var count := tally(kind)
	_words(Vector2(TRAY.position.x + 20.0, TRAY.position.y + 34.0), tr(FoeCatalog.KINDS[kind]), &"title_font", &"body_size", _colour(&"seal_light"))
	_words(Vector2(TRAY.position.x + 20.0, TRAY.position.y + 58.0), tr("%d / %d を観察") % count, &"font", &"small_size", _colour(&"seal_light", 0.75))
	var order := tr("並び：%s") % tr(SORT_NAMES[sort])
	_words(Vector2(TRAY.position.x + 20.0, TRAY.position.y + 84.0), order, &"font", &"small_size", _colour(&"seal_light", 1.0 if _hovered(&"sort", 0) or _since(&"sort") < 0.4 else 0.75))
	_zone(Rect2(TRAY.position.x + 12.0, TRAY.position.y + 66.0, 200.0, 28.0), [&"sort", 0])
	var room := TRAY.end.x - 24.0 - SPECIMENS_LEFT
	var shown := int(room / SPECIMEN_STEP)
	var first := clampi(place - shown / 2, 0, maxi(0, listed.size() - shown))
	var lift := _eased(&"turn", UIMotion.SELECT_TIME)
	for index in range(first, mini(listed.size(), first + shown)):
		var foe := listed[index]
		var here := index == place
		var centre := Vector2(SPECIMENS_LEFT + SPECIMEN_STEP * (index - first + 0.5), TRAY.position.y + 46.0 - (8.0 * lift if here else 0.0))
		_zone(Rect2(centre - Vector2.ONE * (SPECIMEN + 8.0), Vector2.ONE * (SPECIMEN + 8.0) * 2.0), [&"specimen", index])
		if here:
			draw_line(centre + Vector2(0.0, SPECIMEN), Vector2(centre.x, TRAY.end.y - 22.0), _colour(&"seal_light", 0.8), 1.5)
		draw_circle(centre, SPECIMEN + 3.0, _colour(&"seal_light") if known(foe) else _colour(&"tray_edge"))
		var face := FoeIcon.of(foe.visual_id, known(foe), foe.tint)
		if face != null:
			draw_texture_rect(face, Rect2(centre - Vector2.ONE * SPECIMEN, Vector2.ONE * SPECIMEN * 2.0), false)
		var rim := &"seal" if here else (&"seal_light" if _hovered(&"specimen", index) else &"tray_edge")
		_ring(centre, SPECIMEN + 3.0, _colour(rim), 3.0 if here else 1.5)
		_words(Vector2(centre.x - 30.0, TRAY.end.y - 8.0), "%02d" % (FoeCatalog.FOES.find(foe) + 1), &"font", &"small_size", _colour(&"seal_light", 0.95 if here else 0.5), HORIZONTAL_ALIGNMENT_CENTER, 60.0)
	# More of the tray lies past its ends.
	if first > 0:
		_words(Vector2(SPECIMENS_LEFT - 22.0, TRAY.position.y + 52.0), "‹", &"title_font", &"held_size", _colour(&"seal_light", 0.7))
	if first + shown < listed.size():
		_words(Vector2(TRAY.end.x - 22.0, TRAY.position.y + 52.0), "›", &"title_font", &"held_size", _colour(&"seal_light", 0.7))
