class_name HudActions
extends Panel

# What can be done right now, at the bottom right of the dungeon HUD: one key
# cap per line. Out of the aim it lists the actions the HUD has no other place
# for (ready an attack, open the inventory, cast when a staff is worn, leave
# the run); while an attack's direction is being chosen it turns into that
# mode's own card, in the gilt plate (HudPanelActive) and titled so, with only
# the keys that work in it. The aim's instructions once ran as a line in the message log, where
# they were the only sign that the mode had begun. The weapon swap stays on
# the weapon row, beside the weapons it swaps.

const WIDTH := 300.0
# From the screen's edges, like the other HUD plates.
const MARGIN := 16.0
# Clear of the plate's corner brackets.
const PADDING := Vector2(24, 16)
const LINE := 34.0
const TITLE_HEIGHT := 26.0

var aiming := false
var can_cast := false
var title: Label
var _guides: Array[KeyGuide] = []
var _lines: VBoxContainer


func _init() -> void:
	theme_type_variation = &"HudPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_lines = VBoxContainer.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lines)
	_lines.position = PADDING
	title = Label.new()
	title.theme_type_variation = &"HudCaption"
	title.custom_minimum_size.y = TITLE_HEIGHT
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.add_child(title)
	show_state(false, false)


# Lists the keys for the state: aiming or not, and whether a staff can cast.
func show_state(is_aiming: bool, staff: bool) -> void:
	aiming = is_aiming
	can_cast = staff
	theme_type_variation = &"HudPanelActive" if aiming else &"HudPanel"
	for guide in _guides:
		_lines.remove_child(guide)
		guide.queue_free()
	_guides.clear()
	var lines: Array = []
	if aiming:
		title.text = "攻撃の向きを選択中"
		title.theme_type_variation = &"GoldLabel"
		lines = [["方向", "十字", "向きを変える"], ["Space", "A", "攻撃する"], ["Esc", "B", "やめる"]]
	else:
		title.text = "操作"
		title.theme_type_variation = &"HudCaption"
		lines = [["Space", "A", "構える"], ["I", "X", "所持品"]]
		if can_cast:
			lines.append(["M", "RB", "魔法"])
		lines.append(["R", "Start", "中断"])
	for line: Array in lines:
		var guide := KeyGuide.new()
		guide.custom_minimum_size.y = LINE
		_lines.add_child(guide)
		guide.add_hint(line[0], line[1], line[2])
		_guides.append(guide)
	# Held to the screen's bottom-right corner; the card grows upward.
	var height := PADDING.y * 2 + _lines.get_combined_minimum_size().y
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_right = -MARGIN
	offset_bottom = -MARGIN
	offset_left = -MARGIN - WIDTH
	offset_top = -MARGIN - height
	_lines.size.x = WIDTH - PADDING.x * 2


# The keys this card names, in order, for the tests and the help.
func keys() -> Array[String]:
	var found: Array[String] = []
	for guide in _guides:
		for hint: Button in guide._hints:
			found.append(guide.cap_text(hint))
	return found
