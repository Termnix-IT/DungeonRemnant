class_name VitalTicks
extends Control

# Quarter notches over a vital bar, so its fill reads as a gauge at a glance.
# Placed over the bar's rectangle and drawn above the fill; never takes input.
const STEPS := 4
const NOTCH := Color(0.02, 0.025, 0.035, 0.7)
const GLINT := Color(1, 1, 1, 0.12)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	for step in range(1, STEPS):
		var x := roundf(size.x * step / STEPS)
		draw_rect(Rect2(x - 1, 0, 1, size.y), NOTCH)
		draw_rect(Rect2(x, 0, 1, size.y), GLINT)
