class_name StatBars
extends Control

# Stat rows that read a change at a glance: the caption, an optional bar
# (the current value filled, a rise drawn green past it, a fall cut back in
# red), then "current » new" with an arrow. Values that do not change stay
# in the quiet colour so the changed ones stand out.

const ROW_HEIGHT := 28.0
const CAPTION_WIDTH := 96.0
const BAR_WIDTH := 132.0
const BAR_HEIGHT := 4.0
const NUMBER_WIDTH := 44.0

# Each row: [caption, before, after, scale]; scale is the bar's full value.
var rows: Array = []
var bars := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_rows(values: Array) -> void:
	rows = values
	custom_minimum_size.y = ROW_HEIGHT * rows.size()
	visible = not rows.is_empty()
	queue_redraw()


func _draw() -> void:
	var font := get_theme_font(&"font")
	var caption_size := get_theme_font_size(&"font_size", &"MutedLabel")
	var value_size := get_theme_font_size(&"font_size", &"BodyLabel")
	var muted := get_theme_color(&"font_color", &"MutedLabel")
	var body := get_theme_color(&"font_color", &"Label")
	var rise := get_theme_color(&"font_color", &"StatUp")
	var fall := get_theme_color(&"font_color", &"StatDown")
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
			var scale := maxf(1.0, float(row[3]))
			var track := Rect2(x, middle - BAR_HEIGHT * 0.5, BAR_WIDTH, BAR_HEIGHT)
			draw_rect(track, Color(muted, 0.18))
			var kept := minf(before, after) / scale * BAR_WIDTH
			draw_rect(Rect2(track.position, Vector2(clampf(kept, 0, BAR_WIDTH), BAR_HEIGHT)), Color(body, 0.75))
			if after != before:
				var from := clampf(minf(before, after) / scale * BAR_WIDTH, 0, BAR_WIDTH)
				var to := clampf(maxf(before, after) / scale * BAR_WIDTH, 0, BAR_WIDTH)
				draw_rect(Rect2(track.position + Vector2(from, 0), Vector2(to - from, BAR_HEIGHT)), tone)
			x += BAR_WIDTH + 16.0
		var right := size.x
		var arrow := "▲" if after > before else ("▼" if after < before else "")
		var arrow_width := 18.0
		draw_string(font, Vector2(right - arrow_width, baseline), arrow, HORIZONTAL_ALIGNMENT_RIGHT, arrow_width, caption_size, tone)
		draw_string(font, Vector2(right - arrow_width - NUMBER_WIDTH, baseline), str(after), HORIZONTAL_ALIGNMENT_RIGHT, NUMBER_WIDTH, value_size, tone if after != before else body)
		draw_string(font, Vector2(right - arrow_width - NUMBER_WIDTH - 26.0, baseline), "»", HORIZONTAL_ALIGNMENT_CENTER, 26.0, caption_size, muted)
		draw_string(font, Vector2(right - arrow_width - NUMBER_WIDTH * 2.0 - 26.0, baseline), str(before), HORIZONTAL_ALIGNMENT_RIGHT, NUMBER_WIDTH, value_size, muted)
