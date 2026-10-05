class_name CategoryTabs
extends HBoxContainer

# A row of text tabs that filter a list, with the keys that step through
# them shown at either end (Q / E, LB / RB on a gamepad). The chosen tab is
# underlined in gold; the others are quiet text with no box round them.

signal changed(index: int)

var selected := 0
var tabs: Array[Button] = []
var _group := ButtonGroup.new()
var _caps: Array[Label] = []


func _init() -> void:
	theme_type_variation = &"CategoryTabs"


func setup(names: Array[String]) -> void:
	_caps.append(_cap("Q"))
	for index in names.size():
		var tab := Button.new()
		tab.text = names[index]
		tab.theme_type_variation = &"CategoryTab"
		tab.toggle_mode = true
		tab.button_group = _group
		tab.pressed.connect(func(): select(index, true))
		add_child(tab)
		tabs.append(tab)
	_caps.append(_cap("E"))
	select(0)


func _cap(text: String) -> Label:
	var cap := Label.new()
	cap.text = text
	cap.theme_type_variation = &"CategoryCap"
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(cap)
	return cap


# The caps follow the device: Q / E on keys, LB / RB on a gamepad.
func use_pad(pad: bool) -> void:
	_caps[0].text = "LB" if pad else "Q"
	_caps[1].text = "RB" if pad else "E"


func select(index: int, emit := false) -> void:
	selected = posmod(index, tabs.size())
	for other in tabs.size():
		tabs[other].set_pressed_no_signal(other == selected)
	if emit:
		changed.emit(selected)


func step(direction: int) -> void:
	select(selected + direction, true)
