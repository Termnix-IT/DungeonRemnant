class_name HudActions
extends Control

# What can be done right now, at the top left of the dungeon HUD: one key cap
# per line, standing on the floor without a plate. Out of the aim it lists the
# actions the HUD has no other place for (ready an attack, swap weapons, open
# the inventory, cast when a staff is worn, open the menu, which holds the
# settings and leaving the run), untitled. While an attack's direction is
# being chosen it turns into that mode's own card, titled so in gold, with
# only the keys that work in it. The aim's instructions once ran as a line in
# the message log, where they were the only sign that the mode had begun. The
# two weapons themselves stand beside the level (HudWeapons).

const WIDTH := 330.0
# Close to the screen's corner: the card has no plate to keep clear of.
const MARGIN := 6.0
# One line per key, packed closer than the hints' own height: the painted
# caps are shorter than a hint, so lines this far apart leave a small gap
# between the caps without the loose spacing of a stacked list.
const LINE := 34.0
const TITLE_HEIGHT := 26.0
# The most lines the card ever lists: out of the aim with a staff worn.
const MOST_LINES := 5

var aiming := false
var can_cast := false
var title: Label
var _guides: Array[KeyGuide] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	title = Label.new()
	title.theme_type_variation = &"HudGoldCaption"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	title.size = Vector2(WIDTH, TITLE_HEIGHT)
	show_state(false, false)


# Lists the keys for the state: aiming or not, and whether a staff can cast.
func show_state(is_aiming: bool, staff: bool) -> void:
	aiming = is_aiming
	can_cast = staff
	for guide in _guides:
		remove_child(guide)
		guide.queue_free()
	_guides.clear()
	var lines: Array = []
	if aiming:
		title.text = "攻撃の向きを選択中"
		lines = [["方向", "十字", "向きを変える"], ["Space", "A", "攻撃する"], ["Esc", "B", "やめる"]]
	else:
		lines = [["Space", "A", "構える"], ["Tab", "Y", "武器切替"], ["I", "X", "所持品"]]
		if can_cast:
			lines.append(["M", "RB", "魔法"])
		lines.append(["Esc", "Start", "メニュー"])
	# Only the aim has a title: it is the card's sign that the mode began.
	title.visible = aiming
	var top := TITLE_HEIGHT if aiming else 0.0
	for line: Array in lines:
		var guide := KeyGuide.new()
		add_child(guide)
		guide.add_hint(line[0], line[1], line[2])
		# Each hint is centred on its line and may reach past it a little.
		var height := guide.get_combined_minimum_size().y
		guide.position = Vector2(0, top + (LINE - height) * 0.5)
		guide.size = Vector2(WIDTH, height)
		_guides.append(guide)
		top += LINE
	# Held to the screen's top-left corner; the card grows downward.
	position = Vector2.ONE * MARGIN
	size = Vector2(WIDTH, top)


# How far down the card reaches at its longest, so what stands under it never
# moves as the card's lines change.
func full_height() -> float:
	return LINE * MOST_LINES


# The keys this card names, in order, for the tests and the help.
func keys() -> Array[String]:
	var found: Array[String] = []
	for guide in _guides:
		for hint: Button in guide._hints:
			found.append(guide.cap_text(hint))
	return found
