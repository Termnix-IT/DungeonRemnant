class_name AbilityCard
extends Control

# Display layer of one level-up offer. The owning Button keeps input and
# layout; this Control only draws, so UIMotion may move it freely.
#
# The card is a painted one (art/ui/cards/card_face.png: a bronze and gold
# frame round dark slate, a ring at its head for the boon's emblem and a
# gold line under it), over the theme's opaque plate, so its words read on
# any floor. It is dealt face down (card_back.png, the game's emblem) and
# turned over (`turn`): its words show only once its face does. Pointed at
# or focused it stands in a warm light of its own and its ring kindles; the
# chosen moment (`glow`) floods it with that light.
#
# It shows a BoonData: the shortcut and whether the boon is new or a rank
# being raised ("新規", "Lv 1 → 2") over the ring, the emblem in the ring,
# the name under the gold line, the ranks as bronze sockets (the owned ones
# holding an amber gem), and its words for the rank on offer: what a new
# boon does, and for a rank being raised, the numbers that grow.

const FACE: Texture2D = preload("res://art/ui/cards/card_face.png")
const BACK: Texture2D = preload("res://art/ui/cards/card_back.png")
# The card's size on the 1600x900 base (the painting's 2:3).
const SIZE := Vector2(300.0, 450.0)
# Where the painting's ring is (its middle, and the emblem's width in it)
# and where its parts stand, all as shares of the card.
const RING := Vector2(0.494, 0.268)
const EMBLEM_ACROSS := 0.27
const STATUS_Y := 0.078
const NAME_Y := 0.452
const PIPS_Y := 0.548
const WORDS := Rect2(0.13, 0.595, 0.74, 0.265)
# What the boon belongs to, at the card's foot.
const FAMILIES_Y := 0.868
# The plate stands this far inside the card's outline (the painting's
# corners are round).
const PLATE_INSET := 9.0
# The light a card pointed at stands in: how far it spreads past the card.
const HALO_SPREAD := 1.5

var ability: BoonData
var level := 0
var hovered := false:
	set(value):
		hovered = value
		_show_status()
		_light()
# 0..1 strength of the chosen moment: the card floods with light and the
# gained rank's gem comes in.
var glow := 0.0:
	set(value):
		glow = value
		_light()
		pips.queue_redraw()
# 0: face down; 1: face up. Between, the card is seen edge on.
var turn := 1.0:
	set(value):
		turn = clampf(value, 0.0, 1.0)
		_content.visible = turn > 0.5
		queue_redraw()

var key_label: Label
var status_label: Label
var name_label: Label
var effect_label: Label
var families_label: Label
var symbol: Control
var pips: Control
var _content: Control
var _halo: TextureRect


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# The warm light it stands in, behind it.
	var fall := Gradient.new()
	fall.set_color(0, Color(1.0, 0.82, 0.48, 0.5))
	fall.set_color(1, Color(1.0, 0.82, 0.48, 0.0))
	fall.add_point(0.55, Color(1.0, 0.82, 0.48, 0.22))
	var light := GradientTexture2D.new()
	light.gradient = fall
	light.fill = GradientTexture2D.FILL_RADIAL
	light.fill_from = Vector2(0.5, 0.5)
	light.fill_to = Vector2(1.0, 0.5)
	_halo = TextureRect.new()
	_halo.texture = light
	_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_halo.stretch_mode = TextureRect.STRETCH_SCALE
	_halo.show_behind_parent = true
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var added := CanvasItemMaterial.new()
	added.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_halo.material = added
	_halo.modulate.a = 0.0
	add_child(_halo)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The shortcut and the status share one centred line over the ring.
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(top)
	_place(top, Rect2(0.1, STATUS_Y - 0.03, 0.8, 0.06))
	key_label = HubUI.label(top, "", &"MutedLabel")
	key_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label = HubUI.label(top, "", &"MutedLabel")
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	# The painted emblem in the ring, from its mipmaps.
	symbol = _canvas(_draw_symbol)
	_place(symbol, Rect2(RING.x - EMBLEM_ACROSS * 0.5, RING.y - EMBLEM_ACROSS * 0.5 * SIZE.x / SIZE.y, EMBLEM_ACROSS, EMBLEM_ACROSS * SIZE.x / SIZE.y))
	symbol.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	name_label = HubUI.label(_content, "", &"HeadingLabel")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(name_label, Rect2(0.1, NAME_Y, 0.8, 0.085))
	pips = _canvas(_draw_pips)
	_place(pips, Rect2(0.14, PIPS_Y, 0.72, 0.034))
	effect_label = HubUI.label(_content, "", &"DescriptionLabel")
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Its words stand in the middle of the slate under the ranks, few or many.
	effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(effect_label, WORDS)
	# Its families, always in sight: hands are compared by what a card adds
	# to (her blade, her skills, her guard), before its words are read.
	families_label = HubUI.label(_content, "", &"MutedLabel")
	families_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	families_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	families_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(families_label, Rect2(0.1, FAMILIES_Y, 0.8, 0.05))


