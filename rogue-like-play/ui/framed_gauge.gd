class_name FramedGauge
extends Control

# A health bar set in a painted frame (art/ui/<name>_gauge.png, built by
# tools/build_gauges.py): an ornament at each end and a dark channel between
# them. The frame is a nine-patch that stretches only the channel; the fill,
# the trail that drains behind it after each hit, and quarter ticks are laid
# inside the channel. The boss's gauge and the hero's HP bar each hold one,
# with their own picture and Theme roles. The gauge is as tall as its picture.

var frame: NinePatchRect
var trail: ProgressBar
var bar: ProgressBar
var ticks: VitalTicks
var _channel_top: int
var _channel_bottom: int


# The cap widths and channel rows are the picture's, as
# `python tools/build_gauges.py --measure` prints them.
func _init(picture: Texture2D, cap_left: int, cap_right: int, channel_top: int, channel_bottom: int, fill_role: StringName, trail_role: StringName) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(cap_left + cap_right, picture.get_height())
	_channel_top = channel_top
	_channel_bottom = channel_bottom
	frame = NinePatchRect.new()
	frame.texture = picture
	frame.patch_margin_left = cap_left
	frame.patch_margin_right = cap_right
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	trail = _bar(trail_role)
	trail.step = 0.0
	bar = _bar(fill_role)
	ticks = VitalTicks.new()
	add_child(ticks)
	resized.connect(_layout)
	_layout()


func _bar(role: StringName) -> ProgressBar:
	var progress := ProgressBar.new()
	progress.theme_type_variation = role
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress)
	return progress


# Where the fill runs, in the gauge's own coordinates.
func channel() -> Rect2:
	var left := frame.patch_margin_left
	return Rect2(left, _channel_top, size.x - left - frame.patch_margin_right, _channel_bottom - _channel_top)


func _layout() -> void:
	frame.size = Vector2(size.x, frame.texture.get_height())
	var rect := channel()
	for control: Control in [trail, bar, ticks]:
		control.position = rect.position
		control.size = rect.size
