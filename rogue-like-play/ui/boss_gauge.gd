class_name BossGauge
extends Control

# The boss's health across the top of the screen while it is in view: its name
# in the display face above a generated frame (art/ui/boss_gauge.png, built by
# tools/build_boss_gauge.py) whose dark channel holds the fill, a trail that
# drains after each hit, and quarter ticks like the player's HP bar.
const FRAME := preload("res://art/ui/boss_gauge.png")
# Measured by `python tools/build_boss_gauge.py --measure`; update them when
# the picture changes.
const CAP_LEFT := 62
const CAP_RIGHT := 33
const CHANNEL_TOP := 27
const CHANNEL_BOTTOM := 49
const NAME_HEIGHT := 30.0
const HIT_FLASH := Color(1.8, 1.8, 1.8)
const HIT_FLASH_TIME := 0.16

var name_label: Label
var value_label: Label
var frame: NinePatchRect
var trail: ProgressBar
var bar: ProgressBar
var ticks: VitalTicks
var _boss_name := ""
var _flash: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	frame = NinePatchRect.new()
	frame.texture = FRAME
	frame.patch_margin_left = CAP_LEFT
	frame.patch_margin_right = CAP_RIGHT
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	trail = _bar(&"BossHpTrail")
	trail.step = 0.0
	bar = _bar(&"BossHp")
	ticks = VitalTicks.new()
	ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ticks)
	name_label = _label(&"BossGaugeName", HORIZONTAL_ALIGNMENT_LEFT)
	value_label = _label(&"BossGaugeValue", HORIZONTAL_ALIGNMENT_RIGHT)
	resized.connect(_layout)
	_layout()
	hide()


func _bar(role: StringName) -> ProgressBar:
	var progress := ProgressBar.new()
	progress.theme_type_variation = role
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress)
	return progress


func _label(role: StringName, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.theme_type_variation = role
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _layout() -> void:
	frame.position = Vector2(0, NAME_HEIGHT)
	frame.size = Vector2(size.x, FRAME.get_height())
	var channel := Rect2(CAP_LEFT, NAME_HEIGHT + CHANNEL_TOP, size.x - CAP_LEFT - CAP_RIGHT, CHANNEL_BOTTOM - CHANNEL_TOP)
	for control: Control in [trail, bar, ticks]:
		control.position = channel.position
		control.size = channel.size
	name_label.position = Vector2(CAP_LEFT, 0)
	name_label.size = Vector2(channel.size.x * 0.7, NAME_HEIGHT)
	value_label.position = Vector2(channel.end.x - channel.size.x * 0.3, 0)
	value_label.size = Vector2(channel.size.x * 0.3, NAME_HEIGHT)


# An empty name hides the gauge. A new boss enters with the gauge already
# full; later hits drain the trail behind the fill.
func present(boss_name: String, hp: int, max_hp: int) -> void:
	if boss_name.is_empty():
		_boss_name = ""
		UIMotion.of(trail).reset_vital()
		hide()
		return
	var arriving := boss_name != _boss_name or not visible
	var hurt := not arriving and hp < bar.value
	_boss_name = boss_name
	name_label.text = boss_name
	value_label.text = "%d / %d" % [maxi(hp, 0), max_hp]
	bar.max_value = maxi(max_hp, 1)
	bar.value = maxi(hp, 0)
	show()
	UIMotion.of(trail).update_vital(hp, max_hp, value_label)
	if arriving:
		UIMotion.of(self).appear(0.0, UIMotion.WINDOW_TIME)
	elif hurt:
		_flash_hit()


func _flash_hit() -> void:
	if _flash != null:
		_flash.kill()
	bar.modulate = HIT_FLASH
	_flash = create_tween()
	_flash.tween_property(bar, "modulate", Color.WHITE, HIT_FLASH_TIME)
