class_name GoalTrack
extends Range

# How far an area's goal has come, on the fight's HUD: a thin track with a
# star that travels along it, the way gone lit behind the star and quarter
# marks ahead of it. It is drawn unlike the echo bar on purpose (a line and
# a marker, not a filling band), so the two are never taken for each other:
# the band across the top is what she has gathered toward a level, this is
# how much of the place is left. Colours are the theme's (HudGoldValue for
# the way gone, HudCaption for the way ahead).

const LINE := 2.0
const STAR := 7.0
const TICK := 4.0
const QUARTERS := 4


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	min_value = 0.0
	max_value = 100.0
	step = 0.01
	value_changed.connect(func(_now: float): queue_redraw())


func _draw() -> void:
	var gone := get_theme_color(&"font_color", &"HudGoldValue")
	var ahead := Color(get_theme_color(&"font_color", &"HudCaption"), 0.55)
	var middle := size.y * 0.5
	var from := Vector2(STAR, middle)
	var to := Vector2(size.x - STAR, middle)
	var share := clampf((value - min_value) / maxf(max_value - min_value, 0.001), 0.0, 1.0)
	var at := from.lerp(to, share)
	draw_line(from, to, ahead, LINE, true)
	for quarter in QUARTERS + 1:
		var mark := from.lerp(to, float(quarter) / QUARTERS)
		draw_line(mark - Vector2(0.0, TICK), mark + Vector2(0.0, TICK), gone if mark.x <= at.x else ahead, LINE, true)
	draw_line(from, at, gone, LINE + 1.0, true)
	HubUI.mark(self, at, STAR, gone)
