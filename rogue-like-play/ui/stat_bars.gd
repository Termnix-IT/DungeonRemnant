class_name StatBars
extends Control

# Stat rows that read a change at a glance: the caption, an optional bar
# (the current value filled, a rise drawn green past it, a fall cut back in
# red), then "current » new" with an arrow. A value that does not change is
# written once, so only the changed rows carry an arrow.

const ROW_HEIGHT := 28.0
const CAPTION_WIDTH := 96.0
const BAR_WIDTH := 132.0
const BAR_HEIGHT := 4.0
const NUMBER_WIDTH := 44.0

# Each row: [caption, before, after, scale]; scale is the bar's full value.
var rows: Array = []
var bars := true
# 0 to 1 while the bars move from what they showed to the new rows
# (UIMotion.blend_in); the numbers are always the new ones.
var blend := 1.0:
	set(value):
		blend = value
		queue_redraw()
# Per row, the bar as [kept, reach, tone]: the length both values share, the
# length of the larger, and the colour of the part between them.
var _from: Array = []
var _to: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_rows(values: Array) -> void:
	var shown := _shown()
	rows = values
	_to = []
	for row: Array in rows:
		_to.append(_bar(row))
	# The bars move from where they are only when the same rows are on show.
	_from = shown if shown.size() == _to.size() else _to.duplicate()
	custom_minimum_size.y = ROW_HEIGHT * rows.size()
	visible = not rows.is_empty()
	UIMotion.of(self).blend_in()
	queue_redraw()


func _bar(row: Array) -> Array:
	var before: int = row[1]
	var after: int = row[2]
	var full := maxf(1.0, float(row[3]))
	var tone := &"StatUp" if after > before else (&"StatDown" if after < before else &"")
	return [clampf(minf(before, after) / full, 0, 1) * BAR_WIDTH, clampf(maxf(before, after) / full, 0, 1) * BAR_WIDTH, tone]


# The bars as drawn now, partway through a move.
func _shown() -> Array:
	var shown := []
	for index in mini(_from.size(), _to.size()):
		var start: Array = _from[index]
		var end: Array = _to[index]
		# A change that is going away keeps its colour while it shrinks.
		shown.append([lerpf(start[0], end[0], blend), lerpf(start[1], end[1], blend), end[2] if end[2] != &"" else start[2]])
	return shown


func _draw() -> void:
	var font := get_theme_font(&"font")
	var caption_size := get_theme_font_size(&"font_size", &"MutedLabel")
	var value_size := get_theme_font_size(&"font_size", &"BodyLabel")
	var muted := get_theme_color(&"font_color", &"MutedLabel")
	var body := get_theme_color(&"font_color", &"Label")
	var rise := get_theme_color(&"font_color", &"StatUp")
	var fall := get_theme_color(&"font_color", &"StatDown")
	var shown := _shown()
	for index in rows.size():
		var row: Array = rows[index]
		var before: int = row[1]
		var after: int = row[2]
		var top := index * ROW_HEIGHT
		var middle := top + ROW_HEIGHT * 0.5
		var baseline := middle + (font.get_ascent(value_size) - font.get_descent(value_size)) * 0.5
		var tone := rise if after > before else (fall if after < before else muted)
		draw_string(font, Vector2(0, baseline), row[0], HORIZONTAL_ALIGNMENT_LEFT, CAPTION_WIDTH, caption_size, muted)
		var x := CAPTION_WIDTH
		if bars:
			var track := Rect2(x, middle - BAR_HEIGHT * 0.5, BAR_WIDTH, BAR_HEIGHT)
			draw_rect(track, Color(muted, 0.18))
			var bar: Array = shown[index] if index < shown.size() else _bar(row)
			draw_rect(Rect2(track.position, Vector2(bar[0], BAR_HEIGHT)), Color(body, 0.75))
			if bar[1] - bar[0] > 0.5 and bar[2] != &"":
				draw_rect(Rect2(track.position + Vector2(bar[0], 0), Vector2(bar[1] - bar[0], BAR_HEIGHT)), rise if bar[2] == &"StatUp" else fall)
			x += BAR_WIDTH + 16.0
		# Without bars the numbers keep close to their captions, so the eye
		# does not cross an empty stretch to find a row's value.
		var right := size.x if bars else minf(size.x, CAPTION_WIDTH + NUMBER_WIDTH * 2.0 + 26.0 + 18.0)
		var arrow :="▲" if after > before else ("▼" if after < before else "")
		var arrow_width := 18.0
		# A new arrow fades in with the bar's move.
		var arrow_tone := tone
		if index < _from.size() and _from[index][2] != _to[index][2]:
			arrow_tone.a *= blend
		draw_string(font, Vector2(right - arrow_width, baseline), arrow, HORIZONTAL_ALIGNMENT_RIGHT, arrow_width, caption_size, arrow_tone)
		draw_string(font, Vector2(right - arrow_width - NUMBER_WIDTH, baseline), str(after), HORIZONTAL_ALIGNMENT_RIGHT, NUMBER_WIDTH, value_size, tone if after != before else body)
		if after == before:
			continue
		draw_string(font, Vector2(right - arrow_width - NUMBER_WIDTH - 26.0, baseline), "»", HORIZONTAL_ALIGNMENT_CENTER, 26.0, caption_size, muted)
		draw_string(font, Vector2(right - arrow_width - NUMBER_WIDTH * 2.0 - 26.0, baseline), str(before), HORIZONTAL_ALIGNMENT_RIGHT, NUMBER_WIDTH, value_size, muted)
