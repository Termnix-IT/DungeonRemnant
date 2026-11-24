class_name BossOutro
extends CanvasLayer

# A boss's fall, told the way its entrance was (BossIntro), so the end of
# the fight answers its start: once the fall's slowed moment has passed, the
# black bars come back in at the top and bottom and the fight's HUD goes; its
# epithet and name rise in the lower third, as they did when it came;
# a blade of light crosses the name and leaves it struck through; and the
# word of its slaying is stamped over it in gold, the screen flushing and
# shaking with the blow. It stays until the hall is left (`leave`, with the
# dark closing on the place) or a level's cards come up over it.
#
# It is only seen: the world goes on under it (she walks, the echoes come to
# her), and nothing waits for it. The area times the hall's leaving, not
# this.

# The word has landed.
signal struck

const BAR_TIME := 0.28
# The name rises, the blade crosses it, the word is stamped (seconds from
# the start).
const NAME_AT := 0.05
const NAME_TIME := 0.3
const NAME_RISE := 14.0
const CUT_AT := 0.42
const CUT_TIME := 0.15
const CUT_SLANT := 7.0
const WORD_AT := 0.56
const WORD_TIME := 0.14
const WORD_FROM := 1.8
# The word's middle and the name's, as shares of the screen's height (both
# under her, who stands in the screen's middle), and how far the struck name
# fades under the word.
const WORD_PLACE := 0.645
const NAME_PLACE := 0.805
const STRUCK := 0.55
const FLUSH := Color(1.0, 0.8, 0.42, 0.24)
const FLUSH_TIME := 0.5
const SHAKE := 9.0
# The lines out from either side of the landed word, and how long they take.
const WING := 230.0
const WING_TIME := 0.35
const OUT_TIME := 0.45

var word: Label
# Whether the word has landed, and whether it is on its way out.
var landed := false
var leaving := false
var _area: BattleArea
var _root: Control
var _top: ColorRect
var _bottom: ColorRect
var _epithet: Label
var _name: Label
var _cut: Control
var _flush: ColorRect
var _reach := 0.0
var _wings := 0.0
var _name_width := 0.0
var _playing: Tween


# When the word lands, from the start.
static func word_time() -> float:
	return WORD_AT + WORD_TIME


func present(area: BattleArea, theme: Theme) -> void:
	_area = area
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = theme
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flush = ColorRect.new()
	_flush.color = Color(FLUSH, 0.0)
	_flush.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flush)
	_flush.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bar_color := _root.get_theme_color(&"bar", &"BossIntro")
	_top = _bar(bar_color, true)
	_bottom = _bar(bar_color, false)
	var boss: FoeData = area.data.boss
	_epithet = _label(tr(boss.epithet), &"BossEpithet")
	_name = _label(tr(boss.display_name), &"BossName")
	var screen := _root.get_viewport_rect().size
	_name.position.y = screen.y * NAME_PLACE - _name.get_combined_minimum_size().y * 0.5
	_epithet.position.y = _name.position.y - _epithet.get_combined_minimum_size().y - 2.0
	_name_width = _name.get_theme_font(&"font").get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _name.get_theme_font_size(&"font_size")).x
	_cut = Control.new()
	_cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cut.draw.connect(_draw_cut)
	_root.add_child(_cut)
	_cut.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	word = _label(tr("討伐"), &"SlainWord")
	var room := word.get_combined_minimum_size()
	word.size.y = room.y
	word.position.y = screen.y * WORD_PLACE - room.y * 0.5
	word.pivot_offset = Vector2(screen.x * 0.5, room.y * 0.5)
	for label: Label in [_epithet, _name, word]:
		label.modulate.a = 0.0