# A part of the card held at a share of it, whatever the card's size.
func _place(part: Control, share: Rect2) -> void:
	part.anchor_left = share.position.x
	part.anchor_top = share.position.y
	part.anchor_right = share.end.x
	part.anchor_bottom = share.end.y
	part.offset_left = 0.0
	part.offset_top = 0.0
	part.offset_right = 0.0
	part.offset_bottom = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5
		if _halo != null:
			_halo.size = size * HALO_SPREAD
			_halo.position = (size - _halo.size) * 0.5


# The light it stands in: a little while pointed at, all of it at the chosen moment.
func _light() -> void:
	if _halo != null:
		_halo.modulate.a = maxf(glow, 0.5 if hovered else 0.0)
	queue_redraw()


# A rank being raised says so; a new boon says it is new. Its families are
# at its foot either way.
func _show_status() -> void:
	if status_label == null or ability == null:
		return
	status_label.text = "Lv %d → %d" % [level, level + 1] if level > 0 else tr("新規")
	families_label.text = ability.families_text()


func setup(data: BoonData, current_level: int, shortcut: int) -> void:
	ability = data
	level = current_level
	glow = 0.0
	hovered = false
	key_label.text = str(shortcut)
	_show_status()
	name_label.text = tr(data.display_name)
	name_label.tooltip_text = tr(data.display_name)
	# A rank being raised tells what grows; a new boon, what it does.
	var gain := data.gain_text(level) if level > 0 else ""
	TextWrap.set_text(effect_label, gain if not gain.is_empty() else data.effect_description(level + 1))
	symbol.queue_redraw()


func _canvas(painter: Callable) -> Control:
	var canvas := Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(painter)
	_content.add_child(canvas)
	return canvas


# Face down, edge on or face up, by its turn; lit by its light.
func _draw() -> void:
	var across := absf(cos(turn * PI))
	var rect := Rect2(Vector2(size.x * (1.0 - across) * 0.5, 0.0), Vector2(size.x * across, size.y))
	if turn > 0.5:
		draw_style_box(get_theme_stylebox(&"plate", &"AbilityCard"), rect.grow(-PLATE_INSET * across))
	var lit := maxf(glow, 0.5 if hovered else 0.0)
	var shine := 1.0 + 0.32 * lit
	draw_texture_rect(FACE if turn > 0.5 else BACK, rect, false, Color(shine, shine, shine))


func _draw_symbol() -> void:
	if ability == null:
		return
	var extent := minf(symbol.size.x, symbol.size.y)
	EmblemIcons.paint(symbol, Rect2((symbol.size - Vector2.ONE * extent) / 2, Vector2.ONE * extent), ability.emblem_key())


# One socket per rank: owned ranks hold a gem, the offered rank's gem fades
# in on choice.
func _draw_pips() -> void:
	if ability == null:
		return
	var empty := get_theme_icon(&"pip_empty", &"AbilityCard")
	var full := get_theme_icon(&"pip_full", &"AbilityCard")
	var count: int = ability.max_level
	var gap := 3.0
	var width := minf(full.get_width(), (pips.size.x - gap * (count - 1)) / count)
	var height := width * full.get_height() / full.get_width()
	var start := (pips.size.x - width * count - gap * (count - 1)) / 2
	for index in count:
		var rect := Rect2(start + index * (width + gap), (pips.size.y - height) / 2, width, height)
		pips.draw_texture_rect(empty, rect, false)
		if index < level:
			pips.draw_texture_rect(full, rect, false)
		elif index == level:
			pips.draw_texture_rect(full, rect, false, Color(1, 1, 1, lerpf(0.35, 1.0, glow)))