func begin() -> void:
	var screen := _root.get_viewport_rect().size
	_playing = create_tween().set_parallel().set_ignore_time_scale(true)
	_playing.tween_property(_top, "position:y", 0.0, BAR_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_playing.tween_property(_bottom, "position:y", screen.y - BossIntro.BAR_HEIGHT, BAR_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for label: Label in [_epithet, _name]:
		var rest := label.position.y
		label.position.y = rest + NAME_RISE
		_playing.tween_property(label, "modulate:a", 1.0, NAME_TIME).set_delay(NAME_AT)
		_playing.tween_property(label, "position:y", rest, NAME_TIME).set_delay(NAME_AT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_playing.tween_callback(GameAudio.play.bind(self, &"boss_slain", -8.0)).set_delay(CUT_AT)
	_playing.tween_method(_reach_to, 0.0, 1.0, CUT_TIME).set_delay(CUT_AT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	word.scale = Vector2.ONE * WORD_FROM
	_playing.tween_property(word, "scale", Vector2.ONE, WORD_TIME).set_delay(WORD_AT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_playing.tween_property(word, "modulate:a", 1.0, WORD_TIME * 0.6).set_delay(WORD_AT)
	_playing.tween_callback(_land).set_delay(word_time())


func _reach_to(value: float) -> void:
	_reach = value
	_cut.queue_redraw()


func _wing_to(value: float) -> void:
	_wings = value
	_cut.queue_redraw()


# The word lands: the screen flushes gold and shakes, the name under it
# stands back.
func _land() -> void:
	if landed:
		return
	landed = true
	_flush.color = FLUSH
	var after := create_tween().set_parallel().set_ignore_time_scale(true)
	after.tween_property(_flush, "color", Color(FLUSH, 0.0), FLUSH_TIME)
	for label: Label in [_epithet, _name]:
		after.tween_property(label, "modulate:a", STRUCK, FLUSH_TIME)
	after.tween_method(_wing_to, 0.0, 1.0, WING_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_area):
		_area.shake(SHAKE)
	struck.emit()


# It goes: with the dark closing on the hall, or as a level's cards come.
func leave(time: float = OUT_TIME) -> void:
	if leaving:
		return
	leaving = true
	if _playing != null:
		_playing.kill()
	var screen := _root.get_viewport_rect().size
	var out := create_tween().set_parallel().set_ignore_time_scale(true)
	for part: Control in [_epithet, _name, word, _cut]:
		out.tween_property(part, "modulate:a", 0.0, time * 0.7)
	out.tween_property(_top, "position:y", -BossIntro.BAR_HEIGHT, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	out.tween_property(_bottom, "position:y", screen.y, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	out.chain().tween_callback(queue_free)


func _bar(color: Color, top: bool) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)
	var screen := _root.get_viewport_rect().size
	bar.size = Vector2(screen.x, BossIntro.BAR_HEIGHT)
	bar.position = Vector2(0, -BossIntro.BAR_HEIGHT if top else screen.y)
	return bar


func _label(text: String, role: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = role
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	label.size.x = _root.get_viewport_rect().size.x
	return label


# The blade of light across the name: the stroke it leaves behind it, gold,
# fading at its ends, and while it is crossing a bright head at its tip.
func _draw_cut() -> void:
	if _reach <= 0.0:
		return
	var gold := word.get_theme_color(&"font_color")
	var middle := Vector2(_cut.size.x * 0.5, _name.position.y + _name.size.y * 0.54)
	var half := _name_width * 0.5 + 46.0
	var from := middle + Vector2(-half, CUT_SLANT)
	var to := middle + Vector2(half, -CUT_SLANT)
	var tip := from.lerp(to, _reach)
	var dark := _name.get_theme_color(&"font_outline_color")
	var ends := 0.95 if _reach < 1.0 else 0.0
	_cut.draw_polyline_colors(PackedVector2Array([from, from.lerp(tip, 0.5), tip]), PackedColorArray([Color(dark, 0.0), Color(dark, 0.7), Color(dark, 0.7 * ends)]), 8.0, true)
	_cut.draw_polyline_colors(PackedVector2Array([from, from.lerp(tip, 0.5), tip]), PackedColorArray([Color(gold, 0.0), Color(gold, 1.0), Color(gold, ends)]), 4.0, true)
	# The word's wings: a line out from either side of it once it has landed.
	if _wings > 0.0:
		var level := word.position.y + word.size.y * 0.52
		var room := word.get_theme_font(&"font").get_string_size(word.text, HORIZONTAL_ALIGNMENT_LEFT, -1, word.get_theme_font_size(&"font_size")).x * 0.5 + 34.0
		for side: float in [-1.0, 1.0]:
			var near := Vector2(_cut.size.x * 0.5 + side * room, level)
			var far := near + Vector2(side * WING * _wings, 0.0)
			_cut.draw_polyline_colors(PackedVector2Array([near, near.lerp(far, 0.4), far]), PackedColorArray([Color(gold, 0.9), Color(gold, 0.6), Color(gold, 0.0)]), 2.0, true)
			HubUI.mark(_cut, near, 5.0, gold)
	if _reach < 1.0:
		var bright := Color(1.0, 0.97, 0.88)
		var along := (to - from).normalized()
		var across := along.orthogonal()
		_cut.draw_colored_polygon(PackedVector2Array([tip + along * 34.0, tip + across * 5.0, tip - along * 90.0, tip - across * 5.0]), bright)
